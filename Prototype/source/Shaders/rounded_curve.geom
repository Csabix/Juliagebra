#version 330 core

layout (lines) in;
in vec3 color[];

layout (triangle_strip, max_vertices = 4) out;

uniform float lineWidth = 0.01;

// * Same 4 all.
out vec2 fromPos;
out vec2 toPos;

// * Different 4 all
out float leftDistance;
out float rightDistance;
out vec2 fragPos;
out vec3 pointCol;

uniform vec3 aColor = vec3(1.0,0.0,0.0);
uniform vec3 bColor = vec3(1.0,1.0,0.0);

void main(){

    vec4 from = gl_in[0].gl_Position;
    vec4 to   = gl_in[1].gl_Position;

    fromPos         = vec2(from.xy/from.w);
    toPos           = vec2(to.xy/to.w);
    
    vec2 fromTo     = toPos - fromPos;
    float fromToLen = length(fromTo);    
    vec2 fromToNorm = fromTo/fromToLen;
    vec2 fromToNormUp       = vec2(-fromToNorm.y,fromToNorm.x);
    vec2 fromToNormUpScaled = lineWidth*fromToNormUp;
    vec2 fromToNormScaled   = lineWidth*fromToNorm;

    vec2 bottomLeft         = fromPos  - fromToNormUpScaled - fromToNormScaled;    
    vec2 bottomRight        = toPos    - fromToNormUpScaled + fromToNormScaled;
    vec2 upperLeft          = fromPos  + fromToNormUpScaled - fromToNormScaled;
    vec2 upperRight         = toPos    + fromToNormUpScaled + fromToNormScaled;
    
    float leftCornerValue   = -lineWidth;
    float rightCornerValue  = fromToLen + lineWidth;

    gl_Position = vec4(bottomLeft*from.w,from.zw);
    leftDistance = leftCornerValue;
    rightDistance = rightCornerValue;
    fragPos = bottomLeft;
    pointCol = color[0];
    //pointCol = aColor;
    EmitVertex();

    gl_Position = vec4(bottomRight*to.w,to.zw);
    leftDistance = rightCornerValue;
    rightDistance = leftCornerValue;
    fragPos = bottomRight;
    pointCol = color[1];
    //pointCol = bColor;
    EmitVertex();
    
    gl_Position = vec4(upperLeft*from.w,from.zw);
    leftDistance = leftCornerValue;
    rightDistance = rightCornerValue;
    fragPos = upperLeft;
    pointCol = color[0];
    //pointCol = aColor;
    EmitVertex();
    
    gl_Position = vec4(upperRight*to.w,to.zw);
    leftDistance = rightCornerValue;
    rightDistance = leftCornerValue;
    fragPos = upperRight;
    pointCol = color[1];
    //pointCol = bColor;
    EmitVertex();

    EndPrimitive();
}