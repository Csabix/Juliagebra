# TODO: decide where this file should live in the file system (which subdirectory)

# the transpiler currently only recognizes JuliaGLM types
# so manual normalization is required from StaticVector for now
_svec_to_vec(v::StaticVector{2,T}) where {T} = Vec2T{T}(v)
_svec_to_vec(v::StaticVector{3,T}) where {T} = Vec3T{T}(v)
_svec_to_vec(v::StaticVector{4,T}) where {T} = Vec4T{T}(v)
_svec_to_vec(::StaticVector)                 = nothing

"""
Handles parsing of uploaded uniform values for GPU tessellation.
Forces numeric types to their 32-bit variant, component-wise.
nothing triggers a GPU tessellation failure and the dependent falls back to the CPU
"""
gpu_tessellation_uniform(::Any)       = nothing
gpu_tessellation_uniform(b::Bool)     = b
gpu_tessellation_uniform(n::Integer)  = typemin(Int32) <= n <= typemax(Int32) ? Int32(n) : nothing
gpu_tessellation_uniform(n::Unsigned) = n <= typemax(UInt32) ? UInt32(n) : nothing
gpu_tessellation_uniform(x::Real)     = Float32(x)

gpu_tessellation_uniform(v::StaticVector{N,Bool})    where {N} = 2 <= N <= 4 ? _svec_to_vec(v) : nothing
gpu_tessellation_uniform(v::StaticVector{N,Int32})   where {N} = 2 <= N <= 4 ? _svec_to_vec(v) : nothing
gpu_tessellation_uniform(v::StaticVector{N,UInt32})  where {N} = 2 <= N <= 4 ? _svec_to_vec(v) : nothing
gpu_tessellation_uniform(v::StaticVector{N,Float32}) where {N} = 2 <= N <= 4 ? _svec_to_vec(v) : nothing

gpu_tessellation_uniform(v::StaticVector{N,<:Integer})  where {N} =
    2 <= N <= 4 && all(n -> typemin(Int32) <= n <= typemax(Int32), v) ? _svec_to_vec(similar_type(v, Int32)(v)) : nothing
gpu_tessellation_uniform(v::StaticVector{N,<:Unsigned}) where {N} =
    2 <= N <= 4 && all(n -> n <= typemax(UInt32), v) ? _svec_to_vec(similar_type(v, UInt32)(v)) : nothing
gpu_tessellation_uniform(v::StaticVector{N,<:Real})     where {N} = _svec_to_vec(similar_type(v, Float32)(v))

gpu_tessellation_uniform(m::SMatrix{N,M,Float32}) where {N,M} = (2 <= N <= 4 && 2 <= M <= 4) ? m : nothing
gpu_tessellation_uniform(m::SMatrix{N,M,<:Real})  where {N,M} = (2 <= N <= 4 && 2 <= M <= 4) ? similar_type(m, Float32)(m) : nothing
