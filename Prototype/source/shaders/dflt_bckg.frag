#version 460 core

layout(location = 0) out vec4 outCol;
layout(location = 1) out uint outInd;

uniform vec3 bCol;
uniform uint id = uint(99);

void main(){

    outCol = vec4(bCol.x,bCol.y,bCol.z,1.0);
    outInd = id;
}