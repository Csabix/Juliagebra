include("Prototype/juliagebra.jl")
using .JuliAgebra

App()

a = Point(5.0,0.0,10.0)

surface1 = ParametricSurface([a],50,50,0.0,2*pi,0.0,1.0) do u,v,a

    # xx = sin(u * atan(v/u)) * sin(v * atan(v/u))
    # yy = sin(u * atan(v/u)) * cos(v * atan(v/u))
    # zz = sin(u * atan(v/u))

    h = 5
    R = 6

    xx = (R/h)* v * cos(u)
    yy = (R/h)* v * sin(u)
    zz = v
    
    r = x(a) / z(a)
    v = v * z(a)
    

    xx = r * v * sign(cos(u)) * abs(cos(u))^1.85
    yy = r * v * sign(sin(u)) * abs(sin(u))^1.85
    zz = v

    return (xx,yy,zz)
end

surface2 = ParametricSurface(50,50,0.0,2*pi,0.0,5) do u,v

    # xx = sin(u * atan(v/u)) * sin(v * atan(v/u))
    # yy = sin(u * atan(v/u)) * cos(v * atan(v/u))
    # zz = sin(u * atan(v/u))

    h = 5
    R = 6

    xx = (R/h)* v * cos(u)
    yy = (R/h)* v * sin(u)
    zz = v

    yy = v * cos(u)
    xx = v *sin(u)
    zz = v

    return (xx,yy,zz-15)
end

play!()