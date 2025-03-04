#version 330 core

layout(location = 0) in vec3 vertPosition;
uniform mat4 VP;

void main(){
    vec4 SP = VP * vec4(vertPosition,1.0);
    gl_Position = SP;
}