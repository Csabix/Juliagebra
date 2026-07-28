using Juliagebra
using JuliaGLM

p1 = Point(0, 0,-1)
p2 = Point(0,10, 1)
s1 = Segment(p1,p2)

p3 = Point( 4,5,-1)
p4 = Point(-4,5, 1)
l1 = Line(p3,p4,50)

Point([l1];color="r") do line
    return line.p + line.v
end

i1 = Intersection(s1, l1)
Point([i1]) do intersection
    return intersection[1]
end

p5 = Point( 4,5,  0)
p6 = Point(-4,5,1.9)
l2 = Line(p5,p6,50; color="y", style=".")

i2 = Intersection(l2, s1)
Point([i2]) do intersection
    return intersection[1]
end

i3 = Intersection(l1, l2)
Point([i3]) do intersection
    return intersection[1]
end

t1 = Triangle(Vec3D(7,1,2),Vec3D(4,6,3),Vec3D(5,10,-5))

p7 = Point(-1,-1,-1)
p8 = Point(2,2,2)
Ray(p7,p8,100.0)

# i3 = Intersection(l2, t1)
# Point([i3]) do intersection
#     return intersection[1]
# end



Juliagebra.Wait()
