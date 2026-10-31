shader_type spatial;
// The opener's terraces and the machine's ceiling (C40, scripts/opener/tree_fall.gd): one mesh of flat rings, a level
// of the directory tree each, stepping down and in round the shaft, and a disc over everything. On a terrace a
// faint floor grid and, at its inner edge, a rim of light in the theme's accent with packets running round it: the
// rings you fall through. The pit's rim terrace burns red toward the pit. The ceiling carries circuit traces with
// light running along them: you are inside the machine. Underneath, only the rim shows.
//
// Per vertex UV: x the ring's inner radius, y its kind: 0 a terrace, 1 the ceiling, 2 the pit's rim.
render_mode unshaded, cull_disabled, specular_disabled;

uniform vec3 floor_color : source_color = vec3(0.012, 0.014, 0.024);
uniform vec3 grid_color : source_color = vec3(0.478, 0.635, 0.969);
uniform vec3 rim_color : source_color = vec3(0.478, 0.635, 0.969);
uniform vec3 trace_color : source_color = vec3(0.32, 0.36, 0.52);
uniform vec3 hot_color : source_color = vec3(1.0, 0.33, 0.42);
uniform vec3 maze_color : source_color = vec3(0.73, 0.6, 0.97);
uniform float rim_energy = 3.2;
uniform float grid_energy = 0.35;
uniform float clock = 0.0;
uniform float pulse = 0.0;
uniform float pit_r = 30.0;

varying vec3 world_pos;
varying flat vec2 info;

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
	info = UV;
}

// Lines every `cell` metres in the floor's plane, a pixel wide at least, fading to their average far off.
float grid(vec2 p, float cell) {
	vec2 g = p / cell;
	vec2 fw = fwidth(g);
	vec2 d = abs(fract(g - 0.5) - 0.5) / max(fw, vec2(0.0001));
	float line = 1.0 - min(min(d.x, d.y), 1.0);
	return mix(line, 0.06, smoothstep(0.15, 0.5, max(fw.x, fw.y)));
}

void fragment() {
	float r = length(world_pos.xz);
	float angle = atan(world_pos.z, world_pos.x);
	vec3 rgb = floor_color;
	int kind = int(info.y + 0.5);
	if (kind == 1) {
		// Circuit traces: a run along one axis in each 14 m cell, a pad at its end, light running along some.
		vec2 g = world_pos.xz / 14.0;
		ivec2 cell = ivec2(floor(g));
		vec2 f = fract(g);
		float h = hash3(cell.x + 512, cell.y + 512, 3);
		float along = h < 0.5 ? f.x : f.y;
		float off = h < 0.5 ? f.y : f.x;
		float lane = fract(h * 7.0) * 0.6 + 0.2;
		float fw = fwidth(g.x) * 1.5;
		float run = (1.0 - smoothstep(0.012, 0.012 + fw, abs(off - lane))) * step(0.15, along) * step(along, 0.85);
		float pad = 1.0 - smoothstep(0.035, 0.035 + fw, length(vec2(along - 0.85, off - lane)));
		float light = step(0.9, fract(along * 0.5 - clock * 0.25 + h * 3.0)) * step(0.6, fract(h * 13.0));
		float far = smoothstep(0.08, 0.3, fw);
		rgb += trace_color * mix((run + pad) * (0.5 + 2.5 * light), 0.05, far);
	} else {
		float rim_d = r - info.x;
		float top = FRONT_FACING ? 1.0 : 0.0;
		rgb += grid_color * grid(world_pos.xz, 6.0) * grid_energy * top;
		float rim = exp(-max(rim_d, 0.0) / 0.7) + 0.35 * exp(-abs(rim_d - 3.2) / 0.25);
		float packets = step(0.82, fract(angle * 7.0 - clock * 0.4 + info.x * 0.01));
		rgb += rim_color * rim * rim_energy * (0.7 + 0.6 * packets);
		if (kind == 2) {
			// Red at the pit's edge, gone a few metres out (these are linear values: a little goes a long way).
			float toward = exp(-max(r - pit_r, 0.0) / 1.6);
			rgb += hot_color * toward * (0.45 + 0.55 * pulse) * 0.8;
			rgb += hot_color * grid(world_pos.xz, 3.0) * 0.12 * exp(-max(r - pit_r, 0.0) / 9.0) * top;
			// The pit's maze spills out over its rim, fading a few metres out.
			vec2 g = world_pos.xz / 2.5;
			ivec2 cell = ivec2(floor(g));
			vec2 f = fract(g);
			float diag = hash3(cell.x + 512, cell.y + 512, 11) < 0.5 ? f.x - f.y : f.x + f.y - 1.0;
			float fwm = fwidth(g.x);
			float maze = 1.0 - smoothstep(0.06, 0.06 + fwm * 2.0, abs(diag) * 0.7071);
			rgb += maze_color * maze * exp(-max(r - pit_r, 0.0) / 2.5) * (0.6 + 0.4 * pulse) * top;
		}
	}
	ALBEDO = rgb;
}
