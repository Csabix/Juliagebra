
# ? ---------------------------------
# ! LBVHCache
# ? ---------------------------------

mutable struct LBVHCache{N}
    number_of_leafs::UInt32
    number_of_internal_nodes::UInt32
    lbvh_nodes::Vector{LBVHNode{N}}

    function LBVHCache{N}() where N
        number_of_leafs = UInt32(0)
        number_of_internal_nodes = UInt32(0)
        lbvh_nodes = Vector{LBVHNode{N}}()
        new(number_of_leafs,number_of_internal_nodes,lbvh_nodes)
    end
end

function BuildLBVH!(lbvh::LBVHCache{N},primitive_aabbs::Vector{AABB{N}}, ::Type{MortonCodeT}) where {N, MortonCodeT<:AbstractMortonCodeType}
    @assert (length(primitive_aabbs) > 0) "Error, can't construct empty lbvh"
    @assert ((N == 2) || ( N == 3)) "Error, only dimensions 2 and 3 are supported"

    sorted_morton_codes_with_primitive_indecies::Vector{PrimitiveIndexWithMortonCode{MortonCodeT}} = GetSortedMortonCodesWithIndecies(CalculateMortonCodesForPrimitiveAABBs(primitive_aabbs, MortonCodeT))

    # ? Just updating the cache
    lbvh.number_of_leafs = UInt32(length(sorted_morton_codes_with_primitive_indecies))
    lbvh.number_of_internal_nodes = (lbvh.number_of_leafs - 1)
    Base.resize!(lbvh.lbvh_nodes,(lbvh.number_of_internal_nodes + lbvh.number_of_leafs))

    parent_information::Vector{UInt32} = Vector{UInt32}(undef, (lbvh.number_of_internal_nodes + lbvh.number_of_leafs))
    visitation_information::Vector{UInt32} = Vector{UInt32}(undef, lbvh.number_of_internal_nodes)

    for i in 0:(length(visitation_information) - 1)
        visitation_information[i + 1] = 0
    end

    primitive_indecies::Vector{UInt32} = getfield.(sorted_morton_codes_with_primitive_indecies, :primitive_index)
    sorted_morton_codes::Vector{MortonCodeT} = getfield.(sorted_morton_codes_with_primitive_indecies, :morton_code)

    InitLeafs(
        lbvh.lbvh_nodes, 
        primitive_indecies, 
        primitive_aabbs, 
        lbvh.number_of_internal_nodes, 
        lbvh.number_of_leafs
    )

    BuildHierarchy(
        lbvh.lbvh_nodes, 
        sorted_morton_codes, 
        parent_information, 
        lbvh.number_of_internal_nodes
    )

    CalculateBoundingBoxesBottomUp(
        lbvh.lbvh_nodes, 
        parent_information, 
        visitation_information, 
        lbvh.number_of_internal_nodes, 
        lbvh.number_of_leafs
    )

end