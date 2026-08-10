#ifndef TRIANGLE_COMMON
#define TRIANGLE_COMMON

layout(std140, binding = 0) uniform TriangleUniforms {
    mat4 M;
    mat4 MIT;
    int isInfinite;
};

#endif