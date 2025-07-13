include("Prototype/juliagebra.jl")
using .JuliAgebra

App()

cursor = Point(-15,0,0)

function gravField(fieldHeight,fieldStrengthDistance,u,v,p) 
    x = u
    y = v
    
    d  = (x - p[:x])^2
    d += (y - p[:y])^2
    d  = sqrt(d)
    d  = d * (1.0/fieldStrengthDistance)
    d  = clamp(1.0-d,0.0,1.0)
    d  = sin(d*pi/2.0)
    
    z = (d) * p[:z] +
        (1-d) * (fieldHeight)

    return (x,y,z)
end

field1 = ParametricSurface(50,50,-10.0,10.0,-10.0,10.0,[cursor]) do u,v,p
    return gravField(-5.0,5.0,u,v,p)
end

field2 = ParametricSurface(50,50,-10.0,10.0,-10.0,10.0,[cursor]) do u,v,p
    return gravField(5.0,5.0,u,v,p)
end

play!()