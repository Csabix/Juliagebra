#version 330 core

layout(location = 0) in vec3 vertPosition;
out vec3 color;

uniform vec3 col1 = vec3(1.0,0.0,1.0);
uniform vec3 col2 = vec3(0.0,1.0,1.0);

uniform mat4 VP;

void main(){
    if(gl_VertexID%2==0){
        color = col1;
    }else{
        color = col2;
    }
    
    
    
    gl_Position = VP * vec4(vertPosition,1.0);
}