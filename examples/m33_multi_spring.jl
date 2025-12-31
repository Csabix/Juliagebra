using Juliagebra

App()

spring = function (t,c)
    tMax = (2*pi)*5
    x = cos(t)
    y = sin(t)
    z = (t/tMax)

    return (c.x + x, c.y + y, c.z * z)
end
tMax = (2*pi)*5
A = Point(0,0,1)
ParametricCurve(spring,range(0,tMax,20000),[A];color=(0.3,0.8,0.3),type=CURVE_SOLID)
B = Point(2,0,1)
ParametricCurve(spring,range(0,tMax,20000),[B];color=(0.3,0.8,0.3),type=CURVE_DASHED)
C = Point(-2,0,1)
ParametricCurve(spring,range(0,tMax,20000),[C],color=(0.3,0.8,0.3),type=CURVE_DOTTED)
D = Point(0,2,1)
ParametricCurve(spring,range(0,tMax,20000),[D],color=(0.3,0.8,0.3),type=CURVE_WAVE)
E = Point(0,-2,1)
ParametricCurve(spring,range(0,tMax,20000),[E],color=(0.3,0.8,0.3),type=CURVE_DASH_DOT)
F = Point(2,2,1)
ParametricCurve(spring,range(0,tMax,20000),[F],color=(0.3,0.8,0.3),type=CURVE_ARROW)

play!()