#version 330 core

layout(location = 0) in vec3 vertPosition;
out vec3 color;


void main(){
    color = vec3(1.0,1.0,0.0);
    
    gl_Position = vec4(vertPosition,1.0);
}