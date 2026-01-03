#version 460

in layout(location = 0) vec4 pos;
in layout(location = 1) float col;

in layout(location = 3) vec4 sdf_;

out float dis;
out vec4 color;
out vec4 sdf;

void main() {


	gl_Position = vec4(pos.xyz,1.0);
	color = unpackUnorm4x8(floatBitsToUint(col));
	dis = pos.w;
	sdf = sdf_;
}