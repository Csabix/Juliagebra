include("Prototype/juliagebra.jl")
using .JuliAgebra

context = App()

Center = Point!(0,0,0,context)

tMax = (2*pi)*5
radius = 5


function spiral(t,p1)    
    xx = cos(t) * radius
    yy = sin(t) * radius
    zz = z(p1) * (t/tMax)
    
    return (xx,yy,zz)
end

crv1 = ParametricCurve!(0,tMax,50,[Center],spiral,context)

play!(context)
