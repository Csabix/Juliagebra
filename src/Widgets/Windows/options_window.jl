
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
    update!(getOpenGL(app), app._cam, true, UInt32(0))
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
function _setGizmo(self::OptionsWindow, app::AppDNA)
    gizmo = app._opengl._renderers.gizmo
    gizmo.ubo_size[1] = self._gizmoLength[]
    gizmo.ubo_size[2] = self._gizmoThickness[]
    _updateScene!(app)
end
function _setInfiniteAABBSize(self::OptionsWindow, app::AppDNA)
    app._opengl._ubo_aabb[1] = UBO_AABB(
        Vec4F(self._aabbMin[1],self._aabbMin[2],self._aabbMin[3],0.0),
        Vec4F(self._aabbMax[1],self._aabbMax[2],self._aabbMax[3],0.0)
    )
    _updateScene!(app)
end

function renderContent(self::OptionsWindow, app::AppDNA)
    if (CImGui.Checkbox("White background", self._whitebg))
        _setBackground(self, app)
    end

    CImGui.BeginDisabled(self._whitebg[])
    if (CImGui.ColorEdit3("Custom background color", self._bgColor, CImGui.ImGuiColorEditFlags_NoInputs))
        _setBackground(self, app)
    end
    CImGui.EndDisabled()
    
    CImGui.SameLine()
    if (CImGui.Button("Default"))
        defcol = getOpenGL(app)._backgroundCol
        self._bgColor = Cfloat[defcol[1], defcol[2], defcol[3]]
        _setBackground(self, app)
    end

    if (CImGui.CollapsingHeader("Gizmo settings"))
        if (CImGui.SliderFloat("Length", self._gizmoLength, 0.5, 2.0))
            _setGizmo(self, app)
        end
        if (CImGui.SliderFloat("Thickness", self._gizmoThickness, 0.5, 2.0))
            _setGizmo(self, app)
        end
    end

    if (CImGui.CollapsingHeader("Infinite AABB settings"))
        if (CImGui.DragFloat3("Minimum", self._aabbMin, 1.0, -100.0, -1.0))
            _setInfiniteAABBSize(self, app)
        end
        if (CImGui.DragFloat3("Maximum", self._aabbMax, 1.0, 1.0, 100.0))
            _setInfiniteAABBSize(self, app)
        end
    end
end
