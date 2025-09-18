mutable struct OrthoGizmoGL <: OpenGLWidgetDNA
    _widget::OpenGLWidget

    _lineShader::ShaderProgram
    _lineBuffer::TypedBufferArray
    
    _linePosVec::Vector{Vec3F}
    _lineColVec::Vector{Vec3F}

    #_pointShader::ShaderProgram
    #_pointBuffer::TypedBuffer
    #_pointVec::Vector
    
    function OrthoGizmoGL()
        widget = OpenGLWidget()

        lineShader = ShaderProgram(
            sp("ortho_gizmo.vert"),
            sp("rounded_curve.geom"),
            sp("rounded_curve.frag"),
            ["VP"])

        lineBuffer = TypedBufferArray{Tuple{Vec3F,Vec3F}}()
        
        linePosVec = Vector{Vec3F}([
            Vec3F(1,0,0),Vec3F(-1,0,0),Vec3FNan,
            Vec3F(0,1,0),Vec3F(0,-1,0),Vec3FNan,
            Vec3F(0,0,1),Vec3F(0,0,-1)
        ])
        
        lineColVec = Vector{Vec3F}([
            Vec3F(1,0,0),Vec3F(1,0,0),Vec3FNan,
            Vec3F(0,1,0),Vec3F(0,1,0),Vec3FNan,
            Vec3F(0,0,1),Vec3F(0,0,1)
        ])

        upload!(lineBuffer,1,linePosVec,GL_STATIC_DRAW)
        upload!(lineBuffer,2,lineColVec,GL_STATIC_DRAW)

        new(widget,
            lineShader,lineBuffer,
            linePosVec,lineColVec)
    end
end

function draw(self::OrthoGizmoGL,cam::Camera,width,height)
    vp,v,p = getMat(cam,width,height,3)
    activate(self._lineShader)
    setUniform!(self._lineShader,"VP",vp)
    draw(self._lineBuffer,GL_LINE_STRIP)
end

function destroy!(self::OrthoGizmoGL)
    destroy!(self._lineShader)
    destroy!(self._lineBuffer)
end