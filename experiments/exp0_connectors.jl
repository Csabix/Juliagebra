using DataStructures

mutable struct Connector{A}{B}

end

@kwdef mutable struct UpdateQueue{T}
    _queue::Queue{Int} = Queue{Int}()
    _items::Vector{T} = Vector{T}()
end

function push(self::UpdateQueue{T},item::T)::Int where T

end
