#version 460 core
#include "../ubo.glsl"

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

float computeLinearDepth(float clip_space_depth) {
    const float NEAR = znear();
    const float FAR  = zfar();
    return ((FAR * NEAR) / (NEAR - FAR)) / (clip_space_depth - (FAR / (FAR - NEAR)));
}

vec3 rayDirection() {
    vec3 right    = vec3(V[0][0], V[1][0], V[2][0]);
    vec3 up       = vec3(V[0][1], V[1][1], V[2][1]);
    vec3 backward = vec3(V[0][2], V[1][2], V[2][2]);

    float focal_length = -1.0 / tan(fov() * 0.5);
    vec2 screen_uv = (gl_FragCoord.xy / resolution()) * 2.0 - 1.0; 
    screen_uv.x *= aspect();

    return normalize(screen_uv.x  * right + 
                     screen_uv.y  * up + 
                     focal_length * backward);
}

void main() {
    const ivec2 coords = ivec2(gl_FragCoord.xy);

    vec3 ray_dir = rayDirection();
    float t = -eye().z / ray_dir.z;
    vec3 frag_position = eye() + t * ray_dir;
    
    float depth = texelFetch(depthTex, coords, 0).x;
    float depth_lin = computeLinearDepth(depth);
    vec3 view_forward = normalize(at() - eye());
    float grid_view_z = t * dot(ray_dir, view_forward);

    bool hit_in_front_of_camera = t > 0.0;
    bool hit_in_render_distance = grid_view_z <= zfar() && grid_view_z < depth_lin;
    bool outside_render_distance = depth == 1.0;
    if (!hit_in_front_of_camera || !hit_in_render_distance || !outside_render_distance){
        discard;
    }

    vec4 gridColor = grid(frag_position, dist_10/10.0);
    gridColor = mix(gridColor,grid(frag_position, dist_10),smoothstep(dist_10,10.0*dist_10,dist));
    float fade = max(0.0,((2.0*dist) - distance(at(),frag_position)) / (2.0*dist));
    gridColor.w *= fade;
    if (gridColor.a < 0.0001) discard;
    color_out = gridColor;
}