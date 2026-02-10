#version 330 core
#define PI 3.1415926538

layout(location = 0) out uint outInd;

flat in uint id;

void main(){
    vec2 texCoord = gl_PointCoord;
    float centerDist = distance(texCoord,vec2(0.5,0.5));

    if (centerDist>0.5) discard;
    outInd = id;
}