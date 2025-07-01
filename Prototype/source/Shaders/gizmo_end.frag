#version 330 core

layout(location = 0) out vec4 outCol;
layout(location = 1) out uint outInd;

in vec3 endColor;
flat in uint gizmoID;

// ! x:[0,1] -> [-0.5,0.5]
// ! y:[0,1] -> [-0.5,0.5]
bool plusNorm(vec2 coords,float size){
    float x = abs(coords.x-0.5);
    float y = abs(coords.y-0.5);

    if (x>=size && y>=size){
        return false;
    }
    return true;
    
}

void main(){

    vec2 texCoord = gl_PointCoord;
    float centerDist = distance(texCoord,vec2(0.5,0.5));

    if (centerDist>0.5){
        discard;
    }

    if(centerDist>=0.3){
        outCol = vec4(endColor,1.0);
    }else if(plusNorm(texCoord,0.08)){
        outCol = vec4(0.2,0.2,0.2,1.0);
    }else{
        outCol = vec4(endColor,1.0);
    }
    
    outInd = gizmoID;
    
}