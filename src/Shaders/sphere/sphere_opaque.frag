#version 330 core

layout(location = 0) out vec4 out_color;

uniform mat4 VP;
uniform vec3 cam;
uniform vec3 lightDirCam;
uniform vec3 lightDirSide;

flat in float sphereRadius;
flat in vec3 sphereCenter;
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

void main(){
    vec3 v = normalize(worldPos-cam);
    
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