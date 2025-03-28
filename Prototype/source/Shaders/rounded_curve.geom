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

#define LVT vec2

struct LineVecs{
    LVT fromPos;
    LVT toPos;
    LVT up;
    LVT right;
};

#define CVT vec2

struct CornerVecs{
    CVT bo_le;
    CVT bo_ri;
    CVT up_le;
    CVT up_ri;
};

LineVecs calcLineVecs(vec4 from, vec4 to){
    
    LVT fromPos = LVT(from.xy/from.w);
    LVT toPos   = LVT(to.xy/to.w);
    
    LVT  fromToVec           = toPos - fromPos;
    float fromToVecLength    = length(fromToVec);    
    LVT  fromToVecNormalized = normalize(fromToVec);
    LVT  upVec               = LVT(-fromToVecNormalized.y,fromToVecNormalized.x);
    LVT  up                  = lineWidth*upVec;
    LVT  right               = lineWidth*fromToVecNormalized;

    return LineVecs(fromPos,toPos,up,right);
}

CornerVecs calcCornerVecs(LineVecs lv){
    CVT bo_le  = lv.fromPos  - lv.up - lv.right;    
    CVT bo_ri  = lv.toPos    - lv.up + lv.right;
    CVT up_le  = lv.fromPos  + lv.up - lv.right;
    CVT up_ri  = lv.toPos    + lv.up + lv.right;

    return CornerVecs(bo_le,bo_ri,up_le,up_ri);
}

vec4 finalCalc(CVT corner, vec4 og){
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