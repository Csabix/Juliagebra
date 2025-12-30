# ! All exported constructors should be defined, and exported from here.

const DependentsT = Vector{T} where T <: PlanDNA
const DEFAULT_CALLBACK = () -> (return nothing)

# ? ---------------------------------
# ! GenericDependent
# ? ---------------------------------

function _GenericDependent(;
                _app::App = implicitApp,
                _call::Function = () -> (return nothing),
                _deps::DependentsT = Vector{PlanDNA}(),
                _startT::T
)::GenericDependentPlan{T} where {T}
    plan = GenericDependentPlan{T}(_call,_deps,_startT)
    submit!(_app,plan)
    return plan
end

GenericDependent(startT::T) where {T} = 
_GenericDependent(_startT = startT)

# ? Works, because Julia can figure out I'm just changing the syntax
# ? and T can be inferred in _GenericDependent
GenericDependent{T}(startT) where {T} = 
_GenericDependent(_startT = T(startT))

GenericDependent(callback::Function,startT::T,dependents::DependentsT) where {T} = 
_GenericDependent(_call = callback, _startT = startT, _deps = dependents)

GenericDependent{T}(callback::Function,startT,dependents::DependentsT) where {T} = 
_GenericDependent(_call = callback, _startT = T(startT), _deps = dependents)

# ? ---------------------------------
# ! Point
# ? ---------------------------------

function _Point(;
                _app::App = implicitApp,
                _call::Function = DEFAULT_CALLBACK,
                _deps::DependentsT = Vector{PlanDNA}(),
                _x = 0,
                _y = 0,
                _z = 0,
                )::PointPlan
    
    if (_call === DEFAULT_CALLBACK)
        _call = () -> (return Vec3D(_x,_y,_z))
    end
                
    plan = PointPlan(_call,_deps,_x,_y,_z)
    submit!(_app,plan)
    return plan
end

Point(x::Real,y::Real,z::Real) = 
_Point(_x=x,_y=y,_z=z)

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
        return a .* t .+ (1-t) .* b
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

# ? ---------------------------------
# ! Toggle
# ? ---------------------------------

function _Toggle(;
                _app::App = implicitApp,
                _call::Function = () -> (return nothing),
                _deps::DependentsT = Vector{PlanDNA}(),
                )::TogglePlan
    plan = TogglePlan(_call,_deps)
    submit!(_app,plan)
    return plan
end

Toggle() =
_Toggle()

Toggle(callback::Function,dependents::DependentsT) =
_Toggle(_call = callback, _deps=dependents)

# ? ---------------------------------
# ! Slider
# ? ---------------------------------

function _Slider(;
                _app::App = implicitApp,
                _call::Function = () -> (return nothing),
                _deps::DependentsT = Vector{PlanDNA}(),
                _minVal = 0.0,
                _startVal = 0.5,
                _maxVal = 1.0
                )::SliderPlan
    plan = SliderPlan(_call,_deps,_minVal,_startVal,_maxVal)
    submit!(_app,plan)
    return plan
end

Slider() =
_Slider()

Slider(minVal,maxVal) =
_Slider(_minVal = minVal, _startVal = ((maxVal - minVal)*0.5) + minVal ,_maxVal = maxVal)

Slider(minVal,startVal,maxVal) = 
_Slider(_minVal = minVal, _startVal = clamp(startVal,minVal,maxVal) ,_maxVal = maxVal)

Slider(callback::Function,minVal,maxVal,dependents::DependentsT) =
_Slider(_call = callback, _minVal = minVal ,_maxVal = maxVal, _deps=dependents)

# ? ---------------------------------
# ! TextBox
# ? ---------------------------------

function _TextBox(;
                _app::App = implicitApp,
                _call::Function = () -> (return nothing),
                _deps::DependentsT = Vector{PlanDNA}(),
                _text::String = ""
                )::TextBoxPlan
    plan = TextBoxPlan(_call,_deps,_text)
    submit!(_app,plan)
    return plan
