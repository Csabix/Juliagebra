include("Prototype/juliagebra.jl")
using .JuliAgebra

App()

crv1 = ParametricCurve(0,5*3.14) do t
    xx = t
    yy = sin(t)
    zz = 0
    
    return (xx,yy,zz)
end



play!()