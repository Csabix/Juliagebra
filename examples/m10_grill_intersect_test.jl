using Juliagebra

App()

function genPoints(xp,yp,zp,xtr,ytr,ztr)
    p = Point(xp,yp,zp)
    s = Point([p]) do p
        return p .+ (xtr,ytr,ztr)
    end
    return (p,s)
end

p1,s1 = genPoints(0,-1,0,0,5,0)
p2,s2 = genPoints(0,1,0,5,0,0)

phase = 5*3.14
crv1 = ParametricCurve(range(-phase,phase,250),[p1,s1],color=(0.9,0.6,0.3)) do t, p, s
    distance = p.y - s.y
    
    x = t
    y = sin(t) * distance
    z = 0

    return p .+ (x,y,z) 
end

crv2 = ParametricCurve(range(-phase,phase,250),[p2,s2],color=(0.3,0.6,0.9)) do t, p, s
    distance = p.x - s.x
    
    x = sin(t) * distance
    y = t
    z = 0

    return p .+ (x,y,z) 
end

it = Intersection(crv1,crv2,100)

for i in 1:100
    Point([it]) do iit
        return iit[i]
    end
end

play!()




