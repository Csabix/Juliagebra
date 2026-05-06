#version 460 core
#include "../color_output.glsl"
#define PI 3.1415926538

#define AMBIENT 0.2
#define DIFFUSE 0.8
// The two directional light source
#define FRONT 0.2
#define SIDE 0.8

#ifdef TRANSPARENT_WEIGHTED_ONLY
#define DISCARD alpha > 0.7
#else
#define DISCARD alpha <= 0.7
#endif

noperspective layout(location = 0) in vec4 segment_SDF_field_in;
noperspective layout(location = 1) in vec3 color_in;
noperspective layout(location = 2) in float total_distance_in;
flat          layout(location = 3) in vec4 begin_pos_rad_in;
flat          layout(location = 4) in vec4 end_pos_rad_in;

float rounding() {
    vec2 p = vec2(abs(segment_SDF_field_in.x),segment_SDF_field_in.y);
    if( p.y < 0.0 ) return length(p) - segment_SDF_field_in.z;
    if( p.y > segment_SDF_field_in.w ) return length(p-vec2(0.0,segment_SDF_field_in.w)) - segment_SDF_field_in.z;
    return p.x - segment_SDF_field_in.z;
}

vec4 get_color(in vec3 normal, in float alpha) {
    float diffuse = (max(dot(normal,light_cam()),0.0) * 0.3 + max(dot(normal,light_side()),0.0) * 0.7) * 0.8;
    float ambient = 0.2;
    return vec4(color_in * (diffuse + ambient), alpha);
}

float sdCircle( vec2 p, float r ) {
    return length(p) - r;
}

#if defined(SOLID)
float pattern() {
    return abs(segment_SDF_field_in.x) - segment_SDF_field_in.z;
}
#elif defined(DASHED)
float pattern() {
    const float lenX = segment_SDF_field_in.z;
    float d = abs(segment_SDF_field_in.x) - lenX;
    const float width = lenX * 5.0;
    return max(d, abs(2.0 * mod(total_distance_in + lenX, width) - width) - lenX * 4.0);
}
#elif defined(DOTTED)
float pattern() {
    const float lenX = segment_SDF_field_in.z;
    return sdCircle(vec2(segment_SDF_field_in.x, mod(total_distance_in,lenX * 3.0) - lenX), lenX);
}
#elif defined(WAVE)
float pattern() {
    const float lenX = segment_SDF_field_in.z;
    return distance(sin(total_distance_in / lenX) * 0.5 * lenX, segment_SDF_field_in.x) - lenX * 0.5;
}
#elif defined(DASH_DOT)
float pattern() {
    const float lenX = segment_SDF_field_in.z;
    float d = abs(segment_SDF_field_in.x) - lenX;
    d = max(d, abs(mod(total_distance_in,lenX * 8.0) * 2.0 - lenX * 8.0) - lenX * 4.0);
    return min(d, sdCircle(vec2(segment_SDF_field_in.x, mod(total_distance_in + lenX * 3.0,lenX * 8.0) - 3.0 * lenX), lenX));
}
#elif defined(ARROW)
float sdEquilateralTriangle( in vec2 p, in float r ) {
    const float k = sqrt(3.0);
    p.x = abs(p.x) - r;
    p.y = p.y + r/k;
    if( p.x+k*p.y>0.0 ) p = vec2(p.x-k*p.y,-k*p.x-p.y)/2.0;
    p.x -= clamp( p.x, -2.0*r, 0.0 );
    return -length(p)*sign(p.y);
}

float pattern() {
    const float lenX = segment_SDF_field_in.z;
    float d = abs(segment_SDF_field_in.x) - lenX * 0.3;
    d = max(d, abs(mod(total_distance_in + lenX,lenX * 8.0) * 2.0 - lenX * 8.0) - lenX * 6.0);
    d = min(d, sdEquilateralTriangle(vec2(segment_SDF_field_in.x,mod(total_distance_in + lenX * 4.0, lenX * 8.0) - 2 * lenX), lenX));
    return d;
}
#endif

vec3 rayDirection() {
    vec3 right    = vec3(V[0][0], V[1][0], V[2][0]);
    vec3 up       = vec3(V[0][1], V[1][1], V[2][1]);
    vec3 backward = vec3(V[0][2], V[1][2], V[2][2]);

    float focal_length = -1.0 / tan(fov() * 0.5);
    vec2 screen_uv = (gl_FragCoord.xy / resolution()) * 2.0 - 1.0; 
    screen_uv.x *= aspect();

    return normalize(screen_uv.x  * right + 
                     screen_uv.y  * up + 
                     focal_length * backward);
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

void main() {
    float d = pattern();
    float alpha = 1.0 - smoothstep(max(-0.4*segment_SDF_field_in.z,-4.0), 0.0, d);
    alpha = alpha >= 0.9 ? 1.0 : alpha;
    d = max(d, rounding());

    if (d > 0.0 || DISCARD) discard;

    vec3 ro = eye();
    vec3 rd = rayDirection();
    
    vec3 pa = begin_pos_rad_in.xyz;
    float ra = begin_pos_rad_in.w;
    vec3 pb = end_pos_rad_in.xyz;
    float rb = end_pos_rad_in.w;
    
    vec3 normal;
    float t = iUnevenCapsule(ro, rd, pa, pb, ra, rb, normal);
    if (t < 0.0) discard;

    vec4 p = vec4(fma(rd,vec3(t),eye()), 1.0);
    float zc = dot(vec4(VP[0].z, VP[1].z, VP[2].z, VP[3].z), p);
    float wc = dot(vec4(VP[0].w, VP[1].w, VP[2].w, VP[3].w), p);
    float depth = fma((zc / wc),0.5,0.5);
    
    gl_FragDepth = depth;

    vec4 color = get_color(normal, alpha);
    WRITE_COLOR(color, 0, depth)
}