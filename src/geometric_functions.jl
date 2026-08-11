
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
    color="m",style=".",size=25,axis_constraint=AXIS_NONE)::NodeHandle

    return Point(pointHandles,color_style;color=color,style=style,size=size,axis_constraint=axis_constraint) do points...
        return Midpoint(collect(points))
    end
end
function Midpoint(pointHandleArgs::NodeHandle...;color_style::Union{Nothing,String}=nothing, # color_style must also be a named parameter here
    color="m",style=".",size=25,axis_constraint=AXIS_NONE)::NodeHandle

    pointHandles = collect(pointHandleArgs)
    return Midpoint(pointHandles,color_style;color=color,style=style,size=size,axis_constraint=axis_constraint)
end
#endregion

#region Distance
function _Distance(point1::Point,point2::Point)::Float64
    return Distance(point1.coord,point2.coord)
end

function Distance(coord::Vec3D,line::Union{Line,Ray,Segment})::Float64
    return Distance(coord,ClosestPoint(coord,line))
end
function Distance(coord::Vec3D,plane::Plane)::Float64
    return abs(dot(n(plane),coord - p0(plane)))
end
function Distance(coord::Vec3D,sphere::Sphere)::Float64
    return abs(Distance(coord,p0(sphere)) - r(sphere))
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

#region Closest Point

function ClosestPoint(coord::Vec3D,line::Union{Line,Ray,Segment})::Vec3D
    t = dot(coord - p0(line), v(line))
    projected = p0(line) + v(line) * ClampParameter(line,t)
    return projected
end
function ClosestPoint(coord::Vec3D,plane::Plane)::Vec3D
    signedDist = dot(n(plane),coord - p0(plane))
    return coord - (n(plane) * signedDist)
end
function ClosestPoint(coord::Vec3D,sphere::Sphere)::Vec3D
    dir = normalize(coord - p0(sphere))
    if (dir === Vec3DNan) return Vec3DNan end
    return p0(sphere) + dir * r(sphere)
end

function ClosestPoint(coord::Vec3D,coord_list::Vector{Vec3D})::Vec3D
    if (length(coord_list) == 0) return Vec3DNan end

    closest::Vec3D = coord_list[1]
    closest_dist::Float64 = Distance(coord, coord_list[1])
    for i in 2:length(coord_list)
        dist = Distance(coord, coord_list[i])
        if (dist < closest_dist)
            closest_dist = dist
            closest = coord_list[i]
        end
    end

    return closest
end

function ClosestPoint(nodeHandle1::NodeHandle,nodeHandle2::NodeHandle,color_style::Union{Nothing,String}=nothing;
    color="m",style=".",size=25,axis_constraint=AXIS_NONE)::NodeHandle
    
    return Point([nodeHandle1,nodeHandle2],color_style;color=color,style=style,size=size,axis_constraint=axis_constraint) do point,geometry
        return ClosestPoint(point,geometry)
    end
end

#endregion


#region Perpendicular Line & Plane

# Perpendicular Line
function PerpendicularLine(coord::Vec3D,plane::Plane)::Tuple{Vec3D,Vec3D}
    return (coord, coord + n(plane))
end
function PerpendicularLine(coord::Vec3D,line::Union{Line,Ray,Segment},plane::Union{Plane,Nothing}=nothing)::Tuple{Vec3D,Vec3D}
    # plane_normal = Vec3D(0,0,1)
    # plane_point = Vec3D(0)
    # if (plane !== nothing)
    #     plane_normal = n(plane)
    #     plane_point = p0(plane)
    # end

    t = dot(coord - p0(line), v(line))
    projected_to_line = p0(line) + v(line) * t

    return (coord,projected_to_line)
end

function PerpendicularLine(nodeHandle1::NodeHandle,nodeHandle2::NodeHandle,color_style::Union{Nothing,String}=nothing;
    color="g",style="-",size::Union{AbstractFloat,Integer}=3.0f0)::NodeHandle

    return Line([nodeHandle1,nodeHandle2],color_style;color=color,style=style,size=size) do point,geometry
        return PerpendicularLine(point,geometry)
    end
end

# Perpendicular Plane
function PerpendicularPlane(coord::Vec3D,line::Union{Line,Ray,Segment})::Tuple{Vec3D,Vec3D}
    return (coord,v(line))
end
function PerpendicularPlane(coord1::Vec3D,coord2::Vec3D)::Tuple{Vec3D,Vec3D}
    return ((coord1 + coord2) / 2.0,normalize(coord2 - coord1))
end

function PerpendicularPlane(nodeHandle1::NodeHandle,nodeHandle2::NodeHandle,color_style::Union{Nothing,String}=nothing;
    color="g")::NodeHandle
    
    return Plane([nodeHandle1,nodeHandle2],color_style;color=color) do point,geometry
        return PerpendicularPlane(point,geometry)
    end
end

# Perpendicular
function Perpendicular(nodeHandle1::NodeHandle,nodeHandle2::NodeHandle,nodeHandle3::Union{NodeHandle,Nothing}=nothing,
    color_style::Union{Nothing,String}=nothing;color="g",style="-",size::Union{AbstractFloat,Integer}=3.0f0)::NodeHandle
    
    node1 = get_element(nodeHandle1)
    node2 = get_element(nodeHandle2)
    # node3 = get_element(nodeHandle3)

    if (isa(node2, Plane) #=|| isa(node3, Plane) =#)
        return PerpendicularLine(nodeHandle1,nodeHandle2,color_style;color=color,style=style,size=size)
    else
        return PerpendicularPlane(nodeHandle1,nodeHandle2,color_style;color=color)
    end
end

#endregion


export Midpoint, Distance, ClosestPoint, PerpendicularLine, PerpendicularPlane, Perpendicular








