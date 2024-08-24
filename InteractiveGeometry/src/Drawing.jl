
#
#   Drawings form an abstract syntax tree. Including Movable and Dependent type Drawings.
#   Encapsulated Geometry-s need not know whether they are Movable or not.
#
abstract type Drawing end

id(x::Drawing)::Int = id(x.geometry[])
value(x::Drawing) = value(x.geometry[])
label(x::Drawing) = label(x.geometry[])

insert2sorted(v::Vector, x::Drawing)::Nothing = (splice!(v, searchsorted(v,x;by=id), [x]); nothing)

#
#   Movable
#
mutable struct Movable{T <: Geometry} <: Drawing
    geometry   :: Ref{T}
    dependents :: Vector{Any} # Sorted list of Dependents
    Movable{T}(geom::Ref{T}) where {T <: Geometry} = new(geom,[])
end

function moveto!(x::Movable,v::Any)::Nothing
    assign!(x.geometry[],v)
    map(update!,x.dependents) # used to be called update on movables
    return nothing
end

#
#   Dependent
#
mutable struct Dependent{T <: Geometry} <: Drawing
    geometry :: Ref{T}
    callback :: Function
    inputs   :: Vector{Any}
    movables :: Vector{Any} # Sorted list of Movables
    function Dependent{T}(geom::Ref{T},callback::Function,inputs) where {T <: Geometry} 
        ret = new(geom,callback,inputs,[])
        # Todo: there should be a way to create a vector of items to be inserted and merge those into the sorted list at once, maybe even in-place
        for input in inputs
            if input isa Movable
                insert2sorted(ret.movables,input)
                insert2sorted(input.dependents,ret)
            elseif input isa Dependent
                for movable in input.movables
                    insert2sorted(movable.dependents,ret)
                end
            else
                error("unexpected input type")
            end
        end
        update!(ret)
        return ret
    end
end

update!(x::Dependent) :: Nothing = assign!(x.geometry[],x.callback(map(value,x.inputs)...))
