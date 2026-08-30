#version 460 core
#extension GL_GOOGLE_include_directive : require
#include "../../common_data.glsl"

layout(constant_id = 0) const float REVERSED = 1.0;

restrict readonly layout(std430, binding = 0) buffer DistanceBufferIn {
    float in_distances[];
};
restrict readonly layout(std430, binding = 1) buffer ColorTypeBufferIn {
    uint in_color_types[];
};
restrict readonly layout(std430, binding = 2) buffer PositionWidthBufferIn {
    vec4 in_position_widths[];
};

noperspective layout(location = 0) out vec4 segment_SDF_field_out;
noperspective layout(location = 1) out vec3 color_out;
noperspective layout(location = 2) out float total_distance_out;
flat          layout(location = 3) out vec4 begin_pos_rad_out;
flat          layout(location = 4) out vec4 end_pos_rad_out;
flat          layout(location = 5) out int dis;

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

void clip(  inout vec4 B, inout vec4 color_dist_B, inout vec3 position_B,
            inout vec4 C, inout vec4 color_dist_C, inout vec3 position_C,
            inout vec4 A, inout vec4 D) {
    for (int p = 0; p < 5; ++p) {
        float dB = get_plane_dist(B, p);
        float dC = get_plane_dist(C, p);
        if (dB < 0.0 && dC < 0.0) {
            B = vec4(0.0 / 0.0);
            C = vec4(0.0 / 0.0);
            break;
        } else if (dB < 0.0) {
            float t = dB / (dB - dC);
            B = mix(B, C, t);
            color_dist_B = mix(color_dist_B,color_dist_C,t);
            position_B = mix(position_B,position_C,t);
            A = vec4(0.0 / 0.0);
        } else if (dC < 0.0) {
            float t = dC / (dC - dB);
            C = mix(C, B, t);
            color_dist_C = mix(color_dist_C,color_dist_B,t);
            position_C = mix(position_C,position_B,t);
            D = vec4(0.0 / 0.0);
        }
    }
    if (!isnan(B.x) && !isnan(C.x)) {
        for (int p = 0; p < 5; ++p) {
            float dA = get_plane_dist(A, p);
            float dB = get_plane_dist(B, p);
            if (dA < 0.0 && dB >= 0.0) {
                A = mix(A, B, dA / (dA - dB));
            }

            float dD = get_plane_dist(D, p);
            float dC = get_plane_dist(C, p);
            if (dD < 0.0 && dC >= 0.0) {
                D = mix(D, C, dD / (dD - dC));
            }
        }
    }
}

bool calc_overlap(vec2 dir_AB, float d, vec2 v, float l_AB, float l_CB, float line_width) {
    if (d <= -0.9996) return true;
    if (d >= 0.9996) return false;

    float cos_abc = abs(dot(dir_AB, v));
    float sin_abc = inversesqrt(max(0.0, 1.0 - cos_abc * cos_abc));
    float l = line_width * cos_abc * sin_abc;
    return l > l_AB || l > l_CB;
}

