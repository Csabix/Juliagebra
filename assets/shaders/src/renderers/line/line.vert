#version 460 core
#extension GL_GOOGLE_include_directive : require
#include "../../common_data.glsl"

layout(constant_id = 0) const float REVERSED = 1.0;

// Input SSBOs
restrict readonly layout(std430, binding = 0) buffer DistanceBufferIn {
    float in_distances[];
};
restrict readonly layout(std430, binding = 1) buffer ColorTypeBufferIn {
    uint in_color_types[];
};
restrict readonly layout(std430, binding = 2) buffer PositionWidthBufferIn {
    vec4 in_position_widths[];
};

// Outputs to Fragment Shader
noperspective layout(location = 0) out vec4 segment_SDF_field_out;
noperspective layout(location = 1) out vec3 color_out;
noperspective layout(location = 2) out float total_distance_out;
flat          layout(location = 3) out vec4 begin_pos_rad_out;
flat          layout(location = 4) out vec4 end_pos_rad_out;

vec2 OctWrap(vec2 v) {
    return (1.0 - abs(v)) * sign(v);
}

vec2 Encode(vec3 n) {
    n /= dot(abs(n), vec3(1.0));
    n.xy = n.z >= 0.0 ? n.xy : OctWrap(n.xy);
    n.xy = n.xy * 0.5 + 0.5;
    return n.xy;
}

float get_plane_dist(vec4 p, int plane_idx) {
    switch (plane_idx) {
        case 0: return p.z + p.w; // Near plane  (z >= -w)
        case 1: return p.x + p.w; // Left plane  (x >= -w)
        case 2: return p.w - p.x; // Right plane (x <= w)
        case 3: return p.y + p.w; // Bottom plane(y >= -w)
        case 4: return p.w - p.y; // Top plane   (y <= w)
    }
    return 0.0;
}

