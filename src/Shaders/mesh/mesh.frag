#version 460 core

#if defined(TRANSPARENT) || defined(OPAQUE)
    layout(location = 0) in vec3 in_normal;
    layout(location = 1) in vec3 in_color;
#endif

#if defined(ID)
layout(location = 0) out uint outInd;
#elif defined(OPAQUE)
layout(location = 0) out vec4 outCol;
#else
layout(location = 0) out vec4 accum;
layout(location = 1) out float reveal;
#endif

#if defined(TRANSPARENT) || defined(OPAQUE)
uniform vec3 lightDirCam;
uniform vec3 lightDirSide;
#endif

void main() {
    #if defined(ID)
    outInd = uint(0);
    #else
    vec3 normal = in_normal;
    vec3 fragColor = in_color;
    if(!gl_FrontFacing){
        fragColor = abs(1.0 - fragColor);
        normal *= -1.0;
    }

    float diffuse = (max(dot(normal,lightDirCam),0.0) * 0.3 + max(dot(normal,lightDirSide),0.0) * 0.7) * 0.8;
    float ambient = 0.2;
    #if defined(OPAQUE)
    outCol = vec4(fragColor * (diffuse + ambient), 1.0);
    #else
    vec4 color = vec4(fragColor * (diffuse + ambient), 0.5);

    float weight = max(min(1.0, max(max(color.r, color.g), color.b) * color.a), color.a) *
                   clamp(0.03 / (1e-5 + pow(gl_FragCoord.z / 200, 4.0)), 1e-2, 3e3);

    accum = vec4(color.rgb * color.a, color.a) * weight;
    reveal = color.a;
    #endif
    #endif
}