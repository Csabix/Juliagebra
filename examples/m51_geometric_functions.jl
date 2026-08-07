using Juliagebra
using JuliaGLM
using LinearAlgebra


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


Juliagebra.Wait()
