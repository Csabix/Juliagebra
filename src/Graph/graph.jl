include("node.jl")
include("graph_helpers.jl")

@kwdef struct GeometryPlotGraph
    lck::LockRW = LockRW()
    elements::Vector{Any} = Vector{Any}()
    render_data::Vector{Any} = Vector{Any}()
    nodes::Vector{GeometryPlotNode} = Vector{GeometryPlotNode}()
    invalidate_stack::Vector{NodeHandle} = Vector{NodeHandle}()
    wait_pool::WaitPool = WaitPool()
    invalid_count::Base.Threads.Atomic{UInt64} = Base.Threads.Atomic{UInt64}(0)
    needs_render_count::Base.Threads.Atomic{UInt64} = Base.Threads.Atomic{UInt64}(0)
end

@node_bit NODE_UPDATE_RENDER
@node_bit NODE_EVAL_ON_MAIN

function clear!(graph::GeometryPlotGraph)::Nothing
    empty!(graph.elements)
    empty!(graph.render_data)
    empty!(graph.nodes)
    return nothing
end

function add!(graph::GeometryPlotGraph, element::Any, render_data::Any,
    parents::Union{Vector{NodeHandle},Nothing}, callback::Union{Function,Nothing}, flags::NodeFlag)::NodeHandle

    push!(graph.elements, element)
    push!(graph.render_data, render_data)
    handle::NodeHandle = NodeHandle(UInt32(length(graph.elements)))
    node::GeometryPlotNode = GeometryPlotNode(callback, parents, flags)
    
    if (callback === nothing)
        Threads.atomic_add!(graph.needs_render_count,UInt64(1))
        set_geom_flags!(node,NODE_UPDATE_RENDER)
    else Threads.atomic_add!(graph.invalid_count,UInt64(1)) end
    push!(graph.nodes, node)
    if parents !== nothing
        parents_vec::Vector{NodeHandle} = parents::Vector{NodeHandle}
        for parent_h::NodeHandle in parents_vec
            if graph.nodes[parent_h].child_h === nothing
                graph.nodes[parent_h].child_h = NodeHandle[handle]
            else
                push!(graph.nodes[parent_h].child_h, handle)
            end
        end
    end

    return handle
end

function set_geom_flags!(node::GeometryPlotNode, flags::NodeFlag)::NodeFlag
    node.flags |= flags
    return node.flags
end

has_geom_flag(node::GeometryPlotNode, flags::NodeFlag) = (node.flags & flags) == flags

function unset_geom_flags!(node::GeometryPlotNode, flags::NodeFlag)::NodeFlag
    node.flags &= ~flags
    return node.flags
end

function rerender!(graph::GeometryPlotGraph, handle::NodeHandle)::Nothing
    if !has_geom_flag(graph.nodes[handle], NODE_UPDATE_RENDER)
        set_geom_flags!(graph.nodes[handle], NODE_UPDATE_RENDER)
        Threads.atomic_add!(graph.needs_render_count,UInt64(1))
    end
    return nothing
end

function invalidate!(graph::GeometryPlotGraph, handle::NodeHandle)::Nothing
    current::NodeHandle = handle
    nodes::Vector{GeometryPlotNode} = graph.nodes
    invalidate_stack::Vector{NodeHandle} = graph.invalidate_stack
    #nodes[handle].needs_render = NODE_RENDER
    #set_geom_flags!(graph.nodes[handle], NODE_UPDATE_RENDER)
    while true
        node::GeometryPlotNode = nodes[current]
        if (@atomic :monotonic node.state) == NODE_VALID
            if node.child_h !== nothing append!(invalidate_stack, node.child_h) end
            if node.callback !== nothing
                @atomic :monotonic node.state = NODE_INVALID
                Threads.atomic_add!(graph.invalid_count,UInt64(1))
            else
                if !has_geom_flag(nodes[current], NODE_UPDATE_RENDER)
                    set_geom_flags!(nodes[current], NODE_UPDATE_RENDER)
                    Threads.atomic_add!(graph.needs_render_count,UInt64(1))
                end
            end
        end
        if isempty(invalidate_stack)
            break
        end
        current = pop!(invalidate_stack)
    end
    return nothing
