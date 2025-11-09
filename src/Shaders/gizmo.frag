#version 330 core

noperspective in vec4 segment_SDF_field_g_out; // x,y,lenX,lenY; x in [0,lenX] y in [0,lenY]
flat          in vec3 color_g_out;
flat          in uint id_g_out;

layout(location = 0) out vec4 color_out;
layout(location = 1) out uint id_out;

float sdCapsule( vec2 p, float r, float h ) {
    p.x = abs(p.x);
    if( p.y < 0.0 ) return length(p) - r;
    if( p.y > h ) return length(p-vec2(0.0,h)) - r;
    return p.x - r;
}

void main() {
    float d = sdCapsule(segment_SDF_field_g_out.xy, segment_SDF_field_g_out.z, segment_SDF_field_g_out.w);

    float alpha = 1.0-smoothstep(-0.85,0.0,d);
    color_out = vec4(color_g_out,alpha);
    id_out = id_g_out;

    if (d > 0.0) discard;
}