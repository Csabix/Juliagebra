const BRUTE_FORCE_LBVH_THRESHOLD = 100
const MORTON_CODE_TYPE = UInt64

# ? ---------------------------------
# ! IntersectionCalculatorDependent{T}
# ? ---------------------------------

mutable struct IntersectionCalculatorDependent{T}
    # _dependent::Dependent
    _foundIntersectionNum::UInt
    _intersections::Vector{T}

    # YELLOW Thread
    function IntersectionCalculatorDependent{T}(geometry1::NodeHandle, geometry2::NodeHandle, maxIntersectionNum::UInt) where T
        # ! Note that in the callback:
        # ! - data: IntersectionCalculatorDependent{T12}
        # ! - geometry1: PrimtiviesOf{T1<:Primitive} or LazyLBVH{PrimitivesOf{T1<:AABBPrimitive}}
        # ! - geometry2: PrimtiviesOf{T2<:Primitive} or LazyLBVH{PrimitivesOf{T2<:AABBPrimitive}}
        
        # dependent = Dependent([geometry1,geometry2]) do data, geometry1, geometry2
        #     FindIntersections(data,geometry1,geometry2)
        #     return nothing
        # end
        
        foundIntersectionNum = 0
        intersections = Vector{T}(undef,maxIntersectionNum)
        new(#=dependent,=#foundIntersectionNum,intersections)
    end
end

getGeometry1(self::IntersectionCalculatorDependent)::NodeHandle = return getGraphParent(self,1) #
getGeometry2(self::IntersectionCalculatorDependent)::NodeHandle = return getGraphParent(self,2) #

# YELLOW Thread
# RED Thread
onNodeEval(self::IntersectionCalculatorDependent) = evalCallbackDp(self; callbackParams = Tuple([self]))

evalCallbackDpReturn(self::IntersectionCalculatorDependent,::Nothing) = return nothing

evalCallbackDpEntry(self::IntersectionCalculatorDependent)::IntersectionCalculatorDependent = return self
convert_callback_entry(self::IntersectionCalculatorDependent)::IntersectionCalculatorDependent = return self

function FindIntersections(self::IntersectionCalculatorDependent,shapes_a::PrimitivesOf,shapes_b::PrimitivesOf)
    self._foundIntersectionNum = 0
    BruteForceIntersections(self,shapes_a,shapes_b)
    # println(self._foundIntersectionNum)
end

function FindIntersections(self::IntersectionCalculatorDependent,shapes_a::LazyLBVHDependent{PrimitivesOf{U}}, shapes_b::LazyLBVHDependent{PrimitivesOf{V}}) where {U,V <: AABBPrimitive}
    self._foundIntersectionNum = 0

    if ((length(shapes_a._iter) < BRUTE_FORCE_LBVH_THRESHOLD) && (length(shapes_b._iter) < BRUTE_FORCE_LBVH_THRESHOLD))
        BruteForceIntersections(self, shapes_a._iter, shapes_b._iter)
    else
        if (length(shapes_a._iter) <= length(shapes_b._iter))
            @log "$(getGraphID(shapes_a)) vs $(getGraphID(shapes_b)) --> $(getGraphID(shapes_a)) is LBVH"
            LBVHIntersections(self, shapes_a, shapes_b)
        else
            @log "$(getGraphID(shapes_a)) vs $(getGraphID(shapes_b)) --> $(getGraphID(shapes_b)) is LBVH"
            LBVHIntersections(self, shapes_b, shapes_a)
        end
    end
end

function BruteForceIntersections(self::IntersectionCalculatorDependent{T}, shapes_a::PrimitivesOf{U}, shapes_b::PrimitivesOf{V}) where {T,U,V}
    println("<<< brute force start >>>")
    println("shapes_a: ", shapes_a)
    println("shapes_b: ", shapes_b)
    for primitive_a in shapes_a
        for primitive_b in shapes_b
            intersection::Union{T,Nothing} = PrimitiveToPrimitiveIntersection(primitive_a, primitive_b)
            println("intersection of $primitive_a and $primitive_b: $intersection")
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
    println("<<< brute force end >>>")
end

function LBVHIntersections(self::IntersectionCalculatorDependent, geometry_lbvh::LazyLBVHDependent{PrimitivesOf{U}}, geometry_b::LazyLBVHDependent{PrimitivesOf{V}}) where {U,V <: AABBPrimitive}    
    lbvh = getLBVH(geometry_lbvh)
    
    shapes_lbvh = geometry_lbvh._iter
    shapes_b = geometry_b._iter
            
    for primitive_b in shapes_b
        number_of_intersections = LBVHToPrimitiveIntersection(
            lbvh.lbvh_nodes,
            shapes_lbvh,
            lbvh.number_of_internal_nodes,
            lbvh.number_of_leafs,
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

function Base.getindex(self::IntersectionCalculatorDependent{T}, idx = 1)::Union{T,Nothing} where T
    if (1 <= idx && idx <= self._foundIntersectionNum)
        return self._intersections[idx]
    else
        return nothing
    end
end

# ? ---------------------------------
# ! IntersectionCalculator(T)
# ? ---------------------------------

function eval_node(element::IntersectionCalculatorDependent, callback::Function, arguments::Vector{Any})::Any
    println("eval_node")
    callback(element, arguments...)
    println("foundNum: ", element._foundIntersectionNum)
    println("its[1]: ", element._intersections[1])
    return element
end

# YELLOW Thread
# IntersectionCalculator(T12::Type, geometry1::NodeHandle, geometry2::NodeHandle; maxIntersectionNum=25) =
# Build!(IntersectionCalculatorDependent{T12}(geometry1,geometry2,UInt(maxIntersectionNum)))
function IntersectionCalculator(T12::Type, geometry1::NodeHandle, geometry2::NodeHandle; maxIntersectionNum=25)
    add_node!(IntersectionCalculatorDependent{T12}(geometry1,geometry2,UInt(maxIntersectionNum)),[geometry1,geometry2]) do data,g1,g2
        println(typeof(data))
        println(g1)
        println(g2)
        FindIntersections(data,g1,g2)
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
    DependentT::Type = typeof(get_element(geometry))
    println("\tDependentT: ", DependentT)
    CallbackDpEntryT::Type = InferSingletonDefinitionFor(DependentT,convert_callback_entry,Any)
    println("\tCallbackDpEntryT: ", CallbackDpEntryT)
    PrimitivesOfT::Type = InferSingletonDefinitionFor(CallbackDpEntryT,PrimitivesOf,PrimitivesOf)
    println("\tPrimitivesOfT: ", PrimitivesOfT)
    return getPrimitivesT(PrimitivesOfT)
end

function InferPrimitiveToPrimitiveIntersection(::Type{U},::Type{V})::Type where {U,V <: Primitive}
    return InferSingletonDefinitionFor(Tuple{U,V},PrimitiveToPrimitiveIntersection,Union{Any,Nothing})
end

# YELLOW Thread
function Intersection(geometry1::NodeHandle,geometry2::NodeHandle; maxIntersectionNum=25)
    T1::Type = InferPrimitivesT(geometry1)
    println("T1: ", T1)
    T2::Type = InferPrimitivesT(geometry2)
    println("T2: ", T2)
    T12::Type = InferPrimitiveToPrimitiveIntersection(T1,T2)
    println("T12: ", T12)
    return _Intersection(geometry1,geometry2,T1,T2,T12; maxIntersectionNum = maxIntersectionNum)
end

function _Intersection(geometry1::NodeHandle,geometry2::NodeHandle, T1::Type{<:Primitive}, T2::Type{<:Primitive}, T12::Type; maxIntersectionNum=25)
    global implicitApp

    call = function (g)
        return PrimitivesOf(g)
    end
    
    println("___")

    # gvh1::GenericValueHolderDependent{PrimitivesOf{T1}} = getIntersectionPrimitiveIter!(implicitApp._optimizer,geometry1,T1,call)
    # gvh2::GenericValueHolderDependent{PrimitivesOf{T2}} = getIntersectionPrimitiveIter!(implicitApp._optimizer,geometry2,T2,call)
    println(PrimitivesOf(get_element(geometry1)))
    println("OKAY")
    gvh1 = add_node!(call,PrimitivesOf(get_element(geometry1)),[geometry1])
    # println(get_element(gvh1))
    gvh2 = add_node!(call,PrimitivesOf(get_element(geometry2)),[geometry2])
    # println(get_element(gvh2))

    return IntersectionCalculator(T12, gvh1, gvh2; maxIntersectionNum=maxIntersectionNum)
end

function _Intersection(geometry1::NodeHandle,geometry2::NodeHandle, T1::Type{<:AABBPrimitive}, T2::Type{<:AABBPrimitive}, T12::Type; maxIntersectionNum=25)
    global implicitApp

    llbvh1::LazyLBVHDependent{PrimitivesOf{T1}} = getIntersectionPrimitiveIter!(implicitApp._optimizer,geometry1,T1)
    llbvh2::LazyLBVHDependent{PrimitivesOf{T2}} = getIntersectionPrimitiveIter!(implicitApp._optimizer,geometry2,T2)

    return IntersectionCalculator(T12, llbvh1, llbvh2; maxIntersectionNum=maxIntersectionNum)
end

export Intersection

function ParametricCurve(it::IntersectionCalculatorDependent{<:Union{Nothing,PSegment}}; maxIntersectionNum=25, color=(0.941, 0.914, 0.141))
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
