
"""
Repsresentation of a segment primitive.
- p0, p1 are the start and end points of the segment.
"""
struct PSegment <: AABBPrimitive
    p0::Vec3F
    p1::Vec3F
end

function GetAABB(line_segment::PSegment)::AABB3D
    return AABB3D(min.(line_segment.p0, line_segment.p1), max.(line_segment.p0, line_segment.p1))
end

"""
Representation of a triangle primitive.
- v0, v1, v2 are the corners of the triangle.
"""
struct PTriangle <: AABBPrimitive
    v0::Vec3F
    v1::Vec3F
    v2::Vec3F
end

function GetAABB(triangle::PTriangle)::AABB3D
    return AABB3D(min.(triangle.v0, min.(triangle.v1, triangle.v2)), max.(triangle.v0, max.(triangle.v1, triangle.v2)))
end

"""
Infinite representation of a line primitive.
- p is a point on the line.
- v is the direction vector.
"""
struct PLine <: Primitive
    p::Vec3D
    v::Vec3D
end

Base.convert(::Type{PLine},::Nothing)::PLine = return PLine(Vec3DNan,Vec3DNan)

"""
Infinite representation of a plane primitive.
- p is a point on the plane.
- n is the normal vector of the plane.
"""
struct PPlane <: Primitive
    p::Vec3D
    n::Vec3D
end

Base.convert(::Type{PPlane},::Nothing)::PPlane = return PPlane(Vec3DNan,Vec3DNan)

"""
Representation of a primitive sphere.
- c is the center of the sphere.
- r is the size of the radius of the sphere.
"""
struct PSphere <: Primitive
    c::Vec3D
    r::Float64
end

Base.convert(::Type{PSphere},::Nothing)::PSphere = return PSphere(Vec3DNan,NaN64)




