
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
function Segment(first::PointDependent,second::PointDependent;
                 color=(0.6,0.6,0.9),width=5.0f0,type=SOLID,reversed=false)::ParametricCurveDependent
    return ParametricCurve(range(0,1,length=2),[first,second];color=color,width=width) do t,a,b
        return b .* t .+ (1-t) .* a
    end
end

function Segment(first::PointDependent,second;
                 color=(0.6,0.6,0.9),width=5.0f0,type=SOLID,reversed=false)::ParametricCurveDependent
    b = Vec3D(second)
    return ParametricCurve(range(0,1,length=2),[first];color=color,width=width) do t,a
        return b .* t .+ (1-t) .* a
    end
end

function Segment(first,second::PointDependent;
                 color=(0.6,0.6,0.9),width=5.0f0,type=SOLID,reversed=false)::ParametricCurveDependent
    a = Vec3D(first)
    return ParametricCurve(range(0,1,length=2),[second];color=color,width=width) do t,b
        return b .* t .+ (1-t) .* a
    end
end

function Segment(first,second;
                 color=(0.6,0.6,0.9),width=5.0f0,type=SOLID,reversed=false)::ParametricCurveDependent
    a = Vec3D(first)
    b = Vec3D(second)
    return ParametricCurve(range(0,1,length=2);color=color,width=width) do t
        return b .* t .+ (1-t) .* a
    end
end

export Segment