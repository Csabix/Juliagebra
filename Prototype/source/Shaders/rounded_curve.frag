#version 330 core

// TODO: Vonalnak a vonal kozepen vegigmeno szakasz alapjan discardolni a becsatolt texturabol
// TODO: Ekkor az egesz vonal egy egyenes resze nem latszik, ha a vonal kozepe a melyseg mogott van.

layout(location = 0) out vec4 outCol;
layout(location = 1) out uint outInd;

uniform float lineWidth;

// * Same 4 all.
in vec2 fromPos;
in vec2 toPos;
flat in uint geomID;

// * Different 4 all
in float leftDist;
in float rightDist;
in vec2 fragPos;
in vec3 pointCol;

void main(){
     
    if((leftDist<0.0) && (distance(fragPos,fromPos)>lineWidth)){
        discard;
    }else if((rightDist<0.0) && (distance(fragPos,toPos)>lineWidth)){
        discard; 
    }

    outCol = vec4(pointCol,1.0);    
    outInd = geomID;
}