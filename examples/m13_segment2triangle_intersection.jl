using Juliagebra
using LinearAlgebra

App()

sp1 = Point(-5,0,0)
sp2 = Point( 5,0,0)

ray = Segment(sp1,sp2)

coords = [
    (-1,-11,6),
    (6,8,14),
    (12,0,-8)
]



ta = Point(coords[1]...)
tb = Point(coords[2]...)
tc = Point(coords[3]...)

tab = Segment(ta,tb,color=(1.0,0.6,0.0))
tbc = Segment(tb,tc,color=(1.0,0.6,0.0))
tca = Segment(tc,ta,color=(1.0,0.6,0.0))

normals = [
    (0,0,0),
    (0,0,0),
    (0,0,0)
]
triangle = ParametricSurface(3,3,0.0,1.0,0.0,1.0,[ta,tb,tc]) do u,v,a,b,c
    
    if (u>=0.5 && v>=0.5)
        u = 0.5
        v = 0.5
    end

    return (1-u-v) .* a .+ u .* b .+ v .* c
end

intersectPoint = Point([sp1,sp2,ta,tb,tc]) do p1,p2,a,b,c
    p0 = p1
    v = p2 - p1

    ab = b - a
    ac = c - a
    ap = p0 - a
    f = cross(v,ac)
    g = cross(ap,ab)

    tuv = (1/dot(f,ab)) * [dot(g,ac),dot(f,ap),dot(g,v)]
    t = tuv[1]

    return (1-t) * p1 + t * p2
end

play!()