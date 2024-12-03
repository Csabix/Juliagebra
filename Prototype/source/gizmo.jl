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
        
        red   = Vec3F(1.0,0.0,0.0)
        green = Vec3F(0.0,1.0,0.0)
        blue  = Vec3F(0.0,0.0,1.0)
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

function _getAxisClampedT(axis::Vec2F,mouse::Vec2F)::Float32
    partOne =  axis.x * mouse.x + axis.y * mouse.y
    partDiv =  axis.x * axis.x + axis.y * axis.y
    return partOne / partDiv
end

function _screen24(v::Vec4F,shrd::SharedData)::Vec2F
    x = (((v.x/v.w)))#+1)/2)*shrd._width
    y = (((v.y/v.w)))#+1)/2)*shrd._height
    return Vec2F(x,y)
end

function _getAxisClampedT(axis::Vec3F,origin::Vec3F,mouse::Vec2F,vp::Mat4T,shrd::SharedData)::Float32
    screenOrigin = vp * Vec4F(origin,1.0)
    screenOrigin = _screen24(screenOrigin,shrd)

    screenAxis = vp * Vec4F(axis,1.0)
    screenAxis = _screen24(screenAxis,shrd)

    screenMouse = Vec2F((mouse.x/shrd._width)*2-1,(mouse.y/shrd._height)*2-1)
    screenMouse = screenMouse - screenOrigin

    #println("center:($(p.x);$(p.y)) <> vector:($(v.x);$(v.y)) <> mouse:($(a.x);$(a.y))")
    t = _getAxisClampedT(screenAxis,screenMouse)
    #println("axis:($((mouse.x/shrd._width)*2-1);$((mouse.y/shrd._height)*2-1)")
    #println(t)
    #v1 = p+oldV*t
    
    #println("$(v1.x) - $(v1.y) == $(a.x) - $(a.y)")
    return t
end

function setAxisClampedT!(self::GizmoGL,selectedAxis::UInt32,shrd::SharedData,vp::Mat4T)
    mouse = Vec2F(shrd._mouseX,shrd._mouseY)
    origin = self._pos
    axis = self._idToAxis[selectedAxis] * self._scale
    t = _getAxisClampedT(axis,origin,mouse,vp,shrd)
    #println(t)
    self._pos =  (origin + axis*t)   
end

function destroy!(self::GizmoGL)
    destroy!(self._endShader)
    destroy!(self._endBuffer)
    destroy!(self._lineShader)
    destroy!(self._lineBuffer)
end
