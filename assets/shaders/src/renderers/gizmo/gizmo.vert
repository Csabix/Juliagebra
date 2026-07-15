#version 460 core
#extension GL_GOOGLE_include_directive : require
#include "../../common_data.glsl"

layout(constant_id = 0) const bool CORNER_GIZMO = false;
layout(constant_id = 1) const float CONTENT_SCALE = 1.0;
layout(std140, binding = 0) uniform Gizmo_UBO_Axis {
    vec4 center_axis;
};
layout(std140, binding = 1) uniform Gizmo_UBO_Size {
    float gizmo_length;
    float gizmo_thickness;
};

const vec3 vertices[6] = vec3[6](vec3(1,0,0),vec3(-1,0,0),vec3(0,1,0),vec3(0,-1,0),vec3(0,0,1),vec3(0,0,-1));
const uint ids[3] = uint[3](uint(1),uint(2),uint(3));
const uint axes[3] = uint[3](uint(1),uint(2),uint(4));
uint indices[6] = uint[6](uint(0),uint(1),uint(2),uint(3),uint(4),uint(5));

layout(location = 0) flat out vec3 color_v_out;
layout(location = 1) flat out uint id_v_out;

void main(){
    const float gizmoPixelLength = 100.0 * CONTENT_SCALE;
    const float padding = 20 * CONTENT_SCALE;

    float z_values[6];
    vec3 gizmoCenter;
    vec4 centerClip;
    float gizmoScale;
    if (CORNER_GIZMO) {
        for (int i = 0; i < 6; ++i) {
            vec4 rotated = V * vec4(vertices[i], 0.0);
            z_values[i] = -rotated.z;
        }
    } else {
        gizmoCenter = center_axis.xyz;
        centerClip = VP * vec4(gizmoCenter, 1.0);
        gizmoScale = (centerClip.w / P[0][0]) * (gizmoPixelLength * gizmo_length / width());
        
        for (int i = 0; i < 6; ++i) {
            vec4 proj_point = VP * vec4(vertices[i] * gizmoScale + gizmoCenter, 1.0); 
            z_values[i] = proj_point.z / proj_point.w;
        }
    }

    for (int i = 5; i > 0; --i) {
        for (int j = 0; j < i; ++j) {
            if (z_values[j] < z_values[j + 1]) {
                float tmp_depth = z_values[j];
                z_values[j] = z_values[j + 1];
                z_values[j + 1] = tmp_depth;

                uint tmp_index = indices[j];
                indices[j] = indices[j + 1];
                indices[j + 1] = tmp_index;
            }
        }
    }

    uint current_index = indices[gl_VertexID / 2];
    color_v_out = abs(vertices[current_index]);
    vec3 offset = gl_VertexID % 2 == 0 ? vertices[current_index] : vec3(0);
    if (!CORNER_GIZMO) {
        id_v_out = ids[current_index >> 1];
        uint gizmo_axis = floatBitsToUint(center_axis.w);
        if ((axes[current_index >> 1] & gizmo_axis) == uint(0)) {
            offset = vec3(0.0/0.0);
        }
    }
    
    if (CORNER_GIZMO) {
        vec2 ndcOffset = 2.0 * (gizmoPixelLength * vec2(0.5) + vec2(padding)) / vec2(width(),height());
        vec3 fixedCenterNDC = vec3(1.0 - ndcOffset.x, 1.0 - ndcOffset.y, 0.0);
        vec2 scaleToNDC = vec2(gizmoPixelLength / width(), gizmoPixelLength / height());
        
        vec4 rotatedOffset = V * vec4(offset, 0.0);
        vec2 finalNDCOffset = rotatedOffset.xy * scaleToNDC;

        gl_Position = vec4(fixedCenterNDC.xy + finalNDCOffset, -1.0, 1.0);
    } else {
        gl_Position = VP * vec4(offset * gizmoScale + gizmoCenter, 1.0);
    }
}