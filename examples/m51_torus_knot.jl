using Juliagebra
using JuliaGLM

const TESS_COUNT = 225_000

p_cpu = Slider(-20,8,20;label="p CPU")
q_cpu = Slider(-20,9,20;label="q CPU")

p_gpu = Slider(-20,8,20;label="p GPU")
q_gpu = Slider(-20,9,20;label="q GPU")

flip_cpu = Toggle(;label="Flip CPU")
flip_gpu = Toggle(;label="Flip GPU")

dist_amp_cpu = Slider(0,0,2pi;label="Distortion Amplitude CPU")
dist_phase_cpu = Stepper(0.0;label="Distortion Phase CPU")

dist_amp_gpu = Slider(0,0,2pi;label="Distortion Amplitude GPU")
dist_phase_gpu = Stepper(0.0;label="Distortion Phase GPU")

center1 = Point( 3.5, 0, 0)
center2 = Point(-3.5, 0, 0)

@callback_helper function torus_knot(p::Float32, q::Float32, phi::Float32,
                                     dist_amp::Float32, dist_phase::Float32, flip::Bool)
    r = cos(q * phi) + 2

    x = r * cos(p * phi)
    y = r * sin(p * phi)
    z = sin(q * phi) * (2 * Int32(flip) - 1)
    
    return Vec3F(x, y, z) .+ (sin(phi + dist_phase) * dist_amp)
end

# CPU
@ParametricCurve(range(0, 2pi, TESS_COUNT)) do phi
    return center1 + torus_knot(
        Float32(p_cpu), Float32(q_cpu), Float32(phi),
        Float32(dist_amp_cpu), Float32(dist_phase_cpu), flip_cpu
    )
end

# GPU
@ParametricCurve(range(0, 2pi, TESS_COUNT), enable_gpu_tessellation=true) do phi
    return center2 + torus_knot(
        Float32(p_gpu), Float32(q_gpu), Float32(phi),
        Float32(dist_amp_gpu), Float32(dist_phase_gpu), flip_gpu
    )
end

Juliagebra.Wait()
