using LinearAlgebra

@kwdef mutable struct Camera
    eye::Vec3F= Vec3F(0.0f0,-5.0f0,1.0f0)
    at::Vec3F = Vec3F(0.0f0,0.0f0,0.0f0)
    up::Vec3F = Vec3F(0.0f0,0.0f0,1.0f0)

    view::Mat4T{Float32} = mat4(0.0f0)
    proj::Mat4T{Float32} = mat4(0.0f0)
    view_proj::Mat4T{Float32} = mat4(0.0f0)

    fov::Float32 = 50.0f0
    zNear::Float32 = 0.01f0
    zFar::Float32 = 999.0f0
    aspect::Float32 = 1280.0f0 / 720.0f0
end

function defaultCamera()::Camera
    camera = Camera()
    calculate_matrices!(camera)
    return camera
end

is_perspective(camera::Camera)::Bool = camera.proj[16] != 1.0f0
function set_ortho!(camera::Camera)::Nothing
    dist::Float32 = norm(camera.at - camera.eye)
    fovy::Float32 = deg2rad(camera.fov)
    a::Float32  = tan(fovy / 2.0f0)
    dz::Float32 = camera.zFar - camera.zNear
    ortho = Mat4T{Float32}(
        1.0f0 / (dist * camera.aspect * a), 0.0f0,                       0.0f0,                        0.0f0,
        0.0f0,                       1.0f0 / (dist * a),          0.0f0,                        0.0f0,
        0.0f0,                       0.0f0,                       -2.0f0 / dz,                  0.0f0,
        0.0f0,                       0.0f0,                       -(camera.zFar + camera.zNear) / dz, 1.0f0
    )
    camera.proj = ortho
    return nothing
end
function set_perspective!(camera::Camera)::Nothing
    camera.proj = perspective(deg2rad(camera.fov),camera.aspect,camera.zNear,camera.zFar)
    return nothing
end

swap_projection!(cam::Camera) = is_perspective(cam) ? set_ortho!(cam) : set_perspective!(cam)

function calculate_projection_matrix!(camera::Camera)::Nothing
    is_perspective(camera) ? set_perspective!(camera) : set_ortho!(camera)
    camera.view_proj = camera.proj * camera.view
    return nothing
end
function calculate_view_matrix!(camera::Camera)::Nothing
    camera.view = lookat(camera.eye,camera.at,camera.up)
    camera.view_proj = camera.proj * camera.view
    return nothing
end
function calculate_matrices!(camera::Camera)::Nothing
    camera.view = lookat(camera.eye,camera.at,camera.up)
    is_perspective(camera) ? set_perspective!(camera) : set_ortho!(camera)
    camera.view_proj = camera.proj * camera.view
    return nothing
end

function get_fov(self::Camera)::Float32
    if is_perspective(self)
        return deg2rad(self.fov)
    else
        d = norm(self.at - self.eye)
        a  = tan(deg2rad(self.fov) / 2.0f0)
        return -d * a;
    end
end

function get_lights(self::Camera, z::Float32 = 45.0f0)
    z = deg2rad(z)
    l_cam = normalize(self.at - self.eye)
    rot = Mat3T{Float32}(
        cos(z), -sin(z), 0.0f0,
        sin(z),  cos(z), 0.0f0,
        0.0f0,  0.0f0,   1.0f0
    )
    
    return (l_cam, rot * l_cam)
end

function get_matrices(self::Camera)
    return self.view_proj, self.view, self.proj
end