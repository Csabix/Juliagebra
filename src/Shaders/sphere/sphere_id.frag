#version 330 core

layout(location = 0) out vec4 out_color;
layout(location = 1) out uint out_id;

uniform mat4 VP;
uniform vec3 cam;

flat in float sphereRadius;
flat in vec3 sphereCenter;
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
        return -1.0; // no intersection
    float sqd = sqrt(discriminant);

    float t1 = (-b - sqd) / (2.0 * a);
    float t2 = (-b + sqd) / (2.0 * a);


    float t = -1.0;
    if (t1 >= ray.tmin && t1 <= ray.tmax) {
        t = t1;
    } else if (t2 >= ray.tmin && t2 <= ray.tmax) {
        t = t2;
    }
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
    
    if(t == -1.0){
        discard;    
    }
    
    vec3 spherePos = cam + v * t;
    
    vec4 vpPos = VP * vec4(spherePos,1.0); 
    float depth = (vpPos.xyzw / vpPos.w).z;
    depth = (depth + 1.0) / 2.0;
    gl_FragDepth = depth;

    out_id = uint(0);
}