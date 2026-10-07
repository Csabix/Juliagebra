using Juliagebra
using JuliaGLM

const MAX_INTERSECTIONS = 2000

const TESS_RANGE = range(-5.0,5.0,200)
const TORUS_TESS_COUNT = 500

a = Point(0.0, 0.0, 5.0)

toggle = Toggle(true)
toggle2 = Toggle(true)

num_node = @add_node!(() -> toggle ? 1 : -1.5) # switches between two different GPU-compatible arg types
num_node2 = @add_node!(() -> toggle2 ? 0 : Complex(1, 0)) # switches between GPU-compatible and incompatible arg types

R = Slider(0.1, 2.0, 10.0; label="R")
r = Slider(0.1, 0.4, 2.0; label="r")

torus_base = Point(10, 0, 0)

@ParametricSurface(range(0, 2pi, TORUS_TESS_COUNT), range(0, 2pi, TORUS_TESS_COUNT), color="b", enable_gpu_tessellation=true) do u, v
    Rrcosv = (R + r * cos(v))
    x = Rrcosv * cos(u)
    y = Rrcosv * sin(u)
    z = r * sin(v)
    return torus_base + Vec3(x, y, z + num_node + num_node2)
end

s1 = @ParametricSurface(TESS_RANGE, TESS_RANGE, color="r", enable_gpu_tessellation=true) do u, v
    x = u
    y = v
    z = (u*u + v*v) * -0.05
    return Vec3(x, y, z + 2.0)
end

s2 = @ParametricSurface(TESS_RANGE, TESS_RANGE, color="g", enable_gpu_tessellation=true) do u, v
    x = u
    y = v
    z = -1.0 * (u*u + v*v) * -0.05
    return a .+ Vec3(x,y,z - 5.0)
end

@add_node!(() -> (s1; return nothing))
@add_node!(() -> (s1; s2; return nothing))

it = Intersection(s1, s2; maxIntersectionNum = MAX_INTERSECTIONS)

for i in 1:MAX_INTERSECTIONS
    ParametricCurve(range(0,1,2), [it]; size=3.0) do t, iit
        s::PSegment = iit[i]
        return s.p0 .* t .+ (1.0 - t) .* s.p1
    end
end

Juliagebra.Wait()
