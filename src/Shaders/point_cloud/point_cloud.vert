#version 330 core

layout(location = 0) in vec3 vertPosition;

uniform mat4 VP;
uniform float pointSize = 25.0;

void main(){
    gl_PointSize = pointSize;
    gl_Position = VP * vec4(vertPosition,1.0);
}