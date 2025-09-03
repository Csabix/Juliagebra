const INVALID_CHILD_POINTER::UInt32 = 0 # 0 is the root thus it can't be a child pointer

mutable struct LBVHNode{N}
    left_child_index::UInt32
    right_child_index_or_primitive_index::UInt32 # if (left_child_index == INVALID_CHILD_POINTER) then this points to a primitive, otherwise this is points to the right child node
    aabb::AABB{N}
end

const LBVHNode2D = LBVHNode{2}
const LBVHNode3D = LBVHNode{3}

struct PrimitiveIndexWithMortonCode{MortonCodeT<:AbstractMortonCodeType}
    primitive_index::UInt32
    morton_code::MortonCodeT
end

const STACK_SIZE = 100



"""
```julia
function GetContainerAABB(aabbs::Vector{AABB{N}})::AABB{N} where {N}
```

Calculates a bounding AABB (Axis Aligned Bounding Box) around a vector of AABBs (basically takes the min of mins and max of maxes)

# Arguments
- `aabbs`: the vector of AABBs 

# Returns
- `AABB{N}`: an AABB which contains all of the `aabbs` (inclusive)

# Examples
```julia
julia> GetContainerAABB(Vector{AABB2D}([AABB2D(SVector(4.0f0, 5.4f0), SVector(6.0f0, 5.6f0)), AABB2D(SVector(0.0f0, 5.0f0), SVector(10.01f0, 6.6f0)), AABB2D(SVector(-10.0f0, -5.0f0), SVector(10.0f0, 6.0f0))])) # => AABB2D(Float32[-10.0, -5.0], Float32[10.01, 6.6])
julia> GetContainerAABB(Vector{AABB2D}([AABB2D(SVector(2.0f0, -2.0f0), SVector(2.0f0, -2.0f0)), AABB2D(SVector(2.0f0, -2.0f0), SVector(2.1f0, 3.1f0))])) == AABBUnion(AABB2D(SVector(2.0f0, -2.0f0), SVector(2.0f0, -2.0f0)), AABB2D(SVector(2.0f0, -2.0f0), SVector(2.1f0, 3.1f0))) # => true
julia> GetContainerAABB(Vector{AABB3D}([AABB3D(SVector(0.7f0, 0.8f0, 1.8f0), SVector(0.7f0, 0.8f0, 1.8f0)), AABB3D(SVector(0.7f0, -0.8f0, 1.8f0), SVector(0.7f0, 1.8f0, 1.8f0)), AABB3D(SVector(0.0f0, 0.0f0, 0.0f0), SVector(1.0f0, 1.0f0, 2.0f0))])) # => AABB3D(Float32[0.0, -0.8, 0.0], Float32[1.0, 1.8, 2.0])
```
"""
function GetContainerAABB(aabbs::Vector{AABB{N}})::AABB{N} where {N}
    @assert all(AABBValid.(aabbs)) "Error, invalid AABBs provided"
    return AABB{N}(reduce((a, b) -> min.(a, b), getfield.(aabbs, :min)), reduce((a, b) -> max.(a, b), getfield.(aabbs, :max)))
end

