// SIGKILL node_modules maze wall (W2, scripts/fsmap/maze_world.gd): every wall of the maze in one mesh, original and made
// in code. Black glass, code falling down it in columns, its edges lit, and across it every so often an install's
// progress bar filling, `[#####.....]`, over and over and never finishing. Most walls run in toxic lime; one in five is a
// WARN wall in amber, one in twenty an ERR! wall in red that pulses. Its own light only (unshaded), so it reads in the
// dark; the posts between walls draw with `post` on (brighter edges, no bars).
//
// Per vertex (the wall's mesh, made by the maze): UV its place on its face in metres (x across, y down from the top);
// CUSTOM0 the wall's seed (0 to 1), its face's width and height, and 1 on a top face. Glyphs as the code rain's
// (shaders/code_rain.gdshader): a 4 by 6 bit grid mirrored left to right, chosen by an integer hash, so nothing grows with
// the clock. Time is the arena's clock (scripts/arena/arena_art.gd): SIGSTOP slows it.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back;

global uniform float arena_clock;

const int GLYPH_COLS = 6;
const int GLYPH_ROWS = 8;
const float TICK_WRAP = 1024.0;

uniform bool post = false;
uniform float glyph_size = 0.16;
uniform vec4 glass_color : source_color = vec4(0.004, 0.008, 0.002, 1.0);
uniform vec4 lime : source_color = vec4(0.72, 1.0, 0.08, 1.0);
uniform vec4 amber : source_color = vec4(1.0, 0.62, 0.0, 1.0);
uniform vec4 red : source_color = vec4(1.0, 0.1, 0.06, 1.0);
uniform vec4 head_color : source_color = vec4(0.94, 1.0, 0.82, 1.0);
uniform float code_energy = 1.4;
uniform float edge_energy = 2.6;
uniform float bar_energy = 1.7;

varying vec4 wall;
varying vec2 face;

void vertex() {
	wall = CUSTOM0;
	face = UV;
}

uint pcg(uint v) {
	uint state = v * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}

float hash3(int a, int b, int c) {
	uint h = pcg(uint(a) + pcg(uint(b) + pcg(uint(c))));
	return float(h >> 8u) * (1.0 / 16777216.0);
}

float glyph(vec2 cell, int column, int row, int tick) {
	ivec2 g = ivec2(floor(cell * vec2(float(GLYPH_COLS), float(GLYPH_ROWS))));
	if (g.x < 1 || g.x > GLYPH_COLS - 2 || g.y < 1 || g.y > GLYPH_ROWS - 2) {
		return 0.0;
	}
	int mirrored = min(g.x - 1, GLYPH_COLS - 2 - g.x);
	return step(0.45, hash3(column, row, mirrored + GLYPH_ROWS * g.y + GLYPH_ROWS * GLYPH_ROWS * tick));
}

// Code falling: a head and a tail of glyphs a column, `density` of the columns carrying one.
vec3 code(vec2 uv, float density, float speed, int salt, float clock, vec3 tint) {
	vec2 g = uv / glyph_size;
	int column = int(floor(g.x)) + salt * 131;
	if (hash3(column, 1, salt) > density) {
		return vec3(0.0);
	}
	int row = int(floor(g.y));
	float fall = mix(speed * 0.6, speed * 1.4, hash3(column, 2, salt));
	int tail = 9;
	int cycle = tail + 6 + int(floor(12.0 * hash3(column, 3, salt)));
	int at = int(floor(clock * fall + hash3(column, 4, salt) * float(cycle)));
	int k = int(mod(float(row - at), float(cycle)));
	if (k >= tail) {
		return vec3(0.0);
	}
	int tick = int(mod(floor(clock * 7.0 + hash3(column, 5, row) * 8.0), TICK_WRAP));
	float bits = glyph(fract(g), column, row, tick);
	if (k == 0) {
		return head_color.rgb * bits * 1.6;
	}
	float fade = 1.0 - float(k) / float(tail);
	return tint * fade * fade * bits;
}

void fragment() {
	float clock = arena_clock;
	float seed = wall.x;
	vec2 size = wall.yz;
	bool top = wall.w > 0.5;
	int salt = int(seed * 977.0);
	// Its kind: most lime, a fifth amber (WARN), a twentieth red (ERR!), pulsing.
	float pick = fract(seed * 13.17);
	vec3 tint = pick < 0.05 ? red.rgb * (0.75 + 0.45 * sin(clock * 4.0 + seed * 20.0)) : (pick < 0.25 ? amber.rgb : lime.rgb);
	float d = min(min(face.x, size.x - face.x), min(face.y, size.y - face.y));
	float e = 1.0 - smoothstep(0.0, post ? 0.05 : 0.04, d);
	vec3 lit = tint * e * edge_energy * (post ? 1.4 : 1.0);
	if (!top) {
		lit += code(face, post ? 0.3 : 0.4, 3.2, salt, clock, tint) * code_energy;
		// A seam across it every half metre.
		lit += tint * 0.07 * smoothstep(0.47, 0.5, abs(fract(face.y * 2.0) - 0.5));
		if (!post) {
			// The install's bar: a band at its own height, brackets at its ends, filling cell by cell and starting over.
			float bar_y = 1.0 + floor(hash3(salt, 11, 0) * 3.0) * 1.3;
			float in_band = step(abs(face.y - bar_y), 0.11);
			if (in_band > 0.0 && face.x > 0.35 && face.x < size.x - 0.35) {
				float run = size.x - 0.7;
				float cells = floor(run / 0.18);
				float c = floor((face.x - 0.35) / 0.18);
				float speed = mix(0.06, 0.22, hash3(salt, 12, 0));
				float filled = floor(fract(clock * speed + seed) * (cells + 6.0));
				float box = step(abs(fract((face.x - 0.35) / 0.18) - 0.5), 0.36) * step(abs(face.y - bar_y), 0.07);
				float bracket = (c < 0.5 || c > cells - 1.5) ? step(abs(face.y - bar_y), 0.11) * step(abs(fract((face.x - 0.35) / 0.18) - 0.5), 0.12) : 0.0;
				lit += tint * bar_energy * (c < filled ? box : box * 0.12) + head_color.rgb * bracket * 1.2;
			}
		}
	}
	ALBEDO = glass_color.rgb + lit;
}
