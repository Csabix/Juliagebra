#version 330 core

layout (lines) in;
in vec3 color[];

layout (triangle_strip, max_vertices = 4) out;

uniform float lineWidth = 0.01;

// * Same 4 all.
//out vec2 fromPos;
//out vec2 toPos;

// * Different 4 all
//out float leftDistance;
//out float rightDistance;
//out vec2 fragPos;
out vec3 pointCol;

uniform vec3 aColor = vec3(1.0,0.0,0.0);
uniform vec3 bColor = vec3(1.0,1.0,0.0);

uniform mat4 V;
uniform mat4 P;

struct LineVecs{
    vec2 fromPos;
    vec2 toPos;
    vec2 up;
    vec2 right;
};

LineVecs calcVecs(vec4 from, vec4 to){
    
    vec2 fromPos = vec2(from.xy/from.w);
    vec2 toPos   = vec2(to.xy/to.w);
    
    vec2  fromToVec           = toPos - fromPos;
    float fromToVecLength     = length(fromToVec);    
    vec2  fromToVecNormalized = normalize(fromToVec);
    vec2  upVec               = vec2(-fromToVecNormalized.y,fromToVecNormalized.x);
    vec2  up                  = lineWidth*upVec;
    vec2  right               = lineWidth*fromToVecNormalized;

    return LineVecs(fromPos,toPos,up,right);
}


void main(){

    vec4 from = P * V * gl_in[0].gl_Position;
    vec4 to   = P * V * gl_in[1].gl_Position;

    LineVecs lv = calcVecs(from,to);

    vec2 bottomLeft         = lv.fromPos  - lv.up - lv.right;    
    vec2 bottomRight        = lv.toPos    - lv.up + lv.right;
    vec2 upperLeft          = lv.fromPos  + lv.up - lv.right;
    vec2 upperRight         = lv.toPos    + lv.up + lv.right;
    
    //float leftCornerValue   = -lineWidth;
    //float rightCornerValue  = fromToLen + lineWidth;

    gl_Position = vec4(bottomLeft*from.w,from.zw);
    pointCol = color[0];
    //leftDistance = leftCornerValue;
    //rightDistance = rightCornerValue;
    //fragPos = bottomLeft;
    
    //pointCol = aColor;
    EmitVertex();

    gl_Position = vec4(bottomRight*to.w,to.zw);
    pointCol = color[1];
    //leftDistance = rightCornerValue;
    //rightDistance = leftCornerValue;
    //fragPos = bottomRight;
    
    //pointCol = bColor;
    EmitVertex();
    
    gl_Position = vec4(upperLeft*from.w,from.zw);
    pointCol = color[0];
    //leftDistance = leftCornerValue;
    //rightDistance = rightCornerValue;
    //fragPos = upperLeft;
    
    //pointCol = aColor;
    EmitVertex();
    
    gl_Position = vec4(upperRight*to.w,to.zw);
    pointCol = color[1];

    //leftDistance = rightCornerValue;
    //rightDistance = leftCornerValue;
    //fragPos = upperRight;
    //pointCol = bColor;
    EmitVertex();

    EndPrimitive();
}