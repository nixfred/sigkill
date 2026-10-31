// SIGKILL ruins bodies (C36): everything solid in the ruins, lit, in the register it stands in (ruins_common's
// weights). The vertex colour carries each part's own data (scripts/ruins/ruins_pieces.gd paints it):
//   r  grime (metal, stone, glass) or a cable's phase
//   g  how bright its true edges are (0 none), the shape kit's edged buckets drawing them as lines
//   b  its material: 0 metal, 1/3 stone (a monolith's black glass), 2/3 cable, 1 screen glass
//   a  how far it swings (0 rigid; a cut cable's dangling end goes to 1 at its tip, glowing hot there)
// Metal is dark gunmetal cut into panels in world space, each a shade of its own, darker with grime and down into the
// abyss. Per register: tron clean, its edges bright teal, a scan of light climbing the towers now and then; cyberpunk
// wet, slick and dim, rain running down every side face; matrix its edges green and code rain streaming down the side
// faces (stronger near daemons, as the code rain in the arena: scripts/code_rain_driver.gd's slots, fed in by the
// world). A register shift tears it in bands. Colour defaults mirror scripts/ruins/ruins_register.gd, which sets them.
shader_type spatial;
render_mode cull_back;

#include "res://shaders/ruins_common.gdshaderinc"

const int MAX_ENEMIES = 8;

uniform vec4 metal_color : source_color = vec4(0.043, 0.055, 0.067, 1.0);
uniform vec4 stone_color : source_color = vec4(0.012, 0.016, 0.022, 1.0);
uniform vec4 edge_tron : source_color = vec4(0.098, 0.827, 0.773, 1.0);
uniform vec4 edge_cyber : source_color = vec4(0.36, 0.30, 0.95, 1.0);
uniform vec4 edge_matrix : source_color = vec4(0.0, 1.0, 0.255, 1.0);
uniform vec3 edge_energy = vec3(2.2, 0.2, 0.15);
uniform vec4 vein_tron : source_color = vec4(0.098, 0.827, 0.773, 1.0);
uniform vec4 vein_cyber : source_color = vec4(0.82, 0.29, 1.0, 1.0);
uniform vec4 vein_matrix : source_color = vec4(0.0, 1.0, 0.255, 1.0);
uniform vec4 glyph_head : source_color = vec4(0.784, 1.0, 0.816, 1.0);
uniform vec4 glyph_tail : source_color = vec4(0.0, 1.0, 0.255, 1.0);
uniform vec4 sheen_color : source_color = vec4(0.45, 0.4, 1.0, 1.0);
uniform vec4 hot_color : source_color = vec4(1.0, 0.92, 0.75, 1.0);
uniform float glyph_density = 0.42;
uniform float glyph_energy = 2.6;
uniform float scan_energy = 1.6;
uniform float panel_m = 0.62;
uniform vec4 enemies[MAX_ENEMIES];
uniform int enemy_count = 0;
uniform float enemy_reach_m = 9.0;

varying vec3 world_pos;
varying vec3 world_normal;
varying vec3 bary;
varying vec4 paint;

void vertex() {
	paint = COLOR;
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// A cut cable's dangling end swings: more toward its tip, each cable on its own phase.
	if (COLOR.a > 0.0) {
		float t = arena_clock * 1.3 + COLOR.r * 31.0;
		vec3 swing = vec3(sin(t), 0.0, cos(t * 0.83 + 1.7)) * (0.35 * COLOR.a * COLOR.a);
		VERTEX += (inverse(MODEL_MATRIX) * vec4(swing, 0.0)).xyz;
	}
	float tear = ruins_tear_band(w);
	if (tear > 0.0) {
		VERTEX += (inverse(MODEL_MATRIX) * vec4(sin(w.y * 13.0 + arena_clock * 50.0) * 0.18 * tear, 0.0, 0.0, 0.0)).xyz;
	}
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
	bary = CUSTOM0.rgb;
}

float enemy_near() {
	float clear = 1.0;
	for (int i = 0; i < MAX_ENEMIES; i++) {
		if (i >= enemy_count) {
			break;
		}
		float d = distance(world_pos, enemies[i].xyz);
		clear *= 1.0 - enemies[i].w * (1.0 - smoothstep(0.0, enemy_reach_m, d));
	}
	return 1.0 - clear;
}

