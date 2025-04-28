
const DependentsT = Vector{T} where T <: PlanDNA

# ? ---------------------------------
# ! Point
# ? ---------------------------------

POINT_DEFAULT_X = 0
POINT_DEFAULT_Y = 0
POINT_DEFAULT_Z = 0

function Point(x, y, z,dependents::DependentsT, callback::Function, app::App)::PointPlan
    plan = PointPlan(x,y,z,dependents,callback)
    submit!(app,plan)
    return plan
end

Point(x::Real,y::Real,z::Real,app::App) = 
Point(x,y,z,Vector{PlanDNA}(), () -> () ,app)

Point(x::Real,y::Real,z::Real) = 
Point(x,y,z,implicitApp)

Point(callback::Function,x::Real,y::Real,z::Real,dependents::DependentsT) = 
Point(x,y,z,dependents,callback,implicitApp)

Point(callback::Function,x::Real,y::Real,z::Real,dependents::DependentsT,app::App) = 
Point(x,y,z,dependents,callback,app)

Point(callback::Function,dependents::DependentsT,app::App) = 
Point(POINT_DEFAULT_X,POINT_DEFAULT_Y,POINT_DEFAULT_Z,dependents,callback,app)


# ? ---------------------------------
# ! ParametricCurve
# ? ---------------------------------

CURVE_DETAIL_LEVEL  = 1000
CURVE_DEFULT_START  = 0
CURVE_DEFULT_END    = 1
CURVE_DEFAULT_COLOR = (0.6,0.6,0.9)

function ParametricCurve(tStart,tEnd,tNum,dependents::DependentsT, callback::Function, app::App, color=CURVE_DEFAULT_COLOR)::ParametricCurvePlan
    plan = ParametricCurvePlan(tStart,tEnd,tNum,dependents,callback,color)
    submit!(app,plan)
    return plan
end


ParametricCurve(tStart,tEnd,tNum,callback::Function,app::App)::ParametricCurvePlan =
ParametricCurve(tStart,tEnd,tNum,Vector{PlanDNA}(),callback,app)

ParametricCurve(callback::Function,tStart::Real,tEnd::Real,tNum::Int,app::App)::ParametricCurvePlan = 
ParametricCurve(tStart,tEnd,tNum,Vector{PlanDNA}(),callback,app)

ParametricCurve(callback::Function,tStart::Real,tEnd::Real,tNum::Int,dependents::DependentsT,app::App)::ParametricCurvePlan = 
ParametricCurve(tStart,tEnd,tNum,dependents,callback,app)

ParametricCurve(callback::Function,tStart::Real,tEnd::Real,dependents::DependentsT,app::App)::ParametricCurvePlan = 
ParametricCurve(tStart,tEnd,CURVE_DETAIL_LEVEL,dependents,callback,app)

ParametricCurve(callback::Function,tStart::Real,tEnd::Real,tNum::Int,dependents::DependentsT)::ParametricCurvePlan =
ParametricCurve(callback,tStart,tEnd,tNum,dependents,implicitApp)

ParametricCurve(callback::Function,tStart::Real,tEnd::Real,tNum::Int,dependents::DependentsT,color)::ParametricCurvePlan =
ParametricCurve(tStart,tEnd,tNum,dependents,callback,implicitApp,color)

ParametricCurve(callback::Function,tStart::Real,tEnd::Real,dependents::DependentsT)::ParametricCurvePlan =
ParametricCurve(callback,tStart,tEnd,dependents,implicitApp)

ParametricCurve(callback::Function,dependents::DependentsT,app::App)::ParametricCurvePlan = 
ParametricCurve(CURVE_DEFULT_START,CURVE_DEFULT_END,CURVE_DETAIL_LEVEL,dependents,callback,app)

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

export Point
export ParametricCurve
export Segment
export Intersection
export Mesh