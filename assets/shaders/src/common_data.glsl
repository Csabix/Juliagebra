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

#endif