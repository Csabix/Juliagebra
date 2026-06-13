mutable struct OrthoGizmoGL <: OpenGLWidgetDNA
    _widget::OpenGLWidget

    _gizmoShader::Pipeline

    _empty_vao::VertexArray

    function OrthoGizmoGL(loader::PipelineLoader, content_scale::Float32)
        widget = OpenGLWidget()

        gizmoShader = create_graphics_pipeline!(loader;
            vert = (spv"renderers/gizmo/gizmo.vert",Tuple{GLuint,GLuint}[(0,1),(1,reinterpret(GLuint,content_scale))]),
            geom = (spv"renderers/gizmo/gizmo.geom",Tuple{GLuint,GLuint}[(1,reinterpret(GLuint,content_scale))]),
            frag = spv"renderers/gizmo/gizmo.frag"
        )

        empty_vao::VertexArray = VertexArray()

        new(widget,
            gizmoShader,
            empty_vao)
    end
end

_OpenGLWidget_(self::OrthoGizmoGL)::OpenGLWidget = return self._widget

function draw(self::OrthoGizmoGL)
    activate(self._empty_vao)
    activate(self._gizmoShader)
    glDrawArrays(GL_LINES, 0, 12)
end

function destroy!(self::OrthoGizmoGL)
end