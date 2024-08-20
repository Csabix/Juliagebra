module Glm

using StaticArrays
using LinearAlgebra

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

export StaticFloat,StaticSigned,StaticUnsigned,StaticInteger,StaticReal,StaticNumber

include("Vec.jl")
include("Mat.jl")

# SHOW
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