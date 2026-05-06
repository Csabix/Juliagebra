#version 330 core

uniform float nanVal;
uniform mat4 VP;
uniform vec3 gizmoCenter = vec3(0.0,0.0,0.0);
uniform float gizmoScale;
uniform uint selectedID;
uniform uint gizmo_axis;

const vec3 vertices[6] = vec3[6](vec3(1,0,0),vec3(-1,0,0),vec3(0,1,0),vec3(0,-1,0),vec3(0,0,1),vec3(0,0,-1));
const uint ids[6] = uint[6](uint(1),uint(1),uint(2),uint(2),uint(3),uint(3));
const uint axes[3] = uint[3](uint(1),uint(2),uint(4));
uint indices[6] = uint[6](uint(0),uint(1),uint(2),uint(3),uint(4),uint(5));

flat out vec3 color_v_out;
flat out uint id_v_out;

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
    color_v_out = abs(vertices[current_index]);
    vec3 position = gl_VertexID % 2 == 0 ? vertices[current_index] : vec3(0);
    id_v_out = ids[current_index];
    if (((axes[current_index >> 1] & gizmo_axis) == uint(0)) || (selectedID != uint(0) && selectedID != id_v_out)) {
        position = vec3(nanVal);
    }
    gl_Position = VP * vec4(position*gizmoScale + gizmoCenter, 1.0);
}