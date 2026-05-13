using Juliagebra

spring = function (t,c)
    tMax = (2*pi)*5
    x = cos(t)
    y = sin(t)
    z = (t/tMax)

    return (c.x + x, c.y + y, c.z * z)
end
tMax = (2*pi)*5
A = Point(0,0,1)
ParametricCurve(spring,range(0,tMax,20000),[A],"c-")
B = Point(2,0,1)
ParametricCurve(spring,range(0,tMax,20000),[B],"c--")
C = Point(-2,0,1)
ParametricCurve(spring,range(0,tMax,20000),[C],"c:")
D = Point(0,2,1)
ParametricCurve(spring,range(0,tMax,20000),[D],"c~")
E = Point(0,-2,1)
ParametricCurve(spring,range(0,tMax,20000),[E],"c-.")
F = Point(2,2,1)
ParametricCurve(spring,range(0,tMax,20000),[F],"c->")
F = Point(2,-2,1)
ParametricCurve(spring,range(0,tMax,20000),[F],"c<-")

Juliagebra.Wait()