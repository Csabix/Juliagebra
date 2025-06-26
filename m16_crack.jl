include("Prototype/juliagebra.jl")
using .JuliAgebra

App()

srfc1 = ParametricSurface(2,2,-10,10,-10,10) do u,v
    return (u,v,u*0.25)
end

a = Point(0,0,2)
phase = 5*3.14

crv1 = ParametricCurve(-phase,phase,250,[a]) do t, p
    xx = t
    yy = 0
    zz = sin(t)*5

    return (x(p) + xx, y(p) + yy, z(p) + zz)
end

it = Intersection(crv1,srfc1,10)

for i in 1:10
    Point(-999,-999,-999,[it]) do iit
        return iit[i]
    end
end

ParametricCurve(1,10,10,[it]) do t,itt
    return itt[Int(t)]
end

ParametricSurface([it],10,10,1,10,11,15) do u,v,itt
    result = itt[Int(u)]
    if(isa(result,Undef))
        return result
    end

    rx,ry,rz = result

    return (rx,v,rz)
end

play!()