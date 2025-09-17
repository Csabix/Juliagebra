using Juliagebra
using Juliagebra.LinearAlgebra
using StaticArrays
using LinearAlgebra

App()

struct LineSegment2D
    p1::SVector{2, Float32}
    p2::SVector{2, Float32}
end

struct Circle
    o::SVector{2, Float32}
    r::Float32
end

function GetAABBLineSegment2D(line_segment::LineSegment2D)::AABB2D
    return AABB2D(min.(line_segment.p1, line_segment.p2), max.(line_segment.p1, line_segment.p2))
end

function GetAABBCircle(circle::Circle)::AABB2D
    return AABB2D((circle.o .- circle.r), (circle.o .+ circle.r))
end

function onIntersection(points::Vector{SVector{2, Float32}})
    for i in 0:(length(points) - 1)
        Point(points[i + 1][1], 0.001, points[i + 1][2])
    end
end

function LineSegment2DToCircleIntersection(line_segment::LineSegment2D, circle::Circle)::Tuple{Bool, Vector{SVector{2, Float32}}}
    v::SVector{2, Float32} = line_segment.p2 .- line_segment.p1
    f::SVector{2, Float32} = line_segment.p1 .- circle.o

    a::Float32 = dot(v, v)
    b::Float32 = 2.0 * dot(f, v)
    c::Float32 = dot(f, f) - (circle.r * circle.r)

    d::Float32 = (b * b - 4.0 * a * c)
    
    if (d < 0.0)
        return false, []
    end

    sqrt_d::Float32 = sqrt(d)

    t1::Float32 = (-b + sqrt_d) / (2.0 * a)
    t2::Float32 = (-b - sqrt_d) / (2.0 * a)
    
    points::Vector{SVector{2, Float32}} = Vector{SVector{2, Float32}}[]
    if ((t1 >= 0.0) && (t1 <= 1.0))
        push!(points, SVector{2, Float32}(line_segment.p1 .+ t1 .* v))
    end
    if ((t2 >= 0.0) && (t2 <= 1.0)) && (t1 != t2)
        push!(points, SVector{2, Float32}(line_segment.p1 .+ t2 .* v))
    end

    return !isempty(points), points
end

function circle(ox, oy, radius,t)
    x = cos(t) * radius + ox
    y = 0
    z = sin(t) * radius + oy # watch out: the circle is visualized along x and z axis but the circle origin cames as x and y coordinates
    return (x,y,z)
end

segment_n = 200
circle_n = 100
radius_range = 2

l = -10.0
t = -5.0

w = 20.0
h = 10.0

starts = rand(segment_n, 2)
ends = rand(segment_n, 2)

origins = rand(circle_n, 2)
radiuses = rand(circle_n)

starts[:, 1] = (w .* starts[:, 1]) .+ l
starts[:, 2] = (h .* starts[:, 2]) .+ t
ends[:, 1] = (w .* ends[:, 1]) .+ l
ends[:, 2] = (h .* ends[:, 2]) .+ t

origins[:, 1] = (w .* origins[:, 1]) .+ l
origins[:, 2] = (h .* origins[:, 2]) .+ t
radiuses = radius_range .* radiuses

segments = Vector{LineSegment2D}(undef, segment_n)
circles = Vector{Circle}(undef, circle_n)

for i in 0:(segment_n - 1)
    p1x = starts[2 * i + 1]
    p1y = starts[2 * i + 1 + 1]
    p2x = ends[2 * i + 1]
    p2y = ends[2 * i + 1 + 1]
    segments[i + 1] = LineSegment2D(SVector{2, Float32}(p1x, p1y), SVector{2, Float32}(p2x, p2y))
    p1 = Point(p1x, 0.001, p1y)
    p2 = Point(p2x, 0.001, p2y)
    s = Segment(p1, p2)
end

for i in 0:(circle_n - 1)
    ox = origins[2 * i + 1]
    oy = origins[2 * i + 1 + 1]
    r = radiuses[i + 1]
    circles[i + 1] = Circle(SVector{2, Float32}(ox, oy), r)
    c = ParametricCurve(0, 2 * pi, 50) do t
        circle(ox, oy, r, t)
    end
end

lbvh_nodes, number_of_leafs, number_of_internal_nodes = BuildLBVH(GetAABBCircle.(circles), UInt32)

for i in 0:(length(segments) - 1)
    LBVHToPrimitiveIntersection(
        lbvh_nodes,
        circles,
        number_of_internal_nodes, 
        number_of_leafs,
        segments[i + 1],
        GetAABBLineSegment2D(segments[i + 1]),
        LineSegment2DToCircleIntersection,
        onIntersection
    )
end

play!()