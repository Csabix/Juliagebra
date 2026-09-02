##
using Juliagebra
using JuliaGLM
using LinearAlgebra
##
function triangle(a, b, c, col)
    ParametricSurface(range(0.0, 1.0, 3), range(0.0, 1.0, 3), [a, b, c]; color=col) do u, v, a, b, c
        if (u >= 0.5 && v >= 0.5)
            u = 0.5
            v = 0.5
        end
        return (1 - u - v) .* a .+ u .* b .+ v .* c
    end
end

function point_dir(to, from)
    return normalize(to - from)
end

function project_to_2d(P)
    return Vec2D(P[1], P[3])
end

function draw_vector(origin, dir; color="c", style="->", width=5.0f0)
    offset = Point([origin, dir], size=0) do o, d
        d3 = Vec3D(d[1], 0.0, d[2])
        return o + d3
    end
    Segment(origin, offset; color=color, style=style, size=width)
end

const add_offset = (p, o, w) -> begin
    o = o * w
    return Vec3D(p[1] + o[1], p[2], p[3] + o[2])
end

perp(v::Vec2D) = Vec2D(v[2], -v[1])

function miter_offset(v1, v2)
    d = abs(dot(v1, v2))
    r1, r2 = perp(v1), perp(v2)
    return isapprox(d, 1.0; atol=1e-4) ? r1 : (r1 .+ r2) / (1.0 + dot(r1, r2))
end

function curve_segment(_pA, _pB, _pC, _pD, line_width, index)    
    is_low = index <= 2
    pA_in = is_low ? _pA : _pD
    pB    = is_low ? _pB : _pC
    pC_in = is_low ? _pC : _pB

    A = add_node!(project_to_2d,parents=[pA_in])
    B = add_node!(project_to_2d,parents=[pB])
    C = add_node!(project_to_2d,parents=[pC_in])

    l_AB = @add_node!(() -> norm(A - B))
    l_CB = @add_node!(() -> norm(B - C))

    dir_AB = add_node!(point_dir;parents=[A, B])
    dir_BC = add_node!(point_dir;parents=[B, C])

    dir_AB_r = add_node!(perp;parents=[dir_AB])
    dir_BC_r = add_node!(perp;parents=[dir_BC])

    inner = @add_node!() do
        r_ab = dir_AB_r * (dot(dir_AB_r, dir_BC) >= 0.0 ? -1.0 : 1.0)
        r_bc = dir_BC_r * (dot(dir_BC_r, dir_AB) < 0.0 ? -1.0 : 1.0)
        isapprox(abs(dot(dir_AB, dir_BC)), 1.0; atol=1e-4) ? r_ab : (r_ab .+ r_bc) / (1.0 + dot(r_ab, r_bc))
    end

    right_offset = @add_node!(() -> miter_offset(dir_AB, dir_BC))

    overlap = @add_node!() do
        d_dot = dot(dir_AB, dir_BC)
        d_dot <= -0.9999 && return true
        d_dot >= 0.9999  && return false

        cos_abc = abs(dot(dir_AB, normalize(inner)))
        sin_abc = sqrt(max(0.0, 1.0 - cos_abc * cos_abc))
        l_abc   = line_width * cos_abc / sin_abc
        return l_abc > l_AB || l_abc > l_CB
    end

    t = @add_node!() do
        v = normalize(inner) * (dot(right_offset, inner) <= 0.0 ? -1.0 : 1.0)
        cos_half = clamp(dot(dir_BC_r, v), -1.0, 1.0)
        sqrt(max(0.0, 1.0 - cos_half) / (1.0 + cos_half))
    end

    perp_base = index < 5 ? dir_BC_r : dir_AB_r
    parallel  = index < 5 ? dir_BC   : @add_node!(() -> -dir_AB)

    perpendicular = @add_node!() do
        (dot(right_offset, inner) >= 0.0 ? -1.0 : 1.0) * perp_base
    end

    no_overlap_offset = @add_node!() do
        a = perpendicular + t * parallel
        b = index == 5 ? a : inner
        first_v, second_v = xor(index > 2, iseven(index - 1)) ? (b, a) : (a, b)
        dot(right_offset, inner) >= 0.0 ? first_v : second_v
    end

    s_23 = index in (2, 3) ? -1.0 : 1.0
    overlap_offset = @add_node!(() -> dir_BC + s_23 * dir_BC_r)
    obtuse_offset  = @add_node!(() -> s_23 * right_offset)

    offset = @add_node!() do
        dot(dir_AB, dir_BC) >= 0 ? obtuse_offset : (overlap ? overlap_offset : no_overlap_offset)
    end

    Point(add_offset, [pB, offset, line_width]; size=10)
end
##
const line_width = Slider(0.05, 0.2, 0.5)

const A = Point(3, 0, 2)
const B = Point(0, 0, 1)
const C = Point(-2, 0, 2)
const D = Point(-4, 0, 1)
const E = Point(-5, 0, 2)

r1 = curve_segment(A, B, C, D, line_width, 1)
r2 = curve_segment(A, B, C, D, line_width, 2)
r3 = curve_segment(A, B, C, D, line_width, 3)
r4 = curve_segment(A, B, C, D, line_width, 4)
r5 = curve_segment(A, B, C, D, line_width, 5)

triangle(r1, r2, r3, (1.0, 0.0, 0.0))
triangle(r3, r2, r4, (0.0, 1.0, 0.0))
triangle(r3, r4, r5, (0.0, 0.0, 1.0))

r1 = curve_segment(B, C, D, E, line_width, 1)
r2 = curve_segment(B, C, D, E, line_width, 2)
r3 = curve_segment(B, C, D, E, line_width, 3)
r4 = curve_segment(B, C, D, E, line_width, 4)
r5 = curve_segment(B, C, D, E, line_width, 5)

triangle(r1, r2, r3, (1.0, 0.0, 0.0))
triangle(r3, r2, r4, (0.0, 1.0, 0.0))
triangle(r3, r4, r5, (0.0, 0.0, 1.0))