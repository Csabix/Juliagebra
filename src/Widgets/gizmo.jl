mutable struct GizmoGL <: OpenGLWidgetDNA 
    _widget::OpenGLWidget
    
    _lineShader::ShaderProgram
    _lineBuffer::TypedBufferArray
    
    _id2Axis::Vector
    
    _pos::Vec3F
    _size::Float32

    function GizmoGL()
        widget = OpenGLWidget()
        
        lineShader = ShaderProgram(
            sp("move_gizmo.vert"),
            sp("rounded_curve.geom"),
            sp("rounded_curve.frag"),
            ["VP","gizmoCenter","gizmoScale","selectedID","nanVal"])
        
        lineBuffer = TypedBufferArray{Tuple{Vec3F,Vec3F,Float32}}()

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
        
        lineIDVec = Vector{Float32}([
            Float32(1),Float32(1),NaN32,
            Float32(2),Float32(2),NaN32,
            Float32(3),Float32(3)
        ])

        id2Axis = [Vec3F(1,0,0),Vec3F(0,1,0),Vec3F(0,0,1)]

        upload!(lineBuffer,1,linePosVec,GL_STATIC_DRAW)
        upload!(lineBuffer,2,lineColVec,GL_STATIC_DRAW)
        upload!(lineBuffer,3,lineIDVec,GL_STATIC_DRAW)
        
        activate(lineShader)
        setUniform!(lineShader,"nanVal",NaN32) 

        new(widget,
            lineShader,lineBuffer,
            id2Axis,
            Vec3F(0.0,0.0,0.0),0.085)
    end
end

_OpenGLWidget_(self::GizmoGL)::OpenGLWidget = return self._widget

function draw(self::GizmoGL,vp::Mat4T,cam::Camera,gID::UInt32)
    
    gs = Float32((exp(cam._zoom)-1.0) * self._size)

    glClear(GL_DEPTH_BUFFER_BIT)
    activate(self._lineShader)
    setUniform!(self._lineShader,"VP",vp)

    setUniform!(self._lineShader,"gizmoCenter",self._pos)
    setUniform!(self._lineShader,"gizmoScale",gs)
    setUniform!(self._lineShader,"selectedID",gID)
    draw(self._lineBuffer,GL_LINE_STRIP)
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
    t = _getAxisClampedT(screenAxis-screenOrigin,screenMouse-screenOrigin)

    clampedStuff = screenOrigin + (screenAxis-screenOrigin)*t
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
    axis = self._id2Axis[selectedAxis] * gs  + origin

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
    destroy!(self._lineShader)
    destroy!(self._lineBuffer)
end
