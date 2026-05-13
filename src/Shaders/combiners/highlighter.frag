#version 460 core

out vec4 color_out;

uniform usampler2D idTex;

uniform uint highlighted_id;

void main() {
    uint id = texelFetch(idTex, ivec2(gl_FragCoord.xy), 0).r;
    if (id != highlighted_id) discard;

    color_out = vec4(1.0,1.0,0.0,0.3);
}