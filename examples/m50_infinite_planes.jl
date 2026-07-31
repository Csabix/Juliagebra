using Juliagebra
using JuliaGLM

using LinearAlgebra

p1 = Point(0,1,0)
p2 = Point(1,1,0)
p3 = Point(0,1,1)
plane1 = Plane(p1,p2,p3)

p4 = Point(  0,-0.5,0)
p5 = Point(0.5,-1.5,0)
p6 = Point(0.5,-0.5,0)
plane2 = Plane(p4,p5,p6;distance=9.9,color=(1.0,1.0,0.0,0.9))

Point([plane2];color="r") do plane
    return plane.p + plane.n * 2
end

p7 = Point(6.0,-5.6,-2.0)
p8 = Point(3.9, 3.2, 3.0)
segment1 = Segment(p7,p8)

i1 = Intersection(segment1, plane1)
Point([i1]) do intersection
    return intersection[1]
end
i2 = Intersection(plane2, segment1)
Point([i2]) do intersection
    return intersection[1]
end

i3 = Intersection(plane1, plane2)
Line([i3]) do intersection
    return intersection[1]
end

parallelHandle = Point(0,3,3)
parallelPlane1 = Plane(
    Vec3D(0,3,2),
    Vec3D(1,3,2),
    parallelHandle
)

i4 = Intersection(plane1, parallelPlane1)
Line([i4]) do intersection
    return intersection[1]
end

ray1 = Ray(Vec3D(3,-1,-2),Vec3D(3,-1,2);color="m")
i5 = Intersection(plane2, ray1)
Point([i5]) do intersection
    return intersection[1]
end

l1 = Line(Vec3D(-5,-5,10),Vec3D(-5,-5,-10);color="b")
i6 = Intersection(l1, plane2)
Point([i6]) do intersection
    return intersection[1]
end

p9  = Point(-3,-3,-2)
p10 = Point(-5,-3,-2)
p11 = Point(-3,-3,4)
triangle1 = Triangle(p9,p10,p11;color="b")
p12 = Point(-3,-2,1)
p13 = Point(-5,-4,1)
p14 = Point(-2,-4,1)
triangle2 = Triangle(p12,p13,p14;color=(.0,.0,1.0,0.9))

i7 = Intersection(triangle1,triangle2)
for i in 1:25
    Segment([i7]) do intersection
        return intersection[i]
    end
end

i7 = Intersection(triangle1,plane2)
for i in 1:25
    Segment([i7]) do intersection
        return intersection[i]
    end
end
i8 = Intersection(plane2,triangle2)
for i in 1:25
    Segment([i8]) do intersection
        return intersection[i]
    end
end



Juliagebra.Wait()
