using Juliagebra
using JuliaGLM
using LinearAlgebra

# tessellation range density
TESS_RADIUS = 750
TESS_THETA = 750

P1 = Point(-2, 0, 0)
P2 = Point(2, 0, 0)

amplitude_cpu = Slider(0, 0, 1; label="Noise Amplitude CPU")
amplitude_gpu = Slider(0, 0, 1; label="Noise Amplitude GPU")

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

@callback_helper function noise(p::Vec3F)
    freq = 6.0f0

    val = sin(p.x * freq + p.y * 2.3f0) *
          cos(p.y * freq + p.z * 3.1f0) *
          sin(p.z * freq + p.x * 1.7f0)

    return val
end

@callback_helper function param_fn(r::Float32, theta::Float32, offset::Vec3F, amp::Float32)
    eps = 0.001f0

    pos = bryant_kusner(r, theta)
    pos_dr = bryant_kusner(r + eps, theta)
    pos_dtheta = bryant_kusner(r, theta + eps)

    norm = cross(pos_dr - pos, pos_dtheta - pos)
    norm_unit = normalize(norm)

    if any(isnan.(norm_unit))
        norm_unit = vec3(0)
    end

    return offset + vec3(0,0,3) + pos + (amp * noise(pos) * norm_unit)
end

ParametricSurface(range(0, 1, TESS_RADIUS), range(0, 2pi, TESS_THETA), [P2, amplitude_cpu]) do r, theta, P2, amp
    return param_fn(Float32(r), Float32(theta), Vec3F(P2), Float32(amp))
end

@ParametricSurface(range(0, 1, TESS_RADIUS), range(0, 2pi, TESS_THETA), enable_gpu_tessellation=true) do r, theta
    return param_fn(Float32(r), Float32(theta), Vec3F(P1), Float32(amplitude_gpu))
end

Juliagebra.Wait()
