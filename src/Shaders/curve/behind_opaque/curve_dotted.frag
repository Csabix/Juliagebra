#version 460
#define PI 3.1415926538

layout(location=0) out vec4 color_out;

noperspective layout(location=0) in vec4 segment_SDF_field_in;
noperspective layout(location=1) in vec3 color_in;
noperspective layout(location=2) in float total_distance_in;


float sdCapsule( vec2 p, float r, float h ) {
    p.x = abs(p.x);
    if( p.y < 0.0 ) return length(p) - r;
    if( p.y > h ) return length(p-vec2(0.0,h)) - r;
    return p.x - r;
}

float sdCircle( vec2 p, float r ) {
    return length(p) - r;
}

void main() {
    vec2 p = segment_SDF_field_in.xy;
    float lenX = segment_SDF_field_in.z;
    float lenY = segment_SDF_field_in.w;
    float d = sdCapsule(p,lenX,lenY);
    d = max(d,sdCircle(vec2(p.x, mod(total_distance_in,lenX * 6.0) - lenX), lenX));

    color_out = vec4(color_in * 0.8, 1.0);

    if (d > 0.0) discard;
}