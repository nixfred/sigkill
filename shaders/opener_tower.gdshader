shader_type spatial;
// The opener's city (C40): every box of scripts/opener/tree_layout.gd, drawn by scripts/opener/tree_fall.gd as one
// MultiMesh of unit boxes. Near-black bodies, so they stand as silhouettes against the glowing dark; their true edges
// lit in the theme's accent, the roofs brighter; on the walls a grid of windows, each lit or dark by a hash of where
// it is, as big a share lit as the folder holds entries, a few flickering. The home folder's monolith is a wall of
// dark screens round the one that is lit (its glow spilling onto the wall); a node_modules is a maze ("10 PRINT":
// one diagonal a cell); every wall reddens toward the pit, where the hottest process beats. Unshaded: all the light
// is its own, and the fog gives the depth. Once a window is a few pixels small it gives way to its average glow, so
// far towers never shimmer. Every hash is an integer hash (PCG) of small integers, as the arena's code rain's.
//
// Per box (INSTANCE_CUSTOM): r the share of windows lit, g its kind (TreeLayout.Kind), b a roll (0 to 1), a flags
// (TreeLayout.FLAG_ROOF, FLAG_SPIRE). The colours come from the opener's palette (TreeFall), these defaults only
// mirror the night palette so the material previews in the editor.
render_mode unshaded, specular_disabled;

uniform vec3 body_color : source_color = vec3(0.016, 0.018, 0.03);
uniform vec3 edge_color : source_color = vec3(0.478, 0.635, 0.969);
uniform vec3 dim_color : source_color = vec3(0.32, 0.36, 0.52);
uniform vec3 window_color : source_color = vec3(0.49, 0.65, 1.0);
uniform vec3 cool_color : source_color = vec3(0.05, 0.73, 0.84);
uniform vec3 warm_color : source_color = vec3(0.88, 0.69, 0.41);
uniform vec3 alert_color : source_color = vec3(0.97, 0.46, 0.56);
uniform vec3 maze_color : source_color = vec3(0.73, 0.6, 0.97);
uniform vec3 hot_color : source_color = vec3(1.0, 0.33, 0.42);
uniform vec3 panel_color : source_color = vec3(0.1, 0.11, 0.18);
uniform float edge_energy = 2.6;
uniform float window_energy = 1.8;
// The opener's clock (seconds), and the hot process's beat (0 to 1).
uniform float clock = 0.0;
uniform float pulse = 0.0;
// The pit's rim, where the red starts to rise from.
uniform float pit_y = -470.0;
uniform float hot_reach = 40.0;
// The lit screen on the monolith's face: its centre, half its size, how much it lights the wall round it.
uniform vec3 panel_at = vec3(0.0, 20.0, -150.0);
uniform vec2 panel_half = vec2(4.0, 2.25);
uniform float panel_spill = 1.0;

const int KIND_FOLDER = 0;
const int KIND_HIDDEN = 1;
const int KIND_UNCOUNTED = 2;
const int KIND_MAZE = 3;
const int KIND_FILLER = 4;
const int KIND_SKYLINE = 5;
const int KIND_HOME = 6;

varying vec3 local_m;
varying vec3 half_m;
varying vec3 world_pos;
varying vec3 normal_l;
varying flat vec4 custom;

uint pcg(uint v) {
	uint state = v * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}

float hash3(int a, int b, int c) {
	return float(pcg(uint(a & 0x3ff) | (uint(b & 0x3ff) << 10u) | (uint(c & 0x3ff) << 20u)) & 0xffffu) / 65535.0;
}

void vertex() {
	half_m = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz)) * 0.5;
	local_m = VERTEX * half_m * 2.0;
	normal_l = NORMAL;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	custom = INSTANCE_CUSTOM;
}

// 1 on a box's true edges, at least a pixel and a half wide however far it is.
float edge_line(float width_m) {
	vec3 d = half_m - abs(local_m);
	float lo = min(d.x, min(d.y, d.z));
	float hi = max(d.x, max(d.y, d.z));
	float mid = d.x + d.y + d.z - lo - hi;
	float px = fwidth(mid);
	float w = max(width_m, px * 1.5);
	return 1.0 - smoothstep(w * 0.5, w + px, mid);
}

