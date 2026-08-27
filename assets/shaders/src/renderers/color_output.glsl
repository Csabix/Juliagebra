#ifndef COLOR_OUTPUT
#define COLOR_OUTPUT
#if defined(TRANSPARENT)
    #if defined(GL_ARB_fragment_shader_interlock)
        #extension GL_ARB_fragment_shader_interlock : enable
        layout(pixel_interlock_unordered) in;
    #else
        #undef TRANSPARENT
        #define TRANSPARENT_WEIGHTED_ONLY
    #endif
#endif
#extension GL_GOOGLE_include_directive : require
#include "../common_data.glsl"

#define AMBIENT 0.2
#define DIFFUSE 0.8
// The two directional light source
#define FRONT 0.2
#define SIDE 0.8

#if defined(TRANSPARENT)

coherent layout(std430, binding = 11) buffer PixelDataDistBuffer {
    uvec4 _distances_b[];
};
coherent layout(std430, binding = 12) buffer PixelDataColBuffer {
    uvec4 _colors_b[];
};

coherent layout(std430, binding = 13) buffer PixelDataBufferID {
    uvec2 _dist_ids[];
};

layout(location = 0) out vec4  _accum;
layout(location = 1) out float _reveal;

#elif defined(TRANSPARENT_WEIGHTED_ONLY)

layout(location = 0) out vec4  _accum;
layout(location = 1) out float _reveal;

#else

layout(location = 0) out vec4 _color_out;
layout(location = 1) out uint _id_out;

#endif

#if defined(TRANSPARENT)
layout(binding = 13) uniform sampler2D _depth_tex;

#define WRITE_COLOR(color, id, depth)                                           \
if (depth > texelFetch(_depth_tex, ivec2(gl_FragCoord.xy), 0).r) discard;       \
uint _pixelIdx = uint(gl_FragCoord.x) + uint(gl_FragCoord.y) * width_u();       \
uint _packedColor = packUnorm4x8(color);                                        \
                                                                                \
                                                                                \
beginInvocationInterlockARB();                                                  \
const float _dist_id_x = _dist_ids[_pixelIdx].x;                                \
if (_dist_id_x == uint(0) || _dist_id_x > floatBitsToUint(depth))               \
    _dist_ids[_pixelIdx] = uvec2(floatBitsToUint(depth), id);                   \
uvec4 distances = _distances_b[_pixelIdx];                                      \
uint max_idx;                                                                   \
uint max_dist = 0;                                                              \
for (uint i = 0; i < 4; ++i) {                                                  \
    if (distances[i] == 0) {                                                    \
        max_dist = distances[i];                                                \
        max_idx = i;                                                            \
        break;                                                                  \
    } else if (distances[i] > max_dist) {                                       \
        max_dist = distances[i];                                                \
        max_idx = i;                                                            \
    }                                                                           \
}                                                                               \
uint old_col = _colors_b[_pixelIdx][max_idx];                                   \
if (max_dist == 0 || floatBitsToUint(depth) < max_dist) {                       \
    distances[max_idx] = floatBitsToUint(depth);                                \
    _distances_b[_pixelIdx] = distances;                                        \
    _colors_b[_pixelIdx][max_idx] = _packedColor;                               \
}                                                                               \
if (floatBitsToUint(depth) < max_dist) {                                        \
    _packedColor = old_col;                                                     \
}                                                                               \
                                                                                \
                                                                                \
endInvocationInterlockARB();                                                    \
                                                                                \
if (uint(0) == max_dist) discard;                                               \
                                                                                \
float _d = uintBitsToFloat(max_dist) / 200;                                     \
float _d4 = _d * _d * _d * _d;                                                  \
                                                                                \
color = unpackUnorm4x8(_packedColor);                                           \
float _weight = max(max(max(color.r, color.g), color.b) * color.a, color.a) *   \
           clamp(0.03 / (1e-5 + _d4), 1e-2, 3e3);                               \
                                                                                \
_accum = vec4(color.rgb * color.a, color.a) * _weight;                          \
_reveal = color.a;

#elif defined(TRANSPARENT_WEIGHTED_ONLY)
layout(binding = 13) uniform sampler2D _depth_tex;

#define WRITE_COLOR(color, id, depth)                                           \
if (depth > texelFetch(_depth_tex, ivec2(gl_FragCoord.xy), 0).r) discard;       \
                                                                                \
float _d = depth / 200;                                                         \
float _d4 = _d * _d * _d * _d;                                                  \
                                                                                \
float _weight = max(max(max(color.r, color.g), color.b) * color.a, color.a) *   \
           clamp(0.03 / (1e-5 + _d4), 1e-2, 3e3);                               \
                                                                                \
_accum = vec4(color.rgb * color.a, color.a) * _weight;                          \
_reveal = color.a;

#else

#define WRITE_COLOR(color, id, depth) \
    _color_out = color; \
    _id_out = id;

#endif

#endif // COLOR_OUTPUT