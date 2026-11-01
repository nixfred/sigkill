// SIGKILL's desktop windows (W4, scripts/keys/key_window.gd): keybind gunplay's shortcuts made physical as the windows a
// tiling desktop draws (an Omarchy window is a thin border in its theme's accent and no title bar), on one quad each.
// What is in the window by `style`:
//   0  a terminal: rows of glyph cells printing in (`typed`), the prompt in the accent, a block cursor blinking
//   1  an empty frame: a selection (a window drawn round a daemon to close, float or split)
//   2  a monitor: rows of meters, as top's header draws them
//   3  an editor: line numbers down a gutter, rows of code in two colours
// The border is drawn over-bright so the glow pass blooms it; `flash` whites the window; `seam` draws a split down its
// middle; `fade` takes it all out. Sizes are in metres (`size`), so a border is as thick on a big window as a small one.
// Visual only.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 accent : source_color = vec4(0.49, 1.0, 0.81, 1.0);
uniform vec4 ink : source_color = vec4(0.62, 0.95, 0.85, 1.0);
uniform vec2 size = vec2(2.0, 1.4);
uniform int style = 0;
uniform float body_alpha = 0.7;
uniform float glow = 2.4;
uniform float seed = 0.0;
uniform float clock = 0.0;
uniform float typed = 1.0;
uniform float flash = 0.0;
uniform float seam = 0.0;
uniform float fade = 1.0;
uniform float border = 0.035;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.13) * 43758.5453);
}

void fragment() {
	vec2 m = UV * size;
	float b = border;
	float edge = 1.0 - step(b, m.x) * step(m.x, size.x - b) * step(b, m.y) * step(m.y, size.y - b);
	// A soft halo just inside the border, so a window reads at a distance.
	float inner = min(min(m.x, size.x - m.x), min(m.y, size.y - m.y));
	float halo = (1.0 - smoothstep(b, b + 0.12, inner)) * 0.35;
	vec3 col = vec3(0.01, 0.015, 0.02);
	float a = body_alpha;
	vec2 pad = vec2(0.12, 0.1);
	vec2 c = m - pad;
	float row_h = 0.11;
	float cell_w = 0.06;
	float row = floor(c.y / row_h);
	float rows = floor((size.y - pad.y * 2.0) / row_h);
	float in_row = fract(c.y / row_h);
	float cell = floor(c.x / cell_w);
	float in_cell = fract(c.x / cell_w);
	float cols = floor((size.x - pad.x * 2.0) / cell_w);
	bool inside = c.x > 0.0 && c.y > 0.0 && row < rows && cell < cols;
	float glyph_shape = step(0.12, in_cell) * step(in_cell, 0.86) * step(0.2, in_row) * step(in_row, 0.82);
	if (style == 0 && inside) {
		float shown_rows = floor(typed * rows + 0.001);
		float len = floor(cols * (0.25 + 0.7 * hash(vec2(row, 3.0))));
		float on = step(0.32, hash(vec2(cell, row))) * step(cell, len);
		if (row < shown_rows) {
			bool prompt = cell < 1.5 && hash(vec2(row, 9.0)) > 0.45;
			vec3 g = prompt ? accent.rgb * 1.6 : ink.rgb * (0.55 + 0.45 * hash(vec2(cell * 0.3, row)));
			col = mix(col, g, on * glyph_shape * (prompt ? 1.0 : 0.85));
		}
		// The cursor: a block after the last row printed.
		float cur_row = min(shown_rows, rows - 1.0);
		float cur_cell = row == cur_row && row == shown_rows ? 0.0 : floor(cols * (0.25 + 0.7 * hash(vec2(cur_row, 3.0)))) + 1.0;
		if (row == cur_row && cell == cur_cell && fract(clock * 1.8) < 0.55) {
			col = accent.rgb * 2.0 * step(0.1, in_cell) * step(in_row, 0.92);
		}
	} else if (style == 2 && inside) {
		// Meters: a label stub, a bar filling and breathing, its numbers.
		float fill = 0.25 + 0.7 * fract(hash(vec2(row, 5.0)) + sin(clock * (0.6 + hash(vec2(row, 7.0))) + row) * 0.12);
		float u = c.x / max(size.x - pad.x * 2.0, 0.01);
		float label = step(cell, 3.0) * glyph_shape * step(0.4, hash(vec2(cell, row + 40.0)));
		float bar = step(0.22, u) * step(u, 0.22 + 0.7 * fill) * step(0.25, in_row) * step(in_row, 0.75);
		vec3 hot = mix(accent.rgb, vec3(1.0, 0.45, 0.35), smoothstep(0.6, 0.95, fill));
		col = mix(col, ink.rgb * 0.8, label);
		col = mix(col, hot * 1.3, bar * step(mod(cell, 2.0), 0.5) + bar * 0.6);
	} else if (style == 3 && inside) {
		float gutter = step(cell, 2.0);
		float len = floor(cols * (0.15 + 0.75 * hash(vec2(row, 11.0)))) + 3.0;
		float indent = 3.0 + floor(hash(vec2(row, 13.0)) * 3.0) * 2.0;
		float on = step(0.25, hash(vec2(cell, row + 70.0))) * step(cell, len) * step(indent, cell);
		vec3 word = hash(vec2(floor(cell / 4.0), row)) > 0.6 ? accent.rgb * 1.3 : ink.rgb * 0.75;
		col = mix(col, ink.rgb * 0.35, gutter * glyph_shape * step(0.3, hash(vec2(cell, row))));
		col = mix(col, word, on * glyph_shape);
	}
	col += accent.rgb * halo;
	if (edge > 0.5) {
		col = accent.rgb * glow;
		a = 1.0;
	}
	// A split down the middle: a bright seam, the halves' edges lit.
	if (seam > 0.0) {
		float d = abs(m.x - size.x * 0.5);
		float s = 1.0 - smoothstep(0.0, 0.03 + 0.08 * seam, d);
		col = mix(col, vec3(1.0, 0.98, 0.9) * 3.0, s * seam);
		a = max(a, s * seam);
	}
	col = mix(col, vec3(2.5), flash);
	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 1.0) * fade;
}
