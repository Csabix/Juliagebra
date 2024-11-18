#version 330 core

layout(location = 0) out vec4 outCol;
layout(location = 1) out uint outInd;




void main(){
    
    
    vec2 texCoord = gl_PointCoord;
    
    if(distance(texCoord,vec2(0.5,0.5))>0.5){
        discard;
    }
    
    
    outCol = vec4(0.0,0.0,1.0,1.0);
    outInd = uint(170);
}