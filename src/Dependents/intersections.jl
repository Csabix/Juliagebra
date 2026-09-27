const BRUTE_FORCE_LBVH_THRESHOLD = 100
const MORTON_CODE_TYPE = UInt64

# ? ---------------------------------
# ! IntersectionCalculator{T}
# ? ---------------------------------

struct IntersectionCalculator{T}
    intersections::Vector{T}
    limit::UInt

    function IntersectionCalculator{T}(maxIntersectionNum::UInt) where T
        @assert maxIntersectionNum > 0 "Intersection count must be larger than 0"
        new(sizehint!(T[],maxIntersectionNum),maxIntersectionNum)
    end
end

# Brute-force
function FindIntersections(self::IntersectionCalculator{T}, shapes_a::PrimitivesOf{U}, shapes_b::PrimitivesOf{V}) where {T,U,V}
    empty!(self.intersections)
    for (b,a) in Iterators.product(shapes_b,shapes_a)
        maybe_intersection::Union{T,Nothing} = PrimitiveToPrimitiveIntersection(a, b)
        if maybe_intersection !== nothing
            intersection::T = maybe_intersection::T
            push!(self.intersections, intersection)
            length(self.intersections) >= self.limit && break
        end
    end
    return self
end

# LBVH
function FindIntersections(self::IntersectionCalculator,shapes_a::LazyLBVH{PrimitivesOf{U}}, shapes_b::LazyLBVH{PrimitivesOf{V}}) where {U,V <: AABBPrimitive}
    if ((length(shapes_a._iter) < BRUTE_FORCE_LBVH_THRESHOLD) && (length(shapes_b._iter) < BRUTE_FORCE_LBVH_THRESHOLD))
        FindIntersections(self, shapes_a._iter, shapes_b._iter)
    else
        empty!(self.intersections)
        if (length(shapes_a._iter) <= length(shapes_b._iter))
            LBVHIntersections(self, shapes_a, shapes_b)
        else
            LBVHIntersections(self, shapes_b, shapes_a)
        end
    end
    return self
end

function LBVHIntersections(self::IntersectionCalculator, geometry_lbvh::LazyLBVH{PrimitivesOf{U}}, geometry_b::LazyLBVH{PrimitivesOf{V}}) where {U,V <: AABBPrimitive}    
    lbvh = getLBVH(geometry_lbvh)
    
    shapes_lbvh = geometry_lbvh._iter
    shapes_b = geometry_b._iter
            
    for primitive_b in shapes_b
        length(self.intersections) >= self.limit && break
        LBVHToPrimitiveIntersection(
            lbvh.lbvh_nodes,
            shapes_lbvh,
            lbvh.number_of_internal_nodes,
            lbvh.number_of_leafs,
            primitive_b,
            GetAABB(primitive_b),
            PrimitiveToPrimitiveIntersection,
            self.intersections,
            self.limit
        )
    end
    return nothing
end

function eval_geometry_node(element::IntersectionCalculator, node::GeometryPlotNode, elements::Vector{Any})
    A = convert_callback_entry(elements[node.parent_h[1]])
    B = convert_callback_entry(elements[node.parent_h[2]])
    return FindIntersections(element, A, B)
end

Base.checkbounds(Bool,self::IntersectionCalculator,idx) = return 0 < idx <= self.limit
function Base.getindex(self::IntersectionCalculator{T}, idx = 1)::Union{T,Nothing} where T
    if checkbounds(Bool, self.intersections, idx)
        return @inbounds self.intersections[idx]
    else
        return nothing
    end
end

# ? ---------------------------------
# ! IntersectionCalculator(T)
# ? ---------------------------------

function IntersectionCalculator(T12::Type, geometry1::NodeHandle, geometry2::NodeHandle; maxIntersectionNum=25)
    # ! Note that in the callback:
    # ! - data: IntersectionCalculator{T12}
    # ! - geometry1: PrimtiviesOf{T1<:Primitive} or LazyLBVH{PrimitivesOf{T1<:AABBPrimitive}}
    # ! - geometry2: PrimtiviesOf{T2<:Primitive} or LazyLBVH{PrimitivesOf{T2<:AABBPrimitive}}
    add_node!(IntersectionCalculator{T12}(UInt(maxIntersectionNum));parents=[geometry1,geometry2])
end

# ? ---------------------------------
# ! Intersection
# ? ---------------------------------

function getPrimitivesT(::Type{<:PrimitivesOf{T}})::Type{T} where {T <: Primitive}
    return T
end

function InferPrimitivesT(geometry::NodeHandle)
    NodeT::Type = typeof(get_element(geometry))
    CallbackDpEntryT::Type = InferSingletonDefinitionFor(NodeT,convert_callback_entry,Any)
    PrimitivesOfT::Type = InferSingletonDefinitionFor(CallbackDpEntryT,PrimitivesOf,PrimitivesOf)
    return getPrimitivesT(PrimitivesOfT)
end

function InferPrimitiveToPrimitiveIntersection(::Type{U},::Type{V})::Type where {U,V <: Primitive}
    return InferSingletonDefinitionFor(Tuple{U,V},PrimitiveToPrimitiveIntersection,Union{Any,Nothing})
end

function Intersection(geometry1::NodeHandle,geometry2::NodeHandle; maxIntersectionNum=25)
    T1::Type = InferPrimitivesT(geometry1)
    T2::Type = InferPrimitivesT(geometry2)
    T12::Type = InferPrimitiveToPrimitiveIntersection(T1,T2)
    return _Intersection(geometry1,geometry2,T1,T2,T12; maxIntersectionNum = maxIntersectionNum)
end

function _Intersection(geometry1::NodeHandle,geometry2::NodeHandle, T1::Type{<:Primitive}, T2::Type{<:Primitive}, T12::Type; maxIntersectionNum=25)
    global implicitApp

    call = function (g)
        return PrimitivesOf(g)
    end

    gvh1::NodeHandle = getIntersectionPrimitiveIter!(implicitApp._optimizer,geometry1,T1,call)
    gvh2::NodeHandle = getIntersectionPrimitiveIter!(implicitApp._optimizer,geometry2,T2,call)

    return IntersectionCalculator(T12, gvh1, gvh2; maxIntersectionNum=maxIntersectionNum)
end

function _Intersection(geometry1::NodeHandle,geometry2::NodeHandle, T1::Type{<:AABBPrimitive}, T2::Type{<:AABBPrimitive}, T12::Type; maxIntersectionNum=25)
    global implicitApp

    llbvh1::NodeHandle = getIntersectionPrimitiveIter!(implicitApp._optimizer,geometry1,T1)
    llbvh2::NodeHandle = getIntersectionPrimitiveIter!(implicitApp._optimizer,geometry2,T2)

    return IntersectionCalculator(T12, llbvh1, llbvh2; maxIntersectionNum=maxIntersectionNum)
end

export Intersection

function ParametricCurve(it::IntersectionCalculator{<:Union{Nothing,PSegment}}; maxIntersectionNum=25, color=(0.941, 0.914, 0.141))
    return ParametricCurve(range(0, maxIntersectionNum * 3 - 1, maxIntersectionNum * 3), [it]; color) do t, it 
        idx = floor(Int, t)
        idx1 = div(idx,3) + 1
        idx2 = idx % 3 + 1

        iit = it[idx1]

        if isnothing(iit)
            return Vec3DNan
        end

        if idx2 == 1
            return iit.p0
        elseif  idx2 == 2
            return iit.p1
        else  
            @assert idx2 == 3 "idx2 must be 3!"
            return Vec3DNan
        end
    end
end
