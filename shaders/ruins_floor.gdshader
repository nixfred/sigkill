// SIGKILL ruins floor (C36): the district's slabs, lit, in the register they stand in. Dark deck plates in world space
// (plate_m squares, each a shade of its own) parted by seams, a light strip along every cell's edge (the old grid, cut
// into slabs), and cracks through them, glowing from below: a crazed network (a cellular noise's edges) as dense as the
// slab's damage, wider and hotter where it is worst. A slab's sides that meet the void or a hole glow at the rim.
// The vertex colour (scripts/ruins/ruins_pieces.gd paints it): r the slab's damage, 0 to 1; g the rims, a bit for each
// side that meets the void (1 north, 2 east, 4 south, 8 west, over 15). Per register: tron's grid bright and a pulse of
// light running out over it from the district's middle; cyberpunk wet, puddles holding the light, rain rings in them;
// matrix's code rain trickling over it. A register shift tears it.
shader_type spatial;

#include "res://shaders/ruins_common.gdshaderinc"

uniform vec4 base_color : source_color = vec4(0.03, 0.038, 0.046, 1.0);
uniform vec4 grid_tron : source_color = vec4(0.49, 1.0, 0.812, 1.0);
uniform vec4 grid_cyber : source_color = vec4(0.36, 0.30, 0.95, 1.0);
uniform vec4 grid_matrix : source_color = vec4(0.0, 1.0, 0.255, 1.0);
uniform vec3 grid_energy = vec3(1.25, 0.18, 0.45);
uniform vec4 crack_tron : source_color = vec4(0.098, 0.827, 0.773, 1.0);
uniform vec4 crack_cyber : source_color = vec4(0.62, 0.36, 1.0, 1.0);
uniform vec4 crack_matrix : source_color = vec4(0.0, 1.0, 0.255, 1.0);
uniform vec3 crack_energy = vec3(1.3, 0.55, 0.75);
uniform vec4 glyph_head : source_color = vec4(0.784, 1.0, 0.816, 1.0);
uniform vec4 glyph_tail : source_color = vec4(0.0, 1.0, 0.255, 1.0);
uniform vec4 puddle_tint : source_color = vec4(0.82, 0.29, 1.0, 1.0);
uniform vec4 puddle_tint_b : source_color = vec4(1.0, 0.478, 0.102, 1.0);
uniform float cell_m = 4.0;
// Where the cells' edges fall: the district's grid is offset by this from the world's.
uniform vec2 grid_offset = vec2(0.0);
uniform vec2 pulse_from = vec2(0.0);
uniform float plate_m = 1.0;

varying vec3 world_pos;
varying vec3 world_normal;
varying vec4 paint;

