using Juliagebra

App()

function circle(radius,t)
    x = cos(t) * radius
    y = sin(t) * radius
    z = 0
    return (x,y,z)
end

crv1 = ParametricCurve(0,2*pi,5) do t
    circle(5.0,t)
end
crv2 = ParametricCurve(0,2*pi,5) do t
    circle(10.0,t)
end

Center = Point(0,0,0)

tMax = (2*pi)*5
radius = 5

crv3 = ParametricCurve(0,tMax,55,[Center]) do t,p1
    xx = cos(t) * radius
    yy = sin(t) * radius
    zz = p1[:z] * (t/tMax)
    
    return (xx,yy,zz + 15)
end

play!()