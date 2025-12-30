using Juliagebra
using JuliaGLM
using LinearAlgebra

App()

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

function line2PlaneIntersection(line_n,line_p,plane_n,plane_p)
    t = dot(plane_p-line_p,plane_n) / dot(line_n,plane_n)
    return line_p + t * line_n   
end

function sameDistancePlane(p1,p2)
    plane_n = p2 - p1
    plane_c = ((p2 - p1) / 2.0) + p1
    return (plane_n,plane_c)
end

function sphereCenter(p1,p2,p3,p4)
    plane_n12,plane_c12 = sameDistancePlane(p1,p2)
    plane_n34,plane_c34 = sameDistancePlane(p3,p4)

    line_n_12_34,line_p_12_34 = plane2planeIntersection(plane_n12,plane_n34,plane_c12,plane_c34)
    
    plane_n23,plane_c23 = sameDistancePlane(p2,p3)

    c = line2PlaneIntersection(line_n_12_34,line_p_12_34,plane_n23,plane_c23)

    return c
end

p1 = Point( 1.0, 1.0,0.0)
p2 = Point( 1.0,-1.0,0.0)
p3 = Point(-1.0,-1.0,0.0)
p4 = Point(-1.0, 1.0,0.0)


c = Point([p1,p2,p3,p4]) do p1,p2,p3,p4
    return sphereCenter(p1,p2,p3,p4)
end

r = GenericDependent(NaN64,[c,p1]) do c,p1
    return norm(p1-c)
end


sphr3 = Sphere(c,r)

play!()