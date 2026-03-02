# ! All exported constructors should be defined, and exported from here.

_deps_collect_add!(vec::Vector{Vec3D},v) = push!(vec,v)
_deps_collect_add!(vec::Vector{Vec3D},v::Vector) = append!(vec,v)
function _deps_collect_add!(vec::Vector{Vec3D},intersectons::IntersectionCalculatorDependent)
    i = 1
    while true
        v = intersectons[i]
        if isnothing(v) return end
        push!(vec,v)
        i += 1
    end
end
function _deps_collect(deps...)
    result = Vector{Vec3D}()
    for dep in deps
        _deps_collect_add!(result,dep)
    end
    return result
end

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

macro Point(callback::Expr)
    callback = _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.Point)
end

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

macro ParametricCurve(callback::Expr,range,kw_args...)
    parsed_kw_args = _parse_macro_kw_args([:color, :width, :type, :reversed], kw_args...)
    callback = _validate_callback_expr(callback, 1)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.ParametricCurve, (cb, deps) -> (cb, range, deps); parsed_kw_args...)
end

# ? ---------------------------------
# ! SegmentSequence
# ? ---------------------------------

function _SegmentSequence(;
                         _app::App = implicitApp,
                         _call::Function = () -> (),
                         _break_every = 2,
                         _deps::DependentsT = Vector{PlanDNA}(),
                         _col= (0.6,0.6,0.9),
                         _type= CURVE_SOLID,
                         _reversed= 0,
                         _width= 5.0f0
                         )::SegmentSequencePlan
    plan = SegmentSequencePlan(_call,_deps,_col,_break_every,_type,_reversed,_width)
    submit!(_app,plan)
    return plan
end

SegmentSequence(callback::Function,dependents::DependentsT=Vector{PlanDNA}(),break_every=2;
                color=(0.6,0.6,0.9),width=5.0f0,type=CURVE_SOLID,reversed=false)::SegmentSequencePlan =
_SegmentSequence(_call=callback,_deps=dependents,_col=color,_break_every=break_every,_type=type,_reversed=reversed ? 0x1 : 0x0,_width=width)

SegmentSequence(dependents::DependentsT=Vector{PlanDNA}(),break_every=2;
                color=(0.6,0.6,0.9),width=5.0f0,type=CURVE_SOLID,reversed=false)::SegmentSequencePlan =
_SegmentSequence(_call=_deps_collect,_deps=dependents,_col=color,_break_every=break_every,_type=type,_reversed=reversed ? 0x1 : 0x0,_width=width)

macro SegmentSequence(callback::Expr,break_every=2,kw_args...)
    (break_every, kw_args) = _kw_arg_or_default!(break_every, 2, kw_args)

    parsed_kw_args = _parse_macro_kw_args([:color, :width, :type, :reversed], kw_args...)
    callback = _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.SegmentSequence, (cb, deps) -> (cb, deps, break_every); parsed_kw_args...)
end

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
                           _color = (0.8,0.0,0.3),
                           _transparent = false
                           )::ParametricSurfacePlan
    plan = ParametricSurfacePlan(_call,_deps,_width,_height,_uStart,_uEnd,_vStart,_vEnd,_color,_transparent)
    submit!(_app,plan)
    return plan
end

ParametricSurface(callback::Function,width,height,uStart,uEnd,vStart,vEnd,dependents::DependentsT;transparent::Bool=false,color=(0.8,0.0,0.3)) =
_ParametricSurface(_call=callback,_width=width,_height=height,_uStart=uStart,_uEnd=uEnd,_vStart=vStart,_vEnd=vEnd,_deps=dependents,
_transparent=transparent,_color=color)

ParametricSurface(callback::Function,width,height,uStart,uEnd,vStart,vEnd;transparent::Bool=false,color=(0.8,0.0,0.3)) =
_ParametricSurface(_call=callback,_width=width,_height=height,_uStart=uStart,_uEnd=uEnd,_vStart=vStart,_vEnd=vEnd,
_transparent=transparent,_color=color)

macro ParametricSurface(callback::Expr,width,height,uStart,uEnd,vStart,vEnd,kw_args...)
    parsed_kw_args = _parse_macro_kw_args([:transparent, :color], kw_args...)
    callback = _validate_callback_expr(callback, 2)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.ParametricSurface,
        (cb, deps) -> (cb, width, height, uStart, uEnd, vStart, vEnd, deps);
        parsed_kw_args...)
end

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

macro Toggle(callback::Expr)
    callback = _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.Toggle)
end

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

macro Slider(callback::Expr,minVal,maxVal)
    _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.Slider, (cb, deps) -> (cb,minVal,maxVal,deps))
end

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

macro TextBox(callback::Expr)
    callback = _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.TextBox)
end

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
                _col = (0.980,0.467,0.306),
                _transparent = false
                )::SpherePlan
    plan = SpherePlan(_call,_deps,_x,_y,_z,_r,_col,_transparent)
    submit!(_app,plan)
    return plan
end

Sphere(x,y,z,r) =
_Sphere(_x = Float64(x), _y = Float64(y), _z = Float64(z), _r = Float64(r))

function Sphere(center::PointPlan,p1::PointPlan; color = (0.980,0.467,0.306), transparent = false)::SpherePlan
    deps = Vector{PlanDNA}([center,p1])
    call = function (center,p1)
        radius = norm(center - p1) 
        return (center,radius)
    end

    return _Sphere(_call = call, _deps = deps, _col = color, _transparent = transparent)
end

function Sphere(center::PointPlan,radius::ValueHolderPlanDNA{Float64}; color = (0.031,0.337,0.412), transparent = false)
    deps = Vector{PlanDNA}([center,radius])
    call = function (center,radius)
        return (center,radius)
    end

    return _Sphere(_call = call, _deps = deps, _col = color, _transparent = transparent)
end

function Sphere(p1::PointPlan,p2::PointPlan,p3::PointPlan,p4::PointPlan; color = (0.697,0.230,0.958))
    deps = [p1,p2,p3,p4]
    call = function (p1,p2,p3,p4)
        s::PSphere = FourPointOnPSphere(p1,p2,p3,p4)
        return s
    end

    return _Sphere(_call = call, _deps = deps, _col = color)
end

# ? ---------------------------------
# ! PointCloud
# ? ---------------------------------

function _PointCloud(;
                         _app::App = implicitApp,
                         _call::Function = () -> (),
                         _deps::DependentsT = Vector{PlanDNA}(),
                         _col=(0.0,1.0,1.0),
                         _width=25.0f0
                         )::PointCloudPlan
    plan = PointCloudPlan(_call,_deps,_col,_width)
    submit!(_app,plan)
    return plan
end

PointCloud(callback::Function,dependents::DependentsT=Vector{PlanDNA}();color=(0.0,1.0,1.0),width=25.0f0)::PointCloudPlan =
_PointCloud(_call=callback,_deps=dependents,_col=color,_width=width)

PointCloud(dependents::DependentsT) = GenericValueHolder(_deps_collect,Vector{Vec3D},dependents)
PointCloud(positions) = PointCloud([Point(p...) for p in positions])

macro PointCloud(callback::Expr, kw_args...)
    parsed_kw_args = _parse_macro_kw_args([:color, :width], kw_args...)
    callback = _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.PointCloud; parsed_kw_args...)
end

export Point
export @Point
export ParametricCurve
export Segment
export SegmentSequence
export Intersection
export Mesh
export ParametricSurface
export Toggle
export Slider
export TextBox
export Sphere
export PointCloud
export _deps_collect