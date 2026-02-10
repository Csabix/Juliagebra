#version 460 core

const vec4 positions[6] = vec4[6](
    vec4(-1.0,-1.0,-1.0, 1.0),
    vec4( 1.0,-1.0,-1.0, 1.0),
    vec4( 1.0, 1.0,-1.0, 1.0),
    
    vec4( 1.0, 1.0, -1.0, 1.0),
    vec4(-1.0, 1.0, -1.0, 1.0),
    vec4(-1.0,-1.0, -1.0, 1.0)
);

void main() {
	gl_Position = vec4(positions[gl_VertexID].xy,-1.0,1.0);
}