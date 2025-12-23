#version 330 core

layout(location = 0) out vec4 out_color;
layout(location = 1) out uint out_id;

uniform mat4 VP;
uniform vec3 cam;

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
    
    {
    /*
    
    float u = dot(normal,vec3(1,0,0));
    float v = dot(normal,vec3(0,1,0));
    
    n.x = cos(uv.x)*cos(-uv.y)
    n.y = sin(-uv.y)
    n.z = sin(uv.x)*cos(-uv.y)
    
    asin(n.y) = -uv.y
    -asin(n.y) = uv.y
    
    n.z/cos(-uv.y) = sin(uv.x)
    asin(n.z/cos(-uv.y)) = uv.x
    
    _U~~
    */ 
    }
    
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

    if(isOutside==1){
        float diffuse = dot(rs.n,-normalize(spherePos-cam));
        out_color = vec4(sphereColor*diffuse,1.0);  
    }else{
        float diffuse = dot(-rs.n,-normalize(spherePos-cam));
        //out_color = vec4(0.0,abs(rs.uv),1.0);
        out_color = vec4(sphereColor*diffuse,1.0);
    }

    out_id = uint(0);
}