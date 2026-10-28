// SIGKILL arena screens (A3): the faces of the arena's terminal screens and server racks, drawn
// procedurally, no texture or font. A screen (racks off) is a terminal: lines of glyphs of random
// length and indent scroll up a line at a time, now and then a line in the hot or the hostile colour,
// a block cursor blinking after a few of them, faint scanlines across it all. A rack (racks on) is a
// stack of 1U units, each a dark grille with four status lights at its right that blink on their own
// rhythms and a thin activity bar that jumps as it works. The face is measured in world space on its
// own plane (as the code rain does), so every screen and rack draws at the same scale at any size.
// Glyphs are 4 by 6 bit grids mirrored left to right like the daemons', from an integer hash (PCG) of
// small integers, every tick wrapped at 1024, so nothing in it grows with time.
// Defaults only mirror scripts/palette.gd so the material previews in the editor; palette.gd sets
// every value at runtime and is the single source.
shader_type spatial;
render_mode unshaded;

uniform vec4 back_color : source_color = vec4(0.008, 0.024, 0.027, 1.0);
uniform vec4 text_color : source_color = vec4(0.098, 0.827, 0.773, 1.0);
uniform vec4 hot_color : source_color = vec4(0.49, 1.0, 0.812, 1.0);
uniform vec4 alert_color : source_color = vec4(1.0, 0.2, 0.333, 1.0);
uniform bool racks = false;
uniform float energy : hint_range(0.0, 16.0) = 1.6;
uniform float glyph_m : hint_range(0.01, 0.5) = 0.055;
uniform float lines_per_s : hint_range(0.0, 10.0) = 1.5;
uniform float rack_m : hint_range(0.1, 2.0) = 0.6;
uniform float unit_m : hint_range(0.02, 0.5) = 0.09;
uniform float blink_hz : hint_range(0.0, 20.0) = 1.2;

varying vec3 world_pos;
varying vec3 world_normal;

uint pcg(uint v) {
	uint state = v * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}

// A hash of three small integers (ten bits of each), from 0 to 1.
float hash3(int a, int b, int c) {
	return float(pcg(uint(a & 0x3ff) | (uint(b & 0x3ff) << 10u) | (uint(c & 0x3ff) << 20u)) & 0xffffu) / 65535.0;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = mat3(MODEL_MATRIX) * NORMAL;
}

// This point on its face, in metres: x across it (left to right seen from the front), y up it. A
// face lying flat reads along world X and Z instead (self-review pass 1: no cross product of nothing).
vec2 face_uv() {
	vec3 n = normalize(world_normal);
	if (abs(n.y) > 0.9) {
		return world_pos.xz;
	}
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), n));
	return vec2(dot(world_pos, right), world_pos.y);
}

// Coverage of thin lines `width` wide every `every` metres along v, anti-aliased.
float lines(float v, float every, float width) {
	float d = abs(fract(v / every) - 0.5) * every;
	float fw = max(fwidth(v), 0.0001);
	return smoothstep(width * 0.5 + fw, width * 0.5 - fw, every * 0.5 - d);
}

vec3 terminal(vec2 uv) {
	vec2 cell = uv / glyph_m;
	int col = int(mod(floor(cell.x), 64.0));
	int scroll = int(mod(floor(TIME * lines_per_s), 1024.0));
	int line = int(floor(cell.y)) - scroll;
	int indent = int(floor(4.0 * hash3(line, 1, 0)));
	int len = 5 + int(floor(34.0 * hash3(line, 2, 0)));
	vec3 ink = text_color.rgb;
	float kind = hash3(line, 3, 0);
	if (kind > 0.94) {
		ink = alert_color.rgb;
	} else if (kind > 0.72) {
		ink = hot_color.rgb;
	}
	vec3 rgb = back_color.rgb;
	ivec2 g = ivec2(floor(fract(cell) * vec2(6.0, 8.0)));
	bool inside = g.x >= 1 && g.x <= 4 && g.y >= 1 && g.y <= 6;
	if (col >= indent && col < indent + len && hash3(line, 4, 0) > 0.1 && inside) {
		int m = min(g.x - 1, 4 - g.x);
		rgb += ink * energy * step(0.45, hash3(col, line, m + 2 * g.y));
	}
	// A block cursor after a few lines' text, blinking.
	if (col == indent + len && hash3(line, 5, 0) < 0.12 && inside) {
		rgb += hot_color.rgb * energy * step(0.5, fract(mod(TIME * blink_hz, 1024.0)));
	}
	return rgb * (0.8 + 0.2 * lines(uv.y, glyph_m * 0.25, glyph_m * 0.08));
}

vec3 rack(vec2 uv) {
	int unit = int(floor(uv.y / unit_m));
	float in_unit = fract(uv.y / unit_m);
	int bay = int(floor(uv.x / rack_m));
	float x = fract(uv.x / rack_m) * rack_m;
	vec3 rgb = back_color.rgb;
	rgb += text_color.rgb * 0.06 * lines(uv.x, 0.012, 0.004);  // the grille's slots
	rgb *= 1.0 - 0.75 * step(in_unit, 0.1);  // the seam under each unit
	for (int k = 0; k < 4; k++) {
		vec2 p = vec2(x - (rack_m - 0.045 - float(k) * 0.03), (in_unit - 0.55) * unit_m);
		float led = 1.0 - smoothstep(0.004, 0.007, length(p));
		float rate = 0.3 + 2.7 * hash3(unit, bay, k);
		float on = step(0.45, fract(mod(TIME * blink_hz * rate, 1024.0) + hash3(unit, bay, k + 8)));
		vec3 led_rgb = hash3(unit, bay, k + 16) > 0.95 ? alert_color.rgb : (k == 0 ? hot_color.rgb : text_color.rgb);
		rgb += led_rgb * (energy * 2.0 * led * on);
	}
	// The activity bar, its lit length jumping a few times a second.
	int tick = int(mod(floor(TIME * 3.0), 1024.0));
	float bar_m = 0.04 + 0.16 * hash3(unit, bay, tick);
	float bar = step(0.04, x) * step(x, 0.04 + bar_m) * step(abs(in_unit - 0.55), 0.07);
	rgb += text_color.rgb * (energy * 0.5 * bar);
	return rgb;
}

void fragment() {
	vec2 uv = face_uv();
	ALBEDO = racks ? rack(uv) : terminal(uv);
}
