
mutable struct PropertyWindow <: WindowDNA
    window::Window
    model::Model
    renderers::PrimitiveRenderers

    PropertyWindow(model::Model, renderers::PrimitiveRenderers) = new(Window(), model, renderers)
end

_Window_(self::PropertyWindow)::Window = self.window
getWindowName(self::PropertyWindow) = "Dependent Properties"

edit_dependent_overload(::RenderedDependentDNA)::Bool = false
edit_dependent(::RenderedDependentDNA,::Model,::PrimitiveRenderers)::Nothing = nothing


function renderContent(self::PropertyWindow)
    dependents::Vector{RenderedDependentDNA} = filter(x -> x isa RenderedDependentDNA, self.model._graph._dependents)
    names::Vector{String} = [string(typeof(d)) for d in dependents]
    sorted_indices = sortperm(names)

    current_type = ""
    is_tree_open = false

    for i in sorted_indices
        dependent = dependents[i]
        if !edit_dependent_overload(dependent) continue end

        dependent_type_name = names[i]
        if dependent_type_name != current_type
            if is_tree_open
                CImGui.TreePop()
            end
            current_type = dependent_type_name
            is_tree_open = CImGui.TreeNode(current_type)
        end
        if is_tree_open
            CImGui.PushID(i)
            edit_dependent(dependent, self.model, self.renderers)
            CImGui.PopID()
        end
    end

    if is_tree_open
        CImGui.TreePop()
    end
end
