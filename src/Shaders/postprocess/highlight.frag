#version 460 core
#include "../ubo.glsl"

layout(location = 0) out vec4 color_out;
layout(binding = 0) uniform usampler2D idTex;

void main() {
    uint id = texelFetch(idTex, ivec2(gl_FragCoord.xy), 0).r;
    if (id != hovered_id()) discard;

    color_out = vec4(1.0,1.0,0.0,0.3);
}