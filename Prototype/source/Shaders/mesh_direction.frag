#version 330 core

layout(location = 0) out vec4 outCol;
layout(location = 1) out uint outInd;

in vec3 vertNormal;
in vec3 vertColor;

uniform vec3 lightDir;
uniform float minFactor = 0.2;

void main(){
    
    vec3 normal = normalize(vertNormal);
    vec3 fragColor = vertColor;
    if(!gl_FrontFacing){
        fragColor = abs(1.0 - fragColor);
        normal *= -1.0;
    }

    float diffuseFactor = max(dot(normal,lightDir),minFactor);
    outCol = vec4(fragColor * diffuseFactor,1.0);    
    outInd = uint(0);
}