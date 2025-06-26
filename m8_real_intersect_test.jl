include("Prototype/juliagebra.jl")
using .JuliAgebra

App()

Center1 = Point(0,0,0)

tMax = (2*pi)*5
radius = 5

crv1 = ParametricCurve(0,tMax,55,[Center1],(0.3,0.8,0.3)) do t,p1
    xx = cos(t) * radius
    yy = sin(t) * radius
    zz = z(p1) * (t/tMax)
    
    return (xx,yy,zz)
end

Center2 = Point(0,0,10)

radius2 = 4

crv2 = ParametricCurve(0,2*pi,35,[Center2]) do t,c2
    xx = x(c2) + cos(t) * radius2
    yy = y(c2) 
    zz = z(c2) + sin(t) * radius2
    return (xx,yy,zz)
end

it = Intersection(crv1,crv2,25)

for i in 1:25
    Point(0,0,-10,[it]) do iit
        return iit[i]
    end
end

play!()


