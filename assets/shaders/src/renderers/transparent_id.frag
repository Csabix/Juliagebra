#version 460 core
#extension GL_GOOGLE_include_directive : require
#include "../common_data.glsl"

restrict layout(std430, binding = 13) buffer PixelDataBufferID {
    uvec2 _dist_ids[];
};

layout(location = 1) out uint id;

void main() {
    const uint pixelIdx = uint(gl_FragCoord.x) + uint(gl_FragCoord.y) * width_u();
    uvec2 dist_id = _dist_ids[pixelIdx];
    if (dist_id.x == uint(0)) discard;
    _dist_ids[pixelIdx] = uvec2(0);
    gl_FragDepth = uintBitsToFloat(dist_id.x);
    id = dist_id.y;
}