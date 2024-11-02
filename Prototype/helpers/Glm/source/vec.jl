
#
#   Vec N
#

abstract type VecNT{N,T<:StaticNumber} <: FieldVector{N, T} end
const VecTN{T,N} = VecNT{N,T}

struct Vec2T{T} <: VecNT{2,T};  x::T; y::T;             end
struct Vec3T{T} <: VecNT{3,T};  x::T; y::T; z::T;       end
struct Vec4T{T} <: VecNT{4,T};  x::T; y::T; z::T; w::T; end

StaticArrays.similar_type(::Type{<:Vec2T}, ::Type{T}, s::Size{(2,)}) where T = Vec2T{T}
StaticArrays.similar_type(::Type{<:Vec3T}, ::Type{T}, s::Size{(3,)}) where T = Vec3T{T}
StaticArrays.similar_type(::Type{<:Vec4T}, ::Type{T}, s::Size{(4,)}) where T = Vec4T{T}

Vec2T{T}(x::StaticNumber) where T = Vec2T{T}(x,x)
Vec3T{T}(x::StaticNumber) where T = Vec3T{T}(x,x,x)
Vec4T{T}(x::StaticNumber) where T = Vec4T{T}(x,x,x,x)
Vec3T{T}(x::StaticNumber,yz::Vec2T) where T = Vec3T{T}(x,yz...)
Vec3T{T}(xy::Vec2T,z::StaticNumber) where T = Vec3T{T}(xy...,z)
Vec4T{T}(x::StaticNumber,y::StaticNumber,zw::Vec2T) where T = Vec4T{T}(x,y,zw...)
Vec4T{T}(x::StaticNumber,yz::Vec2T,w::StaticNumber) where T = Vec4T{T}(x,yz...,w)
Vec4T{T}(xy::Vec2T,z::StaticNumber,w::StaticNumber) where T = Vec4T{T}(xy...,z,w)
Vec4T{T}(x::StaticNumber,yzw::Vec3T) where T = Vec4T{T}(x,yzw...)
Vec4T{T}(xyz::Vec3T,w::StaticNumber) where T = Vec4T{T}(xyz...,w)
Vec4T{T}(xy::Vec2T,zw::Vec2T) where T = Vec4T{T}(xy...,zw...)
# Actually glsl has oversized vec constructors, such as vec2(vec3(1,2,3))=vec2(1,2). I don't wanna support that.

# Generate concrete types and constructors
for n in 2:4
    dsym = Symbol("Vec"*string(n)*"T")
    for (str, type) in CharTypeMap
        ssym = Symbol(uppercase(str)*"Vec"*string(n))
        fsym = Symbol(lowercase(str)*"vec"*string(n))
        @eval const $ssym = $dsym{$type}
        @eval @inline $fsym(v...) = $ssym(v...) 
        @eval export $ssym, $fsym
    end
end

# SWIZZLE
import StaticArrays.getindex

@Base.propagate_inbounds @inline function getindex(v::VecNT{N,T},ii::NTuple{1}) where {N,T}
    v[@inbounds ii[1]]
end
@Base.propagate_inbounds @inline function getindex(v::VecNT{N,T},ii::NTuple{2}) where {N,T}
    Vec2T{T}(v[@inbounds ii[1]],v[@inbounds ii[2]])
end
@Base.propagate_inbounds @inline function getindex(v::VecNT{N,T},ii::NTuple{3}) where {N,T}
    Vec3T{T}(v[@inbounds ii[1]],v[@inbounds ii[2]],v[@inbounds ii[3]])
end
@Base.propagate_inbounds @inline function getindex(v::VecNT{N,T},ii::NTuple{4}) where {N,T}
    Vec4T{T}(v[@inbounds ii[1]],v[@inbounds ii[2]],v[@inbounds ii[3]],@inbounds v[ii[4]])
end
function checkindex_string(::Type{Bool}, inds::AbstractUnitRange, I::String) # same signiture as in Base.checkindex, but only one use, no need to generalize
    @inline 
    b = true
    for i in I
        b &= checkindex(Bool, inds, UInt8(i))
    end
    b
end
const SwizzleBounds = [UInt8('x'):UInt8('x'),UInt8('x'):UInt8('y'),UInt8('x'):UInt8('z'),UInt8('w'):UInt8('z')]; # wxyz in ABC vs xyzw order 
@inline function getindex(v::VecNT{N,T},swizzle::String) where {N,T} # String SWIZZLE
    @boundscheck (1<=length(swizzle)<=4) & checkindex_string(Bool,SwizzleBounds[N],swizzle) || Base.throw_boundserror(v,swizzle)
    @inbounds getindex(v, (UInt8.(Tuple(swizzle)) .& 0x03) .+ 1) # mod('wxyz',4) = [3,0,1,2]
end

export getindex

function getAPlane()::Vector{Vec3} 
    plane = Vector{Vec3}()
    push!(plane,Vec3(-1.0,-1.0, 1.0))
    push!(plane,Vec3(-1.0,1.0,1.0))
    push!(plane,Vec3(1.0,-1.0,1.0))
    push!(plane,Vec3(-1.0,1.0,1.0))
    push!(plane,Vec3(1.0,1.0,1.0))
    push!(plane,Vec3(1.0,-1.0,1.0))
    return plane
end

export getAPlane