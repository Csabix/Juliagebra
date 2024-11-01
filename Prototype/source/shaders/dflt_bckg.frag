#version 330 core

layout(location = 0) out vec4 outCol;
layout(location = 1) out uint outInd;

void main(){

    outCol = vec4(0.0,1.0,0.0,1.0);
    outInd = uint(5);
}