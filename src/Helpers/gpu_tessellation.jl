const GPU_TESS_LOCAL_SIZE::UInt32 = UInt32(256)

# the transpiler currently only recognizes JuliaGLM types
# so manual normalization is required from StaticVector for now
_svec_to_vec(v::StaticVector{2,T}) where {T} = Vec2T{T}(v)
_svec_to_vec(v::StaticVector{3,T}) where {T} = Vec3T{T}(v)
_svec_to_vec(v::StaticVector{4,T}) where {T} = Vec4T{T}(v)
_svec_to_vec(::StaticVector)                 = nothing

# if adding new return types to convert_argument_gpu, make sure _parse_curly_type can handle them in transpilation.jl

"""
Handles parsing of uploaded uniform values for GPU tessellation.
Forces numeric types to their 32-bit variant, component-wise when possible.
Returning nothing triggers a GPU tessellation failure and the dependent falls back to the CPU
"""
convert_argument_gpu(::Any)       = nothing
convert_argument_gpu(b::Bool)     = b
convert_argument_gpu(n::Integer)  = typemin(Int32) <= n <= typemax(Int32) ? Int32(n) : nothing
convert_argument_gpu(n::Unsigned) = n <= typemax(UInt32) ? UInt32(n) : nothing
convert_argument_gpu(x::Real)     = Float32(x)

convert_argument_gpu(v::StaticVector{N,Bool})    where {N} = 2 <= N <= 4 ? _svec_to_vec(v) : nothing
convert_argument_gpu(v::StaticVector{N,Int32})   where {N} = 2 <= N <= 4 ? _svec_to_vec(v) : nothing
convert_argument_gpu(v::StaticVector{N,UInt32})  where {N} = 2 <= N <= 4 ? _svec_to_vec(v) : nothing
convert_argument_gpu(v::StaticVector{N,Float32}) where {N} = 2 <= N <= 4 ? _svec_to_vec(v) : nothing

convert_argument_gpu(v::StaticVector{N,<:Integer})  where {N} =
    2 <= N <= 4 && all(n -> typemin(Int32) <= n <= typemax(Int32), v) ? _svec_to_vec(similar_type(v, Int32)(v)) : nothing
convert_argument_gpu(v::StaticVector{N,<:Unsigned}) where {N} =
    2 <= N <= 4 && all(n -> n <= typemax(UInt32), v) ? _svec_to_vec(similar_type(v, UInt32)(v)) : nothing
convert_argument_gpu(v::StaticVector{N,<:Real})     where {N} = _svec_to_vec(similar_type(v, Float32)(v))

convert_argument_gpu(m::SMatrix{N,M,Float32}) where {N,M} = (2 <= N <= 4 && 2 <= M <= 4) ? m : nothing
convert_argument_gpu(m::SMatrix{N,M,<:Real})  where {N,M} = (2 <= N <= 4 && 2 <= M <= 4) ? similar_type(m, Float32)(m) : nothing
