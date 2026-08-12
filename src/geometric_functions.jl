
#region Midpoint
_MidpointCount(p::Vec3D)::Tuple{Vec3D,Integer} = (p,1)
_MidpointCount(p::Point)::Tuple{Vec3D,Integer} = (p.coord,1)
_MidpointCount(coords::AbstractVector{Vec3D})::Tuple{Vec3D,Integer} = (sum(coords),length(coords))
_MidpointCount(point_sequence::PointSequence)::Tuple{Vec3D,Integer} = _MidpointCount(point_sequence.coords)

function Midpoint(nodes::Any...)::Vec3D
    sum::Vec3D = Vec3D(0.0)
    count::Integer = 0

    for node in nodes
        (plus_sum,plus_count) = _MidpointCount(node)
        sum += plus_sum
        count += plus_count
    end
    
    if (count == 0)
        return Vec3DNan
    else
        return sum / count
    end
end
function Midpoint(pointHandles::NodeHandle...;color_style::Union{Nothing,String}=nothing, # color_style must also be a named parameter here
    color="m",style=".",size=25,axis_constraint=AXIS_NONE)::NodeHandle

    return Point([pointHandles...],color_style;color=color,style=style,size=size,axis_constraint=axis_constraint) do nodes...
        return Midpoint(nodes...)
    end
end
#endregion


#region Distance
Distance(coord1::Vec3D,coord2::Vec3D)::Float64 = hypot(coord1.x - coord2.x, coord1.y - coord2.y, coord1.z - coord2.z)
Distance(point1::Point,point2::Point)::Float64 = Distance(point1.coord,point2.coord)
Distance(coord::Vec3D,plane::Plane)::Float64   = abs(dot(n(plane),coord - p0(plane)))
Distance(coord::Vec3D,sphere::Sphere)::Float64 = abs(Distance(coord,p0(sphere)) - r(sphere))
Distance(coord::Vec3D,circle::Circle)::Float64 = Distance(coord,ClosestPoint(coord,circle))
Distance(coord::Vec3D,geometry::Any)::Float64  = Distance(coord,ClosestPoint(coord,geometry))
function Distance(nodeHandles::NodeHandle...)::Float64
    # TODO: return a scalar node
    return add_node!([nodeHandles...]) do nodes...
        dist = Distance(nodes...)
        println(dist)
        return dist
    end
end
#endregion


#region Closest Point
function ClosestPoint(coord::Vec3D,line::Union{PLine,PRay,PSegment})::Vec3D
    point = p0(line)
    dir = v(line)
    t = dot(coord - point,dir) / dot(dir,dir)
    projected = point + dir * ClampParameter(line,t)
    return projected
end
function ClosestPoint(coord::Vec3D,plane::PPlane)::Vec3D
    signedDist = dot(n(plane),coord - p0(plane))
    return coord - (n(plane) * signedDist)
end
function ClosestPoint(coord::Vec3D,sphere::Sphere)::Vec3D # sphere primtives of: triangles!
    dir = normalize(coord - p0(sphere))
    if (dir === Vec3DNan) return Vec3DNan end
    return p0(sphere) + dir * r(sphere)
end
# https://www.geometrictools.com/Documentation/DistanceToCircle3.pdf
function ClosestPoint(coord::Vec3D,circle::Circle)::Vec3D
    centerToCoord = coord - p0(circle)
    centerToProjected = centerToCoord - dot(n(circle),centerToCoord) * n(circle)
    return p0(circle) + r(circle) * normalize(centerToProjected)
end
function ClosestPoint(coord::Vec3D,triangle::PTriangle)::Vec3D
    inTriangle = PrimitiveToPrimitiveIntersection(triangle,PLine(coord,coord + n(triangle)))
    if (inTriangle !== nothing)
        return inTriangle
    else
        a = PSegment(triangle.v0,triangle.v1)
        b = PSegment(triangle.v1,triangle.v2)
        c = PSegment(triangle.v2,triangle.v0)
        a_cp = ClosestPoint(coord,a)
        b_cp = ClosestPoint(coord,b)
        c_cp = ClosestPoint(coord,c)
        return ClosestPoint(coord,[a_cp,b_cp,c_cp])
    end
end
function ClosestPoint(coord::Vec3D,geometry::Any)::Vec3D
    primitives = PrimitivesOf(geometry)

    closest = Vec3DNan
    for primitive in primitives
        cp = ClosestPoint(coord,primitive)
        closest = ClosestPoint(coord,[closest,cp])
    end

    return closest
end
function ClosestPoint(coord::Vec3D,coord_list::Vector{Vec3D})::Vec3D
    if (length(coord_list) == 0) return Vec3DNan end

    closest::Vec3D = coord_list[1]
    closest_dist::Float64 = Distance(coord, coord_list[1])
    for i in 2:length(coord_list)
        dist = Distance(coord, coord_list[i])
        if (dist < closest_dist || closest_dist === NaN)
            closest_dist = dist
            closest = coord_list[i]
        end
    end

    return closest
