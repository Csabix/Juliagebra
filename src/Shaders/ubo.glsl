#ifndef UBO
#define UBO

layout(std140, binding = 0) uniform UBO_Buffer {
    mat4 VP;
    mat4 V;
    mat4 P;
    vec4 light_side;
    vec4 light_cam;
    vec4 eye;
    vec4 width_height_aspect_width_u;
};
float width()  { return width_height_aspect_width_u.x; }
float height() { return width_height_aspect_width_u.y; }
float aspect() { return width_height_aspect_width_u.z; }
uint width_u() { return floatBitsToUint(width_height_aspect_width_u.w); }

#endif