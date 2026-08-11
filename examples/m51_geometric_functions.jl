using Juliagebra
using JuliaGLM
using LinearAlgebra

#region Midpoints

p1 = Point(1,-.5,0;color="c")
p2 = Point(1,  0,0;color="c")

p3 = Point(1.5,0, 0)
p4 = Point(1.5,0,.5)
p5 = Point(  1,0,.5)
ps = PointSequence([p3,p4,p5];color="b") do p3,p4,p5
    return [p3,p4,p5]
end

Midpoint(p1,p2,ps;color="y")

p6 = Point(-1,0,0;color="b")
p7 = Point(-2,1,0;color="b")
Point((p0,p1) -> Midpoint(p0,p1), [p6,p7];color="y")
Point((p0,p1) -> Midpoint([p0,p1]) * 1.1, [p6,p7];color="y")

#endregion

#region Distance & Closest Point

# Point-Point
Segment([p1,p2];color="c") do p1,p2
    dist = Distance(p1,p2)
    return (p2, p2 + Vec3D(0,-1,0) * dist)
end

# Point-Line
p8 = Point(-.5,-1.5,1;color="y")
l1 = Line(Vec3D(0,-2,1),Vec3D(1,-2,1);color="c")
ClosestPoint(p8,l1;color="w")
Segment([p8,l1];color="c") do point,line
    dist = Distance(point,line)
    return (p0(line),p0(line) + Vec3D(0,1,0) * dist)
end

# Point-Ray
p9 = Point(0,-2.5,2;color="y")
r1 = Ray(Vec3D(.5,-3,2),Vec3D(1.5,-3,2);color="c")
ClosestPoint(p9,r1;color="w")
Segment([p9,r1];color="c") do point,line
    dist = Distance(point,line)
    return (p0(line),p0(line) + Vec3D(0,1,0) * dist)
end

# Point-Segment
p10 = Point(.5,-3.5,3;color="y")
s1 = Segment(Vec3D(1,-4,3),Vec3D(2,-4,3);color="c")
ClosestPoint(p10,s1;color="w")
Segment([p10,s1];color="c") do point,line
    dist = Distance(point,line)
    return (p0(line),p0(line) + Vec3D(0,1,0) * dist)
end

# Point-plane
p11 = Point(1,-4.5,3;color="y")
plane1 = Plane(Vec3D(1.5,-5,3),Segment(Vec3D(10,-5,0),Vec3D(-10,-5,0);color="c");color="c")
ClosestPoint(p11,plane1;color="w")
Segment([p11,plane1];color="c") do point,plane
    dist = Distance(point,plane)
    return (p0(plane),p0(plane) + Vec3D(0,1,0) * dist)
end

# Point-sphere
p12 = Point(1.5,-5.5,3;color="y")
sphere1 = Sphere(Vec3D(2,-7,3),1.0;color="c")
ClosestPoint(p12,sphere1;color="w")
Segment([p12,sphere1];color="c") do point,sphere
    dist = Distance(point,sphere)
    return (Vec3D(2,-6,3),Vec3D(2,-6,3) + Vec3D(0,1,0) * dist)
end

# Closet Point
ps2 = PointSet([Vec3D(0,1.5,4),Vec3D(-.5,1.5,4),Vec3D(-.5,2,4),Vec3D(-1,1,4.25)];color="b")
p13 = Point(-.75,1.25,4.25;color="y")
ClosestPoint(p13,ps2;color="w",size=30)

#endregion

#region Perpendicular Line

p14 = Point(8,-4,8;color="y")
PerpendicularLine(p14,plane1;color="g")

p15 = Point(12,-.5,1.5;color="y")
PerpendicularLine(p15,l1;color="g")

#endregion



Juliagebra.Wait()
