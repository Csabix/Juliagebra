flip!(b::Bool) = !b

mutable struct Peripherals
    _keyToFlip::Dict
    _forwardHeld::Bool
    _backwardHeld::Bool
    _leftHeld::Bool
    _rightHeld::Bool
    _upHeld::Bool
    _downHeld::Bool
    _aHeld::Bool
    _bHeld::Bool
    _middleHeld::Bool
    function Peripherals()
        keyToFlip = Dict([
            GLFW.KEY_W => (x) -> flipForward!(x),
            GLFW.KEY_S => (x) -> flipBackward!(x),
            GLFW.KEY_A => (x) -> flipLeft!(x),
            GLFW.KEY_D => (x) -> flipRight!(x),
            GLFW.KEY_Q => (x) -> flipUp!(x),
            GLFW.KEY_E => (x) -> flipDown!(x),
            GLFW.MOUSE_BUTTON_LEFT => (x) -> flipA!(x),
            GLFW.MOUSE_BUTTON_RIGHT => (x) -> flipB!(x),
            GLFW.MOUSE_BUTTON_MIDDLE => (x) -> flipMiddle!(x)
        ])
        new(keyToFlip,fill(false,9)...)
    end
end

flip!(self::Peripherals,key) = key in keys(self._keyToFlip) ? self._keyToFlip[key](self) : return

flipForward!(self::Peripherals) = self._forwardHeld = !self._forwardHeld
flipBackward!(self::Peripherals) = self._backwardHeld = !self._backwardHeld

flipLeft!(self::Peripherals) = self._leftHeld = !self._leftHeld
flipRight!(self::Peripherals) = self._rightHeld = !self._rightHeld

flipUp!(self::Peripherals) = self._upHeld = !self._upHeld
flipDown!(self::Peripherals) = self._downHeld = !self._downHeld

flipA!(self::Peripherals) = self._aHeld = !self._aHeld
flipB!(self::Peripherals) = self._bHeld = !self._bHeld
flipMiddle!(self::Peripherals) = self._middleHeld = !self._middleHeld


