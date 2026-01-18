#version 460 core

layout(location = 0) in vec3 vertex;
uniform mat4 VP;

void main(){
    gl_Position = VP * vec4(vertex,1.0);
}