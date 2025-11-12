#version 330

in vec2 tex_vs_out;
in vec3 near_vs_out;
in vec3 far_vs_out;

out vec4 color_out;

uniform sampler2D frameTex;
uniform sampler2D depthTex;

uniform vec4 NEAR_FAR_DISTANCE_DISTANCE_LOG;
uniform vec3 Eye;
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

void main() {
	vec4 originalColor = texture(frameTex, tex_vs_out);
	color_out = originalColor;

    float t = -near_vs_out.z / (far_vs_out.z - near_vs_out.z);
    vec3 frag_position = near_vs_out + t * (far_vs_out - near_vs_out);

    float depth_frag = dot(Eye-frag_position,Eye-frag_position);
    float depth_origin = computeLinearDepth(texture(depthTex, tex_vs_out).x);
    depth_origin *= depth_origin;

    if(t > 0 && depth_frag < depth_origin){
        float DISTANCE_LOG = NEAR_FAR_DISTANCE_DISTANCE_LOG.w;
        float DISTANCE = NEAR_FAR_DISTANCE_DISTANCE_LOG.z;
        
        vec4 gridColor = grid(frag_position, DISTANCE_LOG*10);
        gridColor = mix(gridColor,grid(frag_position, DISTANCE_LOG),smoothstep(1/DISTANCE_LOG,10/DISTANCE_LOG,DISTANCE));
        float fade = max(0,((2.0*DISTANCE) - distance(At,frag_position)) / (2.0*DISTANCE));
        
        gridColor.w *= fade;
        color_out = mix(originalColor,gridColor, gridColor.w);
    }
}