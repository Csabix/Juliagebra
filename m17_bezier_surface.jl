include("Prototype/juliagebra.jl")
using .JuliAgebra

App()


P00 = Point(0, 0, 0)
P10 = Point(5, 0, 0)
P01 = Point(0, 5, 0)
P11 = Point(5, 5, 5)

bezierSurface = ParametricSurface([P00,P10,P01,P11],50,50,0,1,0,1) do u, v, p00, p10, p01, p11
    xx = (1-u)*(1-v)*x(p00) + u*(1-v)*x(p10) + (1-u)*v*x(p01) + u*v*x(p11)
    yy = (1-u)*(1-v)*y(p00) + u*(1-v)*y(p10) + (1-u)*v*y(p01) + u*v*y(p11) 
    zz = (1-u)*(1-v)*z(p00) + u*(1-v)*z(p10) + (1-u)*v*z(p01) + u*v*z(p11)
    return (xx,yy,zz) 
end

play!()
