#version 460
#define PI 3.1415926538

layout(location=0) out vec4 color_out;
layout(location=1) out uint index_out;

noperspective layout(location=0) in vec4 segment_SDF_field_in;
noperspective layout(location=1) in vec3 color_in;
flat          layout(location=2) in uint type_in;
noperspective layout(location=3) in float total_distance_in;
flat          layout(location=4) in vec3 LIGHT_DIR;


float sdCapsule( vec2 p, float r, float h ) {
    p.x = abs(p.x);
    if( p.y < 0.0 ) return length(p) - r;
    if( p.y > h ) return length(p-vec2(0.0,h)) - r;
    return p.x - r;
}

void main() {
    vec2 p = segment_SDF_field_in.xy;
    float lenX = segment_SDF_field_in.z;
    float lenY = segment_SDF_field_in.w;
    float d = sdCapsule(p,lenX,lenY);
    d = max(d,mod(total_distance_in,lenX * 5.0) - lenX * 4.0);

    float alpha = 1.0 - smoothstep(max(-0.2*lenX,-2.0), 0.0, d);

    float val = mix(0.0,PI,(segment_SDF_field_in.x * 0.5 + 0.5 * lenX)/segment_SDF_field_in.z);
    vec3 n = vec3(-cos(val),0,sin(val));

    color_out = vec4( color_in*(max(0.0,dot(n,LIGHT_DIR))*0.70+0.30), alpha);
    index_out = uint(0);
    if (d > 0.0) discard;
}