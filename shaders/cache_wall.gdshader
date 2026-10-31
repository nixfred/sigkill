// SIGKILL cache field wall (M3, scripts/ruins/cache_field.gd): one wall of code in the cache lines, rewriting itself.
//
// Written, it is black glass with fine green code streaming down it and its edges lit, standing solid. Mid-rewrite, it is
// a storm of glyphs, flickering and see-through in places over a dark veil, a white scan line sweeping down it: it stands
// as tall, but nothing of it is solid yet. A wall writing in fills from the top down behind a thin bright write head, the
// storm still below it; draining, it empties the other way. Gone, it draws nothing (the field draws its seam on the floor).
// Its own light only (unshaded): black glass reflects nothing of the green round it, so the code reads.
//
// Per wall (instance uniforms, set by the field): `fill`, the written share from the top (0 to 1); `storm`, how much of
// the storm stands where it is not written (0 to 1); `wall_seed`, its own dice; `calm`, held still at the end (the loop
// broken, the storm frozen where it stood); `caret`, `^C` over both its faces in the signs' pixel letters (the loop
// broken). Its posts draw with `post` on: every face written, the edges brighter.
//
// Glyphs: original and procedural, as the code rain's (shaders/code_rain.gdshader): a 4 by 6 bit grid mirrored left to
// right, chosen by an integer hash (PCG) of small integers, so nothing grows with the clock. Time is the arena's clock
// (scripts/arena/arena_art.gd), so SIGSTOP slows it and a held clock (the rain stopping for a second) stops it.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_always, cull_back;

global uniform float arena_clock;

const int GLYPH_COLS = 6;
const int GLYPH_ROWS = 8;
const float TICK_WRAP = 1024.0;
// `^C` in 5 by 7 pixel letters, a row a number (its leftmost pixel the highest bit), the top row first.
const int CARET_HAT[7] = {4, 10, 17, 0, 0, 0, 0};
const int CARET_C[7] = {14, 17, 16, 16, 16, 17, 14};

instance uniform float fill = 1.0;
instance uniform float storm = 0.0;
instance uniform float wall_seed = 0.0;
instance uniform float calm = 0.0;
instance uniform float caret = 0.0;

uniform bool post = false;
// The box's size, metres: across (x), tall (y), thick (z).
uniform vec3 size = vec3(3.5, 4.0, 0.3);
uniform float glyph_size = 0.15;
uniform vec4 glass_color : source_color = vec4(0.002, 0.012, 0.006, 1.0);
uniform vec4 code_color : source_color = vec4(0.0, 1.0, 0.255, 1.0);
uniform vec4 head_color : source_color = vec4(0.784, 1.0, 0.816, 1.0);
uniform vec4 scan_color : source_color = vec4(0.92, 1.0, 0.95, 1.0);
uniform float code_energy = 1.5;
uniform float storm_energy = 2.6;
uniform float edge_energy = 2.4;
uniform float head_energy = 3.2;
uniform float caret_energy = 3.4;
// A `^C` pixel's side, metres, and its middle's height over the wall's middle.
uniform float caret_px = 0.13;
uniform float caret_y = 0.35;

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
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

// This point's place on its face, metres: x across, y down (z along the top).
vec2 face_uv() {
	vec3 n = abs(ln);
	if (n.y > n.x && n.y > n.z) {
		return vec2(lp.x, lp.z);
	}
	float across = (n.x > n.z) ? lp.z : lp.x;
	return vec2(across + sign(ln.x + ln.z) * 0.37, -lp.y);
}

// How near the face's edge, 1 on it and 0 a few centimetres in.
float edge() {
	vec3 h = size * 0.5;
	vec3 d = h - abs(lp);
	vec3 n = abs(ln);
	float e;
	if (n.z > n.x && n.z > n.y) {
		e = min(d.x, d.y);
	} else if (n.x > n.y) {
		e = min(d.z, d.y);
	} else {
		e = min(d.x, d.z);
	}
	return 1.0 - smoothstep(0.0, 0.035, e);
}

// Code streaming down: a head and a tail of glyphs a column, `density` of the columns carrying one, at `speed`.
vec3 code(vec2 uv, float density, float speed, int salt, float clock) {
	vec2 g = uv / glyph_size;
	int column = int(floor(g.x)) + salt * 131;
	if (hash3(column, 1, salt) > density) {
		return vec3(0.0);
	}
	int row = int(floor(g.y));
	float fall = mix(speed * 0.6, speed * 1.4, hash3(column, 2, salt));
	int tail = 11;
	int cycle = tail + 5 + int(floor(10.0 * hash3(column, 3, salt)));
	int at = int(floor(clock * fall + hash3(column, 4, salt) * float(cycle)));
	int k = int(mod(float(row - at), float(cycle)));
	if (k >= tail) {
		return vec3(0.0);
	}
	int tick = int(mod(floor(clock * 7.0 + hash3(column, 5, row) * 8.0), TICK_WRAP));
	float bits = glyph(fract(g), column, row, tick);
	if (k == 0) {
		return head_color.rgb * bits * 1.8;
	}
	float fade = 1.0 - float(k) / float(tail);
	return code_color.rgb * fade * fade * bits;
}

