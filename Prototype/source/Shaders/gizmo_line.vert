#version 330 core

layout(location = 0) in vec3 vertPosition;

uniform mat4 VP;
uniform vec3 gizmoCenter = vec3(0.0,0.0,0.0);
uniform float gizmoScale = 1.0;

out vec3 lineColor;
flat out uint gizmoID;

const vec3 lineColors[12] = vec3[12](
    vec3(0.5   ,0.5   ,0.5),
    vec3(1.0   ,0.0   ,0.0),
    vec3(0.5   ,0.5   ,0.5),
    vec3(1.0   ,0.0   ,0.0),
    
    vec3(0.5   ,0.5   ,0.5),
    vec3(0.0   ,1.0   ,0.0),
    vec3(0.5   ,0.5   ,0.5),
    vec3(0.0   ,1.0   ,0.0),
    
    vec3(0.5   ,0.5   ,0.5),
    vec3(0.0   ,0.0   ,1.0),
    vec3(0.5   ,0.5   ,0.5),
    vec3(0.0   ,0.0   ,1.0)
);


const uint gizmoIDs[12] = uint[12](
    uint(1),
    uint(1),
    uint(1),
    uint(1),
    
    uint(2),
    uint(2),
    uint(2),
    uint(2),
    
    uint(3),
    uint(3),
    uint(3),
    uint(3)
);

void main(){

    lineColor = lineColors[gl_VertexID];
    gizmoID = gizmoIDs[gl_VertexID];

    vec4 SP = VP * vec4((vertPosition*gizmoScale) + gizmoCenter,1.0);
    gl_Position = SP;
}