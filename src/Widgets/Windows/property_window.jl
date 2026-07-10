mutable struct PropertyWindow <: WindowDNA
    window::Window
    graph::GeometryPlotGraph
    renderers::Dict{DataType,Renderer}

    PropertyWindow(graph::GeometryPlotGraph, renderers::Dict{DataType,Renderer}) = new(Window(), graph, renderers)
end

_Window_(property_window::PropertyWindow)::Window = property_window.window
getWindowName(property_window::PropertyWindow) = "Node Properties"

const DEFAULT_EDIT_NODE_METHOD = which(edit_node, Tuple{Any, Dict{DataType,Renderer}, NodeHandle})
function renderContent(property_window::PropertyWindow)
    elements::Vector{Any} = property_window.graph.elements
    names::Vector{String} = [string(typeof(e)) for e in elements]
    sorted_indices = sortperm(names)

    current_type = ""
    is_tree_open = false

    for i in sorted_indices
        element = elements[i]
        #current_method = which(edit_node, Tuple{typeof(element), typeof(property_window.renderers), NodeHandle})
        #if current_method == DEFAULT_EDIT_NODE_METHOD
        #    continue
        #end
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
            new_element, invalidate = edit_node(element, property_window.renderers, NodeHandle(i))
            elements[i] = new_element
            if invalidate 
                invalidate!(property_window.graph, NodeHandle(i)) 
            end
            CImGui.PopID()
        end
    end

    if is_tree_open
        CImGui.TreePop()
    end
end