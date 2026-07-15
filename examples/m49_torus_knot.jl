using Juliagebra
using JuliaGLM

p = 8
q = 9

TESS_COUNT = 120_000

center1 = Point(3.5, 0, 0)
center2 = Point(-3.5, 0, 0)

@callback_helper function torus_knot(phi::Float32)
    r = cos(9 * phi) + 2

    x = r * cos(8 * phi)
    y = r * sin(8 * phi)
    z = -sin(9 * phi)
    
    return Vec3F(x, y, z)
end

# CPU
ParametricCurve(range(0, 2pi, TESS_COUNT), [center1]) do phi, o
    return o["xyz"] + torus_knot(Float32(phi))
end

# GPU
@ParametricCurve(range(0, 2pi, TESS_COUNT), enable_gpu_tessellation=true) do phi
    return center2["xyz"] + torus_knot(Float32(phi))
end

Juliagebra.Wait()
