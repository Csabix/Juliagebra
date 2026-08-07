#ifndef COMMON_DATA
#define COMMON_DATA

layout(std140, binding = 10) uniform UBO_Buffer {
    mat4 VP;
    mat4 V;
    mat4 P;
    vec4 _light_side_width;
    vec4 _light_cam_heigth;
    vec4 _eye_aspect;
    vec4 _at_width_u;
    vec4 _near_far_fov_hovered;
};
layout(std140, binding = 11) uniform Infinite_UBO_Buffer {
    vec4 aabb_min;
    vec4 aabb_max;
};

float width()  { return _light_side_width.w; }
float height() { return _light_cam_heigth.w; }
float aspect() { return _eye_aspect.w; }
uint width_u() { return floatBitsToUint(_at_width_u.w); }

vec3 light_side() { return _light_side_width.xyz; }
vec3 light_cam() { return _light_cam_heigth.xyz; }
vec3 eye() { return _eye_aspect.xyz; }
vec3 at() { return _at_width_u.xyz; }

vec2 resolution() { return vec2(_light_side_width.w, _light_cam_heigth.w); }

float znear() { return _near_far_fov_hovered.x; }
float zfar() { return _near_far_fov_hovered.y; }
float fov() { return _near_far_fov_hovered.z; }
float orthoHalfHeight() { return -_near_far_fov_hovered.z; }
bool isOrtho() { return fov() < 0.0; }
uint hovered_id() { return floatBitsToUint(_near_far_fov_hovered.w); }

int inside_aabb(vec4 position) {
    if (position.x >= aabb_min.x && position.y >= aabb_min.y && position.z >= aabb_min.z &&
        position.x <= aabb_max.x && position.y <= aabb_max.y && position.z <= aabb_max.z) {
        return 1;
    }
    else {
        return 0;
    }
}
float distance_from_aabb_edge(vec4 position) {
    float xDiff = min(abs(aabb_min.x - position.x), abs(aabb_max.x - position.x));
    float yDiff = min(abs(aabb_min.y - position.y), abs(aabb_max.y - position.y));
    float zDiff = min(abs(aabb_min.z - position.z), abs(aabb_max.z - position.z));
    float minDistance = min(xDiff, yDiff);
    return min(minDistance, zDiff);
}
int visible_in_stripes(vec4 fragPosition) {
    if (mod(floor((fragPosition.x - fragPosition.y) / 5.0), 2.0) == 0.0) {
        return 1;
    }
    else {
        return 0;
    }
}

float computeLinearDepth(float clip_space_depth) {
    const float NEAR = znear();
    const float FAR  = zfar();
    if (isOrtho()) {
        return mix(NEAR, FAR, clip_space_depth);
    } else {
        return ((FAR * NEAR) / (NEAR - FAR)) / (clip_space_depth - (FAR / (FAR - NEAR)));
    }
}

#endif

#ifdef RAY
#ifndef RAY_DEF
vec3 rayDirection() {
    vec3 forward = -vec3(V[0][2], V[1][2], V[2][2]);
    if (isOrtho()) {
        return forward;
    } else {
        vec3 right  = vec3(V[0][0], V[1][0], V[2][0]);
        vec3 up     = vec3(V[0][1], V[1][1], V[2][1]);

        float focal_length = 1.0 / tan(fov() * 0.5);
        vec2 screen_uv = (gl_FragCoord.xy / resolution()) * 2.0 - 1.0; 
        screen_uv.x *= aspect();

        return normalize(screen_uv.x  * right + 
                         screen_uv.y  * up + 
                         focal_length * forward);
    }
}

vec3 rayOrigin() {
    if (isOrtho()) {
        vec3 right = vec3(V[0][0], V[1][0], V[2][0]);
        vec3 up    = vec3(V[0][1], V[1][1], V[2][1]);
        vec2 uv = (gl_FragCoord.xy / resolution()) * 2.0 - 1.0;
        uv.x *= aspect();
        float ortho_scale = orthoHalfHeight();
        return eye() + (uv.x * ortho_scale * right) + (uv.y * ortho_scale * up);
    } else {
        return eye();
    }
}
#define RAY_DEF
#endif
#endif