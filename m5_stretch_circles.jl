include("Prototype/juliagebra.jl")
using .JuliAgebra

context = App()

Center = Point(0,0,0,context)

ax1(Center) = return (x(Center)+5,y(Center),z(Center))
Axis1 = Point(5,0,0,[Center],ax1,context)

ax2(Center) = return (x(Center),y(Center)+5,z(Center))
Axis2 = Point(0,5,0,[Center],ax2,context)

function circle(t,xRad,yRad)
    x = cos(t)*xRad
    y = sin(t)*yRad
    z = 0
    
    return (x,y,z)
end

function depCircle1(t,p1,p2,p3)
    xRad = abs(x(p1) - x(p2))
    yRad = abs(y(p1) - y(p3))
    xx,yy,zz = circle(t,xRad,yRad)
    return (xx + x(p1),yy + y(p1),zz + z(p1))
end

crv1 = ParametricCurve(0,2*pi,51,[Center,Axis1,Axis2],depCircle1,context)

ax3(Center) = return (x(Center),y(Center),z(Center)+5)
Axis3 = Point(0,0,5,[Center],ax3,context)

function depCircle2(t,p1,p2,p3)
    yRad = abs(y(p1) - y(p2))
    zRad = abs(z(p1) - z(p3))
    yy,zz,xx = circle(t,yRad,zRad)
    return (xx + x(p1),yy + y(p1),zz + z(p1))
end

crv2 = ParametricCurve(0,2*pi,51,[Center,Axis2,Axis3],depCircle2,context)

play!(context)
