#version 330 core

const vec4 vertices[6] = vec4[6](
    vec4(-1.0   ,-1.0   ,-1.0    ,1.0),
    vec4(-1.0   , 1.0   ,-1.0    ,1.0),
    vec4(1.0    ,-1.0   ,-1.0    ,1.0),
    vec4(-1.0   ,1.0    ,-1.0    ,1.0),
    vec4(1.0    ,1.0    ,-1.0    ,1.0),
    vec4(1.0    ,-1.0   ,-1.0    ,1.0)

);

const vec2 textureCoords[6] = vec2[6](
    vec2(0.0    ,0.0),
    vec2(0.0    ,1.0),
    vec2(1.0    ,0.0),
    vec2(0.0    ,1.0),
    vec2(1.0    ,1.0),
    vec2(1.0    ,0.0)
);

out vec2 textureCoord;

void main(){
    gl_Position     = vertices[gl_VertexID];
    textureCoord    = textureCoords[gl_VertexID];
}