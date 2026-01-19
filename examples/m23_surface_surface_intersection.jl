using Juliagebra

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

    return p1 .+ (x,y,z - 5.0)
end

const MAX_INTERSECTIONS = 1000

it = Intersection(surface1, surface2; maxIntersectionNum = MAX_INTERSECTIONS)

for i in 1:MAX_INTERSECTIONS
    ParametricCurve(range(0, 1, length = 2), [it]; width=15.0) do t, iit
        s::PSegment = iit[i]
        return s.p0 .* t .+ (1.0 - t) .* s.p1
    end
end

play!()
