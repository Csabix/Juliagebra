
#region Midpoint
midpoint_count(p::Vec3D)::Tuple{Vec3D,Integer} = (p,1)
midpoint_count(p::Point)::Tuple{Vec3D,Integer} = (p.coord,1)
midpoint_count(coords::AbstractVector{Vec3D})::Tuple{Vec3D,Integer} = (sum(coords),length(coords))
midpoint_count(point_sequence::PointSequence)::Tuple{Vec3D,Integer} = midpoint_count(point_sequence.coords)
midpoint_count(point_set::PointSet)::Tuple{Vec3D,Integer}           = midpoint_count(point_set.coords)

function midpoint(nodes::Any...)::Vec3D
    sum::Vec3D = Vec3D(0.0)
    count::Integer = 0

    for node in nodes
        (plus_sum,plus_count) = midpoint_count(node)
        sum += plus_sum
        count += plus_count
    end
    
    if (count == 0)
        return Vec3DNan
    else
        return sum / count
    end
end
#endregion

#region Distance
distance(coord1::Vec3D,coord2::Vec3D)::Float64 = hypot(coord1.x - coord2.x, coord1.y - coord2.y, coord1.z - coord2.z)
distance(coord::Vec3D,plane::Plane)::Float64   = abs(dot(n(plane),coord - p0(plane)))
distance(coord::Vec3D,sphere::Sphere)::Float64 = abs(distance(coord,p0(sphere)) - r(sphere))
distance(coord::Vec3D,circle::Circle)::Float64 = distance(coord,closest_point(coord,circle))
distance(coord::Vec3D,geometry::Any)::Float64  = distance(coord,closest_point(coord,geometry))
#endregion

#region Closest Point
function closest_point(coord::Vec3D,line::Union{PLine,PRay,PSegment})::Vec3D
    point = p0(line)
    dir = v(line)
    t = dot(coord - point,dir) / dot(dir,dir)
    projected = point + dir * ClampParameter(line,t)
    return projected
end
function closest_point(coord::Vec3D,plane::PPlane)::Vec3D
    signedDist = dot(n(plane),coord - p0(plane))
    return coord - (n(plane) * signedDist)
end
function closest_point(coord::Vec3D,sphere::Sphere)::Vec3D
    dir = normalize(coord - p0(sphere))
    if (dir === Vec3DNan) return Vec3DNan end
    return p0(sphere) + dir * r(sphere)
end
# https://www.geometrictools.com/Documentation/DistanceToCircle3.pdf
function closest_point(coord::Vec3D,circle::PCircle)::Vec3D
    centerToCoord = coord - p0(circle)
    centerToProjected = centerToCoord - dot(n(circle),centerToCoord) * n(circle)
    return p0(circle) + r(circle) * normalize(centerToProjected)
end
function closest_point(coord::Vec3D,triangle::PTriangle)::Vec3D
    inTriangle = PrimitiveToPrimitiveIntersection(triangle,PLine(coord,coord + n(triangle)))
    if (inTriangle !== nothing)
        return inTriangle
    else
        a = PSegment(triangle.v0,triangle.v1)
        b = PSegment(triangle.v1,triangle.v2)
        c = PSegment(triangle.v2,triangle.v0)
        a_cp = closest_point(coord,a)
        b_cp = closest_point(coord,b)
        c_cp = closest_point(coord,c)
        return closest_point(coord,[a_cp,b_cp,c_cp])
    end
end
function closest_point(coord::Vec3D,geometry::Any)::Vec3D
    primitives = PrimitivesOf(geometry)

    closest = Vec3DNan
    for primitive in primitives
        cp = closest_point(coord,primitive)
        closest = closest_point(coord,[closest,cp])
    end

    return closest
end
function closest_point(coord::Vec3D,coord_list::Vector{Vec3D})::Vec3D
    if (length(coord_list) == 0) return Vec3DNan end

    closest::Vec3D = coord_list[1]
    closest_dist::Float64 = distance(coord, coord_list[1])
    for i in 2:length(coord_list)
        dist = distance(coord, coord_list[i])
        if (dist < closest_dist || closest_dist === NaN)
            closest_dist = dist
            closest = coord_list[i]
        end
    end

    return closest
end
#endregion

#region Perpendicular Line & Plane
perpendicular_line(coord::Vec3D,geometry_with_normal::Union{Plane,Circle})::Tuple{Vec3D,Vec3D} = (coord,coord + n(geometry_with_normal))
perpendicular_line(coord::Vec3D,line::Union{Line,Ray,Segment})::Tuple{Vec3D,Vec3D} = (coord,project_to_line(coord,line))
function perpendicular_line(line::Union{Line,Ray,Segment},coord::Vec3D)::Tuple{Vec3D,Vec3D}
    projected_to_line = project_to_line(coord,line)
    perp = cross(v(line),coord - projected_to_line)
    return (projected_to_line,projected_to_line + perp)
end

perpendicular_plane(coord::Vec3D,line::Union{Line,Ray,Segment})::Tuple{Vec3D,Vec3D} = (coord,v(line))
perpendicular_plane(coord1::Vec3D,coord2::Vec3D)::Tuple{Vec3D,Vec3D} = ((coord1 + coord2) / 2.0,normalize(coord2 - coord1))
#endregion

#region Parallel Line & Plane
parallel_line(coord::Vec3D,line::Union{Line,Ray,Segment})::Tuple{Vec3D,Vec3D} = (coord,coord + v(line))
parallel_line(coord1::Vec3D,coord2::Vec3D,coord3::Vec3D)::Tuple{Vec3D,Vec3D} = (coord1,coord1 + coord3 - coord2)

parallel_plane(coord::Vec3D,geometry_with_normal::Union{Plane,Circle})::Tuple{Vec3D,Vec3D} = (coord,n(geometry_with_normal))
function parallel_plane(line1::Union{Line,Ray,Segment},line2::Union{Line,Ray,Segment})::Tuple{Vec3D,Vec3D}
    dir1 = v(line1)
    dir2 = v(line2)
    normal = normalize(cross(dir1,dir2))
    return (p0(line1),normal)
end
#endregion

function project_to_line(coord::Vec3D,line::Union{Line,Ray,Segment})::Vec3D
    t = dot(coord - p0(line), v(line))
    return p0(line) + v(line) * t
end
