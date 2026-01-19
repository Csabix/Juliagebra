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

# function Base.iterate(self::IntersectionResult, state = 1) 
#     if (state <= self._data._foundIntersectionNum)
#         return (self[i],state+1)
#     else
#         return nothing
#     end
# end


function FindIntersections(self::IntersectionData,shapes_a::PrimitivesOf, shapes_b::PrimitivesOf)
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

function BruteForceIntersections(self::IntersectionData{T}, shapes_a::PrimitivesOf{T}, shapes_b::PrimitivesOf{T}) where T
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

function LBVHIntersections(self::IntersectionData, shapes_lbvh::PrimitivesOf{T}, shapes_b::PrimitivesOf{T}) where T <: AABBPrimitive
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
# ! Intersection
# ? ---------------------------------

# TODO: Restrain PlanDNA to intersectable plans?

function IIntersection(geometry1::PlanDNA, geometry2::PlanDNA; maxIntersectionNum = 25)::GenericValueHolderPlan
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

export IIntersection

# ? ---------------------------------
# ! Curve2CurveIntersectionPlan
# ? ---------------------------------

mutable struct Curve2CurveIntersectionPlan <: PlanDNA
    _plan::Plan
    _curve1::ParametricCurvePlan
    _curve2::ParametricCurvePlan
    _intersectNum::UInt

    function Curve2CurveIntersectionPlan(curve1::ParametricCurvePlan,curve2::ParametricCurvePlan,intersectNum::UInt)
        new(Plan(() -> (), [curve1,curve2]),curve1,curve2,intersectNum)
    end
end

_Plan_(self::Curve2CurveIntersectionPlan)::Plan = return self._plan

# ? ---------------------------------
# ! Curve2CurveIntersectionDependent
# ? ---------------------------------

mutable struct Curve2CurveIntersectionDependent <: DependentDNA
    _dependent::Dependent
    _foundIntersectionNum::UInt
    _intersections::Vector{Vec3D}
    
    function Curve2CurveIntersectionDependent(plan::Curve2CurveIntersectionPlan)
        dependent = Dependent(plan)
        foundIntersectionNum = 0
        intersections = Vector{Vec3D}(undef,plan._intersectNum)
        
        self = new(dependent,foundIntersectionNum,intersections)
        onNodeEval(self)

        return self
    end
end

_Dependent_(self::Curve2CurveIntersectionDependent)::Dependent = return self._dependent

curve1(self::Curve2CurveIntersectionDependent)::ParametricCurveDependent = return self._dependent._graphParents[1]
curve2(self::Curve2CurveIntersectionDependent)::ParametricCurveDependent = return self._dependent._graphParents[2]

function Plan2Dependent(plan::Curve2CurveIntersectionPlan)::Curve2CurveIntersectionDependent
    return Curve2CurveIntersectionDependent(plan)
end

function Base.getindex(self::Curve2CurveIntersectionDependent,index)::Union{Vec3D,Nothing}
    if (index > self._foundIntersectionNum || index < 1)
        return nothing
    end
    
    return self._intersections[index]
end


function onNodeEval(self::Curve2CurveIntersectionDependent)
    FindIntersections(curve1(self), curve2(self), self)
end

# ? ---------------------------------
# ! Curve2SurfaceIntersectionPlan
# ? ---------------------------------

mutable struct Curve2SurfaceIntersectionPlan <: PlanDNA
    _plan::Plan
    _curve::ParametricCurvePlan
    _surface::ParametricSurfacePlan
    _intersectNum::UInt

    function Curve2SurfaceIntersectionPlan(curve::ParametricCurvePlan,surface::ParametricSurfacePlan,intersectNum::UInt)
        new(Plan(() -> (), [curve,surface]),curve,surface,intersectNum)
    end
end

_Plan_(self::Curve2SurfaceIntersectionPlan)::Plan = return self._plan

# ? ---------------------------------
# ! Curve2SurfaceIntersectionDependent
# ? ---------------------------------