"""
```julia
function GetScaledAABBCenter(aabb::AABB{N}, container_aabb::AABB{N})::SVector{N, Float32} where {N}
```

Computes the center of an AABB (Axis Aligned Bounding Box) and scales it by a containing AABB, thus if the center of the AABB lies inside the containing AABB than the returned vector will have values between 0.0 and 1.0 (both inclusive [0.0, 1.0])

# Arguments
- `aabb`: the AABB of which this function is taking the center and scaling
- `container_aabb`: the AABB which hopefully contains the `aabb`

# Returns
- `SVector{N, Float32}`: the scaled vector where each value is the scaled (by the size of the `container_aabb` alongst the corresponding axis) and offset (by the corresponding min of `container_aabb`) value of the `aabb`'s center

# Examples
```julia
julia> GetScaledAABBCenter(AABB2D(SVector(4.0f0, 5.4f0), SVector(6.0f0, 5.6f0)), AABB2D(SVector(0.0f0, 5.0f0), SVector(10.0f0, 6.0f0))) # => Float32[0.5, 0.5]
julia> GetScaledAABBCenter(AABB2D(SVector(2.0f0, -2.0f0), SVector(2.0f0, -2.0f0)), AABB2D(SVector(2.0f0, -2.0f0), SVector(2.1f0, 3.1f0))) # => Float32[0.0, 0.0]
julia> GetScaledAABBCenter(AABB2D(SVector(-32.0f0, 3.2f0), SVector(-12.0f0, 3.4f0)), AABB2D(SVector(-1.0f0, 0.0f0), SVector(1.1f0, 1.1f0))) # => Float32[-10.0, 3.0]
julia> GetScaledAABBCenter(AABB3D(SVector(0.7f0, 0.8f0, 1.8f0), SVector(0.7f0, 0.8f0, 1.8f0)), AABB3D(SVector(0.0f0, 0.0f0, 0.0f0), SVector(1.0f0, 1.0f0, 2.0f0))) # => Float32[0.7, 0.8, 0.9]
```

# Notes
- if the `aabb` isn't a point and the `container_aabb` is computed as the min of mins and max of maxes than this might be a tiny bit wasteful  
"""
function GetScaledAABBCenter(aabb::AABB{N}, container_aabb::AABB{N})::SVector{N, Float32} where {N}
    @assert AABBValid(aabb) "Error, invalid AABB provided"
    @assert AABBValid(container_aabb) "Error, invalid container AABB provided"
    return ((aabb.min .+ 0.5 .* (aabb.max .- aabb.min) .- container_aabb.min) ./ (container_aabb.max .- container_aabb.min))
end

"""
```julia
function MortonCodeScaledCenter32(scaled_center::SVector{2, Float32})::UInt32
```

Quantizes the values of a 2D point from ranges of [0.0, 1.0] (both can be inclusive) into ranges [0, 65535] (both inclusive, 65535 == ((2^16) - 1)) and then creates a 32 bit morton code out of them

# Arguments
- `scaled_center`: a 2D point which should have values in ranges of [0.0, 1.0] (both inclusive)

# Returns
- `UInt32`: the resulting morton code which is the combination of the quantized axis
"""
function MortonCodeScaledCenter32(scaled_center::SVector{2, Float32})::UInt32
    @assert (all(scaled_center .>= 0.0) && all(scaled_center .<= 1.0)) "Error, invalid scaled center provided"
    return MortonCode2D32(UInt16(round(65535.0 * scaled_center[1])), UInt16(round(65535.0 * scaled_center[2])))
end

"""
```julia
function MortonCodeScaledCenter32(scaled_center::SVector{3, Float32})::UInt32
```

Quantizes the values of a 3D point from ranges of [0.0, 1.0] (both can be inclusive) into ranges [0, 1023] (both inclusive, 1023 == ((2^10) - 1)) and then creates a 32 (only 30 is used) bit morton code out of them

# Arguments
- `scaled_center`: a 3D point which should have values in ranges of [0.0, 1.0] (both inclusive)

# Returns
- `UInt32`: the resulting morton code which is the combination of the quantized axis, the 2 most significant bits are always 0
"""
function MortonCodeScaledCenter32(scaled_center::SVector{3, Float32})::UInt32
    @assert (all(scaled_center .>= 0.0) && all(scaled_center .<= 1.0)) "Error, invalid scaled center provided"
    return MortonCode3D30(UInt16(round(1023.0 * scaled_center[1])), UInt16(round(1023.0 * scaled_center[2])), UInt16(round(1023.0 * scaled_center[3])))
end

"""
```julia
function MortonCodeScaledCenter64(scaled_center::SVector{2, Float32})::UInt64
```

Quantizes the values of a 2D point from ranges of [0.0, 1.0] (both can be inclusive) into ranges [0, 4294967295] (both inclusive, 4294967295 == ((2^32) - 1)) and then creates a 64 bit morton code out of them

# Arguments
- `scaled_center`: a 2D point which should have values in ranges of [0.0, 1.0] (both inclusive)

# Returns
- `UInt32`: the resulting morton code which is the combination of the quantized axis
"""
function MortonCodeScaledCenter64(scaled_center::SVector{2, Float32})::UInt64
    @assert (all(scaled_center .>= 0.0) && all(scaled_center .<= 1.0)) "Error, invalid scaled center provided"
    return MortonCode2D64(UInt32(round(4294967295.0 * scaled_center[1])), UInt32(round(4294967295.0 * scaled_center[2])))
end

