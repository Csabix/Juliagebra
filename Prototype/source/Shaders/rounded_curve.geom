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

LineVecs calcLineVecs(vec4 from, vec4 to){
    
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

struct CornerVecs{
    vec2 bo_le;
    vec2 bo_ri;
    vec2 up_le;
    vec2 up_ri;
};

CornerVecs calcCornerVecs(LineVecs lv){
    vec2 bo_le  = lv.fromPos  - lv.up - lv.right;    
    vec2 bo_ri  = lv.toPos    - lv.up + lv.right;
    vec2 up_le  = lv.fromPos  + lv.up - lv.right;
    vec2 up_ri  = lv.toPos    + lv.up + lv.right;

    return CornerVecs(bo_le,bo_ri,up_le,up_ri);
}

vec4 finalCalc(vec2 corner, vec4 og){
    return vec4(corner*og.w,og.zw);
}

void main(){

    vec4 from = P * V * gl_in[0].gl_Position;
    vec4 to   = P * V * gl_in[1].gl_Position;

    LineVecs lv = calcLineVecs(from,to);
    CornerVecs cv = calcCornerVecs(lv);
    
    gl_Position = finalCalc(cv.bo_le,from);
    pointCol = color[0];
    EmitVertex();

    gl_Position = finalCalc(cv.bo_ri,to);
    pointCol = color[1];
    EmitVertex();
    
    gl_Position = finalCalc(cv.up_le,from);
    pointCol = color[0];
    EmitVertex();

    gl_Position = finalCalc(cv.up_ri,to);
    pointCol = color[1];
    EmitVertex();

    EndPrimitive();    

    /*
        float leftCornerValue   = -lineWidth;
        float rightCornerValue  = fromToLen + lineWidth;
    */
    /*
        leftDistance = leftCornerValue;
        rightDistance = rightCornerValue;
        fragPos = bottomLeft;    
        pointCol = aColor;
    */
    /*
        leftDistance = rightCornerValue;
        rightDistance = leftCornerValue;
        fragPos = bottomRight;
        pointCol = bColor;
    */
    /*
        leftDistance = leftCornerValue;
        rightDistance = rightCornerValue;
        fragPos = upperLeft;
        pointCol = aColor;
    */
    /*
        leftDistance = rightCornerValue;
        rightDistance = leftCornerValue;
        fragPos = upperRight;
        pointCol = bColor;
    */
}