module Glm

export Vec2T, Vec3T, Vec4T, VecTN, VecNT
export MatNxMT, MatTNxM, MatNT, MatTN
export lookat, perspective

"""
# exports types     `Vec{2,3,4}[T]`       and  `Mat{2,3,4}[x{2,3,4}][T]`
# exports types     `[D,I,U,B]Vec{2,3,4}` and  `[D,I,U,B]Mat{2,3,4}[x{2,3,4}]`
# exports functions `[d,i,u,b]vec{2,3,4}` and  `[d,i,u,b]mat{2,3,4}[x{2,3,4}]`
#
# Use lowercase function to construct objects. (Vec constructors are exactly the same, but Mat constructors are not!)
#   for instance, write `M :: Mat2 = mat2(2)` because `M :: Mat2 = Mat2(2)` does not work.
# Vectors have x,y,z,w members (the right amount ofc)
# Vector swizzle: v=vec4(1,2,3,4); v["yxz"] == vec3(2,1,3)  (might make a macro later for thsi)
# Vectors can be constructed from other vectors as long as total size exactly fits. (or one-arg construction: vecN(x))
# Matrices can be constructed from its column VecN-s with the lowecase *mat* functions.  (or one-arg construction: matN(x))
"""

using StaticArrays
using LinearAlgebra
using Test

# Option to export sized types like i16vec2 or u16mat3x4 apart from the default ones
const noSizedTypes = true;

const BaseCharTypeMap  = [""=>Float32,"d"=>Float64, "b"=>Bool,    "i"=>Int32,  "u"=>UInt32]
const SizedCharTypeMap = ["i8"=>Int8, "i16"=>Int16, "i32"=>Int32, "i64"=>Int64,
                          "u8"=>UInt8,"u16"=>UInt16,"u32"=>UInt32,"u64"=>UInt64]
const CharTypeMap = vcat(BaseCharTypeMap,ifelse(noSizedTypes,[],SizedCharTypeMap))

# Basically Base.Number, except only static sized types are allowed:
const StaticFloat    = Union{Float16,Float32,Float64}
const StaticSigned   = Union{Int8,Int16,Int32,Int64,Int128};
const StaticUnsigned = Union{UInt8,UInt16,UInt32,UInt64,UInt128};
const StaticInteger  = Union{Bool,StaticSigned,StaticUnsigned}
const StaticReal     = Union{StaticInteger,StaticFloat,Rational{<:StaticInteger}}
const StaticNumber   = Union{StaticReal,Complex{<:StaticReal}}
#export StaticFloat,StaticSigned,StaticUnsigned,StaticInteger,StaticReal,StaticNumber # maybe not needed


include("Vec.jl")
include("Mat.jl")

# custom SHOW
import StaticArrays.show

format_val(t::StaticNumber)  = t # dont convert by default
format_val(t::StaticInteger) = Int(t)     # convert integers (signed and unsigned)
format_val(t::StaticFloat)   = Float64(t) # convert floats
format_val(t::Union{Bool,Int64,Int128,UInt64,UInt128}) = t # exceptions

size_to_str(::VecNT{N})     where N     = "Vec$(N)"
size_to_str(::MatNxMT{N,M}) where {N,M} = "Mat$(N)x$(M)"
size_to_str(::MatNxMT{N,N}) where N     = "Mat$(N)"

type_to_str(v::Union{MatTNxM{T},VecTN{T}}) where T = size_to_str(v) * "{$(T)}"
for (str, type) in CharTypeMap
    @eval type_to_str(v::Union{MatTNxM{$type},VecTN{$type}}) =  uppercase($str) * size_to_str(v)
end

format_elements(v) = repr.(format_val.(v) ; context=:compact=>true);
value_to_str(v::VecNT)   = "(" * join(format_elements([v...]),',') * ")"
value_to_str(v::MatNxMT) = "[ " * join(join.(eachrow(format_elements(v)),' ')," ; ") * " ]"

show(io::IO,v::VecNT) = print(io,type_to_str(v),value_to_str(v))
show(io::IO,v::MatNxMT) = print(io,type_to_str(v),value_to_str(v))
show(io::IO,::MIME{Symbol("text/plain")},v::VecNT) = show(io,v)
show(io::IO,::MIME{Symbol("text/plain")},v::MatNxMT) = show(io,v)

export show


end