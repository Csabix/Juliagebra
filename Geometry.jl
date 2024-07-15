module Geometries

using GeometryBasics
import Base:show
export show

using PrettyPrint

global g_current_id :: Int = 0
getNextId!()::Int = begin global g_current_id; return g_current_id += 1 end

# Common properties of Geometry
@kwdef mutable struct CommonProperties
    id    :: Int    = getNextId!()
    label :: String = string(id)
    width :: Float32 = 1f0
    color :: Vec4{UInt8} = Vec4{UInt8}(50,50,255,255)
end
#Base.show(x::CommonProperties) = Base.show(Base.stdout,MIME("text/plain"),x)
#Base.show(io::IO,::MIME"text/plain",x::CommonProperties) = print(io, "[id=$(x.id), label = $(x.label), width=$(x.width), color=$(convert(NTuple{4,Int},tuple(x.color...)))]")

PrettyPrint.pp_impl(io,v::Vec{N,T} where {N,T<:AbstractFloat},it::Int) = begin printstyled(io,Float64[v...];bold=true,color=6); return it end
PrettyPrint.pp_impl(io,v::Vec{N,T} where {N,T<:Integer      },it::Int) = begin printstyled(io,    Int[v...];bold=true,color=2); return it end


function PrettyPrint.pp_impl(io,x::CommonProperties,it::Int)
    printstyled(io,"(";color=3);
    for v in fieldnames(typeof(x))
        printstyled(io,v,"=";italic=true,color=0)
        pprint(io,getfield(x,v),it); print(io,", ")
    end
    printstyled(io,")";color=3);
    return it
end

#
#   Instances Geometry handle syncronization with backend (?)
#
abstract type Geometry end

id(::Geometry)::Int = 0
label(::Geometry)::String = "drawing"
value(::Geometry) = Vector{Vec3f}[]
assign!(::Geometry,y::Any)::Nothing = nothing

mutable struct Point <: Geometry
    value      :: Vec3f
    properties :: CommonProperties
end

Point(v::AbstractVector=Vec3f(0); options...) = Point(Vec3f(v...),CommonProperties(;options...))

id(x::Point)::Int = x.properties.id 
label(x::Point)::String = x.properties.label
value(x::Point)::Vec3f  = x.value
assign!(x::Point,y::AbstractVector)::Nothing = begin x.value = Vec3f(y...); nothing end

#
#   Drawings form an abstract syntax tree. Including Movable and Dependent type Drawings.
#   Encapsulated Geometry-s need not know whether they are Movable or not.
#
abstract type Drawing end

id(::Drawing)::Int = 0 # invalid id
label(::Drawing)::String = "label of abstract type"
value(::Drawing) = Vector{Vec3f}[]

insert2sorted(v::Vector, x::Drawing)::Nothing = (splice!(v, searchsorted(v,x;by=id), [x]); nothing)

#
#   Movable
#
mutable struct Movable{T <: Geometry} <: Drawing
    geometry   :: T
    dependents :: Vector{Any} # Sorted list of Dependents
    Movable{T}(geom::T) where {T <: Geometry} = new(geom,[])
end
id(x::Movable)::Int = id(x.geometry)
value(x::Movable) = value(x.geometry)
label(x::Movable) = label(x.geometry)

function moveto!(x::Movable,v::Any)::Nothing
    assign!(x.geometry,v)
    map(update!,x.dependents) # used to be called update on movables
    return nothing
end

#
#   Dependent
#
mutable struct Dependent{T <: Geometry} <: Drawing
    geometry :: T
    callback :: Function
    inputs   :: Vector{Any}
    movables :: Vector{Any} # Sorted list of Movables
    function Dependent{T}(geom::T,callback::Function,inputs) where {T <: Geometry} 
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
id(x::Dependent)::Int = id(x.geometry)
value(x::Dependent) = value(x.geometry)
label(x::Dependent) = label(x.geometry)

update!(x::Dependent) :: Nothing = assign!(x.geometry,x.callback(map(value,x.inputs)...))

#
#   Others
#

function PrettyPrint.pp_impl(io,x::Drawing, it::Int)
    col = (typeof(x) <: Dependent ? 105 : 202);
    ind = " "^it;
    printstyled(io,"$(typeof(x).name.name){";color=col);
    printstyled(io,"$(typeof(x).parameters[1].name.name)"; bold=true, color=3);
    printstyled(io,"}","(";color=col);
    print(io,"id=$(id(x)), label=\"$(label(x))\"")
    if it < 4
        print(io,"\n")
        for v in fieldnames(typeof(x))
            printstyled(io,ind*"  ",v," = ";italic=true,bold=true,color=0)
            pprint(io,getfield(x,v),it+2); print(io,",\n")
        end
        print(io,ind)
    end
    printstyled(io,")";color=col);
    return it
end

function PrettyPrint.pp_impl(io,x::Function,it::Int)
    printstyled(io, join(split("$(code_lowered(x)[1])",'\n'),"\n  "*" "^it) ;color=5)
    return it
end

const MPoint = Movable{Point};
const DPoint = Dependent{Point};

mpoint(v::AbstractArray; options...) = Movable{Point}(Point(v;options...))
dpoint(callback, inputs...; options...) = Dependent{Point}(Point(;options...), callback, [inputs...])

function test()
    A = mpoint([1,2,3] ; label="A")
    B = mpoint([2,3,4] ; label="B")
    C = dpoint((a,b)->a+b, A, B ; label="C")
    D = dpoint(A,B,C ; label="D") do a, b, c
        k = a + c
        b - k
    end
    moveto!(A,[0,0,1])
    pprint(D)
end

end # module Geometries