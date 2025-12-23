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
flat          layout(location=4) out vec3 light_dir_cam_out;
flat          layout(location=5) out vec3 light_dir_side_out;

layout(location = 0) uniform mat4 VP;
layout(location = 1) uniform vec3 Eye;
layout(location = 2) uniform vec4 W_H_NEAR_FAR;
layout(location = 3) uniform vec3 lightDirCam;
layout(location = 4) uniform vec3 lightDirSide;


void calcTBN() {
    vec3 A = gl_in[1].gl_Position.xyz;
    vec3 B = gl_in[2].gl_Position.xyz;
    vec3 BI = normalize(A-B);
    vec3 AE = normalize(A-Eye);
    vec3 T = normalize(cross(BI,AE));
    vec3 N = normalize(cross(T,BI));

    mat3 TBN = transpose(mat3(T,BI,N));
    light_dir_cam_out = TBN * lightDirCam;
    light_dir_side_out = TBN * lightDirSide;
}

void unpack(in uint color_type, out vec3 color, out uint type) {
    color = unpackUnorm4x8(color_type).xyz;
    type = uint(0);
}

void clampNDC(inout vec4 from, inout vec4 to) {
    float t0 = from.z + from.w;
    float t1 = to.z + to.w;
    if(t1 < 0.0) {
        to = mix(to, from, t1 / (t1 - t0));
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

    vec3 color_B, color_C;
    float distace_B = total_distance_in[1];
    unpack(color_type_in[1], color_B, type_out);
    float distace_C = total_distance_in[2];
    unpack(color_type_in[2], color_C, type_out);

    float t0 = B4.z + B4.w;
    float t1 = C4.z + C4.w;
    if(t0 < 0.0){
        B4 = mix(B4, C4, t0 / (t0 - t1));
        distace_B = mix(distace_B, distace_C, t0 / (t0 - t1));
        color_B = mix(color_B, color_C, t0 / (t0 - t1));
    } else if(t1 < 0.0){
        C4 = mix(C4, B4, t1 / (t1 - t0));
        distace_C = mix(distace_C, distace_B, t1 / (t1 - t0));
        color_C = mix(color_C, color_B, t1 / (t1 - t0));
    }
    if (t0 < 0.0 || t1 < 0.0) { // DIRTY FIX
        t0 = B4.x + B4.w;
        t1 = C4.x + C4.w;
        if(t0 < 0.0 && t1 >= 0.0) {
            B4 = mix(B4, C4, t0 / (t0 - t1));
            distace_B = mix(distace_B, distace_C, t0 / (t0 - t1));
            color_B = mix(color_B, color_C, t0 / (t0 - t1));
        } else if(t1 < 0.0 && t0 >= 0.0) {
            C4 = mix(C4, B4, t1 / (t1 - t0));
            distace_C = mix(distace_C, distace_B, t1 / (t1 - t0));
            color_C = mix(color_C, color_B, t1 / (t1 - t0));
        }
    }
    clampNDC(B4,A4);
    clampNDC(C4,D4);

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
    vec2 DC_dir = (D-C) / distances.z; // A B C --> D
    
    vec2 AB_dir_r = vec2( AB_dir.y,-AB_dir.x);
    vec2 CB_dir_r = vec2(-CB_dir.y, CB_dir.x);
    vec2 DC_dir_r = vec2(-DC_dir.y, DC_dir.x);

    vec2 begin_inner_offset = -CB_dir + CB_dir_r;
    vec2 begin_outer_offset = -CB_dir - CB_dir_r;
    vec2 end_inner_offset   =  CB_dir + CB_dir_r;
    vec2 end_outer_offset   =  CB_dir - CB_dir_r;
    vec2 end_outer_third_offset = vec2(1.0/0.0);

    vec2 inner_offset_ABC = (1.0/dot(AB_dir_r,CB_dir)) * CB_dir + (1.0/dot(CB_dir_r,AB_dir)) * AB_dir;
    if (dot(AB_dir,CB_dir) <= -0.9999) inner_offset_ABC = CB_dir_r;
    vec2 inner_offset_BCD = (1.0/dot(CB_dir_r,DC_dir)) * DC_dir + (1.0/dot(DC_dir_r,-CB_dir)) * -CB_dir;
    if (dot(-CB_dir,DC_dir) <= -0.9999) inner_offset_BCD = CB_dir_r;

    if (!any(isnan(A)) && distances.y > 1.0) {
        if (dot(AB_dir,CB_dir) <= 0.00006) {
            // OBSTUSE
            begin_inner_offset =  inner_offset_ABC;
            begin_outer_offset = -inner_offset_ABC;

            if (dot(AB_dir,CB_dir) <= -0.9999) sdf_begin = vec2(0);
            else sdf_begin = vec2(dot(begin_inner_offset,CB_dir),dot(begin_outer_offset,CB_dir))*width_in[1];
        } else {
            // ACUTE
            float AB_l = distances.x / width_in[1];
            float CB_l = distances.y / width_in[1];
            float ab = abs(dot(inner_offset_ABC,AB_dir));
            float cb = abs(dot(inner_offset_ABC,CB_dir));
            if (ab < AB_l && cb < CB_l) {
                begin_inner_offset = inner_offset_ABC;
                begin_outer_offset = -CB_dir - CB_dir_r;

                if (dot(inner_offset_ABC, AB_dir + CB_dir) < 0.0) {
                    begin_inner_offset = -CB_dir + CB_dir_r;
                    begin_outer_offset = -inner_offset_ABC;
                }
                sdf_begin = vec2(dot(begin_inner_offset,CB_dir),dot(begin_outer_offset,CB_dir))*width_in[1];
            }
        }
    }
    
    if (!any(isnan(D))) {
        if (dot(-CB_dir,DC_dir) <= 0.00006) {
            // OBSTUSE
            end_inner_offset =  inner_offset_BCD;
            end_outer_offset = -inner_offset_BCD;

            if (dot(-CB_dir,DC_dir) <= -0.9999) sdf_end.xy = vec2(distances.y);
            else {
                sdf_end.xy = vec2(dot(end_inner_offset,CB_dir),dot(end_outer_offset,CB_dir)) * width_in[1];
                sdf_end.xy += distances.y;
            }
        } else {
            // ACUTE
            float BC_l = distances.y / width_in[1];
            float DC_l = distances.z / width_in[1];
            float bc = abs(dot(inner_offset_BCD,-CB_dir));
            float dc = abs(dot(inner_offset_BCD,DC_dir));
            if (bc < BC_l && dc < DC_l) {
                end_inner_offset = inner_offset_BCD;
                end_outer_offset = CB_dir - CB_dir_r;
                end_outer_third_offset = -DC_dir - DC_dir_r;

                if (dot(inner_offset_BCD, -CB_dir + DC_dir) < 0.0) {
                    end_inner_offset = CB_dir + CB_dir_r;
                    end_outer_offset = -inner_offset_BCD;
                    end_outer_third_offset = -DC_dir + DC_dir_r;
                }
                third_sdf_side = dot(end_outer_third_offset, CB_dir_r) * width_in[1];

                sdf_end = vec3(dot(end_inner_offset,CB_dir),dot(end_outer_offset,CB_dir),dot(end_outer_third_offset,CB_dir)) * width_in[1];
                sdf_end += distances.y;
            }
        }
    }

    vec2 length_conversion = 2.0 / WH * width_in[1];

    segment_SDF_field_out.z = width_in[1];
    segment_SDF_field_out.w = distances.y;

    color_out = color_B;
    segment_SDF_field_out.xy = vec2(width_in[1],sdf_begin.x);
    total_distance_out = distace_B + sdf_begin.x;
    gl_Position = vec4(B4.xy + begin_inner_offset * length_conversion, B4.z, 1.0);
    EmitVertex();

    segment_SDF_field_out.xy = vec2(-width_in[1],sdf_begin.y);
    total_distance_out = distace_B + sdf_begin.y;
    gl_Position = vec4(B4.xy + begin_outer_offset * length_conversion, B4.z, 1.0);
    EmitVertex();

    color_out = color_C;
    segment_SDF_field_out.xy = vec2(width_in[1],sdf_end.x);
    total_distance_out = distace_B + sdf_end.x;
    gl_Position = vec4(C4.xy + end_inner_offset * length_conversion, C4.z, 1.0);
    EmitVertex();

    segment_SDF_field_out.xy = vec2(-width_in[1],sdf_end.y);
    total_distance_out = distace_B + sdf_end.y;
    gl_Position = vec4(C4.xy + end_outer_offset * length_conversion, C4.z, 1.0);
    EmitVertex();

    segment_SDF_field_out.xy = vec2(third_sdf_side,sdf_end.z);
    total_distance_out = distace_B + sdf_end.z;
    gl_Position = vec4(C4.xy + end_outer_third_offset * length_conversion, C4.z, 1.0);
    EmitVertex();

    EndPrimitive();
}