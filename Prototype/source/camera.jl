@kwdef mutable struct Camera
    _fov::Float32 = 70
    _zNear::Float32 = 0.01
    _zFar::Float32 = 100.0
    _eye::Vec3T{Float32}= Vec3T{Float32}(0.0,-5.0,0.0)
    _at::Vec3T{Float32} = Vec3T{Float32}(0.0,0.0,0.0)
    _up::Vec3T{Float32} = Vec3T{Float32}(0.0,0.0,1.0)
    _distance::Float32 = -5.0
    _leftRightRot::Float32 = 0.0
    _upDownRot::Float32 = 0.0
end

function setRot!(self::Camera,upDownRot::Float32,leftRightRot::Float32)
    self._leftRightRot = leftRightRot % 360
    self._upDownRot = upDownRot % 360
end

addRot!(self::Camera,leftRightRot::Float32,upDownRot::Float32) = setRot!(self,self._leftRightRot + leftRightRot, self._upDownRot + upDownRot)

setAt!(self::Camera,at::Vec3T{Float32}) = self._at = at

addAt!(self::Camera,at::Vec3T{Float32}) = setAt!(self,self._at + at)

function getMat(self::Camera,width,height)
    
    dv = Vec3T{Float32}(cos(self._leftRightRot)*sin(self._upDownRot),
                        sin(self._leftRightRot)*sin(self._upDownRot) ,       
                        cos(self._upDownRot)
                        )
    
    self._eye = dv * self._distance + self._at

    p = perspective(self._fov,Float32(width/height),self._zNear,self._zFar)
    l = lookat(self._eye,self._at,self._up)
    return p * l
end