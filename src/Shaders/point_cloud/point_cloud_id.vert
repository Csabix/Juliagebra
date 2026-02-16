#version 330 core

layout(location = 0) in vec3 vertPosition;


uniform mat4 VP;

void main(){
    gl_PointSize = 25.0;
    gl_Position = VP * vec4(vertPosition,1.0);
}