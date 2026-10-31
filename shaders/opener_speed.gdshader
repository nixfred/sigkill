shader_type spatial;
// The air in the machine (C40, scripts/opener/tree_fall.gd): motes of light drifting in the dark round the camera,
// and, as it falls, speed lines streaking up past it, longer and brighter the faster it goes. Each instance's place
// is worked out here from its roll and the camera's position, wrapped in a box round the camera, so a hundred-odd
// quads fill all the air it ever passes through and nothing is moved on the CPU. Added to what is behind it.
//
// Per instance: INSTANCE_CUSTOM r, g, b its place in the box (0 to 1 each way), a its roll (over MOTE_FROM: a mote).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform, fog_disabled, specular_disabled;

uniform vec3 line_color : source_color = vec3(0.75, 0.8, 0.96);
uniform vec3 mote_color : source_color = vec3(0.478, 0.635, 0.969);
uniform vec3 cam_pos = vec3(0.0);
// Metres a second the camera moves (down), and how bright the motes are.
uniform float speed = 0.0;
uniform float motes = 1.0;
uniform vec3 box = vec3(70.0, 150.0, 70.0);
uniform float clock = 0.0;

const float MOTE_FROM = 0.62;

varying vec2 quad;
varying flat float is_mote;
varying flat float glow;

void vertex() {
	vec4 s = INSTANCE_CUSTOM;
	is_mote = s.a > MOTE_FROM ? 1.0 : 0.0;
	vec3 drift = is_mote > 0.5 ? vec3(sin(clock * 0.21 + s.r * 40.0), cos(clock * 0.17 + s.g * 31.0), sin(clock * 0.13 + s.b * 23.0)) * 1.5 : vec3(0.0);
	vec3 rel = mod(s.rgb * box - cam_pos + drift, box) - box * 0.5;
	float out_r = length(rel.xz);
	if (out_r < 2.5) {
		rel.xz = (out_r > 0.001 ? rel.xz / out_r : vec2(1.0, 0.0)) * 2.5;
	}
	vec3 mid = cam_pos + rel;
	float len = is_mote > 0.5 ? 0.22 : 0.6 + speed * 0.16 * (0.6 + s.a);
	float width = is_mote > 0.5 ? 0.22 : 0.07;
	vec3 a = vec3(0.0, 1.0, 0.0);
	vec3 to_cam = cam_pos - mid;
	vec3 side = cross(a, normalize(to_cam));
	side = length(side) < 0.0001 ? vec3(1.0, 0.0, 0.0) : normalize(side);
	vec3 up = is_mote > 0.5 ? normalize(cross(normalize(to_cam), side)) : a;
	vec3 world = mid + up * (VERTEX.y * len) + side * (VERTEX.x * width);
	quad = VERTEX.xy * 2.0;
	float edge = (1.0 - smoothstep(box.y * 0.3, box.y * 0.5, abs(rel.y))) * (1.0 - smoothstep(box.x * 0.3, box.x * 0.5, out_r));
	glow = edge * (is_mote > 0.5 ? motes * (0.4 + 0.6 * s.r) : smoothstep(5.0, 32.0, speed) * (0.35 + 0.65 * s.g));
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	NORMAL = normalize((VIEW_MATRIX * vec4(to_cam, 0.0)).xyz);
}

void fragment() {
	float shape;
	vec3 ink;
	if (is_mote > 0.5) {
		shape = max(1.0 - length(quad), 0.0);
		shape *= shape;
		ink = mote_color;
	} else {
		shape = exp(-quad.x * quad.x * 6.0) * (1.0 - abs(quad.y));
		ink = line_color;
	}
	ALBEDO = ink * shape * glow * (is_mote > 0.5 ? 1.3 : 2.2);
}
