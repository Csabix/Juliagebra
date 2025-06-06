# ? ---------------------------------
# ! Curve2CurveIntersectionAlgebra
# ? ---------------------------------

# TODO: Rename LineStrip, LineSeq

EPSILON = 0.1


mutable struct Curve2CurveIntersectionAlgebra <: AlgebraDNA
    _algebra::Algebra
    _intersections::Vector{Vec3F}
    _intersectionNum::Int

    function Curve2CurveIntersectionAlgebra(curve1::ParametricCurvePlan,curve2::ParametricCurvePlan,intersectNum::UInt)
        algebra = Algebra(Vector{PlanDNA}([curve1,curve2]),() -> ())
        intersections = Vector{Vec3F}(undef,intersectNum)
        new(algebra,intersections,Int(intersectNum))
    end
end

_Algebra_(self::Curve2CurveIntersectionAlgebra)::Algebra = return self._algebra
curve1(self::Curve2CurveIntersectionAlgebra)::ParametricCurveAlgebra = return _Algebra_(self)._dependents[1]
curve2(self::Curve2CurveIntersectionAlgebra)::ParametricCurveAlgebra = return _Algebra_(self)._dependents[2]

# TODO: Undef 2 Nothing
# TODO: Optional keyword

function Base.getindex(self::Curve2CurveIntersectionAlgebra,index)::Union{Tuple{Float32,Float32,Float32},Undef}
    if (index > self._intersectionNum || index < 1)
        return Undef()
    end
    
    v = self._intersections[index]

    return (v[1],v[2],v[3])
end

function onGraphEval(self::Curve2CurveIntersectionAlgebra)
    intersectNum = length(self._intersections)
    intersectIndex = 1

    c1 = curve1(self)
    c2 = curve2(self)

    for i1 in c1._startIndex:(c1._endIndex-1)
        for i2 in c2._startIndex:(c2._endIndex-1)
            
            a1 = c1._tValues[i1]
            b1 = c1._tValues[i1+1]
            a2 = c2._tValues[i2]
            b2 = c2._tValues[i2+1]

            result = Segment2SegmentIntersection(a1,b1,a2,b2)

            if result !== nothing
                self._intersections[intersectIndex] = result
                intersectIndex+=1
                if intersectIndex > intersectNum
                    self._intersectionNum = intersectNum
                    return
                end
            end
        end
    end

    self._intersectionNum = intersectIndex-1
end

function Segment2SegmentIntersection(a1::Vec3F,b1::Vec3F,a2::Vec3F,b2::Vec3F)::Union{Vec3F,Nothing}
    v1 = b1 - a1
    v2 = b2 - a2

    n_up = normalize(cross(v1,v2))
    
    d = abs(dot(a2-a1,n_up))
    if( d > EPSILON)
        return nothing
    end

    plane_n  = normalize(cross(v1,n_up))    
    plane_q0 = a1
    ray_p0 = a2
    ray_v  = v2
    t = dot(plane_q0-ray_p0,plane_n)/dot(ray_v,plane_n)
    if (t > 1.0 || t<0.0)
        return nothing
    end

    hit1 = ray_p0 + t * ray_v

    plane_n  = normalize(cross(v2,n_up))    
    plane_q0 = a2
    ray_p0 = a1
    ray_v  = v1
    s = dot(plane_q0-ray_p0,plane_n)/dot(ray_v,plane_n)
    if (s > 1.0 || s<0.0)
        return nothing
    end

    hit2 = ray_p0 + s * ray_v

    hit = (hit1 + hit2) ./ 2

    return hit
end

# ? ---------------------------------
# ! Curve2CurveIntersectionPlan
# ? ---------------------------------

mutable struct Curve2CurveIntersectionPlan <: PlanDNA
    _plan::Plan
    _curve1::ParametricCurvePlan
    _curve2::ParametricCurvePlan
    _intersectNum::UInt

    function Curve2CurveIntersectionPlan(curve1::ParametricCurvePlan,curve2::ParametricCurvePlan,intersectNum::UInt)
        new(Plan(),curve1,curve2,intersectNum)
    end
end

_Plan_(self::Curve2CurveIntersectionPlan)::Plan = return self._plan

