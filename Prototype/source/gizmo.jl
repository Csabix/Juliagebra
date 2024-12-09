mutable struct GizmoGL 
    # ! Shaders:
    _endShader::ShaderProgram
    _lineShader::ShaderProgram
    _debugShader::ShaderProgram

    # ! BufferArrays:
    _endBuffer::BufferArray
    _lineBuffer::BufferArray
    _debugBuffer::BufferArray
    _debugLineBuffer::BufferArray

    _pos::Vec3F
    _size::Float32

    _red::Vec3F
    _green::Vec3F
    _blue::Vec3F
    
    _idToAxis::Vector
    _debugVec::Vector
    _debugLineVec::Vector


    function GizmoGL()
        
        red   = Vec3F(1.0,0.0,0.0)
        green = Vec3F(0.0,1.0,0.0)
        blue  = Vec3F(0.0,0.0,1.0)
        pos   = Vec3F(0.0,0.0,0.0)

        myPath = (@__FILE__)
        myPath = myPath[1:(length(myPath) - length("gizmo.jl"))]
        
        endShader = ShaderProgram(
            myPath * "Shaders/gizmo_end.vert",
            myPath * "Shaders/gizmo_end.frag",
            ["VP","gizmoCenter","gizmoScale"])

        lineShader = ShaderProgram(
            myPath * "Shaders/gizmo_line.vert",
            myPath * "Shaders/gizmo_line.frag",
            ["VP","gizmoCenter","gizmoScale"])
        
        debugShader = ShaderProgram(
            myPath * "Shaders/gizmo_debug.vert",
            myPath * "Shaders/gizmo_debug.frag"
            ,["line"])

        debugVecs = Vector{Vec2F}([
            Vec2F(0.0,0.0),
            Vec2F(0.0,0.0),
            Vec2F(0.0,0.0),
            Vec2F(0.0,0.0)
        ])

        debugLineVecs = Vector{Vec2F}([
            Vec2F(0.0,0.0),
            Vec2F(0.0,0.0),
            Vec2F(0.0,0.0),
            Vec2F(0.0,0.0)
        ])

        debugBuffer = BufferArray(
            Vec2F,
            GL_DYNAMIC_DRAW,
            debugVecs
        )

        debugLineBuffer = BufferArray(
            Vec2F,
            GL_DYNAMIC_DRAW,
            debugLineVecs
        )

        endVecs = Vector{Vec3F}([
            red,
            green,
            blue])

        endBuffer = BufferArray(
            Vec3F,
            GL_STATIC_DRAW,
            endVecs)

        lineVecs = Vector{Vec3F}([
            pos,red,
            pos,green,
            pos,blue])

        lineBuffer = BufferArray(
            Vec3F,
            GL_STATIC_DRAW,
            lineVecs)
        
        
        size = 0.1

        glLineWidth(6.0)

        new(endShader,lineShader,debugShader,
            endBuffer,lineBuffer,debugBuffer,debugLineBuffer,
            pos,size,
            red,green,blue,
            [red,green,blue],
            debugVecs,debugLineVecs)
    end
end

function draw(self::GizmoGL,vp::Mat4T,camPos::Vec3F)
    
    gs = norm(camPos - self._pos) * self._size
    

    # TODO: Optimize glClears

    glClear(GL_DEPTH_BUFFER_BIT)

    activate(self._lineShader)
    setUniform!(self._lineShader,"VP",vp)  
    setUniform!(self._lineShader,"gizmoCenter",self._pos)
    setUniform!(self._lineShader,"gizmoScale",gs)
    draw(self._lineBuffer,GL_LINES)

    glClear(GL_DEPTH_BUFFER_BIT)

    activate(self._endShader)
    setUniform!(self._endShader,"VP",vp)
    setUniform!(self._endShader,"gizmoCenter",self._pos)
    setUniform!(self._endShader,"gizmoScale",gs)
    draw(self._endBuffer,GL_POINTS)

    activate(self._debugShader)
    
    draw(self._debugBuffer,GL_POINTS)
    
    setUniform!(self._debugShader,"line",Float32(1.0))
    draw(self._debugLineBuffer,GL_LINES)
    setUniform!(self._debugShader,"line",Float32(0.0))



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

function _getAxisClampedT(self::GizmoGL,axis::Vec3F,origin::Vec3F,mouse::Vec2F,vp::Mat4T,shrd::SharedData)::Float32
    screenOrigin = vp * Vec4F(origin,1.0)
    screenOrigin = _screen24(screenOrigin,shrd)

    screenAxis = vp * Vec4F(axis,1.0)
    screenAxis = _screen24(screenAxis,shrd)

    screenMouse = Vec2F((mouse.x/shrd._width)*2-1,(mouse.y/shrd._height)*2-1)
    screenMouse = screenMouse

    t = _getAxisClampedT(screenAxis-screenOrigin,screenMouse-screenOrigin)

    clampedStuff = screenOrigin + (screenAxis-screenOrigin)*t

    self._debugVec[1] = screenOrigin
    self._debugVec[2] = screenAxis
    self._debugVec[3] = screenMouse
    self._debugVec[4] = clampedStuff

    upload!(self._debugBuffer,self._debugVec)

    self._debugLineVec[1] = screenAxis
    self._debugLineVec[2] = clampedStuff
    self._debugLineVec[3] = clampedStuff
    self._debugLineVec[4] = screenMouse

    upload!(self._debugLineBuffer,self._debugLineVec)

    return t
end

function setAxisClampedT!(self::GizmoGL,selectedAxis::Int32,shrd::SharedData,vp::Mat4T,v::Mat4T,p::Mat4T)
    mouse = Vec2F(shrd._mouseX,shrd._mouseY)
    origin = self._pos
    axis = self._idToAxis[selectedAxis] + origin
    t = _getAxisClampedT(self,axis,origin,mouse,vp,shrd)
    self._pos =  (origin + (axis-origin)*t)   
end

function destroy!(self::GizmoGL)
    destroy!(self._endShader)
    destroy!(self._endBuffer)
    destroy!(self._lineShader)
    destroy!(self._lineBuffer)
    destroy!(self._debugShader)
    destroy!(self._debugBuffer)
    destroy!(self._debugLineBuffer)
end
