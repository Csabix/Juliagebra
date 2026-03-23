#version 460 core

layout(location = 0) in vec3 position_in;
layout(location = 1) in vec4 color_size_in;
layout(location = 2) in uint type_id_in;

layout(location = 0) flat out vec3 color_out;
layout(location = 1) flat out vec3 color_inv_out;
layout(location = 2) flat out uint type_id_out;

uniform mat4 VP;

void main() {
    gl_Position = VP * vec4(position_in,1.0);
    gl_PointSize = color_size_in.a * 255.0;
    color_out = color_size_in.rgb;
    color_inv_out = vec3(1.0) - color_size_in.rgb;
    type_id_out = type_id_in;
}