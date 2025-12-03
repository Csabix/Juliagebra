using Juliagebra

App()

spring = function (t,c)
    tMax = (2*pi)*5
    x = cos(t)
    y = sin(t)
    z = (t/tMax)

    return (c[:x] + x, c[:y] + y, c[:z] * z)
end
tMax = (2*pi)*5
A = Point(0,0,1)
ParametricCurve(spring,0,tMax,200,(0.3,0.8,0.3),1,[A])
B = Point(2,0,1)
ParametricCurve(spring,0,tMax,200,(0.3,0.8,0.3),2,[B])
C = Point(-2,0,1)
ParametricCurve(spring,0,tMax,200,(0.3,0.8,0.3),3,[C])
D = Point(0,2,1)
ParametricCurve(spring,0,tMax,200,(0.3,0.8,0.3),4,[D])
E = Point(0,-2,1)
ParametricCurve(spring,0,tMax,200,(0.3,0.8,0.3),5,[E])
F = Point(2,2,1)
ParametricCurve(spring,0,tMax,200,(0.3,0.8,0.3),6,[F])

play!()