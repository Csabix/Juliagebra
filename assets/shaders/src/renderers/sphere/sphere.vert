#version 460 core
#extension GL_GOOGLE_include_directive : require
#include "../../common_data.glsl"

restrict readonly layout(std430, binding = 0) buffer CenterRadiusBuffer {
    vec4 center_radius_in[];
};
restrict readonly layout(std430, binding = 1) buffer ColorIdBuffer {
    uvec2 color_id_in[];
};

flat layout(location = 0) out vec4 color_out;
flat layout(location = 1) out uint id_out;
flat layout(location = 2) out vec3 center_out;
flat layout(location = 3) out float radius_out;

const vec2 quadOffsets[6] = vec2[6](
    vec2(-1.0, -1.0),
    vec2(+1.0, -1.0),
    vec2(-1.0, +1.0),

    vec2(+1.0, -1.0),
    vec2(-1.0, +1.0),
    vec2(+1.0, +1.0)
);

void main() {
    int index = gl_VertexID / 6;
    color_out = unpackUnorm4x8(color_id_in[index].x);
    id_out = color_id_in[index].y;

    vec3 center = center_radius_in[index].xyz;
    float radius = center_radius_in[index].w;
    vec2 base_offset = quadOffsets[gl_VertexID % 6];

    center_out = center;
    radius_out = radius;

    float dist = distance(eye(), center);
    if (dist < radius) {
        gl_Position = vec4(base_offset,0.0,1.0);
    } else {
        vec3 a = (eye() - center) / dist; 
        vec3 b = vec3(0.0, 0.0, 1.0);

        vec3 v = cross(a, b);
        float c = dot(a, b);
        float k = 1.0 / (1.0 + c);

        mat3 Rot = c > -0.9999 ? mat3(
            v.x * v.x * k + c,   v.y * v.x * k - v.z, v.z * v.x * k + v.y,
            v.x * v.y * k + v.z, v.y * v.y * k + c,   v.z * v.y * k - v.x,
            v.x * v.z * k - v.y, v.y * v.z * k + v.x, v.z * v.z * k + c
        ) : mat3(-1.0);

        vec3 surfaceCenter = center + a * radius;
        vec3 offset = Rot * vec3(base_offset,0.0) * radius;
        gl_Position = VP * vec4(surfaceCenter + offset, 1.0);
    }
}