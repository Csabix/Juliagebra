mutable struct OrthoGizmoGL <: OpenGLWidgetDNA
    _widget::OpenGLWidget

    _lineShader::ShaderProgram

    function OrthoGizmoGL()
        widget = OpenGLWidget()

        lineShader = ShaderProgram(
            sp("ortho_gizmo.vert"),
            sp("gizmo.geom"),
            sp("gizmo.frag"),
            ["VP","WH"])

        new(widget,
            lineShader)
    end
end

_OpenGLWidget_(self::OrthoGizmoGL)::OpenGLWidget = return self._widget

function draw(self::OrthoGizmoGL,cam::Camera,wh::Vec2F)
    vp,_,_ = get_matrices(cam,3)
    activate(self._lineShader)
    setUniform!(self._lineShader,"VP",vp)
    setUniform!(self._lineShader,"WH",wh)
    glDrawArrays(GL_LINES, 0, 12)
end

function destroy!(self::OrthoGizmoGL)
    destroy!(self._lineShader)
end