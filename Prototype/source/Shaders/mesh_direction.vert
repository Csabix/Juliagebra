#version 330 core

layout(location = 0) in vec3 vertex;
layout(location = 1) in vec3 normal;
layout(location = 2) in vec3 color;

uniform mat4 VP;

out vec3 vertNormal;
out vec3 vertColor;

void main(){
    vec4 SP = VP * vec4(vertex,1.0);
    gl_Position = SP;
    vertNormal = normal;
    vertColor = color;
}