include("Prototype/juliagebra.jl")
using .JuliAgebra
using .JuliAgebra.LinearAlgebra

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

tab = Segment(ta,tb,(1.0,0.6,0.0))
tbc = Segment(tb,tc,(1.0,0.6,0.0))
tca = Segment(tc,ta,(1.0,0.6,0.0))

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

    return (1-u-v) .* a[:xyz] .+ u .* b[:xyz] .+ v .* c[:xyz]
end

intersectPoint = Point(-999,-999,-999,[sp1,sp2,ta,tb,tc]) do p1,p2,a,b,c
    p1 = collect(p1[:xyz])
    p2 = collect(p2[:xyz])
    
    a = collect(a[:xyz])
    b = collect(b[:xyz])
    c = collect(c[:xyz])

    p0 = p1
    v = p2 - p1

    ab = b - a
    ac = c - a
    ap = p0 - a
    f = cross(v,ac)
    g = cross(ap,ab)

    tuv = (1/dot(f,ab)) * [dot(g,ac),dot(f,ap),dot(g,v)]
    t = tuv[1]

    intersection = (1-t) * p1 + t * p2

    return (intersection[1],intersection[2],intersection[3])
end

play!()