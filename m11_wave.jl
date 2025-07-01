include("Prototype/juliagebra.jl")
using .JuliAgebra

App()

a = Point(0,0,0)

wave = ParametricSurface([a],10,10,-10.0,10.0,-10.0,10.0) do u,v,p1

    xx = u
    yy = v
    zz = sin(u + x(p1))

    return (xx,yy,zz)
end

play!()


