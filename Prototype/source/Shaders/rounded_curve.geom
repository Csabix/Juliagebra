#version 330 core

layout (lines) in;
in vec3 color[];

layout (triangle_strip, max_vertices = 4) out;

uniform float lineWidth = 0.01;

// * Same 4 all.
out vec2 fromPos;
out vec2 toPos;

// * Different 4 all
out float leftDist;
out float rightDist;
out vec2 fragPos;
out vec3 pointCol;

uniform vec3 aColor = vec3(1.0,0.0,0.0);
uniform vec3 bColor = vec3(1.0,1.0,0.0);

#define LVT vec2

struct LineVecs{
    float leftValue;
    float rightValue;
    LVT fromPos;
    LVT toPos;
    LVT up;
    LVT right;
};

#define LVT_FALSE LineVecs(LVT(0),LVT(0),LVT(0),LVT(0))

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

    float leftValue   = -lineWidth;
    float rightValue  = fromToVecLength + lineWidth;

    return LineVecs(leftValue,rightValue,fromPos,toPos,up,right);
}

CornerVecs calcCornerVecs(LineVecs lv){
    CVT bo_le  = lv.fromPos  - lv.up - lv.right;    
    CVT bo_ri  = lv.toPos    - lv.up + lv.right;
    CVT up_le  = lv.fromPos  + lv.up - lv.right;
    CVT up_ri  = lv.toPos    + lv.up + lv.right;

    return CornerVecs(bo_le,bo_ri,up_le,up_ri);
}

vec4 finalCalc(CVT corner, vec4 og){
    return vec4(corner.xy,og.z/og.w,1.0);
}

void main(){

    vec4 from = gl_in[0].gl_Position;
    vec4 to   = gl_in[1].gl_Position;

    float t0 = from.z + from.w;
    float t1 = to.z + to.w;
    if(t0 < 0.0){
        if(t1 < 0.0)
            return;
        // ! t0<0<t1
        from = mix(from, to, (0 - t0) / (t1 - t0));
    }
    if(t1 < 0.0){
        // ! t1<0<t0
        to = mix(to, from, (0 - t1) / (t0 - t1));
    }

    LineVecs lv = calcLineVecs(from,to);
    CornerVecs cv = calcCornerVecs(lv);
    
    fromPos = lv.fromPos;
    toPos = lv.toPos;


    gl_Position = finalCalc(cv.bo_le,from);
    fragPos     = cv.bo_le; 
    leftDist    = lv.leftValue;
    rightDist   = lv.rightValue;
    pointCol    = color[0];       
    EmitVertex();

    gl_Position = finalCalc(cv.bo_ri,to);
    fragPos     = cv.bo_ri; 
    leftDist    = lv.rightValue;
    rightDist   = lv.leftValue;
    pointCol    = color[1];  
    EmitVertex();
    
    gl_Position = finalCalc(cv.up_le,from);
    fragPos     = cv.up_le; 
    leftDist    = lv.leftValue;
    rightDist   = lv.rightValue;
    pointCol    = color[0]; 
    EmitVertex();

    gl_Position = finalCalc(cv.up_ri,to);
    fragPos     = cv.up_ri; 
    leftDist    = lv.rightValue;
    rightDist   = lv.leftValue;
    pointCol    = color[1]; 
    EmitVertex();

    EndPrimitive();    

}