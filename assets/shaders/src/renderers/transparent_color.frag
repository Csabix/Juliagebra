#version 460 core
#extension GL_GOOGLE_include_directive : require
#include "../common_data.glsl"

restrict layout(std430, binding = 11) buffer DatDistBuff {
    uvec4 distances_b[];
};
restrict readonly layout(std430, binding = 12) buffer DatColorBuff {
    uvec4 colors_b[];
};

layout (location = 0) out vec4 frag;


layout (binding = 0) uniform sampler2D accum;
layout (binding = 1) uniform sampler2D reveal;

const float EPSILON = 0.00001f;

float max3(vec3 v) {
	return max(max(v.x, v.y), v.z);
}

void sort4(inout uvec2 dist_col[4]) {
    if (dist_col[0].x < dist_col[1].x) {
        uvec2 tmp = dist_col[0];
        dist_col[0] = dist_col[1];
        dist_col[1] = tmp;
    }
    if (dist_col[2].x < dist_col[3].x) {
        uvec2 tmp = dist_col[2];
        dist_col[2] = dist_col[3];
        dist_col[3] = tmp;
    }
    if (dist_col[0].x < dist_col[2].x) {
        uvec2 tmp = dist_col[0];
        dist_col[0] = dist_col[2];
        dist_col[2] = tmp;
    }
    if (dist_col[1].x < dist_col[3].x) {
        uvec2 tmp = dist_col[1];
        dist_col[1] = dist_col[3];
        dist_col[3] = tmp;
    }
    if (dist_col[1].x < dist_col[2].x) {
        uvec2 tmp = dist_col[1];
        dist_col[1] = dist_col[2];
        dist_col[2] = tmp;
    }
}

void main() {
    frag = vec4(0.0);
    // WEIGHTED BLENDNED
    const ivec2 coords = ivec2(gl_FragCoord.xy);
	float revealage = texelFetch(reveal, coords, 0).r;
    if (revealage != 1.0f) {
        vec4 accumulation = texelFetch(accum, coords, 0);
        if (isinf(max3(abs(accumulation.rgb))))
		    accumulation.rgb = vec3(accumulation.a);
        vec3 average_color = accumulation.rgb / max(accumulation.a, EPSILON);
        float alpha = 1.0f - revealage;
	    frag = vec4(average_color * alpha, alpha);
    }
    // TOP 4 layer
    const uint pixelIdx = uint(gl_FragCoord.x) + uint(gl_FragCoord.y) * width_u();
    uvec4 distances = distances_b[pixelIdx];
    if (distances.x != 0) {
        distances_b[pixelIdx] = uvec4(0);
        uvec4 colors = colors_b[pixelIdx];
        uvec2 dist_col[4] = uvec2[4](
            uvec2(distances.x,colors.x),uvec2(distances.y,colors.y),uvec2(distances.z,colors.z),uvec2(distances.w,colors.w)
        );
        sort4(dist_col);
        for (int i = 0; i < 4; ++i) {
        if (dist_col[i].x == 0) break;
            vec4 color = unpackUnorm4x8(dist_col[i].y);
            color.rgb *= color.a; 
            frag = color + frag * vec4(1.0 - color.a);
        }
    }
    if (frag.a == 0.0) discard;
}