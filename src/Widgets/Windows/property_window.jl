mutable struct PropertyWindow <: WindowDNA
    window::Window
    graph::GeometryPlotGraph
    renderers::Dict{DataType,Renderer}

    PropertyWindow(graph::GeometryPlotGraph, renderers::Dict{DataType,Renderer}) = new(Window(), graph, renderers)
end

_Window_(property_window::PropertyWindow)::Window = property_window.window
getWindowName(property_window::PropertyWindow) = "Node Properties"

function renderContent(property_window::PropertyWindow)
    elements::Vector{Any} = property_window.graph.elements
    render_data::Vector{Any} = property_window.graph.render_data
    names::Vector{String} = [string(typeof(e)) for e in elements]
    sorted_indices = sortperm(names)

    current_type = ""
    is_tree_open = false

    for i in sorted_indices
        element = elements[i]
        if !edit_node_overload(element) continue end

        element_type_name = names[i]
        if element_type_name != current_type
            if is_tree_open
                CImGui.TreePop()
            end
            current_type = element_type_name
            is_tree_open = CImGui.TreeNode(current_type)
        end
        if is_tree_open
            CImGui.PushID(i)
            elements[i], render_data[i], result = edit_node(element, render_data[i], property_window.renderers, NodeHandle(i))
            if (result & EDIT_NODE_INVALIDATE) == EDIT_NODE_INVALIDATE
                invalidate!(property_window.graph, NodeHandle(i)) 
            elseif (result & EDIT_NODE_RERENDER) == EDIT_NODE_RERENDER
                rerender!(property_window.graph, NodeHandle(i))
            end
            CImGui.PopID()
        end
    end

    if is_tree_open
        CImGui.TreePop()
    end
end