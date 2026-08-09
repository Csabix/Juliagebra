using Juliagebra
using JuliaGLM

App()


#Point_test
Point(0.0, 0.0, 0.0)
Point(0.0,1.0,0.0,color="c",style="+",size=30)
Point(0.0,2.0,0.0,"g+",size=12)
Point(0.0,3.0,0.0,style="+",size=35)
Point(0.0,4.0,0.0,style=".",size=10)
Point(0.0,5.0,0.0,style="+")

#PointSet_test
positions = [
    (3.0, 0.0, 0.0),
    (3.0, 1.0, 0.0),
]

positions2 = [
    (3.0, 2.0, 0.0),
    (3.0, 3.0, 0.0),
]


points = [
    Point(3.0, 4.0, 0.0),
    Point(3.0, 5.0, 0.0)
]


PointSet(positions)

PointSet(positions2,color = "c",style = "+",size = 30)

PointSet(points)


#PointSequence_test
points2 = [
    Point(6.0, 0.0, 0.0),
    Point(6.0, 1.0, 0.0)
]

points3 = [
    Point(6.0, 2.0, 0.0),
    Point(6.0, 3.0, 0.0)
]

points4 = [
    Point(6.0, 4.0, 0.0),
    Point(6.0, 5.0, 0.0)
]

PointSequence(points2)

PointSequence(points3,color="c",style="+",size=35)

PointSequence(points4,"m+")

#Sphere_test
p1=Point(9.0,0.0,0.0)
p2=Point(9.0,2.0,0.0)
p3=Point(9.0,4.0,0.0)

p4=Point(10.0, 6.0, 0.0)
p5=Point(8.0,  6.0, 0.0)
p6=Point(9.0,  7.0, 0.0)
p7=Point(9.0,  6.0, 1.0)

Sphere(p1,1.0)

Sphere(p2,0.5, color="m")

Sphere(p3,1.2,"c")

Sphere(p4,p5,p6,p7)


#ParametricCurve_test

function circle(radius,t)
    x = cos(t) * radius
    y = sin(t) * radius
    z = 0
    return (x,y,z)
end

Center = Point(12,0,0)
Center2 = Point(12,5,0)
Center3 = Point(12,10,0)

tMax = (2*pi)*5
radius = 1

ParametricCurve(range(0,tMax,150),[Center]) do t,p1
    xx = cos(t) * radius
    yy = sin(t) * radius
    zz = p1.z * (t/tMax)
    
    return (xx+12,yy,zz)
end

ParametricCurve(range(0,tMax,150),[Center2],color="g",style="-.",size=2.4) do t,p1
    xx = cos(t) * radius
    yy = sin(t) * radius
    zz = p1.z * (t/tMax)
    
    return (xx+12,yy+5,zz)
end

ParametricCurve(range(0,tMax,150),[Center3],"m:") do t,p1
    xx = cos(t) * radius
    yy = sin(t) * radius
    zz = p1.z * (t/tMax)
    
    return (xx+12,yy+10,zz)
end


#ParametricSurface_test

a = Point(15,0,0)
n = 0.1
k= 0.5

ParametricSurface(range(-10.0,10.0,50),range(-10.0,10.0,50),[a]) do u,v,p1
    x = u * n
    y = v * n
    z = sin(u + p1.x) * k

    return (x + 15,y,z)
end

ParametricSurface(range(-10.0,10.0,50),range(-10.0,10.0,50),[a],color="m") do u,v,p1
    x = u * n
    y = v * n
    z = sin(u + p1.x) * k

    return (x + 15,y+5,z)
end

ParametricSurface(range(-10.0,10.0,50),range(-10.0,10.0,50),[a],"r") do u,v,p1
    x = u * n
    y = v * n
    z = sin(u + p1.x) * k

    return (x + 15,y+10,z)
end

#SegmentSequence_test

styles = [SOLID,DASHED,DOTTED,WAVE,DASH_DOT,ARROW,ARROW_REVERSED]

    s = Slider(2,10)

    for i in 1:10
        ss = SegmentSequence([s],i) do s
            return [Vec3F(j+21,i,0) for j in 1:s]
        end
    end

    for i in 1:10
        ss = SegmentSequence([s],i;
        style=styles[mod1(i,length(styles))],size=10.0,color=[(1.0,0.0,0.0),(0.0,1.0,0.0)]) do s
            return [Vec3F(j+18,i,0) for j in 1:s]
        end
    end

    for i in 1:10
        ss = SegmentSequence([s],i,"g<-") do s
            return [Vec3F(j+24,i,0) for j in 1:s]
        end
    end


#Triangle_test
p8 = Point(27,0,0)
p9 = Point(30,0,0)
p10 = Point(28.5,3,0)
p11 = Point(27,6,0)
p12 = Point(30,6,0)
p13 = Point(28.5,9,0)

Triangle(p8,p9,p10)
Triangle(p11,p12,p13,color="r")

#TriangleCluster_test
#m39_scene_load.jl

#Tetrahedra_test
p14 = Point(33,0,0)
p15 = Point(36,0,0)
p16 = Point(33,3,0)
p17 = Point(33,0,3)

p18 = Point(39,0,0)
p19 = Point(42,0,0)
p20 = Point(39,3,0)
p21 = Point(39,0,3)

Tetrahedra(p14,p15,p16,p17)
Tetrahedra(p18,p19,p20,p21,color="r",border_color="c",border_style="-.",border_size=8)

#Segment_test
p22 = Point(-3,0,0)
p23 = Point(-3,3,0)

p24 = Point(-6,0,0)
p25 = Point(-6,3,0)

Segment(p22,p23)
Segment(p24,p25,color="g",style="~",size=10)

Juliagebra.Wait()