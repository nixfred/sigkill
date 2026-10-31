shader_type spatial;
// The node_modules pit (C40, scripts/opener/tree_fall.gd): the inside walls of a well under the bottom of the
// directory tree, and of a smaller one inside it, going down further than the fog lets you see. Their walls are a
// maze ("10 PRINT": one diagonal a cell, picked by a hash), lit in the theme's magenta and brighter toward the
// bottom, light running down its passages, the whole pit flushing red with the hottest process's beat at the
// bottom. Unshaded; the fog makes it bottomless.
//
// Per vertex UV: the well's centre (x, z); UV2.x its radius.
render_mode unshaded, cull_disabled, specular_disabled;

uniform vec3 wall_color : source_color = vec3(0.012, 0.01, 0.02);
uniform vec3 maze_color : source_color = vec3(0.73, 0.6, 0.97);
uniform vec3 hot_color : source_color = vec3(1.0, 0.33, 0.42);
uniform float clock = 0.0;
uniform float pulse = 0.0;
uniform float pit_y = -470.0;
uniform float core_y = -700.0;

varying vec3 world_pos;
varying flat vec2 centre;
varying flat float radius;

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
	centre = UV;
	radius = UV2.x;
}

void fragment() {
	vec2 rel = world_pos.xz - centre;
	float around = atan(rel.y, rel.x) * radius;
	vec2 g = vec2(around, world_pos.y) / 3.0;
	ivec2 cell = ivec2(floor(g));
	vec2 f = fract(g);
	float diag = hash3(cell.x + 512, cell.y + 512, int(radius)) < 0.5 ? f.x - f.y : f.x + f.y - 1.0;
	float fw = max(fwidth(g.x), fwidth(g.y));
	float line = 1.0 - smoothstep(0.06, 0.06 + fw * 2.0, abs(diag) * 0.7071);
	float far = smoothstep(0.3, 0.7, fw);
	float run = step(0.9, fract(g.y * 0.05 + clock * 0.5 + hash3(cell.x + 512, 9, 5) * 3.0));
	float down = max(pit_y - world_pos.y, 0.0);
	float near_core = exp(-abs(world_pos.y - core_y) / 110.0);
	vec3 rgb = wall_color;
	rgb += maze_color * mix(line, 0.16, far) * (0.55 + 0.9 * smoothstep(0.0, 220.0, down) + 1.6 * run);
	rgb += hot_color * (0.15 + 0.85 * near_core) * (0.45 + 0.55 * pulse) * 0.9;
	ALBEDO = rgb;
}
