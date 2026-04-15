#version 460 core

layout(location = 0) in vec4 position_in;
layout(location = 1) in vec4 color_size_in;
layout(location = 2) in uint type_id_in;

layout(location = 0) flat out vec3 color_out;
layout(location = 1) flat out vec3 color_inv_out;
layout(location = 2) flat out uint type_id_out;
layout(location = 3) flat out float radius_out;
layout(location = 4) flat out float z_view_out;

uniform mat4 VP;
uniform mat4 P;
uniform vec4 v_2_x;
uniform vec2 width_p_0_0;

void main() {
    z_view_out = dot(position_in, v_2_x);
    vec4 p = VP * position_in;
    gl_PointSize = color_size_in.a * 255.0;
    radius_out = (p.w / width_p_0_0.y) * (gl_PointSize / width_p_0_0.x);
    float clip_z = (z_view_out + radius_out) * P[2][2] + P[3][2];
    float clip_w = (z_view_out + radius_out) * P[2][3] + P[3][3];
    gl_Position = vec4(p.xy,clip_z,clip_w);
    color_out = color_size_in.rgb;
    color_inv_out = vec3(1.0) - color_size_in.rgb;
    type_id_out = type_id_in;
}