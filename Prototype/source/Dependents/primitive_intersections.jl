EPSILON = 0.1

function Segment2SegmentIntersection(line_segment_a::LineSegment, line_segment_b::LineSegment)::Union{Nothing, Vec3F}
    v1 = line_segment_a.p1 - line_segment_a.p0
    v2 = line_segment_b.p1 - line_segment_b.p0

    n_up = normalize(cross(v1,v2))
    
    d = abs(dot(line_segment_b.p0-line_segment_a.p0,n_up))
    if( d > EPSILON)
        return nothing
    end

    plane_n  = normalize(cross(v1,n_up))    
    plane_q0 = line_segment_a.p0
    ray_p0 = line_segment_b.p0
    ray_v  = v2
    t = dot(plane_q0-ray_p0,plane_n)/dot(ray_v,plane_n)
    if (t > 1.0 || t<0.0)
        return nothing
    end

    hit1 = ray_p0 + t * ray_v

    plane_n  = normalize(cross(v2,n_up))    
    plane_q0 = line_segment_b.p0
    ray_p0 = line_segment_a.p0
    ray_v  = v1
    s = dot(plane_q0-ray_p0,plane_n)/dot(ray_v,plane_n)
    if (s > 1.0 || s<0.0)
        return nothing
    end

    hit2 = ray_p0 + s * ray_v

    hit = (hit1 + hit2) ./ 2

    return hit
end

function Segment2TriangleIntersection(line_segment::LineSegment, triangle::Triangle)::Union{Nothing, Vec3F}
    p0 = line_segment.p0
    v = line_segment.p1 - line_segment.p0

    ab = triangle.v1 - triangle.v0
    ac = triangle.v2 - triangle.v0
    ap = p0 - triangle.v0
    f = cross(v,ac)
    g = cross(ap,ab)

    m = (1.0 / dot(f, ab))

    t = m * dot(g, ac)
    u = m * dot(f, ap)
    v = m * dot(g, v)
    w = 1.0 - u - v

    if (0.0 <= t && t <= 1.0 && 0.0 <= u && 0.0 <= v && 0.0 <= w)
        return (line_segment.p0 + t * (line_segment.p1 - line_segment.p0))
    else
        nothing
    end
end

function Segment2TriangleIntersection(triangle::Triangle, line_segment::LineSegment)::Union{Nothing, Vec3F}
    return Segment2TriangleIntersection(line_segment, triangle)
end

function Isect2(
    VTX0::Vec3F,
    VTX1::Vec3F,
    VTX2::Vec3F,
    D0::Float32, 
    D1::Float32, 
    D2::Float32
)::Tuple{Vec3F, Vec3F}
    tmp0::Float32 = D0 / (D0 - D1)
    tmp1::Float32 = D0 / (D0 - D2);
    isectpoint0::Vec3F = VTX0 .+ (tmp0 .* (VTX1 .- VTX0))
    isectpoint1::Vec3F = VTX0 .+ (tmp1 .* (VTX2 .- VTX0))

    return isectpoint0, isectpoint1
end

function ComputeIntervalsIsectline(
    triangle::Triangle,
    D0::Float32, 
    D1::Float32, 
    D2::Float32
)::Tuple{Vec3F, Vec3F}
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

function EpsilonTest(N::Vec3F, V::Vec3F, triangle::Triangle)::Tuple{Float32, Float32, Float32}
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


#from https://fileadmin.cs.lth.se/cs/Personal/Tomas_Akenine-Moller/code/tritri_isectline.txt
function Triangle2TriangleIntersection(triangle_a::Triangle, triangle_b::Triangle)::Union{Nothing, LineSegment}
    N1::Vec3F = cross((triangle_a.v1 .- triangle_a.v0), (triangle_a.v2 .- triangle_a.v0))
    du0::Float32, du1::Float32, du2::Float32 = EpsilonTest(N1, triangle_a.v0, triangle_b)
    if (((du0 * du1) > 0.0) && ((du0 * du2) > 0.0))
        return nothing
    end
    
    N2::Vec3F = cross((triangle_b.v1 .- triangle_b.v0), (triangle_b.v2 .- triangle_b.v0))
    dv0::Float32, dv1::Float32, dv2::Float32 = EpsilonTest(N2, triangle_b.v0, triangle_a)
    if (((dv0 * dv1) > 0.0) && ((dv0 * dv2) > 0.0))
        return nothing
    end

    if (IsCoplanar(dv0, dv1, dv2))
        return nothing
    end

    D::Vec3F = abs.(cross(N1, N2))
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

    isectpointA1::Vec3F, isectpointA2::Vec3F = ComputeIntervalsIsectline(triangle_a, dv0, dv1, dv2)
    isectpointB1::Vec3F, isectpointB2::Vec3F = ComputeIntervalsIsectline(triangle_b, du0, du1, du2)

    isect10 = min(isectpointA1[index + 1], isectpointA2[index + 1])
    isect11 = max(isectpointA1[index + 1], isectpointA2[index + 1])
    isect20 = min(isectpointB1[index + 1], isectpointB2[index + 1])
    isect21 = max(isectpointB1[index + 1], isectpointB2[index + 1])

    if ((isect11 < isect20) || (isect21 < isect10))
        return nothing
    end

    isectpt1 = Vec3F(0.0, 0.0, 0.0)
    isectpt2 = Vec3F(0.0, 0.0, 0.0)

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

    return LineSegment(isectpt1, isectpt2)
end
