#version 450
layout(location=0) in vec3  inPosition;
layout(location=1) in float inSize;
layout(location=2) in vec4  inColor;

flat out vec4  color;
flat out int   index;

uniform mat4 VP = mat4(1);

void main()
{
    gl_Position = VP  * vec4(inPosition, 1.0);
    gl_PointSize = 3*inSize;
    color = inColor;
    index = gl_VertexID;
}