const general_uniforms =
"<UNIFORMS>" =>
"""
layout(std140, binding = 0) uniform UBO_Buffer {
    mat4 VP;
    mat4 V;
    mat4 P;
    vec4 light_side;
    vec4 light_cam;
    vec4 eye;
    vec4 width_height_aspect_width_u;
}
float width()  { return width_height_aspect_width_u.x; }
float height() { return width_height_aspect_width_u.y; }
float aspect() { return width_height_aspect_width_u.z; }
uint width_u() { return floatBitsToUint(width_height_aspect_width_u.w); }
"""

const opaque_output =
"<OUTPUT>" =>
"""
layout(location = 0) out vec4 color_out;
layout(location = 1) out uint id_out;
"""

const transparent_output =
"<OUTPUT>" =>
"""
#extension GL_ARB_fragment_shader_interlock : require
layout(pixel_interlock_unordered) in;

struct PixelData {
    uvec2 dist_col[4];
    uvec2 dist_id;
};

coherent layout(std430, binding = 0) buffer PixelDataBuffer {
    PixelData data[];
};

layout(location = 0) out vec4 accum;
layout(location = 1) out float reveal;
"""

# require: vec4 color, uint id
const opaque_color_write =
"<WRITE>" =>
"""
color_out = color;
id_out = id;
"""

# require: vec4 color, uint id, float depth
const transparent_color_write =
"<WRITE>" =>
"""
uint pixelIdx = uint(gl_FragCoord.x) + uint(gl_FragCoord.y) * width;
uint packedColor = packUnorm4x8(color);

uint max_index;
uvec2 max_dist_col = uvec2(uint(0));

beginInvocationInterlockARB();
const float dist_id_x = data[pixelIdx].dist_id.x;
if (dist_id_x == uint(0) ||dist_id_x > floatBitsToUint(depth))
    data[pixelIdx].dist_id = uvec2(floatBitsToUint(depth),id);
for (uint i = 0; i < 4; ++i) {
    const uvec2 dist_col = data[pixelIdx].dist_col[i];
    if (uint(0) == dist_col.x) {
        max_dist_col = dist_col;
        max_index = i;
        break;
    } else if(dist_col.x > max_dist_col.x) {
        max_dist_col = dist_col;
        max_index = i;
    }
}

if (floatBitsToUint(depth) < max_dist_col.x || uint(0) == max_dist_col.x) {
    data[pixelIdx].dist_col[max_index] = uvec2(floatBitsToUint(depth), packedColor);
} else {
    max_dist_col = uvec2(floatBitsToUint(depth), packedColor);
}
    
endInvocationInterlockARB();

if (uint(0) == max_dist_col.x) discard;

color = unpackUnorm4x8(max_dist_col.y);

float _d = uintBitsToFloat(max_dist_col.x) / 200;
float _d4 = d*d*d*d;

float weight = max(max(max(color.r, color.g), color.b) * color.a, color.a) *
           clamp(0.03 / (1e-5 + _d4), 1e-2, 3e3);

accum = vec4(color.rgb * color.a, color.a) * weight;
reveal = color.a;
"""

# require: vec4 color, uint id, float depth
const transparent_weighted_blended_only_color_write =
"<WRITE>" =>
"""
uint pixelIdx = uint(gl_FragCoord.x) + uint(gl_FragCoord.y) * width;
uint packedColor = packUnorm4x8(color);

beginInvocationInterlockARB();
const float dist_id_x = data[pixelIdx].dist_id.x;
if (dist_id_x == uint(0) ||dist_id_x > floatBitsToUint(depth))
    data[pixelIdx].dist_id = uvec2(floatBitsToUint(depth),id);
endInvocationInterlockARB();

float _d = depth / 200;
float _d4 = d*d*d*d;

float weight = max(max(max(color.r, color.g), color.b) * color.a, color.a) *
           clamp(0.03 / (1e-5 + _d4), 1e-2, 3e3);

accum = vec4(color.rgb * color.a, color.a) * weight;
reveal = color.a;
"""

const OPAQUE = [opaque_output, opaque_color_write]
const TRANSPARENT = [transparent_output, transparent_color_write]