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
//
// Uniform defaults mirror resources/code_rain.tres and scripts/palette.gd so the material
// previews in the editor; the driver sets every value at runtime.
shader_type spatial;
render_mode specular_disabled;

#include "res://shaders/neon_edge.gdshaderinc"

// Size of the enemy array. CodeRainTuning.MAX_ENEMIES mirrors it.
const int MAX_ENEMIES = 8;
// Glyph bit grid: the cell is cut 6 across and 8 down, with a one-bit margin all round.
const vec2 GLYPH_GRID = vec2(6.0, 8.0);
const float BIT_ON = 0.45;

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

float hash11(float n) {
	return fract(sin(n * 127.1 + 311.7) * 43758.5453);
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
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

// One glyph, 1 where a bit is lit. cell is the position inside the cell, 0 to 1 each way.
float glyph(vec2 cell, float seed) {
	vec2 g = floor(cell * GLYPH_GRID);
	if (g.x < 1.0 || g.x > GLYPH_GRID.x - 2.0 || g.y < 1.0 || g.y > GLYPH_GRID.y - 2.0) {
		return 0.0;
	}
	float mirrored = min(g.x - 1.0, GLYPH_GRID.x - 2.0 - g.x);
	return step(BIT_ON, hash21(vec2(mirrored, g.y) + seed * 7.31));
}

// Rain colour at this point before any intensity is applied.
vec3 rain() {
	vec2 uv = surface_uv() / glyph_size;
	float column = floor(uv.x);
	if (hash11(column) > column_density) {
		return vec3(0.0);
	}
	float row = floor(uv.y);
	float speed = mix(fall_speed_min, fall_speed_max, hash11(column + 31.7));
	float tail = floor(tail_length);
	// Head, tail, then a dark gap of half a tail to a full tail, repeating down the column.
	float cycle = tail + floor(tail * (0.5 + hash11(column + 57.3)));
	float step_count = floor(TIME * speed + hash11(column + 91.1) * cycle);
	// 0 at the leading glyph, counting up the tail behind it.
	float k = mod(row + step_count, cycle);
	if (k >= tail) {
		return vec3(0.0);
	}
	float seed = hash21(vec2(column, row)) * 97.0 + floor(TIME * flicker_rate + hash21(vec2(row, column)));
	float bits = glyph(fract(uv), seed);
	if (k < 1.0) {
		return head_color.rgb * bits;
	}
	float fade = 1.0 - k / tail;
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
