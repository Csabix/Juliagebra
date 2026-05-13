using Juliagebra

App()

Center1 = Point(0,0,0)

tMax = (2*pi)*5
radius = 5

crv1 = ParametricCurve(range(0,tMax,55),[Center1],color=(0.3,0.8,0.3)) do t,p1
    x = cos(t) * radius
    y = sin(t) * radius
    z = p1.z * (t/tMax)
    
    return [x,y,z]
end

Center2 = Point(0,0,10)

radius2 = 4

crv2 = ParametricCurve(range(0,2*pi,35),[Center2]) do t,c2
    x = c2.x + cos(t) * radius2
    y = c2.y 
    z = c2.z + sin(t) * radius2
    return [x,y,z]
end

it = Intersection(crv1,crv2; maxIntersectionNum=25)

for i in 1:25
    Point([it]) do iit
        return iit[i]
    end
end

Juliagebra.Wait()


