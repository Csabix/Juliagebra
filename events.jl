module Events

using DataStructures, BitFlags, ImGuiGLFWBackend.LibGLFW

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
    # timestamp :: UInt32
    # window    :: Ptr{GLFWwindow}
    mouseX    :: Int32
    mouseY    :: Int32
    xrel      :: Int32
    yrel      :: Int32
    mouse_btn :: MouseButtonState
    key_mods  :: KeyModState
end
struct MouseDownEvent <: Event
    # timestamp :: UInt32
    # window    :: Ptr{GLFWwindow}
    glfw_key  :: Cint
    mouseX    :: Int32
    mouseY    :: Int32
    mouse_btn :: MouseButtonState
    key_mods  :: KeyModState
end
struct MouseUpEvent <: Event
    # timestamp :: UInt32
    # window    :: Ptr{GLFWwindow}
    glfw_key  :: Cint
    mouseX    :: Int32
    mouseY    :: Int32
    mouse_btn :: MouseButtonState
    key_mods  :: KeyModState
end
struct MouseWheelEvent <: Event
    # timestamp :: UInt32
    # window    :: Ptr{GLFWwindow}
    wheelX    :: Int32      # horizontal scroll
    wheelY    :: Int32      # vertical scroll
    mouseX    :: Int32
    mouseY    :: Int32
    mouse_btn :: MouseButtonState
    key_mods  :: KeyModState
end
struct KeyboardDownEvent <: Event
    # timestamp :: UInt32
    # window    :: Ptr{GLFWwindow}
    glfw_key  :: Cint
    glfw_scan :: Cint
    glfw_mods :: Cint
    mouse_btn :: MouseButtonState
    key_mods  :: KeyModState
end
struct KeyboardUpEvent <: Event
    # timestamp :: UInt32
    # window    :: Ptr{GLFWwindow}
    glfw_key  :: Cint
    glfw_scan :: Cint
    glfw_mods :: Cint
    mouse_btn :: MouseButtonState
    key_mods  :: KeyModState
end
struct ResizeEvent <: Event
    # timestamp :: UInt32
    # window    :: Ptr{GLFWwindow}
    width     :: Int32
    height    :: Int32
    mouse_btn :: MouseButtonState
    key_mods  :: KeyModState
end
const MouseButtonEvent = Union{MouseDownEvent,MouseUpEvent}
const MouseEvent    = Union{MouseMotionEvent,MouseButtonEvent}
const KeyboardEvent = Union{KeyboardDownEvent,KeyboardUpEvent}
const WindowEvent   = Union{ResizeEvent}
#const Event         = Union{MouseEvent,KeyboardEvent,WindowEvent}

mutable struct EventQueue
    queue     :: Queue{Event}
    window    :: Ptr{GLFWwindow}
    mouseX    :: Int32
    mouseY    :: Int32
    mouse_btn :: MouseButtonState
    key_mods  :: KeyModState
end

global eq :: EventQueue

function mouse_motion(window::Ptr{GLFWwindow}, x::Cdouble, y::Cdouble)::Cvoid
    global eq
    ev = MouseMotionEvent(x, y, x-eq.mouseX, y-eq.mouseY,eq.mouse_btn,eq.key_mods)
    eq.mouseX, eq.mouseY = x, y
    enqueue!(eq.queue,ev); return nothing
    #push!(eq.queue,ev); return nothing
end
function mouse_button(window::Ptr{GLFWwindow}, key::Cint, action::Cint, mods::Cint)::Cvoid
    global eq
    eq.key_mods = KeyModState(mods)
    btn = key == GLFW_MOUSE_BUTTON_LEFT   ? MOUSE_BUTTON_LEFT   :
          key == GLFW_MOUSE_BUTTON_RIGHT  ? MOUSE_BUTTON_RIGHT  :
          key == GLFW_MOUSE_BUTTON_MIDDLE ? MOUSE_BUTTON_MIDDLE : MOUSE_BUTTON_NONE
    if action == GLFW_PRESS
        eq.mouse_btn |=  btn
        ev = MouseDownEvent(key, eq.mouseX, eq.mouseY,eq.mouse_btn,eq.key_mods)
    elseif action == GLFW_RELEASE
        eq.mouse_btn ⊻= btn
        ev = MouseUpEvent(key, eq.mouseX, eq.mouseY,eq.mouse_btn,eq.key_mods)
    else
        return nothing
    end
    enqueue!(eq.queue,ev); return nothing
end
function mouse_wheel(window::Ptr{GLFWwindow}, xoffset::Cdouble, yoffset::Cdouble)::Cvoid
    ev = MouseWheelEvent(xoffset, yoffset, eq.mouseX, eq.mouseY,eq.mouse_btn,eq.key_mods)
    enqueue!(eq.queue,ev); return nothing
end
function key_event(window::Ptr{GLFWwindow}, key::Cint, scancode::Cint, action::Cint, mods::Cint)::Cvoid
    global eq
    eq.key_mods = KeyModState(mods)
    if action == GLFW_PRESS
        ev = KeyboardDownEvent(key, scancode, mods,eq.mouse_btn,eq.key_mods)
    elseif action == GLFW_RELEASE
        ev = KeyboardUpEvent(key, scancode, mods,eq.mouse_btn,eq.key_mods)
    else
        return nothing
    end
    enqueue!(eq.queue,ev); return nothing
end
function windoow_resize(window::Ptr{GLFWwindow}, x::Cint, y::Cint)::Cvoid
    global eq
    ev = ResizeEvent(x,y,eq.mouse_btn,eq.key_mods)
    enqueue!(eq.queue,ev); return nothing
end

function EventQueue(window :: Ptr{GLFWwindow})
    global eq
    mouseX, mouseY = 0, 0 # TODO get mouse pos from glfw?
    eq = EventQueue(Queue{Event}(),window,mouseX,mouseY,MOUSE_BUTTON_NONE,KEY_MOD_NONE)
    glfwSetCursorPosCallback(window, @cfunction(mouse_motion, Cvoid, (Ptr{GLFWwindow}, Cdouble, Cdouble)))
    glfwSetMouseButtonCallback(window, @cfunction(mouse_button, Cvoid, (Ptr{GLFWwindow}, Cint, Cint, Cint)))
    glfwSetScrollCallback(window, @cfunction(mouse_wheel, Cvoid, (Ptr{GLFWwindow}, Cdouble, Cdouble)))
    glfwSetKeyCallback(window, @cfunction(key_event, Cvoid, (Ptr{GLFWwindow}, Cint, Cint, Cint, Cint)))
    glfwSetWindowSizeCallback(window, @cfunction(windoow_resize, Cvoid, (Ptr{GLFWwindow}, Cint, Cint)))
    # glfwSetCharCallback(window, @cfunction(CharCallback, Cvoid, (Ptr{GLFWwindow}, Cuint)))
    # glfwSetWindowCloseCallback(window, @cfunction(WindowCloseCallback, Cvoid, (Ptr{GLFWwindow},)))
    # glfwSetWindowPosCallback(window, @cfunction(WindowPosCallback, Cvoid, (Ptr{GLFWwindow}, Cint, Cint)))
    return eq
end

function poll_event!(q::EventQueue) :: Union{Nothing,Event}
    return isempty(q.queue) ? nothing : dequeue!(q.queue)
end

export Event, EventQueue, poll_event!
export MouseMotionEvent,MouseDownEvent,MouseUpEvent,KeyboardDownEvent,KeyboardUpEvent,ResizeEvent
export MouseEvent,MouseButtonEvent,KeyboardEvent,WindowEvent

end # module
