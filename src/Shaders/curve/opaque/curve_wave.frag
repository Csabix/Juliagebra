#version 460
#define PI 3.1415926538

layout(location=0) out vec4 color_out;

noperspective layout(location=0) in vec4 segment_SDF_field_in;
noperspective layout(location=1) in vec3 color_in;
noperspective layout(location=2) in float total_distance_in;
flat          layout(location=3) in vec3 light_dir_cam_in;
flat          layout(location=4) in vec3 light_dir_side_in;


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
    d = max(d,distance(sin(total_distance_in / lenX) * 0.5 * lenX, p.x) - lenX * 0.5);

    float alpha = 1.0 - smoothstep(-1.0, 0.0, d);

    float val = mix(0.0,PI,(segment_SDF_field_in.x * 0.5 + 0.5 * lenX)/segment_SDF_field_in.z);
    vec3 normal = vec3(-cos(val),0,sin(val));

    float diffuse = (max(dot(normal,light_dir_cam_in),0.0) * 0.3 + max(dot(normal,light_dir_side_in),0.0) * 0.7) * 0.8;
    float ambient = 0.2;
    color_out = vec4(color_in * (diffuse + ambient), alpha);

    if (d > 0.0) discard;
}