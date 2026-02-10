#version 460 core

restrict readonly layout(std430, binding = 0) buffer PositionTotalDistanceBuffer {
	vec4 position_total_distance_in[];
};
restrict readonly layout(std430, binding = 1) buffer ColorBuffer {
	uvec2 color_in[];
};
restrict readonly layout(std430, binding = 2) buffer SDFBuffer {
	vec4 sdf_in[];
};

noperspective layout(location=0) out vec4 segment_SDF_field_out;
noperspective layout(location=1) out vec3 color_out;
noperspective layout(location=2) out float total_distance_out;

void main() {
	const int per_vertex = (gl_BaseInstance + gl_InstanceID) * 5 + gl_VertexID;

	const vec4 position_total_distance = position_total_distance_in[per_vertex];
	gl_Position = vec4(position_total_distance.xyz,1.0);
	total_distance_out = position_total_distance.w;
	segment_SDF_field_out = sdf_in[per_vertex];

	const int per_segment = gl_BaseInstance + gl_InstanceID;

	color_out = unpackUnorm4x8(gl_VertexID > 1 ? color_in[per_segment].y : color_in[per_segment].x).xyz;
}