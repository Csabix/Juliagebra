using Juliagebra
using JuliaGLM
using LinearAlgebra

mat3 = Mat3T{Float64}
vec3 = Vec3D

function triangle(a,b,c)
    ParametricSurface(3,3,0.0,1.0,0.0,1.0,[a,b,c];transparent=true) do u,v,a,b,c
        if (u>=0.5 && v>=0.5)
            u = 0.5
            v = 0.5
        end
        return (1-u-v) .* a .+ u .* b .+ v .* c
    end
end

function rotated_point_center(base_direction,to_eye,center,radius)
    a = to_eye ./ norm(to_eye)
    return a * radius + center
end

function rotated_point_side(base_direction,to_eye,center,radius)
    a = to_eye ./ norm(to_eye)
    b = vec3(1,0,0)

    v = cross(a,b)
    s = norm(v)
    c = dot(a,b)
    k = 1.0 / (1.0 + c)

    R = mat3(
        [v.x * v.x * k + c,   v.y * v.x * k - v.z, v.z * v.x * k + v.y,
        v.x * v.y * k + v.z, v.y * v.y * k + c,   v.z * v.y * k - v.x,
        v.x * v.z * k - v.y, v.y * v.z * k + v.x, v.z * v.z * k + c]
    )

    direction = base_direction ./ norm(base_direction)
    r = sqrt(radius * radius * 2)
    return R * direction * r + center
end

constant(x,y,z) = GenericDependent{vec3}(vec3(x,y,z))

App()

radius = Slider(0.1,1.0,5.0)

bl = constant(0.0,-1.0,-1.0)
br = constant(0.0,+1.0,-1.0)
tl = constant(0.0,-1.0,+1.0)
tr = constant(0.0,+1.0,+1.0)

center = Point(0,0,0)
to = Point(1,1,1)
to_eye = GenericDependent{vec3}(vec3(0,0,0),[center,to]) do center, to
    return (to-center) ./ norm(to-center)
end

sphere_side = Point(rotated_point_center,[constant(1,0,0),to_eye,center,radius])
a = Point(rotated_point_side,[bl,to_eye,sphere_side,radius])
b = Point(rotated_point_side,[br,to_eye,sphere_side,radius])
c = Point(rotated_point_side,[tl,to_eye,sphere_side,radius])
d = Point(rotated_point_side,[tr,to_eye,sphere_side,radius])

triangle(a,b,c)
triangle(c,b,d)
Sphere(center,sphere_side;transparent=true)

play!()