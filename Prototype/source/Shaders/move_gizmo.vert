#version 330 core

layout(location = 0) in vec3 vertPosition;
layout(location = 1) in vec3 vertColor;
layout(location = 2) in float id;

uniform float nanVal;
uniform mat4 VP;
uniform vec3 gizmoCenter = vec3(0.0,0.0,0.0);
uniform float gizmoScale;
uniform uint selectedID;

out vec3 color;
flat out uint vertID;

void main(){
    color = vertColor;
    vertID = uint(id);

    if(selectedID != uint(0) && selectedID != uint(id)){
        gl_Position = vec4(nanVal);
    }else{
        gl_Position = VP * vec4((vertPosition*gizmoScale) + gizmoCenter,1.0);
    } 
}