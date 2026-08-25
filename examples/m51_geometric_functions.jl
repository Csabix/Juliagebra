using Juliagebra
using JuliaGLM
using LinearAlgebra

#region Midpoints

p1 = Point(1,-.5,0;color="c")
p2 = Point(1,  0,0;color="c")

p3 = Point(1.5,0, 0)
p4 = Point(1.5,0,.5)
p5 = Point(  1,0,.5)
ps = PointSequence([p3,p4,p5];color="b")

Midpoint(p1,p2,ps;color="y")

p6 = Point(-1,0,0;color="b")
p7 = Point(-2,1,0;color="b")
Midpoint(p6,p7;color="y")

#endregion

#region Distance & Closest Point

# Point-Point
d1 = Distance(p1,p2; label="Point-Point distance")
Segment([p1,p2,d1];color="c") do p1,p2,dist
    return (p2, p2 + Vec3D(0,-1,0) * dist)
end

# Point-Triangle
p_t1 = Point(0,.3,.3;color="y")
t1 = Triangle(Vec3D(0.3,.6,0.1),Vec3D(-.2,.2,0.1),Vec3D(.4,0,0.1);color="b")
ClosestPoint(p_t1,t1;color="w")
d2 = Distance(p_t1,t1; label="Point-Triangle distance")
Segment([p_t1,t1,d2];color="c") do point,triangle,dist
    return (Vec3D(0),Vec3D(0,0,dist))
end

# Point-Curve
p_c1 = Point(0,1.3,.3;color="y")
c1 = ParametricCurve(range(-pi,pi,13);color="b") do t
    offset = Vec3D(0,1.5,0)
    return offset + Vec3D(t / 5.0,0,sin(t) / 5.0)
end
ClosestPoint(p_c1,c1;color="w")
d3 = Distance(p_c1,c1; label="Point-Curve distance")
Segment([p_c1,c1,d3];color="c") do point,curve,dist
    return (Vec3D(0,1.7,0),Vec3D(0,1.7,dist))
end

# Point-Surface
p_s1 = Point(0,2.3,.3;color="y")
surface1 = ParametricSurface(range(-pi,pi,5),range(-pi,pi,5);) do u,v
    return (u / 5, 2.5 + v / 5, (sin(u) + sin(v)) / 10)
end
ClosestPoint(p_s1,surface1;color="w")
d4 = Distance(p_s1,surface1; label="Point-Surface distance")
Segment([p_s1,surface1,d4];color="c") do point,surface,dist
    return (Vec3D(0,2,0),Vec3D(0,2,dist))
end

# Point-PointSet/PointSequence
ps2 = PointSet([Vec3D(0,4.5,0),Vec3D(.75,4.5,0),Vec3D(.5,5,0),Vec3D(-.5,4,.25)];color="b")
p13 = Point(-.25,4.25,.25;color="y")
ClosestPoint(p13,ps2;color="w",size=30)

p_circle1 = Point(.25,6,.25;color="b")
p_circle2 = Point(.25,6,-.25;color="b")
Segment(p_circle1,p_circle2;color="b",style="->",size=8)
d5 = Distance(p_circle1,p_circle2; label="Point-PointSet distance")
circle1 = Circle((p1,p2,dist) -> (p1,dist,p2 - p1),[p_circle1,p_circle2,d5];color="b")
p_circle3 = Point(.5,5.5,.5;color="y")
ClosestPoint(p_circle3,circle1;color="w")
d6 = Distance(p_circle3,circle1; label="Point-PointSequence distance")
Segment([p_circle3,circle1,d6];color="c") do point,circle,dist
    return (p0(circle),p0(circle) + Vec3D(0,0,1) * dist)
end

# Point-Line
p8 = Point(-.5,-1.5,1;color="y")
l1 = Line(Vec3D(0,-2,1),Vec3D(1,-2,1);color="c")
ClosestPoint(p8,l1;color="w")
d7 = Distance(p8,l1; label="Point-Line distance")
Segment([p8,l1,d7];color="c") do point,line,dist
    return (p0(line),p0(line) + Vec3D(0,1,0) * dist)
end

