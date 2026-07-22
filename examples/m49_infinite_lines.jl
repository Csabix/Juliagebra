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

# i1 = Intersection(s1, l1)
# Point([i1]) do intersection
#     return intersection[1]
# end

p5 = Point( 4,5,  0)
p6 = Point(-4,5,1.9)
l2 = Line(p5,p6,50; color="y", style=".")

i2 = Intersection(l1, l2)
Point([i2]) do intersection
    return intersection[1]
end

p7 = Point(7, 1, 2)
p8 = Point(4, 6, 3)
p9 = Point(5,10,-5)
t1 = Triangle(p7,p8,p9)

# i3 = Intersection(l2, t1)
# Point([i3]) do intersection
#     return intersection[1]
# end



Juliagebra.Wait()
