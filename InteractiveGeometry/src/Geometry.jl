
global g_current_id :: Int = 0
getNextId!()::Int = begin global g_current_id; return g_current_id += 1 end

# Common properties of Geometry
@kwdef mutable struct CommonProperties
    id    :: Int          = getNextId!()
    label :: String       = string(id)
    width :: Float32      = 1f0
    color :: Vec4T{UInt8} = Vec4T{UInt8}(50,50,255,255)
end

#
#   Geometry interface
#

abstract type Geometry end

abstract type AbstractPoints    <: Geometry end

struct DynamicPoints            <: Geometry
    value :: Vector{Vec3}
    properties :: CommonProperties
end
struct StaticPoints{N}          <: Geometry
    value :: Array{Vec3,N}
    properties :: CommonProperties
end
const Point = StaticPoints{1};


abstract type AbstractLines     <: Geometry end


abstract type AbstractTriangles <: Geometry end
abstract type VectorField       <: Geometry end

const StaticGeometries = Union{Point,StaticPoints}
const DynamicGeometries = Union{DynamicPoints}

#
#   Geometry methods
#

# This is essentially a constructor for all defived types!
(::Type{FA})(value, others...; options...) where {FA <: Geometry} = FA(value, CommonProperties(;options),others...)

id(g::Geometry) = g.properties.id
label(g::Geometry)::String = g.properties.label
value(g::Geometry) = g.value
assign!(g::Geometry,y::Any)::Nothing = (g.value = y, nothing)
render(g::Geometry) = show(g)


#
#   GeometryRenderer
#

struct GeometryRenderer{G}
    data :: Vector{G}
end
getindex(gc::GeometryRenderer, id) = gc.data[id_to_index(gc,id)]

render(gc::GeometryRenderer{<:StaticGeometries})  = println("Static geometry draw\n",gc)  # could use "data" buffer directly        TODO implement
render(gc::GeometryRenderer{<:DynamicGeometries}) = println("Dynamic geometry draw\n",gc) # must manage memory or render seperately TODO implement

id_to_index(gc::GeometryRenderer,id) = id # Maps renderer's id read from FBO to an index in data. TODO overload this

# problem: GeometryRenderer and Drawing cannot both contain Geometries
#   TODO: figure out how Drawing could ommit containing the Geometries. References? I think yes!

