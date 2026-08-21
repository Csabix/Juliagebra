#version 460 core
#extension GL_GOOGLE_include_directive : require
#include "../color_output.glsl"
#include "./line_helpers.glsl"

noperspective layout(location = 0) in vec4 segment_SDF_field_in;
noperspective layout(location = 1) in vec3 color_in;
noperspective layout(location = 2) in float total_distance_in;
flat          layout(location = 3) in vec4 begin_pos_rad_in;
flat          layout(location = 4) in vec4 end_pos_rad_in;
flat          layout(location = 5) in uint style_in;

void main() {
    float d = pattern(segment_SDF_field_in, total_distance_in, style_in);
    float alpha = 1.0 - smoothstep(max(-0.4*segment_SDF_field_in.z,-4.0), 0.0, d);
    alpha = alpha >= 0.9 ? 1.0 : alpha;

    if (d > 0.0 || OPAQUE_DISCRAD) discard;

    vec4 normal_depth = get_normal_depth(begin_pos_rad_in,end_pos_rad_in);
    gl_FragDepth = normal_depth.w;

    vec4 color = get_color(vec4(color_in,alpha), normal_depth.xyz);
    WRITE_COLOR(color, 0, normal_depth.w)
}