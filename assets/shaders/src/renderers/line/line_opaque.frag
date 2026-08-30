#version 460 core
#extension GL_GOOGLE_include_directive : require
#include "../color_output.glsl"
#include "./line_helpers.glsl" 

noperspective layout(location = 0) in vec4 segment_SDF_field_in;
noperspective layout(location = 1) in vec3 color_in;
noperspective layout(location = 2) in float total_distance_in;
flat          layout(location = 3) in vec4 begin_pos_rad_in;
flat          layout(location = 4) in vec4 end_pos_rad_in;
flat          layout(location = 5) in int dis;

void main() {
    //if (dis == 1) discard;
    //WRITE_COLOR(vec4(vec3(1.0),1.0), 0, 0)
    //return;
    //vec2 p = vec2(abs(segment_SDF_field_in.x),segment_SDF_field_in.y);
    //float pp;
    //if( p.y < 0.0 ) pp = length(p) - segment_SDF_field_in.z;
    //else if( p.y > segment_SDF_field_in.w ) pp = length(p-vec2(0.0,segment_SDF_field_in.w)) - segment_SDF_field_in.z;
    //else pp = p.x - segment_SDF_field_in.z;
    //WRITE_COLOR(vec4(vec3(pp > 0.0 ? 1.0 : 0.0),1.0), 0, 0)
    WRITE_COLOR(vec4(vec3(abs(segment_SDF_field_in.y)/10.),1.0), 0, 0)
    //WRITE_COLOR(vec4(vec3(total_distance_in/1000.0),1.0), 0, 0)
    //return;

    float d = pattern(segment_SDF_field_in, total_distance_in);
    float alpha = 1.0 - smoothstep(max(-0.4*segment_SDF_field_in.z,-4.0), 0.0, d);
    alpha = alpha >= 0.9 ? 1.0 : alpha;

    if (d > 0.0 || OPAQUE_DISCRAD) discard;

    vec4 normal_depth = get_normal_depth(begin_pos_rad_in,end_pos_rad_in);
    gl_FragDepth = normal_depth.w;

    vec4 color = get_color(vec4(color_in,alpha), normal_depth.xyz);
    WRITE_COLOR(color, 0, normal_depth.w)
    //WRITE_COLOR(vec4(vec3(segment_SDF_field_in.y)/100.0,1.0), 0, 0)
}