void main() {
    dis = 0;
    const uint i = uint(gl_BaseInstance + gl_InstanceID);
    const uint index = uint(gl_VertexID);

    if (i + 3u >= in_position_widths.length()) {
        gl_Position = vec4(0.0 / 0.0);
        return;
    }

    vec4 A4 = vec4(in_position_widths[i   ].xyz, 1.0);
    vec4 B4 = vec4(in_position_widths[i+1u].xyz, 1.0);
    const float width_pixel = in_position_widths[i+1u].w;
    vec4 C4 = vec4(in_position_widths[i+2u].xyz, 1.0);
    vec4 D4 = vec4(in_position_widths[i+3u].xyz, 1.0);

    vec4 color_distance_B = vec4(unpackUnorm4x8(in_color_types[i+1u]).xyz,in_distances[i+1u]);
    vec4 color_distance_C = vec4(unpackUnorm4x8(in_color_types[i+2u]).xyz,in_distances[i+2u]);
    vec3 position_B = B4.xyz;
    vec3 position_C = C4.xyz;

    A4 = VP * A4;
    B4 = VP * B4;
    C4 = VP * C4;
    D4 = VP * D4;

    clip(B4,color_distance_B,position_B,
         C4,color_distance_C,position_C,
         A4,D4);

    color_out = index < 2 ? color_distance_B.xyz : color_distance_C.xyz;
    float radius_conversion = 2.0 / P[0][0] * width_pixel / width();
    begin_pos_rad_out = vec4(position_B, B4.w * radius_conversion);
    end_pos_rad_out   = vec4(position_C, C4.w * radius_conversion);
    total_distance_out = color_distance_B.w;
    

    A4 /= A4.w;
    B4 /= B4.w;
    C4 /= C4.w;
    D4 /= D4.w;

    //A4 = C4;
    //D4 = (B4+C4)/2;

    

    vec2 A; vec2 B; vec2 C;
    if (index < 2) {
        A = A4.xy;
        B = B4.xy;
        C = C4.xy;
        gl_Position = vec4(B4.xyz,1.0);
    } else {
        A = D4.xy;
        B = C4.xy;
        C = B4.xy;
        gl_Position = vec4(C4.xyz,1.0);
    }

    if (isnan(A.x)) A = C;
    //if (gl_InstanceID == 0) dis = 1;

    const vec2 WH = vec2(width(), height());
    A = fma(A, vec2(0.5), vec2(0.5)) * WH;
    B = fma(B, vec2(0.5), vec2(0.5)) * WH;
    C = fma(C, vec2(0.5), vec2(0.5)) * WH;

    float l_AB = distance(A, B);
    float l_CB = distance(B, C);

    vec2 dir_AB = (A - B) / l_AB;
    vec2 dir_BC = (B - C) / l_CB;

    vec2 dir_AB_r = vec2(dir_AB.y, -dir_AB.x);
    vec2 dir_BC_r = vec2(dir_BC.y, -dir_BC.x);

    // endcap
    if (index == 0) color_out = vec3(1,0,0);
    if (index == 1) color_out = vec3(0,1,0);
    if (index == 2) color_out = vec3(0,0,1);
    if (index == 3) color_out = vec3(0,0,0);
    if (index == 4) color_out = vec3(1,1,1);
    // if (any(isnan(A))) {
    //     color_out = vec3(1,0,1);
    //     //dis = 1;
    //     vec2 offset;
    //     if (index == 0) offset =  dir_BC + dir_BC_r;
    //     if (index == 1) offset =  dir_BC - dir_BC_r;
    //     if (index == 2) offset = -dir_BC + dir_BC_r;
    //     if (index == 3) offset = -dir_BC - dir_BC_r;
    //     float sdf = dot(offset, dir_BC) * width_pixel;
    //     vec2 length_conversion = 2.0 / WH * width_pixel;
    //     gl_Position.xy = fma(length_conversion, offset, gl_Position.xy);
    //     total_distance_out = REVERSED * (total_distance_out + sdf);

    //     segment_SDF_field_out.x = index == 4 ? (dot(offset, dir_BC_r) * width_pixel) : (index % 2 == 0 ? width_pixel : -width_pixel);
    //     segment_SDF_field_out.y = sdf;
    //     segment_SDF_field_out.zw = vec2(width_pixel, l_CB);
    //     return;
    // }

    float d = dot(dir_AB, dir_BC);
    vec2 inner;
    {
        vec2 r_ab = dir_AB_r * (dot(dir_AB_r, dir_BC) >= 0.0 ? -1.0 : 1.0);
        vec2 r_bc = dir_BC_r * (dot(dir_BC_r, dir_AB) < 0.0 ? -1.0 : 1.0);
        inner = abs(d) > 0.9996 ? r_ab : (r_ab + r_bc) / (1.0 + dot(r_ab, r_bc));
    }

    vec2 right_offset = abs(d) > 0.9999 ? dir_AB_r : (dir_AB_r + dir_BC_r) / (1.0 + dot(dir_AB_r, dir_BC_r));
    vec2 v = normalize(inner);
    bool overlap = calc_overlap(dir_AB, d, v, l_AB, l_CB, width_pixel);

    v *= (dot(right_offset, inner) <= 0.0 ? -1.0 : 1.0);
    float cos_half = clamp(dot(dir_BC_r, v), -1.0, 1.0);
    float t = sqrt(max(0.0, 1.0 - cos_half) / (1.0 + cos_half));

    vec2 perp_base = index < 4 ? dir_BC_r : dir_AB_r;
    vec2 perpendicular = (dot(right_offset, inner) >= 0.0 ? -1.0 : 1.0) * perp_base;
    vec2 parallel  = index < 4 ? dir_BC   : -dir_AB;

    vec2 no_overlap_offset;
    {
        vec2 a = perpendicular + t * parallel;
        vec2 b = index == 4 ? a : inner;
        if (index > 1 ^^ index % 2 == 0) {
            vec2 tmp = a;
            a = b;
            b = tmp;
        }
        no_overlap_offset = dot(right_offset, inner) >= 0.0 ? a : b;
    }

    float s_12 = (index == 1 || index == 2) ? -1.0 : 1.0;
    vec2 overlap_offset = dir_BC + s_12 * dir_BC_r;
    vec2 obtuse_offset  = s_12 * right_offset;
    
    vec2 offset = d >= 0 ? obtuse_offset : (overlap ? overlap_offset : no_overlap_offset);
    float sdf = overlap ? 0.0 : dot(offset, dir_BC) * width_pixel;
    sdf += index < 2 ? 0.0 : l_CB;

    vec2 length_conversion = 2.0 / WH * width_pixel;
    //if (index >= 3) dis = 1;
    gl_Position.xy = fma(length_conversion, offset, gl_Position.xy);
    total_distance_out = REVERSED * (total_distance_out + sdf);

    segment_SDF_field_out.x = index == 4 ? (dot(offset, dir_BC_r) * width_pixel) : (index % 2 == 0 ? width_pixel : -width_pixel);
    segment_SDF_field_out.y = sdf;
    segment_SDF_field_out.zw = vec2(width_pixel, l_CB);
}