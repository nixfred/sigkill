shader_type canvas_item;
// Theme-shift levels (W3): the whole frame in a terminal theme's colours, and the shift between two themes as a
// palette tear. Drawn by scripts/themes/theme_grade.gd on a layer over the 3D view, the HUD and the menu (under the
// colourblind filter), only while the theme shift runs; the sums are scripts/themes/theme_look.gd's (grade(), kept the
// same: the tests read RAMP_AT and HUE_AT back out of this file).
//
// The grade: a colour's lightness down the theme's ramp of shades (a light theme's runs the other way), and its hue to
// the theme's colour of that name, lifted toward the source's brightness (at most LIFT_MOST), mixed in by how coloured
// the source is.
// The tear: the screen in bands of uneven height, each torn across from one side at its own moment; the old theme on
// one side of each band's front and the new on the other; each band slid sideways and split red from blue while it
// tears; a seam of the new theme's accent along every front; blocks near the fronts glitching between the two; a flash
// at the middle of it.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

// The theme now (a) and the theme torn in (b): ramp shades and hue colours (vec4, alpha unused), light 1 for a light
// theme.
uniform vec4 ramp_a[6];
uniform vec4 hue_a[13];
uniform float light_a = 0.0;
uniform vec4 back_a : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 ramp_b[6];
uniform vec4 hue_b[13];
uniform float light_b = 0.0;
uniform vec4 back_b : source_color = vec4(0.0, 0.0, 0.0, 1.0);
// 0 the plain picture, 1 graded (eases in as the mode begins).
uniform float strength = 1.0;
// The tear's progress: 0 all a, 1 all b; its own seed, its seam's colour (b's accent) and its time.
uniform float tear = 0.0;
uniform float tear_seed = 0.0;
uniform vec4 seam : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float clock = 0.0;

const float RAMP_AT[6] = float[](0.0, 0.07, 0.2, 0.42, 0.75, 1.0);
const float HUE_AT[13] = float[](20.0, 42.0, 60.0, 85.0, 130.0, 160.0, 178.0, 200.0, 228.0, 265.0, 300.0, 325.0, 350.0);
const float SAT_FROM = 0.06;
const float SAT_TO = 0.4;
const float INK = 1.15;
const float LIFT_MOST = 1.15;
const float BANDS = 26.0;

float luma(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

float hue_of(vec3 c) {
	float hi = max(c.r, max(c.g, c.b));
	float lo = min(c.r, min(c.g, c.b));
	float d = hi - lo;
	if (d <= 0.00001) {
		return 0.0;
	}
	float h;
	if (hi == c.r) {
		h = mod((c.g - c.b) / d, 6.0);
	} else if (hi == c.g) {
		h = (c.b - c.r) / d + 2.0;
	} else {
		h = (c.r - c.g) / d + 4.0;
	}
	return h * 60.0;
}

vec3 ramp_of(float l, bool b) {
	l = clamp(l, 0.0, 1.0);
	for (int i = 1; i < 6; i++) {
		if (l <= RAMP_AT[i]) {
			float u = (l - RAMP_AT[i - 1]) / max(RAMP_AT[i] - RAMP_AT[i - 1], 0.00001);
			return b ? mix(ramp_b[i - 1].rgb, ramp_b[i].rgb, u) : mix(ramp_a[i - 1].rgb, ramp_a[i].rgb, u);
		}
	}
	return b ? ramp_b[5].rgb : ramp_a[5].rgb;
}

vec3 hue_target(float h, bool b) {
	h = mod(h, 360.0);
	for (int i = 0; i < 13; i++) {
		float a = HUE_AT[i];
		int j = (i + 1) % 13;
		float e = HUE_AT[j] + (i == 12 ? 360.0 : 0.0);
		float hh = h + ((i == 12 && h < a) ? 360.0 : 0.0);
		if (hh >= a && hh < e) {
			float u = (hh - a) / (e - a);
			return b ? mix(hue_b[i].rgb, hue_b[j].rgb, u) : mix(hue_a[i].rgb, hue_a[j].rgb, u);
		}
	}
	return b ? hue_b[0].rgb : hue_a[0].rgb;
}

vec3 grade(vec3 c, bool b) {
	float l = luma(c);
	float v = max(c.r, max(c.g, c.b));
	float chroma = v - min(c.r, min(c.g, c.b));
	float sat = smoothstep(SAT_FROM, SAT_TO, chroma);
	vec3 base = ramp_of(l, b);
	vec3 target = hue_target(hue_of(c), b);
	vec3 tint;
	if ((b ? light_b : light_a) > 0.5) {
		tint = mix(b ? back_b.rgb : back_a.rgb, target, clamp(v * INK, 0.0, 1.0));
	} else {
		float top = max(target.r, max(target.g, target.b));
		tint = target * min(v / max(top, 0.01), LIFT_MOST);
	}
	return mix(base, tint, sat);
}

float hash(float n) {
	return fract(sin(n * 12.9898 + tear_seed * 78.233) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	if (tear <= 0.0 || tear >= 1.0) {
		vec3 c = texture(screen_texture, uv).rgb;
		vec3 g = grade(c, tear >= 1.0);
		COLOR = vec4(mix(c, g, strength), 1.0);
	} else {
		// The band this pixel is in: bands of uneven height (two rows of hashes), each with its own moment and side.
		float row = floor(uv.y * BANDS + hash(floor(uv.y * BANDS * 0.5)) * 0.9);
		float delay = hash(row) * 0.42;
		float p = clamp((tear - delay) / 0.5, 0.0, 1.0);
		p = p * p * (3.0 - 2.0 * p);
		bool from_left = hash(row + 31.0) > 0.5;
		float x = from_left ? uv.x : 1.0 - uv.x;
		// The band slides sideways while it tears (most at the middle of its own tear), and splits red from blue.
		float live = 4.0 * p * (1.0 - p);
		float slide = (hash(row + 7.0) - 0.5) * 0.09 * live;
		vec2 at = vec2(uv.x + slide, uv.y);
		float split = 0.006 * live;
		vec3 c = vec3(texture(screen_texture, at + vec2(split, 0.0)).r, texture(screen_texture, at).g, texture(screen_texture, at - vec2(split, 0.0)).b);
		bool is_b = x < p * 1.08 - 0.04;
		// Blocks near the front glitch between the two.
		float near = 1.0 - smoothstep(0.0, 0.12, abs(x - p));
		vec2 block = floor(uv * vec2(48.0, 27.0));
		float flip = hash(block.x * 3.1 + block.y * 17.7 + floor(clock * 24.0));
		if (near > 0.0 && flip < 0.35 * near * live) {
			is_b = !is_b;
		}
		vec3 g = grade(c, is_b);
		// The seam along the front: the new theme's accent, hot at the front and fading behind it.
		float edge = 1.0 - smoothstep(0.0, 0.012, abs(x - (p * 1.08 - 0.04)));
		g = mix(g, seam.rgb * 1.6, edge * live);
		// A flash across the whole frame at the middle of the shift.
		g += seam.rgb * 0.22 * (1.0 - smoothstep(0.0, 0.18, abs(tear - 0.5)));
		COLOR = vec4(mix(c, g, strength), 1.0);
	}
}
