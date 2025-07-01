#version 330 core

layout(location = 0) in vec3 vertPosition;

uniform mat4 VP;
uniform vec3 gizmoCenter = vec3(0.0,0.0,0.0);
uniform float gizmoScale = 1.0;

out vec3 endColor;
flat out uint gizmoID;


const vec3 endColors[3] = vec3[3](
    vec3(0.9   ,0.0   ,0.0),
    vec3(0.0   ,0.9   ,0.0),
    vec3(0.0   ,0.0   ,0.9)
);

const uint gizmoIDs[3] = uint[3](
    uint(1),
    uint(2),
    uint(3)
);

void main(){
    
    endColor = endColors[gl_VertexID];
    gizmoID = gizmoIDs[gl_VertexID];

    gl_PointSize = 25.0;
    
    vec4 SP = VP * vec4((vertPosition*gizmoScale) + gizmoCenter,1.0);
    gl_Position = SP;
}