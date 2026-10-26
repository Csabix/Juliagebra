using CImGui.CSyntax.CStatic
mutable struct OptionsWindow <: WindowDNA
    _window::Window

    _aabbMin::Array{Cfloat}
    _aabbMax::Array{Cfloat}
    function OptionsWindow(aabbMin,aabbMax)
        aabbMin = Cfloat[aabbMin[1],aabbMin[2],aabbMin[3]]
        aabbMax = Cfloat[aabbMax[1],aabbMax[2],aabbMax[3]]
        new(Window(),aabbMin,aabbMax)
    end
end

_Window_(self::OptionsWindow)::Window = self._window
getWindowName(self::OptionsWindow) = "Options"


function _setInfiniteAABBSize(self::OptionsWindow, app)
    app._opengl._ubo_aabb[1] = UBO_AABB(
        Vec4F(self._aabbMin[1],self._aabbMin[2],self._aabbMin[3],0.0),
        Vec4F(self._aabbMax[1],self._aabbMax[2],self._aabbMax[3],0.0)
    )
    _updateScene!(app)
end

function _render_option(name::String, subcategory::Dict{String, Any}, defaults::Dict{String, Any}, hints::Union{Dict{String, Any}, Nothing}, path::String)
    if CImGui.TreeNode(name)
        options = collect(keys(subcategory))
        indices = sortperm(options)
        for i in indices
            o = options[i]
            v = subcategory[o]
            h = hints !== nothing ? get(hints, o, nothing) : nothing
            if v isa Dict
                _render_option(o, v, defaults[o], h, path*"/$o")
            else
                result = input_property(o,v, h)
                if v!=result
                    set_global_setting(path*"/$o", result)
                end
                if result != defaults[o]
                    CImGui.SameLine()
                    if CImGui.Button("Reset##$path/$o")
                        set_global_setting(path*"/$o", defaults[o])
                    end
                end

            end
        end
        CImGui.TreePop()
    end
end

selected_category::Int = -1 # @cstatic doesn't work for some reaon?
function renderContent(self::OptionsWindow, app::AppDNA)
    @assert global_settings !== nothing "Settings are uninitialized"
    #=@cstatic selected_category::Int = -1=# begin
        CImGui.BeginChild("Option Categories",(CImGui.GetContentRegionAvail().x * 0.2, 0.0))
        categories = collect(keys(global_settings.settings))
        category_indices = sortperm(categories)
        for i in category_indices
            if CImGui.Selectable(categories[i], selected_category == i)
                global selected_category = i
            end
        end
        CImGui.EndChild()
        CImGui.SameLine()
        CImGui.BeginChild("Options", (0.0,0.0))
        if checkbounds(Bool, categories, selected_category)
            i = selected_category
            _render_option(categories[i], global_settings.settings[categories[i]], default_settings()[categories[selected_category]], global_settings.settings_hints[categories[i]], categories[i])
        end
        CImGui.EndChild()
        return
    end

    # if (CImGui.CollapsingHeader("Gizmo settings"))
    #     if (CImGui.SliderFloat("Length", self._gizmoLength, 0.5, 2.0))
    #         _setGizmo(self, app)
    #     end
    #     if (CImGui.SliderFloat("Thickness", self._gizmoThickness, 0.5, 2.0))
    #         _setGizmo(self, app)
    #     end
    # end
    # if (CImGui.CollapsingHeader("Infinite AABB settings"))
    #     if (CImGui.DragFloat3("Minimum", self._aabbMin, 1.0, -100.0, -1.0))
    #         _setInfiniteAABBSize(self, app)
    #     end
    #     if (CImGui.DragFloat3("Maximum", self._aabbMax, 1.0, 1.0, 100.0))
    #         _setInfiniteAABBSize(self, app)
    #     end
    # end
end