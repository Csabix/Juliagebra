#ifndef LINE_HELPERS
#define LINE_HELPERS
#extension GL_GOOGLE_include_directive : require
#define RAY
#include "../../common_data.glsl"
#include "../color_output.glsl"

#define OPAQUE_DISCRAD alpha <= 0.7
#define TRANSPARENT_DISCARD alpha > 0.7

vec4 get_color(in vec4 color, in vec3 normal) {
    float diffuse = (max(dot(normal,light_cam()),0.0) * FRONT + max(dot(normal,light_side()),0.0) * SIDE) * DIFFUSE;
    float ambient = AMBIENT;
    return vec4(color.rgb * (diffuse + ambient), color.a);
}

float iSphere(vec3 ro, vec3 rd, vec3 sp, float r) {
    vec3 oc = ro - sp;
    float b = dot(oc, rd);
    float c = dot(oc, oc) - r * r;
    float h = sqrt(b * b - c);
    float t = -b - h;
    if (t < 0.0) t = -b + h;
    return t > 0.0 ? t : -10000.0;
}

float iUnevenCapsule(vec3 ro, vec3 rd, vec3 pa, vec3 pb, float ra, float rb, out vec3 normal) {
    float t = 10000.0;
    t = min(t, iSphere(ro, rd, pa, ra));
    t = min(t, iSphere(ro, rd, pb, rb));
    
    vec3 ba = pb - pa;
    float l = length(ba);
    
    if (l > 1e-5) {
        vec3 v = ba / l;
        vec3 oc = ro - pa;
        float y0 = dot(oc, v);
        float dy = dot(rd, v);
        
        vec3 w0 = oc - y0 * v;
        vec3 wd = rd - dy * v;
        
        float dr = (rb - ra) / l;
        float r0 = ra + y0 * dr;
        float rd_r = dy * dr;
        
        float A = dot(wd, wd) - rd_r * rd_r;
        float B = dot(w0, wd) - r0 * rd_r;
        float C = dot(w0, w0) - r0 * r0;
        
        float h = B * B - A * C;
        if (h >= 0.0) {
            h = sqrt(h);
            float t3 = -1.0;
            if (abs(A) > 1e-6) {
                float ta = (-B - h) / A;
                float tb = (-B + h) / A;
                if (ta > 0.0 && tb > 0.0) t = min(ta, tb);
                else if (ta > 0.0) t = ta;
                else if (tb > 0.0) t = tb;
            } else if (abs(B) > 1e-6) {
                t3 = -0.5 * C / B;
            }
            
            if (t3 > 0.0) {
                float y = y0 + t3 * dy;
                if(y >= 0.0 && y <= l) {
                    t = min(t,t3);
                }
            }
        }
    }
    
    if (t >= 10000.0) return -1.0;

    if (l > 1e-5) {
        vec3 pt = ro + t * rd;
        vec3 v = ba / l;
        float y = dot(pt - pa, v);
        vec3 proj = pa + y * v;
        vec3 radVec = normalize(pt - proj);
        
        float dr = (rb - ra) / l;
        float hyp = sqrt(1.0 + dr * dr);
        float s = dr / hyp;
        float c_factor = 1.0 / hyp;
        
        normal = radVec * c_factor - v * s;
    } else {
        normal = normalize((ro + t * rd) - pa);
    }
    
    return t;
}

vec4 get_normal_depth(vec4 pos_rad_begin, vec4 pos_rad_end) {
    vec3 ro = rayOrigin();
    vec3 rd = rayDirection();
    
    vec3 pa = pos_rad_begin.xyz;
    float ra = pos_rad_begin.w;
    vec3 pb = pos_rad_end.xyz;
    float rb = pos_rad_end.w;

    vec3 normal;
    float t = iUnevenCapsule(ro, rd, pa, pb, ra, rb, normal);
    if (t < 0.0) discard;

    vec4 p = vec4(fma(rd,vec3(t),eye()), 1.0);
    float zc = dot(vec4(VP[0].z, VP[1].z, VP[2].z, VP[3].z), p);
    float wc = dot(vec4(VP[0].w, VP[1].w, VP[2].w, VP[3].w), p);
    float depth = fma((zc / wc),0.5,0.5);

    return vec4(normal,depth);
}

layout(constant_id = 0) const int PATTERN_GROUP = 0; // 0 OPAQUE 1, 1 BEHIND OPAQUE
layout(constant_id = 1) const int PATTERN_TYPE = 0;  // 0: SOLID, 1: DASHED, 2: DOTTED, 3: WAVE, 4: DASH_DOT, 5: ARROW

