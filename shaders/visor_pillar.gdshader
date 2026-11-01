// SIGKILL Audit Trail visor (C43): a sever reshaping the arena (scripts/visor/visor_collapse.gd): hex columns of the
// floor thrust up round where a process stood, their caps lit in the visor's colour going to embers, and sinking back.
// Obsidian sides that take the scene's light, a hot band round each cap, faint seams down the sides. Its custom data:
// (glow, ember, 0, 0). Black ICE's dark dims it with the rest.
shader_type spatial;
render_mode cull_back, shadows_disabled;

#include "res://shaders/ruins_common.gdshaderinc"

uniform vec3 hue_tron : source_color = vec3(1.0, 0.5, 0.1);
uniform vec3 hue_cyber : source_color = vec3(0.35, 0.9, 1.0);
uniform vec3 hue_matrix : source_color = vec3(1.0, 0.32, 0.72);

varying vec3 v_local;
varying vec3 v_world;
varying vec4 v_data;

void vertex() {
	v_local = VERTEX;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_data = INSTANCE_CUSTOM;
}

void fragment() {
	vec3 w = ruins_weights(v_world);
	vec3 hue = hue_tron * w.x + hue_cyber * w.y + hue_matrix * w.z;
	vec3 ember = vec3(1.0, 0.36, 0.08);
	vec3 lit = mix(hue, ember, clamp(v_data.y, 0.0, 1.0));
	float cap = smoothstep(0.43, 0.5, v_local.y);
	float seam = smoothstep(0.92, 1.0, abs(fract(v_local.y * 6.0 - TIME * 1.5) - 0.5) * 2.0) * 0.25;
	ALBEDO = vec3(0.012, 0.016, 0.022);
	ROUGHNESS = 0.35;
	METALLIC = 0.6;
	EMISSION = lit * v_data.x * (cap * 5.0 + seam + 0.12) * mix(0.45, 1.0, arena_light);
}
