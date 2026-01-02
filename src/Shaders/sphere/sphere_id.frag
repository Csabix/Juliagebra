#version 330 core

layout(location = 0) out vec4 out_color;
layout(location = 1) out uint out_id;

uniform mat4 VP;
uniform vec3 cam;

in float sphereRadius;
in vec3 sphereCenter;
in vec3 worldPos;
flat in vec3 sphereColor;

struct Ray {
	vec3 p0; float tmin;
	vec3 v;	 float tmax;
};

struct Sphere {
    vec3 c;    // center
    float r;   // radius
};

float intersectSphere(Ray ray, Sphere s)
{
    vec3 p0c = ray.p0 - s.c;
    float a = dot(ray.v, ray.v);
    float b = 2.0 * dot(p0c, ray.v);
    float c = dot(p0c,p0c) - s.r*s.r;
    float discriminant = b*b - 4.0*a*c;
    if(discriminant < 0.0)
        return ray.tmax; // no intersection
    float sqd = sqrt(discriminant);
    float numerator = -b - sqd;
    if(numerator < 0.0)
        numerator = -b + sqd;
    float t = 0.5 * numerator / a;
    
    return t;
}

void main(){
    vec3 v = normalize(worldPos-cam);
    
    Ray r = Ray(cam,
                0.01,
                v,
                1000.0);
    
    Sphere s = Sphere(sphereCenter,sphereRadius); 
    float t = intersectSphere(r,s);
    
    if(t == r.tmax){
        discard;    
    }
    
    vec3 spherePos = cam + v * t;
    
    vec4 vpPos = VP * vec4(spherePos,1.0); 
    float depth = (vpPos.xyzw / vpPos.w).z;
    depth = (depth + 1.0) / 2.0;
    gl_FragDepth = depth;

    out_id = uint(0);
}