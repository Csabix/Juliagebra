#version 330 core

layout (points) in;
layout (triangle_strip, max_vertices = 4) out;

in float radius[];
in vec3 color[];

uniform mat4 VP;
uniform vec3 cam;

flat out float sphereRadius;
flat out vec3 sphereCenter;
flat out vec3 sphereColor;

const vec2 quadOffsets[4] = vec2[4](
    vec2(-1.0, -1.0),
    vec2(+1.0, -1.0),
    vec2(-1.0, +1.0),
    vec2(+1.0, +1.0)
);

void main() {
    vec3 center = gl_in[0].gl_Position.xyz;
    float r = radius[0];

    sphereRadius = r;
    sphereCenter = center;
    sphereColor = color[0];

    if (distance(cam, center) < r) {
        for(int i = 0; i < 4; i++) {
            gl_Position = vec4(quadOffsets[i],0.0,1.0);
            EmitVertex();
        }
    } else {
        vec3 a = normalize(cam - center); 
        vec3 b = vec3(0.0, 0.0, 1.0);

        vec3 v = cross(a, b);
        float c = dot(a, b);
        float k = 1.0 / (1.0 + c);

        mat3 R = c > -0.9999 ? mat3(
            v.x * v.x * k + c,   v.y * v.x * k - v.z, v.z * v.x * k + v.y,
            v.x * v.y * k + v.z, v.y * v.y * k + c,   v.z * v.y * k - v.x,
            v.x * v.z * k - v.y, v.y * v.z * k + v.x, v.z * v.z * k + c
        ) : mat3(-1.0);

        vec3 surfaceCenter = center + a * r;

        for(int i = 0; i < 4; i++) {
            vec3 offset = R * vec3(quadOffsets[i],0.0) * r;
            gl_Position = VP * vec4(surfaceCenter + offset, 1.0);
            EmitVertex();
        }
    }

    EndPrimitive();
}