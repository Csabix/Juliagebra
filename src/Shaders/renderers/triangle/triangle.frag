#version 460 core
#include "../color_output.glsl"

layout(location = 0) flat in vec4 color_in;
layout(location = 1) flat in vec3 normal_in;
layout(location = 2) flat in uint id_in;

void main(){
    vec3 normal = normal_in;
    vec3 color = color_in.rgb;
    float alpha = color_in.a;
    if (!gl_FrontFacing) {
        normal = -normal;
        color = vec3(1.0) - color;
    }

    float diffuse = (max(dot(normal,light_cam()),0.0) * 0.3 + max(dot(normal,light_side()),0.0) * 0.7) * 0.8;
    float ambient = 0.2;
    vec4 color4 = vec4(color * (diffuse + ambient), color_in.a);

    WRITE_COLOR(color4, id_in, gl_FragCoord.z)
}
