include("Prototype/juliagebra.jl")
using .JuliAgebra

App()

tMax = (2*pi)*5
radius = 5
a = Point(-tMax-10,0,0)

curve = ParametricCurve(0,tMax,55,(0.3,0.8,0.3),[a]) do t,p1
    z = cos(t) * radius
    y = sin(t) * radius
    x = t
    
    return p1[:xyz] .+ (x,y,z)
end

surface = ParametricSurface(50,50,-10.0,10.0,-10.0,10.0) do u,v
    x = u
    y = v
    z = (u^2 + v^2) * -0.05

    return (x,y,z)
end

it = Intersection(curve,surface,6)

for i in 1:6
    Point(0,0,-999,[it]) do iit
        return iit[i]
    end
end


play!()


