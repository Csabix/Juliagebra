#version 460

in vec2 tex_vs_out;

out vec4 color_out;

uniform sampler2D frameTex;
uniform sampler2D depthTex;

uniform vec3 EYE;
uniform vec3 AT;
uniform vec2 ASPECT_FOV = vec2(1.0,0.8726646);
uniform vec3 NEAR_FAR_DISTANCE_POWER; // near_z, far_z of the camera, nearest power of ten of the distance

vec4 grid(vec3 position, float scale) {
    vec2 coord = position.xy / scale;
    vec2 derivative = fwidth(coord);
    vec2 grid = abs(fract(coord - 0.5) - 0.5) / derivative;
    float line = min(grid.x, grid.y);

    float minimum_y = min(derivative.y, 1);
    float minimum_x = min(derivative.x, 1);

    vec4 color = vec4(0.2, 0.2, 0.2, 1.0 - min(line, 1.0));

    if(position.x > -scale * minimum_x && position.x < scale * minimum_x)
        color.y = 1.0;
    
    if(position.y > -scale * minimum_y && position.y < scale * minimum_y)
        color.x = 1.0;
    
    return color;
}

float computeLinearDepth(float clip_space_depth) {
    const float NEAR = NEAR_FAR_DISTANCE_POWER.x;
    const float FAR  = NEAR_FAR_DISTANCE_POWER.y;
    clip_space_depth = 2.0 * clip_space_depth - 1.0;
    return (NEAR * FAR) / (FAR + clip_space_depth * (NEAR - FAR));
}

vec3 rayDirection() {
    const float ASPECT = ASPECT_FOV.x;
    const float FOV    = ASPECT_FOV.y;

    vec3 look_dir = normalize(EYE - AT);
    vec3 right = normalize(cross(look_dir, vec3(0.0, 0.0, 1.0)));
    vec3 up = normalize(cross(right, look_dir));

    float focal_length = -1.0 / tan(FOV * 0.5);
    vec2 screen_uv = tex_vs_out * 2.0 - 1.0; 
    
    screen_uv.x *= ASPECT;

    return normalize(screen_uv.x  * right + 
                     screen_uv.y  * up + 
                     focal_length * look_dir);
}

void main() {
    const float NEAR           = NEAR_FAR_DISTANCE_POWER.x;
    const float FAR            = NEAR_FAR_DISTANCE_POWER.y;
    const float DISTANCE       = distance(EYE,AT);
    const float DISTANCE_POWER = NEAR_FAR_DISTANCE_POWER.z;

	color_out = texture(frameTex, tex_vs_out);

    vec3 ray_dir = rayDirection();
    float t = -EYE.z / ray_dir.z;
    vec3 frag_position = EYE + t * ray_dir;

    float depth = texture(depthTex, tex_vs_out).x;
    float depth_lin = computeLinearDepth(depth);

    vec4 gridColor = grid(frag_position, DISTANCE_POWER/10.0);
    gridColor = mix(gridColor,grid(frag_position, DISTANCE_POWER),smoothstep(DISTANCE_POWER,10.0*DISTANCE_POWER,DISTANCE));
    float fade = max(0,((2.0*DISTANCE) - distance(AT,frag_position)) / (2.0*DISTANCE));
    gridColor.w *= fade;

    bool hit_in_front_of_camera = t > 0;
    bool hit_in_render_distance = t <= FAR && t < depth_lin;
    bool outside_render_distance = depth == 1.0;
    if(hit_in_front_of_camera && (hit_in_render_distance || outside_render_distance)){
        color_out = mix(color_out, gridColor, gridColor.w);
    }
}