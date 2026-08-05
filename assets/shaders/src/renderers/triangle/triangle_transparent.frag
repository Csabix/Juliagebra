#version 460 core
#extension GL_GOOGLE_include_directive : require
#define TRANSPARENT
#include "../color_output.glsl"

layout(location = 0) flat in vec4 color_in;
layout(location = 1) flat in vec3 normal_in;
layout(location = 2) flat in uint id_in;
layout(location = 3) in vec4 position_in;
layout(std140, binding = 0) uniform TriangleUniforms {
    mat4 M;
    mat4 MIT;
    int isInfinite;
};

void main(){
    if (isInfinite != 0 && inside_aabb(position_in) == 0) {
        discard;
    }

    vec3 normal = normal_in;
    vec3 color = color_in.rgb;
    float alpha = color_in.a;
    if (!gl_FrontFacing) {
        normal = -normal;
        color = vec3(1.0) - color;
    }

    if (isInfinite != 0) {
        float distanceFromEdge = distance_from_aabb_edge(position_in);
        if (distanceFromEdge <= 2.0) {
            float t = distanceFromEdge / 2.0;
            alpha *= t;
            if (visible_in_stripes(gl_FragCoord) == 0) {
                color = color * t + vec3(1.0) * (1.0 - t);
            }
            else {
                color = color * t + (color / 1.33) * (1.0 - t);
            }
        }
    }

    float diffuse = (max(dot(normal,light_cam()),0.0) * 0.3 + max(dot(normal,light_side()),0.0) * 0.7) * 0.8;
    float ambient = 0.2;
    vec4 color4 = vec4(color * (diffuse + ambient), alpha);

    WRITE_COLOR(color4, id_in, gl_FragCoord.z)
}
