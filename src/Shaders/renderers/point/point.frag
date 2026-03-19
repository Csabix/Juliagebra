#version 460 core
#define PI 3.1415926538

#define PLUS_WIDTH 0.08
#define AMBIENT 0.2
#define DIFFUSE 0.8
// The two directional light source
#define FRONT 0.2
#define SIDE 0.8

layout(location = 0) out vec4 color_out;
layout(location = 1) out uint id_out;

layout(location = 0) flat in vec3 color_in;
#ifndef STATIC
layout(location = 1) flat in vec3 color_inv_in;
#endif
layout(location = 2) flat in uint id_in;

#ifndef STATIC
uniform uint selected_id;
uniform uint picked_id;
#endif
uniform vec3 light_dir_side_view;

#ifndef STATIC
uint plusNorm() {
    vec2 dist = abs(gl_PointCoord - vec2(0.5));
    return uint(dist.x < PLUS_WIDTH) | uint(dist.y < PLUS_WIDTH);
}

vec3 get_color() {
    uint selected = uint(selected_id == id_in) | uint(picked_id == id_in);
    uint inside_plus = plusNorm();
    return (selected ^ inside_plus) == 0 ? color_in : color_inv_in;
}
#else
vec3 get_color() {
    return color_in;
}
#endif
float light(vec3 normal, vec3 direction) {
    return max(0.0,dot(normal,direction));
}

void main() {
    float centerDist = distance(gl_PointCoord,vec2(0.5,0.5));
    if (distance(gl_PointCoord,vec2(0.5)) > 0.5) discard;

    vec3 color = get_color();

    vec2 angle = gl_PointCoord * PI;
    vec2 sin_vu = sin(angle);
    vec2 cos_vu = cos(angle);
    vec3 normal = -vec3(sin_vu.x * cos_vu.y, cos_vu.x, sin_vu.x * sin_vu.y);

    float diffuse = light(normal, vec3(0,0,-1.0)) * FRONT + light(normal, light_dir_side_view) * DIFFUSE;
    color_out = vec4(color * (diffuse + AMBIENT), 1.0);
    id_out = id_in;
}