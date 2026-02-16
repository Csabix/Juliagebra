#version 330 core
#define PI 3.1415926538

layout(location = 0) out vec4 outCol;

uniform vec3 lightDirSideView;

uniform vec4 defaultColor = vec4(1.0,0.0,1.0,1.0);

void main(){

    vec4 drawColor = defaultColor;

    vec2 texCoord = gl_PointCoord;
    float centerDist = distance(texCoord,vec2(0.5,0.5));

    if (centerDist>0.5){
        discard;
    }

    float sinv = sin(gl_PointCoord.x * PI);
    float sinu = sin(gl_PointCoord.y * PI);
    float cosv = cos(gl_PointCoord.x * PI);
    float cosu = cos(gl_PointCoord.y * PI);
    vec3 normal = -vec3(sinv * cosu, cosu, sinv * sinu);

    float diffuse = max(0.0,dot(normal,vec3(0,0,-1.0)) * 0.2 + max(dot(normal,lightDirSideView),0.0) * 0.8) * 0.8;
    float ambient = 0.2;
    outCol = vec4(drawColor.xyz * (diffuse + ambient), 1.0);
}