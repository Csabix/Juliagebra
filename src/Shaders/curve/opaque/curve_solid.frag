#version 460
#define PI 3.1415926538

layout(location=0) out vec4 color_out;

noperspective layout(location=0) in vec4 segment_SDF_field_in;
noperspective layout(location=1) in vec3 color_in;
noperspective layout(location=2) in float total_distance_in;
flat          layout(location=3) in vec3 light_dir_cam_in;
flat          layout(location=4) in vec3 light_dir_side_in;

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

float pattern() {
    return abs(segment_SDF_field_in.x) - segment_SDF_field_in.z;
}

void main() {
    float d = pattern();
    float alpha = 1.0 - smoothstep(max(-0.2*segment_SDF_field_in.z,-2.0), 0.0, d);
    d = max(d, rounding());

    if (d > 0.0 || alpha <= 0.9) discard;

    vec3 normal = get_normal();
    color_out = get_color(normal, alpha);
}