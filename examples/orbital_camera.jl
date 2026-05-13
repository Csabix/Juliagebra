using Juliagebra
using JuliaGLM
using LinearAlgebra

u = Slider(-π,π;label="u")
v = Slider(-π,π;label="v")

function show_vec(p,v,color)
    w_p = WrapValue(p)
    w_v = WrapValue(v)
    pp = ValueHolder(Vec3D, [w_p,w_v]) do p, v
        return (p + v * 0.3)
    end
    Segment(w_p,pp;color=color,style="->",size=6.0)
end

Sphere((0,0,0),1;color=(0.5,0.5,0.5,0.5));

eye = @ValueHolder(Vec3D) do
    eye = Vec3T(cos(u) * sin(v),
                sin(u) * sin(v),
                cos(v))
end

world_up = Vec3D(0,0,1)

forward = @ValueHolder(Vec3D) do
    normalize(-eye)
end
right = @ValueHolder(Vec3D) do
    Vec3D(cos(u+π/2.0),sin(u+π/2.0),0.0)
end
up = @ValueHolder(Vec3D) do
    cross(right, forward)
end

show_vec(eye, world_up, "w")
show_vec(eye, forward,  "b")
show_vec(eye, right,    "r")
show_vec(eye, up,       "g")

@TriangleCluster(color="cyan") do
    fov = 45.0
    aspect_ratio = 1.6
    scale = 0.2

    half_h = scale * tan(deg2rad(fov / 2.0))
    half_w = half_h * aspect_ratio

    base_center = eye .+ (forward .* scale)

    positions = [
        eye,
        base_center .+ (right .* half_w) .+ (up .* half_h),
        base_center .- (right .* half_w) .+ (up .* half_h),
        base_center .- (right .* half_w) .- (up .* half_h),
        base_center .+ (right .* half_w) .- (up .* half_h)
    ]

    indices = [
        0, 1, 2,
        0, 2, 3,
        0, 3, 4,
        0, 4, 1,
        1, 3, 2,
        1, 4, 3
    ]

    return positions, indices
end

Juliagebra.Wait()