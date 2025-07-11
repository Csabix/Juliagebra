
const DependentsT = Vector{T} where T <: PlanDNA

# ? ---------------------------------
# ! Point
# ? ---------------------------------

function _Point(;
                _app::App = implicitApp,
                _call::Function = () -> (),
                _deps::DependentsT = Vector{PlanDNA}(),
                _x = 0,
                _y = 0,
                _z = 0,
                )::PointPlan
    plan = PointPlan(_call,_deps,_x,_y,_z)
    submit!(_app,plan)
    return plan
end

Point(x::Real,y::Real,z::Real) = 
_Point(_x=x,_y=y,_z=z)

Point(callback::Function,x::Real,y::Real,z::Real,dependents::DependentsT) = 
_Point(_call=callback,_x=x,_y=y,_z=z,_deps=dependents)

Point(callback::Function,dependents::DependentsT) = 
_Point(_call=callback,_deps=dependents)


# ? ---------------------------------
# ! ParametricCurve
# ? ---------------------------------

CURVE_DETAIL_LEVEL  = 1000
CURVE_DEFULT_START  = 0
CURVE_DEFULT_END    = 1
CURVE_DEFAULT_COLOR = (0.6,0.6,0.9)

function _ParametricCurve(;
                         _app::App = implicitApp,
                         _call::Function = () -> (),
                         _deps::DependentsT = Vector{PlanDNA}(),
                         _tStart = 0,
                         _tEnd = 1,
                         _tNum = 1000,
                         _col= (0.6,0.6,0.9)
                         )::ParametricCurvePlan
    plan = ParametricCurvePlan(_call,_deps,_tStart,_tEnd,_tNum,_col)
    submit!(_app,plan)
    return plan
end

ParametricCurve(callback::Function,tStart::Real,tEnd::Real)::ParametricCurvePlan =
_ParametricCurve(_call=callback,_tStart=tStart,_tEnd=tEnd)

ParametricCurve(callback::Function,tStart::Real,tEnd::Real,tNum::Real)::ParametricCurvePlan =
_ParametricCurve(_call=callback,_tStart=tStart,_tEnd=tEnd,_tNum=tNum)

ParametricCurve(callback::Function,tStart::Real,tEnd::Real,dependents::DependentsT)::ParametricCurvePlan =
_ParametricCurve(_call=callback,_tStart=tStart,_tEnd=tEnd,_deps=dependents)

ParametricCurve(callback::Function,tStart::Real,tEnd::Real,tNum::Int,dependents::DependentsT)::ParametricCurvePlan =
_ParametricCurve(_call=callback,_tStart=tStart,_tEnd=tEnd,_tNum=tNum,_deps=dependents)

ParametricCurve(callback::Function,tStart::Real,tEnd::Real,tNum::Int,color,dependents::DependentsT,)::ParametricCurvePlan =
_ParametricCurve(_call=callback,_tStart=tStart,_tEnd=tEnd,_tNum=tNum,_col=color,_deps=dependents)  

# ? ---------------------------------
# ! Segment
# ? ---------------------------------

DEFAULT_SEGMENT_COLOR = (0.6,0.0,1.0)

function Segment(fst::PointPlan,snd::PointPlan,color)::ParametricCurvePlan
    return ParametricCurve(0,1,2,[fst,snd],color) do t,a,b
        xx = t * x(a) + (1-t) * x(b) 
        yy = t * y(a) + (1-t) * y(b)
        zz = t * z(a) + (1-t) * z(b)
        return (xx,yy,zz)
    end
end

Segment(fst::PointPlan,snd::PointPlan) =
Segment(fst,snd,DEFAULT_SEGMENT_COLOR)




# ? ---------------------------------
# ! Intersections
# ? ---------------------------------

function Intersection(curve1::ParametricCurvePlan,curve2::ParametricCurvePlan,intersectionNum,app::App)::Curve2CurveIntersectionPlan
    plan = Curve2CurveIntersectionPlan(curve1,curve2,UInt(intersectionNum))
    submit!(app,plan)
    return plan
end

Intersection(curve1::ParametricCurvePlan,curve2::ParametricCurvePlan,intersectionNum) =
Intersection(curve1,curve2,intersectionNum,implicitApp)

function Intersection(curve::ParametricCurvePlan,surface::ParametricSurfacePlan,intersectionNum,app::App)::Curve2SurfaceIntersectionPlan
    plan = Curve2SurfaceIntersectionPlan(curve,surface,UInt(intersectionNum))
    submit!(app,plan)
    return plan
end

Intersection(curve::ParametricCurvePlan,surface::ParametricSurfacePlan,intersectionNum) =
Intersection(curve,surface,intersectionNum,implicitApp)

# ? ---------------------------------
# ! Mesh
# ? ---------------------------------

function Mesh(vertexes,normals,color,app::App)::MeshAlgebraPlan
    plan = MeshAlgebraPlan(vertexes,normals,color)
    submit!(app,plan)
    return plan
end

Mesh(vertexes,normals,color) =
Mesh(vertexes,normals,color,implicitApp)

# ? ---------------------------------
# ! ParametricSurface
# ? ---------------------------------

SURFACE_DEFAULT_COLOR = (0.8,0.0,0.3)

function ParametricSurface(callback::Function,dependents::DependentsT,width,height,uStart,uEnd,vStart,vEnd,color=SURFACE_DEFAULT_COLOR, app::App=implicitApp)::ParametricSurfacePlan
    plan = ParametricSurfacePlan(dependents,callback,width,height,uStart,uEnd,vStart,vEnd,color)
    submit!(app,plan)
    return plan
end

ParametricSurface(callback::Function,width,height,uStart,uEnd,vStart,vEnd,color=SURFACE_DEFAULT_COLOR, app::App=implicitApp) =
ParametricSurface(callback,Vector{PlanDNA}(),width,height,uStart,uEnd,vStart,vEnd,color,app)

export Point
export ParametricCurve
export Segment
export Intersection
export Mesh
export ParametricSurface
export Undef