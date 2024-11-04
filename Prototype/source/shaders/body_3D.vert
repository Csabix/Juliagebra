#version 330 core

layout(location = 0) in vec3 vertPosition;

uniform mat4 VP;

out vec3 normal;
out vec3 lolz;

void main(){
    if (vertPosition.z == 0.0){
        lolz = vec3(0.0,1.0,0.0);
    }else{
        lolz = vec3(1.0,0.0,0.0);
    }
    
    gl_Position = VP * vec4(vertPosition,1.0);
   
    
    //normal = (VPT * vec4(vertNormal,1.0)).xyz;

}