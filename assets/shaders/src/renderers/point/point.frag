#version 460 core
#extension GL_GOOGLE_include_directive : require
#include "../color_output.glsl"
layout (depth_greater) out float gl_FragDepth;
#define PI 3.1415926538
#define PLUS_WIDTH 0.08

layout(constant_id = 0) const bool OPAQUE_BEHIND = false;

layout(location = 0) flat in vec3 color_in;
layout(location = 1) flat in vec3 color_inv_in;
layout(location = 2) flat in uint type_id_in;
layout(location = 3) flat in float radius_in;
layout(location = 4) flat in float z_view_in;
layout(location = 5) flat in vec3 view_side_light_in;

uint plusNorm() {
    vec2 dist = abs(gl_PointCoord - vec2(0.5));
    return uint(dist.x < PLUS_WIDTH) | uint(dist.y < PLUS_WIDTH);
}

float light(vec3 normal, vec3 direction) {
    return max(0.0, dot(normal, direction));
}

void main() {
    vec2 coord = gl_PointCoord * 2.0 - 1.0;
    float r2 = dot(coord, coord);
    if (r2 > 1.0) discard;

    float ring_alpha = 1.0;
    if (OPAQUE_BEHIND) {
        ring_alpha = smoothstep(0.75, 0.82, sqrt(r2));
        if (ring_alpha < 0.01) discard;
    }

    const uint id = type_id_in & ~(uint(255) << 24);
    uint type = (type_id_in & (uint(255) << 24)) >> 24;

    uint inside_pattern;
    switch(type) {
        case 0: inside_pattern = uint(0); break;
        case 1: inside_pattern = plusNorm(); break;
        default: inside_pattern = uint(0); break;
    }

    vec3 col = ((inside_pattern & uint(r2 < 0.5)) == 0) ? color_in : color_inv_in;

    vec2 angle = gl_PointCoord * PI;
    vec2 sin_vu = sin(angle);
    vec2 cos_vu = cos(angle);
    vec3 normal = -vec3(sin_vu.x * cos_vu.y, cos_vu.x, sin_vu.x * sin_vu.y);

    float diffuse = (light(normal, vec3(0, 0, -1.0)) * FRONT + light(normal, view_side_light_in) * SIDE) * DIFFUSE;
    
    vec4 color;
    if (OPAQUE_BEHIND) {
        color = vec4(col * AMBIENT, ring_alpha * 0.5);
    } else {
        color = vec4(col * (diffuse + AMBIENT), 1.0);
    }

    float z_offset = sqrt(1.0 - r2);
    float sphere_pos_z = z_offset * radius_in + z_view_in;

    float clip_z = sphere_pos_z * P[2][2] + P[3][2];
    float clip_w = sphere_pos_z * P[2][3] + P[3][3];

    float ndc_z = clip_z / clip_w;
    
    gl_FragDepth = (ndc_z + 1.0) / 2.0;

    WRITE_COLOR(color,id,(ndc_z + 1.0) / 2.0)
}