# ! All exported constructors should be defined, and exported from here.

struct PointPlan end

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