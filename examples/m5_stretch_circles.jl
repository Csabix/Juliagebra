using Juliagebra

App()

Center = Point(0,0,0)

Axis1 = Point([Center]) do c
    return c + [5.0,0.0,0.0]
end

Axis2 = Point([Center]) do c
    return c + [0.0,5.0,0.0]
end

Axis3 = Point([Center]) do c
    return c + [0.0,0.0,5.0]
end

function dCircle(t,xRadius,yRadius)
    x = cos(t)*xRadius
    y = sin(t)*yRadius
    z = 0
    return [x,y,z]
end

ParametricCurve(range(0,2*pi,51),[Center,Axis1,Axis2]) do t, c, a1, a2
    xR = abs(c[:x] - a1[:x])
    yR = abs(c[:y] - a2[:y]) 
    
    coords = dCircle(t,xR,yR)
    
    return coords + c
end

ParametricCurve(range(0,2*pi,51),[Center,Axis2,Axis3]) do t, c, a2, a3
    yRad = abs(c[:y] - a2[:y])
    zRad = abs(c[:z] - a3[:z])

    y,z,x = dCircle(t,yRad,zRad)

    return [x,y,z] + c
end

play!()
