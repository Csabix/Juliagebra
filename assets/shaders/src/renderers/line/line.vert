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

vec4  side_dist(vec4 p) { return vec4(p.x, -p.x, p.y, -p.y) + p.w; }
vec2 depth_dist(vec4 p) { return vec2(p.z, -p.z) + p.w; }

float max4(vec4 v) { return max(max(v.x, v.y), max(v.z, v.w)); }
float min4(vec4 v) { return min(min(v.x, v.y), min(v.z, v.w)); }
float max2(vec2 v) { return max(v.x, v.y); }
float min2(vec2 v) { return min(v.x, v.y); }

bool clip(inout vec4 B, inout vec4 color_distance_B, inout vec3 position_B,
          inout vec4 C, inout vec4 color_distance_C, inout vec3 position_C,
          inout vec4 A, inout vec4 D) {
    if (isnan(B.x) || isnan(C.x)) return false;

    vec4 sB = side_dist(B),  sC = side_dist(C);
    vec2 nB = depth_dist(B), nC = depth_dist(C);

    if (any(lessThan(min(sB, sC), vec4(0.0))) || any(lessThan(min(nB, nC), vec2(0.0)))) {// any < 0.0
        if (any(lessThan(max(sB, sC), vec4(0.0))) || any(lessThan(max(nB, nC), vec2(0.0)))) return false;// both < 0.0

        vec4  ds = sC - sB;
        vec4  ts = -sB / ds;
        float t0 = max(0.0, max4(mix(vec4(0.0), ts, greaterThan(ds, vec4(0.0)))));
        float t1 = min(1.0, min4(mix(vec4(1.0), ts, lessThan(   ds, vec4(0.0)))));

        vec2 dn = nC - nB;
        vec2 tn = -nB / dn;
        t0 = max(t0, max2(mix(vec2(0.0), tn, greaterThan(dn, vec2(0.0)))));
        t1 = min(t1, min2(mix(vec2(1.0), tn, lessThan(   dn, vec2(0.0)))));

        if (t0 >= t1) return false;

        vec4 B0 = B, C0 = C;
        B = mix(B0, C0, t0);
        C = mix(B0, C0, t1);

        vec4 cd_B0 = color_distance_B, cd_C0 = color_distance_C;
        color_distance_B = mix(cd_B0, cd_C0, t0);
        color_distance_C = mix(cd_B0, cd_C0, t1);

        vec3 p_B0 = position_B, p_C0 = position_C;
        position_B = mix(p_B0, p_C0, t0);
        position_C = mix(p_B0, p_C0, t1);

        vec2 nB0 = nB, nC0 = nC;
        nB = mix(nB0, nC0, t0);
        nC = mix(nB0, nC0, t1);

        if (t0 > 0.0) A = C;
        if (t1 < 1.0) D = B;
    }

    vec2  hA = vec2(depth_dist(A).x, A.w);
    vec2  eA = vec2(nB.x, B.w) - hA;
    vec2  tA = -hA / eA;
    float uA = max(max(0.0, eA.x > 0.0 ? tA.x : 0.0), eA.y > 0.0 ? tA.y : 0.0);
    if (uA > 0.0) A = mix(A, B, uA);

    vec2  hD = vec2(depth_dist(D).x, D.w);
    vec2  eD = vec2(nC.x, C.w) - hD;
    vec2  tD = -hD / eD;
    float uD = max(max(0.0, eD.x > 0.0 ? tD.x : 0.0), eD.y > 0.0 ? tD.y : 0.0);
    if (uD > 0.0) D = mix(D, C, uD);
    return true;
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

    if (!clip(B4,color_distance_B,position_B,
              C4,color_distance_C,position_C,
              A4,D4)) {
        gl_Position = vec4(0.0 / 0.0);
        return;
    }

    color_out = index < 2 ? color_distance_B.xyz : color_distance_C.xyz;
    float radius_conversion = 2.0 / P[0][0] * width_pixel / width();
    begin_pos_rad_out = vec4(position_B, B4.w * radius_conversion);
    end_pos_rad_out   = vec4(position_C, C4.w * radius_conversion);
    total_distance_out = color_distance_B.w;
    
    A4 /= A4.w;
    B4 /= B4.w;
    C4 /= C4.w;
    D4 /= D4.w;

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

    const vec2 WH = vec2(width(), height());
    A = fma(A, vec2(0.5), vec2(0.5)) * WH;
    B = fma(B, vec2(0.5), vec2(0.5)) * WH;
    C = fma(C, vec2(0.5), vec2(0.5)) * WH;

    A = any(isnan(A)) ? C : A;

    float l_AB = distance(A, B);
    float l_CB = distance(B, C);

    vec2 dir_AB = (A - B) / l_AB;
    vec2 dir_BC = (B - C) / l_CB;

    vec2 dir_AB_r = vec2(dir_AB.y, -dir_AB.x);
    vec2 dir_BC_r = vec2(dir_BC.y, -dir_BC.x);

    float d = dot(dir_AB, dir_BC);
    vec2 inner;
    {
        vec2 r_ab = dir_AB_r * (dot(dir_AB_r, dir_BC) >= 0.0 ? -1.0 : 1.0);
        vec2 r_bc = dir_BC_r * (dot(dir_BC_r, dir_AB) < 0.0 ? -1.0 : 1.0);
        float dd = dot(r_ab, r_bc);
        inner = dd <= -0.9999 ? r_ab : (r_ab + r_bc) / (1.0 + dd);
    }

    vec2 right_offset = d <= -0.9999 ? dir_AB_r : (dir_AB_r + dir_BC_r) / (1.0 + dot(dir_AB_r, dir_BC_r));
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
    
    vec2 offset = dot(dir_AB, dir_BC) >= 0 ? obtuse_offset : (overlap ? overlap_offset : no_overlap_offset);
    float sdf = dot(offset, index < 2 ? dir_BC : -dir_BC) * -width_pixel;
    sdf += index < 2 ? 0.0 : l_CB;
    total_distance_out = REVERSED * (total_distance_out + sdf);
    vec2 length_conversion = 2.0 / WH * width_pixel;
    gl_Position.xy = fma(length_conversion, offset, gl_Position.xy);

    segment_SDF_field_out.x = index == 4 ? (dot(offset, dir_BC_r) * width_pixel) : (index % 2 == 0 ? width_pixel : -width_pixel);
    segment_SDF_field_out.y = sdf;
    segment_SDF_field_out.zw = vec2(width_pixel, l_CB);
}