# Point-Ray
p9 = Point(0,-2.5,2;color="y")
r1 = Ray(Vec3D(.5,-3,2),Vec3D(1.5,-3,2);color="c")
ClosestPoint(p9,r1;color="w")
d8 = Distance(p9,r1; label="Point-Ray distance")
Segment([p9,r1,d8];color="c") do point,line,dist
    return (p0(line),p0(line) + Vec3D(0,1,0) * dist)
end

# Point-Segment
p10 = Point(.5,-3.5,3;color="y")
s1 = Segment(Vec3D(1,-4,3),Vec3D(2,-4,3);color="c")
ClosestPoint(p10,s1;color="w")
d9 = Distance(p10,s1; label="Point-Segment distance")
Segment([p10,s1,d9];color="c") do point,line,dist
    return (p0(line),p0(line) + Vec3D(0,1,0) * dist)
end

# Point-Plane
p11 = Point(1,-4.5,3;color="y")
plane1 = Plane(Vec3D(1.5,-5,3),Segment(Vec3D(10,-5,0),Vec3D(-10,-5,0);color="c");color="c")
ClosestPoint(p11,plane1;color="w")
d10 = Distance(p11,plane1; label="Point-Plane distance")
Segment([p11,plane1,d10];color="c") do point,plane,dist
    return (p0(plane),p0(plane) + Vec3D(0,1,0) * dist)
end

# Point-Sphere
p12 = Point(1.5,-5.5,10.5;color="y")
sphere1 = Sphere(Vec3D(2,-7,10.5),1.0;color="c")
ClosestPoint(p12,sphere1;color="w")
d11 = Distance(p12,sphere1; label="Point-Sphere distance")
Segment([p12,sphere1,d11];color="c") do point,sphere,dist
    return (Vec3D(2,-6,3),Vec3D(2,-6,3) + Vec3D(0,1,0) * dist)
end

#endregion

#region Perpendicular Line

p14 = Point(8,-4,8;color="y")
# PerpendicularLine(p14,plane1;color="g")
Perpendicular(p14,plane1;color="g")

p15 = Point(12,-.5,1.5;color="y")
PerpendicularLine(p15,l1;color="g")
# Perpendicular(p15,l1;color="g") # prefers plane

p15_2 = Point(15,-.5,1.5;color="y")
# PerpendicularLine(l1,p15_2;color="g")
Perpendicular(l1,p15_2;color="g")


#endregion

#region Perpendicular Plane

p16 = Point(22,-1.5,7.5;color="y")
p17 = Point(27,-5,6;color="g")
p18 = Point(22,2,6;color="g")
l2 = Ray(p18,p17;color="g")
# PerpendicularPlane(p16,l2;color="g")
Perpendicular(p16,l2;color="g")

p19 = Point(26,24,1;color="y")
p20 = Point(24,21,2;color="y")
# PerpendicularPlane(p19,p20;color="g")
Perpendicular(p19,p20;color="g")

#endregion

#region Parallel Line

p21 = Point(-13,18,3;color="y")
p22 = Point(-15,20,4;color="g")
p23 = Point(-15,20,0;color="g")
s2 = Segment(p22,p23;color="g")
# These give identical lines:
# ParallelLine(p21,s2;color="y")
# ParallelLine(p21,p22,p23;color="y")
Parallel(p21,s2;color="y")
Parallel(p21,p22,p23;color="y")

#endregion

#region Parallel Plane

p24 = Point(-19,-3,9;color="m")
# plane2 = Plane(p24,Vec3D(-19,-3,8),Vec3D(-19,-2,9);color="m")
circle2 = Circle([p24];color="m") do point
    return (Vec3D(-20,-3,9),1.0,point - Vec3D(-20,-3,9))
end
p25 = Point(-18,-2,2;color="y")
# ParallelPlane(p25,plane2;color="y")
# Parallel(p25,plane2;color="y")
Parallel(p25,circle2;color="y")

p26 = Point(-25,-12,8;color="m")
p27 = Point(-25,-12,9;color="m")
s3 = Segment(p26,p27;color="m")
p28 = Point(-24,-11,8;color="m")
p29 = Point(-26,-11,8;color="m")
s4 = Segment(p29,p28;color="m")
# ParallelPlane(s3,s4;color="y")
Parallel(s3,s4;color="y")

#endregion

Juliagebra.Wait()