void fragment() {
	int kind = int(custom.g + 0.5);
	int flags = int(custom.a + 0.5);
	int salt = int(custom.b * 997.0);
	bool side = abs(normal_l.y) < 0.5;
	vec3 rgb = body_color;
	// The wall's own coordinates, metres: across it, and up from the box's foot.
	float across = abs(normal_l.x) > 0.5 ? local_m.z : local_m.x;
	vec2 wall = vec2(across, local_m.y + half_m.y);
	int face = int(dot(normal_l, vec3(1.0, 2.0, 3.0)) + 4.0);

	vec3 edge_ink = edge_color;
	float edge_k = edge_energy;
	if (kind == KIND_HIDDEN || kind == KIND_UNCOUNTED) {
		edge_ink = dim_color;
		edge_k *= 0.8;
	} else if (kind == KIND_MAZE) {
		edge_ink = maze_color;
	} else if (kind == KIND_FILLER) {
		edge_k *= 0.42;
	} else if (kind == KIND_SKYLINE) {
		edge_k *= 0.3;
	} else if (kind == KIND_HOME) {
		edge_k *= 0.9;
	}
	float edge = edge_line(kind == KIND_SKYLINE || kind == KIND_HOME ? 0.5 : 0.22);
	bool roof = (flags & 1) != 0 && half_m.y - local_m.y < 0.6;
	rgb += edge_ink * edge * edge_k * (roof ? 1.7 : 1.0);

	if (side && kind == KIND_MAZE) {
		vec2 g = wall / 2.6;
		vec2 f = fract(g);
		ivec2 cell = ivec2(floor(g));
		float diag = hash3(cell.x + 512, cell.y + 512, face + salt) < 0.5 ? f.x - f.y : f.x + f.y - 1.0;
		float fw = fwidth(g.y);
		float line = 1.0 - smoothstep(0.07, 0.07 + fw * 2.0, abs(diag) * 0.7071);
		float far = smoothstep(0.3, 0.7, fw);
		float run = step(0.86, fract(g.y * 0.07 - clock * 0.35 + float(cell.x) * 0.13));
		rgb += maze_color * mix(line * (0.9 + 1.4 * run), 0.18, far) * 1.3;
	} else if (side && kind == KIND_HOME) {
		// A wall of dark screens, one of them lit (the panel, a mesh of its own in front of the wall).
		vec2 g = (wall - vec2(0.0, 2.0)) / vec2(10.4, 6.2);
		vec2 f = fract(g);
		ivec2 cell = ivec2(floor(g));
		float fw = max(fwidth(g.x), fwidth(g.y));
		vec2 frame = abs(f - 0.5);
		float glass = step(frame.x, 0.43) * step(frame.y, 0.4);
		float rim = glass * (1.0 - step(frame.x, 0.41) * step(frame.y, 0.37));
		float far = smoothstep(0.2, 0.5, fw);
		rgb += dim_color * mix(rim * 0.55, 0.06, far);
		float wake = hash3(cell.x + 512, cell.y + 512, 77);
		float flick = step(0.985, wake) * step(0.6, fract(clock * (0.3 + wake) + wake * 9.0));
		rgb += cool_color * glass * flick * 0.08 * (1.0 - far);
		if (normal_l.z < -0.5) {
			vec2 off = max(abs(world_pos.xy - panel_at.xy) - panel_half, vec2(0.0));
			float d = length(off);
			rgb += panel_color * panel_spill * (0.85 * exp(-d / 3.5) + 0.22 * exp(-d / 22.0));
		}
	} else if (side && custom.r > 0.0) {
		vec2 cell_m = kind == KIND_SKYLINE ? vec2(4.4, 5.4) : vec2(2.6, 3.4);
		vec2 g = wall / cell_m;
		vec2 f = fract(g);
		ivec2 cell = ivec2(floor(g));
		float roll = hash3(cell.x + 512, cell.y + 512, face * 97 + salt);
		float lit = step(roll, custom.r);
		float pick = hash3(cell.x + 512, cell.y + 512, face * 97 + salt + 401);
		if (pick < 0.05 && fract(clock * (0.4 + pick * 9.0) + roll * 5.0) < 0.35) {
			lit = 0.0;
		}
		vec3 ink = window_color;
		if (pick > 0.97) {
			ink = alert_color;
		} else if (pick > 0.84) {
			ink = warm_color;
		} else if (pick > 0.55) {
			ink = cool_color;
		}
		vec2 frame = abs(f - 0.5);
		float pane = step(frame.x, 0.3) * step(frame.y, 0.22);
		float fw = max(fwidth(g.x), fwidth(g.y));
		float far = smoothstep(0.22, 0.55, fw);
		float k = kind == KIND_FILLER ? 0.55 : (kind == KIND_SKYLINE ? 0.45 : 1.0);
		rgb += mix(ink * lit * pane, window_color * custom.r * 0.26, far) * window_energy * k;
	}
	if (side || normal_l.y < -0.5) {
		float up = max(world_pos.y - pit_y, 0.0);
		rgb += hot_color * exp(-up / hot_reach) * (0.03 + 0.05 * pulse);
	}
	ALBEDO = rgb;
}
