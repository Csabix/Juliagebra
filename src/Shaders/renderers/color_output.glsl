#ifndef COLOR_OUTPUT
#define COLOR_OUTPUT

#include "../ubo.glsl"

#define PLUS_WIDTH 0.08
#define AMBIENT 0.2
#define DIFFUSE 0.8
// The two directional light source
#define FRONT 0.2
#define SIDE 0.8

#if defined(TRANSPARENT) || defined (TRANSPARENT_WEIGHTED_ONLY)
#extension GL_ARB_fragment_shader_interlock : require
layout(pixel_interlock_unordered) in;

struct PixelData {
    uvec2 dist_col[4];
    uvec2 dist_id;
};

coherent layout(std430, binding = 0) buffer PixelDataBuffer {
    PixelData _pixel_data[];
};

layout(location = 0) out vec4  _accum;
layout(location = 1) out float _reveal;

#else

layout(location = 0) out vec4 _color_out;
layout(location = 1) out uint _id_out;

#endif

#if defined(TRANSPARENT)

#define WRITE_COLOR(color, id, depth)

#elif defined(TRANSPARENT_WEIGHTED_ONLY)

#define WRITE_COLOR(color, id, depth)                                           \
uint _pixelIdx = uint(gl_FragCoord.x) + uint(gl_FragCoord.y) * width_u();       \
uint _packedColor = packUnorm4x8(color);                                        \
                                                                                \
beginInvocationInterlockARB();                                                  \
const float _dist_id_x = _pixel_data[pixelIdx].dist_id.x;                       \
if (_dist_id_x == uint(0) || _dist_id_x > floatBitsToUint(depth))               \
    _pixel_data[pixelIdx].dist_id = uvec2(floatBitsToUint(depth),id);           \
endInvocationInterlockARB();                                                    \
                                                                                \
float _d = depth / 200;                                                         \
float _d4 = _d*_d*_d*_d;                                                        \
                                                                                \
float _weight = max(max(max(color.r, color.g), color.b) * color.a, color.a) *   \
           clamp(0.03 / (1e-5 + _d4), 1e-2, 3e3);                               \
                                                                                \
_accum = vec4(color.rgb * color.a, color.a) * _weight;                          \
_reveal = color.a;                                                              \

#else

#define WRITE_COLOR(color, id, depth) \
    _color_out = color; \
    _id_out = id;

#endif

#endif // COLOR_OUTPUT