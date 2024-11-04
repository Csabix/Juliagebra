#version 330 core

layout(location = 0) out vec4 outCol;
layout(location = 1) out uint outInd;


//in vec3 normal;
uniform vec3 toLight = vec3(0.0,1.0,0.0);
uniform vec3 bodyColor = vec3(0.0,1.0,0.0);
uniform vec3 Ld = vec3(0.5,0.5,0.5);
uniform uint id = uint(99);

in vec3 lolz;

void main(){
    //vec3 normalizedNormal = normalize(normal);
    
    //float DiffuseFactor = max(dot(toLight,normal), 0.0);
	//vec3 Diffuse = DiffuseFactor * Ld;

    //outCol = vec4(Diffuse,1.0) * vec4(bodyColor,1.0);
    outCol = vec4(lolz,1.0);
    outInd = id;
}