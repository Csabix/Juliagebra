#version 450
layout(location=0) in vec3  inPosition;
layout(location=1) in float inLength;
layout(location=2) in vec3  inDirection;
layout(location=3) in vec4  inColor;


#define INOUT out // so i can copy this:

noperspective INOUT vec4  color;
noperspective INOUT vec2  fragCoord;
flat          INOUT float zDir;
flat          INOUT int   index;

uniform mat4 VP = mat4(1);
uniform vec2 resolution = vec2(640,480);

void main()
{
    color = inColor;
    gl_Position = VP * vec4(inPosition,1);
    fragCoord  = (gl_Position.xy/gl_Position.w*0.5 + 0.5)*resolution;
    vec4 dir = VP * vec4(inDirection,0);
    // dir.xyz /= dir.w; // methinks not needed
    zDir = sqrt(1-dir.z*dir.z/dot(dir.xyz,dir.xyz));
    index = gl_VertexID;
}