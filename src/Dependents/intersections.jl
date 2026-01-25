const BRUTE_FORCE_LBVH_THRESHOLD = 100
const MORTON_CODE_TYPE = UInt64

# ? ---------------------------------
# ! IntersectionDataPlan{T}
# ? ---------------------------------

mutable struct IntersectionDataPlan{T} <: PlanDNA
    _plan::Plan
    _maxIntersectionNum::UInt

    function IntersectionDataPlan{T}(plan1::PlanDNA,plan2::PlanDNA,maxIntersectionNum::UInt) where T
        plans = Vector{PlanDNA}([plan1,plan2])
        # TODO: Enforce this:
        # ! Note that in the callback:
        # ! - data: IntersectionData{T12}
        # ! - geometry1: GenericValueHolder{PrimtiviesOf{T1<:Primitive}} or LazyLBVH{PrimitivesOf{T1<:AABBPrimitive}}
        # ! - geometry2: GenericValueHolder{PrimtiviesOf{T2<:Primitive}} or LazyLBVH{PrimitivesOf{T2<:AABBPrimitive}}
        callback = function (data,geometry1,geometry2)
            FindIntersections(data,geometry1,geometry2)
            return nothing
        end
        plan = Plan(callback,plans)
        new(plan,maxIntersectionNum)
    end
end

_Plan_(self::IntersectionDataPlan)::Plan = return self._plan

# ? ---------------------------------
# ! IntersectionData{T}
# ? ---------------------------------

mutable struct IntersectionData{T} <: DependentDNA
    _dependent::Dependent
    _foundIntersectionNum::UInt
    _intersections::Vector{T}

    function IntersectionData{T}(plan::IntersectionDataPlan{T}) where T
        dependent = Dependent(plan)
        foundIntersectionNum = 0
        intersections = Vector{T}(undef,plan._maxIntersectionNum)
        self = new(dependent,foundIntersectionNum,intersections)
        onNodeEval(self)
        return self
    end
end

_Dependent_(self::IntersectionData)::Dependent = self._dependent
getGeometry1(self::IntersectionData)::DependentDNA = return getGraphParent(self,1)
getGeometry2(self::IntersectionData)::DependentDNA = return getGraphParent(self,2)

evalCallbackDpEntry(self::IntersectionData)::IntersectionData = return self
onNodeEval(self::IntersectionData) = evalCallbackDp(self; callbackParams = (self))
evalCallbackDpReturn(self::IntersectionData,::Nothing) = return nothing

function FindIntersections(self::IntersectionData,shapes_a::PrimitivesOf,shapes_b::PrimitivesOf)
    BruteForceIntersections(self,shapes_a,shapes_b)
end

function FindIntersections(self::IntersectionData,shapes_a::LazyLBVH{PrimitivesOf{U}}, shapes_b::LazyLBVH{PrimitivesOf{V}}) where {U <: AABBPrimitive,V <: AABBPrimitive}
    self._foundIntersectionNum = 0

    if ((length(shapes_a) < BRUTE_FORCE_LBVH_THRESHOLD) && (length(shapes_b) < BRUTE_FORCE_LBVH_THRESHOLD))
        BruteForceIntersections(self, shapes_a._iter, shapes_b._iter)
    else
        if (length(shapes_a._iter) <= length(shapes_b._iter))
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

function LBVHIntersections(self::IntersectionData, geometry_lbvh::LazyLBVH{PrimitivesOf{U}}, geometry_b::LazyLBVH{PrimitivesOf{V}}) where {U <: AABBPrimitive,V <: AABBPrimitive}
    lbvh_nodes, number_of_leafs, number_of_internal_nodes = getLBVH(geometry_lbvh)
    shapes_b = geometry_b._iter
            
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

function Base.getindex(self::IntersectionData{T}, idx = 1)::Union{T,Nothing} where T
    if (1 <= idx && idx <= self._data._foundIntersectionNum)
        return self._data._intersections[idx]
    else
        return nothing
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

function getPrimitivesT(::Type{<:PrimitivesOf{T}})::Type{T} where {T <: Primitive}
    return T
end

function InferPrimitivesT(geometry::PlanDNA)
    DependentT::Type = InferSingletonDefinitionFor(geometry,Plan2Dependent,DependentDNA)
    PrimitivesOfT::Type = InferSingletonDefinitionFor(DependentT,PrimitivesOf,PrimitivesOf)
    return getPrimitivesT(PrimitivesOfT)
end

function InferPrimitiveToPrimitiveIntersection(::Type{U},::Type{V})::Type where {U,V <: Primitive}
    return InferSingletonDefinitionFor(Tuple{U,V},PrimitiveToPrimitiveIntersection,Union{Any,Nothing})
end

function Intersection(geometry1::PlanDNA, geometry2::PlanDNA; maxIntersectionNum = 25)::GenericValueHolderPlan
    
    T1::Type = InferPrimitivesT(geometry1)
    T2::Type = InferPrimitivesT(geometry2)
    T12::Type = InferPrimitiveToPrimitiveIntersection(T1,T2)

    call = function (g::DependentDNA)
        return PrimitivesOf(g)
    end

    gvh1 = GenericValueHolder(call,PrimitivesOf{T1},[geometry1])
    gvh2 = GenericValueHolder(call,PrimitivesOf{T2},[geometry2])

    results = UnaryValueHolder(IntersectionData{T12}(maxIntersectionNum)) do unary
        return GenericValueHolder(IntersectionResult{T12},[unary,gvh1,gvh2]) do unary, gvh1, gvh2
            FindIntersections(unary,gvh1,gvh2)
            return IntersectionResult{T12}(unary)
        end
    end

    return results
end

# TODO: Finish this.

function Intersection(geometry1::PlanDNA,geometry2::PlanDNA; maxIntersectionNum = 25)
    T1::Type = InferPrimitivesT(geometry1)
    T2::Type = InferPrimitivesT(geometry2)
    T12::Type = InferPrimitiveToPrimitiveIntersection(T1,T2)

    
end

function _Intersection(geometry1::PlanDNA,geometry2::PlanDNA, T1::Type{<:Primitive}, T2::Type{<:Primitive}, T12::Type; maxIntersectionNum = 25, )
    call = function (g)
        return PrimitivesOf(g)
    end

    gvh1 = GenericValueHolder(call,PrimitivesOf{T1},[geometry1])
    gvh2 = GenericValueHolder(call,PrimitivesOf{T2},[geometry2])


end

export Intersection
