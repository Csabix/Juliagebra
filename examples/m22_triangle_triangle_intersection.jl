include("../../Prototype/juliagebra.jl")
using .JuliAgebra
using .JuliAgebra.LinearAlgebra
using StaticArrays
using LinearAlgebra

App()

struct Triangle
    v0::SVector{3, Float32}
    v1::SVector{3, Float32}
    v2::SVector{3, Float32}
end

function Isect2(
    VTX0::SVector{3, Float32},
    VTX1::SVector{3, Float32},
    VTX2::SVector{3, Float32},
    D0::Float32, 
    D1::Float32, 
    D2::Float32
)::Tuple{SVector{3, Float32}, SVector{3, Float32}}
    tmp0::Float32 = D0 / (D0 - D1)
    tmp1::Float32 = D0 / (D0 - D2);
    isectpoint0::SVector{3, Float32} = VTX0 .+ (tmp0 .* (VTX1 .- VTX0))
    isectpoint1::SVector{3, Float32} = VTX0 .+ (tmp1 .* (VTX2 .- VTX0))

    return isectpoint0, isectpoint1
end

function ComputeIntervalsIsectline(
    triangle::Triangle,
    D0::Float32, 
    D1::Float32, 
    D2::Float32
)::Tuple{SVector{3, Float32}, SVector{3, Float32}}
    if ((D0 * D1) > 0.0)
        return Isect2(triangle.v2, triangle.v0, triangle.v1, D2, D0, D1)
    elseif ((D0 * D2) > 0.0)
        return Isect2(triangle.v1, triangle.v0, triangle.v2, D1, D0, D2)
    elseif ((D1 * D2) > 0.0)
        return Isect2(triangle.v0, triangle.v1, triangle.v2, D0, D1, D2)
    elseif (D0 != 0.0)
        return Isect2(triangle.v0, triangle.v1, triangle.v2, D0, D1, D2)
    elseif (D1 != 0.0)
        return Isect2(triangle.v1, triangle.v0, triangle.v2, D1, D0, D2)
    else #if (D2 != 0.0) not needed because its not coplanar
        return Isect2(triangle.v2, triangle.v0, triangle.v1, D2, D0, D1)
    end
end

function IsCoplanar(D0::Float32, D1::Float32, D2::Float32)::Bool
    return ((D0 == 0.0) && (D1 == 0.0) && (D2 == 0.0))
end

function EpsilonTest(N::SVector{3, Float32}, V::SVector{3, Float32}, triangle::Triangle)::Tuple{Float32, Float32, Float32}
    d1::Float32 = -dot(N, V)

    du0::Float32 = dot(N, triangle.v0) + d1
    du1::Float32 = dot(N, triangle.v1) + d1
    du2::Float32 = dot(N, triangle.v2) + d1

#if USE_EPSILON_TEST == TRUE
    if (abs(du0) < 0.000001) 
        du0 = 0.0
    end
    if (abs(du1) < 0.000001)
        du1 = 0.0
    end
    if (abs(du2) < 0.000001)
        du2 = 0.0
    end
#endif

    return du0, du1, du2
end


