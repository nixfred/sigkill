shader_type canvas_item;
// The opener's fake crash (C38): the game's own last frame, frozen, coming apart the way a stalled renderer's
// picture does: slices of it slipping sideways, a stretch of rows smeared down from one row, blocks stuck on one
// colour, the colour channels pulled apart, a few bands with their colour corrupted (toward the daemons' magenta)
// and the colours banding as their depth drops. Drawn on the frozen frame's own rectangle by scripts/opener/
// opener.gd, which steps `seed` at most a few times a second and sets `dark` from its brightness model, so the
// picture changes in jerks, as a broken one does, but never strobes: none of this moves the screen's overall
// brightness much, and every drop to black is the opener's model's, flash-capped.

// 0 is the frame as it froze, 1 as far gone as it gets.
uniform float amount : hint_range(0.0, 1.0) = 0.0;
// The pattern: a new one for each step.
uniform float seed = 0.0;
// 1 is black.
uniform float dark : hint_range(0.0, 1.0) = 0.0;
// A corrupted band's tint.
uniform vec4 bleed : source_color = vec4(1.0, 0.17, 0.84, 1.0);
// The window's height in pixels, so blocks keep their size at any resolution.
uniform float lines = 1080.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float k = lines / 1080.0;
	// Slices of varying height, some slipped sideways.
	float band_h = 1.0 / mix(14.0, 42.0, hash(vec2(seed, 1.0)));
	float band = floor(uv.y / band_h);
	float slip = step(1.0 - amount * 0.55, hash(vec2(band, seed)));
	uv.x += slip * (hash(vec2(band, seed + 7.0)) - 0.5) * 0.16 * amount;
	// A stretch of rows repeating one row: a frame half drawn.
	float smear_top = hash(vec2(seed, 3.0));
	float smear_len = 0.14 * amount * hash(vec2(seed, 4.0));
	if (amount > 0.35 && uv.y > smear_top && uv.y < smear_top + smear_len) {
		uv.y = smear_top;
	}
	// Blocks stuck on one colour, in runs along a row of blocks, as a decoder fails.
	vec2 block = vec2(32.0 * k) * TEXTURE_PIXEL_SIZE;
	vec2 cell = floor(uv / block);
	float row_bad = step(1.0 - amount * 0.45, hash(vec2(cell.y, seed + 21.0)));
	float run_len = floor(mix(3.0, 9.0, hash(vec2(cell.y, seed + 5.0))));
	float run = floor(cell.x / run_len);
	float stuck = row_bad * step(0.45, hash(vec2(run, cell.y + seed * 1.7)));
	// A broken run smears its first block's colour across the rest of it.
	vec2 at = mix(uv, (vec2(run * run_len, cell.y) + 0.5) * block, stuck);
	// The channels pulled apart.
	float split = 0.004 * amount;
	vec3 rgb;
	rgb.r = texture(TEXTURE, at + vec2(split, 0.0)).r;
	rgb.g = texture(TEXTURE, at).g;
	rgb.b = texture(TEXTURE, at - vec2(split, 0.0)).b;
	// A few bands with their colour corrupted: channels swapped, the bleed coming through at the same brightness.
	float bad = step(1.0 - amount * 0.18, hash(vec2(band, seed + 13.0)));
	float lum = dot(rgb, vec3(0.299, 0.587, 0.114));
	vec3 corrupt = mix(rgb.brg, bleed.rgb * lum * 1.6, 0.5);
	rgb = mix(rgb, corrupt, bad);
	// The colour depth dropping.
	float levels = mix(256.0, 12.0, amount * amount);
	rgb = floor(rgb * levels + 0.5) / levels;
	COLOR = vec4(rgb * (1.0 - dark), 1.0);
}
