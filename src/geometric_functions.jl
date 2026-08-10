
#region Midpoint
_Midpoint(p::Vec3D)::Tuple{Vec3D,Integer} = (p,1)
_Midpoint(coords::AbstractVector{Vec3D})::Tuple{Vec3D,Integer} = (sum(coords),length(coords))

_Midpoint(p::Point)::Tuple{Vec3D,Integer} = (p.coord,1)
_Midpoint(point_sequence::PointSequence)::Tuple{Vec3D,Integer} = _Midpoint(point_sequence.coords)

function Midpoint(points::AbstractVector)::Vec3D
    sum::Vec3D = Vec3D(0.0)
    count::Integer = 0

    for point in points
        (plus_sum,plus_count) = _Midpoint(point)
        sum += plus_sum
        count += plus_count
    end
    
    if (count == 0)
        return Vec3DNan
    else
        return sum / count
    end
end
Midpoint(points...)::Vec3D = Midpoint(collect(points))

function Midpoint(pointHandles::AbstractVector{NodeHandle},color_style::Union{Nothing,String}=nothing;
    color="m",style=".",size=25,axis_constraint=AXIS_NONE)

    return Point(pointHandles,color_style;color=color,style=style,size=size,axis_constraint=axis_constraint) do points...
        return Midpoint(collect(points))
    end
end
function Midpoint(pointHandleArgs::NodeHandle...;color_style::Union{Nothing,String}=nothing, # color_style must also be a named parameter here
    color="m",style=".",size=25,axis_constraint=AXIS_NONE)

    pointHandles = collect(pointHandleArgs)
    return Midpoint(pointHandles,color_style;color=color,style=style,size=size,axis_constraint=axis_constraint)
end
#endregion

#region Distance
function _Distance(point1::Point,point2::Point)::Float64
    return Distance(point1.coord,point2.coord)
end
function Distance(point::Vec3D,line::Union{Line,Ray,Segment})
    t = dot(point - p0(line), v(line))
    projected = p0(line) + v(line) * ClampParameter(line,t)
    return Distance(point,projected)
end

function Distance(coord1::Vec3D,coord2::Vec3D)::Float64
    return hypot(coord1.x - coord2.x, coord1.y - coord2.y, coord1.z - coord2.z)
end
function Distance(nodeHandle1::NodeHandle,nodeHandle2::NodeHandle)::Float64
    node1 = get_element(nodeHandle1)
    node2 = get_element(nodeHandle2)
    return _Distance(node1,node2) # TODO: return a scalar node
end
#endregion


export Midpoint, Distance








