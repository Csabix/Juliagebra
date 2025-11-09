mutable struct OrthoGizmoGL <: OpenGLWidgetDNA
    _widget::OpenGLWidget

    _lineShader::ShaderProgram

    function OrthoGizmoGL()
        widget = OpenGLWidget()

        lineShader = ShaderProgram(
            sp("ortho_gizmo.vert"),
            sp("rounded_curve.geom"),
            sp("rounded_curve.frag"),
            ["VP"])

        new(widget,
            lineShader)
    end
end

_OpenGLWidget_(self::OrthoGizmoGL)::OpenGLWidget = return self._widget

function draw(self::OrthoGizmoGL,cam::Camera)
    vp,_,_ = get_matrices(cam,3)
    activate(self._lineShader)
    setUniform!(self._lineShader,"VP",vp)
    glDrawArrays(GL_LINES, 0, 12)
end

function destroy!(self::OrthoGizmoGL)
    destroy!(self._lineShader)
end