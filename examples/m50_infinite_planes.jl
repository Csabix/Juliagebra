using Juliagebra
using JuliaGLM

using LinearAlgebra

p1 = Point(0,1,0)
p2 = Point(1,1,0)
p3 = Point(0,1,1)
plane1 = Plane(p1,p2,p3)

p4 = Point(  0, 0,0)
p5 = Point(0.5,-1,0)
p6 = Point(0.5, 0,0)
plane2 = Plane(p4,p5,p6,9.9;color="y")

l1 = Line(Vec3D(-5,5,10),Vec3D(-5,-5,-10);color="b")
i1 = Intersection(l1, plane1)
Point([i1]) do intersection
    return intersection[1]
end
i2 = Intersection(l1, plane2)
Point([i2]) do intersection
    return intersection[1]
end



Juliagebra.Wait()
