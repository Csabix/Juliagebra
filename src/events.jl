using DataStructures, BitFlags, GLFW

Base.:⊻(  x::T, y::T) where {T<:BitFlag} = T(Integer(x) ⊻ Integer(y))

@bitflag MouseButtonState :: UInt8 begin
    MOUSE_BUTTON_NONE   = 0
    MOUSE_BUTTON_LEFT   = 1
    MOUSE_BUTTON_RIGHT  = 2
    MOUSE_BUTTON_MIDDLE = 4
end

@bitflag KeyModState::UInt8 begin
    KEY_MOD_NONE        = 0
    KEY_MOD_SHIFT       = 1
    KEY_MOD_CONTROL     = 2
    KEY_MOD_ALT         = 4
    KEY_MOD_SUPER       = 8
    KEY_MOD_CAPS_LOCK   = 16
    KEY_MOD_NUM_LOCK    = 32
end

mutable struct MouseState
    state::MouseButtonState
    mods::KeyModState
    x::Cdouble
    y::Cdouble
    xrel::Cdouble
    yrel::Cdouble
    xoffset::Cdouble
    yoffset::Cdouble

    xrel_total::Cdouble
    yrel_total::Cdouble
    xoffset_total::Cdouble
    yoffset_total::Cdouble

end

struct KeyboardEvent
    key::GLFW.Key
    scancode::Cint
    action::GLFW.Action
    mods::KeyModState
end

struct MouseMotionEvent
    state::MouseButtonState
    mods::KeyModState
    x::Cdouble
    y::Cdouble
    xrel::Cdouble
    yrel::Cdouble

    MouseMotionEvent(ms::MouseState) = new(ms.state,ms.mods,ms.x,ms.y,ms.xrel,ms.yrel)
end

struct MouseButtonEvent
    button::MouseButtonState
    mods::KeyModState
    x::Cdouble
    y::Cdouble
    press::Bool # Mouse down or up

    MouseButtonEvent(ms::MouseState, btn::MouseButtonState, press::Bool) = new(btn,ms.mods,ms.x,ms.y,press)
end

struct MouseWheelEvent
    xoffset::Cdouble
    yoffset::Cdouble
    x::Cdouble
    y::Cdouble
    mods::KeyModState

    MouseWheelEvent(ms::MouseState) = new(ms.xoffset,ms.yoffset,ms.x,ms.y,ms.mods)
end

global _mouse_state::MouseState = MouseState(MOUSE_BUTTON_NONE,KEY_MOD_NONE,0,0,0,0,0,0,0,0,0,0)
global _window_size::Tuple{Cint, Cint} = (0,0)

function get_mouse_position_relative()::Tuple{Cdouble, Cdouble}
    return (_mouse_state.x / Cdouble(_window_size[1]),_mouse_state.y / Cdouble(_window_size[2]))
end

function get_total_mouse_movement()::Tuple{Cdouble, Cdouble}
    return (_mouse_state.xrel_total,_mouse_state.yrel_total)
end

function get_total_mouse_scroll()::Tuple{Cdouble, Cdouble}
    return (_mouse_state.xoffset_total,_mouse_state.yoffset_total)
end

#
# Implement these functions before calling setInputEvents
#

function keyboard_event(event::KeyboardEvent, data::T)::Nothing where {T} end
function mouse_motion_event(event::MouseMotionEvent, data::T)::Nothing where {T} end
function mouse_button_event(event::MouseButtonEvent, data::T)::Nothing where {T} end
function mouse_wheel_event(event::MouseWheelEvent, data::T)::Nothing where {T} end
function window_resize_event(width::Cint, height::Cint, data::T)::Nothing where {T} end
function framebuffer_resize_event(width::Cint, height::Cint, data::T)::Nothing where {T} end

function can_capture_keys(data::T)::Bool where {T} end
function can_capture_mouse(data::T)::Bool where {T} end


function _key_callback(key::GLFW.Key, scancode::Cint, action::GLFW.Action, mods::Cint, data::T)::Nothing where {T}
    _mouse_state.mods = KeyModState(mods)
    if can_capture_keys(data)
        keyboard_event(KeyboardEvent(key,scancode,action,KeyModState(mods)), data)
    end
end

function _cursor_position_callback(xpos::Cdouble, ypos::Cdouble, data::T)::Nothing where {T}
    _mouse_state.xrel = xpos - _mouse_state.x
    _mouse_state.yrel = ypos - _mouse_state.y
    _mouse_state.xrel_total += _mouse_state.xrel
    _mouse_state.yrel_total += _mouse_state.yrel
    _mouse_state.x = xpos
    _mouse_state.y = ypos
    if can_capture_mouse(data)
        mouse_motion_event(MouseMotionEvent(_mouse_state), data)
    end
end

function _mouse_button_callback(button::GLFW.MouseButton, action::GLFW.Action, mods::Cint, data::T)::Nothing where {T}
    btn = button == GLFW.MOUSE_BUTTON_LEFT   ? MOUSE_BUTTON_LEFT   :
          button == GLFW.MOUSE_BUTTON_RIGHT  ? MOUSE_BUTTON_RIGHT  :
          button == GLFW.MOUSE_BUTTON_MIDDLE ? MOUSE_BUTTON_MIDDLE : MOUSE_BUTTON_NONE
    
    if action == GLFW.PRESS
        _mouse_state.state |= btn
    elseif action == GLFW.RELEASE
        _mouse_state.state ⊻= btn
    end

    _mouse_state.mods = KeyModState(mods)

    if can_capture_mouse(data)
        mouse_button_event(MouseButtonEvent(_mouse_state, btn, action == GLFW.PRESS), data)
    end
end

function _scroll_callback(xoffset::Cdouble, yoffset::Cdouble, data::T)::Nothing where {T}
    _mouse_state.xoffset = xoffset
    _mouse_state.yoffset = yoffset
    _mouse_state.xoffset_total += xoffset
    _mouse_state.yoffset_total += yoffset

    if can_capture_mouse(data)
        mouse_wheel_event(MouseWheelEvent(_mouse_state), data)
    end
end

function _window_size_callback(width::Cint, height::Cint, data::T)::Nothing where {T}
    global _window_size=(width,height)
    window_resize_event(width,height,data)
end
function _framebuffer_size_callback(width::Cint, height::Cint, data::T)::Nothing where {T}
    framebuffer_resize_event(width,height,data)
end

function setInputEvents(window::GLFW.Window, data::T)::Nothing where {T}
    global _window_size = values(GLFW.GetWindowSize(window))

    GLFW.SetKeyCallback(window,(_,key,scancode,action,mods) -> _key_callback(key,scancode,action,mods,data))
    GLFW.SetCursorPosCallback(window,(_,x,y) -> _cursor_position_callback(x,y,data))
    GLFW.SetMouseButtonCallback(window,(_,button,action,mods) -> _mouse_button_callback(button,action,mods,data))
    GLFW.SetScrollCallback(window,(_,xoffset,yoffset) -> _scroll_callback(xoffset,yoffset,data))
    GLFW.SetWindowSizeCallback(window,(_,width,height) -> _window_size_callback(width,height,data))
    GLFW.SetFramebufferSizeCallback(window,(_,width,height) -> _framebuffer_size_callback(width,height,data))
    return nothing
end

function poll_events()::Nothing
    _mouse_state.xrel_total = 0
    _mouse_state.yrel_total = 0
    _mouse_state.xoffset_total = 0
    _mouse_state.yoffset_total = 0
    GLFW.PollEvents()
end