end
function ClosestPoint(nodeHandles::NodeHandle...;
    color_style::Union{Nothing,String}=nothing,color="w",style=".",size=25,axis_constraint=AXIS_NONE)::NodeHandle
    
    return Point([nodeHandles...],color_style;color=color,style=style,size=size,axis_constraint=axis_constraint) do nodes...
        return ClosestPoint(nodes...)
    end
end
#endregion


#region Perpendicular Line & Plane
function PerpendicularLine(coord::Vec3D,plane::Plane)::Tuple{Vec3D,Vec3D}
    return (coord,coord + n(plane))
end
function PerpendicularLine(coord::Vec3D,line::Union{Line,Ray,Segment})::Tuple{Vec3D,Vec3D}
    t = dot(coord - p0(line), v(line))
    projected_to_line = p0(line) + v(line) * t
    return (coord,projected_to_line)
end
function PerpendicularLine(nodeHandles::NodeHandle...;
    color_style::Union{Nothing,String}=nothing,color="g",style="-",size::Union{AbstractFloat,Integer}=3.0f0)::NodeHandle

    return Line([nodeHandles...],color_style;color=color,style=style,size=size) do nodes...
        return PerpendicularLine(nodes...)
    end
end

function PerpendicularPlane(coord::Vec3D,line::Union{Line,Ray,Segment})::Tuple{Vec3D,Vec3D}
    return (coord,v(line))
end
function PerpendicularPlane(coord1::Vec3D,coord2::Vec3D)::Tuple{Vec3D,Vec3D}
    return ((coord1 + coord2) / 2.0,normalize(coord2 - coord1))
end
function PerpendicularPlane(nodeHandles::NodeHandle...;
    color_style::Union{Nothing,String}=nothing,color="g")::NodeHandle
    
    return Plane([nodeHandles...],color_style;color=color) do node...
        return PerpendicularPlane(node...)
    end
end

function Perpendicular(nodeHandles::NodeHandle...;
    color_style::Union{Nothing,String}=nothing,color="g",style="-",size::Union{AbstractFloat,Integer}=3.0f0)::NodeHandle
    
    node2 = get_element(nodeHandles[2])

    if (isa(node2, Plane))
        return PerpendicularLine(nodeHandles...;color_style=color_style,color=color,style=style,size=size)
    else
        return PerpendicularPlane(nodeHandles...;color_style=color_style,color=color)
    end
end
#endregion


#region Parallel Line & Plane
function ParallelLine(coord::Vec3D,line::Union{Line,Ray,Segment})::Tuple{Vec3D,Vec3D}
    return (coord,coord + v(line))
end
function ParallelLine(coord1::Vec3D,coord2::Vec3D,coord3::Vec3D)::Tuple{Vec3D,Vec3D}
    dir = coord3 - coord2
    return (coord1,coord1 + dir)
end
function ParallelLine(nodeHandles::NodeHandle...;
    color_style::Union{Nothing,String}=nothing,color="g",style="-",size::Union{AbstractFloat,Integer}=3.0f0)::NodeHandle
    
    return Line([nodeHandles...],color_style;color=color,style=style,size=size) do nodes...
        return ParallelLine(nodes...)
    end
end

function ParallelPlane(coord::Vec3D,geometry_with_normal::Union{Plane})::Tuple{Vec3D,Vec3D} # TODO: triangle, circle
    return (coord,n(geometry_with_normal))
end
function ParallelPlane(line1::Union{Line,Ray,Segment},line2::Union{Line,Ray,Segment})::Tuple{Vec3D,Vec3D}
    dir1 = v(line1)
    dir2 = v(line2)
    normal = normalize(cross(dir1,dir2))
    return (p0(line1),normal)
end
function ParallelPlane(nodeHandles::NodeHandle...;
    color_style::Union{Nothing,String}=nothing,color="g")
    
    return Plane([nodeHandles...],color_style;color=color) do nodes...
        return ParallelPlane(nodes...)
    end
end

function Parallel(nodeHandles::NodeHandle...;
    color_style::Union{Nothing,String}=nothing,color="g",style="-",size::Union{AbstractFloat,Integer}=3.0f0)
    
    node1 = get_element(nodeHandles[1])
    node2 = get_element(nodeHandles[2])
    if (isa(node1, Union{Line,Ray,Segment}) || isa(node2, Plane))
        return ParallelPlane(nodeHandles...;color_style=color_style,color=color)
    else
        return ParallelLine(nodeHandles...;color_style,color=color,style=style,size=size)
    end
end
#endregion




export Midpoint, Distance, ClosestPoint, PerpendicularLine, PerpendicularPlane, Perpendicular, ParallelLine, ParallelPlane, Parallel


