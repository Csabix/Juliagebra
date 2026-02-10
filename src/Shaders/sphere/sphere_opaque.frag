#version 460 core

layout(location = 0) out vec4 out_color;
layout(depth_greater) out float gl_FragDepth;

uniform mat4 VP;
uniform vec3 cam;
uniform vec3 at;
uniform vec3 lightDirCam;
uniform vec3 lightDirSide;
uniform vec4 ASPECT_FOV_RESOLUTION;

flat in float sphereRadius;
flat in vec3 sphereCenter;
flat in vec3 sphereColor;

struct Ray {
	vec3 p0; float tmin;
	vec3 v;	 float tmax;
};

struct TraceResult
{
    vec3 n;  // Normal vector on surface
    float t; // Distance taken on ray
    vec2 uv; // Texture Coords
    bool isOutside;
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
        return TraceResult(vec3(0),-1.0,vec2(0), false); // no intersection
    float sqd = sqrt(discriminant);

    float t1 = (-b - sqd) / (2.0 * a);
    float t2 = (-b + sqd) / (2.0 * a);


    float t = -1.0;
    bool isOutside = false;
    if (t1 >= ray.tmin && t1 <= ray.tmax) {
        t = t1;
        isOutside = true;
    } else if (t2 >= ray.tmin && t2 <= ray.tmax) {
        t = t2;
    }

    vec3 p = ray.p0 + t * ray.v;
    vec3 normal = normalize(p - s.c);
    
    float v = -asin(normal.y);
    float u = asin(normal.z/cos(-v));
    
    return TraceResult(normal, t,vec2(u,v), isOutside);
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
    TraceResult rs = intersectSphere(r,s);
    
    if(rs.t == -1.0) discard;
    
    vec3 spherePos = cam + v * rs.t;
    
    vec4 vpPos = VP * vec4(spherePos,1.0); 
    float depth = (vpPos.xyzw / vpPos.w).z;
    depth = (depth + 1.0) / 2.0;
    gl_FragDepth = depth;

    if(rs.isOutside){
        float diffuse = (max(dot(rs.n,lightDirCam),0.0) * 0.3 + max(dot(rs.n,lightDirSide),0.0) * 0.7) * 0.8;
        float ambient = 0.2;
        out_color = vec4(sphereColor*(diffuse+ambient),1.0);
    }else{
        float diffuse = max(dot(-rs.n,lightDirCam),0.0);
        out_color = vec4(sphereColor*diffuse,1.0);
    }
}