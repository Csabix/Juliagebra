#ifndef UBO
#define UBO

layout(std140, binding = 10) uniform UBO_Buffer {
    mat4 VP;
    mat4 V;
    mat4 P;
    vec4 _light_side_width;
    vec4 _light_cam_heigth;
    vec4 _eye_aspect;
    vec4 _at_width_u;
};

float width()  { return _light_side_width.w; }
float height() { return _light_cam_heigth.w; }
float aspect() { return _eye_aspect.w; }
uint width_u() { return floatBitsToUint(_at_width_u.w); }

vec3 light_side() { return _light_side_width.xyz; }
vec3 light_cam() { return _light_cam_heigth.xyz; }
vec3 eye() { return _eye_aspect.xyz; }
vec3 at() { return _at_width_u.xyz; }

#endif