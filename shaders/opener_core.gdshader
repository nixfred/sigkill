shader_type spatial;
// The hottest process at the bottom of the pit (C40, scripts/opener/tree_fall.gd; PRD 5.7: "their top CPU process,
// named, pulses red at the bottom"): a core of red light, white-hot at its middle, beating twice a second at most
// (the beat is TreeFall's pulse_at(), shared with every wall it reddens).
render_mode unshaded, specular_disabled, fog_disabled;

uniform vec3 hot_color : source_color = vec3(1.0, 0.33, 0.42);
uniform float pulse = 0.0;

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 c = hot_color * (1.6 + 2.4 * pulse) * (0.4 + 0.6 * facing);
	c += vec3(1.0, 0.85, 0.85) * pow(facing, 6.0) * (0.8 + 1.2 * pulse);
	ALBEDO = c;
}
