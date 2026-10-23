using CImGui.CSyntax.CStatic
mutable struct OptionsWindow <: WindowDNA
    _window::Window

    _whitebg::Ref{Bool}
    _bgColor::Array{Cfloat}

    _gizmoLength::Ref{Float32}
    _gizmoThickness::Ref{Float32}

    _aabbMin::Array{Cfloat}
    _aabbMax::Array{Cfloat}
    function OptionsWindow(color,aabbMin,aabbMax)
        whitebg = false
        bgColor = Cfloat[color[1], color[2], color[3]]
        gizmoLength = 1.0
        gizmoThickness = 1.0
        aabbMin = Cfloat[aabbMin[1],aabbMin[2],aabbMin[3]]
        aabbMax = Cfloat[aabbMax[1],aabbMax[2],aabbMax[3]]
        new(Window(), whitebg, bgColor, gizmoLength, gizmoThickness,aabbMin,aabbMax)
    end
end

_Window_(self::OptionsWindow)::Window = self._window
getWindowName(self::OptionsWindow) = "Options"

function _updateScene!(app::AppDNA)
    app._scene_change = true
end
function _setBackground(self::OptionsWindow, app::AppDNA)
    if (self._whitebg[])
        glClearColor(1.0f0, 1.0f0, 1.0f0, 1.0f0)
    else
        glClearColor(self._bgColor[1], self._bgColor[2], self._bgColor[3], 1.0f0)
    end
    # ? updates so that the background changes instantly, instead of waiting for an actual scene_change
    _updateScene!(app)
end
function _setGizmo(self::OptionsWindow, app)
    gizmo::GizmoRenderer = app._opengl._renderers[GizmoRenderer]
    gizmo.ubo_size[1] = self._gizmoLength[]
    gizmo.ubo_size[2] = self._gizmoThickness[]
    _updateScene!(app)
end
function _setInfiniteAABBSize(self::OptionsWindow, app)
    app._opengl._ubo_aabb[1] = UBO_AABB(
        Vec4F(self._aabbMin[1],self._aabbMin[2],self._aabbMin[3],0.0),
        Vec4F(self._aabbMax[1],self._aabbMax[2],self._aabbMax[3],0.0)
    )
    _updateScene!(app)
end

function _render_option(name::String, subcategory::Dict{String, Any}, defaults::Dict{String, Any}, hints::Dict{String, Any}, path::String)
    if CImGui.TreeNode(name)
        options = collect(keys(subcategory))
        indices = sortperm(options)
        for i in indices
            o = options[i]
            v = subcategory[o]
            if v isa Dict
                _render_option(o, v, defaults[o], hints[o], path*"/$o")
            else
                result = input_property(o,v, hints[o])
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
    #=@cstatic selected_category::Int=-1=# begin
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
        # for a in keys(global_settings.settings)
        #     CImGui.Text(a)
        # end
    
        return
    end
    # if (CImGui.Checkbox("White background", self._whitebg))
    #     _setBackground(self, app)
    # end
    # CImGui.BeginDisabled(self._whitebg[])
    # if (CImGui.ColorEdit3("Custom background color", self._bgColor, CImGui.ImGuiColorEditFlags_NoInputs))
    #     _setBackground(self, app)
    # end
    # CImGui.EndDisabled()
    # CImGui.SameLine()
    # if (CImGui.Button("Default"))
    #     defcol = getOpenGL(app)._backgroundCol
    #     self._bgColor = Cfloat[defcol[1], defcol[2], defcol[3]]
    #     _setBackground(self, app)
    # end
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