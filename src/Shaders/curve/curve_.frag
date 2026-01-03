#version 460 core

layout(location = 0) out vec4 outCol;

in float dis;
in vec4 color;
in vec4 sdf;

float sdCapsule( vec2 p, float r, float h ) {
    p.x = abs(p.x);
    if( p.y < 0.0 ) return length(p) - r;
    if( p.y > h ) return length(p-vec2(0.0,h)) - r;
    return p.x - r;
}

float sdCircle( vec2 p, float r ) {
    return length(p) - r;
}

void main(){
    vec2 p = sdf.xy;
    float lenX = sdf.z;
    float lenY = sdf.w;
    float d = sdCapsule(p,lenX,lenY);
    d = max(d,sdCircle(vec2(p.x, mod(dis,lenX * 3.0) - lenX), lenX));

    float alpha = 1.0 - smoothstep(max(-0.2*lenX,-2.0), 0.0, d);

    outCol = vec4(color.xyz, alpha);

    //if (d > 0.0) discard;
    outCol = vec4(vec3(mod(dis,lenX * 3.0)/(lenX * 3.0)),1);
}