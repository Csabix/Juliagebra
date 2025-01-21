mutable struct SharedData
    _name::String
    _width::Int
    _height::Int
    _gameOver::Bool
    _selectedID::UInt32
    _mouseMoved::Bool
    _relMouseX::Int
    _relMouseY::Int
    _mouseX::Int
    _mouseY::Int
    _wheelUpDown::Float64
    _wheelMoved::Bool
    _oldTime::Float64
    _deltaTime::Float32
    _selectedGizmo::UInt32

    function SharedData(name::String,width::Int,height::Int)
        new(name,width,height,false,UInt32(0),false,0,0,0,0,0.0,false,0.0,0.0,UInt32(0))
    end
end

function update!(self::SharedData)
    self._wheelUpDown = 0.0
    self._relMouseX = 0
    self._relMouseY = 0
    self._wheelMoved = false
    self._mouseMoved = false
end