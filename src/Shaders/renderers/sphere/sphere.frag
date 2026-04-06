#version 460 core
#ifdef TRANSPARENT
#extension GL_ARB_fragment_shader_interlock : require
layout(pixel_interlock_unordered) in;
layout(early_fragment_tests) in;
#endif

#ifdef TRANSPARENT
struct PixelData {
    uvec2 dist_col[4];
    uvec2 dist_id;
};

coherent layout(std430, binding = 0) buffer PixelDataBuffer {
    PixelData data[];
};

layout(binding = 0) uniform sampler2D depth_tex;

layout(location = 0) out vec4 accum;
layout(location = 1) out float reveal;

layout(location = 0) uniform uint width;
#else
layout(location = 0) out vec4 color_out;
layout(location = 1) out uint id_out;
layout(depth_greater) out float gl_FragDepth;
#endif

flat layout(location = 0) in vec4 color_in;
flat layout(location = 1) in uint id_in;
flat layout(location = 2) in vec3 center_in;
flat layout(location = 3) in float radius_in;

uniform mat4 VP;
uniform vec3 cam;
uniform vec3 at;
uniform vec3 lightDirCam;
uniform vec3 lightDirSide;
uniform vec4 ASPECT_FOV_RESOLUTION;

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

#ifdef TRANSPARENT
float pow4(float val) {
    return val * val * val * val;
}
#endif

void main(){
    vec3 v = rayDirection();
    
    Ray r = Ray(cam,
                0.01,
                v,
                1000.0);
    
    Sphere s = Sphere(center_in,radius_in);
    TraceResult rs = intersectSphere(r,s);
    
    if(rs.t < 0.0) discard;
    
    vec3 spherePos = cam + v * rs.t;
    
    vec4 vpPos = VP * vec4(spherePos,1.0); 
    float depth = (vpPos.xyzw / vpPos.w).z;
    depth = (depth + 1.0) / 2.0;
#ifdef TRANSPARENT
    if (depth > texelFetch(depth_tex, ivec2(gl_FragCoord.xy), 0).r) discard;
#endif

    vec4 color;
    if(rs.isOutside){
        float diffuse = (max(dot(rs.n,lightDirCam),0.0) * 0.3 + max(dot(rs.n,lightDirSide),0.0) * 0.7) * 0.8;
        float ambient = 0.2;
        color = vec4(color_in.rgb*(diffuse+ambient),color_in.a);
    }else{
        float diffuse = max(dot(-rs.n,lightDirCam),0.0);
        color = vec4(color_in.rgb*diffuse,color_in.a);
    }

#ifdef TRANSPARENT
    uint pixelIdx = uint(gl_FragCoord.x) + uint(gl_FragCoord.y) * width;
    uint packedColor = packUnorm4x8(color);

    uint max_index;
    uvec2 max_dist_col = uvec2(uint(0));

    beginInvocationInterlockARB();
    const float dist_id_x = data[pixelIdx].dist_id.x;
    if (dist_id_x == uint(0) ||dist_id_x > floatBitsToUint(depth))
        data[pixelIdx].dist_id = uvec2(floatBitsToUint(depth),uint(id_in));
    for (uint i = 0; i < 4; ++i) {
        const uvec2 dist_col = data[pixelIdx].dist_col[i];
        if (uint(0) == dist_col.x) {
            max_dist_col = dist_col;
            max_index = i;
            break;
        } else if(dist_col.x > max_dist_col.x) {
            max_dist_col = dist_col;
            max_index = i;
        }
    }

    if (floatBitsToUint(depth) < max_dist_col.x || uint(0) == max_dist_col.x) {
        data[pixelIdx].dist_col[max_index] = uvec2(floatBitsToUint(depth), packedColor);
    } else {
        max_dist_col = uvec2(floatBitsToUint(depth), packedColor);
    }
    
    endInvocationInterlockARB();

    if (uint(0) == max_dist_col.x) discard;

    color = unpackUnorm4x8(max_dist_col.y);
    float weight = max(max(max(color.r, color.g), color.b) * color.a, color.a) *
               clamp(0.03 / (1e-5 + pow4(uintBitsToFloat(max_dist_col.x) / 200)), 1e-2, 3e3);

    accum = vec4(color.rgb * color.a, color.a) * weight;
    reveal = color.a;
#else
    gl_FragDepth = depth;
    id_out = id_in;
    color_out = color;
#endif
}