#version 330

const vec4 positions[6] = vec4[6](
    vec4(-1.0   ,-1.0   ,-1.0    ,1.0),
    vec4(1.0    ,-1.0   ,-1.0    ,1.0),
    vec4(1.0   , 1.0   ,-1.0    ,1.0),
    
    vec4(1.0   ,1.0    ,-1.0    ,1.0),
    vec4(-1.0    ,1.0    ,-1.0    ,1.0),
    vec4(-1.0    ,-1.0   ,-1.0    ,1.0)
);

const vec2 texCoords[6] = vec2[6](
    vec2(0.0    ,0.0),
    vec2(1.0    ,0.0),
    vec2(1.0    ,1.0),
    vec2(1.0    ,1.0),
    vec2(0.0    ,1.0),
    vec2(0.0    ,0.0)
);

out vec2 tex_vs_out;
out vec3 near_vs_out;
out vec3 far_vs_out;

uniform mat4 IVP;

void main() {
	gl_Position = vec4(positions[gl_VertexID].xy,-1.0,1.0);
    
	tex_vs_out	= texCoords[gl_VertexID];

	vec4 near = IVP * vec4(positions[gl_VertexID].xy,-1.0,1.0);
    near_vs_out = near.xyz / near.w;

    vec4 far = IVP * vec4(positions[gl_VertexID].xy, 1.0,1.0);
	far_vs_out  = far.xyz / far.w;
}