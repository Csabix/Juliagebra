#ifndef COLOR_OUTPUT
#define COLOR_OUTPUT
#if defined(TRANSPARENT)
#extension GL_ARB_fragment_shader_interlock : require
layout(pixel_interlock_unordered) in;
#endif
#extension GL_GOOGLE_include_directive : require
#include "../common_data.glsl"

#define AMBIENT 0.2
#define DIFFUSE 0.8
// The two directional light source
#define FRONT 0.2
#define SIDE 0.8

#if defined(TRANSPARENT)

struct PixelData {
    uvec2 dist_col[4];
    uvec2 dist_id;
};

coherent layout(std430, binding = 11) buffer PixelDataBuffer {
    PixelData _pixel_data[];
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
layout(binding = 12) uniform sampler2D _depth_tex;

#define WRITE_COLOR(color, id, depth)                                                           \
if (depth > texelFetch(_depth_tex, ivec2(gl_FragCoord.xy), 0).r) discard;                       \
uint _pixelIdx = uint(gl_FragCoord.x) + uint(gl_FragCoord.y) * width_u();                       \
uint _packedColor = packUnorm4x8(color);                                                        \
                                                                                                \
uint _max_index;                                                                                \
uvec2 _max_dist_col = uvec2(uint(0));                                                           \
                                                                                                \
beginInvocationInterlockARB();                                                                  \
const float _dist_id_x = _pixel_data[_pixelIdx].dist_id.x;                                      \
if (_dist_id_x == uint(0) || _dist_id_x > floatBitsToUint(depth))                               \
    _pixel_data[_pixelIdx].dist_id = uvec2(floatBitsToUint(depth),id);                          \
for (uint i = 0; i < 4; ++i) {                                                                  \
    const uvec2 _dist_col = _pixel_data[_pixelIdx].dist_col[i];                                 \
    if (uint(0) == _dist_col.x) {                                                               \
        _max_dist_col = _dist_col;                                                              \
        _max_index = i;                                                                         \
        break;                                                                                  \
    } else if(_dist_col.x > _max_dist_col.x) {                                                  \
        _max_dist_col = _dist_col;                                                              \
        _max_index = i;                                                                         \
    }                                                                                           \
}                                                                                               \
                                                                                                \
if (floatBitsToUint(depth) < _max_dist_col.x || uint(0) == _max_dist_col.x) {                   \
    _pixel_data[_pixelIdx].dist_col[_max_index] = uvec2(floatBitsToUint(depth), _packedColor);  \
} else {                                                                                        \
    _max_dist_col = uvec2(floatBitsToUint(depth), _packedColor);                                \
}                                                                                               \
                                                                                                \
endInvocationInterlockARB();                                                                    \
                                                                                                \
if (uint(0) == _max_dist_col.x) discard;                                                        \
                                                                                                \
float _d = uintBitsToFloat(_max_dist_col.x) / 200;                                              \
float _d4 = _d * _d * _d * _d;                                                                  \
                                                                                                \
color = unpackUnorm4x8(_max_dist_col.y);                                                        \
float _weight = max(max(max(color.r, color.g), color.b) * color.a, color.a) *                   \
           clamp(0.03 / (1e-5 + _d4), 1e-2, 3e3);                                               \
                                                                                                \
_accum = vec4(color.rgb * color.a, color.a) * _weight;                                          \
_reveal = color.a;

#elif defined(TRANSPARENT_WEIGHTED_ONLY)
layout(binding = 12) uniform sampler2D _depth_tex;

#define WRITE_COLOR(color, id, depth)                                                           \
if (depth > texelFetch(_depth_tex, ivec2(gl_FragCoord.xy), 0).r) discard;                       \
                                                                                                \
float _d = depth / 200;                                                                         \
float _d4 = _d * _d * _d * _d;                                                                  \
                                                                                                \
float _weight = max(max(max(color.r, color.g), color.b) * color.a, color.a) *                   \
           clamp(0.03 / (1e-5 + _d4), 1e-2, 3e3);                                               \
                                                                                                \
_accum = vec4(color.rgb * color.a, color.a) * _weight;                                          \
_reveal = color.a;

#else

#define WRITE_COLOR(color, id, depth) \
    _color_out = color; \
    _id_out = id;

#endif

#endif // COLOR_OUTPUT