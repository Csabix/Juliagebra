#version 460 core

const vec4 vertices[6] = vec4[6](
    vec4(-1.0   ,-1.0   ,0.99    ,1.0),
    vec4(-1.0   , 1.0   ,0.99    ,1.0),
    vec4(1.0    ,-1.0   ,0.99    ,1.0),
    vec4(-1.0   ,1.0    ,0.99    ,1.0),
    vec4(1.0    ,1.0    ,0.99    ,1.0),
    vec4(1.0    ,-1.0   ,0.99    ,1.0)

);

void main(){

    gl_Position = vertices[gl_VertexID];

}