#version 330 core

layout(location = 0) out vec4 outCol;
layout(location = 1) out uint outInd;

uniform float lineWidth;

// * Same 4 all.
in vec2 fromPos;
in vec2 toPos;

// * Different 4 all
in float leftDistance;
in float rightDistance;
in vec2 fragPos;
in vec3 pointCol;

void main(){
    
    //float z = zW.x;
    //float w = zW.y;
    //
    //if(z>w || z<-w){
    //    discard;
    //}
    //float zz = ((z/w)+1.0)/2.0;
    //gl_FragDepth = zz;
    
    if((leftDistance<0.0) && (distance(fragPos,fromPos)>lineWidth)){
        discard;
    }else if((rightDistance<0.0) && (distance(fragPos,toPos)>lineWidth)){
        discard; 
    }

    outCol = vec4(pointCol,1.0);    
    outInd = uint(0);
}