using Juliagebra
using JuliaGLM

p1 = Point(0, 0,-1)
p2 = Point(0,10, 1)
s1 = Segment(p1,p2)

p3 = Point( 4,5,-1)
p4 = Point(-4,5, 1)
l1 = Line([p3,p4]) do p0,p1
    return (p0,p1)
end

# Point([l1];color="r") do line
#     return line.p0 + (line.p1 - line.p0)
# end

# i1 = Intersection(s1, l1)
# Point([i1]) do intersection
#     return intersection[1]
# end

# p5 = Point( 4,5,  0)
# p6 = Point(-4,5,1.9)
# l2 = Line(p5,p6;color="y",style=".")

# i2 = Intersection(l2, s1)
# Point([i2]) do intersection
#     return intersection[1]
# end

# i3 = Intersection(l1, l2)
# Point([i3]) do intersection
#     return intersection[1]
# end

# t1 = Triangle(Vec3D(7,1,2),Vec3D(4,6,3),Vec3D(5,10,-5))

# p7 = Point(-1.0,2.4,-0.6)
# p8 = Point(2.0,4.3,0.0)
# ray1 = Ray(p7,p8;color="m")

# i4 = Intersection(l2, ray1)
# Point([i4]) do intersection
#     return intersection[1]
# end

# ray2 = Ray(Vec3D(1.0,3.667,-2),Vec3D(1.0,3.667,3);color="m")
# i5 = Intersection(ray1, ray2)
# Point([i5]) do intersection
#     return intersection[1]
# end

# i6 = Intersection(ray1, s1)
# Point([i6]) do intersection
#     return intersection[1]
# end

# i7 = Intersection(t1, l2)
# Point([i7]) do intersection
#     return intersection[1]
# end
# i8 = Intersection(ray1, t1)
# Point([i8]) do intersection
#     return intersection[1]
# end

# p9  = Point(5.0,3.8,1.9)
# p10 = Point(6.5,3.9,1.8)
# s2 = Segment(p9,p10)
# i9 = Intersection(t1, s2)
# Point([i9]) do intersection
#     return intersection[1]
# end



Juliagebra.Wait()