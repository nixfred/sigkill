// SIGKILL arena towers (A3): the megastructures and data towers of the void round the arena, and the
// slabs drifting through it. Unshaded and near black, so they read as silhouettes against the sky and
// the fog; their true edges drawn as thin teal lines (the shape kit's edged buckets, as the panels),
// and on their walls a grid of windows in world space, a share of them lit in teal or mint and now
// and then hostile red, each cell picked by an integer hash of where it is. Once a window is smaller
// than a couple of pixels the grid gives way to its average glow, so the far towers never shimmer.
// Defaults only mirror scripts/palette.gd so the material previews in the editor; palette.gd sets
// every value at runtime and is the single source.
shader_type spatial;
render_mode unshaded;
// Black ICE (I3) dims it: arena_light, the arena's light level (1 normal, its lights_low while it is out),
// a shader global set by scripts/ice/blackout.gd.
global uniform float arena_light;

uniform vec4 body_color : source_color = vec4(0.016, 0.027, 0.039, 1.0);
uniform vec4 edge_color : source_color = vec4(0.098, 0.827, 0.773, 1.0);
uniform vec4 window_color : source_color = vec4(0.098, 0.827, 0.773, 1.0);
uniform vec4 hot_color : source_color = vec4(0.49, 1.0, 0.812, 1.0);
uniform vec4 alert_color : source_color = vec4(1.0, 0.2, 0.333, 1.0);
uniform float edge_energy : hint_range(0.0, 16.0) = 0.8;
uniform float edge_px : hint_range(0.0, 8.0) = 1.0;
uniform float window_energy : hint_range(0.0, 16.0) = 1.1;
uniform float window_share : hint_range(0.0, 1.0) = 0.12;
uniform vec2 window_cell_m = vec2(2.2, 3.0);
uniform vec2 window_size = vec2(0.55, 0.42);

varying vec3 world_pos;
varying vec3 world_normal;
varying vec3 bary;

uint pcg(uint v) {
	uint state = v * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}

float hash3(int a, int b, int c) {
	return float(pcg(uint(a & 0x3ff) | (uint(b & 0x3ff) << 10u) | (uint(c & 0x3ff) << 20u)) & 0xffffu) / 65535.0;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = mat3(MODEL_MATRIX) * NORMAL;
	bary = CUSTOM0.rgb;
}

void fragment() {
	vec3 rgb = body_color.rgb;
	vec3 n = normalize(world_normal);
	if (abs(n.y) < 0.5 && window_share > 0.0) {
		vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), n));
		vec2 uv = vec2(dot(world_pos, right), world_pos.y) / window_cell_m;
		ivec2 cell = ivec2(floor(uv));
		int face = int(floor(dot(world_pos, n) * 0.1));
		float roll = hash3(cell.x, cell.y, face);
		vec3 ink = window_color.rgb;
		float pick = hash3(cell.x, cell.y, face + 512);
		if (pick > 0.97) {
			ink = alert_color.rgb;
		} else if (pick > 0.7) {
			ink = hot_color.rgb;
		}
		float lit = step(roll, window_share) * (0.5 + 0.5 * hash3(cell.x, cell.y, face + 256));
		vec2 f = abs(fract(uv) - 0.5);
		vec2 fw = max(fwidth(uv), vec2(0.0001));
		vec2 inside = smoothstep(window_size * 0.5 + fw, window_size * 0.5 - fw, f);
		float sharp = inside.x * inside.y;
		// Past a couple of pixels a cell, the grid becomes its average glow.
		float far = smoothstep(0.15, 0.5, max(fw.x, fw.y));
		float average = window_share * 0.75 * window_size.x * window_size.y;
		rgb += window_energy * mix(ink * lit * sharp, window_color.rgb * average, far);
	}
	vec3 bw = max(fwidth(bary), vec3(0.00001));
	vec3 near = smoothstep(bw * (edge_px - 0.5), bw * (edge_px + 0.5), bary);
	float line = 1.0 - min(min(near.x, near.y), near.z);
	ALBEDO = (rgb + edge_color.rgb * (edge_energy * line)) * arena_light;
}
