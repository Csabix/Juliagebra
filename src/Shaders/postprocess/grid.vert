#version 460 core
#include "../ubo.glsl"

const vec4 positions[3] = vec4[3](
    vec4(-1.0, -1.0, 0.0, 1.0),
    vec4( 3.0, -1.0, 0.0, 1.0),
    vec4(-1.0,  3.0, 0.0, 1.0)
);

layout(location = 0) flat out float dist;
layout(location = 1) flat out float dist_10;

void main() {
    dist = distance(at(), eye());
    dist_10 = pow(10.0, floor(log(dist) / log(10.0)));

	gl_Position = vec4(positions[gl_VertexID].xy, -1.0, 1.0);
}