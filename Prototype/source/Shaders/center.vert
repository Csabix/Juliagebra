#version 330 core

layout(location = 0) in vec3 vertPosition;

void main(){
    gl_PointSize = 25.0;
    gl_Position = vec4(vertPosition, 1.0);
}

