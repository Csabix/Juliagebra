# ? This file contains the code of some Intersection Dependables.
# ? It is a very good starting point to understand how one can create
# ? a Dependent, which is not Rendered.

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

EPSILON = 0.1

const BRUTE_FORCE_LBVH_THRESHOLD = 100

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
    self._foundIntersectionNum = 0

    c1 = curve1(self)
    c2 = curve2(self)

    if ((length(c1) < BRUTE_FORCE_LBVH_THRESHOLD) && (length(c2) < BRUTE_FORCE_LBVH_THRESHOLD))
        for i1 in 1:length(c1)
            for i2 in 1:length(c2)
                line_segment1 = c1[UInt(i1)]
                line_segment2 = c2[UInt(i2)]
    
                intersection = Segment2SegmentIntersection(line_segment1, line_segment2)
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
    else
        if (length(c1) >= length(c2))
            lbvh_nodes, number_of_leafs, number_of_internal_nodes = BuildLBVH([GetAABBLineSegment(c1[UInt(i1)]) for i1 in 1:length(c1)], UInt32)
            
            for i2 in 1:length(c2)
                line_segment2 = c2[UInt(i2)]

                number_of_intersections = LBVHToPrimitiveIntersection(
                    lbvh_nodes,
                    c1,
                    number_of_internal_nodes, 
                    number_of_leafs,
                    line_segment2,
                    GetAABBLineSegment(line_segment2),
                    Segment2SegmentIntersection,
                    self._intersections,
                    self._foundIntersectionNum
                )
                self._foundIntersectionNum += number_of_intersections

                if (self._foundIntersectionNum == length(self._intersections))
                    return
                end
            end
        else
            lbvh_nodes, number_of_leafs, number_of_internal_nodes = BuildLBVH([GetAABBLineSegment(c2[UInt(i2)]) for i2 in 1:length(c2)], UInt32)
            
            for i1 in 1:length(c1)
                line_segment1 = c1[UInt(i1)]

                number_of_intersections = LBVHToPrimitiveIntersection(
                    lbvh_nodes,
                    c2,
                    number_of_internal_nodes, 
                    number_of_leafs,
                    line_segment1,
                    GetAABBLineSegment(line_segment1),
                    Segment2SegmentIntersection,
                    self._intersections,
                    self._foundIntersectionNum
                )
                self._foundIntersectionNum += number_of_intersections

                if (self._foundIntersectionNum == length(self._intersections))
                    return
                end
            end
        end
    end
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
    self._foundIntersectionNum = 0

    crv = curve(self)
    triangles = TrianglesOf(surface(self)._uvValues)

    if ((length(crv) < BRUTE_FORCE_LBVH_THRESHOLD) && (length(triangles) < BRUTE_FORCE_LBVH_THRESHOLD))
        for triangle in triangles
            for i in 1:length(crv)
                line_segment = crv[UInt(i)]
    
                intersection = Segment2TriangleIntersection(line_segment, triangle)
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
    else
        if (length(crv) >= length(triangles))
            lbvh_nodes, number_of_leafs, number_of_internal_nodes = BuildLBVH([GetAABBLineSegment(crv[UInt(i)]) for i in 1:length(crv)], UInt32)

            for triangle in triangles
                number_of_intersections = LBVHToPrimitiveIntersection(
                    lbvh_nodes,
                    crv,
                    number_of_internal_nodes, 
                    number_of_leafs,
                    triangle,
                    GetAABBTriangle(triangle),
                    Segment2TriangleIntersection,
                    self._intersections,
                    self._foundIntersectionNum
                )
                self._foundIntersectionNum += number_of_intersections

                if (self._foundIntersectionNum == length(self._intersections))
                    return
                end
            end
        else
            lbvh_nodes, number_of_leafs, number_of_internal_nodes = BuildLBVH(map(GetAABBTriangle, triangles), UInt32)
        
            for i in 1:length(crv)
                line_segment = crv[UInt(i)]

                number_of_intersections = LBVHToPrimitiveIntersection(
                    lbvh_nodes,
                    triangles,
                    number_of_internal_nodes, 
                    number_of_leafs,
                    line_segment,
                    GetAABBLineSegment(line_segment),
                    Segment2TriangleIntersection,
                    self._intersections,
                    self._foundIntersectionNum
                )
                self._foundIntersectionNum += number_of_intersections

                if (self._foundIntersectionNum == length(self._intersections))
                    return
                end
            end
        end
    end
    
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
    self._foundIntersectionNum = 0

    triangles1 = TrianglesOf(surface1(self)._uvValues)
    triangles2 = TrianglesOf(surface2(self)._uvValues)

    if ((length(triangles1) < BRUTE_FORCE_LBVH_THRESHOLD) && (length(triangles2) < BRUTE_FORCE_LBVH_THRESHOLD))
        for t1 in triangles1
            for t2 in triangles2
                intersection = Triangle2TriangleIntersection(t1, t2)

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
    else
        if (length(triangles1) >= length(triangles2))
            lbvh_nodes, number_of_leafs, number_of_internal_nodes = BuildLBVH(map(GetAABBTriangle, triangles1), UInt32)

            for t2 in triangles2
                number_of_intersections = LBVHToPrimitiveIntersection(
                    lbvh_nodes,
                    triangles1,
                    number_of_internal_nodes, 
                    number_of_leafs,
                    t2,
                    GetAABBTriangle(t2),
                    Triangle2TriangleIntersection,
                    self._intersections,
                    self._foundIntersectionNum
                )
                self._foundIntersectionNum += number_of_intersections
                
                if (self._foundIntersectionNum == length(self._intersections))
                    return
                end
            end
        else
            lbvh_nodes, number_of_leafs, number_of_internal_nodes = BuildLBVH(map(GetAABBTriangle, triangles2), UInt32)

            for t1 in triangles1
                number_of_intersections = LBVHToPrimitiveIntersection(
                    lbvh_nodes,
                    triangles2,
                    number_of_internal_nodes, 
                    number_of_leafs,
                    t1,
                    GetAABBTriangle(t1),
                    Triangle2TriangleIntersection,
                    self._intersections,
                    self._foundIntersectionNum
                )
                self._foundIntersectionNum += number_of_intersections
                
                if (self._foundIntersectionNum == length(self._intersections))
                    return
                end
            end
        end
    end
end
