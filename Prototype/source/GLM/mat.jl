
#
#   Mat N
#

const MatNxMT{N,M,T<:StaticNumber} = SMatrix{N,M,T}
const MatTNxM{T,N,M}               = MatNxMT{N,M,T}
const MatNT{N}                     = MatNxMT{N,N}
const MatTN{T,N}                   = MatNT{N,T}

mat_constructor(::Type{MatNxMT{N,M,T,L}},v...) where {N,M,T,L} = SMatrix{N,M,T,L}(v...) # general constructor
mat_constructor(::Type{MatNxMT{N,N,T,L}}, x::StaticNumber) where {N,T,L} = one(SMatrix{N,N,T,L}).*x # can do better?
mat_constructor(::Type{MatNxMT{N,M,T,L}}, x::StaticNumber) where {N,M,T,L} = SMatrix{N,M,T,L}(diagm(N,M,repeat([x],min(N,M))))
mat_constructor(::Type{MatNxMT{N,M,T,L}}, vs::Vararg{VecNT{N}}) where {N,M,T,L} = SMatrix{N,M,T,L}((vs...)...)
# Glsl has matN constructors such as mat3(vec2,float,vec2,float,vec2,float)
# which can be useful, but no alignmet to the columns is necessery. I don't wanna suport either.
# Glsl mat types can be also constructed with smaller matrices filling with identity elsewhere. I'm not planning on adding this.

# Generate all MatNxM types
for n in 2:4
    for m in 2:4
        nmsym = Symbol("Mat$(n)x$(m)T")     # creating incomplete type
        @eval const $nmsym{T} = MatNxMT{$n,$m,T,$n*$m} # for consistency with Vec{2,3,4}T
        @eval export $nmsym
        for (str, type) in CharTypeMap
            ssym = Symbol(uppercase(str)*"Mat$(n)x$(m)")
            fsym = Symbol(lowercase(str)*"mat$(n)x$(m)")
            @eval const $ssym = MatNxMT{$n,$m,$type,$n*$m}
            @eval @inline $fsym(v...) = mat_constructor($ssym,v...) 
            @eval export $ssym, $fsym
        end
    end
    # Diagonal types : MatN:
    nsym = Symbol("Mat$(n)T");
    @eval const $nsym{T} = MatNT{$n,T,$n*$n}
    #@eval export $nsym
    for (str, type) in CharTypeMap
        ssym = Symbol(uppercase(str)*"Mat$(n)")
        fsym = Symbol(lowercase(str)*"mat$(n)")
        @eval const $ssym = $nsym{$type}
        @eval @inline $fsym(v...) = mat_constructor($ssym,v...) 
        #@eval export $ssym, $fsym
    end
end

#
# Math
#

function lookat(eye::Vec3T{T}, at::Vec3T{T}, up::Vec3T{T}) :: Mat4T{T} where T
    f = -normalize(at-eye)      # Why -?
    s = normalize(cross(f,up))
    u = cross(s,f)
    M3 = [s u f]'
    return [M3 -M3*eye; 0 0 0 1]
end
function perspective(fovy::T, aspect::T, zNear::T, zFar::T) :: Mat4T{T} where T
    a  = tan(fovy/T(2))
    dz = zFar-zNear
    return Mat4T{T}(
        one(T)/(aspect*a), 0,        0,                 0,
        0,               one(T)/(a), 0,                 0,
        0,               0,        -(zFar+zNear)/dz,   -1,
        0,               0,        -(2*zFar*zNear)/dz,  0
    )
end

#export  lookat, perspective