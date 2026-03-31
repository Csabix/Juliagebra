#version 460 core
#define PI 3.1415926538

#define AMBIENT 0.2
#define DIFFUSE 0.8
// The two directional light source
#define FRONT 0.2
#define SIDE 0.8

layout(location = 0) out vec4 color_out;
layout(location = 1) out uint id_out;

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

void main() {
    float d = pattern();
    d = max(d, rounding());
    float alpha = 1.0 - smoothstep(max(-0.2*segment_SDF_field_in.z,-2.0), 0.0, d);

    if (d > 0.0 /*|| alpha <= 0.9*/) discard;

    vec4 color = get_color(get_normal(), alpha);
#ifdef TRANSPARENCY
    const uint zero_float = floatBitsToUint(0.0);
    uint pixelIdx = uint(gl_FragCoord.x) + uint(gl_FragCoord.y) * width;
    uint packedColor = packUnorm4x8(color);
#else
    color_out = color;
    id_out = 0;
#endif
}