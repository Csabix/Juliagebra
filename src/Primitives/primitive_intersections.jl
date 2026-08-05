const LINE_TO_LINE_EPSILON = 0.1
#const PLANE_TO_PLANE_EPSILON = 0.0000000001
#const LINE_TO_PLANE_EPSILON = 0.0000000001
const F64_LINEAR_THRESHOLD = 1E-15 # when comparing distances
const F64_ANGULAR_THRESHOLD = 1E-15 # when comparing dot products
const F64_RELATIVE_THRESHOLD = 1E-15 # when comparing ratios

function PrimitiveToPrimitiveIntersection(line_segment_a::PSegment, line_segment_b::PSegment)::Union{Nothing, Vec3D}
    v1 = line_segment_a.p1 - line_segment_a.p0
    v2 = line_segment_b.p1 - line_segment_b.p0

    # println("aabb")

    n_up = normalize(cross(v1,v2))
    
    d = abs(dot(line_segment_b.p0-line_segment_a.p0,n_up))
    if( d > LINE_TO_LINE_EPSILON)
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

function Isect2(
    VTX0::Vec3D,
    VTX1::Vec3D,
    VTX2::Vec3D,
    D0::Float64, 
    D1::Float64, 
    D2::Float64
)::Tuple{Vec3D, Vec3D}
    tmp0::Float64 = D0 / (D0 - D1)
    tmp1::Float64 = D0 / (D0 - D2);
    isectpoint0::Vec3D = VTX0 .+ (tmp0 .* (VTX1 .- VTX0))
    isectpoint1::Vec3D = VTX0 .+ (tmp1 .* (VTX2 .- VTX0))

    return isectpoint0, isectpoint1
end

function ComputeIntervalsIsectline(
    triangle::PTriangle,
    D0::Float64, 
    D1::Float64, 
    D2::Float64
)::Tuple{Vec3D, Vec3D}
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

function IsCoplanar(D0::Float64, D1::Float64, D2::Float64)::Bool
    return ((abs(D0) <= F64_LINEAR_THRESHOLD) && (abs(D1) <= F64_LINEAR_THRESHOLD) && (abs(D2) <= F64_LINEAR_THRESHOLD))
end

function TriangleVertexDistancesFromPlane(N::Vec3D, V::Vec3D, triangle::PTriangle)::Tuple{Float64, Float64, Float64}
                             # plane equation: normal * v + d = 0
    d1::Float64 = -dot(N, V) # d1 is the constant of the equation

    # ? signed (distance if normal is unit vector) -> shows which side it is on
    du0::Float64 = dot(N, triangle.v0) + d1
    du1::Float64 = dot(N, triangle.v1) + d1
    du2::Float64 = dot(N, triangle.v2) + d1

    return du0, du1, du2
end

#from https://fileadmin.cs.lth.se/cs/Personal/Tomas_Akenine-Moller/code/tritri_isectline.txt
function PrimitiveToPrimitiveIntersection(triangle_a::PTriangle, triangle_b::PTriangle)::Union{PSegment,Nothing}
    N1::Vec3D = cross((triangle_a.v1 .- triangle_a.v0), (triangle_a.v2 .- triangle_a.v0))
    du0::Float64, du1::Float64, du2::Float64 = TriangleVertexDistancesFromPlane(N1, triangle_a.v0, triangle_b)
    if (((du0 * du1) > 0.0) && ((du0 * du2) > 0.0))
        return nothing
    end
    
    N2::Vec3D = cross((triangle_b.v1 .- triangle_b.v0), (triangle_b.v2 .- triangle_b.v0))
    dv0::Float64, dv1::Float64, dv2::Float64 = TriangleVertexDistancesFromPlane(N2, triangle_b.v0, triangle_a)
    if (((dv0 * dv1) > 0.0) && ((dv0 * dv2) > 0.0))
        return nothing
    end

    if (IsCoplanar(dv0, dv1, dv2))
        return nothing
    end

    D::Vec3D = abs.(cross(N1, N2))
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

    isectpointA1::Vec3D, isectpointA2::Vec3D = ComputeIntervalsIsectline(triangle_a, dv0, dv1, dv2)
    isectpointB1::Vec3D, isectpointB2::Vec3D = ComputeIntervalsIsectline(triangle_b, du0, du1, du2)

    isect10 = min(isectpointA1[index + 1], isectpointA2[index + 1])
    isect11 = max(isectpointA1[index + 1], isectpointA2[index + 1])
    isect20 = min(isectpointB1[index + 1], isectpointB2[index + 1])
    isect21 = max(isectpointB1[index + 1], isectpointB2[index + 1])

    if ((isect11 < isect20) || (isect21 < isect10))
        return nothing
    end

    isectpt1 = Vec3D(0.0)
    isectpt2 = Vec3D(0.0)

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

    return PSegment(isectpt1, isectpt2)
