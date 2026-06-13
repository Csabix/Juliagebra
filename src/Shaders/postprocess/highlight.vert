#version 460 core

const vec4 positions[3] = vec4[3](
    vec4(-1.0, -1.0, 0.0, 1.0),
    vec4( 3.0, -1.0, 0.0, 1.0),
    vec4(-1.0,  3.0, 0.0, 1.0)
);

void main() {
	gl_Position = vec4(positions[gl_VertexID].xy, -1.0, 1.0);
}