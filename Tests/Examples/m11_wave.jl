include("../../Prototype/juliagebra.jl")
using .JuliAgebra

App()

a = Point(0,0,0)

wave = ParametricSurface(50,50,-10.0,10.0,-10.0,10.0,[a]) do u,v,p1

    x = u
    y = v
    z = sin(u + p1[:x])

    return (x,y,z)
end

play!()


