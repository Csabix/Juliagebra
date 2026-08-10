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

#region Distance

# Point-Point
Segment([p1,p2];color="c") do p1,p2
    dist = Distance(p1,p2)
    return (p2, p2 + Vec3D(0,-1,0) * dist)
end

# Point-Line
p8 = Point(-.5,-1.5,1;color="y")
l1 = Line(Vec3D(0,-2,1),Vec3D(1,-2,1);color="c")
Point([p8,l1];color="c") do point,line
    t = dot(point - p0(line), v(line))
    projected = p0(line) + v(line) * t
    return projected
end
Segment([p8,l1];color="c") do point,line
    dist = Distance(point,line)
    return (p0(line),p0(line) + Vec3D(0,1,0) * dist)
end

# Point-Ray
p9 = Point(-.5,-2.5,2;color="y")
r1 = Ray(Vec3D(0,-3,2),Vec3D(1,-3,2);color="c")
Segment([p9,r1];color="c") do point,line
    dist = Distance(point,line)
    return (p0(line),p0(line) + Vec3D(0,1,0) * dist)
end

# Point-Segment
p10 = Point(-.5,-3.5,3;color="y")
s1 = Segment(Vec3D(0,-4,3),Vec3D(1,-4,3);color="c")
Segment([p10,s1];color="c") do point,line
    dist = Distance(point,line)
    return (p0(line),p0(line) + Vec3D(0,1,0) * dist)
end

#endregion




Juliagebra.Wait()
