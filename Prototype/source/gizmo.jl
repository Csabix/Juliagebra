mutable struct GizmoGL 
    # ! Shaders:
    _endShader::ShaderProgram
    _lineShader::ShaderProgram
    
    # ! BufferArrays:
    _endBuffer::BufferArray
    _lineBuffer::BufferArray
    
    _pos::Vec3F
    _size::Float32
    _scale::Float32

    _red::Vec3F
    _green::Vec3F
    _blue::Vec3F
    
    _idToAxis::Vector

    function GizmoGL()
        
        red   = Vec3F(0.0,0.0,1.0)
        green = Vec3F(0.0,1.0,0.0)
        blue  = Vec3F(1.0,0.0,0.0)
        pos = Vec3F(0.0,0.0,0.0)

        myPath = (@__FILE__)
        myPath = myPath[1:(length(myPath) - length("gizmo.jl"))]
        
        endShader = ShaderProgram(
            myPath * "Shaders/gizmo_end.vert",
            myPath * "Shaders/gizmo_end.frag",
            ["VP","scaleFactor","gizmoCenter"])

        lineShader = ShaderProgram(
            myPath * "Shaders/gizmo_line.vert",
            myPath * "Shaders/gizmo_line.frag",
            ["VP","scaleFactor","gizmoCenter"])
        
        endVecs = Vector{Vec3F}([
            red,
            green,
            blue])

        endBuffer = BufferArray(
            Vec3F,
            GL_STATIC_DRAW,
            endVecs)

        lineVecs = Vector{Vec3F}([
            Vec3F(0.0,0.0,0.0),red,
            Vec3F(0.0,0.0,0.0),green,
            Vec3F(0.0,0.0,0.0),blue])

        lineBuffer = BufferArray(
            Vec3F,
            GL_STATIC_DRAW,
            lineVecs)
        
        
        size = 0.1
        scale = 1.0

        glLineWidth(6.0)

        new(endShader,lineShader,
            endBuffer,lineBuffer,
            pos,size,scale,
            red,green,blue,
            [red,green,blue])
    end
end

function draw(self::GizmoGL,vp::Mat4T,camPos::Vec3F)
    
    scaleFactor = norm(camPos - self._pos)
    scaleFactor *= self._size
    self._scale = scaleFactor

    # TODO: Optimize glClears

    glClear(GL_DEPTH_BUFFER_BIT)

    activate(self._lineShader)
    setUniform!(self._lineShader,"VP",vp)  
    setUniform!(self._lineShader,"scaleFactor",scaleFactor)
    setUniform!(self._lineShader,"gizmoCenter",self._pos)
    draw(self._lineBuffer,GL_LINES)

    glClear(GL_DEPTH_BUFFER_BIT)

    activate(self._endShader)
    setUniform!(self._endShader,"VP",vp)
    setUniform!(self._endShader,"scaleFactor",scaleFactor)
    setUniform!(self._endShader,"gizmoCenter",self._pos)
    draw(self._endBuffer,GL_POINTS)

end

function _getAxisClampedT(v::Vec2F,p::Vec2F,a::Vec2F)::Float32
    partOne =  v.x*p.x + v.y*p.y
    partTwo = -a.x*v.x - a.y*v.y
    partDiv = -(v.x*v.x) - (v.y*v.y)
    #println("$(partOne) - $(partTwo) - $(partDiv)")
    return (partOne + partTwo) / partDiv
end

function _screen24(v::Vec4F,shrd::SharedData)::Vec2F
    x = (((v.x/v.w)+1)/2)*shrd._width
    y = (((v.y/v.w)+1)/2)*shrd._height
    return Vec2F(x,y)
end

function _getAxisClampedT(axis::Vec3F,pos::Vec3F,a::Vec2F,vp::Mat4T,shrd::SharedData)::Float32
    oldV = vp * Vec4F(axis.x,axis.y,axis.z,1.0)
    oldV = _screen24(oldV,shrd)
    p = vp * Vec4F(pos.x,pos.y,pos.z,1.0)
    p = _screen24(p,shrd)
    v = -p + oldV
    #println("center:($(p.x);$(p.y)) <> vector:($(v.x);$(v.y)) <> mouse:($(a.x);$(a.y))")
    t = _getAxisClampedT(v,p,a)
    #println(t)
    #v1 = p+oldV*t
    
    #println("$(v1.x) - $(v1.y) == $(a.x) - $(a.y)")
    return t
end

function setAxisClampedT!(self::GizmoGL,selectedAxis::UInt32,shrd::SharedData,vp::Mat4T)
    a = Vec2F(shrd._mouseX,shrd._mouseY)
    p = self._pos
    v = self._idToAxis[selectedAxis] * self._scale
    t = _getAxisClampedT(v,p,a,vp,shrd)
    
    self._pos =  (p + v*t)    
end

function destroy!(self::GizmoGL)
    destroy!(self._endShader)
    destroy!(self._endBuffer)
    destroy!(self._lineShader)
    destroy!(self._lineBuffer)
end
