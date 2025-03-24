#version 330 core

layout(location = 0) in vec3 vertPosition;
layout(location = 1) in vec3 vertColor;

out vec3 color;

uniform mat4 VP;

void main(){
    color = vertColor;
    
    gl_Position = VP * vec4(vertPosition,1.0);
}