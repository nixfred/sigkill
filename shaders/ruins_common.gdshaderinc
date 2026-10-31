// SIGKILL ruins (C36): what every ruins shader shares. The register the ruins stand in (ruins_mix: x tron, y cyberpunk,
// z matrix, w "all", the finale's three at once mixed across the place by a slow noise in world space), a register
// shift's tear (ruins_tear), the arena's clock (stepped at the game's pace, so SIGSTOP slows the ruins too) and light
// level (Black ICE dims them), integer hashes (PCG: nothing in them grows with time), a value noise, and the code
// rain's glyphs. All globals are set by scripts/ruins/ruins_world.gd; scripts/ice/blackout.gd sets arena_light.

global uniform vec4 ruins_mix;
global uniform float ruins_tear;
global uniform float arena_clock;
global uniform float arena_light;

uint ruins_pcg(uint v) {
	uint state = v * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}

// Three integers to 0 to 1, 24 bits of spread whatever their size.
float ruins_hash(int a, int b, int c) {
	uint h = ruins_pcg(uint(a) + ruins_pcg(uint(b) + ruins_pcg(uint(c))));
	return float(h >> 8u) * (1.0 / 16777216.0);
}

// A smooth value noise of a point on a plane, 0 to 1.
float ruins_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	ivec2 c = ivec2(i);
	float a = ruins_hash(c.x, c.y, 91);
	float b = ruins_hash(c.x + 1, c.y, 91);
	float d = ruins_hash(c.x, c.y + 1, 91);
	float e = ruins_hash(c.x + 1, c.y + 1, 91);
	return mix(mix(a, b, u.x), mix(d, e, u.x), u.y);
}

float ruins_fbm(vec2 p) {
	return ruins_noise(p) * 0.55 + ruins_noise(p * 2.13 + 7.1) * 0.3 + ruins_noise(p * 4.7 + 3.3) * 0.15;
}

// How much of each register this place stands in (tron, cyberpunk, matrix), summing to 1.
vec3 ruins_weights(vec3 world) {
	vec3 w = ruins_mix.xyz;
	if (ruins_mix.w > 0.0) {
		float t = arena_clock * 0.015;
		vec3 n = vec3(ruins_noise(world.xz / 34.0 + vec2(t, 0.0)), ruins_noise(world.xz / 29.0 + vec2(5.2, -t)), ruins_noise(world.xz / 31.0 + vec2(-t, 9.7)));
		n = pow(n, vec3(3.0));
		w += ruins_mix.w * n / max(n.x + n.y + n.z, 0.0001);
	}
	return w / max(w.x + w.y + w.z, 0.0001);
}

// A register shift's glitch at this height: how strongly this band of the place tears now, 0 to 1.
float ruins_tear_band(vec3 world) {
	if (ruins_tear <= 0.0) {
		return 0.0;
	}
	int band = int(floor(world.y * 4.0 + world.x * 0.02));
	int tick = int(mod(floor(arena_clock * 24.0), 1024.0));
	return step(1.0 - ruins_tear * 0.22, ruins_hash(band, tick, 17)) * ruins_tear;
}

// One code-rain glyph (as shaders/code_rain.gdshader draws them): 1 where a bit of a 4 by 6 grid is lit, mirrored
// left to right so it reads as a character; column, row and tick pick the shape.
float ruins_glyph(vec2 cell, int column, int row, int tick) {
	ivec2 g = ivec2(floor(cell * vec2(6.0, 8.0)));
	if (g.x < 1 || g.x > 4 || g.y < 1 || g.y > 6) {
		return 0.0;
	}
	int mirrored = min(g.x - 1, 4 - g.x);
	return step(0.45, ruins_hash(column, row, mirrored + 8 * g.y + 64 * tick));
}

// Code rain on a surface: `uv` its place in metres (x across, y down the stream), glyphs `size` metres; `density` of
// the columns carry a stream. Returns [head, tail] brightness for the head and tail colours.
vec2 ruins_rain(vec2 uv, float size, float density) {
	vec2 g = uv / size;
	int column = int(floor(g.x));
	if (ruins_hash(column, 1, 0) > density) {
		return vec2(0.0);
	}
	int row = int(floor(g.y));
	float speed = mix(3.0, 9.0, ruins_hash(column, 2, 0));
	int tail = 12;
	int cycle = tail + int(floor(float(tail) * (0.5 + ruins_hash(column, 3, 0))));
	int steps = int(floor(arena_clock * speed + ruins_hash(column, 4, 0) * float(cycle)));
	int k = int(mod(float(row + steps), float(cycle)));
	if (k >= tail) {
		return vec2(0.0);
	}
	int tick = int(mod(floor(arena_clock * 6.0 + ruins_hash(column, 5, row) * 8.0), 1024.0));
	float bits = ruins_glyph(fract(g), column, row, tick);
	if (k == 0) {
		return vec2(bits, 0.0);
	}
	float fade = 1.0 - float(k) / float(tail);
	return vec2(0.0, fade * fade * bits);
}

// Distance to the nearest crack of a crazed network at `p` (a cellular noise's second nearest minus nearest), in its
// cells: the floor's cracks and (C37) a monolith's glass.
float ruins_crack(vec2 p) {
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

// Anti-aliased coverage of a line `width` wide at distance `d` from it, fading once a pixel is wider than the line.
float ruins_line(float d, float width) {
	float fw = max(fwidth(d), 0.00001);
	return (1.0 - smoothstep(width * 0.5 - fw, width * 0.5 + fw, d)) * min(1.0, width / fw);
}
