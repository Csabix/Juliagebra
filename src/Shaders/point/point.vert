#version 330 core

layout(location = 0) in vec3 vertPosition;
layout(location = 1) in float vertID;

flat out uint id;

uniform mat4 VP;

void main(){
    gl_PointSize = 25.0;
    gl_Position = VP * vec4(vertPosition,1.0);
    id = uint(vertID);
}