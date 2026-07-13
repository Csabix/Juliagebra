using LinearAlgebra

@kwdef mutable struct Camera
    _eye::Vec3F= Vec3F(0.0f0,-5.0f0,1.0f0)
    _up::Vec3F = Vec3F(0.0f0,0.0f0,1.0f0)
    _at::Vec3F = Vec3F(0.0f0,0.0f0,0.0f0)

    _view::Mat4T{Float32} = mat4(1.0f0)
    _proj::Mat4T{Float32} = mat4(1.0f0)
    _view_proj::Mat4T{Float32} = mat4(1.0f0)

    _fov::Float32 = 50.0f0
    _zNear::Float32 = 0.01f0
    _zFar::Float32 = 999.0f0
    _aspect::Float32 = 1280.0f0 / 720.0f0
end

function defaultCamera()::Camera
    camera = Camera()
    camera._proj = perspective(deg2rad(camera._fov),camera._aspect,camera._zNear,camera._zFar)
    camera._view = lookat(camera._eye,camera._at,camera._up)
    return camera
end

function get_lights(self::Camera, z::Float32 = 45.0f0)
    z = deg2rad(z)
    l_cam = normalize(self._at - self._eye)
    rot = Mat3T{Float32}(
        cos(z), -sin(z), 0.0f0,
        sin(z),  cos(z), 0.0f0,
        0.0f0,  0.0f0,   1.0f0
    )
    
    return (l_cam, rot * l_cam)
end

function get_matrices(self::Camera)
    return self._view_proj, self._view, self._proj
end
function get_ray(app::AppDNA, x, y)::Vec3F
    self = app._cam
    mouse = Vec2F((x / app._glfw.width) * 2.0 - 1.0, (y / app._glfw.height) * 2.0 - 1.0)
    
    forward = normalize(self._at - self._eye)
    right = normalize(cross(forward, self._up))
    camUp = cross(right, forward)

    halfHeight = tan(deg2rad(self._fov) / 2.0) * self._zNear
    halfWidth = halfHeight * self._aspect

    nearPlaneCenter = self._eye + forward * self._zNear
    nearPlaneMouse = nearPlaneCenter - right * (mouse[1] * halfWidth) + camUp * (mouse[2] * halfHeight)
    ray = normalize(nearPlaneMouse - self._eye)

    return ray
end

function set_view!(self::Camera,eye::Vec3F,at::Vec3F,up::Vec3F)
    self._eye = eye
    self._at = at
    self._view = lookat(self._eye,self._at,up)
    return nothing
end
function set_proj!(self::Camera,fov,width,height,zn,zf)
    self._fov = Float32(fov)
    self._aspect = Float32(width)/Float32(height)
    self._zNear = Float32(zn)
    self._zFar = Float32(zf)
    self._proj = perspective(deg2rad(self._fov),self._aspect,self._zNear,self._zFar)
    return nothing
end
function set_fov!(self::Camera,fov)
	self._fov = Float32(fov)
	self._proj = perspective(deg2rad(self._fov),self._aspect,self._zNear,self._zFar)
    return nothing
end
function set_aspect!(self::Camera,width,height)
    self._aspect = Float32(width/height)
	self._proj = perspective(deg2rad(self._fov),self._aspect,self._zNear,self._zFar)
    return nothing
end
function set_znear!(self::Camera,zn)
	self._zNear = Float32(zn)
	self._proj = perspective(deg2rad(self._fov),self._aspect,self._zNear,self._zFar)
    return nothing
end
function set_zfar!(self::Camera,zf)
	self._zFar = Float32(zf)
	self._proj = perspective(deg2rad(self._fov),self._aspect,self._zNear,self._zFar)
    return nothing
end