#version 460 core
#extension GL_GOOGLE_include_directive : require
#include "../common_data.glsl"

struct Data {
    uvec2 dist_col[4];
    uvec2 dist_id;
};

restrict readonly layout(std430, binding = 11) buffer DatBuff {
    Data data[];
};

layout(location = 1) out uint id;

void main() {
    const uint pixelIdx = uint(gl_FragCoord.x) + uint(gl_FragCoord.y) * width_u();
    uvec2 dist_id = data[pixelIdx].dist_id;
    if (dist_id.x == uint(0)) discard;
    gl_FragDepth = uintBitsToFloat(dist_id.x);
    id = dist_id.y;
}