"""
```julia
function MortonCodeScaledCenter64(scaled_center::SVector{3, Float32})::UInt64
```

Quantizes the values of a 3D point from ranges of [0.0, 1.0] (both can be inclusive) into ranges [0, 2097151] (both inclusive, 2097151 == ((2^21) - 1)) and then creates a 64 (only 63 is used) bit morton code out of them

# Arguments
- `scaled_center`: a 3D point which should have values in ranges of [0.0, 1.0] (both inclusive)

# Returns
- `UInt32`: the resulting morton code which is the combination of the quantized axis, the top most bit is always 0
"""
function MortonCodeScaledCenter64(scaled_center::SVector{3, Float32})::UInt64
    @assert (all(scaled_center .>= 0.0) && all(scaled_center .<= 1.0)) "Error, invalid scaled center provided"
    return MortonCode3D63(UInt32(round(2097151.0 * scaled_center[1])), UInt32(round(2097151.0 * scaled_center[2])), UInt32(round(2097151.0 * scaled_center[3])))
end

"""
```julia
function CalculateMortonCodesForPrimitiveAABBs(primitive_aabbs::Vector{AABB{N}}, ::Type{MortonCodeT})::Vector{MortonCodeT} where {N, MortonCodeT<:AbstractMortonCodeType}
```

Takes a vector of AABBs (Axis Aligned Bounding Boxes) and first computes a bounding AABB that encapsulates all of the AABBs then using this bounding AABB scales the vector of AABBs before computing their morton codes

# Arguments
- `primitive_aabbs`: a vector of AABBs of the primitives
- `::Type{MortonCodeT}`: specifies if 32 bit or 64 bit morton codes should be used

# Returns
- `Vector{UInt32}`: the resulting vector of either 32 or 64 bit morton codes (specified in the functions argument)
"""
function CalculateMortonCodesForPrimitiveAABBs(primitive_aabbs::Vector{AABB{N}}, ::Type{MortonCodeT})::Vector{MortonCodeT} where {N, MortonCodeT<:AbstractMortonCodeType}
    @assert all(AABBValid.(primitive_aabbs)) "Error, invalid AABBs provided"
    @assert ((N == 2) || ( N == 3)) "Error, only dimensions 2 and 3 are supported"
    container_aabb::AABB{N} = GetContainerAABB(primitive_aabbs)
    if (MortonCodeT === UInt32)
        return MortonCodeScaledCenter32.(GetScaledAABBCenter.(primitive_aabbs, Ref(container_aabb)))
    elseif (MortonCodeT === UInt64)
        return MortonCodeScaledCenter64.(GetScaledAABBCenter.(primitive_aabbs, Ref(container_aabb)))
    else
        @assert (false) "Error, unsupported morton code bit depth"
    end
end

"""
```julia
function GetSortedMortonCodesWithIndecies(morton_codes::Vector{MortonCodeT})::Vector{PrimitiveIndexWithMortonCode{MortonCodeT}} where {MortonCodeT<:AbstractMortonCodeType}
```

Takes a vector of unsorted morton codes, creates pairs out of the morton codes and their indecies (0 based) and sorts them by the morton codes

# Arguments
- `morton_codes`: an unsorted vector of the primitives morton codes

# Returns
- `Vector{PrimitiveIndexWithMortonCode{MortonCodeT}}`: a sorted (by the morton codes) vector of pairs each having a morton code with their original indecies in the `morton_codes` buffer

# Examples
```julia
GetSortedMortonCodesWithIndecies(Vector{UInt32}([0, 9, 2, 8, 3, 7, 4, 6, 5])) # => PrimitiveIndexWithMortonCode{UInt32}[PrimitiveIndexWithMortonCode{UInt32}(0, 0), PrimitiveIndexWithMortonCode{UInt32}(2, 2), PrimitiveIndexWithMortonCode{UInt32}(4, 3), PrimitiveIndexWithMortonCode{UInt32}(6, 4), PrimitiveIndexWithMortonCode{UInt32}(8, 5), PrimitiveIndexWithMortonCode{UInt32}(7, 6), PrimitiveIndexWithMortonCode{UInt32}(5, 7), PrimitiveIndexWithMortonCode{UInt32}(3, 8), PrimitiveIndexWithMortonCode{UInt32}(1, 9)]
```
"""
function GetSortedMortonCodesWithIndecies(morton_codes::Vector{MortonCodeT})::Vector{PrimitiveIndexWithMortonCode{MortonCodeT}} where {MortonCodeT<:AbstractMortonCodeType}
    indecies_with_codes::Vector{PrimitiveIndexWithMortonCode{MortonCodeT}} = [PrimitiveIndexWithMortonCode(UInt32(index - 1), morton_code) for (index, morton_code) in enumerate(morton_codes)]
    return sort(indecies_with_codes, by = x -> x.morton_code)
