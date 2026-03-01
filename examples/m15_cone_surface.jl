using Juliagebra

a = Point(5.0,0.0,10.0)

surface1 = ParametricSurface(range(0.0,2*pi,50),range(0.0,1.0,50),[a]) do u,v,a    
    
    x = a.x * v * sign(cos(u)) * abs(cos(u))^1.85
    y = a.x * v * sign(sin(u)) * abs(sin(u))^1.85
    z = a.z * v

    return (x,y,z)
end

surface2 = ParametricSurface(range(0.0,2*pi,50),range(0.0,5.0,50)) do u,v
    
    h = 5
    R = 6

    y = v * cos(u)
    x = v * sin(u)
    z = v

    return (x,y,z-15)
end

Juliagebra.Wait()