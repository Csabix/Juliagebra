const BRUTE_FORCE_LBVH_THRESHOLD = 100
const MORTON_CODE_TYPE = UInt64

# ? ---------------------------------
# ! IntersectionData{T}
# ? ---------------------------------

mutable struct IntersectionData{T}
    _foundIntersectionNum::UInt
    _intersections::Vector{T}

    function IntersectionData{T}(maxIntersectionNum) where T
        foundIntersectionNum = 0
        intersecions = Vector{T}(undef, maxIntersectionNum)
        new(foundIntersectionNum,intersecions)
    end
end

function FindIntersections(self::IntersectionData,shapes_a::PrimitivesOf{U}, shapes_b::PrimitivesOf{V}) where {U,V}
    
end

function FindIntersections(self::IntersectionData,shapes_a::PrimitivesOf{U}, shapes_b::PrimitivesOf{V}) where {U <: AABBPrimitive,V <: AABBPrimitive}
    self._foundIntersectionNum = 0

    if ((length(shapes_a) < BRUTE_FORCE_LBVH_THRESHOLD) && (length(shapes_b) < BRUTE_FORCE_LBVH_THRESHOLD))
        BruteForceIntersections(self, shapes_a, shapes_b)
    else
        if (length(shapes_a) <= length(shapes_b))
            LBVHIntersections(self, shapes_a, shapes_b)
        else
            LBVHIntersections(self, shapes_b, shapes_a)
        end
    end
end

function BruteForceIntersections(self::IntersectionData{T}, shapes_a::PrimitivesOf{U}, shapes_b::PrimitivesOf{V}) where {T,U,V}
    for primitive_a in shapes_a
        for primitive_b in shapes_b
            intersection::Union{T,Nothing} = PrimitiveToPrimitiveIntersection(primitive_a, primitive_b)
            if (intersection !== nothing)
                if (self._foundIntersectionNum < length(self._intersections))
                    self._intersections[self._foundIntersectionNum + 1] = intersection
                    self._foundIntersectionNum += 1
                else
                    return
                end
            end
        end
    end
end

function LBVHIntersections(self::IntersectionData, shapes_lbvh::PrimitivesOf{U}, shapes_b::PrimitivesOf{V}) where {U <: AABBPrimitive,V <: AABBPrimitive}
    lbvh_nodes, number_of_leafs, number_of_internal_nodes = BuildLBVH(map(GetAABB, shapes_lbvh), MORTON_CODE_TYPE)
            
    for primitive_b in shapes_b
        number_of_intersections = LBVHToPrimitiveIntersection(
            lbvh_nodes,
            shapes_lbvh,
            number_of_internal_nodes,
            number_of_leafs,
            primitive_b,
            GetAABB(primitive_b),
            PrimitiveToPrimitiveIntersection,
            self._intersections,
            self._foundIntersectionNum
        )
        self._foundIntersectionNum += number_of_intersections

        if (self._foundIntersectionNum >= length(self._intersections)) # the > is not necesseary its just for extra safety
            return
        end
    end
end

# ? ---------------------------------
# ! IntersectionResult{T}
# ? ---------------------------------

mutable struct IntersectionResult{T}
    _data::IntersectionData{T}

    function IntersectionResult{T}(data::IntersectionData{T}) where T
        new(data)
    end
end

function Base.getindex(self::IntersectionResult{T}, idx = 1)::Union{T,Nothing} where T
    if (1 <= idx && idx <= self._data._foundIntersectionNum)
        return self._data._intersections[idx]
    else
        return nothing
    end
end

# ? ---------------------------------
# ! Intersection
# ? ---------------------------------

# TODO: Restrain PlanDNA to intersectable plans?

function Intersection(geometry1::PlanDNA, geometry2::PlanDNA; maxIntersectionNum = 25)::GenericValueHolderPlan
    
    # TODO automatic T1, T2 infer
    
    T1::Type = TOfPrimitivesOf(geometry1)
    T2::Type = TOfPrimitivesOf(geometry2)

    call = function (g::DependentDNA)
        return PrimitivesOf(g)
    end

    gvh1 = GenericValueHolder(call,PrimitivesOf{T1},[geometry1])
    gvh2 = GenericValueHolder(call,PrimitivesOf{T2},[geometry2])

    T12::Type = TypeOfPrimitiveToPrimitiveIntersection(T1,T2)
    results = UnaryValueHolder(IntersectionData{T12}(maxIntersectionNum)) do unary
        return GenericValueHolder(IntersectionResult{T12},[unary,gvh1,gvh2]) do unary, gvh1, gvh2
            FindIntersections(unary,gvh1,gvh2)
            return IntersectionResult{T12}(unary)
        end
    end

    return results
end

export Intersection
