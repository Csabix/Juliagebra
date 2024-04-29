abstract type Geometry end


mutable struct CommonInfo
    label :: String
    
end

mutable struct Sequence{T}
    buffer # view
end


mutable struct Point
end
