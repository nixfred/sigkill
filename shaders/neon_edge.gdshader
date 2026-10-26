// SIGKILL neon edge: near-black faces with glowing edges along the shape's outline.
// The edge maths, uniforms and the local_pos varying live in neon_edge.gdshaderinc, shared
// with code_rain.gdshader. This file is the plain look, used on the target dummies.
shader_type spatial;
render_mode specular_disabled;

#include "res://shaders/neon_edge.gdshaderinc"

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float cover = edge_cover(edge_distance());
	ALBEDO = face_color.rgb;
	ROUGHNESS = 1.0;
	EMISSION = edge_color.rgb * (edge_energy * cover);
}
