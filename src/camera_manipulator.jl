abstract type CameraManipulator end

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
    _backward::Int8
    _right::Int8
    _left::Int8
    _up::Int8
    _down::Int8

    _move_state::Int8
    _capture_mouse::Bool
    _mouse_hidden::Bool
end

function create_orbital_manipulator(camera::Camera)::OrbitalCamera
    to_aim = camera.at - camera.eye
    distance = Float32(norm(to_aim))

    u = atan(to_aim.y, to_aim.x)
    v = acos(to_aim.z / distance)

    return OrbitalCamera(camera,u,v,log(distance),Float32(0.5),0,0,0,0,0,0,_ORBITAL_NONE,false,false)
end

function update!(self::OrbitalCamera,deltaTime,inputs::Inputs)
    if self._capture_mouse && !self._mouse_hidden
        disable_mouse(inputs)
        self._mouse_hidden = true
    elseif !self._capture_mouse && self._mouse_hidden
        enable_mouse(inputs)
        self._mouse_hidden = false
    end


    # Required vectors + distance
    lookDirection = Vec3F(cos(self._u) * sin(self._v),
                          sin(self._u) * sin(self._v),
                          cos(self._v))

    right = Vec3F(cos(self._u+0.5π),sin(self._u+0.5π),0.0)
    up = normalize(cross(right, -lookDirection));
    forward = normalize(cross(right, self._cam.up));

    distance = exp(self._zoom)-1.0f0
    # WASD movement
    d_position = ((self._forward + self._backward) * forward +
                  (self._right + self._left) * right +
                  (self._up + self._down) * up) * self._speed * Float32(deltaTime) * distance

    # Mouse movement
    eye, at = if self._move_state != _ORBITAL_LOOK
        eye = self._cam.at - distance * lookDirection
        at = self._cam.at
        eye, at
    else
        at = self._cam.eye + distance * lookDirection
        eye = self._cam.eye
        eye, at
    end
    
    self._cam.eye = eye + d_position
    self._cam.at = at + d_position
    self._cam.up = up
    calculate_view_matrix!(self._cam)
end

_forward(cam::OrbitalCamera)::Bool = (cam._forward = 1; true)
_backward(cam::OrbitalCamera)::Bool = (cam._backward = -1; true)
_right(cam::OrbitalCamera)::Bool = (cam._right = 1; true)
_left(cam::OrbitalCamera)::Bool = (cam._left = -1; true)
_up(cam::OrbitalCamera)::Bool = (cam._down = -1; true)
_down(cam::OrbitalCamera)::Bool = (cam._up = 1; true)

_release_forward(cam::OrbitalCamera)::Bool = (cam._forward = 0; true)
_release_backward(cam::OrbitalCamera)::Bool = (cam._backward = 0; true)
_release_right(cam::OrbitalCamera)::Bool = (cam._right = 0; true)
_release_left(cam::OrbitalCamera)::Bool = (cam._left = 0; true)
_release_up(cam::OrbitalCamera)::Bool = (cam._down = 0; true)
_release_down(cam::OrbitalCamera)::Bool = (cam._up = 0; true)

function _swap_axis(cam::OrbitalCamera)::Bool
    cam._u += Float32(π)
    cam._v = Float32(π) - cam._v
    return true
end

function _axis_z(cam::OrbitalCamera, ev::Event)::Bool
    cam._u = 3.0f0 / 2.0f0 * Float32(π)
    cam._v = (ev.key_mod & KEY_MOD_ALT) == KEY_MOD_ALT ? 0.0f0 : Float32(π)
    return true
end
function _axis_y(cam::OrbitalCamera, ev::Event)::Bool
    cam._u = (ev.key_mod & KEY_MOD_ALT) == KEY_MOD_ALT ? Float32(π) + Float32(π) / 2.0f0 : Float32(π) / 2.0f0
    cam._v = Float32(π) / 2.0f0
    return true
end
function _axis_x(cam::OrbitalCamera, ev::Event)::Bool
    cam._u = (ev.key_mod & KEY_MOD_ALT) == KEY_MOD_ALT ? 2.0f0 * Float32(π) : Float32(π)
    cam._v = Float32(π) / 2.0f0
    return true
end

