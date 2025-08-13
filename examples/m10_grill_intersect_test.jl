using Juliagebra

App()

function genPoints(xp,yp,zp,xtr,ytr,ztr)
    p = Point(xp,yp,zp)
    s = Point(xp+xtr,yp+ytr,zp+ztr,[p]) do p
        return p[:xyz] .+ (xtr,ytr,ztr)
    end
    return (p,s)
end

p1,s1 = genPoints(0,-1,0,0,5,0)
p2,s2 = genPoints(0,1,0,5,0,0)

phase = 5*3.14
crv1 = ParametricCurve(-phase,phase,250,(0.9,0.6,0.3),[p1,s1]) do t, p, s
    distance = p[:y] - s[:y]
    
    x = t
    y = sin(t) * distance
    z = 0

    return p[:xyz] .+ (x,y,z) 
end

crv2 = ParametricCurve(-phase,phase,250,(0.3,0.6,0.9),[p2,s2]) do t, p, s
    distance = p[:x] - s[:x]
    
    x = sin(t) * distance
    y = t
    z = 0

    return p[:xyz] .+ (x,y,z) 
end

it = Intersection(crv1,crv2,100)

for i in 1:100
    Point(-999,-999,-999,[it]) do iit
        return iit[i]
    end
end

play!()




