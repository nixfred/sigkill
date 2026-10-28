// SIGKILL code-rain vision (C21): an enemy body drawn as a silhouette of Matrix glyphs that
// shows through walls. The glyphs are the walls' own code rain (shaders/code_rain.gdshader):
// the same 4 by 6 bit grids from the same PCG integer hash, the same streams of a bright
// leading glyph and a fading tail, the same greens. scripts/abilities/code_rain_vision.gd
// sets every value at runtime from resources/code_rain.tres (the glyphs) and
// resources/code_rain_vision.tres (the glow); the defaults here only preview it.
//
// Drawn with no depth test and additive: no wall ever hides it, and it only adds green light
// to the picture. The streams run down the body's own height and around it, so they move
// with the body. A dim base glow keeps the shape readable between the streams. strength
// fades the whole silhouette in and out: never a flash. A flicker_rate of 0 (the comfort
// settings) holds every glyph still.
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_back, blend_add, shadows_disabled;

const int GLYPH_COLS = 6;
const int GLYPH_ROWS = 8;
const float BIT_ON = 0.45;
const float TICK_WRAP = 1024.0;
const int SALT_STREAM = 1;
const int SALT_SPEED = 2;
const int SALT_GAP = 3;
const int SALT_PHASE = 4;
const int SALT_FLICKER = 5;

uniform float glyph_size = 0.25;
uniform float column_density : hint_range(0.0, 1.0) = 0.6;
uniform float fall_speed_min = 3.0;
uniform float fall_speed_max = 9.0;
uniform float tail_length = 12.0;
uniform float flicker_rate = 6.0;
uniform vec4 head_color : source_color = vec4(0.784, 1.0, 0.816, 1.0);
uniform vec4 tail_color : source_color = vec4(0.0, 1.0, 0.255, 1.0);
uniform float energy = 3.0;
uniform float glow = 0.15;
uniform float strength : hint_range(0.0, 1.0) = 1.0;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

// PCG integer hash, as in shaders/code_rain.gdshader.
uint pcg(uint v) {
	uint state = v * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}

float hash3(int a, int b, int c) {
	uint h = pcg(uint(a) + pcg(uint(b) + pcg(uint(c))));
	return float(h >> 8u) * (1.0 / 16777216.0);
}

// One glyph, 1 where a bit is lit, as in shaders/code_rain.gdshader.
float glyph(vec2 cell, int column, int row, int tick) {
	ivec2 g = ivec2(floor(cell * vec2(float(GLYPH_COLS), float(GLYPH_ROWS))));
	if (g.x < 1 || g.x > GLYPH_COLS - 2 || g.y < 1 || g.y > GLYPH_ROWS - 2) {
		return 0.0;
	}
	int mirrored = min(g.x - 1, GLYPH_COLS - 2 - g.x);
	return step(BIT_ON, hash3(column, row, mirrored + GLYPH_ROWS * g.y + GLYPH_ROWS * GLYPH_ROWS * tick));
}

// The rain at `uv` (metres around the body and up it), before any glow is applied.
vec3 rain(vec2 uv) {
	uv /= glyph_size;
	int column = int(floor(uv.x));
	if (hash3(column, SALT_STREAM, 0) > column_density) {
		return vec3(0.0);
	}
	int row = int(floor(uv.y));
	float speed = mix(fall_speed_min, fall_speed_max, hash3(column, SALT_SPEED, 0));
	int tail = int(floor(tail_length));
	int cycle = tail + int(floor(float(tail) * (0.5 + hash3(column, SALT_GAP, 0))));
	int step_count = int(floor(TIME * speed + hash3(column, SALT_PHASE, 0) * float(cycle)));
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
	float around = atan(local_pos.z, local_pos.x) * length(local_pos.xz);
	vec3 light = rain(vec2(around, local_pos.y)) * energy + tail_color.rgb * glow;
	ALBEDO = light * strength;
	ALPHA = strength;
}
