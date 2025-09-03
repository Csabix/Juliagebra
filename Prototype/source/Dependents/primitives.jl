struct LineSegment
    p0::Vec3F
    p1::Vec3F
end

function GetAABB(line_segment::LineSegment)::AABB3D
    return AABB3D(min.(line_segment.p0, line_segment.p1), max.(line_segment.p0, line_segment.p1))
end

struct Triangle
    v0::Vec3F
    v1::Vec3F
    v2::Vec3F
end

function GetAABB(triangle::Triangle)::AABB3D
    return AABB3D(min.(triangle.v0, min.(triangle.v1, triangle.v2)), max.(triangle.v0, max.(triangle.v1, triangle.v2)))
end
