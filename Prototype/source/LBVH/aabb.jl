using StaticArrays



struct AABB{N}
    min::SVector{N, Float32}
    max::SVector{N, Float32}
end

const AABB2D = AABB{2}
const AABB3D = AABB{3}



function AABBValid(aabb::AABB{N})::Bool where {N}
    return all(aabb.min .<= aabb.max)
end

"""
```julia
function AABBUnion(aabb_1::AABB{N}, aabb_2::AABB{N})::AABB{N} where {N}
```

Returns the union of 2 given AABB (Axis Aligned Bounding Box) basically the min of the mins and the max of the maxs.

# Arguments
- `aabb_1`: the first AABB
- `aabb_2`: the second AABB

# Returns
- `AABB{N}`: the union of the 2 arguments

# Examples
```julia
julia> AABBUnion(AABB2D(SVector(-1.0f0, 1.0f0), SVector(1.1f0, 1.1f0)), AABB2D(SVector(2.0f0, 2.0f0), SVector(2.1f0, 3.1f0))) # => AABB2D(Float32[-1.0, 1.0], Float32[2.1, 3.1])
julia> AABBUnion(AABB2D(SVector(-1.0f0, 1.0f0), SVector(1.1f0, 1.1f0)), AABB2D(SVector(2.0f0, -2.0f0), SVector(2.1f0, 3.1f0))) # => AABB2D(Float32[-1.0, -2.0], Float32[2.1, 3.1])
julia> AABBUnion(AABB2D(SVector(2.0f0, -2.0f0), SVector(2.1f0, 3.1f0)), AABB2D(SVector(-1.0f0, 1.0f0), SVector(1.1f0, 1.1f0))) # => AABB2D(Float32[-1.0, -2.0], Float32[2.1, 3.1])
julia> AABBUnion(AABB3D(SVector(-1.0f0, 1.0f0, 5.0f0), SVector(1.1f0, 1.1f0, 9.0f0)), AABB3D(SVector(2.0f0, -2.0f0, 4.0f0), SVector(2.1f0, 3.1f0, 12.0f0))) # => AABB3D(Float32[-1.0, -2.0, 4.0], Float32[2.1, 3.1, 12.0])
```
"""
function AABBUnion(aabb_1::AABB{N}, aabb_2::AABB{N})::AABB{N} where {N}
    @assert AABBValid(aabb_1) "Error, invalid first AABB provided"
    @assert AABBValid(aabb_2) "Error, invalid second AABB provided"
    return AABB{N}(min.(aabb_1.min, aabb_2.min), max.(aabb_1.max, aabb_2.max))
end

"""
```julia
function AABB2AABBIntersection(aabb_1::AABB{N}, aabb_2::AABB{N})::Bool where {N}
```

This function decides if 2 AABB (Axis Aligned Bounding Box) intersect

# Arguments
- `aabb_1`: the first AABB (order doesn't matter)
- `aabb_2`: the second AABB

# Returns
- `Bool`: true if `aabb_1` and `aabb_2` intersect otherwise false (if only their edges or their corners touch or one is fully inside the other it is still considered an intersection same when they are 2 points with the same coordinates)

# Examples
```julia
julia> AABB2AABBIntersection(AABB2D(SVector(4.0f0, 5.4f0), SVector(6.0f0, 5.6f0)), AABB2D(SVector(0.0f0, 5.0f0), SVector(10.0f0, 6.0f0))) # => true
julia> AABB2AABBIntersection(AABB2D(SVector(2.0f0, -2.0f0), SVector(2.0f0, -2.0f0)), AABB2D(SVector(2.0f0, -2.0f0), SVector(2.1f0, 3.1f0))) # => true
julia> AABB2AABBIntersection(AABB2D(SVector(-32.0f0, 3.2f0), SVector(-12.0f0, 3.4f0)), AABB2D(SVector(-1.0f0, 0.0f0), SVector(1.1f0, 1.1f0))) # => false
julia> AABB2AABBIntersection(AABB3D(SVector(0.7f0, 0.8f0, 1.8f0), SVector(0.7f0, 0.8f0, 1.8f0)), AABB3D(SVector(0.0f0, 0.0f0, 0.0f0), SVector(1.0f0, 1.0f0, 2.0f0))) # => true
julia> AABB2AABBIntersection(AABB3D(SVector(0.1f0, 0.2f0, 0.3f0), SVector(0.4f0, 0.5f0, 0.6f0)), AABB3D(SVector(0.1f0, 0.5f0, 0.3f0), SVector(4.0f0, 0.5f0, 0.6f0))) # => true
julia> AABB2AABBIntersection(AABB3D(SVector(0.1f0, 0.2f0, 0.3f0), SVector(0.4f0, 0.5f0, 0.6f0)), AABB3D(SVector(0.1f0, 0.5001f0, 0.3f0), SVector(4.0f0, 0.5f0, 0.6f0))) # => false
```
"""
function AABB2AABBIntersection(aabb_1::AABB{N}, aabb_2::AABB{N})::Bool where {N}
    @assert AABBValid(aabb_1) "Error, invalid first AABB provided"
    @assert AABBValid(aabb_2) "Error, invalid second AABB provided"
    overlaps = (aabb_2.min .<= aabb_1.max) .& (aabb_1.min .<= aabb_2.max)
    return all(overlaps)
end



export AABB
export AABB2D
export AABB3D
