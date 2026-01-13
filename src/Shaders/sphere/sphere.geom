#version 330 core

layout (points) in;
in float radius[];
in vec3 color[];

uniform mat4 VP;
uniform vec3 cam;

const vec3 corners[8] = vec3[8](
    vec3(1.0,1.0,1.0),
    vec3(1.0,-1.0,1.0),
    vec3(-1.0,-1.0,1.0),
    vec3(-1.0,1.0,1.0),

    vec3(1.0,1.0,-1.0),
    vec3(1.0,-1.0,-1.0),
    vec3(-1.0,-1.0,-1.0),
    vec3(-1.0,1.0,-1.0)
);

const int idxCOUNT = 36;
const int triCount = idxCOUNT/3;
const int idx[idxCOUNT] = int[idxCOUNT](
    // ! top
    0,1,2,
    0,2,3,

    // ! bottom
    4,6,5,
    4,7,6,

    0,3,7,
    0,7,4,

    0,4,5,
    1,0,5,

    2,6,7,
    3,2,7,

    6,2,5,
    5,2,1
);

flat out float sphereRadius;
flat out vec3 sphereCenter;
out vec3 worldPos;
flat out vec3 sphereColor;
layout (triangle_strip, max_vertices = 36) out;

void main(){
    vec3 center = gl_in[0].gl_Position.xyz;
    float r = radius[0];
    vec3 col = color[0];

    vec3 corner1 = vec3(0.0);
    vec3 corner2 = vec3(0.0);
    vec3 corner3 = vec3(0.0);

    sphereRadius = r;
    sphereCenter = center;
    sphereColor = col;
    for(int i = 0; i<triCount; i++){    
        corner1 = corners[idx[i*3 + 0]];
        corner2 = corners[idx[i*3 + 1]];
        corner3 = corners[idx[i*3 + 2]];

        worldPos = center + corner1 * r;
        gl_Position = VP * vec4(worldPos,1.0);
        EmitVertex(); 

        worldPos = center + corner2 * r;
        gl_Position = VP * vec4(worldPos,1.0);
        EmitVertex(); 

        worldPos = center + corner3 * r;
        gl_Position = VP * vec4(worldPos,1.0);
        EmitVertex(); 
    
        EndPrimitive();
    }
}