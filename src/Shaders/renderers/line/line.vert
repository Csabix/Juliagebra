#version 460 core

restrict readonly layout(std430, binding = 1) buffer PositionTotalDistanceBuffer {
	vec4 position_total_distance_in[];
};
restrict readonly layout(std430, binding = 2) buffer ColorBuffer {
	uvec2 color_in[];
};
restrict readonly layout(std430, binding = 3) buffer LightDirBuffer {
	vec4 light_dir_in[];
};
restrict readonly layout(std430, binding = 4) buffer SDFBuffer {
	vec4 sdf_in[];
};
restrict readonly layout(std430, binding = 5) buffer RadiusBuffer {
	float radius_in[];
};

noperspective layout(location=0) out vec4 segment_SDF_field_out;
noperspective layout(location=1) out vec3 color_out;
noperspective layout(location=2) out float total_distance_out;
flat          layout(location=3) out vec3 light_dir_cam_out;
flat          layout(location=4) out vec3 light_dir_side_out;
noperspective layout(location=5) out float radius_out;

vec2 OctWrap(vec2 v) {
    return (1.0 - abs(v)) * sign(v);
}

vec3 Decode(vec2 encN) {
    encN = encN * 2.0 - 1.0;
    vec3 n;
    n.z = 1.0 - abs(encN.x) - abs(encN.y);
    n.xy = n.z >= 0.0 ? encN.xy : OctWrap(encN.xy);
    n = normalize(n);
    return n;
}

void main() {
	const int per_vertex = (gl_BaseInstance + gl_InstanceID) * 5 + gl_VertexID;

	const vec4 position_total_distance = position_total_distance_in[per_vertex];
	gl_Position = vec4(position_total_distance.xyz,1.0);
	total_distance_out = position_total_distance.w;
	segment_SDF_field_out = sdf_in[per_vertex];
	radius_out = radius_in[per_vertex];

	const int per_segment = gl_BaseInstance + gl_InstanceID;

	color_out = unpackUnorm4x8(gl_VertexID > 1 ? color_in[per_segment].y : color_in[per_segment].x).xyz;
	light_dir_cam_out = Decode(light_dir_in[per_segment].xy);
	light_dir_side_out = Decode(light_dir_in[per_segment].zw);
}