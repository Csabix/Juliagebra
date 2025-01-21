#version 330 core

layout(location = 0) out vec4 outCol;
layout(location = 1) out uint outInd;

flat in uint id;

uniform uint selectedID;
uniform uint pickedID;

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

uniform vec4 defaultColor = vec4(1.0,0.0,1.0,1.0);
uniform vec4 selectedColor = vec4(0.0,1.0,1.0,1.0);
uniform vec4 pickedColor = vec4(1.0,1.0,0.0,1.0);

void main(){

    vec4 drawColor = defaultColor;

    if(selectedID == id){
        drawColor = selectedColor;
    }

    if(pickedID == id){
        drawColor = pickedColor;
    }

    vec2 texCoord = gl_PointCoord;
    float centerDist = distance(texCoord,vec2(0.5,0.5));

    if (centerDist>0.5){
        discard;
    }

    if(centerDist>=0.3){
        outCol = drawColor;
    }else if(plusNorm(texCoord,0.08)){
        outCol = vec4(0.2,0.2,0.2,1.0);
    }else{
        outCol = drawColor;
    }

    outInd = id;
}