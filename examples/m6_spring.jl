using Juliagebra

Juliagebra.Window() do 
    Center = Point(5,5,0)
    tMax = (2*pi)*5

    ParametricCurve(range(0,tMax,55),[Center],color=(0.3,0.8,0.3)) do t, c
        x = cos(t)
        y = sin(t)
        z = (t/tMax)

        return c .* [x,y,z]
    end
end
