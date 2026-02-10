#version 460 core

layout(location = 0) out vec4 out_color;
layout(location = 1) out uint out_id;
layout(depth_greater) out float gl_FragDepth;

uniform mat4 VP;
uniform vec3 cam;
uniform vec3 at;
uniform vec4 ASPECT_FOV_RESOLUTION;

flat in float sphereRadius;
flat in vec3 sphereCenter;
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

vec3 rayDirection() {
    const float ASPECT = ASPECT_FOV_RESOLUTION.x;
    const float FOV    = ASPECT_FOV_RESOLUTION.y;
    const vec2 RESOLUTION = ASPECT_FOV_RESOLUTION.zw;

    vec3 look_dir = normalize(cam - at);
    vec3 right = normalize(cross(look_dir, vec3(0.0, 0.0, 1.0)));
    vec3 up = normalize(cross(right, look_dir));

    float focal_length = -1.0 / tan(FOV * 0.5);
    vec2 screen_uv = (gl_FragCoord.xy / RESOLUTION) * 2.0 - 1.0; 
    
    screen_uv.x *= ASPECT;

    return normalize(screen_uv.x  * right + 
                     screen_uv.y  * up + 
                     focal_length * look_dir);
}

void main(){
    vec3 v = rayDirection();
    
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