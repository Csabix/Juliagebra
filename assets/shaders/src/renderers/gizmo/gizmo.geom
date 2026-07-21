#version 460 core
#extension GL_GOOGLE_include_directive : require
#include "../../common_data.glsl"

layout (lines) in;
layout (triangle_strip, max_vertices = 4) out;

layout(location = 0) flat in vec3 color_v_out[];
layout(location = 1) flat in uint id_v_out[];

layout(location = 0) noperspective out vec4 segment_SDF_field_g_out; // x,y,lenX,lenY; x in [-lenX,lenX] y in [0,lenY]
layout(location = 1) flat          out vec3 color_g_out;
layout(location = 2) flat          out uint id_g_out;

layout(constant_id = 0) const bool CORNER_GIZMO = false;
layout(constant_id = 1) const float CONTENT_SCALE = 1.0;
layout(std140, binding = 0) uniform Gizmo_UBO_Axis {
    vec4 center_axis;
};
layout(std140, binding = 1) uniform Gizmo_UBO_Size {
    float gizmo_length;
    float gizmo_thickness;
};

void main() {
    float WIDTH = 5.5 * CONTENT_SCALE;
    if (!CORNER_GIZMO) {
        WIDTH *= gizmo_thickness;
    }
    color_g_out = color_v_out[0];
    id_g_out    = id_v_out[0];

    vec4 A4 = gl_in[0].gl_Position;
    vec4 B4 = gl_in[1].gl_Position;

    float t0 = A4.z + A4.w;
    float t1 = B4.z + B4.w;
    if(t0 < 0.0){
        if(t1 < 0.0) return;
        A4 = mix(A4, B4, (0 - t0) / (t1 - t0));
    } if(t1 < 0.0){
        B4 = mix(B4, A4, (0 - t1) / (t0 - t1));
    }

    A4 /= A4.w;
    B4 /= B4.w;

    vec2 WH = resolution();
    vec2 A = (A4.xy * 0.5 + 0.5) * WH;
    vec2 B = (B4.xy * 0.5 + 0.5) * WH;


    float segment_len = length(B - A);
    vec2 AB_dir = normalize(B - A);
    vec2 AB_N = vec2(-AB_dir.y, AB_dir.x);

    float len_X = WIDTH + WIDTH;
    float len_Y = segment_len + WIDTH + WIDTH;


    vec2 length_conversion = 2.0 / WH * WIDTH;
    AB_dir *= length_conversion;
    AB_N *= length_conversion;

    segment_SDF_field_g_out = vec4(len_X,len_Y,len_X,segment_len);
    gl_Position = vec4(A4.xy - AB_dir + AB_N, -1.0, 1.0);
    EmitVertex();

    segment_SDF_field_g_out.x = -len_X;
    gl_Position = vec4(A4.xy - AB_dir - AB_N, -1.0, 1.0);
    EmitVertex();

    segment_SDF_field_g_out.xy = vec2(len_X,0);
    gl_Position = vec4(B4.xy + AB_N, -1.0, 1.0);
    EmitVertex();

    segment_SDF_field_g_out.x = -len_X;
    gl_Position = vec4(B4.xy - AB_N, -1.0, 1.0);
    EmitVertex();

    EndPrimitive();
}