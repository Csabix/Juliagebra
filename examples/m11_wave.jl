using Juliagebra

a = Point(0,0,0)

wave = ParametricSurface(range(-10.0,10.0,50),range(-10.0,10.0,50),[a]) do u,v,p1
    x = u
    y = v
    z = sin(u + p1.x)

    return (x,y,z)
end

Juliagebra.Wait()


