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
    vec4 _near_far_fov_unused;
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

float znear() { return _near_far_fov_unused.x; }
float zfar() { return _near_far_fov_unused.y; }
float fov() { return _near_far_fov_unused.z; }

#endif