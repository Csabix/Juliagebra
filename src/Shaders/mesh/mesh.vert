#version 460 core

layout (location = 0) in vec4 in_position;
uniform mat4 MVP;
#ifndef ID
layout (location = 1) in vec4 in_normal;
layout(location = 2) in vec3 in_color;
uniform mat4 MIT;
layout(location = 0) out vec3 out_normal;
layout(location = 1) out vec3 out_color;
#endif

void main() {
    #ifndef ID
    out_normal = vec3(MIT * in_normal);
    out_color = in_color;
    #endif
    gl_Position = MVP * in_position;
}