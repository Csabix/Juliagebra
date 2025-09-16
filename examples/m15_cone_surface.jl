using Juliagebra

App()

a = Point(5.0,0.0,10.0)

surface1 = ParametricSurface(50,50,0.0,2*pi,0.0,1.0,[a]) do u,v,a    
    
    x = a[:x] * v * sign(cos(u)) * abs(cos(u))^1.85
    y = a[:x] * v * sign(sin(u)) * abs(sin(u))^1.85
    z = a[:z] * v

    return (x,y,z)
end

surface2 = ParametricSurface(50,50,0.0,2*pi,0.0,5) do u,v
    
    h = 5
    R = 6

    y = v * cos(u)
    x = v * sin(u)
    z = v

    return (x,y,z-15)
end

play!()