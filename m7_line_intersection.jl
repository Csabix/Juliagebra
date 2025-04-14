include("Prototype/juliagebra.jl")
using .JuliAgebra
using LinearAlgebra

context = App()


a1 = Point(10,0,0)
b1 = Point(-10,0,0)
s1 = Segment(a1,b1)

a2 = Point(0,10,0)
b2 = Point(0,-10,0)
s2 = Segment(a2,b2)

ip = Point(-50,-50,-50,[a1,b1,a2,b2]) do a1,b1,a2,b2
    no_intersect = (-50,-50,-50)
    epsilon = 0.1

    a1v = collect((x(a1),y(a1),z(a1)))
    b1v = collect((x(b1),y(b1),z(b1)))
    a2v = collect((x(a2),y(a2),z(a2)))
    b2v = collect((x(b2),y(b2),z(b2)))

    v1v = b1v - a1v
    v2v = b2v - a2v

    n_up = normalize(cross(v1v,v2v))
    
    # ! mivel "a" es "b" altal kifeszitett vektorok kozott az eltolas meroleges "n"-re, ezert mind1 mielyikkel szamolunk
    d = abs(dot(a2v-a1v,n_up))
    if( d > epsilon)
        return no_intersect
    end

    plane_n  = normalize(cross(v1v,n_up))    
    plane_q0 = a1v
    ray_p0 = a2v
    ray_v  = v2v

    # ? float t = dot(plane.q0-ray.p0,plane.n)/dot(ray.v,plane.n);
    t = dot(plane_q0-ray_p0,plane_n)/dot(ray_v,plane_n)
    if (t > 1.0 || t<0.0)
        return no_intersect
    end

    hit = ray_p0 + t * ray_v

    ss = ((hit - a1v) ./ v1v)
    s = ss[1]
    if (s > 1.0 || s<0.0)
        return no_intersect
    end

    printstyled("d: $(d)\n"; color=:blue)
    printstyled("t: $(t)\n"; color=:blue)
    printstyled("hit: $(hit)\n"; color=:blue)
    printstyled("ss: $(ss)\n"; color=:blue)
    printstyled("s: $(s)\n"; color=:blue)


    return(hit[1],hit[2],hit[3])
end


play!(context)