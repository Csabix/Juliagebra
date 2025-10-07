@kwdef mutable struct Camera
    _eye::Vec3F= Vec3F(0.0,-5.0,0.0)
    _up::Vec3F = Vec3F(0.0,0.0,1.0)
    _at::Vec3F = Vec3F(0.0,0.0,0.0)

    _view::Mat4T{Float32} = mat4(Float32(1.0))
    _proj::Mat4T{Float32} = mat4(Float32(1.0))
    _view_proj::Mat4T{Float32} = mat4(Float32(1.0))

    _fov::Float32 = 50.0
    _zNear::Float32 = 0.01
    _zFar::Float32 = 999.0
    _aspect::Float32 = 1280.0f0 / 720.0f0
end

function defaultCamera()::Camera
    camera = Camera()
    camera._proj = perspective(deg2rad(camera._fov),camera._aspect,camera._zNear,camera._zFar)
    camera._view = lookat(camera._eye,camera._at,camera._up)
    return camera
end

function get_matrices(self::Camera)
    return self._view_proj, self._view, self._proj
end
# TODO getting rid of get_matrices(self::Camera,zoom)
function get_matrices(self::Camera,zoom)
    eye = -normalize(self._eye - self._at) * Float32(-(exp(zoom)-1.0))
    p = perspective(deg2rad(self._fov),self._aspect,self._zNear,self._zFar)
    l = lookat(eye,Vec3F(0,0,0),self._up)
    return p * l,l,p
end

function set_view!(self::Camera,eye::Vec3F,at::Vec3F,up::Vec3F)
    self._eye = eye
    self._at = at
    self._up = up
    self._view = lookat(self._eye,self._at,self._up)
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

abstract type CameraManipulator end

function keyboard_down!(self::CameraManipulator,ev::KeyboardEvent) end
function keyboard_up!(self::CameraManipulator,ev::KeyboardEvent) end
function mouse_motion!(self::CameraManipulator,ev::MouseMotionEvent) end
function mouse_wheel!(self::CameraManipulator,ev::MouseWheelEvent) end
function update!(self::CameraManipulator,deltaTime) end

mutable struct OrbitalCamera <: CameraManipulator
    _cam::Camera

    _u::Float32
    _v::Float32
    _zoom::Float32
    _speed::Float32

    _forward::Float32
    _right::Float32
    _up::Float32

    _tmp::Int
end

function create_orbital_manipulator(camera::Camera)::OrbitalCamera
    to_aim = camera._at - camera._eye
    distance = Float32(glm_distance(to_aim))

    u = atan(to_aim.y, to_aim.x)
    v = acos(to_aim.z / distance)

    return OrbitalCamera(camera,u,v,log(distance),Float32(0.3),Float32(0),Float32(0),Float32(0),0)
end

function mouse_motion!(self::OrbitalCamera,ev::MouseMotionEvent)
    if (ev.state & MOUSE_BUTTON_MIDDLE) == MOUSE_BUTTON_MIDDLE && (ev.xrel != 0.0 || ev.yrel != 0.0)
        du = ev.xrel / Float32(100.0)
        dv = ev.yrel / Float32(100.0)
        if (ev.mods & KEY_MOD_SHIFT) == KEY_MOD_SHIFT
            lookat = normalize(self._cam._at - self._cam._eye)
            right = normalize(cross(lookat, self._cam._up))
            up = normalize(cross(right, lookat));
            delta = up * dv + right * du
            delta *= (exp(self._zoom)-1) / Float32(15.0) # good enough for now

            self._cam._eye += delta
            self._cam._at += delta
        else
            self._u += du
            self._v = clamp(self._v + dv, Float32(0.1), Float32(3.1))
        end
    end
end

function keyboard_down!(self::OrbitalCamera,ev::KeyboardEvent)
    if ev.key == GLFW.KEY_W
        self._forward = 1.0f0
    elseif ev.key == GLFW.KEY_A
        self._right = 1.0f0
    elseif ev.key == GLFW.KEY_D
        self._right = -1.0f0
    elseif ev.key == GLFW.KEY_S
        self._forward = -1.0f0
    elseif ev.key == GLFW.KEY_Q
        self._up = -1.0f0
    elseif ev.key == GLFW.KEY_E
        self._up = 1.0f0
    end
end

function keyboard_up!(self::OrbitalCamera,ev::KeyboardEvent)
    if ev.key == GLFW.KEY_W
        self._forward = 0.0f0
    elseif ev.key == GLFW.KEY_A
        self._right = 0.0f0
    elseif ev.key == GLFW.KEY_D
        self._right = 0.0f0
    elseif ev.key == GLFW.KEY_S
        self._forward = 0.0f0
    elseif ev.key == GLFW.KEY_Q
        self._up = 0.0f0
    elseif ev.key == GLFW.KEY_E
        self._up = 0.0f0
    end
end

function mouse_wheel!(self::OrbitalCamera,ev::MouseWheelEvent)
    self._zoom = max(self._zoom + -ev.yoffset / Float32(10.0), 0.01)
end

function update!(self::OrbitalCamera,deltaTime)
    lookDirection = Vec3F(cos(self._u) * sin(self._v),
                          sin(self._u) * sin(self._v),
                          cos(self._v))

    distance = exp(self._zoom)-1.0f0
    eye = self._cam._at - distance * lookDirection;
    up = self._cam._up
    right = normalize(cross(lookDirection, up))
    forward = cross(up, right)
    d_position = (self._forward * forward + self._right * right + self._up * up) * self._speed * Float32(deltaTime) * distance

    eye += d_position
    at = self._cam._at + d_position
    set_view!(self._cam,eye,at,up)
    self._cam._view_proj = self._cam._proj * self._cam._view
end