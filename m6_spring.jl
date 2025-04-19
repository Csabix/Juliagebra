include("Prototype/juliagebra.jl")
using .JuliAgebra

App()

Center = Point(0,0,0)

tMax = (2*pi)*5
radius = 5

crv1 = ParametricCurve(0,tMax,55,[Center],(0.3,0.8,0.3)) do t,p1
    xx = cos(t) * radius
    yy = sin(t) * radius
    zz = z(p1) * (t/tMax)
    
    return (xx,yy,zz)
end

play!()
