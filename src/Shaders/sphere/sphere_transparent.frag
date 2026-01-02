#version 460 core

layout(location = 0) out vec4 accum;
layout(location = 1) out float reveal;

uniform mat4 VP;
uniform vec3 cam;
uniform vec3 lightDirCam;
uniform vec3 lightDirSide;

flat in int isOutside;
in float sphereRadius;
in vec3 sphereCenter;
in vec3 worldPos;
flat in vec3 sphereColor;

struct Ray {
	vec3 p0; float tmin;
	vec3 v;	 float tmax;
};

struct TraceResult
{
    vec3 n;  // Normal vector on surface
    float t; // Distance taken on ray
    vec2 uv; // Texture Coords;
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
        return TraceResult(vec3(0),ray.tmax,vec2(0)); // no intersection
    float sqd = sqrt(discriminant);
    float numerator = -b - sqd;
    if(numerator < 0.0)
        numerator = -b + sqd;
    float t = 0.5 * numerator / a;
    vec3 p = ray.p0 + t * ray.v;
    vec3 normal = normalize(p - s.c);
    
    float v = -asin(normal.y);
    float u = asin(normal.z/cos(-v));
    
    return TraceResult(normal, t,vec2(u,v));
}

void main(){
    vec3 v = normalize(worldPos-cam);
    
    Ray r = Ray(cam,
                0.01,
                v,
                1000.0);
    
    Sphere s = Sphere(sphereCenter,sphereRadius); 
    TraceResult rs = intersectSphere(r,s);
    
    if(rs.t == r.tmax){
        discard;    
    }
    
    vec3 spherePos = cam + v * rs.t;
    
    vec4 vpPos = VP * vec4(spherePos,1.0); 
    float depth = (vpPos.xyzw / vpPos.w).z;
    depth = (depth + 1.0) / 2.0;
    gl_FragDepth = depth;

    vec4 color;
    if(isOutside==1){
        float diffuse = (max(dot(rs.n,lightDirCam),0.0) * 0.3 + max(dot(rs.n,lightDirSide),0.0) * 0.7) * 0.8;
        float ambient = 0.2;
        color = vec4(sphereColor * (diffuse + ambient), 0.5);
    }else{
        float diffuse = dot(-rs.n,-normalize(spherePos-cam));
        color = vec4(sphereColor*diffuse,0.5);
    }

    float weight = max(min(1.0, max(max(color.r, color.g), color.b) * color.a), color.a) *
                   clamp(0.03 / (1e-5 + pow(depth / 200, 4.0)), 1e-2, 3e3);

    accum = vec4(color.rgb * color.a, color.a) * weight;
    reveal = color.a;
}