end

"""
```julia
function Delta(sorted_morton_codes::Vector{MortonCodeT}, i::Int32, codeI::MortonCodeT, j::Int32)::Int32 where {MortonCodeT<:AbstractMortonCodeType}
```

A helper function which tries to find the most significant bit position at which the bits of 2 morton codes differ, if the 2 codes the same than it uses the morton codes indecies

# Arguments
- `sorted_morton_codes`: a sorted vector of the primitives morton codes
- `i`: the index of the first morton code (corresponds to the primitives index)
- `code_i`: the morton code associated with `i`
- `j`: the index of the second morton code (corresponds to the primitives index)

# Returns
- `Int32`: -1 if `j` is an invalid index into `sorted_morton_codes` if the 2 codes don't match then it is equal to the number of bits of the underlying type of the morton codes minus the most significant bits position in which the 2 codes differ if the 2 codes are equal then the primitive indecies are used instead of the morton codes and it is also offset by the types number of bits (this makes it like a secondary condition that is sometimes used in sortings)

# Notes
- this function might be undetermenistic (will result in hugely different tree if there are tiny differences in the sorted morton codes buffer) if different non stable sorts of the morton codes are used
"""
function Delta(sorted_morton_codes::Vector{MortonCodeT}, i::Int32, code_i::MortonCodeT, j::Int32)::Int32 where {MortonCodeT<:AbstractMortonCodeType}
    #@assert (issorted(sorted_morton_codes)) "Error, invalid sorted morton codes buffer provided"
    if ((j < 0) || (j > (length(sorted_morton_codes) - 1)))
        return -1
    end

    code_j::MortonCodeT = sorted_morton_codes[j + 1]
    
    if (code_i == code_j) 
        return (sizeof(MortonCodeT) * 8 + leading_zeros(xor(i, j)))
    end

    return leading_zeros(xor(code_i, code_j))
end

"""
```julia
function DetermineRange(sorted_morton_codes::Vector{MortonCodeType}, idx::Int32)::Tuple{Int32, Int32} where {MortonCodeT<:AbstractMortonCodeType}
```

Calculates the range of primitives in the subtree of each internal node using only the sorted morton codes and the internal nodes index (this is a unique and almost arbitrary index)

# Arguments
- `sorted_morton_codes`: a sorted vector of the primitives morton codes
- `idx`: the current internal nodes index

# Returns
- `Tuple{Int32, Int32}`: a range given by a start and end index corresponding to the primitives in the current nodes subtree 
"""
function DetermineRange(sorted_morton_codes::Vector{MortonCodeT}, idx::Int32)::Tuple{Int32, Int32} where {MortonCodeT<:AbstractMortonCodeType}
    #@assert (issorted(sorted_morton_codes)) "Error, invalid sorted morton codes buffer provided"
    code::MortonCodeT = sorted_morton_codes[idx + 1]
    deltaL::Int32 = Delta(sorted_morton_codes, idx, code, Int32(idx - 1))
    deltaR::Int32 = Delta(sorted_morton_codes, idx, code, Int32(idx + 1))
    d::Int32 = ((deltaR >= deltaL) ? 1 : -1)
    
    deltaMin::Int32 = min(deltaL, deltaR)
    lMax::Int32 = 2
    while (Delta(sorted_morton_codes, idx, code, (idx + (lMax * d))) > deltaMin) 
        lMax *= 2
    end

    l::Int32 = 0
    t::Int32 = (lMax >> 1)
    while (t > 0)
        if (Delta(sorted_morton_codes, idx, code, (idx + (l + t) * d)) > deltaMin) 
            l += t
        end
        
        t >>= 1
    end
    
    jdx::Int32 = idx + l * d
    
    return min(idx, jdx), max(idx, jdx)
end

