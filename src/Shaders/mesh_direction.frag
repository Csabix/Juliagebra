#version 330 core

layout(location = 0) out vec4 outCol;
layout(location = 1) out uint outInd;

in vec3 vertNormal;
in vec3 vertColor;

uniform vec3 lightDirCam;
uniform vec3 lightDirSide;
uniform float minFactor = 0.2;

void main(){
    
    vec3 normal = normalize(vertNormal);
    vec3 fragColor = vertColor;
    if(!gl_FrontFacing){
        fragColor = abs(1.0 - fragColor);
        normal *= -1.0;
    }

    float diffuse = (max(dot(normal,lightDirCam),0.0) * 0.3 + max(dot(normal,lightDirSide),0.0) * 0.7) * 0.8;
    float ambient = 0.2;
    outCol = vec4(fragColor * (diffuse + ambient), 1.0);
    outInd = uint(0);
}