end

function PrimitiveToPrimitiveIntersection(plane1::PPlane,plane2::PPlane)::Union{PLine,Nothing}
    
    plane_d1 = dot(-plane1.n,plane1.p)
    plane_d2 = dot(-plane2.n,plane2.p)

    plane_n3 = cross(plane1.n,plane2.n)
    
    determinant = (norm(plane_n3))^2
    if (determinant == 0.0)
        return nothing
    end

    line_p3 = (cross(plane_n3,plane2.n) * plane_d1 + cross(plane1.n,plane_n3) * plane_d2) / determinant

    return PLine(line_p3,line_p3 + plane_n3)
end

function Seg2SegSqDistParams(p::Vec3D,v::Vec3D,q::Vec3D,w::Vec3D)::Tuple{Float64,Float64,Float64}
	r  = q - p
	v2 = dot(v,v); w2 = dot(w,w); vw = dot(v,w)
    
    D = v2*w2 - vw*vw
    # check if lines are parallel
    if (D < F64_ANGULAR_THRESHOLD)
        return (NaN,NaN,NaN)
    end
	Dinv  = 1.0 / D

	a1 = dot(v,r); a2 = dot(w,r); a3 = dot(cross(v,w), r)
	t  = ( w2*a1 - vw*a2 ) * Dinv
	s  = ( vw*a1 - v2*a2 ) * Dinv
	d2 = a3*a3 * Dinv
	
    return (d2,t,s)
end

function PrimitiveToPrimitiveIntersection(line1::Union{PLine,PRay,PSegment},line2::Union{PLine,PRay,PSegment})::Union{Vec3D,Nothing}
    (d2,t,s) = Seg2SegSqDistParams(p0(line1), v(line1), p0(line2), v(line2))
    if (d2 === NaN || t === NaN || s === NaN)
        return nothing
    end

    # println("not aabb")
    
    if (ParameterInside(line1, t) && ParameterInside(line2, s) && d2 <= LINE_TO_LINE_EPSILON^2)
        return (p0(line1) + v(line1) * t + p0(line2) + v(line2) * s) / 2.0
    else
        return nothing
    end
end

function PrimitiveToPrimitiveIntersection(triangle::PTriangle,line::Union{PLine,PRay,PSegment})::Union{Vec3D,Nothing}
    p = p0(line)
    dir = v(line)

    ab = triangle.v1 - triangle.v0
    ac = triangle.v2 - triangle.v0
    ap = p - triangle.v0
    f = cross(dir,ac)
    g = cross(ap,ab)

    parall = dot(f, ab)
    # check if line is parallel to triangle
    if (abs(parall) < F64_ANGULAR_THRESHOLD)
        return nothing
    end
    m = (1.0 / parall)

    t = m * dot(g, ac)
    u_bar = m * dot(f, ap)
    v_bar = m * dot(g, dir)
    w_bar = 1.0 - u_bar - v_bar

    if (ParameterInside(line, t) && 0.0 <= u_bar && 0.0 <= v_bar && 0.0 <= w_bar)
        return p + t * dir
    else
        return nothing
    end
