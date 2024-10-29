mutable struct SharedData

  _name::String
  _width::Int
  _height::Int
  _gameOver::Bool

  function SharedData(name::String,width::Int,height::Int)
      new(name,width,height,false)
  end
end