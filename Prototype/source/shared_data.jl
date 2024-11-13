mutable struct SharedData

  _name::String
  _width::Int
  _height::Int
  _gameOver::Bool
  _selectedID::UInt32
  _mouseMoved::Bool
  _mouseX::Int
  _mouseY::Int
  _oldTime::Float64
  _deltaTime::Float32

  function SharedData(name::String,width::Int,height::Int)
      new(name,width,height,false,0,false,0.0,0.0)
  end
end