"""
```julia
function FindSplit(sorted_morton_codes::Vector{MortonCodeType}, first::Int32, last::Int32)::Int32 where {MortonCodeT<:AbstractMortonCodeType}
```

Calculates an index inside a range using morton codes such that it makes the result balanced in terms of the morton codes

# Arguments
- `sorted_morton_codes`: a sorted vector of the primitives morton codes
- `first`: the start of the range
- `last`: the end of the range

# Returns
- `Int32`: an index between `first` and `last` that splits the morton codes somewhat evenly
"""
function FindSplit(sorted_morton_codes::Vector{MortonCodeT}, first::Int32, last::Int32)::Int32 where {MortonCodeT<:AbstractMortonCodeType}
    #@assert (issorted(sorted_morton_codes)) "Error, invalid sorted morton codes buffer provided"
    firstCode::MortonCodeT = sorted_morton_codes[first + 1]
    
    commonPrefix::Int32 = Delta(sorted_morton_codes, first, firstCode, last)
    
    split::Int32 = first
    stride::Int32 = (last - first + 1) >> 1
    
    if (((split + stride) < last) && (Delta(sorted_morton_codes, first, firstCode, (split + stride)) > commonPrefix))
        split += stride
    end
    
    while (stride > 1)
        stride = (stride + 1) >> 1
        if (((split + stride) < last) && (Delta(sorted_morton_codes, first, firstCode, (split + stride)) > commonPrefix))
            split += stride
        end
    end

    return split
end

"""
```julia
function InitLeafs(
    lbvh_nodes::Vector{LBVHNode{N}},
    primitive_indecies::Vector{UInt32},
    primitive_aabbs::Vector{AABB{N}},
    number_of_internal_nodes::UInt32, 
    number_of_leafs::UInt32
) where {N}
```

Initializes the leaf nodes with their primitive indexes and their AABBs (Axis Aligned Bounding Box)

# Arguments
- `lbvh_nodes`: the buffer (vector) containing the LBVH nodes (both the internal and leaf nodes)
- `primitive_indecies`: a vector containing the primitive indecies associated with the sorted morton codes
- `primitive_aabbs`: a vector of the primitive abbss
- `number_of_internal_nodes`: the number of internal nodes inside `lbvh_nodes`
- `number_of_leafs`: the number of leaf nodes inside `lbvh_nodes`
"""
function InitLeafs(
    lbvh_nodes::Vector{LBVHNode{N}},
    primitive_indecies::Vector{UInt32},
    primitive_aabbs::Vector{AABB{N}},
    number_of_internal_nodes::UInt32, 
    number_of_leafs::UInt32
) where {N}
    @assert (number_of_leafs > 0) "Error, can't construct any empty lbvh"
    @assert ((number_of_internal_nodes + 1) == number_of_leafs) "Error, number of internal nodes is incorrect"
    @assert (length(lbvh_nodes) == (number_of_internal_nodes + number_of_leafs)) "Error, invalid lbvh buffer provided"
    @assert (length(primitive_indecies) == number_of_leafs) "Error, invalid primitive indecies buffer provided"
    @assert (length(primitive_aabbs) == number_of_leafs) "Error, invalid primitive aabbs buffer provided"
    for i in 0:(number_of_leafs - 1)
        primitive_index::UInt32 = primitive_indecies[i + 1]
        primitive_aabb::AABB{N} = primitive_aabbs[primitive_index + 1]
        leaf_index::UInt32 = (number_of_internal_nodes + i)
        lbvh_nodes[leaf_index + 1] = LBVHNode{N}(INVALID_CHILD_POINTER, primitive_index, primitive_aabb)
    end
end

