#version 330 core

layout(location = 0) in vec2 vertPosition;


uniform mat4 p;
uniform float line = 0.0;
out vec3 col;

const vec3 cols[4] = vec3[4](
    vec3(0.9   ,0.0   ,0.0),
    vec3(0.0   ,0.9   ,0.0),
    vec3(0.0   ,0.0   ,0.9),
    vec3(0.9   ,0.0   ,0.9)
);

void main(){
    if (line == 0.0){
        gl_PointSize = 10.0;
        col = cols[gl_VertexID];
        gl_Position = vec4(vertPosition.xy,-1.0,1.0);
    }else{
        col = vec3(0.0,0.0,0.0);
        gl_Position = vec4(vertPosition.xy,-1.0,1.0);
    }

    
    
    
}