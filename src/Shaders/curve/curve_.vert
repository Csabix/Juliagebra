#version 460 core

layout(location=0) in vec3  position_in;

void main() {
	gl_Position = vec4(position_in,1.0);
}