"""
```julia
function BuildHierarchy(
    lbvh_nodes::Vector{LBVHNode{N}},
    sorted_morton_codes::Vector{MortonCodeT},
    parent_information::Vector{UInt32},
    number_of_internal_nodes::UInt32
) where {N, MortonCodeT<:AbstractMortonCodeType}
```

Builds the LBVH tree by first calculating the current internal nodes range (the primitives between the starting and end indecies correspond to the primitives in the current internal nodes subtrees primitives) by the morton codes then it calculates the split index for determining where to split the range between its 2 childrens

# Arguments
- `lbvh_nodes`: the buffer (vector) containing the LBVH nodes (both the internal and leaf nodes)
- `sorted_morton_codes`: a sorted vector of the primitives morton codes
- `parent_information`: an out vector that will hold each nodes parent index (except root which won't be set) which is only used during the LBVH construction and this is why its seperate from the `lbvh_nodes` buffer
- `number_of_internal_nodes`: the number of internal nodes inside `lbvh_nodes`
"""
function BuildHierarchy(
    lbvh_nodes::Vector{LBVHNode{N}},
    sorted_morton_codes::Vector{MortonCodeT},
    parent_information::Vector{UInt32},
    number_of_internal_nodes::UInt32
) where {N, MortonCodeT<:AbstractMortonCodeType}
    @assert (length(lbvh_nodes) == (number_of_internal_nodes + number_of_internal_nodes + 1)) "Error, invalid lbvh buffer provided"
    @assert ((length(sorted_morton_codes) == (number_of_internal_nodes + 1)) && issorted(sorted_morton_codes)) "Error, invalid sorted morton codes buffer provided"
    @assert (length(parent_information) == (number_of_internal_nodes + number_of_internal_nodes + 1)) "Error, invalid parent information buffer provided"
    for internal_node_index in 0:(number_of_internal_nodes - 1)
        range_start, range_end = DetermineRange(sorted_morton_codes, Int32(internal_node_index))
        range_split = FindSplit(sorted_morton_codes, range_start, range_end)

        left_child_index::UInt32 = range_split + ((range_split == range_start) ? number_of_internal_nodes : 0)
        right_child_index::UInt32 = range_split + 1 + (((range_split + 1) == range_end) ? number_of_internal_nodes : 0)

        lbvh_nodes[internal_node_index + 1] = LBVHNode{N}(left_child_index, right_child_index, AABB{N}(SVector{N, Float32}(MVector{N, Float32}(undef)), SVector{N, Float32}(MVector{N, Float32}(undef))))

        parent_information[left_child_index + 1] = internal_node_index
        parent_information[right_child_index + 1] = internal_node_index
    end
end

"""
```julia
function CalculateBoundingBoxesBottomUp(
    lbvh_nodes::Vector{LBVHNode{N}},
    parent_information::Vector{UInt32},
    visitation_information::Vector{UInt32},
    number_of_internal_nodes::UInt32, 
    number_of_leafs::UInt32
) where {N}
```

From each leaf node it travels to its parent node and if it is the first one then it does nothing and finishes, if it is the second then it computes its parents AABB (Axis Aligned Bounding Box) by taking the union if the parents childrens AABBs and continues possibly up to the root

# Arguments
- `lbvh_nodes`: the buffer (vector) containing the LBVH nodes (both the internal and leaf nodes)
- `parent_information`: a vector that holds each nodes parent index (the roots value for obvious reasons won't be used)
- `visitation_information`: a vector that helps keep track how many child nodes have visited the current node at any given moment
- `number_of_internal_nodes`: the number of internal nodes inside `lbvh_nodes`
- `number_of_leafs`: the number of leaf nodes inside `lbvh_nodes`
"""
function CalculateBoundingBoxesBottomUp(
    lbvh_nodes::Vector{LBVHNode{N}},
    parent_information::Vector{UInt32},
    visitation_information::Vector{UInt32},
    number_of_internal_nodes::UInt32, 
    number_of_leafs::UInt32
) where {N}
    @assert (number_of_leafs > 0) "Error, empty lbvh is not allowed"
    @assert ((number_of_internal_nodes + 1) == number_of_leafs) "Error, number of internal nodes is incorrect"
    @assert (length(lbvh_nodes) == (number_of_internal_nodes + number_of_leafs)) "Error, invalid lbvh buffer provided"
    @assert (length(parent_information) == (number_of_internal_nodes + number_of_leafs)) "Error, invalid parent information buffer provided"
    @assert (length(visitation_information) == number_of_internal_nodes) "Error, invalid visitation info buffer provided"
    for i in 0:(number_of_leafs - 1)
        leaf_index::UInt32 = (number_of_internal_nodes + i)

        current_node_index::UInt32 = parent_information[leaf_index + 1]

        while (true)
            if (visitation_information[current_node_index + 1] == 0)
                visitation_information[current_node_index + 1] += 1
                break
            end

            current_node::LBVHNode{N} = lbvh_nodes[current_node_index + 1]
            left_child_node::LBVHNode{N} = lbvh_nodes[current_node.left_child_index + 1]
            right_child_node::LBVHNode{N} = lbvh_nodes[current_node.right_child_index_or_primitive_index + 1]

            current_node.aabb = AABBUnion(left_child_node.aabb, right_child_node.aabb)


            if (current_node_index == 0)
                break
            end

            current_node_index = parent_information[current_node_index + 1]
        end
    end
end

