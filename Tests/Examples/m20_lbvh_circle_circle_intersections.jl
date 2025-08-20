include("../../Prototype/juliagebra.jl")
using .JuliAgebra
using .JuliAgebra.LinearAlgebra
using StaticArrays

App()

struct Circle
    o::SVector{2, Float32}
    r::Float32
end

function GetAABBCircle(circle::Circle)::AABB2D
    return AABB2D((circle.o .- circle.r), (circle.o .+ circle.r))
end

function onIntersection(p1::SVector{2, Float32}, p2::SVector{2, Float32})
    Point(p1[1], 0.001, p1[2])
    Point(p2[1], 0.001, p2[2])
end

function CircleToCircleIntersection(circle_a::Circle, circle_b::Circle)::Union{Bool, Tuple{Bool, SVector{2, Float32}, SVector{2, Float32}}}
    diff::SVector{2, Float32} = circle_b.o .- circle_a.o

    dd::Float32 = dot(diff, diff)
    do_intersect::Bool = ((dd <= (circle_a.r + circle_b.r)^2) && (dd >= abs(circle_a.r - circle_b.r)^2) && dd > 0)
    if (do_intersect)
        d::Float32 = sqrt(dd)
        a::Float32 = (circle_a.r * circle_a.r - circle_b.r * circle_b.r + dd) / (2 * d)
        h::Float32 = sqrt(circle_a.r * circle_a.r - a * a)
        x2::Float32 = circle_a.o[1] + a * (circle_b.o[1] - circle_a.o[1]) / d
        y2::Float32 = circle_a.o[2] + a * (circle_b.o[2] - circle_a.o[2]) / d
        x3::Float32 = x2 + h * (circle_b.o[2] - circle_a.o[2]) / d
        y3::Float32 = y2 - h * (circle_b.o[1] - circle_a.o[1]) / d
        x4::Float32 = x2 - h * (circle_b.o[2] - circle_a.o[2]) / d
        y4::Float32 = y2 + h * (circle_b.o[1] - circle_a.o[1]) / d
        return true, SVector{2, Float32}(x3, y3), SVector{2, Float32}(x4, y4)
    else
        return false
    end
end

function circle(ox, oy, radius,t)
    x = cos(t) * radius + ox
    y = 0
    z = sin(t) * radius + oy # watch out: the circle is visualized along x and z axis but the circle origin cames as x and y coordinates
    return (x,y,z)
end

n = 100

l = -10.0
t = -5.0

w = 20.0
h = 10.0

radius_range = 2

origins = rand(n, 2)
radiuses = rand(n)

origins[:, 1] = (w .* origins[:, 1]) .+ l
origins[:, 2] = (h .* origins[:, 2]) .+ t
radiuses = radius_range .* radiuses

circles = Vector{Circle}(undef, n)

for i in 0:(n - 1)
    ox = origins[2 * i + 1]
    oy = origins[2 * i + 1 + 1]
    r = radiuses[i + 1]
    circles[i + 1] = Circle(SVector{2, Float32}(ox, oy), r)
    c = ParametricCurve(0, 2 * pi, 50) do t
        circle(ox, oy, r, t)
    end
end

lbvh_nodes, number_of_leafs, number_of_internal_nodes = BuildLBVH(GetAABBCircle.(circles), UInt32)

for i in 0:(length(circles) - 1)
    println(GetAABBCircle(circles[i + 1]), "  ", origins[2 * i + 1], " ", origins[2 * i + 1 + 1], "   ", radiuses[i + 1])
    LBVHToPrimitiveIntersection(
        lbvh_nodes,
        circles,
        number_of_internal_nodes, 
        number_of_leafs,
        circles[i + 1],
        GetAABBCircle(circles[i + 1]),
        CircleToCircleIntersection,
        onIntersection
    )
end

play!()