include("Prototype/juliagebra.jl")
using .JuliAgebra

context = App()

function circle(radius,t)
    x = cos(t) * radius
    y = sin(t) * radius
    z = 0
    return (x,y,z)
end

crv1 = ParametricCurve(0,2*pi,5, t -> circle(5.0,t),context)
crv2 = ParametricCurve(0,2*pi,5, t -> circle(10.0,t),context)

Center = Point(0,0,0)

tMax = (2*pi)*5
radius = 5

crv3 = ParametricCurve(0,tMax,55,[Center]) do t,p1
    xx = cos(t) * radius
    yy = sin(t) * radius
    zz = z(p1) * (t/tMax)
    
    return (xx,yy,zz + 15)
end

play!(context)