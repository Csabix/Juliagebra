
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

function ParametricCurve(tStart,tEnd,tNum,dependents::DependentsT, callback::Function, app::App)::ParametricCurvePlan
    plan = ParametricCurvePlan(tStart,tEnd,tNum,dependents,callback)
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

ParametricCurve(callback::Function,tStart::Real,tEnd::Real,dependents::DependentsT)::ParametricCurvePlan =
ParametricCurve(callback,tStart,tEnd,dependents,implicitApp)

ParametricCurve(callback::Function,dependents::DependentsT,app::App)::ParametricCurvePlan = 
ParametricCurve(CURVE_DEFULT_START,CURVE_DEFULT_END,CURVE_DETAIL_LEVEL,dependents,callback,app)

export Point
export ParametricCurve