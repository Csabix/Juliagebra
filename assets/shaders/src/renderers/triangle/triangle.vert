#version 460 core
#extension GL_GOOGLE_include_directive : require
#include "../../common_data.glsl"

layout(location = 0) in vec4 position_in;
layout(location = 1) in vec4 normal_in;
layout(location = 2) in vec4 color_in;
layout(location = 3) in uint id_in;

layout(location = 0) flat out vec4 color_out;
layout(location = 1) flat out vec3 normal_out;
layout(location = 2) flat out uint id_out;
layout(location = 3) out vec4 position_out;

layout(std140, binding = 0) uniform TriangleUniforms {
    mat4 M;
    mat4 MIT;
};

void main() {
    gl_Position = VP * M * position_in;
    
    color_out = color_in;
    normal_out = (MIT * normal_in).xyz;
    id_out = id_in;
    position_out = position_in;
}