end

function update!(graph::GeometryPlotGraph, delta_time::Float64, handle::NodeHandle)::Nothing
    elements::Vector{Any} = graph.elements
    current::Int = handle.value
    limit::Int = length(elements)
    while current <= limit
        element, invalidate = update(elements[current], delta_time)
        elements[current] = element
        if invalidate
            invalidate!(graph, NodeHandle(UInt32(current)))
        end
        current = current + 1
    end
    return nothing
end

function _ready(graph::GeometryPlotGraph, node::GeometryPlotNode)::Bool
    ready::Bool = true
    if node.parent_h === nothing return ready end
    parent_handles::Vector{NodeHandle} = node.parent_h::Vector{NodeHandle}
    nodes::Vector{GeometryPlotNode} = graph.nodes
    for parent_h in parent_handles
        ready &= (@atomic :acquire nodes[parent_h].state) == NODE_VALID
        if !ready
            break
        end
    end
    return ready
end

function _try_entry_no_wait(graph::GeometryPlotGraph, node::GeometryPlotNode, index::Int)::Nothing
    (old::NodeState, succes::Bool) = @atomicreplace :monotonic :monotonic node.state NODE_INVALID => NODE_LOCKED
    if succes
        graph.elements[index] = eval_geometry_node(graph.elements[index], node, graph.elements)
        set_geom_flags!(node,NODE_UPDATE_RENDER)
        Threads.atomic_add!(graph.needs_render_count,UInt64(1))
        Threads.atomic_sub!(graph.invalid_count,UInt64(1))
        @atomic :release node.state = NODE_VALID
        notify(graph.wait_pool, index)
    end
    return nothing
end

function _try_entry(graph::GeometryPlotGraph, node::GeometryPlotNode, index::Int)::Nothing
    (old::NodeState, succes::Bool) = @atomicreplace :monotonic :monotonic node.state NODE_INVALID => NODE_LOCKED
    if succes
        parent_handles::Vector{NodeHandle} = node.parent_h::Vector{NodeHandle}
        for p_h in parent_handles
            wait(graph.wait_pool, graph.nodes[p_h], Int(p_h.value), NODE_LOCKED)
        end
        graph.elements[index] = eval_geometry_node(graph.elements[index], node, graph.elements)
        set_geom_flags!(node,NODE_UPDATE_RENDER)
        Threads.atomic_add!(graph.needs_render_count,UInt64(1))
        Threads.atomic_sub!(graph.invalid_count,UInt64(1))
        @atomic :release node.state = NODE_VALID
        notify(graph.wait_pool, index)
    end
    return nothing
end

function validate!(graph::GeometryPlotGraph, start::NodeHandle)::Nothing
    if (graph.invalid_count[] == 0) return nothing end
    is_main_thread = Threads.threadid() == 1
    nodes::Vector{GeometryPlotNode} = graph.nodes
    current::Int = start.value
    limit::Int = length(nodes)
    while current <= limit
        node::GeometryPlotNode = nodes[current]
        if (@atomic :monotonic node.state) == NODE_INVALID
            if _ready(graph, node)
                _try_entry_no_wait(graph, node, current)
            else
                _try_entry(graph, node, current)
            end
        end
        current = current + 1
    end
    return nothing
end

function render!(graph::GeometryPlotGraph, renderers::Dict{DataType,Renderer})::Bool
    nodes::Vector{GeometryPlotNode} = graph.nodes
    elements::Vector{Any} = graph.elements
    render_data::Vector{Any} = graph.render_data
    if graph.needs_render_count[] > 0
        for index in eachindex(nodes)
            if (has_geom_flag(nodes[index],NODE_UPDATE_RENDER))
                render_data[index] = render_node(elements[index],render_data[index],renderers,UInt32(index))
                unset_geom_flags!(nodes[index],NODE_UPDATE_RENDER)
                atomic_sub!(graph.needs_render_count,UInt64(1))
            end
        end
        return true
    end
    return false
end