void fragment() {
	vec3 w3 = ruins_weights(world_pos);
	vec3 n = world_normal;
	bool side = abs(n.y) < 0.6;
	int material = int(round(paint.b * 3.0));
	float grime = paint.r;
	// Across a side face (x) and up it (y), in metres.
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), abs(n.y) > 0.99 ? vec3(1.0, 0.0, 0.0) : n));
	vec2 face = side ? vec2(dot(world_pos, right), world_pos.y) : world_pos.xz;

	vec3 albedo = metal_color.rgb;
	float rough = mix(0.42, 0.62, grime);
	float metal = 0.65;
	vec3 glow = vec3(0.0);

	if (material == 0) {
		vec2 cell = face / panel_m;
		ivec2 c = ivec2(floor(cell));
		float tone = 0.72 + 0.56 * ruins_hash(c.x, c.y, 3);
		vec2 f = abs(fract(cell) - 0.5);
		float seam = ruins_line(0.5 - max(f.x, f.y), 0.05);
		albedo *= tone * (1.0 - 0.55 * seam);
		rough = mix(rough, 1.0, seam);
		// Down into the abyss it gets darker and dirtier.
		float deep = clamp(-world_pos.y / 40.0, 0.0, 1.0);
		albedo *= mix(1.0, 0.35, max(grime * 0.6, deep));
	} else if (material == 1) {
		albedo = stone_color.rgb;
		rough = 0.1 + 0.25 * grime;
		metal = 0.0;
		// Cracks through the glass, lit from inside (C37: a crazed network, crisp at any distance, where a ridged noise's
		// crests read as blotches up close): fine crazing over some of a face, a few long cracks across it.
		float fine = ruins_line(ruins_crack(face / 1.6 + vec2(3.1, 9.2)), 0.02) * step(0.55, ruins_noise(face * 0.3 + 3.0));
		float long_crack = ruins_line(ruins_crack(face / 4.6 + vec2(1.7, 4.4)), 0.012);
		float vein = max(fine, long_crack) * smoothstep(0.25, 0.5, ruins_noise(face * 0.11 + 11.0));
		vec3 vc = vein_tron.rgb * w3.x + vein_cyber.rgb * w3.y + vein_matrix.rgb * w3.z;
		glow += vc * vein * 1.1;
	} else if (material == 2) {
		albedo = vec3(0.012, 0.012, 0.014);
		rough = 0.75;
		metal = 0.0;
		float pulse = smoothstep(0.96, 1.0, fract((world_pos.x + world_pos.z) * 0.07 + world_pos.y * 0.02 - arena_clock * 0.35 + paint.r * 7.0));
		vec3 vc = edge_tron.rgb * w3.x + vein_cyber.rgb * w3.y + edge_matrix.rgb * w3.z;
		glow += vc * pulse * 1.6;
		// The cut end of a dangling cable glows hot and crackles.
		float tip = smoothstep(0.95, 1.0, paint.a);
		float crackle = step(0.45, ruins_hash(int(floor(arena_clock * 18.0)), int(paint.r * 1000.0), 5));
		glow += hot_color.rgb * tip * (0.8 + 2.4 * crackle);
	} else {
		albedo = vec3(0.004, 0.008, 0.01);
		rough = 0.06;
		metal = 0.2;
	}

	// The true edges, in the register's edge colour.
	if (paint.g > 0.0) {
		vec3 bw = max(fwidth(bary), vec3(0.00001));
		vec3 near = smoothstep(bw * 0.5, bw * 1.6, bary);
		float line = 1.0 - min(min(near.x, near.y), near.z);
		vec3 ec = edge_tron.rgb * (w3.x * edge_energy.x) + edge_cyber.rgb * (w3.y * edge_energy.y) + edge_matrix.rgb * (w3.z * edge_energy.z);
		glow += ec * line * paint.g;
	}

	if (side && material != 2) {
		// Tron: a scan of light climbing the towers.
		float scan_y = mod(arena_clock * 7.0, 110.0) - 30.0;
		float scan = exp(-pow((world_pos.y - scan_y) / 0.35, 2.0));
		glow += edge_tron.rgb * scan * scan_energy * w3.x;
		// Cyberpunk: rain running down the side faces, slick between the streaks.
		if (w3.y > 0.01) {
			float column = floor(face.x / 0.09);
			float streak = smoothstep(0.82, 1.0, fract(face.y * 0.21 + arena_clock * (0.9 + ruins_hash(int(column), 7, 1) * 1.4) + ruins_hash(int(column), 8, 1)));
			streak *= step(0.55, ruins_hash(int(column), 9, 1));
			rough = mix(rough, mix(0.12, 0.03, streak), w3.y);
			albedo *= mix(1.0, 0.7, w3.y);
			glow += sheen_color.rgb * streak * 0.05 * w3.y;
		}
		// Matrix: code rain down the side faces; anywhere, it pools where daemons are near.
		float near = enemy_near();
		float rain_amount = clamp(w3.z + near * (0.3 + 0.7 * w3.z), 0.0, 1.0);
		if (rain_amount > 0.01) {
			vec2 r = ruins_rain(vec2(face.x, -face.y), mix(0.2, 0.3, w3.z), glyph_density);
			glow += (glyph_head.rgb * r.x + glyph_tail.rgb * r.y) * glyph_energy * rain_amount * mix(0.5, 1.0, w3.z);
		}
	}

	float tear = ruins_tear_band(world_pos);
	glow += mix(edge_tron.rgb, vein_cyber.rgb, step(0.5, fract(world_pos.x * 0.7 + arena_clock * 9.0))) * tear * 0.7;

	ALBEDO = albedo;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.5;
	EMISSION = glow * arena_light;
}
