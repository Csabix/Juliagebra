#version 330 core

layout(location = 0) in vec4 vertPosition;

uniform mat4 VP;

void main(){
    gl_PointSize = 25.0;
    
    vec4 SP = VP * vec4(vertPosition.xyz,1.0);
    gl_Position = SP;
}