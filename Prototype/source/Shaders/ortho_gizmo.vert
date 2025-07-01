#version 330 core

layout(location = 0) in vec3 vertPosition;
layout(location = 1) in vec3 vertColor;

out vec3 color;
flat out uint vertID;

uniform mat4 VP;
uniform vec2 tr = vec2(0.85,0.8);

void main(){
    color  = vertColor;
    vertID = uint(0);

    vec4 sp = VP * vec4(vertPosition,1.0);
    
    // x/w + tr.x = x/w + tr.x*w/w = (x + tr.x*w)/w
    // b.x/b.w - a.x/a.w = (b.x/b.w) * (a.w/a.w) - (a.x/a.w) * (b.w/b.w)
    // (b.x * a.w) / (b.w * a.w) - (a.x * b.w) / (a.w * b.w) =
    // ((b * a.w) - (a * b.w)) / (a.w * b.w)
    // normalize(((b * a_w) - (a * b_w)) / (a_w * b_w)) == (normalize((b * a_w) - (a * b_w))) / (a_w * b_w)
    // 
    // normalize(((b * a_w) - (a * b_w)) / (a_w * b_w)) == ((b * a_w) - (a * b_w)) / 1.0
    //
    // c/c_w + ((b * a_w) - (a * b_w))
    // c/c_w + ((b * a_w) - (a * b_w)) * c_w/c_w
    // (c + ((b * a_w) - (a * b_w)) * c_w)/c_w

    // a.x + t * (b.x - a.x) = w
    // t = (w - a.x)/(b.x - a.x) 


    float w = sp.w;
    gl_Position = vec4(sp.x + tr.x*w, sp.y+ tr.y*w, sp.zw);
}