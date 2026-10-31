shader_type spatial;
// The opener's moving light (C40, scripts/opener/tree_fall.gd), one quad an instance turned about its own long axis
// to face the camera: streams of code light pouring down the shaft from the ceiling (glyph columns stepping down,
// a bright head and a fading tail, as the arena's code rain, over a faint core so a far stream still reads as a
// shaft of light), and the tree's cables, a folder's rim hung to each folder in it, packets of light running down
// them. Added to what is behind it; it fades with distance as the fog would.
//
// Per instance: the transform's Y axis is the quad's length (top to bottom), X its width; INSTANCE_CUSTOM r a roll
// (0 to 1), g 1 for the pit's cable (magenta), b how bright.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform, fog_disabled, specular_disabled;

uniform vec3 code_color : source_color = vec3(0.62, 0.81, 0.42);
uniform vec3 head_color : source_color = vec3(0.85, 1.0, 0.75);
uniform vec3 cable_color : source_color = vec3(0.478, 0.635, 0.969);
uniform vec3 pit_color : source_color = vec3(0.73, 0.6, 0.97);
// 0 streams of code, 1 cables.
uniform float mode = 0.0;
uniform float clock = 0.0;
uniform float fog_density = 0.0028;
// A glyph's cell, metres, and how many glyph rows a second a stream falls.
uniform vec2 glyph_m = vec2(0.9, 1.25);
uniform float fall_rate = 9.0;

varying vec2 along;
varying float dist;
varying flat vec4 custom;
varying flat float len_m;
varying flat float width_m;

uint pcg(uint v) {
	uint state = v * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}

float hash3(int a, int b, int c) {
	return float(pcg(uint(a & 0x3ff) | (uint(b & 0x3ff) << 10u) | (uint(c & 0x3ff) << 20u)) & 0xffffu) / 65535.0;
}

void vertex() {
	vec3 mid = MODEL_MATRIX[3].xyz;
	vec3 axis = MODEL_MATRIX[1].xyz;
	float len = max(length(axis), 0.001);
	vec3 a = axis / len;
	float width = length(MODEL_MATRIX[0].xyz);
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 side = cross(a, normalize(cam - mid));
	side = length(side) < 0.0001 ? vec3(1.0, 0.0, 0.0) : normalize(side);
	vec3 world = mid + a * (VERTEX.y * len) + side * (VERTEX.x * width);
	along = vec2(VERTEX.x * 2.0, (0.5 - VERTEX.y) * len);
	len_m = len;
	width_m = width;
	dist = distance(world, cam);
	custom = INSTANCE_CUSTOM;
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	NORMAL = normalize((VIEW_MATRIX * vec4(cam - world, 0.0)).xyz);
}

float glyph(vec2 cell, int column, int row, int tick) {
	ivec2 g = ivec2(floor(cell * vec2(4.0, 6.0)));
	if (g.x < 1 || g.x > 2 || g.y < 1 || g.y > 4) {
		return 0.0;
	}
	return step(0.45, hash3(column, row, g.x + 4 * g.y + 32 * tick));
}

void fragment() {
	float fade = exp(-dist * fog_density);
	float ends = smoothstep(0.0, 6.0, along.y) * smoothstep(0.0, 3.0, len_m - along.y);
	float across = abs(along.x);
	vec3 rgb = vec3(0.0);
	if (mode < 0.5) {
		float core = exp(-across * 3.5) * 0.16;
		int columns = max(int(width_m / glyph_m.x), 1);
		float u = (along.x * 0.5 + 0.5) * float(columns);
		int column = int(floor(u)) + int(custom.r * 600.0);
		float v = along.y / glyph_m.y;
		int row = int(floor(v));
		float fw = fwidth(v);
		float speed = fall_rate * (0.7 + 0.6 * hash3(column, 3, 1));
		int tail = 9 + int(hash3(column, 4, 1) * 10.0);
		int cycle = tail + 6 + int(hash3(column, 5, 1) * 18.0);
		int step_count = int(floor(clock * speed + hash3(column, 6, 1) * float(cycle)));
		int k = int(mod(float(row - step_count), float(cycle)));
		float bits = glyph(vec2(fract(u), fract(v)), column, row, int(mod(floor(clock * 6.0 + float(row)), 64.0)));
		vec3 ink = vec3(0.0);
		if (k < tail) {
			float t = 1.0 - float(k) / float(tail);
			ink = (k == 0 ? head_color * 1.6 : code_color * t * t) * bits;
		}
		float far = smoothstep(0.35, 0.8, fw);
		rgb = mix(ink * 1.5, code_color * 0.22, far) + code_color * core;
		float splash = exp(-(len_m - along.y) / 2.5) * exp(-across * 1.5);
		rgb += head_color * splash * 0.8;
	} else {
		vec3 ink = custom.g > 0.5 ? pit_color : cable_color;
		float core = exp(-across * across * 9.0);
		float packets = step(0.93, fract(along.y / 18.0 - clock * 0.9 + custom.r * 5.0));
		rgb = ink * core * (0.9 + 3.0 * packets);
	}
	ALBEDO = rgb * fade * ends * custom.b;
}
