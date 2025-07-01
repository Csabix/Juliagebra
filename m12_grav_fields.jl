include("Prototype/juliagebra.jl")
using .JuliAgebra

App()

cursor = Point(-15,0,0)

function gravField(fieldHeight,fieldStrengthDistance,u,v,p) 
    xx = u
    yy = v
    
    d  = (xx - x(p))^2
    d += (yy - y(p))^2
    d  = sqrt(d)
    d  = d * (1.0/fieldStrengthDistance)
    d  = clamp(1.0-d,0.0,1.0)
    d  = sin(d*pi/2.0)
    
    zz = (d) * z(p) +
         (1-d) * (fieldHeight)

    return (xx,yy,zz)
end

field1 = ParametricSurface([cursor],50,50,-10.0,10.0,-10.0,10.0) do u,v,p
    return gravField(-5.0,5.0,u,v,p)
end

field2 = ParametricSurface([cursor],50,50,-10.0,10.0,-10.0,10.0) do u,v,p
    return gravField(5.0,5.0,u,v,p)
end

play!()