// 1 on a lit pixel of `^C` on a big face (read the right way round from either side), 0 elsewhere; `box` 1 inside its
// letters' frame.
float caret_bits(out float box) {
	box = 0.0;
	if (abs(ln.z) < 0.5) {
		return 0.0;
	}
	// Eleven pixels across (two letters and a gap), seven down, centred.
	vec2 p = vec2(lp.x * sign(ln.z), lp.y - caret_y) / caret_px + vec2(5.5, 3.5);
	if (p.x < -1.0 || p.x > 12.0 || p.y < -1.0 || p.y > 8.0) {
		return 0.0;
	}
	box = 1.0;
	ivec2 c = ivec2(floor(p));
	if (c.x < 0 || c.x > 10 || c.y < 0 || c.y > 6 || c.x == 5) {
		return 0.0;
	}
	int row = 6 - c.y;
	int bits = c.x < 5 ? CARET_HAT[row] : CARET_C[row];
	int column = c.x < 5 ? c.x : c.x - 6;
	return float((bits >> (4 - column)) & 1);
}

void fragment() {
	float clock = arena_clock;
	vec2 uv = face_uv();
	// Down from the top, 0 at the top and 1 at the foot.
	float down = clamp((size.y * 0.5 - lp.y) / size.y, 0.0, 1.0);
	bool top = abs(ln.y) > 0.5;
	float written = post ? 1.0 : fill;
	float e = edge();
	float box = 0.0;
	float hat = caret > 0.0 ? caret_bits(box) * caret : 0.0;
	if (top ? written > 0.0 : down < written) {
		// Written: black glass, code down it, its edges lit; a thin bright write head while it fills.
		int salt = int(wall_seed * 977.0);
		vec3 lit = code(uv, post ? 0.35 : 0.42, 3.8, salt, clock) * code_energy * (1.0 - 0.7 * box * caret);
		lit += code_color.rgb * e * edge_energy * (post ? 1.5 : 1.0);
		// The cache lines: a faint seam across it every half metre.
		lit += code_color.rgb * 0.1 * smoothstep(0.475, 0.5, abs(fract(lp.y * 2.0) - 0.5));
		if (!post && written < 1.0) {
			float head = 1.0 - smoothstep(0.0, 0.022, abs(down - written));
			lit += scan_color.rgb * head * head_energy;
		}
		lit += scan_color.rgb * hat * caret_energy;
		ALBEDO = glass_color.rgb + lit;
		ALPHA = 0.98;
	} else {
		// Mid-rewrite: a storm of glyphs over a dark veil, holes in it, a scan line sweeping down.
		float s = storm;
		if (s <= 0.004) {
			discard;
		}
		float still = calm > 0.5 ? 0.0 : 1.0;
		float t = mix(floor(wall_seed * 64.0), clock, still);
		vec2 g = uv / (glyph_size * 1.1);
		int column = int(floor(g.x)) + int(wall_seed * 4096.0);
		int row = int(floor(g.y));
		int tick = int(mod(floor(t * 14.0 + hash3(column, 7, row) * 5.0), TICK_WRAP));
		float bits = glyph(fract(g), column, row, tick);
		float cell_on = step(0.38, hash3(column, row, tick / 3));
		float scan_at = fract(t * 0.55 + wall_seed);
		float scan = 1.0 - smoothstep(0.0, 0.018, abs(down - scan_at));
		float flick = 0.75 + 0.25 * step(0.5, hash3(int(wall_seed * 999.0), int(floor(t * 11.0)), 9));
		vec3 lit = mix(code_color.rgb, head_color.rgb, step(0.8, hash3(column, row, tick))) * bits * cell_on * storm_energy * flick;
		lit += scan_color.rgb * scan * 3.0;
		lit += code_color.rgb * e * edge_energy * 0.7;
		lit += scan_color.rgb * hat * caret_energy;
		ALBEDO = lit * s;
		ALPHA = s * clamp(0.62 + 0.38 * bits * cell_on + scan + 0.35 * e + hat, 0.0, 1.0) * (0.85 + 0.15 * still);
	}
}
