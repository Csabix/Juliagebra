#version 450

flat in vec4  color;
flat in int   index;

layout (location = 0) out vec4 outColor;
layout (location = 1) out int outIndex;

uniform vec3 lightDir = normalize(vec3(1));

void main()
{
    vec3 n = vec3(2*gl_PointCoord.x-1,1-2*gl_PointCoord.y,0);
    float d = dot(n.xy,n.xy);
    if(d>1) discard;
    n.z = sqrt(1-d);
    outColor = color*(dot(n,lightDir)*0.75+0.25);
    outIndex = index;
}