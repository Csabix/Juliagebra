include("../../Prototype/juliagebra.jl")
using .JuliAgebra
using .JuliAgebra.LinearAlgebra
using StaticArrays

App()

struct LineSegment2D
    p1::SVector{2, Float32}
    p2::SVector{2, Float32}
end

function GetAABBLineSegment2D(line_segment::LineSegment2D)::AABB2D
    return AABB2D(min.(line_segment.p1, line_segment.p2), max.(line_segment.p1, line_segment.p2))
end

function onIntersection(p::SVector{2, Float32})
    Point(p[1], 0.001, p[2])
end

function CrossProduct2D(a::SVector{2, Float32}, b::SVector{2, Float32})::Float32
    return ((a[1] * b[2]) - (a[2] * b[1]))
end

function Segment2SegmentIntersection(line_segment_a::LineSegment2D, line_segment_b::LineSegment2D)::Tuple{Bool, SVector{2, Float32}}
    va::SVector{2, Float32} = line_segment_a.p2 .- line_segment_a.p1
    vb::SVector{2, Float32} = line_segment_b.p2 .- line_segment_b.p1

    vba::SVector{2, Float32} = line_segment_a.p1 .- line_segment_b.p1

    denom::Float32 = CrossProduct2D(va, vb)

    s::Float32 = CrossProduct2D(va, vba) / denom
    t::Float32 = CrossProduct2D(vb, vba) / denom

    p::SVector{2, Float32} = line_segment_a.p1 .+ t * va
    
    return (s >= 0.0 && s <= 1.0 && t >= 0.0 && t <= 1.0), p
end

n = 100

l = -10.0
t = -5.0

w = 20.0
h = 10.0

starts = rand(n, 2)
ends = rand(n, 2)

starts[:, 1] = (w .* starts[:, 1]) .+ l
starts[:, 2] = (h .* starts[:, 2]) .+ t
ends[:, 1] = (w .* ends[:, 1]) .+ l
ends[:, 2] = (h .* ends[:, 2]) .+ t

segments = Vector{LineSegment2D}(undef, n)

for i in 0:(n - 1)
    p1x = starts[2 * i + 1]
    p1y = starts[2 * i + 1 + 1]
    p2x = ends[2 * i + 1]
    p2y = ends[2 * i + 1 + 1]
    segments[i + 1] = LineSegment2D(SVector{2, Float32}(p1x, p1y), SVector{2, Float32}(p2x, p2y))
    p1 = Point(p1x, 0.001, p1y)
    p2 = Point(p2x, 0.001, p2y)
    s = Segment(p1, p2)
end

lbvh_nodes, number_of_leafs, number_of_internal_nodes = BuildLBVH(GetAABBLineSegment2D.(segments), UInt32)

for i in 0:(length(segments) - 1)
    LBVHToPrimitiveIntersection(
        lbvh_nodes,
        segments,
        number_of_internal_nodes, 
        number_of_leafs,
        segments[i + 1],
        GetAABBLineSegment2D(segments[i + 1]),
        Segment2SegmentIntersection,
        onIntersection
    )
end

play!()