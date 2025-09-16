# ? This file contains the code of some Intersection Dependables.
# ? It is a very good starting point to understand how one can create
# ? a Dependent, which is not Rendered.

const BRUTE_FORCE_LBVH_THRESHOLD = 100
const MORTON_CODE_TYPE = UInt64

function BruteForceIntersections(shapes_a, shapes_b, self::DependentDNA)
    for primitive_a in shapes_a
        for primitive_b in shapes_b
            intersection = PrimitiveToPrimitiveIntersection(primitive_a, primitive_b)
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

function LBVHIntersections(shapes_lbvh, shapes_b, self::DependentDNA)
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

function FindIntersections(shapes_a, shapes_b, self::DependentDNA)
    self._foundIntersectionNum = 0

    if ((length(shapes_a) < BRUTE_FORCE_LBVH_THRESHOLD) && (length(shapes_b) < BRUTE_FORCE_LBVH_THRESHOLD))
        BruteForceIntersections(shapes_a, shapes_b, self)
    else
        if (length(shapes_a) <= length(shapes_b))
            LBVHIntersections(shapes_a, shapes_b, self)
        else
            LBVHIntersections(shapes_b, shapes_a, self)
        end
    end
end

# ? ---------------------------------
# ! Curve2CurveIntersectionPlan
# ? ---------------------------------

# ? Firstly, for creating a Dependent, we have to design a Plan for it.
# ? The main purpose of a Plan is, to have an objects, which is in the memory space, of the
# ? user's script.
# ? Also, the data, which is required for constructing a dependent should go here.
# ? A Plan for a Dependentent must inherit from PlanDNA.
mutable struct Curve2CurveIntersectionPlan <: PlanDNA
    _plan::Plan
    _curve1::ParametricCurvePlan
    _curve2::ParametricCurvePlan
    _intersectNum::UInt

    function Curve2CurveIntersectionPlan(curve1::ParametricCurvePlan,curve2::ParametricCurvePlan,intersectNum::UInt)
        new(Plan(() -> (), [curve1,curve2]),curve1,curve2,intersectNum)
    end
end

# ? To complete the DNA inheritance, we need to define the acces for the compositional Plan struct in
# ? the "_Plan_" function.
_Plan_(self::Curve2CurveIntersectionPlan)::Plan = return self._plan

# ? ---------------------------------
# ! Curve2CurveIntersectionDependent
# ? ---------------------------------

# TODO: Rename LineStrip, LineSeq

# ? After we've defined a Plan, we need the Dependent itself.
# ? This struct will sit in the dependent graph as a node.
# ? It should inherit from DependentDNA.
mutable struct Curve2CurveIntersectionDependent <: DependentDNA
    _dependent::Dependent
    _foundIntersectionNum::UInt
    _intersections::Vector{Vec3F}
    
    function Curve2CurveIntersectionDependent(plan::Curve2CurveIntersectionPlan)
        dependent = Dependent(plan)
        foundIntersectionNum = plan._intersectNum
        intersections = Vector{Vec3F}(undef,foundIntersectionNum)
        
        new(dependent,foundIntersectionNum,intersections)
    end
end

_Dependent_(self::Curve2CurveIntersectionDependent)::Dependent = return self._dependent

# ? Some easy to access getters.
curve1(self::Curve2CurveIntersectionDependent)::ParametricCurveDependent = return self._dependent._graphParents[1]
curve2(self::Curve2CurveIntersectionDependent)::ParametricCurveDependent = return self._dependent._graphParents[2]

# ? Every Dependent needs a "Plan2Dependent" function, which connects the above defined Dependent to the
# ? Plan We've defined at the beggining of the file. The function must be able to construct a Dependent from a Plan.
# ! Must have
function Plan2Dependent(plan::Curve2CurveIntersectionPlan)::Curve2CurveIntersectionDependent
    return Curve2CurveIntersectionDependent(plan)
end

# ? Some user accessible indexing getter. 
function Base.getindex(self::Curve2CurveIntersectionDependent,index)::Union{Tuple{Float32,Float32,Float32},Nothing}
    if (index > self._foundIntersectionNum || index < 1)
        return nothing
    end
    
    v = self._intersections[index]

    return (v[1],v[2],v[3])
end

# ? Now we need to define, how the Dependent should act, when everything it depends on changes.
# ? Note that for every Dependent, the "onGraphEval" only gets called once and in a way, where everything
# ? it depends on is up-to date.
# ? in the case of curve-to-curve intersecting, we here do an iterative intersection between segments of the curves.
# ! Must have
function onGraphEval(self::Curve2CurveIntersectionDependent)
    FindIntersections(curve1(self), curve2(self), self)
end

# ? Here we can see that curve-to-surface intersection is done in a very similar manner.

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

function onGraphEval(self::Curve2SurfaceIntersectionDependent)
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
    _intersections::Vector{LineSegment}
    _foundIntersectionNum::UInt

    function Surface2SurfaceIntersectionDependent(plan::Surface2SurfaceIntersectionPlan)
        dependent = Dependent(plan)
        intersections = Vector{LineSegment}(undef, plan._intersectNum)
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

    s::LineSegment = self._intersections[index]
    
    a::Tuple{Float32, Float32, Float32} = (s.p0.x, s.p0.y, s.p0.z)
    b::Tuple{Float32, Float32, Float32} = (s.p1.x, s.p1.y, s.p1.z)
    
    return a, b
end

function onGraphEval(self::Surface2SurfaceIntersectionDependent)
    FindIntersections(TrianglesOf(surface1(self)._uvValues), TrianglesOf(surface2(self)._uvValues), self)
end
