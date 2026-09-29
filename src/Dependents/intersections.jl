const BRUTE_FORCE_LBVH_THRESHOLD = 100
const MORTON_CODE_TYPE = UInt64

const _intersection_cache::Dict{NodeHandle, NodeHandle} = Dict{NodeHandle, NodeHandle}()
on_window_clear(() -> empty!(_intersection_cache))

# ? ---------------------------------
# ! Graph shenanigans
# ? ---------------------------------

# _UndefinedAccelerator => | PrimitivesOf                       (PrimitivesOf(elements[node.parent_h[1]]) <: PrimitivesOf{<:Primitive})
#                          | Tuple{LBVHCache{3},<:PrimitivesOf} (PrimitivesOf(elements[node.parent_h[1]]) <: PrimitivesOf{<:AABBPrimitive3D})
_define_accelerator(primitives::PrimitivesOf, ::Union{LBVHCache{3},Nothing}) = primitives
function _define_accelerator(primitives::PrimitivesOf{<:AABBPrimitive3D}, lbvh::Union{LBVHCache{3},Nothing})
    cache::LBVHCache{3} = lbvh === nothing ? LBVHCache{3}() : lbvh
    if length(primitives) >= BRUTE_FORCE_LBVH_THRESHOLD
        BuildLBVH!(cache,map(GetAABB, primitives),MORTON_CODE_TYPE)
    else
        # Keep the allocation, but mark it empty / stale
        cache.number_of_leafs = UInt32(0)
        cache.number_of_internal_nodes = UInt32(0)
    end
    return tuple(cache,primitives)
end

_reuse_lbvh(::Any) = nothing
_reuse_lbvh(accelerator::Tuple{LBVHCache{3},<:PrimitivesOf}) = accelerator[1]

struct _UndefinedAccelerator end
eval_geometry_node(element::Union{_UndefinedAccelerator, PrimitivesOf, Tuple{LBVHCache{3},<:PrimitivesOf}}, node::GeometryPlotNode, elements::Vector{Any}) =
    _define_accelerator(PrimitivesOf(elements[node.parent_h[1]]), _reuse_lbvh(element))

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
function FindIntersections(self::IntersectionCalculator, shapes_a::Tuple{LBVHCache{3},<:PrimitivesOf{<:AABBPrimitive}}, shapes_b::Tuple{LBVHCache{3},<:PrimitivesOf{<:AABBPrimitive}})
    iter_a = shapes_a[2]
    iter_b = shapes_b[2]
    has_lbvh_a = shapes_a[1].number_of_leafs > 0
    has_lbvh_b = shapes_b[1].number_of_leafs > 0
    if !has_lbvh_a && !has_lbvh_b
        FindIntersections(self, iter_a, iter_b)
    else
        empty!(self.intersections)
        if has_lbvh_a && (!has_lbvh_b || length(iter_a) <= length(iter_b))
            LBVHIntersections(self, shapes_a, shapes_b)
        else
            LBVHIntersections(self, shapes_b, shapes_a)
        end
    end
    return self
end

# Mixed (fallback to brute-force)
_primitives(primitives::PrimitivesOf) = primitives
_primitives(accelerator::Tuple{LBVHCache{3},<:PrimitivesOf}) = accelerator[2]
FindIntersections(self::IntersectionCalculator, shapes_a, shapes_b) = FindIntersections(self, _primitives(shapes_a), _primitives(shapes_b))

function LBVHIntersections(self::IntersectionCalculator, geometry_lbvh::Tuple{LBVHCache{3},<:PrimitivesOf{<:AABBPrimitive}}, geometry_b::Tuple{LBVHCache{3},<:PrimitivesOf{<:AABBPrimitive}})
    lbvh = geometry_lbvh[1]
    
    shapes_lbvh = geometry_lbvh[2]
    shapes_b = geometry_b[2]
            
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
# ! Intersection
# ? ---------------------------------

function getPrimitivesT(::Type{<:PrimitivesOf{T}})::Type{T} where {T <: Primitive}
    return T
end

function InferPrimitivesT(geometry::NodeHandle)
    NodeT::Type = typeof(get_element(geometry))
    PrimitivesOfT::Type = InferSingletonDefinitionFor(NodeT,PrimitivesOf,PrimitivesOf)
    return getPrimitivesT(PrimitivesOfT)
end

function InferPrimitiveToPrimitiveIntersection(::Type{U},::Type{V})::Type where {U,V <: Primitive}
    Base.nonnothingtype(InferSingletonDefinitionFor(Tuple{U,V},PrimitiveToPrimitiveIntersection,Union{Any,Nothing}))
end

function _get_accelerator!(geometry::NodeHandle)::NodeHandle
    get!(_intersection_cache,geometry) do
        add_node!(_UndefinedAccelerator();parents=[geometry])
    end
end

function Intersection(geometry1::NodeHandle,geometry2::NodeHandle; maxIntersectionNum=25)
    # I dont like that we need to infer the return type of the the parent intersection
    T12::Type = InferPrimitiveToPrimitiveIntersection(InferPrimitivesT(geometry1),InferPrimitivesT(geometry2))
    accelerator1 = _get_accelerator!(geometry1)
    accelerator2 = _get_accelerator!(geometry2)
    return add_node!(IntersectionCalculator{T12}(UInt(maxIntersectionNum));parents=[accelerator1, accelerator2])
end

export Intersection