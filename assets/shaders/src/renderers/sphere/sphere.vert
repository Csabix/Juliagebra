#version 460 core
#extension GL_GOOGLE_include_directive : require
#include "../../common_data.glsl"

layout(constant_id = 0) const float near = 1.0;
layout(constant_id = 1) const uint opaque = 1;

restrict readonly layout(std430, binding = 0) buffer CenterRadiusBuffer {
    vec4 center_radius_in[];
};
restrict readonly layout(std430, binding = 1) buffer ColorBuffer {
    uint color_in[];
};
restrict readonly layout(std430, binding = 2) buffer IdBuffer {
    uint id_in[];
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
    color_out = unpackUnorm4x8(color_in[index]);
    id_out = id_in[index];

    vec3 center = center_radius_in[index].xyz;
    float radius = center_radius_in[index].w;
    vec2 base_offset = quadOffsets[gl_VertexID % 6];

    center_out = center;
    radius_out = radius;

    float dist = distance(eye(), center);
    vec4 position;
    if (isOrtho()) {
        vec4 viewPos = V * vec4(center, 1.0);
        viewPos.xy += base_offset * radius;
        viewPos.z -= radius;
        position = P * viewPos;
    } else if (dist < radius) {
        position = vec4(base_offset, 0.0, 1.0) * near;
    } else {
        vec3 camUp = vec3(V[0][1], V[1][1], V[2][1]);
        vec3 forward = normalize(eye() - center);
        vec3 right = normalize(cross(camUp, forward));
        vec3 up = cross(forward, right);

        vec3 surfaceCenter = center + forward * radius;
        vec3 offset = (right * base_offset.x + up * base_offset.y) * radius;
        position = VP * vec4(surfaceCenter + offset, 1.0);
    }

    float f;
    if (opaque == uint(1)) f = color_out.a == 1.0 ? 1.0 : 1.0/0.0;
    else f = color_out.a != 1.0 ? 1.0 : 1.0/0.0;
    // Multiply position with NaN if we draw opaque but transparent color is given and vice versa.
    gl_Position = position * f;
}