// SIGKILL viewmodel metal (A1): the dark body of a weapon held in first person. Gunmetal with
// machined panel lines, or hex cells, cut in the model's own space so they ride on the weapon as
// it moves, and a rim of the weapon's own neon round its silhouette so a dark weapon still reads
// against the void. No textures: every line is computed, anti-aliased with fwidth.
// Defaults only mirror scripts/palette.gd so the material previews in the editor. palette.gd sets
// every value at runtime and is the single source.
shader_type spatial;

uniform vec4 base_color : source_color = vec4(0.047, 0.063, 0.078, 1.0);
uniform vec4 neon : source_color = vec4(0.098, 0.827, 0.773, 1.0);
uniform float metallic_amount : hint_range(0.0, 1.0) = 0.75;
uniform float roughness_amount : hint_range(0.0, 1.0) = 0.32;
uniform float rim_energy : hint_range(0.0, 16.0) = 0.06;
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;
uniform float seam_energy : hint_range(0.0, 16.0) = 0.05;
uniform float cell_m : hint_range(0.005, 0.5) = 0.045;
uniform float line_m : hint_range(0.0005, 0.02) = 0.0016;
uniform bool hex_cells = false;

varying vec3 model_pos;
varying vec3 model_normal;

void vertex() {
	model_pos = VERTEX;
	model_normal = NORMAL;
}

// Distance to the nearest cell border, in cells: square panels, or hexagons of unit width.
float border(vec2 p) {
	if (hex_cells) {
		const vec2 r = vec2(1.0, 1.7320508);
		vec2 a = mod(p, r) - r * 0.5;
		vec2 b = mod(p - r * 0.5, r) - r * 0.5;
		vec2 g = dot(a, a) < dot(b, b) ? a : b;
		vec2 q = abs(g);
		return 0.5 - max(dot(q, vec2(0.5, 0.8660254)), q.x);
	}
	vec2 f = abs(fract(p) - 0.5);
	return 0.5 - max(f.x, f.y);
}

void fragment() {
	// The face's plane picks the two axes the lines run along, so every face gets a grid.
	vec3 n = abs(normalize(model_normal));
	vec2 plane = (n.x > n.y && n.x > n.z) ? model_pos.zy : ((n.y > n.z) ? model_pos.xz : model_pos.xy);
	float d = border(plane / cell_m) * cell_m; // metres to the nearest line
	float fw = max(fwidth(d), 0.00001);
	float seam = 1.0 - smoothstep(line_m * 0.5 - fw, line_m * 0.5 + fw, d);
	ALBEDO = base_color.rgb * (1.0 - 0.6 * seam);
	METALLIC = metallic_amount;
	ROUGHNESS = clamp(roughness_amount + 0.35 * seam, 0.0, 1.0);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	EMISSION = neon.rgb * (rim_energy * rim + seam_energy * seam);
}
