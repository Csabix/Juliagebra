using Juliagebra
using JuliaGLM

function orbit(t,c,r)
    return Vec3D(sin(t),cos(t),0.0) .* r .+ c
end

tt = Stepper(0.0; label="Time")
o = Slider(2.0, 3.0, 6.0; label="Orbit")
grabber = Point(0.0,0.0,2.0)

sun = Point([grabber]) do grabber
    return grabber .- Vec3D(0.0,0.0,2.0)
end

Sphere(sun, ValueHolder(1.3); color=(0.902, 0.439, 0.0))

ParametricCurve(range(0.0,2*pi,100), [sun, o]; color=(0.0, 0.063, 0.729)) do t, sun, o
    return orbit(t, sun, o)
end

earth = Point([tt, sun, o]) do tt, sun, o
    orbit(tt, sun, o)
end

Sphere(earth, ValueHolder(0.65); color=(0.0, 0.063, 0.729))

Juliagebra.Wait()