function TriangleTriangleIntersectionWithIsectline(triangle_a::Triangle, triangle_b::Triangle)::Union{Bool, Tuple{Bool, SVector{3, Float32}, SVector{3, Float32}}}
    N1::SVector{3, Float32} = cross((triangle_a.v1 .- triangle_a.v0), (triangle_a.v2 .- triangle_a.v0))
    du0::Float32, du1::Float32, du2::Float32 = EpsilonTest(N1, triangle_a.v0, triangle_b)
    if (((du0 * du1) > 0.0) && ((du0 * du2) > 0.0))
        return false
    end
    
    N2::SVector{3, Float32} = cross((triangle_b.v1 .- triangle_b.v0), (triangle_b.v2 .- triangle_b.v0))
    dv0::Float32, dv1::Float32, dv2::Float32 = EpsilonTest(N2, triangle_b.v0, triangle_a)
    if (((dv0 * dv1) > 0.0) && ((dv0 * dv2) > 0.0))
        return false
    end

    if (IsCoplanar(dv0, dv1, dv2))
        return false
    end

    D::SVector{3, Float32} = abs.(cross(N1, N2))
    index::UInt = 0
    if (D[1 + 1] > D[0 + 1])
        if (D[2 + 1] > D[1 + 1])
            index = 2
        else
            index = 1
        end
    elseif (D[2 + 1] > D[0 + 1])
        index = 2
    end

    isectpointA1::SVector{3, Float32}, isectpointA2::SVector{3, Float32} = ComputeIntervalsIsectline(triangle_a, dv0, dv1, dv2)
    isectpointB1::SVector{3, Float32}, isectpointB2::SVector{3, Float32} = ComputeIntervalsIsectline(triangle_b, du0, du1, du2)

    isect10 = min(isectpointA1[index + 1], isectpointA2[index + 1])
    isect11 = max(isectpointA1[index + 1], isectpointA2[index + 1])
    isect20 = min(isectpointB1[index + 1], isectpointB2[index + 1])
    isect21 = max(isectpointB1[index + 1], isectpointB2[index + 1])

    if ((isect11 < isect20) || (isect21 < isect10))
        return false
    end

    isectpt1 = MVector{3, Float32}(undef)
    isectpt2 = MVector{3, Float32}(undef)

    if (isect20 < isect10)
        if (isectpointA1[index + 1] <= isectpointA2[index + 1])
            isectpt1 = isectpointA1
        else
            isectpt1 = isectpointA2
        end
    else
        if (isectpointB1[index + 1] <= isectpointB2[index + 1])
            isectpt1 = isectpointB1
        else
            isectpt1 = isectpointB2
        end
    end
    
    if (isect21 < isect11)
        if (isectpointB1[index + 1] <= isectpointB2[index + 1])
            isectpt2 = isectpointB2
        else
            isectpt2 = isectpointB1
        end
    else
        if (isectpointA1[index + 1] <= isectpointA2[index + 1])
            isectpt2 = isectpointA2
        else
            isectpt2 = isectpointA1
        end
    end

    return true, isectpt1, isectpt2
end

function DisplaySegment(p1::SVector{3, Float32}, p2::SVector{3, Float32})
    dp1 = Point(p1[1], p1[2], p1[3])
    dp2 = Point(p2[1], p2[2], p2[3])

    Segment(dp1, dp2, (1.0,0.6,0.0))
end

function DisplayTriangle(triangle::Triangle)
    p0 = Point(triangle.v0[1], triangle.v0[2], triangle.v0[3])
    p1 = Point(triangle.v1[1], triangle.v1[2], triangle.v1[3])
    p2 = Point(triangle.v2[1], triangle.v2[2], triangle.v2[3])

    Segment(p0, p1, (1.0,0.6,0.0))
    Segment(p1, p2, (1.0,0.6,0.0))
    Segment(p2, p0, (1.0,0.6,0.0))

    ParametricSurface(3.0, 3.0, 0.0, 1.0, 0.0, 1.0, [p0, p1, p2]) do u, v, a, b, c
        if ((u >= 0.5) && (v >= 0.5))
            u = 0.5
            v = 0.5
        end
        return ((1.0 - u - v) .* a[:xyz]) .+ (u .* b[:xyz]) .+ (v .* c[:xyz])
    end
end

t1 = Triangle(SVector(-1.0, -11.0, 6.0), SVector(6.0, 8.0, 14.0), SVector(12.0, 0.0, -8.0))
t2 = Triangle(SVector(-5.0, -11.0, 6.0), SVector(6.0, 6.0, 14.0), SVector(15.0, -2.0, -8.0))

DisplayTriangle(t1)
DisplayTriangle(t2)

intersects, p1, p2 = TriangleTriangleIntersectionWithIsectline(t1, t2)

if (intersects)
    DisplaySegment(p1, p2)
end

play!()