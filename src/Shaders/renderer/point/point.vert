#version 460core

layout(location = 0) in vec3 coord_in;
layout(location = 1) in uint color_size_in;
layout(location = 2) in uint id_in;

layout(location = 0) flat out uint id_out;
layout(location = 1) flat out vec3 color_out;

layout(location = 0) uniform mat4 VP;

void main(){
    vec4 color_size = unpackUnorm4x8(color_size_in);
    gl_PointSize = color_size.w * 255.0;
    gl_Position = VP * vec4(coord_in,1.0);
    id_out = id_in;
    color_out = color_size.rgb;
}