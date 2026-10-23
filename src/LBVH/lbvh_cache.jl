
# ? ---------------------------------
# ! LBVHCache
# ? ---------------------------------

mutable struct LBVHCache{N, MortonCodeT<:AbstractMortonCodeType}
    number_of_leafs::UInt32
    number_of_internal_nodes::UInt32
    lbvh_nodes::Vector{LBVHNode{N}}
    unsorted_morton_codes::Vector{MortonCodeT}
    morton_codes::Vector{PrimitiveIndexWithMortonCode{MortonCodeT}}
    parent_information::Vector{UInt32}
    visitation_information::Vector{UInt32}
    primitive_indecies::Vector{UInt32}
    sorted_morton_codes::Vector{MortonCodeT}

    function LBVHCache{N, MortonCodeT}() where {N,MortonCodeT<:AbstractMortonCodeType}
        number_of_leafs = UInt32(0)
        number_of_internal_nodes = UInt32(0)
        lbvh_nodes = Vector{LBVHNode{N}}()
        unsorted_morton_codes = Vector{MortonCodeT}()
        morton_codes = Vector{PrimitiveIndexWithMortonCode{MortonCodeT}}()
        parent_information = Vector{UInt32}()
        visitation_information = Vector{UInt32}()
        primitive_indecies = Vector{UInt32}()
        sorted_morton_codes = Vector{MortonCodeT}()
        new(number_of_leafs,number_of_internal_nodes,lbvh_nodes,
            unsorted_morton_codes,morton_codes,parent_information,visitation_information,primitive_indecies,sorted_morton_codes)
    end
end

function BuildLBVH!(lbvh::LBVHCache{N,MortonCodeT},primitive_aabbs::Vector{AABB{N}}) where {N, MortonCodeT<:AbstractMortonCodeType}
    @assert (length(primitive_aabbs) > 0) "Error, can't construct empty lbvh"
    @assert ((N == 2) || ( N == 3)) "Error, only dimensions 2 and 3 are supported"

    CalculateMortonCodesForPrimitiveAABBs!(lbvh.unsorted_morton_codes, primitive_aabbs)
    GetSortedMortonCodesWithIndecies(lbvh.unsorted_morton_codes, lbvh.morton_codes)

    # ? Just updating the cache
    lbvh.number_of_leafs = UInt32(length(lbvh.morton_codes))
    lbvh.number_of_internal_nodes = (lbvh.number_of_leafs - 1)
    Base.resize!(lbvh.lbvh_nodes,(lbvh.number_of_internal_nodes + lbvh.number_of_leafs))

    Base.resize!(lbvh.parent_information, lbvh.number_of_internal_nodes + lbvh.number_of_leafs)
    Base.resize!(lbvh.visitation_information, lbvh.number_of_internal_nodes)

    for i in 0:(length(lbvh.visitation_information) - 1)
        lbvh.visitation_information[i + 1] = 0
    end

    Base.resize!(lbvh.primitive_indecies, Base.length(lbvh.morton_codes))
    Base.resize!(lbvh.sorted_morton_codes, Base.length(lbvh.morton_codes))
    @inbounds for i in eachindex(lbvh.sorted_morton_codes)
        lbvh.primitive_indecies[i] = lbvh.morton_codes[i].primitive_index
        lbvh.sorted_morton_codes[i] = lbvh.morton_codes[i].morton_code
    end

    InitLeafs(
        lbvh.lbvh_nodes, 
        lbvh.primitive_indecies, 
        primitive_aabbs, 
        lbvh.number_of_internal_nodes, 
        lbvh.number_of_leafs
    )

    BuildHierarchy(
        lbvh.lbvh_nodes, 
        lbvh.sorted_morton_codes, 
        lbvh.parent_information, 
        lbvh.number_of_internal_nodes
    )

    CalculateBoundingBoxesBottomUp(
        lbvh.lbvh_nodes, 
        lbvh.parent_information, 
        lbvh.visitation_information, 
        lbvh.number_of_internal_nodes, 
        lbvh.number_of_leafs
    )
end