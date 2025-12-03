#version 460

layout (lines_adjacency) in;
layout (triangle_strip, max_vertices = 5) out;

layout(location=0) in float width_in[];
layout(location=1) in uint color_type_in[];
layout(location=2) in float total_distance_in[];

noperspective layout(location=0) out vec4 segment_SDF_field_out;
noperspective layout(location=1) out vec3 color_out;
flat          layout(location=2) out uint type_out;
noperspective layout(location=3) out float total_distance_out;
flat          layout(location=4) out vec3 light_dir;

layout(location = 0) uniform mat4 VP;
layout(location = 1) uniform vec3 Eye;
layout(location = 2) uniform vec4 W_H_NEAR_FAR;
layout(location = 3) uniform vec3 At;


void calcTBN() {
    vec3 A = gl_in[1].gl_Position.xyz;
    vec3 B = gl_in[2].gl_Position.xyz;
    vec3 BI = normalize(A-B);
    vec3 AE = normalize(A-Eye);
    vec3 T = normalize(cross(BI,AE));
    vec3 N = normalize(cross(T,BI));

    mat3 TBN = transpose(mat3(T,BI,N));
    light_dir = TBN * At;
}

void unpack(in uint color_type, out vec3 color, out uint type) {
    color.x = float((color_type & uint(0xFF000000)) >> 24) / 255.0;
    color.y = float((color_type & uint(0x00FF0000)) >> 16) / 255.0;
    color.z = float((color_type & uint(0x0000FF00)) >> 8 ) / 255.0;
    type = color_type & uint(0x000000FF);

    color = unpackUnorm4x8(color_type).xyz;
    type = uint(0);
}

void clampNDC(inout vec4 A, inout vec4 B) {
    float t0 = A.z + A.w;
    float t1 = B.z + B.w;
    if(t0 < 0.0){
        if(t1 < 0.0) return;
        A = mix(A, B, (0 - t0) / (t1 - t0));
    } if(t1 < 0.0){
        B = mix(B, A, (0 - t1) / (t0 - t1));
    }
}

