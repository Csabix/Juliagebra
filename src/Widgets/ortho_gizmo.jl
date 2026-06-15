mutable struct OrthoGizmoGL <: OpenGLWidgetDNA
    _widget::OpenGLWidget

    _lineShader::ShaderProgram

    _empty_vao::VertexArray

    function OrthoGizmoGL()
        widget = OpenGLWidget()

        lineShader = ShaderProgram(["ortho_gizmo.vert","gizmo.geom","gizmo.frag"],["VP","WH"])

        empty_vao::VertexArray = VertexArray()

        new(widget,
            lineShader,
            empty_vao)
    end
end

_OpenGLWidget_(self::OrthoGizmoGL)::OpenGLWidget = return self._widget

function draw(self::OrthoGizmoGL,cam::Camera,wh::Vec2F)
    #vp,_,_ = get_matrices(cam,3)
    #activate(self._empty_vao)
    #activate(self._lineShader)
    #uniform(self._lineShader,"VP",vp)
    #uniform(self._lineShader,"WH",wh)
    #glDrawArrays(GL_LINES, 0, 12)
end

function destroy!(self::OrthoGizmoGL)
    destroy!(self._lineShader)
end