function register_callbacks!(inputs::Inputs, cam::OrbitalCamera)::Nothing
    # --- KEYBOARD DOWN EVENTS ---
    register_callback!(ev -> (cam._forward = 1; true), inputs, KEY_DOWN, Cint(GLFW.KEY_W))
    register_callback!(ev -> (cam._forward = 1; true), inputs, KEY_DOWN, Cint(GLFW.KEY_UP))
    register_callback!(ev -> (cam._left = -1; true), inputs, KEY_DOWN, Cint(GLFW.KEY_A))
    register_callback!(ev -> (cam._left = -1; true), inputs, KEY_DOWN, Cint(GLFW.KEY_LEFT))
    register_callback!(ev -> (cam._right = 1; true), inputs, KEY_DOWN, Cint(GLFW.KEY_D))
    register_callback!(ev -> (cam._right = 1; true), inputs, KEY_DOWN, Cint(GLFW.KEY_RIGHT))
    register_callback!(ev -> (cam._backward = -1; true), inputs, KEY_DOWN, Cint(GLFW.KEY_S))
    register_callback!(ev -> (cam._backward = -1; true), inputs, KEY_DOWN, Cint(GLFW.KEY_DOWN))
    register_callback!(ev -> (cam._down = -1; true), inputs, KEY_DOWN, Cint(GLFW.KEY_Q))
    register_callback!(ev -> (cam._up = 1; true), inputs, KEY_DOWN, Cint(GLFW.KEY_E))
    
    register_callback!(inputs, KEY_DOWN, Cint(GLFW.KEY_KP_9)) do ev
        cam._u += Float32(π)
        cam._v = Float32(π) - cam._v
        return true
    end

    register_callback!(inputs, KEY_DOWN, Cint(GLFW.KEY_KP_7)) do ev
        cam._u = 3.0f0 / 2.0f0 * Float32(π)
        cam._v = (ev.key_mod & KEY_MOD_ALT) == KEY_MOD_ALT ? 0.0f0 : Float32(π)
        return true
    end

    register_callback!(inputs, KEY_DOWN, Cint(GLFW.KEY_KP_1)) do ev
        cam._u = (ev.key_mod & KEY_MOD_ALT) == KEY_MOD_ALT ? Float32(π) + Float32(π) / 2.0f0 : Float32(π) / 2.0f0
        cam._v = Float32(π) / 2.0f0
        return true
    end

    register_callback!(inputs, KEY_DOWN, Cint(GLFW.KEY_KP_3)) do ev
        cam._u = (ev.key_mod & KEY_MOD_ALT) == KEY_MOD_ALT ? 2.0f0 * Float32(π) : Float32(π)
        cam._v = Float32(π) / 2.0f0
        return true
    end

    register_callback!(inputs, KEY_DOWN, Cint(GLFW.KEY_KP_5)) do ev
        swap_projection!(cam._cam)
        return true
    end


    # --- KEYBOARD UP EVENTS ---
    register_callback!(ev -> (cam._forward = 0; true), inputs, KEY_UP, Cint(GLFW.KEY_W))
    register_callback!( ev -> (cam._forward = 0; true), inputs, KEY_UP, Cint(GLFW.KEY_UP))
    register_callback!( ev -> (cam._left = 0; true), inputs, KEY_UP, Cint(GLFW.KEY_A))
    register_callback!( ev -> (cam._left = 0; true), inputs, KEY_UP, Cint(GLFW.KEY_LEFT))
    register_callback!( ev -> (cam._right = 0; true), inputs, KEY_UP, Cint(GLFW.KEY_D))
    register_callback!( ev -> (cam._right = 0; true), inputs, KEY_UP, Cint(GLFW.KEY_RIGHT))
    register_callback!( ev -> (cam._backward = 0; true), inputs, KEY_UP, Cint(GLFW.KEY_S))
    register_callback!( ev -> (cam._backward = 0; true), inputs, KEY_UP, Cint(GLFW.KEY_DOWN))
    register_callback!( ev -> (cam._down = 0; true), inputs, KEY_UP, Cint(GLFW.KEY_Q))
    register_callback!( ev -> (cam._up = 0; true), inputs, KEY_UP, Cint(GLFW.KEY_E))


    # --- MOUSE BUTTON DOWN EVENTS ---
    register_callback!(inputs, MOUSE_BUTTON_DOWN, Cint(GLFW.MOUSE_BUTTON_MIDDLE)) do ev
        cam._move_state = _ORBITAL_LOOK
        cam._capture_mouse = true
        return true
    end

    register_callback!(inputs, MOUSE_BUTTON_DOWN, Cint(GLFW.MOUSE_BUTTON_LEFT)) do ev
        cam._move_state = _ORBITAL_ORBIT
        cam._capture_mouse = true
        return true
    end

    register_callback!(inputs, MOUSE_BUTTON_DOWN, Cint(GLFW.MOUSE_BUTTON_RIGHT)) do ev
        cam._move_state = _ORBITAL_PAN
        cam._capture_mouse = true
        return true
    end


    # --- MOUSE BUTTON UP EVENTS ---
    register_callback!(inputs, MOUSE_BUTTON_UP, Cint(GLFW.MOUSE_BUTTON_MIDDLE)) do ev
        cam._move_state = cam._move_state == _ORBITAL_LOOK ? _ORBITAL_NONE : cam._move_state
        cam._capture_mouse = cam._move_state != _ORBITAL_NONE
        return true
    end

    register_callback!(inputs, MOUSE_BUTTON_UP, Cint(GLFW.MOUSE_BUTTON_LEFT)) do ev
        cam._move_state = cam._move_state == _ORBITAL_ORBIT ? _ORBITAL_NONE : cam._move_state
        cam._capture_mouse = cam._move_state != _ORBITAL_NONE
        return true
    end

    register_callback!(inputs, MOUSE_BUTTON_UP, Cint(GLFW.MOUSE_BUTTON_RIGHT)) do ev
        cam._move_state = cam._move_state == _ORBITAL_PAN ? _ORBITAL_NONE : cam._move_state
        cam._capture_mouse = cam._move_state != _ORBITAL_NONE
        return true
    end


    # --- MOUSE MOVE EVENT ---
    register_callback!(inputs, MOUSE_MOVE) do ev
        du = Float32(ev.dx) / 100.0f0
        dv = -Float32(ev.dy) / 100.0f0

        if cam._move_state == _ORBITAL_ORBIT || cam._move_state == _ORBITAL_LOOK
            cam._u += du
            cam._v = clamp(cam._v + dv, 0.0f0, Float32(π))
        elseif cam._move_state == _ORBITAL_PAN
            lookat = normalize(cam._cam.at - cam._cam.eye)
            right = Vec3F(cos(cam._u + 0.5f0 * Float32(π)), sin(cam._u + 0.5f0 * Float32(π)), 0.0f0)
            up = normalize(cross(right, lookat))
            delta = up * dv + right * du
            delta *= (exp(cam._zoom) - 1.0f0) / 15.0f0

            cam._cam.eye += delta
            cam._cam.at += delta
        end
        return cam._capture_mouse
    end


    # --- MOUSE WHEEL EVENT ---
    register_callback!(inputs, MOUSE_WHEEL) do ev
        old_distance = exp(cam._zoom) - 1.0f0
        cam._zoom = max(cam._zoom + -Float32(ev.dy) / 10.0f0, 0.01f0)
        new_distance = exp(cam._zoom) - 1.0f0
        delta_distance = new_distance - old_distance

        lookat = normalize(cam._cam.at - cam._cam.eye)
        right = Vec3F(cos(cam._u + 0.5f0 * Float32(π)), sin(cam._u + 0.5f0 * Float32(π)), 0.0f0)
        up = normalize(cross(right, lookat))

        tan_half_fov_Y = tan(deg2rad(cam._cam.fov / 2.0f0))
        tan_half_fov_X = tan_half_fov_Y * cam._cam.aspect
        
        x = (Float32(ev.x) * 2.0f0 - 1.0f0)
        y = (Float32(ev.y) * 2.0f0 - 1.0f0)
        w = tan_half_fov_X * old_distance * (delta_distance / old_distance) * x
        h = tan_half_fov_Y * old_distance * (delta_distance / old_distance) * y

        offset = right * w + up * h
        cam._cam.at += offset
        cam._cam.eye += offset
        if !is_perspective(cam._cam) calculate_projection_matrix!(cam._cam) end
        return true
    end
    
    return nothing
end