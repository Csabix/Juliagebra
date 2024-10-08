module Events

using DataStructures, BitFlags, GLFW

Base.:⊻(  x::T, y::T) where {T<:BitFlag} = T(Integer(x) ⊻ Integer(y))
Base.:xor(x::T, y::T) where {T<:BitFlag} = T(xor(Integer(x),Integer(y)))

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

abstract type Event end

struct MouseMotionEvent <: Event
    mouseX    :: Int32
    mouseY    :: Int32
    xrel      :: Int32
    yrel      :: Int32
    mouse_btn :: MouseButtonState
    key_mods  :: KeyModState
end
Base.string(e::MouseMotionEvent) = "MME"

struct MouseDownEvent <: Event
    glfw_key  :: GLFW.MouseButton
    mouseX    :: Int32
    mouseY    :: Int32
    mouse_btn :: MouseButtonState
    key_mods  :: KeyModState
end
Base.string(e::MouseDownEvent) = "MDE"

struct MouseUpEvent <: Event
    glfw_key  :: GLFW.MouseButton
    mouseX    :: Int32
    mouseY    :: Int32
    mouse_btn :: MouseButtonState
    key_mods  :: KeyModState
end
Base.string(e::MouseUpEvent) = "MUE"

struct MouseWheelEvent <: Event
    wheelX    :: Int32      # horizontal scroll
    wheelY    :: Int32      # vertical scroll
    mouseX    :: Int32
    mouseY    :: Int32
    mouse_btn :: MouseButtonState
    key_mods  :: KeyModState
end
Base.string(e::MouseWheelEvent) = "MWE"

struct KeyboardDownEvent <: Event
    glfw_key  :: GLFW.Key
    glfw_scan :: Cint
    glfw_mods :: Cint
    mouse_btn :: MouseButtonState
    key_mods  :: KeyModState
end
Base.string(e::KeyboardDownEvent) = "KDE"

struct KeyboardUpEvent <: Event
    glfw_key  :: GLFW.Key
    glfw_scan :: Cint
    glfw_mods :: Cint
    mouse_btn :: MouseButtonState
    key_mods  :: KeyModState
end
Base.string(e::KeyboardUpEvent) = "KUE"

struct ResizeEvent <: Event
    width     :: Int32
    height    :: Int32
    mouse_btn :: MouseButtonState
    key_mods  :: KeyModState
end
Base.string(e::ResizeEvent) = "RE"

# TODO keep or delete?
const MouseButtonEvent = Union{MouseDownEvent,MouseUpEvent}
const MouseEvent    = Union{MouseMotionEvent,MouseButtonEvent}
const KeyboardEvent = Union{KeyboardDownEvent,KeyboardUpEvent}
const WindowEvent   = Union{ResizeEvent}


mutable struct GLFWEventQueue
    _queue::Queue{Event}
    _mouseX    :: Int32
    _mouseY    :: Int32
    _mouse_btn :: MouseButtonState
    _key_mods  :: KeyModState

    function GLFWEventQueue(window::GLFW.Window)
        glfwEQ = new(Queue{Event}(),0,0,MOUSE_BUTTON_NONE,KEY_MOD_NONE)
        
        GLFW.SetCursorPosCallback(window,(w,x,y) -> mouse_motion(w,x,y,glfwEQ))
        GLFW.SetMouseButtonCallback(window,(w,key,action,mods) -> mouse_button(w,key,action,mods,glfwEQ))
        GLFW.SetScrollCallback(window,(w,xoffset,yoffset) -> mouse_wheel(w,xoffset,yoffset,glfwEQ))
        GLFW.SetKeyCallback(window,(w,key,scancde,action,mods) -> key_event(w,key,scancde,action,mods,glfwEQ))
        GLFW.SetWindowSizeCallback(window,(w,x,y) -> window_resize(w,x,y,glfwEQ))
        
        return glfwEQ
    end
end

function poll_event!(glfwEQ::GLFWEventQueue) :: Union{Nothing,Event}
    return isempty(glfwEQ._queue) ? nothing : dequeue!(glfwEQ._queue)
end

function mouse_motion(window::GLFW.Window, x::Float64, y::Float64, glfwEQ::GLFWEventQueue)
    ev = MouseMotionEvent(x, y, x-glfwEQ._mouseX, y-glfwEQ._mouseY,glfwEQ._mouse_btn,glfwEQ._key_mods)
    glfwEQ._mouseX, glfwEQ._mouseY = x, y
    enqueue!(glfwEQ._queue,ev)
end
function mouse_button(window::GLFW.Window, key::GLFW.MouseButton, action::GLFW.Action, mods::Int32,glfwEQ::GLFWEventQueue)
    glfwEQ._key_mods = KeyModState(mods)
    btn = key == GLFW.MOUSE_BUTTON_LEFT   ? MOUSE_BUTTON_LEFT   :
          key == GLFW.MOUSE_BUTTON_RIGHT  ? MOUSE_BUTTON_RIGHT  :
          key == GLFW.MOUSE_BUTTON_MIDDLE ? MOUSE_BUTTON_MIDDLE : MOUSE_BUTTON_NONE
    if action == GLFW.PRESS
        glfwEQ._mouse_btn |=  btn
        ev = MouseDownEvent(key, glfwEQ._mouseX, glfwEQ._mouseY,glfwEQ._mouse_btn,glfwEQ._key_mods)
    elseif action == GLFW.RELEASE
        glfwEQ._mouse_btn ⊻= btn
        ev = MouseUpEvent(key, glfwEQ._mouseX, glfwEQ._mouseY,glfwEQ._mouse_btn,glfwEQ._key_mods)
    else
        return nothing
    end
    enqueue!(glfwEQ._queue,ev); return nothing
end
function mouse_wheel(window::GLFW.Window, xoffset::Float64, yoffset::Float64,glfwEQ::GLFWEventQueue)
    ev = MouseWheelEvent(xoffset, yoffset, glfwEQ._mouseX, glfwEQ._mouseY,glfwEQ._mouse_btn,glfwEQ._key_mods)
    enqueue!(glfwEQ._queue,ev)
end
function key_event(window::GLFW.Window, key::GLFW.Key, scancode::Int32, action::GLFW.Action, mods::Int32,glfwEQ::GLFWEventQueue)
    glfwEQ._key_mods = KeyModState(mods)
    if action == GLFW.PRESS
        ev = KeyboardDownEvent(key, scancode, mods,glfwEQ._mouse_btn,glfwEQ._key_mods)
    elseif action == GLFW.RELEASE
        ev = KeyboardUpEvent(key, scancode, mods,glfwEQ._mouse_btn,glfwEQ._key_mods)
    else
        return nothing
    end
    enqueue!(glfwEQ._queue,ev)
end
function window_resize(window::GLFW.Window, x::Int32, y::Int32,glfwEQ::GLFWEventQueue)
    ev = ResizeEvent(x,y,glfwEQ._mouse_btn,glfwEQ._key_mods)
    enqueue!(glfwEQ._queue,ev); return nothing
end

export Event, GLFWEventQueue, poll_event!
export MouseMotionEvent,MouseDownEvent,MouseUpEvent,KeyboardDownEvent,KeyboardUpEvent,ResizeEvent
export string

end # module
