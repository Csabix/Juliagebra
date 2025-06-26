include("Prototype/juliagebra.jl")
using .JuliAgebra

App()
function genPoints(xp,yp,zp,xtr,ytr,ztr)
    p = Point(xp,yp,zp)
    s = Point(xp+xtr,yp+ytr,zp+ztr,[p]) do p
        return (x(p)+xtr,y(p)+ytr,z(p)+ztr)
    end
    return (p,s)
end



p1,s1 = genPoints(0,-1,0,0,5,0)
p2,s2 = genPoints(0,1,0,5,0,0)


phase = 5*3.14
crv1 = ParametricCurve(-phase,phase,250,[p1,s1],(0.9,0.6,0.3)) do t, p, s
    #xd = (x(p) - x(s))^2
    #yd = (y(p) - y(s))^2
    #zd = (z(p) - z(s))^2
    #distance = sqrt(xd+yd+zd)
    
    distance = y(p) - y(s)
    
    xx = t
    yy = sin(t) * distance
    zz = 0

    return (x(p) + xx, y(p) + yy, z(p) + zz)
end

crv2 = ParametricCurve(-phase,phase,250,[p2,s2],(0.3,0.6,0.9)) do t, p, s
    #xd = (x(p) - x(s))^2
    #yd = (y(p) - y(s))^2
    #zd = (z(p) - z(s))^2
    #distance = sqrt(xd+yd+zd)
    
    distance = x(p) - x(s)
    
    xx = sin(t) * distance
    yy = t
    zz = 0

    return (x(p) + xx, y(p) + yy, z(p) + zz)
end

it = Intersection(crv1,crv2,100)

for i in 1:100
    Point(-999,-999,-999,[it]) do iit
        return iit[i]
    end
end

play!()




