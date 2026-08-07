using Juliagebra
using JuliaGLM
using LinearAlgebra


# Midpoints
p1 = Point(1,-.5,0;color="c")
p2 = Point(1,  0,0;color="c")

p3 = Point(1.5,0, 0)
p4 = Point(1.5,0,.5)
p5 = Point(  1,0,.5)
ps = PointSequence([p3,p4,p5];color="b") do p3,p4,p5
    return [p3,p4,p5]
end

Midpoint(p1,p2,ps;color="y")

p6 = Point(-1,0,0)
p7 = Point(-2,1,0)
Point((p0,p1) -> Midpoint(p0,p1), [p6,p7];color="y")
Point((p0,p1) -> Midpoint([p0,p1]) * 1.1, [p6,p7];color="y")


# Distances
d1 = Vec3D(.9,0,0)
d2 = Point([p1,p2];color="c",size=5) do p1,p2
    dist = Distance(p1,p2)
    return Vec3D(.9,-dist,0)
end
Segment(d1,d2;color="c")



Juliagebra.Wait()
