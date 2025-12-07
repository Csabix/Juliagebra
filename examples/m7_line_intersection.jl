using Juliagebra
using LinearAlgebra

context = App()


a1 = Point(10,0,0)
b1 = Point(-10,0,0)
s1 = Segment(a1,b1)

a2 = Point(0,10,0)
b2 = Point(0,-10,0)
s2 = Segment(a2,b2)

ip = Point(NaN64,NaN64,NaN64,[a1,b1,a2,b2]) do a1,b1,a2,b2
    no_intersect = (-50,-50,-50)
    epsilon = 0.1

    v1 = b1 - a1
    v2 = b2 - a2

    n_up = normalize(cross(v1,v2))
    
    # ! minden pont, itt felirhato ugy, mint a1 + v1 * t es dot(v1 * t,n_up) = 0, mivel n_up meroleges v1-re
    # ! tehat dot(a1 + v1 * t,n_up) = dot(a1,n_up) + dot(v1 * t,n_up) = dot(a1,n_up) + 0
    # ! azaz  dot((a2 + v2 * t2) - (a1 + v1 * t1),n_up) = dot(a2 + v2 * t2,n_up) - dot(a1 + v1 * t1,n_up) = dot(a2,n_up) - dot(a1,n_up)
    # ! es dot(a2,n_up) - dot(a1,n_up) = dot(a2 - a1, n_up)
    # ! szoval n_up azert jo vektor, mert mindenhol, csak a1,a2-tol fugg az eredmeny, mindenhol ugyanaz
    # ! a1 es a2 ket olyan sikbol van, amik v1 és v2 olyan sikjai, hogy azok parhuzamosak egymasra
    # ! igy d a ketto kozotti tavolsaga lesz
    # ! mivel "a" es "b" altal kifeszitett vektorok kozott az eltolas meroleges "n"-re, ezert mind1 mielyikkel szamolunk
    d = abs(dot(a2-a1,n_up))
    if( d > epsilon)
        return no_intersect
    end

    plane_n  = normalize(cross(v1,n_up))    
    plane_q0 = a1
    ray_p0 = a2
    ray_v  = v2

    # ? float t = dot(plane.q0-ray.p0,plane.n)/dot(ray.v,plane.n);
    t = dot(plane_q0-ray_p0,plane_n)/dot(ray_v,plane_n)
    if (t > 1.0 || t<0.0)
        return no_intersect
    end

    hit1 = ray_p0 + t * ray_v

    plane_n  = normalize(cross(v2,n_up))    
    plane_q0 = a2
    ray_p0 = a1
    ray_v  = v1
    s = dot(plane_q0-ray_p0,plane_n)/dot(ray_v,plane_n)
    if (s > 1.0 || s<0.0)
        return no_intersect
    end

    hit2 = ray_p0 + s * ray_v

    hit = (hit1 + hit2) ./ 2

    return hit
end


play!(context)