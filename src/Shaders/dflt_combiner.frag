#version 330

in vec2 tex_vs_out;

out vec4 color_out;

uniform sampler2D frameTex;
uniform sampler2D depthTex;

uniform vec4 NEAR_FAR_DISTANCE_DISTANCE_LOG;
uniform vec3 Eye;
uniform vec2 WH;
uniform vec3 At;

vec4 grid(vec3 position, float scale) {
    vec2 coord = position.xy * scale;
    vec2 derivative = fwidth(coord);
    vec2 grid = abs(fract(coord - 0.5) - 0.5) / derivative;
    float line = min(grid.x, grid.y);

    float minimum_y = min(derivative.y, 1);
    float minimum_x = min(derivative.x, 1);

    vec4 color = vec4(0.2, 0.2, 0.2, 1.0 - min(line, 1.0));

    if(position.x > -1.0/scale * minimum_x && position.x < 1.0/scale * minimum_x)
        color.y = 1.0;
    
    if(position.y > -1.0/scale * minimum_y && position.y < 1.0/scale * minimum_y)
        color.x = 1.0;
    
    return color;
}

float computeLinearDepth(float clip_space_depth) {
    float NEAR = NEAR_FAR_DISTANCE_DISTANCE_LOG.x;
    float FAR = NEAR_FAR_DISTANCE_DISTANCE_LOG.y;
    clip_space_depth = 2.0 * clip_space_depth - 1.0;
    return (NEAR * FAR) / (FAR + clip_space_depth * (NEAR - FAR));
}

vec3 rayDirection() {
    vec3 look_dir = normalize(At - Eye);
    vec3 right = -normalize(cross(look_dir, vec3(0.0, 0.0, 1.0)));
    vec3 up = -normalize(cross(right, look_dir));

    float focal_length = 1.0 / tan(0.8726646 * 0.5);
    vec2 screen_uv = tex_vs_out * 2.0 - 1.0; 
    
    float aspect = WH.x / WH.y;
    screen_uv.x *= aspect;

    return normalize(screen_uv.x * right + 
                     screen_uv.y * up + 
                     focal_length * look_dir);
}

void main() {
	vec4 originalColor = texture(frameTex, tex_vs_out);
	color_out = originalColor;

    vec3 ray_dir = rayDirection();
    float t = -Eye.z / ray_dir.z;
    vec3 frag_position = Eye + t * ray_dir;

    float depth_origin = computeLinearDepth(texture(depthTex, tex_vs_out).x);

    if(t > 0 && (t < depth_origin + NEAR_FAR_DISTANCE_DISTANCE_LOG.x || t >= NEAR_FAR_DISTANCE_DISTANCE_LOG.y)){
        float DISTANCE_LOG = NEAR_FAR_DISTANCE_DISTANCE_LOG.w;
        float DISTANCE = NEAR_FAR_DISTANCE_DISTANCE_LOG.z;
        
        vec4 gridColor = grid(frag_position, DISTANCE_LOG*10);
        gridColor = mix(gridColor,grid(frag_position, DISTANCE_LOG),smoothstep(1/DISTANCE_LOG,10/DISTANCE_LOG,DISTANCE));
        float fade = max(0,((2.0*DISTANCE) - distance(At,frag_position)) / (2.0*DISTANCE));
        
        gridColor.w *= fade;
        color_out = mix(originalColor,gridColor, gridColor.w);
    }
}