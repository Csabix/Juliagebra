@kwdef mutable struct Camera
    _fov::Float32 = 50.0
    _zNear::Float32 = 0.01
    _zFar::Float32 = 999.0
    _eye::Vec3F= Vec3F(0.0,-5.0,0.0)
    _at::Vec3F = Vec3F(0.0,0.0,0.0)
    _up::Vec3F = Vec3F(0.0,0.0,1.0)
    _zoom::Float32 = 3.0
    _leftRightRot::Float32 = 270.0
    _upDownRot::Float32 = 90.0
    _rotateSensitivity::Float32 = 120.0
    _zoomSensitivity::Float32 = 22.0
    _moveSpeed::Float32 = 0.115
    _x::Float32 = 0.0
    _y::Float32 = 0.0
    _z::Float32 = 0.0
end

function setRot!(self::Camera,leftRightRot::Float32,upDownRot::Float32)
    self._leftRightRot = (leftRightRot + 360.0) % 360.0
    self._upDownRot = clamp(upDownRot,0.0001,179.9999)
end

function addRot!(self::Camera,leftRightRot::Float32,upDownRot::Float32)
    lr = self._leftRightRot + leftRightRot
    ud = self._upDownRot + upDownRot
    setRot!(self,lr,ud)
end

function sensitivityRot!(self::Camera,leftRightRot::Float32,upDownRot::Float32,deltaTime::Float32)
    lr = leftRightRot*self._rotateSensitivity*deltaTime
    ud = upDownRot*self._rotateSensitivity*deltaTime
    addRot!(self,lr,ud)                                                                             
end

setZoom!(self::Camera,zoom::Float32) = self._zoom = clamp(zoom,0,100)
    
addZoom!(self::Camera,zoom::Float32) = setZoom!(self,self._zoom + zoom)

function sensitivityZoom(self::Camera,zoom::Float32,deltaTime::Float32)
    addZoom!(self,zoom*self._zoomSensitivity*deltaTime)
end

setAt!(self::Camera,at::Vec3F) = self._at = at

addAt!(self::Camera,v::Vec3F) = setAt!(self,self._at + v)

function moveAt!(self::Camera,x::Float32,y::Float32,z::Float32,deltaTime::Float32)
    
    to = normalize(-self._eye + self._at)
    side = normalize(cross(to,self._up))
    up = cross(to,side)
    
    to *=x
    side*=y
    up *=z

    v = to + side + up

    addAt!(self,v*self._moveSpeed*exp(self._zoom)*deltaTime)
end

function setAts!(self::Camera,x::Float32,y::Float32,z::Float32,deltaTime::Float32)
    
    to = normalize(-self._eye + self._at)
    side = normalize(cross(to,self._up))
    up = cross(to,side)
    
    v = to + side + up

    addAt!(self,v*self._moveSpeed*exp(self._zoom)*deltaTime)
end

function getMat(self::Camera,width,height)
    
    lr = deg2rad(self._leftRightRot)
    ud = deg2rad(self._upDownRot)

    x = cos(lr)*sin(ud)
    y = sin(lr)*sin(ud)
    z = cos(ud)
    dv = Vec3F(x,y,z)       
                        
    self._eye = dv * -(exp(self._zoom)-1.0) + self._at

    p = perspective(deg2rad(self._fov),Float32(width/height),self._zNear,self._zFar)
    l = lookat(self._eye,self._at,self._up)
    return p * l,l,p
end

function getMat(self::Camera,width,height,zoom)
    
    lr = deg2rad(self._leftRightRot)
    ud = deg2rad(self._upDownRot)

    x = cos(lr)*sin(ud)
    y = sin(lr)*sin(ud)
    z = cos(ud)
    dv = Vec3F(x,y,z)       
                        
    self._eye = dv * -(exp(zoom)-1.0)

    p = perspective(deg2rad(self._fov),Float32(width/height),self._zNear,self._zFar)
    l = lookat(self._eye,Vec3F(0,0,0),self._up)
    return p * l,l,p
end