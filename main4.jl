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

play!(context)