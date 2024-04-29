#version 450

const vec2 ps[3] = vec2[3](vec2(-1,-1),vec2(3,-1),vec2(-1,3));

void main() {
    gl_Position = vec4(ps[gl_VertexID],0,1);
}