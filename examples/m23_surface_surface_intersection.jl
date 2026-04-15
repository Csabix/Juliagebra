using Juliagebra

Juliagebra.Window() do 
    MAX_INTERSECTIONS = 1000
    
    a = Point(0.0, 0.0, 5.0)

    surface1 = ParametricSurface(range(-10.0,10.0,100),range(-10.0,10.0,100); color=(0.9,0.6,0.3)) do u, v
        x = u
        y = v
        z = (u^2 + v^2) * -0.05

        return (x, y, z + 2.0)
    end

    surface2 = ParametricSurface(range(-10.0,10.0,100),range(-10.0,10.0,100), [a]; color=(0.56,0.66,0.0)) do u, v, p1
        x = u
        y = v
        z = -1.0 * (u^2 + v^2) * -0.05

        return p1 .+ (x,y,z - 5.0)
    end

    

    it = Intersection(surface1, surface2; maxIntersectionNum = MAX_INTERSECTIONS)

    for i in 1:MAX_INTERSECTIONS
        ParametricCurve(range(0,1,2), [it]; width=3.0) do t, iit
            s::PSegment = iit[i]
            return s.p0 .* t .+ (1.0 - t) .* s.p1
        end
    end
end

