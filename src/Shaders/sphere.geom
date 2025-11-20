#version 330 core

layout (points) in;
in float radius[];

uniform mat4 VP;

const vec3 corners[8] = vec3[8](
    vec3(0.5,0.5,0.5),
    vec3(0.5,-0.5,0.5),
    vec3(-0.5,-0.5,0.5),
    vec3(-0.5,0.5,0.5),

    vec3(0.5,0.5,-0.5),
    vec3(0.5,-0.5,-0.5),
    vec3(-0.5,-0.5,-0.5),
    vec3(-0.5,0.5,-0.5)
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

out vec3 sphereCenter;
out vec3 worldPos;
layout (triangle_strip, max_vertices = 36) out;

void main(){
    vec3 center = gl_in[0].gl_Position.xyz;
    float r = radius[0];

    for(int i = 0; i<triCount; i++){
        vec3 corner1 = corners[idx[i*3]] * 2;
        vec3 corner2 = corners[idx[i*3+1]] * 2;
        vec3 corner3 = corners[idx[i*3+2]] * 2;

        sphereCenter = center;
        worldPos = center + corner1;
        gl_Position = VP * vec4(worldPos,1.0);
        EmitVertex(); 

        sphereCenter = center;
        worldPos = center + corner2;
        gl_Position = VP * vec4(worldPos,1.0);
        EmitVertex(); 

        sphereCenter = center;
        worldPos = center + corner3;
        gl_Position = VP * vec4(worldPos,1.0);
        EmitVertex(); 
    
        EndPrimitive();
    }
}