#version 460 core

struct Data {
    uvec2 dist_col[4];
};

layout(std430, binding = 0) buffer DatBuff {
    Data data[];
};

layout(location = 0) out vec4 color_out;
layout(location = 1) out uint id_out;

layout(location = 0) uniform uint width;

layout (binding = 0) uniform sampler2D accum;
layout (binding = 1) uniform sampler2D reveal;

const float EPSILON = 0.00001f;

float max3(vec3 v) {
	return max(max(v.x, v.y), v.z);
}

void sort4(inout uvec2 dist_col[4]) {
    if (dist_col[0].x < dist_col[1].x) {
        uvec2 tmp = dist_col[0];
        dist_col[0] =  dist_col[1];
        dist_col[1] = tmp;
    }
    if (dist_col[2].x < dist_col[3].x) {
        uvec2 tmp = dist_col[2];
        dist_col[2] =  dist_col[3];
        dist_col[3] = tmp;
    }
    if (dist_col[0].x < dist_col[2].x) {
        uvec2 tmp = dist_col[0];
        dist_col[0] =  dist_col[2];
        dist_col[2] = tmp;
    }
    if (dist_col[1].x < dist_col[3].x) {
        uvec2 tmp = dist_col[1];
        dist_col[1] =  dist_col[3];
        dist_col[3] = tmp;
    }
    if (dist_col[1].x < dist_col[2].x) {
        uvec2 tmp = dist_col[1];
        dist_col[1] =  dist_col[2];
        dist_col[2] = tmp;
    }
}

void clear(uint pixelIdx) {
    Data pData;
    const uvec2 clear_value = uvec2(floatBitsToUint(0.0), packUnorm4x8(vec4(0)));
    pData.dist_col[0] = clear_value;
    pData.dist_col[1] = clear_value;
    pData.dist_col[2] = clear_value;
    pData.dist_col[3] = clear_value;
    data[pixelIdx] = pData;
}

void main() {
    uint pixelIdx = uint(gl_FragCoord.x) + uint(gl_FragCoord.y) * width;
    Data pData = data[pixelIdx];
    if (pData.dist_col[0].x == floatBitsToUint(0.0)) discard;
    clear(pixelIdx);

    color_out = vec4(0.0);

    // WEIGHTED BLENDNED
    const ivec2 coords = ivec2(gl_FragCoord.xy);
    if (pData.dist_col[0].x != floatBitsToUint(0.0)) {
	    float revealage = texelFetch(reveal, coords, 0).r;
        if (revealage != 1.0f) {
            vec4 accumulation = texelFetch(accum, coords, 0);
            if (isinf(max3(abs(accumulation.rgb))))
	    	    accumulation.rgb = vec3(accumulation.a);
            vec3 average_color = accumulation.rgb / max(accumulation.a, EPSILON);
            float alpha = 1.0f - revealage;
	        color_out = vec4(average_color * alpha, alpha);
        }
    }
    // TOP 4 layer
    sort4(pData.dist_col);
    for (int i = 0; i < 4; ++i) {
        vec4 color = unpackUnorm4x8(pData.dist_col[i].y);
        color.rgb *= color.a; 
        color_out.rgb = color.rgb + color_out.rgb * (1.0 - color.a);
        color_out.a = color.a + color_out.a * (1.0 - color.a);
    }

	id_out = uint(0);
}