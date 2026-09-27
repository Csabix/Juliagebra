using Juliagebra
using JuliaGLM

const CPU_TESS_COUNT = 500_000
const GPU_TESS_COUNT = 500_000

center_cpu = Point(-3.5,0,0)
center_gpu = Point( 3.5,0,0)

ParametricCurve(range(0, 2pi, CPU_TESS_COUNT), [center_cpu], color="r") do phi, center_cpu
    p = 8
    q = 9

    r = cos(q * phi) + 2

    x = r * cos(p * phi)
    y = r * sin(p * phi)
    z = sin(q * phi)

    return center_cpu + Vec3(x, y, z)
end

@ParametricCurve(range(0, 2pi, GPU_TESS_COUNT), color="g", enable_gpu_tessellation=true) do phi
    p = 8
    q = 9
    
    r = cos(q * phi) + 2

    x = r * cos(p * phi)
    y = r * sin(p * phi)
    z = sin(q * phi)

    return center_gpu + Vec3(x, y, z)
end

Juliagebra.Wait()
