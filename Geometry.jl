module Geometries

using GeometryBasics

# Common properties of Geometry
@kwdef mutable struct CommonProperties
    label :: String = "default"
    width :: Float32 = 1f0
    color :: Vec4{UInt8} = Vec4{UInt8}(50,50,255,255)
end

#
#   Instances Geometry handle syncronization with backend (?)
#
abstract type Geometry end

label(::Geometry)::String = "drawing"
value(::Geometry)::Vector{Vec3f} = Vector{Vec3f}[]
assign!(::Geometry,y::Any)::Nothing = nothing


mutable struct Point <: Geometry
    value :: Vec3f
    prop :: CommonProperties
end

label(x::Point)::String = x.label
value(x::Point)::Vec3f  = x.value
assign!(x::Point,y::Vec3f)::Nothing = x.value = y, nothing


#
#   Drawings form an abstract syntax tree. Including Movable and Dependent type Drawings.
#   Encapsulated Geometry-s need not know whether they are Movable or not.
#
abstract type Drawing end

label(::Drawing)::String = "drawing"
value(::Drawing)::Vector{Vec3f} = Vector{Vec3f}[]
update!(::Drawing)::Nothing = nothing
#setdependency

#   Movable:
#dependents(::Drawing)::Vector{Drawing} = Vector{Drawing}[]

#   Dependant:
#inputs(::Drawing)::Tuple = ()
callback(::Drawing)::Union{Function,Nothing} = nothing

mutable struct Movable{T <: Geometry} <: Drawing
    geom       :: T
    dependents :: Vector{Geometry}
end
mutable struct Dependent{T <: Geometry} <: Drawing
    geom     :: T
    callback :: Function
    inputs   :: Tuple
#   movables :: Set{Drawing}
end

#   Movable:
#dependents(x::Movable{T <: Geometry})::Vector{Drawing} = x.dependents

function update!(x::Movable{<:Geometry})
    for g in x.dependents
        update!(g)
    end
end

#   Dependant:
# inputs(x::Dependent{<:Geometry})::Vector{Drawing} = x.inputs
# callback(x::Dependent{<:Geometry})::Function = x.callback

function update!(x::Movable{<:Geometry})
    assign(x.value,x.callback(x.inputs...))
end

end # module Geometries