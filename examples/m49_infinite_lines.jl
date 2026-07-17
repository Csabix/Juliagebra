using Juliagebra
using JuliaGLM

p1 = Point(   2,0,0)
p2 = Point(-1.5,0,0)
s1 = Segment(p1,p2)

p3 = Point(0, 1, 1)
p4 = Point(0,-1,-1)
s2 = Segment(p3,p4)

i1 = Intersection(s1, s2)
Point([i1]) do intersection
    return intersection[1]
end

# p5 = Point( 1, 1, 1)
# p6 = Point(-1,-1,-1)

# SegmentSequence([p1, p2, p3, p4, p5, p6])

InfiniteLine(1,1,1)

inf1 = InfiniteLine([p3,p4]) do a,b
    return (a * 2.0 + b) / 3.0
end
Point([inf1]) do inf
    return inf * 2.0
end






Juliagebra.Wait()
