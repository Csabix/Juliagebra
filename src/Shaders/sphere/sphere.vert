#version 330 core

layout(location = 0) in vec3 in_center;
layout(location = 1) in float in_radius;
layout(location = 2) in vec3 in_color;

out float radius;
out vec3 color;


void main(){
    gl_Position = vec4(in_center,0.0);
    radius = in_radius;
    color = in_color;
}