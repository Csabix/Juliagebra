#version 460 core

struct Data {
    uvec2 dist_col[4];
    uvec2 dist_id;
};

layout(std430, binding = 0) buffer DatBuff {
    Data data[];
};

layout (location = 1) out uint id;

layout(location = 0) uniform uint width;

void main() {
    const uint pixelIdx = uint(gl_FragCoord.x) + uint(gl_FragCoord.y) * width;
    uvec2 dist_id = data[pixelIdx].dist_id;
    if (dist_id.x = uint(0)) discard;
    gl_FragDepth = uintBitsToFloat(dist_id.x);
    id = dist_id.y
}