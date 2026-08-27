using Juliagebra
using JuliaGLM
using LinearAlgebra

p1 = Point(0, 0,-1)
p2 = Point(0,10, 1)
s1 = Segment(p1,p2)

p3 = Point( 4,5,-1)
p4 = Point(-4,5, 1)
l1 = Line([p3,p4]) do p0,p1
    return (p0,p1)
end

Point([l1];color="r") do line
    return p0(line) + normalize(v(line))
end

Point(Intersection(s1, l1)[1])

p5 = Point( 4,5,  0)
p6 = Point(-4,5,1.9)
l2 = Line(p5,p6;color="y",style=".")

Point(Intersection(l2, s1)[1])

Point(Intersection(l1, l2)[1])

p7 = Point(-1.0,2.40082,-0.5881)
p8 = Point(2.0,4.3,-0.00317593)
ray1 = Ray([p7,p8];color="m") do p0,p1
    return (p0,p1)
end

Point(Intersection(l2, ray1)[1])

ray2 = Ray(Vec3D(1.0,3.667,-2),Vec3D(1.0,3.667,3);color="m")
Point(Intersection(ray1, ray2)[1])

Point(Intersection(ray1, s1)[1])

t1 = Triangle(Vec3D(7,1,2),Vec3D(4,6,3),Vec3D(5,10,-5))


Point(Intersection(l2, t1)[1])
Point(Intersection(t1, ray1)[1])

p9  = Point(5.0,3.8,1.9)
p10 = Point(6.5,3.9,1.8)
s2 = Segment(p9,p10)
Point(Intersection(t1, s2)[1])



Juliagebra.Wait()