float sdCircle(vec2 p, float r) {
    return length(p) - r;
}

float sdEquilateralTriangle(in vec2 p, in float r) {
    const float k = sqrt(3.0);
    p.x = abs(p.x) - r;
    p.y = p.y + r/k;
    if(p.x + k * p.y > 0.0) p = vec2(p.x - k * p.y, -k * p.x - p.y) / 2.0;
    p.x -= clamp(p.x, -2.0 * r, 0.0);
    return -length(p) * sign(p.y);
}

float rounding(vec4 segment_SDF) {
    vec2 p = vec2(abs(segment_SDF.x),segment_SDF.y);
    if( p.y < 0.0 ) return length(p) - segment_SDF.z;
    if( p.y > segment_SDF.w ) return length(p-vec2(0.0,segment_SDF.w)) - segment_SDF.z;
    return p.x - segment_SDF.z;
}

float pattern(vec4 segment_SDF,float total_distance) {
    const float lenX = segment_SDF.z;
    float result;
    // OPAQUE
    if (PATTERN_GROUP == 0) {
        switch(PATTERN_TYPE) {
            case 0: // SOLID
                result = abs(segment_SDF.x) - lenX;
                break;
            case 1: // DASHED
                float d1 = abs(segment_SDF.x) - lenX;
                float width1 = lenX * 5.0;
                result = max(d1, abs(2.0 * mod(total_distance + lenX, width1) - width1) - lenX * 4.0);
                break;
            case 2: // DOTTED
                result = sdCircle(vec2(segment_SDF.x, mod(total_distance, lenX * 3.0) - lenX), lenX);
                break;
            case 3: // WAVE
                result = distance(sin(total_distance / lenX) * 0.5 * lenX, segment_SDF.x) - lenX * 0.5;
                break;
            case 4: // DASH_DOT
                float dd = abs(segment_SDF.x) - lenX;
                dd = max(dd, abs(mod(total_distance, lenX * 8.0) * 2.0 - lenX * 8.0) - lenX * 4.0);
                result = min(dd, sdCircle(vec2(segment_SDF.x, mod(total_distance + lenX * 3.0, lenX * 8.0) - 3.0 * lenX), lenX));
                break;
            case 5: // ARROW
                float da = abs(segment_SDF.x) - lenX * 0.3;
                da = max(da, abs(mod(total_distance + lenX, lenX * 8.0) * 2.0 - lenX * 8.0) - lenX * 6.0);
                result = min(da, sdEquilateralTriangle(vec2(segment_SDF.x, mod(total_distance + lenX * 4.0, lenX * 8.0) - 2.0 * lenX), lenX));
                break;
        }
    } else { // BEHIND OPAQUE
        switch(PATTERN_TYPE) {
            case 0: // SOLID
                float d2 = abs(segment_SDF.x) - lenX;
                result = max(d2, mod(total_distance + lenX, lenX * 5.0) - lenX * 4.0);
                break;
            case 1: // DASHED
                float d3 = abs(segment_SDF.x) - lenX;
                result = max(d3, abs(2.0 * mod(total_distance + lenX, lenX * 10.0) - lenX * 5.0) - lenX * 4.0);
                break;
            case 2: // DOTTED
                result = sdCircle(vec2(segment_SDF.x, mod(total_distance, lenX * 6.0) - lenX), lenX);
                break;
            case 3: // WAVE
                float dw = distance(sin(total_distance / lenX) * 0.5 * lenX, segment_SDF.x) - lenX * 0.5;
                result = max(dw, mod(total_distance, lenX * 5.0) - lenX * 4.0);
                break;
            case 4: // DASH_DOT
                float d4 = abs(segment_SDF.x) - lenX;
                d4 = max(d4, abs(mod(total_distance, lenX * 16.0) * 2.0 - lenX * 8.0) - lenX * 4.0);
                result = min(d4, sdCircle(vec2(segment_SDF.x, mod(total_distance + lenX * 7.0, lenX * 16.0) - 3.0 * lenX), lenX));
                break;
            case 5: // ARROW
                float d5 = abs(segment_SDF.x) - lenX * 0.3;
                d5 = max(d5, abs(mod(total_distance + lenX, lenX * 16.0) * 2.0 - lenX * 8.0) - lenX * 6.0);
                result = min(d5, sdEquilateralTriangle(vec2(segment_SDF.x, mod(total_distance + lenX * 4.0, lenX * 16.0) - 10.0 * lenX), lenX));
                break;
        }
    }
    return max(result,rounding(segment_SDF));
}

#endif