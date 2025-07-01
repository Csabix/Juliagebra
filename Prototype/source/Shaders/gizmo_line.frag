#version 330 core

layout(location = 0) out vec4 outCol;
layout(location = 1) out uint outInd;

in vec3 lineColor;
flat in uint gizmoID;

uniform uint selectedID;

void main(){

    if(selectedID != uint(0) && selectedID!=gizmoID){
        discard;
    }else{
        outCol = vec4(lineColor,1.0);
        outInd = gizmoID;
    }

}