function recruit!(self::OpenGLData, plan::Curve2CurveIntersectionPlan)::Curve2CurveIntersectionAlgebra
    curve1 = plan._curve1
    curve2 = plan._curve2
    intersectNum = plan._intersectNum


    a = Curve2CurveIntersectionAlgebra(curve1,curve2,intersectNum)
    _Plan_(plan)._algebra = a
    return a
end



# ? ---------------------------------
# ! Curve2SurfaceIntersectionAlgebra
# ? ---------------------------------

mutable struct Curve2SurfaceIntersectionAlgebra <: AlgebraDNA
    _algebra::Algebra
    _intersections::Vector{Vec3F}
    _foundIntersectionNum::Int

    function Curve2SurfaceIntersectionAlgebra(curve::ParametricCurvePlan,surface::ParametricSurfacePlan,intersectNum)
        algebra = Algebra(Vector{PlanDNA}([curve,surface]),() -> ())
        intersections = Vector{Vec3F}(undef,intersectNum)
        new(algebra,intersections,0)
    end
end

_Algebra_(self::Curve2SurfaceIntersectionAlgebra)::Algebra = return self._algebra
curve(self::Curve2SurfaceIntersectionAlgebra)::ParametricCurveAlgebra = return _Algebra_(self)._dependents[1]
surface(self::Curve2SurfaceIntersectionAlgebra)::ParametricSurfaceAlgebra = return _Algebra_(self)._dependents[2]

function Base.getindex(self::Curve2SurfaceIntersectionAlgebra,index)::Union{Tuple{Float32,Float32,Float32},Undef}
    if (index > self._foundIntersectionNum || index < 1)
        return Undef()
    end
    
    v = self._intersections[index]

    return (v[1],v[2],v[3])
end

function onGraphEval(self::Curve2SurfaceIntersectionAlgebra)
    maxIntersectNum = length(self._intersections)
    self._foundIntersectionNum = 0

    crv = curve(self)
    srfc = surface(self)

    for triangle in TrianglesOf(srfc._uvValues)
        for i in crv._startIndex:(crv._endIndex-1)
            p1 = crv._tValues[i]
            p2 = crv._tValues[i+1]
            a,b,c = triangle

            tuv = Segment2TriangleIntersection(p1,p2,a,b,c)
            t = tuv[1]
            u = tuv[2]
            v = tuv[3]
            w = 1-u-v

            if (0.0<=t && t<=1.0 &&
                0.0<=u &&
                0.0<=v &&
                0.0<=w)

                self._foundIntersectionNum+=1
                intersectionPoint = p1 + t*(p2-p1)
                self._intersections[self._foundIntersectionNum] = intersectionPoint
                
                if (self._foundIntersectionNum == maxIntersectNum)
                    return
                end
            end
        end
    end
end

function Segment2TriangleIntersection(p1::Vec3F,p2::Vec3F,a::Vec3F,b::Vec3F,c::Vec3F)
    p0 = p1
    v = p2 - p1

    ab = b - a
    ac = c - a
    ap = p0 - a
    f = cross(v,ac)
    g = cross(ap,ab)

    tuv = (1/dot(f,ab)) * [dot(g,ac),dot(f,ap),dot(g,v)]
    
    return tuv
end

# ? ---------------------------------
# ! Curve2SurfaceIntersectionPlan
# ? ---------------------------------

mutable struct Curve2SurfaceIntersectionPlan <: PlanDNA
    _plan::Plan
    _curve::ParametricCurvePlan
    _surface::ParametricSurfacePlan
    _intersectNum::UInt

    function Curve2SurfaceIntersectionPlan(curve::ParametricCurvePlan,surface::ParametricSurfacePlan,intersectNum)
        new(Plan(),curve,surface,UInt(intersectNum))
    end
end

_Plan_(self::Curve2SurfaceIntersectionPlan)::Plan = return self._plan

function recruit!(self::OpenGLData, plan::Curve2SurfaceIntersectionPlan)::Curve2SurfaceIntersectionAlgebra
    curve = plan._curve
    surface = plan._surface
    intersectNum = plan._intersectNum


    a = Curve2SurfaceIntersectionAlgebra(curve,surface,intersectNum)
    _Plan_(plan)._algebra = a
    return a
end