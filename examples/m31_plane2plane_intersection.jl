using Juliagebra
using LinearAlgebra
using JuliaGLM

App()

function Plane(p0,p1,p2)
    return ParametricSurface(2,2,-1.0,1.0,-1.0,1.0,[p0,p1,p2]) do u,v,p0,p1,p2
        xv = p1[:xyz] - p0[:xyz]
        yu = p2[:xyz] - p0[:xyz]

        return p0[:xyz] + (xv * v + yu * u) * 10
    end
end

function NormPoint(p0,p1,p2)
    return Point(NaN64,NaN64,NaN64,[p0,p1,p2]) do p0,p1,p2
        v1 = p1[:xyz] - p0[:xyz]
        v2 = p2[:xyz] - p0[:xyz]
        n = normalize(cross(v1,v2))
                
        return p0[:xyz] + n
    end
end

p10 = Point(2.0,0.0,0.0)
p11 = Point(2.0,0.0,1.0)
p12 = Point(1.0,0.0,0.0)
n1 = NormPoint(p10,p11,p12)
Plane(p10,p11,p12)
Segment(p10,p11)
Segment(p10,p12)
Segment(p10,n1)

p20 = Point(0.0,2.0,0.0)
p21 = Point(0.0,2.0,1.0)
p22 = Point(0.0,1.0,0.0)
n2 = NormPoint(p20,p21,p22)
Plane(p20,p21,p22)
Segment(p20,p21)
Segment(p20,p22)
Segment(p20,n2)

function plane2planeIntersection(plane_n1,plane_n2,plane_p1,plane_p2)
    
    plane_d1 = dot(-plane_n1,plane_p1)
    plane_d2 = dot(-plane_n2,plane_p2)

    plane_n3 = cross(plane_n1,plane_n2)
    
    determinant = (norm(plane_n3))^2

    line_p3 = Vec3D(NaN64,NaN64,NaN64)
    if (determinant != 0.0)
        line_p3 = (cross(plane_n3,plane_n2) * plane_d1 + cross(plane_n1,plane_n3) * plane_d2) / determinant
    end

    return (Vec3D(plane_n3),Vec3D(line_p3))
end

l12 = GenericDependent{Tuple{Vec3D,Vec3D}}((Vec3D(NaN64),Vec3D(NaN64)),[p10,p20,n1,n2]) do p10,p20,n1,n2
    plane_n1 = n1[:xyz] - p10[:xyz]
    plane_n2 = n2[:xyz] - p20[:xyz]

    return plane2planeIntersection(plane_n1,plane_n2,p10[:xyz],p20[:xyz])
end

lp1 = Point(NaN64,NaN64,NaN64,[l12]) do l12
    line_n,line_p = l12[:val]

    return line_p + line_n * 50
end

lp2 = Point(NaN64,NaN64,NaN64,[l12]) do l12
    line_n,line_p = l12[:val]

    return line_p + line_n * -50
end

Segment(lp1,lp2)

play!()