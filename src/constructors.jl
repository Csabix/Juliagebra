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
                _startT::Union{T,Nothing} = nothing,
                _T::Type{T}
)::GenericDependentPlan{T} where {T}
    plan = GenericDependentPlan{T}(_call,_deps,_startT)
    submit!(_app,plan)
    return plan
end

GenericDependent(startT::T) where {T} = 
_GenericDependent(_startT = startT, _T = T)

# ? Works, because Julia can figure out I'm just changing the syntax
# ? and T can be inferred in _GenericDependent
GenericDependent{T}(startT) where {T} = 
_GenericDependent(_startT = T(startT), _T = T)

GenericDependent{T}(callback::Function,dependents::DependentsT) where {T} = 
_GenericDependent(_call = callback, _deps = dependents, _T = T)

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
                         _range= range(0.0,1.0,length=1000),
                         _col= (0.6,0.6,0.9),
                         _type= CURVE_SOLID,
                         _reversed= 0,
                         _width= 5.0f0
                         )::ParametricCurvePlan
    plan = ParametricCurvePlan(_call,_deps,_range,_col,_type,_reversed,_width)
    submit!(_app,plan)
    return plan
end

"""
    ParametricCurve(callback, range, [dependents]; kwargs...) -> ParametricCurvePlan

Construct a plan for a parametric curve defined by a generator function over a specific interval.

# Arguments
- `callback::Function`: A function (typically `t,dependents... -> Point`) that defines the curve's path.
- `range::AbstractRange{Float64}`: The interval and step size over which the `callback` is evaluated.
- `dependents::DependentsT`: A collection of `PlanDNA` objects that this curve depends on. Defaults to an empty vector.

# Keyword Arguments
- `color=(0.6, 0.6, 0.9)`: The RGB tuple or array of tuples defining the curve's color.
- `width=5.0f0`: The line thickness.
- `type=CURVE_SOLID`: The visual style of the curve (e.g., solid, dashed).
- `reversed=false`: Whether to flip the line pattern.

# Returns
- `ParametricCurvePlan`: A `PlanDNA` for further use in dependencies.

# Example
App();

curve = ParametricCurve(t -> (cos(t), sin(t), 0.0), 0:0.1:2π; color=(1, 0, 0));

play!();
"""
ParametricCurve(callback::Function,range::AbstractRange{Float64},dependents::DependentsT=Vector{PlanDNA}();
                color=(0.6,0.6,0.9),width=5.0f0,type=CURVE_SOLID,reversed=false)::ParametricCurvePlan =
_ParametricCurve(_call=callback,_deps=dependents,_range=range,_col=color,_type=type,_reversed=reversed ? 0x1 : 0x0,_width=width)

# ? ---------------------------------
# ! Segment
# ? ---------------------------------

"""
    Segment(first, second; kwargs...) -> ParametricCurvePlan

Construct a plan for a straight line segment connecting two points.

# Arguments
- `first::PointPlan`: The starting point of the segment.
- `second::PointPlan`: The ending point of the segment.

# Keyword Arguments
- `color=(0.6, 0.6, 0.9)`: The RGB tuple or array of tuples defining the segment's color.
- `width=5.0f0`: The line thickness.
- `type=CURVE_SOLID`: The visual style of the curve (e.g., solid, dashed).
- `reversed=false`: Whether to flip the line pattern.

# Returns
- `ParametricCurvePlan`: A `PlanDNA` representing the linear path between the two points.

# Example
App();

Segment(Point(0,0,0),Point(1,1,1));

play!();
"""
function Segment(first::PointPlan,second::PointPlan;
                 color=(0.6,0.6,0.9),width=5.0f0,type=CURVE_SOLID,reversed=false)::ParametricCurvePlan
    return ParametricCurve(range(0,1,length=2),[first,second],color=color,type=type,width=width,reversed=reversed) do t,a,b
        return b .* t .+ (1-t) .* a
    end
end

# ? ---------------------------------
# ! Intersections
# ? ---------------------------------

function GenericIntersection(curve1::ParametricCurvePlan,curve2::ParametricCurvePlan,maxIntersectionNum;_app::App = implicitApp,) 
    call = function (curve)
        po = PrimitivesOf(curve) 
        return po     
    end

    gd1 = GenericDependent{PSegmentsOfCurve}(call,[curve1])
    gd2 = GenericDependent{PSegmentsOfCurve}(call,[curve2])

    plan = GeneralIntersectionPlan(gd1,gd2,UInt(maxIntersectionNum))
    
    submit!(_app,plan)
    return plan
end

export  GenericIntersection

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

function Sphere(p1::PointPlan,p2::PointPlan,p3::PointPlan,p4::PointPlan; color = (0.697,0.230,0.958))
    deps = [p1,p2,p3,p4]
    call = function (p1,p2,p3,p4)
        s::PSphere = FourPointOnPSphere(p1,p2,p3,p4)
        return s
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