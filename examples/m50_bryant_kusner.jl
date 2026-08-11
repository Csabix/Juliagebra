using Juliagebra
using JuliaGLM

# tessellation range density
TESS_RADIUS = 500
TESS_THETA = 750

P1 = Point(-2, 0, 0)
P2 = Point(2, 0, 0)

angle_cpu = Stepper(0.0; label="Rotation Angle CPU")
angle_gpu = Stepper(0.0; label="Rotation Angle GPU")

@callback_helper function rotate_z(v::Vec3, angle::Float32)
    c = cos(angle)
    s = sin(angle)

    return Vec3F(
        c * v.x - s * v.y,
        s * v.x + c * v.y,
        v.z
    )
end

@callback_helper function comp_mul(x::Vec2, y::Vec2)
    _re = x.x * y.x - x.y * y.y
    _im = x.y * y.x + x.x * y.y

    return vec2(_re, _im)
end

@callback_helper function comp_div(x::Vec2, y::Vec2)
    denom = y.x * y.x + y.y * y.y

    _re = (x.x * y.x + x.y * y.y) / denom
    _im = (x.y * y.x - x.x * y.y) / denom

    return vec2(_re, _im)
end

@callback_helper function bryant_kusner(r::Float32, theta::Float32)
    w = vec2(r * cos(theta), r * sin(theta))
    w3 = comp_mul(comp_mul(w, w), w)
    w4 = comp_mul(w3, w)
    w6 = comp_mul(comp_mul(w4, w), w)

    g_denom = w6 + comp_mul(vec2(sqrt(5), 0), w3) - vec2(1, 0)

    g1_base = comp_div(comp_mul(w, vec2(1, 0) - w4), g_denom)
    g1 = -1.5 * g1_base.y

    g2_base = comp_div(comp_mul(w, vec2(1, 0) + w4), g_denom)
    g2 = -1.5 * g2_base.x

    g3_base = comp_div(vec2(1, 0) + w6, g_denom)
    g3 = g3_base.y - 0.5

    pos_denom = g1 * g1 + g2 * g2 + g3 * g3
    return vec3(g1, g2, g3) / Float32(pos_denom)
end

# @ParametricSurface(range(0,1,TESS_RADIUS),range(0,2pi,TESS_THETA)) do r, theta
#     return P2 + vec3(0, 0, 3) + rotate_z(bryant_kusner(Float32(r), Float32(theta)), Float32(angle_cpu))
# end

ParametricSurface(range(0, 1, TESS_RADIUS), range(0, 2pi, TESS_THETA), [P2, angle_cpu]) do r, theta, P2, angle_cpu
    return P2 + vec3(0, 0, 3) + rotate_z(bryant_kusner(Float32(r), Float32(theta)), Float32(angle_cpu))
end

@ParametricSurface(range(0, 1, TESS_RADIUS), range(0, 2pi, TESS_THETA), enable_gpu_tessellation=true)  do r, theta
    return P1 + vec3(0, 0, 3) + rotate_z(bryant_kusner(r, theta), Float32(angle_gpu))
end

Juliagebra.Wait()
