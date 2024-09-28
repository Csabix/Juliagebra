#version 450
#define INOUT in // so i can copy this:

noperspective INOUT vec4  color;
noperspective INOUT vec2  fragCoord;
flat          INOUT float zDir;
flat          INOUT int   index;

layout (location = 0) out vec4 outColor;
layout (location = 1) out int outIndex;

uniform vec3 lightDir = normalize(vec3(1));
uniform vec2 resolution = vec2(640,480);

void main()
{
    outIndex = index;
    vec2 dpix = (gl_FragCoord.xy - fragCoord)/5; // TODO /width
    float dd = dot(dpix,dpix);
    if (dd>1) discard;
    vec3 n = normalize(vec3(dpix,zDir));
    outColor = color*(dot(n,lightDir)*0.75+0.25);
    outIndex = index;
}