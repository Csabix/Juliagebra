#version 460 core

layout(location = 0) in vec3 position_in;
layout(location = 1) in vec4 color_size_in;
layout(location = 2) in uint type_id_in;

layout(location = 0) flat out vec3 color_out;
layout(location = 1) flat out vec3 color_inv_out;
layout(location = 2) flat out uint type_id_out;
layout(location = 3) flat out float radius_out;
layout(location = 4) flat out vec3 view_pos_out;

uniform mat4 VP;
uniform mat4 V;
uniform vec3 width_near_far;

void main() {
    const vec4 p = VP * vec4(position_in,1.0);
    gl_Position = p;
    const float point_size = color_size_in.a * 255.0;
    radius_out = point_size / width_near_far.x * mix(width_near_far.y,width_near_far.z,(p.z/p.w * 2.0 - 1.0));
    gl_PointSize = point_size;
    color_out = color_size_in.rgb;
    color_inv_out = vec3(1.0) - color_size_in.rgb;
    type_id_out = type_id_in;
    view_pos_out = (V * vec4(position_in, 1.0)).xyz;
}