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

flat out int isOutside;
out float sphereRadius;
out vec3 sphereCenter;
out vec3 worldPos;
flat out vec3 sphereColor;
layout (triangle_strip, max_vertices = 36) out;

void main(){
    vec3 center = gl_in[0].gl_Position.xyz;
    float r = radius[0];
    vec3 col = color[0];


    int isCamOutside = 1;
    
    vec3 corner1 = vec3(0.0);
    vec3 corner2 = vec3(0.0);
    vec3 corner3 = vec3(0.0);

    int splice1 = 0;
    int splice2 = 0;
    int splice3 = 0;

    if(distance(cam,center)>=r){
        isCamOutside = 1;
    }else{
        isCamOutside = 0;
    }

    if(isCamOutside==1){
        splice1 = 0;
        splice2 = 1;
        splice3 = 2;
    }else{
        splice1 = 0;
        splice2 = 2;
        splice3 = 1;
    }

    for(int i = 0; i<triCount; i++){    
        corner1 = corners[idx[i*3 + splice1]];
        corner2 = corners[idx[i*3 + splice2]];
        corner3 = corners[idx[i*3 + splice3]];

        isOutside = isCamOutside;
        sphereRadius = r;
        sphereCenter = center;
        worldPos = center + corner1 * r;
        sphereColor = col;
        gl_Position = VP * vec4(worldPos,1.0);
        EmitVertex(); 

        isOutside = isCamOutside;
        sphereRadius = r;
        sphereCenter = center;
        worldPos = center + corner2 * r;
        sphereColor = col;
        gl_Position = VP * vec4(worldPos,1.0);
        EmitVertex(); 

        isOutside = isCamOutside;
        sphereRadius = r;
        sphereCenter = center;
        worldPos = center + corner3 * r;
        sphereColor = col;
        gl_Position = VP * vec4(worldPos,1.0);
        EmitVertex(); 
    
        EndPrimitive();
    }
}