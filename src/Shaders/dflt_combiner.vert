#version 330

const vec4 positions[6] = vec4[6](
    vec4(-1.0,-1.0,-1.0, 1.0),
    vec4( 1.0,-1.0,-1.0, 1.0),
    vec4( 1.0, 1.0,-1.0, 1.0),
    
    vec4( 1.0, 1.0, -1.0, 1.0),
    vec4(-1.0, 1.0, -1.0, 1.0),
    vec4(-1.0,-1.0, -1.0, 1.0)
);

const vec2 texCoords[6] = vec2[6](
    vec2(0.0, 0.0),
    vec2(1.0, 0.0),
    vec2(1.0, 1.0),
    vec2(1.0, 1.0),
    vec2(0.0, 1.0),
    vec2(0.0, 0.0)
);

out vec2 tex_vs_out;

void main() {
	gl_Position = vec4(positions[gl_VertexID].xy,-1.0,1.0);
	tex_vs_out	= texCoords[gl_VertexID];
}