end

PrimitiveToPrimitiveIntersection(line::Union{PLine,PRay,PSegment},triangle::PTriangle)::Union{Vec3D,Nothing} = PrimitiveToPrimitiveIntersection(triangle,line)

function PrimitiveToPrimitiveIntersection(plane::PPlane,line::Union{PLine,PRay,PSegment})::Union{Vec3D,Nothing}
    l = dot(v(line),plane.n)
    if (l == 0.0)
        return nothing
    end

    t = dot(plane.p-p0(line),plane.n) / l
    if (ParameterInside(line,t))
        return p0(line) + t * v(line)
    else
        return nothing
    end
end

PrimitiveToPrimitiveIntersection(line::Union{PLine,PRay,PSegment},plane::PPlane)::Union{Vec3D,Nothing} = PrimitiveToPrimitiveIntersection(plane,line)

function EdgePlaneIntersection(signed_dist1::Float64,signed_dist2::Float64,vert1::Vec3D,vert2::Vec3D)::Vec3D
    # ? true if they're on different sides
    if (signed_dist1 * signed_dist2 <= 0.0)
        distance = abs(signed_dist1) + abs(signed_dist2)
        if (distance != 0.0)
            return vert1 + (vert2 - vert1) * abs(signed_dist1) / distance
        end
    end
    return Vec3DNan
end

function PrimitiveToPrimitiveIntersection(triangle::PTriangle,plane::PPlane)::Union{PSegment,Nothing}
    # ? checks whether the planes are parallel
    v0v1 = triangle.v1 - triangle.v0
    v0v2 = triangle.v2 - triangle.v0
    tri_normal = cross(v0v1,v0v2)
    if (abs(dot(normalize(tri_normal),normalize(plane.n))) > 1.0 - F64_ANGULAR_THRESHOLD)
        return nothing
    end

    du0::Float64, du1::Float64, du2::Float64 = TriangleVertexDistancesFromPlane(plane.n, plane.p, triangle)
    # ? if signs of all three match, then it's entirely on one side
    if (((du0 * du1) > 0.0) && ((du0 * du2) > 0.0))
        return nothing
    end

    # ? Distribute the possible intersection coordinates, 2 or 3 (when there are two equal) into i1 & i2.
    i1 = EdgePlaneIntersection(du0,du1,triangle.v0,triangle.v1)
    i2 = EdgePlaneIntersection(du0,du2,triangle.v0,triangle.v2)
    if (i1 === Vec3DNan)
        i1 = i2
    elseif (i1 == i2)
        i2 = Vec3DNan
    end
    i3 = EdgePlaneIntersection(du1,du2,triangle.v1,triangle.v2)
    if (i3 !== Vec3DNan)
        i2 = i3
        i3 = Vec3DNan
    end

    # ? Not necessary, there must be at least two intersections; just insurance
    if (i1 === Vec3DNan || i2 === Vec3DNan)
        return nothing
    else
        return PSegment(i1,i2)
    end
end

PrimitiveToPrimitiveIntersection(plane::PPlane,triangle::PTriangle)::Union{PSegment,Nothing} = PrimitiveToPrimitiveIntersection(triangle,plane)

ParameterInside(::PLine,::Any)::Bool = true
ParameterInside(::PRay,t)::Bool      = t >= 0.0
ParameterInside(::PSegment,t)::Bool  = t >= 0.0 && t <= 1.0

p0(line::PLine)::Vec3D       = line.p0
p0(ray::PRay)::Vec3D         = ray.p0
p0(segment::PSegment)::Vec3D = segment.p0

p1(line::PLine)::Vec3D       = line.p1
p1(ray::PRay)::Vec3D         = ray.p1
p1(segment::PSegment)::Vec3D = segment.p1

v(line::PLine)::Vec3D       = line.p1 - line.p0
v(ray::PRay)::Vec3D         = ray.p1 - ray.p0
v(segment::PSegment)::Vec3D = segment.p1 - segment.p0
