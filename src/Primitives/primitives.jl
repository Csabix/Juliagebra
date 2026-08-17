
"""
Repsresentation of a segment primitive.
- p0, p1 are the start and end points of the segment.
"""
struct PSegment <: AABBPrimitive3D
    p0::Vec3D
    p1::Vec3D
end

function GetAABB(line_segment::PSegment)::AABB3D
    return AABB3D(min.(line_segment.p0, line_segment.p1), max.(line_segment.p0, line_segment.p1))
end

Base.convert(::Type{PSegment},::Nothing)::PSegment = return PSegment(Vec3DNan,Vec3DNan)

export PSegment

"""
Representation of a triangle primitive.
- v0, v1, v2 are the corners of the triangle.
"""
struct PTriangle <: AABBPrimitive3D
    v0::Vec3D
    v1::Vec3D
    v2::Vec3D
end

function GetAABB(triangle::PTriangle)::AABB3D
    return AABB3D(min.(triangle.v0, min.(triangle.v1, triangle.v2)), max.(triangle.v0, max.(triangle.v1, triangle.v2)))
end

"""
Infinite representation of a line primitive.
- p0 is a point on the line.
- p1 is the second point that defines the direction.
"""
struct PLine <: Primitive
    p0::Vec3D
    p1::Vec3D
end

Base.convert(::Type{PLine},::Nothing)::PLine = return PLine(Vec3DNan,Vec3DNan)

"""
Infinite representation of a ray primitive.
- p0 is the end point on the ray.
- p1 is the second point that defines the direction.
"""
struct PRay <: Primitive
    p0::Vec3D
    p1::Vec3D
end

Base.convert(::Type{PRay},::Nothing)::PRay = return PRay(Vec3DNan,Vec3DNan)

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

"""
Representation of a primitive circle.
- c is the center of the circle.
- r is the radius of the circle.
- n is the normal of the plane that the circle lies on.
"""
struct PCircle <: Primitive
    c::Vec3D
    r::Float64
    n::Vec3D
end

Base.convert(::Type{PCircle},::Nothing)::PCircle = return PCircle(Vec3DNan,NaN64,Vec3DNan)



const DefaultPlane::PPlane = PPlane(Vec3D(0),Vec3D(0,0,1))

ParameterInside(::PLine,::Any)::Bool = true
ParameterInside(::PRay,t)::Bool      = t >= 0.0
ParameterInside(::PSegment,t)::Bool  = t >= 0.0 && t <= 1.0

ClampParameter(::PLine,t)    = t
ClampParameter(::PRay,t)     = max(0.0, t)
ClampParameter(::PSegment,t) = clamp(t, 0.0, 1.0)

p0(line::PLine)::Vec3D       = line.p0
p0(ray::PRay)::Vec3D         = ray.p0
p0(segment::PSegment)::Vec3D = segment.p0
p0(plane::PPlane)::Vec3D     = plane.p
p0(sphere::PSphere)::Vec3D   = sphere.c
p0(circle::PCircle)::Vec3D   = circle.c

p1(line::PLine)::Vec3D       = line.p1
p1(ray::PRay)::Vec3D         = ray.p1
p1(segment::PSegment)::Vec3D = segment.p1

v(line::PLine)::Vec3D       = line.p1 - line.p0
v(ray::PRay)::Vec3D         = ray.p1 - ray.p0
v(segment::PSegment)::Vec3D = segment.p1 - segment.p0

n(plane::PPlane)::Vec3D       = plane.n
n(triangle::PTriangle)::Vec3D = cross(triangle.v1 - triangle.v0,triangle.v2 - triangle.v0)
n(circle::PCircle)::Vec3D     = circle.n

r(sphere::PSphere)::Float64 = sphere.r
r(circle::PCircle)::Float64 = circle.r

