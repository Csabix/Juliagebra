#version 330 core

in vec3 col;

layout(location = 0) out vec4 outCol;
layout(location = 1) out uint outInd;

uniform float line;

void main(){

    vec2 texCoord = gl_PointCoord;
    float centerDist = distance(texCoord,vec2(0.5,0.5));

    if (centerDist>0.5 && line == 0.0){
        discard;
    }
    
    outCol = vec4(col,1.0);
    outInd = uint(55);
    
}