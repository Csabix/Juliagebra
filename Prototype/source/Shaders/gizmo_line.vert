#version 330 core

layout(location = 0) in vec3 vertPosition;

uniform mat4 VP;
uniform float scaleFactor;
uniform vec3 gizmoCenter = vec3(0.0,0.0,0.0);

// ! xx-yy-zz
// ! fb-lr-ud
// ! up-left-forward

out vec3 lineColor;

const vec3 lineColors[6] = vec3[6](
    vec3(0.5   ,0.5   ,0.5),
    vec3(1.0   ,0.0   ,0.0),
    
    vec3(0.5   ,0.5   ,0.5),
    vec3(0.0   ,1.0   ,0.0),
    
    vec3(0.5   ,0.5   ,0.5),
    vec3(0.0   ,0.0   ,1.0)
);

flat out uint gizmoID;

const uint gizmoIDs[6] = uint[6](
    uint(1),
    uint(1),
    
    uint(2),
    uint(2),
    
    uint(3),
    uint(3)
);

void main(){

    lineColor = lineColors[gl_VertexID];
    gizmoID = gizmoIDs[gl_VertexID];

    vec3 scaledPos = vertPosition * scaleFactor;
    // * SP = screenPos
    vec4 SP = VP * vec4(scaledPos + gizmoCenter,1.0);
    gl_Position = SP;
}