using Juliagebra
auto_compile_shaders(true)
##
spring = function (t,c)
    tMax = (2*pi)*5
    x = cos(t)
    y = sin(t)
    z = (t/tMax)

    return (t*3, 0.0, 1.0 + sin(t*2))
end
tMax = 20
A = Point(0,0,1)
C = Point(-2,0,1)
#Segment(A,C;size=40.0)
ParametricCurve(spring,range(0,tMax,10),[C],"c:";size=40.0)
for t in range(0,tMax,10)
    #Point(t*3, 0.0, 1.0 + sin(t*2))
end
##
Segment(Point(0,0,1),Point(1,0,1),":";size=40.0)
Segment(Point(0,0,2),Point(1,0,2),":";size=40.0)
##
Juliagebra.Wait()