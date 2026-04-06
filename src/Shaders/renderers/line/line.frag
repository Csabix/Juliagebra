#version 460 core
#ifdef TRANSPARENT
#extension GL_ARB_fragment_shader_interlock : require

layout(pixel_interlock_unordered) in;
layout(early_fragment_tests) in;
#endif
#define PI 3.1415926538

#define AMBIENT 0.2
#define DIFFUSE 0.8
// The two directional light source
#define FRONT 0.2
#define SIDE 0.8

#ifdef TRANSPARENT
struct PixelData {
    uvec2 dist_col[4];
    uvec2 dist_id;
};

coherent layout(std430, binding = 0) buffer PixelDataBuffer {
    PixelData data[];
};

layout(location = 0) out vec4 accum;
layout(location = 1) out float reveal;
#define DISCARD alpha > 0.7

layout(location = 0) uniform uint width;

#else
layout(location = 0) out vec4 color_out;
layout(location = 1) out uint id_out;
#define DISCARD alpha <= 0.7
#endif

noperspective layout(location = 0) in vec4 segment_SDF_field_in;
noperspective layout(location = 1) in vec3 color_in;
noperspective layout(location = 2) in float total_distance_in;
flat          layout(location = 3) in vec3 light_dir_cam_in;
flat          layout(location = 4) in vec3 light_dir_side_in;

float rounding() {
    vec2 p = vec2(abs(segment_SDF_field_in.x),segment_SDF_field_in.y);
    if( p.y < 0.0 ) return length(p) - segment_SDF_field_in.z;
    if( p.y > segment_SDF_field_in.w ) return length(p-vec2(0.0,segment_SDF_field_in.w)) - segment_SDF_field_in.z;
    return p.x - segment_SDF_field_in.z;
}

vec3 get_normal() {
    float val = mix(0.0,PI,(segment_SDF_field_in.x * 0.5 + 0.5 * segment_SDF_field_in.z)/segment_SDF_field_in.z);
    return vec3(-cos(val),0,sin(val));
}

vec4 get_color(in vec3 normal, in float alpha) {
    float diffuse = (max(dot(normal,light_dir_cam_in),0.0) * 0.3 + max(dot(normal,light_dir_side_in),0.0) * 0.7) * 0.8;
    float ambient = 0.2;
    return vec4(color_in * (diffuse + ambient), alpha);
}

float sdCircle( vec2 p, float r ) {
    return length(p) - r;
}

#if defined(SOLID)
float pattern() {
    return abs(segment_SDF_field_in.x) - segment_SDF_field_in.z;
}
#elif defined(DASHED)
float pattern() {
    const float lenX = segment_SDF_field_in.z;
    float d = abs(segment_SDF_field_in.x) - lenX;
    const float width = lenX * 5.0;
    return max(d, abs(2.0 * mod(total_distance_in + lenX, width) - width) - lenX * 4.0);
}
#elif defined(DOTTED)
float pattern() {
    const float lenX = segment_SDF_field_in.z;
    return sdCircle(vec2(segment_SDF_field_in.x, mod(total_distance_in,lenX * 3.0) - lenX), lenX);
}
#elif defined(WAVE)
float pattern() {
    const float lenX = segment_SDF_field_in.z;
    return distance(sin(total_distance_in / lenX) * 0.5 * lenX, segment_SDF_field_in.x) - lenX * 0.5;
}
#elif defined(DASH_DOT)
float pattern() {
    const float lenX = segment_SDF_field_in.z;
    float d = abs(segment_SDF_field_in.x) - lenX;
    d = max(d, abs(mod(total_distance_in,lenX * 8.0) * 2.0 - lenX * 8.0) - lenX * 4.0);
    return min(d, sdCircle(vec2(segment_SDF_field_in.x, mod(total_distance_in + lenX * 3.0,lenX * 8.0) - 3.0 * lenX), lenX));
}
#elif defined(ARROW)
float sdEquilateralTriangle( in vec2 p, in float r ) {
    const float k = sqrt(3.0);
    p.x = abs(p.x) - r;
    p.y = p.y + r/k;
    if( p.x+k*p.y>0.0 ) p = vec2(p.x-k*p.y,-k*p.x-p.y)/2.0;
    p.x -= clamp( p.x, -2.0*r, 0.0 );
    return -length(p)*sign(p.y);
}

float pattern() {
    const float lenX = segment_SDF_field_in.z;
    float d = abs(segment_SDF_field_in.x) - lenX * 0.3;
    d = max(d, abs(mod(total_distance_in + lenX,lenX * 8.0) * 2.0 - lenX * 8.0) - lenX * 6.0);
    d = min(d, sdEquilateralTriangle(vec2(segment_SDF_field_in.x,mod(total_distance_in + lenX * 4.0, lenX * 8.0) - 2 * lenX), lenX));
    return d;
}
#endif

#ifdef TRANSPARENT
float pow4(float val) {
    return val * val * val * val;
}
#endif

void main() {
    float d = pattern();
    float alpha = 1.0 - smoothstep(max(-0.4*segment_SDF_field_in.z,-4.0), 0.0, d);
    alpha = alpha >= 0.9 ? 1.0 : alpha;
    d = max(d, rounding());

    if (d > 0.0) discard;

    vec4 color = get_color(get_normal(), alpha);
#ifdef TRANSPARENT
    uint pixelIdx = uint(gl_FragCoord.x) + uint(gl_FragCoord.y) * width;
    uint packedColor = packUnorm4x8(color);

    uint max_index;
    uvec2 max_dist_col = uvec2(uint(0));

    beginInvocationInterlockARB();
    const float dist_id_x = data[pixelIdx].dist_id.x;
    if (dist_id_x == uint(0) ||dist_id_x > floatBitsToUint(gl_FragCoord.z))
        data[pixelIdx].dist_id = uvec2(floatBitsToUint(gl_FragCoord.z),uint(0));
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

    if (floatBitsToUint(gl_FragCoord.z) < max_dist_col.x || uint(0) == max_dist_col.x) {
        data[pixelIdx].dist_col[max_index] = uvec2(floatBitsToUint(gl_FragCoord.z), packedColor);
    } else {
        max_dist_col = uvec2(floatBitsToUint(gl_FragCoord.z), packedColor);
    }
    
    endInvocationInterlockARB();

    if (uint(0) == max_dist_col.x) discard;

    color = unpackUnorm4x8(max_dist_col.y);
    float weight = max(max(max(color.r, color.g), color.b) * color.a, color.a) *
               clamp(0.03 / (1e-5 + pow4(uintBitsToFloat(max_dist_col.x) / 200)), 1e-2, 3e3);

    accum = vec4(color.rgb * color.a, color.a) * weight;
    reveal = color.a;
#else
    color_out = color;
    id_out = 0;
#endif
}