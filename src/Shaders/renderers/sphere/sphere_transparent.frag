#version 460 core
#include "../color_output.glsl"
layout(early_fragment_tests) in;

flat layout(location = 0) in vec4 color_in;
flat layout(location = 1) in uint id_in;
flat layout(location = 2) in vec3 center_in;
flat layout(location = 3) in float radius_in;

uniform float near;

struct Ray {
	vec3 p0; float tmin;
	vec3 v;	 float tmax;
};

struct TraceResult
{
    vec3 n;  // Normal vector on surface
    float t; // Distance taken on ray
    vec2 uv; // Texture Coords
};

struct Sphere {
    vec3 c;    // center
    float r;   // radius
};

TraceResult intersectSphere(Ray ray, Sphere s)
{
    vec3 p0c = ray.p0 - s.c;
    float a = dot(ray.v, ray.v);
    float b = 2.0 * dot(p0c, ray.v);
    float c = dot(p0c,p0c) - s.r*s.r;
    float discriminant = b*b - 4.0*a*c;
    if(discriminant < 0.0)
        return TraceResult(vec3(0),-1.0,vec2(0)); // no intersection
    float sqd = sqrt(discriminant) * near;

    float t = (-b - sqd) / (2.0 * a);
    if (t < ray.tmin || t > ray.tmax) t = -1.0;

    vec3 p = ray.p0 + t * ray.v;
    vec3 normal = normalize(p - s.c);
    
    float v = -asin(normal.y);
    float u = asin(normal.z/cos(-v));
    
    return TraceResult(normal, t,vec2(u,v));
}

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

float pow4(float val) {
    return val * val * val * val;
}

void main(){
    vec3 v = rayDirection();
    
    Ray r = Ray(eye(),
                0.01,
                v,
                1000.0);
    
    Sphere s = Sphere(center_in,radius_in);
    TraceResult rs = intersectSphere(r,s);
    
    if(rs.t < 0.0) discard;
    
    vec4 p = vec4(fma(v,vec3(rs.t),eye()), 1.0);
    float zc = dot(vec4(VP[0].z, VP[1].z, VP[2].z, VP[3].z), p);
    float wc = dot(vec4(VP[0].w, VP[1].w, VP[2].w, VP[3].w), p);
    float depth = fma((zc / wc),0.5,0.5);

    rs.n = near == 1.0 ? rs.n : -rs.n;
    float diffuse = (max(dot(rs.n,light_cam()),0.0) * 0.3 + max(dot(rs.n,light_side()),0.0) * 0.7) * 0.8;
    float ambient = 0.2;
    vec4 color = vec4(color_in.rgb*(diffuse+ambient),color_in.a);

    WRITE_COLOR(color, id_in, depth)
}