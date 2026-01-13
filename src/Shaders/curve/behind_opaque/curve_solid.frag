#version 460

layout(location=0) out vec4 color_out;

noperspective layout(location=0) in vec4 segment_SDF_field_in;
noperspective layout(location=1) in vec3 color_in;
noperspective layout(location=2) in float total_distance_in;

float rounding() {
    vec2 p = vec2(abs(segment_SDF_field_in.x),segment_SDF_field_in.y);
    if( p.y < 0.0 ) return length(p) - segment_SDF_field_in.z;
    if( p.y > segment_SDF_field_in.w ) return length(p-vec2(0.0,segment_SDF_field_in.w)) - segment_SDF_field_in.z;
    return p.x - segment_SDF_field_in.z;
}

float pattern() {
    const float lenX = segment_SDF_field_in.z;
    float d = abs(segment_SDF_field_in.x) - segment_SDF_field_in.z;
    return max(d, mod(total_distance_in + lenX,lenX * 5.0) - lenX * 4.0);
}

void main() {
    float d = pattern();
    float alpha = 1.0 - smoothstep(max(-0.2*segment_SDF_field_in.z,-2.0), 0.0, d);
    d = max(d, rounding());

    if (d > 0.0 || alpha <= 0.9) discard;

    color_out = vec4(color_in * 0.8, 1.0);
}