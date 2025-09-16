# ! All exported constructors should be defined, and exported from here.

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
    return ParametricCurve(0,1,2,color,[fst,snd]) do t,a,b
        return a[:xyz] .* t .+ (1-t) .* b[:xyz]
    end
end

Segment(fst::PointPlan,snd::PointPlan) =
Segment(fst,snd,DEFAULT_SEGMENT_COLOR)

# ? ---------------------------------
# ! Intersections
# ? ---------------------------------

function _Curve2CurveIntersection(;
                                 _app::App = implicitApp,                
                                 _curve1::ParametricCurvePlan,
                                 _curve2::ParametricCurvePlan,
                                 _intersectNum
                                 )::Curve2CurveIntersectionPlan
    plan = Curve2CurveIntersectionPlan(_curve1,_curve2,UInt(_intersectNum))
    submit!(_app,plan)
    return plan
end

Intersection(curve1::ParametricCurvePlan,curve2::ParametricCurvePlan,intersectionNum) =
_Curve2CurveIntersection(_curve1=curve1,_curve2=curve2,_intersectNum=intersectionNum)

function _Curve2SurfaceIntersection(;
                                   _app::App = implicitApp,
                                   _curve::ParametricCurvePlan,
                                   _surface::ParametricSurfacePlan,
                                   _intersectNum
                                   )::Curve2SurfaceIntersectionPlan
    plan = Curve2SurfaceIntersectionPlan(_curve,_surface,UInt(_intersectNum))
    submit!(_app,plan)
    return plan
end

Intersection(curve::ParametricCurvePlan,surface::ParametricSurfacePlan,intersectionNum) =
_Curve2SurfaceIntersection(_curve=curve,_surface=surface,_intersectNum=intersectionNum)

function _Surface2SurfaceIntersection(;
                                   _app::App = implicitApp,
                                   _surface1::ParametricSurfacePlan,
                                   _surface2::ParametricSurfacePlan,
                                   _intersectNum
                                   )::Surface2SurfaceIntersectionPlan
    plan = Surface2SurfaceIntersectionPlan(_surface1,_surface2,UInt(_intersectNum))
    submit!(_app,plan)
    return plan
end

Intersection(surface1::ParametricSurfacePlan,surface2::ParametricSurfacePlan,intersectionNum) =
_Surface2SurfaceIntersection(_surface1=surface1,_surface2=surface2,_intersectNum=intersectionNum)

# ? ---------------------------------
# ! Mesh
# ? ---------------------------------

function Mesh(vertexes,normals,color,app::App)::MeshDependentPlan
    plan = MeshDependentPlan(vertexes,normals,color)
    submit!(app,plan)
    return plan
end

Mesh(vertexes,normals,color) =
Mesh(vertexes,normals,color,implicitApp)

# ? ---------------------------------
# ! ParametricSurface
# ? ---------------------------------

function _ParametricSurface(;
                           _app::App = implicitApp,
                           _call::Function = () -> (),
                           _deps::DependentsT = Vector{PlanDNA}(),
                           _width = 50,
                           _height = 50,
                           _uStart = 0.0,
                           _uEnd = 1.0,
                           _vStart = 0.0,
                           _vEnd = 0.0,
                           _color = (0.8,0.0,0.3)
                           )::ParametricSurfacePlan
    plan = ParametricSurfacePlan(_call,_deps,_width,_height,_uStart,_uEnd,_vStart,_vEnd,_color)
    submit!(_app,plan)
    return plan
end

ParametricSurface(callback::Function,width,height,uStart,uEnd,vStart,vEnd,dependents::DependentsT) =
_ParametricSurface(_call=callback,_width=width,_height=height,_uStart=uStart,_uEnd=uEnd,_vStart=vStart,_vEnd=vEnd,_deps=dependents)

ParametricSurface(callback::Function,width,height,uStart,uEnd,vStart,vEnd) =
_ParametricSurface(_call=callback,_width=width,_height=height,_uStart=uStart,_uEnd=uEnd,_vStart=vStart,_vEnd=vEnd)

export Point
export ParametricCurve
export Segment
export Intersection
export Mesh
export ParametricSurface