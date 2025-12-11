using LinearAlgebra

@kwdef mutable struct Camera
    _eye::Vec3F= Vec3F(0.0,-5.0,1.0)
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
function mouse_motion!(self::CameraManipulator,ev::MouseMotionEvent)::Bool end
function mouse_button!(self::CameraManipulator,ev::MouseButtonEvent)::Bool end
function mouse_wheel!(self::CameraManipulator,ev::MouseWheelEvent) end
function update!(self::CameraManipulator,deltaTime) end

const _ORBITAL_NONE::Int8 = 0
const _ORBITAL_ORBIT::Int8 = 1
const _ORBITAL_PAN::Int8 = 2
const _ORBITAL_LOOK::Int8 = 3

mutable struct OrbitalCamera <: CameraManipulator
    _cam::Camera

    _u::Float32
    _v::Float32
    _zoom::Float32
    _speed::Float32

    _forward::Int8
    _bacward::Int8
    _right::Int8
    _left::Int8
    _up::Int8
    _down::Int8

    _move_state::Int8
    _capture_mouse::Bool
    _mouse_hidden::Bool
end

function create_orbital_manipulator(camera::Camera)::OrbitalCamera
    to_aim = camera._at - camera._eye
    distance = Float32(norm(to_aim))

    u = atan(to_aim.y, to_aim.x)
    v = acos(to_aim.z / distance)

    return OrbitalCamera(camera,u,v,log(distance),Float32(0.5),0,0,0,0,0,0,_ORBITAL_NONE,false,false)
end

function mouse_motion!(self::OrbitalCamera,ev::MouseMotionEvent)::Bool
    du = ev.xrel / Float32(100.0)
    dv = ev.yrel / Float32(100.0)

    if self._move_state == _ORBITAL_ORBIT || self._move_state == _ORBITAL_LOOK
        self._u += du
        self._v = clamp(self._v + dv, Float32(0.1), Float32(3.1))
    elseif self._move_state == _ORBITAL_PAN
        lookat = normalize(self._cam._at - self._cam._eye)
        right = normalize(cross(lookat, self._cam._up))
        up = normalize(cross(right, lookat));
        delta = up * dv + right * du
        delta *= (exp(self._zoom)-1) / Float32(15.0) # good enough for now

        self._cam._eye += delta
        self._cam._at += delta
    end
    return self._capture_mouse
end

function mouse_button!(self::OrbitalCamera,ev::MouseButtonEvent)::Bool
    if ev.button == MOUSE_BUTTON_MIDDLE
        if ev.press
            self._move_state = _ORBITAL_LOOK
        else
            self._move_state = self._move_state ==_ORBITAL_LOOK ? _ORBITAL_NONE : self._move_state
        end
    elseif ev.press
        if ev.button == MOUSE_BUTTON_LEFT
            self._move_state = _ORBITAL_ORBIT
        elseif ev.button == MOUSE_BUTTON_RIGHT
            self._move_state = _ORBITAL_PAN
        end
    elseif !ev.press
        if ev.button == MOUSE_BUTTON_LEFT
            self._move_state = (self._move_state ==_ORBITAL_ORBIT) ? _ORBITAL_NONE : self._move_state
        elseif ev.button == MOUSE_BUTTON_RIGHT
            self._move_state = (self._move_state ==_ORBITAL_PAN) ? _ORBITAL_NONE : self._move_state
        end
    end
    self._capture_mouse = self._move_state != _ORBITAL_NONE
    return self._capture_mouse
end

function keyboard_down!(self::OrbitalCamera,ev::KeyboardEvent)
    if ev.key == GLFW.KEY_W || ev.key == GLFW.KEY_UP
        self._forward = 1
    elseif ev.key == GLFW.KEY_A || ev.key == GLFW.KEY_LEFT
        self._left = 1
    elseif ev.key == GLFW.KEY_D || ev.key == GLFW.KEY_RIGHT
        self._right = -1
    elseif ev.key == GLFW.KEY_S || ev.key == GLFW.KEY_DOWN
        self._bacward = -1
    elseif ev.key == GLFW.KEY_Q
        self._down = -1
    elseif ev.key == GLFW.KEY_E
        self._up = 1
    end
end

function keyboard_up!(self::OrbitalCamera,ev::KeyboardEvent)
    if ev.key == GLFW.KEY_W || ev.key == GLFW.KEY_UP
        self._forward = 0
    elseif ev.key == GLFW.KEY_A || ev.key == GLFW.KEY_LEFT
        self._left = 0
    elseif ev.key == GLFW.KEY_D || ev.key == GLFW.KEY_RIGHT
        self._right = 0
    elseif ev.key == GLFW.KEY_S || ev.key == GLFW.KEY_DOWN
        self._bacward = 0
    elseif ev.key == GLFW.KEY_Q
        self._down = 0
    elseif ev.key == GLFW.KEY_E
        self._up = 0
    end
end

function mouse_wheel!(self::OrbitalCamera,ev::MouseWheelEvent)
    old_distance = exp(self._zoom)-1.0f0
    self._zoom = max(self._zoom + -ev.yoffset / Float32(10.0), 0.01)
    new_distance = exp(self._zoom)-1.0f0
    delta_distance = new_distance - old_distance

    lookat = normalize(self._cam._at - self._cam._eye)
    right = normalize(cross(lookat, self._cam._up))
    up = normalize(cross(right, lookat));

    tan_half_fov_Y = tan(deg2rad(self._cam._fov / 2.0f0))
    tan_half_fov_X = tan_half_fov_Y * self._cam._aspect
    
    
    x,y = get_mouse_position_relative()
    x = (x * 2f0 - 1f0)
    y = (y * 2f0 - 1f0)
    w = tan_half_fov_X * old_distance * (delta_distance / old_distance) * x
    h = tan_half_fov_Y * old_distance * (delta_distance / old_distance) * y

    offset = right * w + up * h
    self._cam._at += offset
    self._cam._eye += offset
end


function update!(self::OrbitalCamera,deltaTime,glfw::GLFWData)
    if self._capture_mouse && !self._mouse_hidden
        disable_mouse(glfw)
        self._mouse_hidden = true
    elseif !self._capture_mouse && self._mouse_hidden
        enable_mouse(glfw)
        self._mouse_hidden = false
    end


    # Required vectors + distance
    lookDirection = Vec3F(cos(self._u) * sin(self._v),
                          sin(self._u) * sin(self._v),
                          cos(self._v))
                          
    up = self._cam._up
    right = normalize(cross(lookDirection, up))
    forward = cross(up, right)

    distance = exp(self._zoom)-1.0f0
    # WASD movement
    d_position = ((self._forward + self._bacward) * forward +
                  (self._right + self._left) * right +
                  (self._up + self._down) * up) * self._speed * Float32(deltaTime) * distance

    # Mouse movement
    eye, at = if self._move_state != _ORBITAL_LOOK
        eye = self._cam._at - distance * lookDirection
        at = self._cam._at
        eye, at
    else
        at = self._cam._eye + distance * lookDirection
        eye = self._cam._eye
        eye, at
    end
    
    set_view!(self._cam,eye + d_position,at + d_position,up)
    self._cam._view_proj = self._cam._proj * self._cam._view
end

mutable struct FPS_Camera <: CameraManipulator
    _cam::Camera
end