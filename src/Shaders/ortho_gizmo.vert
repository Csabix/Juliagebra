#version 330 core

out vec3 color;
flat out uint vertID;

uniform mat4 VP;

const vec2 translation = vec2(0.85,0.8);
const vec3 vertices[6] = vec3[](vec3(1,0,0),vec3(-1,0,0),vec3(0,1,0),vec3(0,-1,0),vec3(0,0,1),vec3(0,0,-1));
uint indices[6] = uint[](0,1,2,3,4,5);

void main(){
    float z_values[6];
    for (int i = 0; i < 6; ++i) {
        vec4 proj_point = VP * vec4(vertices[i],1.0);
        z_values[i] = proj_point.z / proj_point.w;
    }

    for (int i = 5; i > 0; --i)
    for (int j = 0; j < i; ++j) {
        if (z_values[j] < z_values[j + 1]) {
            float tmp_depth = z_values[j];
            z_values[j] = z_values[j + 1];
            z_values[j + 1] = tmp_depth;

            uint tmp_index = indices[j];
            indices[j] = indices[j + 1];
            indices[j + 1] = tmp_index;
        }
    }

    uint current_index = indices[gl_VertexID / 2];
    vertID = 0u;
    color = abs(vertices[current_index]);
    vec3 position = gl_VertexID % 2 == 0 ? vertices[current_index] : vec3(0);

    vec4 out_position = VP * vec4(position,1.0);
    out_position.xy += translation * out_position.w;
    gl_Position = out_position; 
}