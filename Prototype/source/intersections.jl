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

mutable struct Curve2SurfaceIntersectionAlgebra

end

# ? ---------------------------------
# ! Curve2SurfaceIntersectionPlan
# ? ---------------------------------

mutable struct Curve2SurfaceIntersectionPlan
    
end