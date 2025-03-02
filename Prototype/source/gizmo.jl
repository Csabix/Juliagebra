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
        
        endShader = ShaderProgram(
            sp("gizmo_end.vert"),
            sp("gizmo_end.frag"),
            ["VP","gizmoCenter","gizmoScale"])

        lineShader = ShaderProgram(
            sp("gizmo_line.vert"),
            sp("gizmo_line.frag"),
            ["VP","gizmoCenter","gizmoScale","selectedID"])
        
        debugShader = ShaderProgram(
            sp("gizmo_debug.vert"),
            sp("gizmo_debug.frag")
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
            pos,-red,
            pos,green,
            pos,-green,
            pos,blue,
            pos,-blue])

        lineBuffer = BufferArray(
            Vec3F,
            GL_STATIC_DRAW,
            lineVecs)
        
        
        size = 0.1

        glLineWidth(15.0)

        new(endShader,lineShader,debugShader,
            endBuffer,lineBuffer,debugBuffer,debugLineBuffer,
            pos,size,
            red,green,blue,
            [red,green,blue],
            debugVecs,debugLineVecs)
    end
end

function draw(self::GizmoGL,vp::Mat4T,camPos::Vec3F,gID::UInt32)
    
    gs = norm(camPos - self._pos) * self._size
    
    glClear(GL_DEPTH_BUFFER_BIT)

    activate(self._lineShader)
    setUniform!(self._lineShader,"VP",vp)  
    setUniform!(self._lineShader,"gizmoCenter",self._pos)
    setUniform!(self._lineShader,"gizmoScale",gs)
    setUniform!(self._lineShader,"selectedID",gID)
    draw(self._lineBuffer,GL_LINES)

    #glClear(GL_DEPTH_BUFFER_BIT)

    #activate(self._endShader)
    #setUniform!(self._endShader,"VP",vp)
    #setUniform!(self._endShader,"gizmoCenter",self._pos)
    #setUniform!(self._endShader,"gizmoScale",gs)
    #draw(self._endBuffer,GL_POINTS)

    #activate(self._debugShader)
    #
    #draw(self._debugBuffer,GL_POINTS)
    #
    #setUniform!(self._debugShader,"line",Float32(1.0))
    #draw(self._debugLineBuffer,GL_LINES)
    #setUniform!(self._debugShader,"line",Float32(0.0))

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

function screenVecs(origin,axis,mouse,shrd,vp)
    screenOrigin = vp * Vec4F(origin,1.0)
    screenOrigin = _screen24(screenOrigin,shrd)

    screenAxis = vp * Vec4F(axis,1.0)
    screenAxis = _screen24(screenAxis,shrd)

    screenMouse = Vec2F((mouse.x/shrd._width)*2-1,(mouse.y/shrd._height)*2-1)
    screenMouse = screenMouse

    return (screenOrigin,screenAxis,screenMouse)
end

function _getAxisClampedT(self::GizmoGL,axis::Vec3F,origin::Vec3F,mouse::Vec2F,vp::Mat4T,shrd::SharedData)::Float32
    
    screenOrigin,screenAxis,screenMouse = screenVecs(origin,axis,mouse,shrd,vp)
    
    #screenOrigin = vp * Vec4F(origin,1.0)
    #screenOrigin = _screen24(screenOrigin,shrd)
    #
    #screenAxis = vp * Vec4F(axis,1.0)
    #screenAxis = _screen24(screenAxis,shrd)
    #
    #screenMouse = Vec2F((mouse.x/shrd._width)*2-1,(mouse.y/shrd._height)*2-1)
    #screenMouse = screenMouse

    t = _getAxisClampedT(screenAxis-screenOrigin,screenMouse-screenOrigin)

    clampedStuff = screenOrigin + (screenAxis-screenOrigin)*t

    #
    #self._debugVec[1] = screenOrigin
    #self._debugVec[2] = screenAxis
    #self._debugVec[3] = screenMouse
    #self._debugVec[4] = clampedStuff
    #
    #upload!(self._debugBuffer,self._debugVec)
    #
    #self._debugLineVec[1] = screenAxis
    #self._debugLineVec[2] = clampedStuff
    #self._debugLineVec[3] = clampedStuff
    #self._debugLineVec[4] = screenMouse
    #
    #upload!(self._debugLineBuffer,self._debugLineVec)
    #
    return t
end

function planeIntersect(P0::Vec3F,v::Vec3F,Q::Vec3F,i::Vec3F,j::Vec3F)::Vec3F
    p = P0 - Q
    m = Mat3T{Float32}(
        -v.x, i.x, j.x,
        -v.y, i.y, j.y,
        -v.z, i.z, j.z
    )
    mInv = inv(m)

    return mInv * p
end

function getAxisVecs(self,shrd,cam,selectedAxis)
    mouse = Vec2F(shrd._mouseX,shrd._mouseY)
    origin = self._pos
    gs = norm(cam._eye - self._pos) * self._size
    axis = self._idToAxis[selectedAxis] * gs  + origin

    return (mouse,origin,gs,axis)
end

function setAxisClampedT!(self::GizmoGL,selectedAxis::UInt32,shrd::SharedData,vp::Mat4T,cam::Camera,v,p)
    
    mouse,origin,gs,axis = getAxisVecs(self,shrd,cam,selectedAxis)
    
    t = _getAxisClampedT(self,axis,origin,mouse,vp,shrd)
    
    oldPos = self._pos
    self._pos = (origin + (axis-origin)*t) 

    mouse,origin,gs,axis = getAxisVecs(self,shrd,cam,selectedAxis)
    screenOrigin,screenAxis,screenMouse = screenVecs(origin,axis,mouse,shrd,vp)
    
    if (norm(screenAxis-screenOrigin) < 0.01)
        self._pos = oldPos
    end     
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
