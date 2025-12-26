#version 460

layout(location=0) in vec3  position_in;
layout(location=1) in float width_in;
layout(location=2) in uint  color_type_in;
layout(location=3) in float total_distance_in;

layout(location=0) out float width_out;
layout(location=1) out uint color_type_out;
layout(location=2) out float total_distance_out;

void main() {
	gl_Position = vec4(position_in,1.0);
	width_out = width_in;
	color_type_out = color_type_in;
	total_distance_out = total_distance_in;
}