#version 330 core

layout(location = 0) in vec3 vertPosition;
layout(location = 1) in vec3 vertColor;

out vec3 color;
flat out uint vertID;

uniform mat4 VP;

void main(){
    color  = vertColor;
    vertID = uint(0);
    gl_Position = VP * vec4(vertPosition,1.0);
}