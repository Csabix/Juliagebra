using Juliagebra
using JuliaGLM
using LinearAlgebra

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

function norm_ab(a, b)
    return norm(a - b)
end

function project_to_2d(P)
    return Vec2D(P[1], P[3])
end

function f_dot(A, B)
    return dot(A, B)
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

function curve_segment(pA, pB, pC, pD, line_width)
    A = ValueHolder(project_to_2d, Vec2D, [pA])
    B = ValueHolder(project_to_2d, Vec2D, [pB])
    C = ValueHolder(project_to_2d, Vec2D, [pC])
    D = ValueHolder(project_to_2d, Vec2D, [pD])

    Segment(pA, pB, color="k", style="->")
    Segment(pB, pC, color="k", style="->")
    Segment(pC, pD, color="k", style="->")

    Sphere(pA, line_width, color=(1.0, 1.0, 1.0, 0.1))
    Sphere(pB, line_width, color=(1.0, 1.0, 1.0, 0.1))
    Sphere(pC, line_width, color=(1.0, 1.0, 1.0, 0.1))
    Sphere(pD, line_width, color=(1.0, 1.0, 1.0, 0.1))

    l_AB = @ValueHolder(() -> norm(A - B), Float64)
    l_DC = @ValueHolder(() -> norm(D - C), Float64)
    l_CB = @ValueHolder(() -> norm(C - B), Float64)

    dir_AB = ValueHolder(point_dir, Vec2D, [A, B])
    dir_CB = ValueHolder(point_dir, Vec2D, [C, B])
    dir_BC = ValueHolder(point_dir, Vec2D, [B, C])
    dir_DC = ValueHolder(point_dir, Vec2D, [D, C])

    draw_vector(pB, dir_AB; width=10.0f0, color="r")
    draw_vector(pB, dir_CB; width=10.0f0, color="r")
    draw_vector(pC, dir_BC; width=10.0f0, color="r")
    draw_vector(pC, dir_DC; width=10.0f0, color="r")

    inner_ABC = @ValueHolder(Vec2D) do
        dir_AB_r = Vec2D(dir_AB[2], -dir_AB[1])
        if dot(dir_AB_r, -dir_BC) < 0.0
            dir_AB_r = -1.0 * dir_AB_r
        end
        dir_BC_r = Vec2D(dir_BC[2], -dir_BC[1])
        if dot(dir_BC_r, dir_AB) < 0.0
            dir_BC_r = -1.0 * dir_BC_r
        end
        return if isapprox(abs(dot(dir_AB, dir_BC)), 1.0; atol=0.0001)
            dir_AB_r
        else
            (dir_AB_r .+ dir_BC_r) / (1.0 + dot(dir_AB_r, dir_BC_r))
        end
    end

    inner_BCD = @ValueHolder(Vec2D) do
        dir_CB_r = Vec2D(-dir_CB[2], dir_CB[1])
        if dot(dir_CB_r, dir_DC) < 0.0
            dir_CB_r = -1.0 * dir_CB_r
        end
        dir_DC_r = Vec2D(-dir_DC[2], dir_DC[1])
        if dot(dir_DC_r, dir_BC) < 0.0
            dir_DC_r = -1.0 * dir_DC_r
        end
        return if isapprox(abs(dot(dir_CB, dir_DC)), 1.0; atol=0.0001)
            dir_DC_r
        else
            (dir_CB_r .+ dir_DC_r) / (1.0 + dot(dir_CB_r, dir_DC_r))
        end
    end

    dir_AB_r = @ValueHolder(Vec2D) do
        return Vec2D(dir_AB[2], -dir_AB[1])
    end
    dir_BC_r = @ValueHolder(Vec2D) do
        return Vec2D(dir_BC[2], -dir_BC[1])
    end
    dir_CB_r = @ValueHolder(Vec2D) do
        return Vec2D(-dir_CB[2], dir_CB[1])
    end
    dir_DC_r = @ValueHolder(Vec2D) do
        return Vec2D(-dir_DC[2], dir_DC[1])
    end

    draw_vector(pA, dir_AB_r; width=10.0f0, color="m")
    draw_vector(pB, dir_BC_r; width=10.0f0, color="m")
    draw_vector(pC, dir_CB_r; width=10.0f0, color="y")
    draw_vector(pD, dir_DC_r; width=10.0f0, color="y")

    right_offset_ABC = @ValueHolder(Vec2D) do
        res = Vec2D(0.0, 0.0)
        if isapprox(abs(dot(dir_AB, dir_BC)), 1.0; atol=0.0001)
            res = dir_AB_r
        else
            res = (dir_AB_r .+ dir_BC_r) / (1.0 + dot(dir_AB_r, dir_BC_r))
        end
        return res
    end
    right_offset_BCD = @ValueHolder(Vec2D) do
        res = Vec2D(0.0, 0.0)
        if isapprox(abs(dot(dir_CB, dir_DC)), 1.0; atol=0.0001)
            res = dir_DC_r
        else
            res = (dir_CB_r .+ dir_DC_r) / (1.0 + dot(dir_CB_r, dir_DC_r))
        end
        return res
    end

    right_offset_ABC_w = @ValueHolder(() -> right_offset_ABC * line_width, Vec2D)
    draw_vector(pB, right_offset_ABC_w; width=5.0f0, color="c", style="-")
    right_offset_BCD_w = @ValueHolder(() -> right_offset_BCD * line_width, Vec2D)
    draw_vector(pC, right_offset_BCD_w; width=5.0f0, color="c", style="-")

    overlap_abc = @ValueHolder(Bool) do
        cos_abc = abs(dot(dir_AB,normalize(inner_ABC)))
        sin_abc = sqrt(1.0 - cos_abc * cos_abc)
        l_abc = line_width * cos_abc / sin_abc
        return l_abc > l_AB || l_abc > l_CB
    end

    overlap_bcd = @ValueHolder(Bool) do
        cos_bcd = abs(dot(dir_DC,normalize(inner_BCD)))
        sin_bcd = sqrt(1.0 - cos_bcd * cos_bcd)
        l_bcd = line_width * cos_bcd / sin_bcd
        return l_bcd > l_DC || l_bcd > l_CB
    end

    begin_right_offset = @ValueHolder(Vec2D) do
        if dot(dir_AB, dir_BC) >= 0
            # Obtuse
            return right_offset_ABC
        else
            # Acute
            if overlap_abc
                return -dir_CB + dir_CB_r
            else
                if dot(right_offset_ABC, inner_ABC) >= 0.0
                    # Inner
                    return inner_ABC
                else
                    # Outer
                    v = normalize(-inner_ABC)
                    cos_half = dot(dir_BC_r, v)
                    sin_half = sqrt(1.0 - cos_half^2)
                    t = (1.0 - cos_half) / sin_half
                    return dir_BC_r + t * dir_BC # TODO improve
                end
            end
        end
        return Vec2D(0.0)
    end

    begin_left_offset = @ValueHolder(Vec2D) do
        if dot(dir_AB, dir_BC) >= 0
            # Obtuse
            return -right_offset_ABC
        else
            if overlap_abc
                return -dir_CB - dir_CB_r
            else
                if dot(right_offset_ABC, inner_ABC) >= 0.0
                    # Outer
                    v = normalize(inner_ABC)
                    cos_half = dot(dir_BC_r, v)
                    sin_half = sqrt(1.0 - cos_half^2)
                    t = (1.0 - cos_half) / sin_half
                    return -dir_BC_r + t * dir_BC # TODO improve
                else
                    # Inner
                    return inner_ABC
                end
            end
        end
        return Vec2D(0.0)
    end

    end_right_offset = @ValueHolder(Vec2D) do
        if dot(dir_DC, dir_CB) >= 0
            # Obtuse
            return right_offset_BCD
        else
            if overlap_bcd
                return dir_CB + dir_CB_r
            else
                if dot(right_offset_BCD, inner_BCD) >= 0.0
                    # Inner
                    return inner_BCD
                else
                    # Outer
                    v = normalize(-inner_BCD)
                    cos_half = dot(dir_BC_r, v)
                    sin_half = sqrt(1.0 - cos_half^2)
                    t = (1.0 - cos_half) / sin_half
                    return dir_CB_r + t * dir_CB # TODO improve
                end
            end
        end
        return Vec2D(0.0)
    end

    end_left_offset = @ValueHolder(Vec2D) do
        if dot(dir_DC, dir_CB) >= 0
            # Obtuse
            return -right_offset_BCD
        else
            if overlap_bcd
                return dir_CB - dir_CB_r
            else
                if dot(right_offset_BCD, inner_BCD) >= 0.0
                    # Outer
                    v = normalize(inner_BCD)
                    cos_half = dot(dir_BC_r, v)
                    sin_half = sqrt(1.0 - cos_half^2)
                    t = (1.0 - cos_half) / sin_half
                    return -dir_CB_r + t * dir_CB # TODO improve
                else
                    # Inner
                    return inner_BCD
                end
            end
        end
        return Vec2D(0.0)
    end

    end_third_offset = @ValueHolder(Vec2D) do
        if dot(dir_DC, dir_CB) < 0
            # Acute
            if overlap_bcd
            else
                if dot(right_offset_BCD, inner_BCD) >= 0.0
                    # Left
                    v = normalize(inner_BCD)
                    cos_half = dot(dir_BC_r, v)
                    sin_half = sqrt(1.0 - cos_half^2)
                    t = (1.0 - cos_half) / sin_half
                    return -dir_DC_r - t * dir_DC # TODO improve
                else
                    # Right
                    v = normalize(-inner_BCD)
                    cos_half = dot(dir_BC_r, v)
                    sin_half = sqrt(1.0 - cos_half^2)
                    t = (1.0 - cos_half) / sin_half
                    return dir_DC_r - t * dir_DC # TODO improve
                end
            end
        end
        return Vec2D(NaN64, NaN64)
    end

    r1 = Point(add_offset, [pB, begin_right_offset, line_width]; size=0)
    r2 = Point(add_offset, [pB, begin_left_offset, line_width]; size=0)
    r3 = Point(add_offset, [pC, end_right_offset, line_width]; size=0)
    r4 = Point(add_offset, [pC, end_left_offset, line_width]; size=0)
    r5 = Point(add_offset, [pC, end_third_offset, line_width]; size=0)

    triangle(r1, r2, r3, (1.0, 0.0, 0.0))
    triangle(r3, r2, r4, (0.0, 1.0, 0.0))
    triangle(r3, r4, r5, (0.0, 0.0, 1.0))
    #=
    @ValueHolder(Float64) do
        cos_abc = abs(dot(dir_AB,normalize(inner_ABC)))
        sin_abc = sqrt(1.0 - cos_abc * cos_abc)
        l_abc = line_width * cos_abc / sin_abc
        if l_abc > l_AB || l_abc > l_CB
            println("overlap abc")
        end

        cos_cbd = abs(dot(dir_DC,normalize(inner_BCD)))
        sin_cbd = sqrt(1.0 - cos_cbd * cos_cbd)
        l_cbd = line_width * cos_cbd / sin_cbd
        if l_cbd > l_DC || l_cbd > l_CB
            println("overlap cbd")
        end
        return 0.0
    end
    =#
end

const line_width = Slider(0.05, 0.2, 0.5)

const A = Point(0, 0, 0)
const B = Point(0, 0, 1)
const C = Point(1, 0, 2)
const D = Point(2, 0, 2)
const E = Point(3, 0, 2)
const F = Point(4, 0, 2)

curve_segment(A, B, C, D, line_width)
curve_segment(B, C, D, E, line_width)
curve_segment(C, D, E, F, line_width)

Juliagebra.Wait()