void main() {
    const uint i = uint(gl_BaseInstance + gl_InstanceID);
    const uint vert_idx = uint(gl_VertexID);

    if (i + 3u >= in_position_widths.length()) {
        gl_Position = vec4(0.0 / 0.0);
        return;
    }

    vec4 A4 = vec4(in_position_widths[i   ].xyz, 1.0);
    vec4 B4 = vec4(in_position_widths[i+1u].xyz, 1.0);
    const float width_pixel = in_position_widths[i+1u].w;
    vec4 C4 = vec4(in_position_widths[i+2u].xyz, 1.0);
    vec4 D4 = vec4(in_position_widths[i+3u].xyz, 1.0);

    const vec3 begin_pos_world = B4.xyz;
    const vec3 end_pos_world   = C4.xyz;

    A4 = VP * A4;
    B4 = VP * B4;
    C4 = VP * C4;
    D4 = VP * D4;

    float radius_conversion = 2.0 / P[0][0] * width_pixel / width();
    begin_pos_rad_out = vec4(begin_pos_world, B4.w * radius_conversion);
    end_pos_rad_out   = vec4(end_pos_world,   C4.w * radius_conversion);

    // Clipping
    if (B4.z + B4.w < 0.0 && C4.z + C4.w < 0.0) {
        B4 = vec4(0.0 / 0.0);
        C4 = vec4(0.0 / 0.0);
    }

    vec3 color_B = unpackUnorm4x8(in_color_types[i+1u]).xyz;
    vec3 color_C = unpackUnorm4x8(in_color_types[i+2u]).xyz;
    float distace_B = in_distances[i+1u];
    float distace_C = in_distances[i+2u];

    for (int p = 0; p < 5; ++p) {
        float dB = get_plane_dist(B4, p);
        float dC = get_plane_dist(C4, p);

        if (dB < 0.0 && dC < 0.0) {
            B4 = vec4(0.0 / 0.0);
            C4 = vec4(0.0 / 0.0);
            break;
        } else if (dB < 0.0) {
            float alpha = dB / (dB - dC);
            B4 = mix(B4, C4, alpha);
            distace_B = mix(distace_B, distace_C, alpha);
            color_B = mix(color_B, color_C, alpha);
            A4 = vec4(0.0 / 0.0);
        } else if (dC < 0.0) {
            float alpha = dC / (dC - dB);
            C4 = mix(C4, B4, alpha);
            distace_C = mix(distace_C, distace_B, alpha);
            color_C = mix(color_C, color_B, alpha);
            D4 = vec4(0.0 / 0.0);
        }
    }

    if (!isnan(B4.x) && !isnan(C4.x)) {
        for (int p = 0; p < 5; ++p) {
            float dB = get_plane_dist(B4, p);
            float dA = get_plane_dist(A4, p);
            if (dA < 0.0 && dB >= 0.0) {
                A4 = mix(A4, B4, dA / (dA - dB));
            }

            float dC = get_plane_dist(C4, p);
            float dD = get_plane_dist(D4, p);
            if (dD < 0.0 && dC >= 0.0) {
                D4 = mix(D4, C4, dD / (dD - dC));
            }
        }
    }

    A4.xyz /= A4.w;
    B4.xyz /= B4.w;
    C4.xyz /= C4.w;
    D4.xyz /= D4.w;

    const vec2 WH = vec2(width(), height());
    vec2 A = fma(A4.xy, vec2(0.5), vec2(0.5)) * WH;
    vec2 B = fma(B4.xy, vec2(0.5), vec2(0.5)) * WH;
    vec2 C = fma(C4.xy, vec2(0.5), vec2(0.5)) * WH;
    vec2 D = fma(D4.xy, vec2(0.5), vec2(0.5)) * WH;

    float l_AB = distance(A, B);
    float l_CB = distance(C, B);
    float l_DC = distance(C, D);

    vec2 dir_AB = (A - B) / l_AB;
    vec2 dir_CB = (C - B) / l_CB;
    vec2 dir_BC = -dir_CB;
    vec2 dir_DC = (D - C) / l_DC;

    vec2 dir_r_AB = vec2( dir_AB.y, -dir_AB.x);
    vec2 dir_r_CB = vec2(-dir_CB.y,  dir_CB.x);
    vec2 dir_r_BC = vec2( dir_BC.y, -dir_BC.x);
    vec2 dir_r_DC = vec2(-dir_DC.y,  dir_DC.x);

    vec2 inner_offset_ABC;
    {
        vec2 dir_AB_r = dot(dir_r_AB, dir_CB) < 0.0 ? -dir_r_AB : dir_r_AB;
        vec2 dir_BC_r = dot(dir_r_BC, dir_AB) < 0.0 ? -dir_r_BC : dir_r_BC;
        inner_offset_ABC = abs(dot(dir_AB, dir_BC)) >= 0.9999 ? dir_BC_r : (dir_AB_r + dir_BC_r) / (1.0 + dot(dir_AB_r, dir_BC_r));
    }
    vec2 inner_offset_BCD;
    {
        vec2 dir_CB_r = dot(dir_r_CB, dir_DC) < 0.0 ? -dir_r_CB : dir_r_CB;
        vec2 dir_DC_r = dot(dir_r_DC, dir_BC) < 0.0 ? -dir_r_DC : dir_r_DC;
        inner_offset_BCD = abs(dot(dir_CB, dir_DC)) >= 0.9999 ? dir_DC_r : (dir_CB_r + dir_DC_r) / (1.0 + dot(dir_CB_r, dir_DC_r));
    }

    vec2 right_offset_ABC = abs(dot(dir_AB, dir_BC)) > 0.9999 ? dir_r_AB : (dir_r_AB + dir_r_BC) / (1.0 + dot(dir_r_AB, dir_r_BC));
    vec2 right_offset_BCD = abs(dot(dir_CB, dir_DC)) > 0.9999 ? dir_r_DC : (dir_r_CB + dir_r_DC) / (1.0 + dot(dir_r_CB, dir_r_DC));

    vec2 dir_ABC = normalize(inner_offset_ABC);
    float d_dot_ABC = dot(dir_AB, dir_BC);
    bool overlap_ABC;
    if (d_dot_ABC <= -0.9999) {
        overlap_ABC = true;
    } else if (d_dot_ABC >= 0.9999) {
        overlap_ABC = false;
    } else {
        float cos_ABC = abs(dot(dir_AB, dir_ABC));
        float l_ABC = width_pixel * cos_ABC * inversesqrt(1.0 - cos_ABC * cos_ABC);
        overlap_ABC = l_ABC > l_AB || l_ABC > l_CB;
    }

    vec2 dir_BCD = normalize(inner_offset_BCD);
    float d_dot_BCD = dot(dir_DC, dir_CB);
    bool overlap_BCD;
    if (d_dot_BCD <= -0.9999) {
        overlap_BCD = true;
    } else if (d_dot_BCD >= 0.9999) {
        overlap_BCD = false;
    } else {
        float cos_BCD = abs(dot(dir_DC, dir_BCD));
        float l_BCD = width_pixel * cos_BCD * inversesqrt(1.0 - cos_BCD * cos_BCD);
        overlap_BCD = l_BCD > l_DC || l_BCD > l_CB;
    }

    vec2 begin_right_offset = -dir_CB + dir_r_CB;
    vec2 begin_left_offset  = -dir_CB - dir_r_CB;
    vec2 end_right_offset   =  dir_CB + dir_r_CB;
    vec2 end_left_offset    =  dir_CB - dir_r_CB;
    vec2 end_third_offset   = vec2(1.0 / 0.0);

    vec2 sdf_begin = vec2(-width_pixel);
    vec3 sdf_end = vec3(l_CB + width_pixel);
    float third_sdf_side = 1.0 / 0.0;

    if (!any(isnan(A)) && l_CB > 1.0) {
        if (dot(dir_AB, dir_BC) >= 0.0) {
            begin_right_offset =  right_offset_ABC;
            begin_left_offset  = -right_offset_ABC;
        } else {
            if (!overlap_ABC) {
                if (dot(right_offset_ABC, inner_offset_ABC) > 0.0) {
                    float cos_half = clamp(dot(dir_r_BC, dir_ABC), -1.0, 1.0);
                    float t = cos_half >= 1.0 ? 0.0 : sqrt((1.0 - cos_half) / (1.0 + cos_half));
                    begin_right_offset = inner_offset_ABC;
                    begin_left_offset = -dir_r_CB + t * dir_CB;
                } else {
                    float cos_half = clamp(dot(dir_r_BC, -dir_ABC), -1.0, 1.0);
                    float t = cos_half >= 1.0 ? 0.0 : sqrt((1.0 - cos_half) / (1.0 + cos_half));
                    begin_left_offset = inner_offset_ABC;
                    begin_right_offset = dir_r_BC + t * dir_BC;
                }
            }
        }
        sdf_begin = vec2(dot(begin_right_offset, dir_CB), dot(begin_left_offset, dir_CB)) * width_pixel;
    }

    if (!any(isnan(D))) {
        if (dot(dir_DC, dir_CB) >= 0.0) {
            end_right_offset =  right_offset_BCD;
            end_left_offset  = -right_offset_BCD;
        } else {
            if (!overlap_BCD) {
                if (dot(right_offset_BCD, inner_offset_BCD) > 0.0) {
                    end_right_offset = inner_offset_BCD;
                    {
                        float cos_half = clamp(dot(dir_r_BC, dir_BCD), -1.0, 1.0);
                        float t = cos_half >= 1.0 ? 0.0 : sqrt((1.0 - cos_half) / (1.0 + cos_half));
                        end_left_offset = -dir_r_CB + t * dir_CB;
                    }
                    {
                        float cos_half = clamp(dot(dir_r_BC, dir_BCD), -1.0, 1.0);
                        float t = cos_half >= 1.0 ? 0.0 : sqrt((1.0 - cos_half) / (1.0 + cos_half));
                        end_third_offset = -dir_r_DC - t * dir_DC;
                    }
                } else {
                    end_left_offset = inner_offset_BCD;
                    {
                        float cos_half = clamp(dot(dir_r_BC, -dir_BCD), -1.0, 1.0);
                        float t = cos_half >= 1.0 ? 0.0 : sqrt((1.0 - cos_half) / (1.0 + cos_half));
                        end_right_offset = dir_r_CB + t * dir_CB;
                    }
                    {
                        float cos_half = clamp(dot(dir_r_BC, -dir_BCD), -1.0, 1.0);
                        float t = cos_half >= 1.0 ? 0.0 : sqrt((1.0 - cos_half) / (1.0 + cos_half));
                        end_third_offset = dir_r_DC - t * dir_DC;
                    }
                }
            }
        }
        third_sdf_side = dot(end_third_offset, dir_r_CB) * width_pixel;
        sdf_end = vec3(dot(end_right_offset, dir_CB), dot(end_left_offset, dir_CB), dot(end_third_offset, dir_CB)) * width_pixel;
        sdf_end += l_CB;
    }

    vec2 length_conversion = 2.0 / WH * width_pixel;

    // Select vertex-specific output based on gl_VertexID [0..4]
    vec2 pos_offset;
    vec2 base_pos;
    float base_z;
    float sdf_begin_end_x;

    if (vert_idx == 0u) {
        pos_offset      = begin_right_offset;
        base_pos        = B4.xy;
        base_z          = B4.z;
        sdf_begin_end_x = sdf_begin.x;
        color_out       = color_B;
        segment_SDF_field_out = vec4(width_pixel, sdf_begin.x, width_pixel, l_CB);
    } else if (vert_idx == 1u) {
        pos_offset      = begin_left_offset;
        base_pos        = B4.xy;
        base_z          = B4.z;
        sdf_begin_end_x = sdf_begin.y;
        color_out       = color_B;
        segment_SDF_field_out = vec4(-width_pixel, sdf_begin.y, width_pixel, l_CB);
    } else if (vert_idx == 2u) {
        pos_offset      = end_right_offset;
        base_pos        = C4.xy;
        base_z          = C4.z;
        sdf_begin_end_x = sdf_end.x;
        color_out       = color_C;
        segment_SDF_field_out = vec4(width_pixel, sdf_end.x, width_pixel, l_CB);
    } else if (vert_idx == 3u) {
        pos_offset      = end_left_offset;
        base_pos        = C4.xy;
        base_z          = C4.z;
        sdf_begin_end_x = sdf_end.y;
        color_out       = color_C;
        segment_SDF_field_out = vec4(-width_pixel, sdf_end.y, width_pixel, l_CB);
    } else { // vert_idx == 4u
        pos_offset      = end_third_offset;
        base_pos        = C4.xy;
        base_z          = C4.z;
        sdf_begin_end_x = sdf_end.z;
        color_out       = color_C;
        segment_SDF_field_out = vec4(third_sdf_side, sdf_end.z, width_pixel, l_CB);
    }

    vec2 pos_xy = fma(length_conversion, pos_offset, base_pos);
    gl_Position = vec4(pos_xy, base_z, 1.0);
    total_distance_out = REVERSED * (distace_B + sdf_begin_end_x);
}