"""
```julia
function BuildLBVH(primitive_aabbs::Vector{AABB{N}}, ::Type{MortonCodeT})::Tuple{Vector{LBVHNode{N}}, UInt32, UInt32} where {N, MortonCodeT<:AbstractMortonCodeType}
```

Takes a vector of AABBs (Axis Aligned Bounding Boxes) and builds a LBVH from them

# Arguments
- `primitive_aabbs`: the vector containing the AABBs of the primitives from which the LBVH will be built, must have either 2D or 3D AABBs and have at least 1 item
- `::Type{MortonCodeT}`: specifies if 32 bit or 64 bit morton codes should be used

# Returns
- `Tuple{Vector{LBVHNode{N}}, UInt32, UInt32}`: the buffer (vector) containing the LBVH nodes (both the internal and leaf nodes) and the counts of the internal and leaf nodes in it
"""
function BuildLBVH(primitive_aabbs::Vector{AABB{N}}, ::Type{MortonCodeT})::Tuple{Vector{LBVHNode{N}}, UInt32, UInt32} where {N, MortonCodeT<:AbstractMortonCodeType}
    @assert (length(primitive_aabbs) > 0) "Error, can't construct empty lbvh"
    @assert ((N == 2) || ( N == 3)) "Error, only dimensions 2 and 3 are supported"

    sorted_morton_codes_with_primitive_indecies::Vector{PrimitiveIndexWithMortonCode{MortonCodeT}} = GetSortedMortonCodesWithIndecies(CalculateMortonCodesForPrimitiveAABBs(primitive_aabbs, MortonCodeT))

    number_of_leafs::UInt32 = UInt32(length(sorted_morton_codes_with_primitive_indecies))
    number_of_internal_nodes::UInt32 = (number_of_leafs - 1)

    lbvh_nodes::Vector{LBVHNode{N}} = Vector{LBVHNode{N}}(undef, (number_of_internal_nodes + number_of_leafs))
    parent_information::Vector{UInt32} = Vector{UInt32}(undef, (number_of_internal_nodes + number_of_leafs))
    visitation_information::Vector{UInt32} = Vector{UInt32}(undef, number_of_internal_nodes)

    for i in 0:(length(visitation_information) - 1)
        visitation_information[i + 1] = 0
    end

    primitive_indecies::Vector{UInt32} = getfield.(sorted_morton_codes_with_primitive_indecies, :primitive_index)
    sorted_morton_codes::Vector{MortonCodeT} = getfield.(sorted_morton_codes_with_primitive_indecies, :morton_code)

    InitLeafs(
        lbvh_nodes, 
        primitive_indecies, 
        primitive_aabbs, 
        number_of_internal_nodes, 
        number_of_leafs
    )

    BuildHierarchy(
        lbvh_nodes, 
        sorted_morton_codes, 
        parent_information, 
        number_of_internal_nodes
    )

    CalculateBoundingBoxesBottomUp(
        lbvh_nodes, 
        parent_information, 
        visitation_information, 
        number_of_internal_nodes, 
        number_of_leafs
    )

    return lbvh_nodes, number_of_leafs, number_of_internal_nodes
end



function LBVHToPrimitiveIntersection(
    lbvh_nodes::Vector{LBVHNode{N}},
    lbvh_primitives::Vector{LBVHPrimitiveT},
    number_of_internal_nodes::UInt32,
    number_of_leafs::UInt32,
    primitive::PrimitiveT,
    primitive_aabb::AABB{N},
    primitive_lbvh_primitive_intersection::Function,
    intersection_callback::Function
) where {N, LBVHPrimitiveT, PrimitiveT}
    @assert (number_of_leafs > 0) "Error, empty lbvh provided"
    @assert ((number_of_internal_nodes + 1) == number_of_leafs) "Error, number of internal nodes is incorrect"
    @assert (length(lbvh_nodes) == (number_of_internal_nodes + number_of_leafs)) "Error, invalid sized lbvh buffer provided"
    @assert (length(lbvh_primitives) == number_of_leafs) "Error, invalid primitives buffer provided"
    @assert AABBValid(primitive_aabb) "Error, invalid primitive AABB provided"

    stack::MVector{STACK_SIZE, UInt32} = MVector{STACK_SIZE, UInt32}(undef)
    stack_size::Int32 = 0

    current_node_index::UInt32 = 0
    current_node::LBVHNode{N} = lbvh_nodes[current_node_index + 1]

    while (true)
        is_node_internal::Bool = (current_node.left_child_index != INVALID_CHILD_POINTER)

        intersect_left_child::Bool = (is_node_internal && AABB2AABBIntersection(primitive_aabb, lbvh_nodes[current_node.left_child_index + 1].aabb))
        intersect_right_child::Bool = (is_node_internal && AABB2AABBIntersection(primitive_aabb, lbvh_nodes[current_node.right_child_index_or_primitive_index + 1].aabb))

        if (intersect_left_child)
            if (intersect_right_child)
                if (stack_size < length(stack))
                    stack[stack_size + 1] = current_node.right_child_index_or_primitive_index
                    stack_size += 1
                else
                    println("Warning, dropped node because stack is too small")
                end
            end
            current_node_index = current_node.left_child_index
            current_node = lbvh_nodes[current_node.left_child_index + 1]
        elseif (intersect_right_child)
            current_node_index = current_node.right_child_index_or_primitive_index
            current_node = lbvh_nodes[current_node.right_child_index_or_primitive_index + 1]
        else
            if (!is_node_internal)
                is_intersecting, intersection_infos... = primitive_lbvh_primitive_intersection(primitive, lbvh_primitives[current_node.right_child_index_or_primitive_index + 1])
                if (is_intersecting)
                    intersection_callback(intersection_infos...)
                end
            end

            if (stack_size == 0)
                break
            end

            current_node_index = stack[(stack_size - 1) + 1]
            stack_size -= 1

            current_node = lbvh_nodes[current_node_index + 1]
        end
    end