end

TextBox() =
_TextBox()

TextBox(text) =
_TextBox(_text = text)

TextBox(callback::Function,dependents::DependentsT) =
_TextBox(_call = callback, _deps = dependents)

# ? ---------------------------------
# ! Sphere
# ? ---------------------------------

function _Sphere(;
                _app::App = implicitApp,
                _call::Function = () -> (return nothing),
                _deps::DependentsT = Vector{PlanDNA}(),
                _x::Float64 = 0.0,
                _y::Float64 = 0.0,
                _z::Float64 = 0.0,
                _r::Float64 = 1.0,
                _col = (0.980,0.467,0.306)
                )::SpherePlan
    plan = SpherePlan(_call,_deps,_x,_y,_z,_r,_col)
    submit!(_app,plan)
    return plan
end

Sphere() =
_Sphere()

Sphere(x,y,z,r) =
_Sphere(_x = Float64(x), _y = Float64(y), _z = Float64(z), _r = Float64(r))

function Sphere(center::PointPlan,p1::PointPlan; color = (0.980,0.467,0.306))::SpherePlan
    deps = Vector{PlanDNA}([center,p1])
    call = function (center,p1)
        radius = norm(center - p1) 
        return (center,radius)
    end

    return _Sphere(_call = call, _deps = deps, _col = color)
end

function Sphere(center::PointPlan,radius::GenericDependentPlan{Float64}; color = (0.031,0.337,0.412))
    deps = Vector{PlanDNA}([center,radius])
    call = function (center,radius)
        return (center,radius)
    end

    return _Sphere(_call = call, _deps = deps, _col = color)
end

function plane2planeIntersection(plane_n1,plane_n2,plane_p1,plane_p2)
    
    plane_d1 = dot(-plane_n1,plane_p1)
    plane_d2 = dot(-plane_n2,plane_p2)

    plane_n3 = cross(plane_n1,plane_n2)
    
    determinant = (norm(plane_n3))^2

    line_p3 = Vec3D(NaN64,NaN64,NaN64)
    if (determinant != 0.0)
        line_p3 = (cross(plane_n3,plane_n2) * plane_d1 + cross(plane_n1,plane_n3) * plane_d2) / determinant
    end

    return (Vec3D(plane_n3),Vec3D(line_p3))
end

function line2PlaneIntersection(line_n,line_p,plane_n,plane_p)
    t = dot(plane_p-line_p,plane_n) / dot(line_n,plane_n)
    return line_p + t * line_n   
end

function sameDistancePlane(p1,p2)
    plane_n = p2 - p1
    plane_c = ((p2 - p1) / 2.0) + p1
    return (plane_n,plane_c)
end

function sphereCenter(p1,p2,p3,p4)
    plane_n12,plane_c12 = sameDistancePlane(p1,p2)
    plane_n34,plane_c34 = sameDistancePlane(p3,p4)

    line_n_12_34,line_p_12_34 = plane2planeIntersection(plane_n12,plane_n34,plane_c12,plane_c34)
    
    plane_n23,plane_c23 = sameDistancePlane(p2,p3)

    c = line2PlaneIntersection(line_n_12_34,line_p_12_34,plane_n23,plane_c23)

    return c
end

function Sphere(p1::PointPlan,p2::PointPlan,p3::PointPlan,p4::PointPlan; color = (0.697,0.230,0.958))
    deps = [p1,p2,p3,p4]
    call = function (p1,p2,p3,p4)
        c = sphereCenter(p1,p2,p3,p4)
        r = norm(p1 - c)
        return (c,r)
    end

    return _Sphere(_call = call, _deps = deps, _col = color)
end

export GenericDependent
export Point
export ParametricCurve
export Segment
export Intersection
export Mesh
export ParametricSurface
export Toggle
export Slider
export TextBox
export Sphere