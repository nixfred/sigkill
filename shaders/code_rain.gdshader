// SIGKILL code rain: the neon edge look plus Matrix glyph streams that bleed through the
// greybox blocks when daemons are near. With no enemy in reach the result is exactly the
// neon edge shader: black faces, glowing edges, nothing else.
//
// Reach: scripts/code_rain_driver.gd fills `enemies` with up to MAX_ENEMIES world positions
// and a weight each (0 to 1, faded in and out over time). Every pixel measures its own
// distance to each enemy, so the rain pools on the part of a wall nearest the enemy, on
// both sides of it, and fades to nothing at falloff_radius.
//
// Glyphs: original and procedural, no fonts or textures. The surface is cut into a grid of
// glyph_size cells in world space, so streams run across block seams. Each column rolls a
// hash for whether it carries a stream, its speed and its phase. A stream is a bright
// leading glyph with a fading tail of tail_length glyphs, then a dark gap, repeating down
// the column; it steps one cell at a time like the film. Each glyph is a 4 by 6 bit grid,
// mirrored left to right so it reads like a character, re-rolled flicker_rate times a second.
// Every hash is an integer hash (PCG) of small integers: cell coordinates, a salt and a
// flicker tick wrapped at 1024, so nothing in it grows with TIME. A float hash loses its
// fractional bits as its inputs grow and would have switched every glyph off within an hour.
//
// Uniform defaults mirror resources/code_rain.tres and scripts/palette.gd so the material
// previews in the editor; the driver sets every value at runtime.
shader_type spatial;
render_mode specular_disabled;

#include "res://shaders/neon_edge.gdshaderinc"

// Size of the enemy array. CodeRainTuning.MAX_ENEMIES mirrors it.
const int MAX_ENEMIES = 8;
// Glyph bit grid: the cell is cut 6 across and 8 down, with a one-bit margin all round.
const int GLYPH_COLS = 6;
const int GLYPH_ROWS = 8;
const float BIT_ON = 0.45;
// Glyph shapes re-roll on a tick that wraps here, so the hash inputs stay small forever.
const float TICK_WRAP = 1024.0;
// Salts that keep each column roll apart.
const int SALT_STREAM = 1;
const int SALT_SPEED = 2;
const int SALT_GAP = 3;
const int SALT_PHASE = 4;
const int SALT_FLICKER = 5;

uniform vec4 enemies[MAX_ENEMIES];
uniform int enemy_count = 0;
uniform float falloff_radius = 8.0;
uniform float min_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float max_intensity : hint_range(0.0, 1.0) = 1.0;
uniform float column_density : hint_range(0.0, 1.0) = 0.6;
uniform float glyph_size = 0.25;
uniform float fall_speed_min = 3.0;
uniform float fall_speed_max = 9.0;
uniform float tail_length = 12.0;
uniform float flicker_rate = 6.0;
uniform float rain_energy = 3.0;
uniform vec4 head_color : source_color = vec4(0.784, 1.0, 0.816, 1.0);
uniform vec4 tail_color : source_color = vec4(0.0, 1.0, 0.255, 1.0);

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	local_pos = VERTEX;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = mat3(MODEL_MATRIX) * NORMAL;
}

// PCG integer hash. tests/code_rain_test.gd mirrors pcg() and hash3() to check their spread.
uint pcg(uint v) {
	uint state = v * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}

// Hash of three integers to 0 to 1, with 24 bits of spread whatever their size.
float hash3(int a, int b, int c) {
	uint h = pcg(uint(a) + pcg(uint(b) + pcg(uint(c))));
	return float(h >> 8u) * (1.0 / 16777216.0);
}

// How much rain this point gets, 0 to 1. An enemy's share fades with distance over
// falloff_radius, and shares combine like independent chances, so two enemies never push
// the total past 1 and it never drops when one comes closer. code_rain_driver.gd mirrors
// this in intensity_at(), which the headless test checks.
float proximity() {
	float clear = 1.0;
	for (int i = 0; i < MAX_ENEMIES; i++) {
		if (i >= enemy_count) {
			break;
		}
		float d = distance(world_pos, enemies[i].xyz);
		clear *= 1.0 - enemies[i].w * (1.0 - smoothstep(0.0, falloff_radius, d));
	}
	return 1.0 - clear;
}

// Grid coordinates of this point on its face, in metres: x across the face, y down the
// stream. Side faces stream down world Y; caps stream along world Z.
vec2 surface_uv() {
	vec3 n = abs(world_normal);
	if (n.y > n.x && n.y > n.z) {
		return vec2(world_pos.x, world_pos.z);
	}
	float across = (n.x > n.z) ? world_pos.z : world_pos.x;
	return vec2(across, world_pos.y);
}

// One glyph, 1 where a bit is lit. cell is the position inside the cell, 0 to 1 each way;
// column, row and tick pick the shape.
float glyph(vec2 cell, int column, int row, int tick) {
	ivec2 g = ivec2(floor(cell * vec2(float(GLYPH_COLS), float(GLYPH_ROWS))));
	if (g.x < 1 || g.x > GLYPH_COLS - 2 || g.y < 1 || g.y > GLYPH_ROWS - 2) {
		return 0.0;
	}
	int mirrored = min(g.x - 1, GLYPH_COLS - 2 - g.x);
	return step(BIT_ON, hash3(column, row, mirrored + GLYPH_ROWS * g.y + GLYPH_ROWS * GLYPH_ROWS * tick));
}

// Rain colour at this point before any intensity is applied.
vec3 rain() {
	vec2 uv = surface_uv() / glyph_size;
	int column = int(floor(uv.x));
	if (hash3(column, SALT_STREAM, 0) > column_density) {
		return vec3(0.0);
	}
	int row = int(floor(uv.y));
	float speed = mix(fall_speed_min, fall_speed_max, hash3(column, SALT_SPEED, 0));
	int tail = int(floor(tail_length));
	// Head, tail, then a dark gap of half a tail to a full tail, repeating down the column.
	int cycle = tail + int(floor(float(tail) * (0.5 + hash3(column, SALT_GAP, 0))));
	int step_count = int(floor(TIME * speed + hash3(column, SALT_PHASE, 0) * float(cycle)));
	// 0 at the leading glyph, counting up the tail behind it. Float mod: it is defined for a
	// negative row, and these values are small enough to be exact.
	int k = int(mod(float(row + step_count), float(cycle)));
	if (k >= tail) {
		return vec3(0.0);
	}
	int tick = int(mod(floor(TIME * flicker_rate + hash3(column, SALT_FLICKER, row) * 8.0), TICK_WRAP));
	float bits = glyph(fract(uv), column, row, tick);
	if (k == 0) {
		return head_color.rgb * bits;
	}
	float fade = 1.0 - float(k) / float(tail);
	return tail_color.rgb * (fade * fade * bits);
}

void fragment() {
	float cover = edge_cover(edge_distance());
	ALBEDO = face_color.rgb;
	ROUGHNESS = 1.0;
	EMISSION = edge_color.rgb * (edge_energy * cover);
	float intensity = mix(min_intensity, max_intensity, proximity());
	if (intensity > 0.0) {
		EMISSION += rain() * (rain_energy * intensity);
	}
}
