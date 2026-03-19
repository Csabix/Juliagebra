#version 460 core

layout(location = 0) in vec3 position_in;
layout(location = 1) in vec3 color_in;
layout(location = 2) in uint point_size_in;
layout(location = 3) in uint id_in;

layout(location = 0) flat out vec3 color_out;
#ifndef STATIC
layout(location = 1) flat out vec3 color_inv_out;
#endif
layout(location = 2) flat out uint id_out;

uniform mat4 VP;

void main() {
    gl_PointSize = float(point_size_in);
    gl_Position = VP * vec4(position_in,1.0);
    color_out = color_in;
    #ifndef STATIC
    color_inv_out = vec3(1.0) - color_in;
    #endif
    id_out = id_in;
}