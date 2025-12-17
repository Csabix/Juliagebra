#version 460
#define PI 3.1415926538

layout(location=0) out vec4 color_out;

noperspective layout(location=0) in vec4 segment_SDF_field_in;
noperspective layout(location=1) in vec3 color_in;
flat          layout(location=2) in uint type_in;
noperspective layout(location=3) in float total_distance_in;
flat          layout(location=4) in vec3 light_dir_cam_in;
flat          layout(location=5) in vec3 light_dir_side_in;


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

    float val = mix(0.0,PI,(segment_SDF_field_in.x * 0.5 + 0.5 * lenX)/segment_SDF_field_in.z);
    vec3 normal = vec3(-cos(val),0,sin(val));

    float diffuse = (max(dot(normal,light_dir_cam_in),0.0) * 0.3 + max(dot(normal,light_dir_side_in),0.0) * 0.7) * 0.8;
    float ambient = 0.2;
    color_out = vec4(vec3(1.0), 0.5);
    if (d > 0.0) discard;
}