end

function LBVHToPrimitiveIntersection(
    lbvh_nodes::Vector{LBVHNode{N}},
    lbvh_primitives,
    number_of_internal_nodes::UInt32,
    number_of_leafs::UInt32,
    primitive,
    primitive_aabb::AABB{N},
    primitive_lbvh_primitive_intersection::Function,
    buffer::Vector,
    buffer_start_index::UInt
) where {N}
    @assert (number_of_leafs > 0) "Error, empty lbvh provided"
    @assert ((number_of_internal_nodes + 1) == number_of_leafs) "Error, number of internal nodes is incorrect"
    @assert (length(lbvh_nodes) == (number_of_internal_nodes + number_of_leafs)) "Error, invalid sized lbvh buffer provided"
    @assert (length(lbvh_primitives) == number_of_leafs) "Error, invalid primitives buffer provided"
    @assert AABBValid(primitive_aabb) "Error, invalid primitive AABB provided"

    stack::MVector{STACK_SIZE, UInt32} = MVector{STACK_SIZE, UInt32}(undef)
    stack_size::Int32 = 0

    current_node_index::UInt32 = 0
    current_node::LBVHNode{N} = lbvh_nodes[current_node_index + 1]

    buffer_current_index::UInt = buffer_start_index

    while (true)
        is_node_internal::Bool = (current_node.left_child_index != INVALID_CHILD_POINTER)

        intersect_left_child::Bool = (is_node_internal && AABB2AABBIntersection(primitive_aabb, lbvh_nodes[current_node.left_child_index + 1].aabb))
        intersect_right_child::Bool = (is_node_internal && AABB2AABBIntersection(primitive_aabb, lbvh_nodes[current_node.right_child_index_or_primitive_index + 1].aabb))

        if (intersect_left_child)
            if (intersect_right_child)
                if (stack_size < length(stack))
                    stack[stack_size + 1] = current_node.right_child_index_or_primitive_index
                    stack_size += 1
                else
                    println("Warning, dropped node because stack is too small")
                end
            end
            current_node_index = current_node.left_child_index
            current_node = lbvh_nodes[current_node.left_child_index + 1]
        elseif (intersect_right_child)
            current_node_index = current_node.right_child_index_or_primitive_index
            current_node = lbvh_nodes[current_node.right_child_index_or_primitive_index + 1]
        else
            if (!is_node_internal)
                intersection = primitive_lbvh_primitive_intersection(primitive, lbvh_primitives[UInt(current_node.right_child_index_or_primitive_index + 1)])
                if ((intersection !== nothing) && buffer_current_index < length(buffer))
                    buffer[buffer_current_index + 1] = intersection
                    buffer_current_index += 1
                end
            end

            if (stack_size == 0)
                break
            end

            current_node_index = stack[(stack_size - 1) + 1]
            stack_size -= 1

            current_node = lbvh_nodes[current_node_index + 1]
        end
    end

    return (buffer_current_index - buffer_start_index)
end



export BuildLBVH
export LBVHToPrimitiveIntersection
