mutable struct SharedData

  _name::String
  _width::Int
  _height::Int
  _gameOver::Bool
  _selectedID::UInt32
  _shouldReadID::Bool
  _mouseX::Int
  _mouseY::Int
  

  function SharedData(name::String,width::Int,height::Int)
      new(name,width,height,false,0,false)
  end
end