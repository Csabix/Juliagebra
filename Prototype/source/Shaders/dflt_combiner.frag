#version 330 core

uniform sampler2D screenTexture;

in vec2 textureCoord;

out vec4 color;

void main(){
    color = texture(screenTexture,textureCoord);
    // TODO: id alapján itt színezni
    // TODO: hoverID, selectedID
}