void vertex() {
	paint = COLOR;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

// Distance to the nearest crack of a crazed network at `p` (a cellular noise's second nearest minus nearest).
float crack_distance(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			ivec2 c = ivec2(i) + ivec2(x, y);
			vec2 o = vec2(ruins_hash(c.x, c.y, 21), ruins_hash(c.x, c.y, 22));
			float d = length(vec2(float(x), float(y)) + o - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return d2 - d1;
}

void fragment() {
	vec3 w3 = ruins_weights(world_pos);
	float damage = paint.r;
	int rims = int(round(paint.g * 15.0));
	vec3 albedo = base_color.rgb;
	float rough = 0.38;
	vec3 glow = vec3(0.0);
	if (world_normal.y > 0.5) {
		vec2 p = world_pos.xz;
		vec2 plate = p / plate_m;
		ivec2 pc = ivec2(floor(plate));
		float tone = 0.7 + 0.6 * ruins_hash(pc.x, pc.y, 1);
		vec2 pf = abs(fract(plate) - 0.5);
		float seam = ruins_line(0.5 - max(pf.x, pf.y), 0.03);
		albedo *= tone * (1.0 - 0.6 * seam);
		rough = mix(rough, 1.0, seam);
		// The cells' edges: the old grid's strip, cut where a slab broke.
		vec2 cell = (p - grid_offset) / cell_m;
		vec2 cf = abs(fract(cell) - 0.5);
		float edge_d = (0.5 - max(cf.x, cf.y)) * cell_m;
		float grid = ruins_line(edge_d, 0.045);
		float minor = ruins_line((0.5 - max(abs(fract(cell * 4.0) - 0.5).x, abs(fract(cell * 4.0) - 0.5).y)) * cell_m * 0.25, 0.015);
		vec3 gc = grid_tron.rgb * (w3.x * grid_energy.x) + grid_cyber.rgb * (w3.y * grid_energy.y) + grid_matrix.rgb * (w3.z * grid_energy.z);
		float broken = step(0.25 + damage * 0.5, ruins_noise(p * 0.9));
		glow += gc * (grid * broken + minor * 0.06);
		// Tron: a pulse running out over the grid from the middle.
		float r = length(p - pulse_from);
		float front = mod(arena_clock * 9.0, 90.0);
		glow += grid_tron.rgb * (grid + minor * 0.5) * exp(-pow((r - front) / 1.2, 2.0)) * 3.0 * w3.x;
		// Cracks, glowing from below, as wide and as many as the damage.
		float cd = crack_distance(p / 0.9 + vec2(13.1, 7.7));
		float big = crack_distance(p / 3.1 + vec2(3.3, 1.1));
		float lines = ruins_line(cd, 0.06 * damage) * step(0.35, ruins_noise(p * 0.35 + 4.0)) * damage;
		lines = max(lines, ruins_line(big, 0.05 + 0.08 * damage) * smoothstep(0.15, 0.5, damage));
		vec3 cc = crack_tron.rgb * (w3.x * crack_energy.x) + crack_cyber.rgb * (w3.y * crack_energy.y) + crack_matrix.rgb * (w3.z * crack_energy.z);
		float breathe = 0.75 + 0.25 * sin(arena_clock * 1.7 + p.x * 0.3 + p.y * 0.2);
		glow += cc * lines * breathe;
		albedo *= 1.0 - 0.7 * lines;
		// Rims where a side meets the void.
		vec2 lc = fract(cell) - 0.5;
		float rim = 0.0;
		if ((rims & 1) != 0) { rim = max(rim, exp(-(0.5 + lc.y) * cell_m / 0.25)); }
		if ((rims & 2) != 0) { rim = max(rim, exp(-(0.5 - lc.x) * cell_m / 0.25)); }
		if ((rims & 4) != 0) { rim = max(rim, exp(-(0.5 - lc.y) * cell_m / 0.25)); }
		if ((rims & 8) != 0) { rim = max(rim, exp(-(0.5 + lc.x) * cell_m / 0.25)); }
		glow += cc * rim * 1.2;
		// Cyberpunk: puddles holding the light, rain rings in them.
		if (w3.y > 0.01) {
			float wet = smoothstep(0.52, 0.6, ruins_fbm(p * 0.22 + 11.0));
			ivec2 dc = ivec2(floor(p / 0.7));
			vec2 dp = fract(p / 0.7) - 0.5;
			float age = fract(arena_clock * 0.9 + ruins_hash(dc.x, dc.y, 31));
			float ring = ruins_line(abs(length(dp) - age * 0.45), 0.02) * (1.0 - age) * step(0.6, ruins_hash(dc.x, dc.y, 32));
			rough = mix(rough, 0.02, wet * w3.y);
			albedo *= mix(1.0, 0.55, wet * w3.y);
			// The signs' neon held in the water: magenta here, amber there, smeared along the puddle.
			vec3 neon = mix(puddle_tint.rgb, puddle_tint_b.rgb, smoothstep(0.4, 0.6, ruins_noise(p * 0.08 + 21.0)));
			float smear = 0.6 + 0.4 * ruins_noise(vec2(p.x * 1.7, p.y * 0.25));
			glow += neon * (wet * (0.09 * smear + ring * 0.5)) * w3.y;
		}
		// Matrix: code rain trickling over the floor.
		if (w3.z > 0.01) {
			vec2 g = ruins_rain(vec2(p.x, p.y), 0.32, 0.22);
			glow += (glyph_head.rgb * g.x + glyph_tail.rgb * g.y) * 1.4 * w3.z;
		}
	} else {
		// A slab's broken side: dark, its top lit where it meets the void.
		albedo *= 0.5;
		float top = exp(-abs(world_pos.y) / 0.12);
		vec3 cc = crack_tron.rgb * w3.x + crack_cyber.rgb * w3.y + crack_matrix.rgb * w3.z;
		glow += cc * top * 1.5;
	}
	float tear = ruins_tear_band(world_pos + vec3(0.0, world_pos.z * 0.25, 0.0));
	glow += grid_tron.rgb * tear * step(0.7, fract(world_pos.x * 0.5 + arena_clock * 20.0)) * 0.5;
	ALBEDO = albedo;
	ROUGHNESS = rough;
	METALLIC = 0.4;
	SPECULAR = 0.6;
	EMISSION = glow * arena_light;
}
