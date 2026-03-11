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