mutable struct Curve2SurfaceIntersectionDependent <: DependentDNA
    _dependent::Dependent
    _intersections::Vector{Vec3F}
    _foundIntersectionNum::UInt

    function Curve2SurfaceIntersectionDependent(plan::Curve2SurfaceIntersectionPlan)
        dependent = Dependent(plan)
        intersections = Vector{Vec3F}(undef,plan._intersectNum)
        new(dependent,intersections,0)
    end
end

_Dependent_(self::Curve2SurfaceIntersectionDependent)::Dependent = return self._dependent
curve(self::Curve2SurfaceIntersectionDependent)::ParametricCurveDependent     = return self._dependent._graphParents[1]
surface(self::Curve2SurfaceIntersectionDependent)::ParametricSurfaceDependent = return self._dependent._graphParents[2]

function Plan2Dependent(plan::Curve2SurfaceIntersectionPlan)::Curve2SurfaceIntersectionDependent
    return Curve2SurfaceIntersectionDependent(plan)
end

function Base.getindex(self::Curve2SurfaceIntersectionDependent,index)::Union{Tuple{Float32,Float32,Float32},Nothing}
    if (index > self._foundIntersectionNum || index < 1)
        return nothing
    end
    
    v = self._intersections[index]

    return (v[1],v[2],v[3])
end

function onNodeEval(self::Curve2SurfaceIntersectionDependent)
    FindIntersections(curve(self), TrianglesOf(surface(self)._uvValues), self)
end

mutable struct Surface2SurfaceIntersectionPlan <: PlanDNA
    _plan::Plan
    _surface1::ParametricSurfacePlan
    _surface2::ParametricSurfacePlan
    _intersectNum::UInt

    function Surface2SurfaceIntersectionPlan(surface1::ParametricSurfacePlan, surface2::ParametricSurfacePlan, intersectNum::UInt)
        new(Plan(() -> (), [surface1, surface2]), surface1, surface2, intersectNum)
    end
end

_Plan_(self::Surface2SurfaceIntersectionPlan)::Plan = return self._plan

# ? ---------------------------------
# ! Surface2SurfaceIntersectionDependent
# ? ---------------------------------

mutable struct Surface2SurfaceIntersectionDependent <: DependentDNA
    _dependent::Dependent
    _intersections::Vector{PSegment}
    _foundIntersectionNum::UInt

    function Surface2SurfaceIntersectionDependent(plan::Surface2SurfaceIntersectionPlan)
        dependent = Dependent(plan)
        intersections = Vector{PSegment}(undef, plan._intersectNum)
        new(dependent, intersections, 0)
    end
end

_Dependent_(self::Surface2SurfaceIntersectionDependent)::Dependent = return self._dependent
surface1(self::Surface2SurfaceIntersectionDependent)::ParametricSurfaceDependent = return self._dependent._graphParents[1]
surface2(self::Surface2SurfaceIntersectionDependent)::ParametricSurfaceDependent = return self._dependent._graphParents[2]

function Plan2Dependent(plan::Surface2SurfaceIntersectionPlan)::Surface2SurfaceIntersectionDependent
    return Surface2SurfaceIntersectionDependent(plan)
end

function Base.getindex(self::Surface2SurfaceIntersectionDependent, index)::Union{Nothing, Tuple{Tuple{Float32, Float32, Float32}, Tuple{Float32, Float32, Float32}}}
    if ((index > self._foundIntersectionNum) || (index < 1))
        return nothing
    end

    s::PSegment = self._intersections[index]
    
    a::Tuple{Float32, Float32, Float32} = (s.p0.x, s.p0.y, s.p0.z)
    b::Tuple{Float32, Float32, Float32} = (s.p1.x, s.p1.y, s.p1.z)
    
    return a, b
end

function onNodeEval(self::Surface2SurfaceIntersectionDependent)
    FindIntersections(TrianglesOf(surface1(self)._uvValues), TrianglesOf(surface2(self)._uvValues), self)
end
