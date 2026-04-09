#version 460 core

layout(location = 0) out vec4 color_out;
layout(location = 1) out uint id_out;

layout(location = 0) flat in vec3 color_in;
layout(location = 1) flat in vec3 normal_in;
layout(location = 2) flat in uint id_in;

uniform vec3 lightDirCam;
uniform vec3 lightDirSide;

void main(){
    id_out = id_in;

    vec3 normal = normal_in;
    vec3 color = color_in;
    if (!gl_FrontFacing) {
        normal = -normal;
        color = vec3(1.0) - color;
    }

    float diffuse = (max(dot(normal,lightDirCam),0.0) * 0.3 + max(dot(normal,lightDirSide),0.0) * 0.7) * 0.8;
    float ambient = 0.2;
    color_out = vec4(color * (diffuse + ambient), 1.0);
}