void main() {
    calcTBN();
    // A - - B||||C - - D
    vec4 A4 = VP * gl_in[0].gl_Position;
    vec4 B4 = VP * gl_in[1].gl_Position;
    vec4 C4 = VP * gl_in[2].gl_Position;
    vec4 D4 = VP * gl_in[3].gl_Position;

    if (B4.z + B4.w < 0.0 && C4.z + C4.w < 0.0) return;

    if(!any(isnan(A4)))clampNDC(A4,B4);
    clampNDC(B4,C4);
    if(!any(isnan(D4)))clampNDC(C4,D4);

    A4 /= A4.w;
    B4 /= B4.w;
    C4 /= C4.w;
    D4 /= D4.w;

    vec2 WH = W_H_NEAR_FAR.xy;
    vec2 A = (A4.xy * 0.5 + 0.5) * WH;
    vec2 B = (B4.xy * 0.5 + 0.5) * WH;
    vec2 C = (C4.xy * 0.5 + 0.5) * WH;
    vec2 D = (D4.xy * 0.5 + 0.5) * WH;

    vec3 distances = vec3(distance(A,B), distance(C,B), distance(C,D));
    vec2 sdf_begin = vec2(-width_in[1]);
    vec3 sdf_end = vec3(distances.y + width_in[1]);
    float third_sdf_side = 1.0/0.0;

    vec2 AB_dir = (A-B) / distances.x; // A <-- B C D
    vec2 CB_dir = (C-B) / distances.y; // A B --> C D
    vec2 BC_dir = -CB_dir;             // A B <-- C D
    vec2 DC_dir = (D-C) / distances.z; // A B C --> D

    float AB_l = distance(A,B) / width_in[0];
    float CB_l = distance(C,B) / width_in[0];
    float BC_l = distance(B,C) / width_in[0];
    float DC_l = distance(D,C) / width_in[0];
    
    vec2 AB_dir_r = vec2( AB_dir.y,-AB_dir.x);
    vec2 CB_dir_r = vec2(-CB_dir.y, CB_dir.x);
    vec2 BC_dir_r = vec2( BC_dir.y,-BC_dir.x);
    vec2 DC_dir_r = vec2(-DC_dir.y, DC_dir.x);

    vec2 begin_inner_offset = -CB_dir + CB_dir_r;
    vec2 begin_outer_offset = -CB_dir - CB_dir_r;
    vec2 end_inner_offset   = -BC_dir + BC_dir_r;
    vec2 end_outer_offset   = -BC_dir - BC_dir_r;
    vec2 end_outer_third_offset = vec2(1.0/0.0);

    vec2 inner_offset_ABC = (1.0/dot(AB_dir_r,CB_dir)) * CB_dir + (1.0/dot(CB_dir_r,AB_dir)) * AB_dir;
    if (dot(AB_dir,CB_dir) <= -0.9999) inner_offset_ABC = CB_dir_r;
    vec2 inner_offset_BCD = (1.0/dot(BC_dir_r,DC_dir)) * DC_dir + (1.0/dot(DC_dir_r,BC_dir)) * BC_dir;
    if (dot(BC_dir,DC_dir) <= -0.9999) inner_offset_BCD = BC_dir_r;

    float ab = abs(dot(inner_offset_ABC,AB_dir));
    float cb = abs(dot(inner_offset_ABC,CB_dir));
    float bc = abs(dot(inner_offset_BCD,BC_dir));
    float dc = abs(dot(inner_offset_BCD,DC_dir));

    if (dot(AB_dir,CB_dir) <= 0.00006 && !any(isnan(A))) {
        // OBSTUSE
        begin_inner_offset =  inner_offset_ABC;
        begin_outer_offset = -inner_offset_ABC;

        if (dot(AB_dir,CB_dir) <= -0.9999) sdf_begin = vec2(0);
        else sdf_begin = vec2(dot(begin_inner_offset,-BC_dir),dot(begin_outer_offset,-BC_dir))*width_in[1];
    } else if (!any(isnan(A)) && ab < AB_l && cb < CB_l) {
        begin_inner_offset = inner_offset_ABC;
        begin_outer_offset = -CB_dir - CB_dir_r;

        if (dot(inner_offset_ABC, AB_dir + CB_dir) < 0.0) {
            begin_inner_offset = -CB_dir + CB_dir_r;
            begin_outer_offset = -inner_offset_ABC;
        }
        sdf_begin = vec2(dot(begin_inner_offset,-BC_dir),dot(begin_outer_offset,-BC_dir))*width_in[1];
    }
    
    if (dot(BC_dir,DC_dir) <= 0.00006) {
        // OBSTUSE
        end_inner_offset =  inner_offset_BCD;
        end_outer_offset = -inner_offset_BCD;

        if (dot(BC_dir,DC_dir) <= -0.9999) sdf_end.xy = vec2(distances.y);
        else {
            sdf_end.xy = vec2(dot(end_inner_offset,CB_dir),dot(end_outer_offset,CB_dir)) * width_in[1];
            sdf_end.xy += distances.y;
        }
    } else if (!any(isnan(D)) && bc < BC_l && dc < DC_l) {
        end_inner_offset = inner_offset_BCD;
        end_outer_offset = -BC_dir - BC_dir_r;
        end_outer_third_offset = -DC_dir - DC_dir_r;

        if (dot(inner_offset_BCD, BC_dir + DC_dir) < 0.0) {
            end_inner_offset = -BC_dir + BC_dir_r;
            end_outer_offset = -inner_offset_BCD;
            end_outer_third_offset = -DC_dir + DC_dir_r;
        }
        third_sdf_side = dot(end_outer_third_offset, BC_dir_r) * width_in[1];

        sdf_end = vec3(dot(end_inner_offset,CB_dir),dot(end_outer_offset,CB_dir),dot(end_outer_third_offset,CB_dir)) * width_in[1];
        sdf_end += distances.y;
    }

    vec2 length_conversion = 2.0 / WH * width_in[1];

    float len_X = width_in[1];
    float len_Y = distances.y;

    unpack(color_type_in[1], color_out, type_out);
    segment_SDF_field_out = vec4(len_X,sdf_begin.x,len_X,len_Y);
    total_distance_out = total_distance_in[1] + sdf_begin.x;
    gl_Position = vec4(B4.xy + begin_inner_offset * length_conversion, B4.z, 1.0);
    EmitVertex();

    segment_SDF_field_out = vec4(-len_X,sdf_begin.y,len_X,len_Y);
    total_distance_out = total_distance_in[1] + sdf_begin.y;
    gl_Position = vec4(B4.xy + begin_outer_offset * length_conversion, B4.z, 1.0);
    EmitVertex();
    unpack(color_type_in[2], color_out, type_out);

    segment_SDF_field_out = vec4(len_X,sdf_end.x,len_X,len_Y);
    total_distance_out = total_distance_in[1] + sdf_end.x;
    gl_Position = vec4(C4.xy + end_inner_offset * length_conversion, C4.z, 1.0);
    EmitVertex();

    segment_SDF_field_out = vec4(-len_X,sdf_end.y,len_X,len_Y);
    total_distance_out = total_distance_in[1] + sdf_end.y;
    gl_Position = vec4(C4.xy + end_outer_offset * length_conversion, C4.z, 1.0);
    EmitVertex();

    segment_SDF_field_out = vec4(third_sdf_side,sdf_end.z,len_X,len_Y);
    total_distance_out = total_distance_in[1] + sdf_end.z;
    gl_Position = vec4(C4.xy + end_outer_third_offset * length_conversion, C4.z, 1.0);
    EmitVertex();

    EndPrimitive();
}