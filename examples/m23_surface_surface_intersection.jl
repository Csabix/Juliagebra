include("../../Prototype/juliagebra.jl")
using .JuliAgebra

App()

a = Point(0.0, 0.0, 5.0)

surface1 = ParametricSurface(100, 100, -10.0, 10.0, -10.0, 10.0) do u, v
    x = u
    y = v
    z = (u^2 + v^2) * -0.05

    return (x, y, z)
end

surface2 = ParametricSurface(100, 100, -10.0, 10.0, -10.0, 10.0, [a]) do u, v, p1
    x = u
    y = v
    z = -1.0 * (u^2 + v^2) * -0.05

    return p1[:xyz] .+ (x,y,z - 5.0)
end

const MAX_INTERSECTIONS = 1000

it = Intersection(surface1, surface2, MAX_INTERSECTIONS)

for i in 1:MAX_INTERSECTIONS
    #just a simple line segment
    ParametricCurve(0.0, 1.0, 2, [it]) do t, iit
        if (iit[i] !== nothing)
            a, b = iit[i]
            return a .* t .+ (1.0 - t) .* b
        else
            return (0.0, 0.0, -999.0)
        end
    end
end

play!()
