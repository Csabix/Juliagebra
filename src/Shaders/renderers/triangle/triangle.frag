#version 460 core

#ifdef TRANSPARENT
#extension GL_ARB_fragment_shader_interlock : require
layout(pixel_interlock_unordered) in;

struct PixelData {
    uvec2 dist_col[4];
    uvec2 dist_id;
};

coherent layout(std430, binding = 0) buffer PixelDataBuffer {
    PixelData data[];
};

layout(location = 0) out vec4 accum;
layout(location = 1) out float reveal;

uniform uint width;
#else
layout(location = 0) out vec4 color_out;
layout(location = 1) out uint id_out;
#endif

layout(location = 0) flat in vec4 color_in;
layout(location = 1) flat in vec3 normal_in;
layout(location = 2) flat in uint id_in;

uniform vec3 lightDirCam;
uniform vec3 lightDirSide;

void main(){
    vec3 normal = normal_in;
    vec3 color = color_in.rgb;
    float alpha = color_in.a;
    if (!gl_FrontFacing) {
        normal = -normal;
        color = vec3(1.0) - color;
    }

    float diffuse = (max(dot(normal,lightDirCam),0.0) * 0.3 + max(dot(normal,lightDirSide),0.0) * 0.7) * 0.8;
    float ambient = 0.2;
    vec4 lit_color = vec4(color * (diffuse + ambient), alpha);

#ifdef TRANSPARENT
    uint pixelIdx = uint(gl_FragCoord.x) + uint(gl_FragCoord.y) * width;
    uint packedColor = packUnorm4x8(lit_color);

    uint max_index;
    uvec2 max_dist_col = uvec2(uint(0));

    beginInvocationInterlockARB();
    const float dist_id_x = data[pixelIdx].dist_id.x;
    if (dist_id_x == uint(0) || dist_id_x > floatBitsToUint(gl_FragCoord.z))
        data[pixelIdx].dist_id = uvec2(floatBitsToUint(gl_FragCoord.z), id_in);
    for (uint i = 0; i < 4; ++i) {
        const uvec2 dist_col = data[pixelIdx].dist_col[i];
        if (uint(0) == dist_col.x) {
            max_dist_col = dist_col;
            max_index = i;
            break;
        } else if (dist_col.x > max_dist_col.x) {
            max_dist_col = dist_col;
            max_index = i;
        }
    }

    if (floatBitsToUint(gl_FragCoord.z) < max_dist_col.x || uint(0) == max_dist_col.x) {
        data[pixelIdx].dist_col[max_index] = uvec2(floatBitsToUint(gl_FragCoord.z), packedColor);
    } else {
        max_dist_col = uvec2(floatBitsToUint(gl_FragCoord.z), packedColor);
    }

    endInvocationInterlockARB();

    if (uint(0) == max_dist_col.x) discard;

    vec4 displaced = unpackUnorm4x8(max_dist_col.y);
    float d = uintBitsToFloat(max_dist_col.x) / 200.0;
    float weight = max(max(max(displaced.r, displaced.g), displaced.b) * displaced.a, displaced.a) *
               clamp(0.03 / (1e-5 + d*d*d*d), 1e-2, 3e3);
    accum = vec4(displaced.rgb * displaced.a, displaced.a) * weight;
    reveal = displaced.a;
#else
    id_out = id_in;
    color_out = vec4(color * (diffuse + ambient), 1.0);
#endif
}
