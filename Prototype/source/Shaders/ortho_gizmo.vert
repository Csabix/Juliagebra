#version 330 core

layout(location = 0) in vec3 vertPosition;
layout(location = 1) in vec3 vertColor;

out vec3 color;

uniform mat4 VP;
uniform vec2 tr = vec2(0.85,0.8);

void main(){
    color = vertColor;
    
    vec4 sp = VP * vec4(vertPosition,1.0);
    
    // x/w + tr.x = x/w + tr.x*w/w = (x + tr.x*w)/w
    float w = sp.w;
    gl_Position = vec4(sp.x + tr.x*w, sp.y+ tr.y*w, sp.zw);
}