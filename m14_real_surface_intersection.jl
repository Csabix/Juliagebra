include("Prototype/juliagebra.jl")
using .JuliAgebra

App()

tMax = (2*pi)*5

a = Point(-tMax-10,0,0)


radius = 5

curve = ParametricCurve(0,tMax,55,[a],(0.3,0.8,0.3)) do t,p1
    zz = cos(t) * radius
    yy = sin(t) * radius
    xx = t
    
    return (x(p1) + xx, y(p1) + yy, z(p1) + zz)
end

surface = ParametricSurface(50,50,-10.0,10.0,-10.0,10.0) do u,v

    xx = u
    yy = v
    zz = (u^2 + v^2) * -0.05

    return (xx,yy,zz)
end

it = Intersection(curve,surface,6)

for i in 1:6
    Point(0,0,-999,[it]) do iit
        return iit[i]
    end
end


play!()


