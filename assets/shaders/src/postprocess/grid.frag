#version 460 core
#extension GL_GOOGLE_include_directive : require
#define RAY
#include "../common_data.glsl"

layout(location = 0) out vec4 color_out;

layout(binding = 0) uniform sampler2D depthTex;

layout(location = 0) flat in float dist;
layout(location = 1) flat in float dist_10;

vec4 grid(vec3 position, float scale) {
    vec2 coord = position.xy / scale;
    vec2 derivative = fwidth(coord);
    vec2 grid = abs(fract(coord - 0.5) - 0.5) / derivative;
    float line = min(grid.x, grid.y);

    float minimum_y = min(derivative.y, 1.0);
    float minimum_x = min(derivative.x, 1.0);

    vec4 color = vec4(0.2, 0.2, 0.2, 1.0 - min(line, 1.0));

    if(position.x > -scale * minimum_x && position.x < scale * minimum_x)
        color.y = 1.0;
    
    if(position.y > -scale * minimum_y && position.y < scale * minimum_y)
        color.x = 1.0;
    
    return color;
}

void main() {
    const ivec2 coords = ivec2(gl_FragCoord.xy);

    vec3 ray_dir = rayDirection();
    float t = -ray_origin().z / ray_dir.z;
    vec3 frag_position = ray_origin() + t * ray_dir;
    
    float depth = texelFetch(depthTex, coords, 0).x;
    float depth_lin = computeLinearDepth(depth);
    vec3 view_forward = -vec3(V[0][2], V[1][2], V[2][2]);
    float grid_view_z = t * dot(ray_dir, view_forward);

    if (t < 0.0 || grid_view_z > zfar() || grid_view_z > depth_lin) {
        discard;
    }

    vec4 gridColor = grid(frag_position, dist_10/10.0);
    gridColor = mix(gridColor,grid(frag_position, dist_10),smoothstep(dist_10,10.0*dist_10,dist));
    float fade = max(0.0,((2.0*dist) - distance(at(),frag_position)) / (2.0*dist));
    gridColor.w *= fade;
    if (gridColor.a < 0.0001) discard;
    color_out = gridColor;
}