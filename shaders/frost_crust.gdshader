// SIGKILL chmod 000's frost (C29): what the freeze ray strips of its permissions is sealed in a shell of
// frost in an opal of its own. scripts/fx/frost_look.gd draws each of a daemon's (or a piece of ICE's)
// own MultiMeshes a second time with this material, pushed out along the normals so the shell sits on
// the creature as it stands, never a stand-in shape; an avatar wears it on a capsule round its body.
//
// The shell is ice, not plaster: see-through in the middle (the dark creature shows inside it) and
// thick at its silhouette, where it turns away from the eye; the world is cut into crystal cells (a
// three-dimensional Voronoi), each a facet with its own tilt and shade, and the cracks between them run
// bright in the frost's text colour; a few cells wink on the daemons' shared clock. `coverage` is how far
// the freeze meter has come: the frost creeps up from the feet (base_y, over height_m) in a ragged front;
// `frozen` seals the body whole, the shell thicker, its cracks and edges burning. A part whose presence
// is gone (custom z, as the daemon shaders read it) draws nothing. Lit by the arena too (glossy, so
// the lamps and the signs catch on it), with its own light so it reads in Black ICE's blackout.
// Defaults only mirror scripts/palette.gd, which sets every value at runtime.
shader_type spatial;
render_mode world_vertex_coords, blend_mix, depth_draw_never, cull_back, specular_schlick_ggx;

global uniform float daemon_clock;

uniform vec4 frost : source_color = vec4(0.659, 0.471, 0.518, 1.0);
uniform vec4 edge : source_color = vec4(0.882, 0.588, 0.635, 1.0);
uniform vec4 glint : source_color = vec4(0.961, 0.816, 0.839, 1.0);
uniform float inflate_m : hint_range(0.0, 0.2) = 0.03;
uniform float body_alpha : hint_range(0.0, 1.0) = 0.3;
uniform float rim_alpha : hint_range(0.0, 1.0) = 0.92;
uniform float rim_power : hint_range(0.5, 8.0) = 2.2;
uniform float cells_per_m : hint_range(1.0, 60.0) = 9.0;
uniform float crack_width : hint_range(0.0, 0.5) = 0.07;
uniform float crack_energy : hint_range(0.0, 16.0) = 1.9;
uniform float rim_energy : hint_range(0.0, 16.0) = 1.2;
uniform float glow_energy : hint_range(0.0, 4.0) = 0.12;
uniform float glint_energy : hint_range(0.0, 32.0) = 4.0;
uniform float glint_share : hint_range(0.0, 1.0) = 0.05;
uniform float front_noise : hint_range(0.0, 1.0) = 0.3;

instance uniform float coverage : instance_index(0) = 0.0;
instance uniform float frozen : instance_index(1) = 0.0;
instance uniform float base_y : instance_index(2) = 0.0;
instance uniform float height_m : instance_index(3) = 2.0;

varying vec4 part;
varying vec3 world_pos;

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

vec3 hash33(vec3 p) {
	return fract(sin(vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)))) * 43758.5453);
}

void vertex() {
	part = INSTANCE_CUSTOM;
	float thick = max(coverage, frozen);
	VERTEX += NORMAL * inflate_m * (0.4 + 0.6 * thick) * (0.7 + 0.3 * frozen);
	world_pos = VERTEX;
}

void fragment() {
	if (clamp(part.z, 0.0, 1.0) <= 0.001) {
		discard;
	}
	// The crystal cells: the nearest two feature points, the crack where they are equally near.
	vec3 p = world_pos * cells_per_m;
	vec3 ip = floor(p);
	vec3 fp = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	vec3 cell = ip;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			for (int z = -1; z <= 1; z++) {
				vec3 n = vec3(float(x), float(y), float(z));
				vec3 r = n + hash33(ip + n) - fp;
				float d = dot(r, r);
				if (d < d1) {
					d2 = d1;
					d1 = d;
					cell = ip + n;
				} else if (d < d2) {
					d2 = d;
				}
			}
		}
	}
	float crack = 1.0 - smoothstep(0.0, crack_width, sqrt(d2) - sqrt(d1));
	float h = hash3(cell);
	float h2 = hash3(cell + vec3(17.0, 3.0, 9.0));
	// The front: the frost has taken the body up to its coverage, ragged by the cells.
	float up = clamp((world_pos.y - base_y) / max(height_m, 0.01), 0.0, 1.0);
	float reach = max(coverage * (1.0 + front_noise), frozen * 2.0);
	if (up + h * front_noise > reach) {
		discard;
	}
	vec3 n = normalize(NORMAL + (vec3(h, h2, hash3(cell + 5.0)) - 0.5) * 0.7);
	NORMAL = n;
	float facing = abs(dot(n, normalize(VIEW)));
	float rim = pow(1.0 - facing, rim_power);
	float sealed = 0.8 + 0.2 * frozen;
	ALBEDO = mix(frost.rgb * 0.5, glint.rgb, 0.12 + 0.18 * h);
	ALPHA = clamp(mix(body_alpha, rim_alpha, rim) + crack * 0.35, 0.0, 1.0) * sealed;
	ROUGHNESS = 0.06 + 0.14 * h2;
	METALLIC = 0.0;
	SPECULAR = 1.0;
	float wink = step(1.0 - glint_share, fract(h2 * 7.0 + daemon_clock * (0.3 + h)));
	EMISSION = (edge.rgb * (crack * crack_energy + rim * rim_energy) + frost.rgb * glow_energy) * sealed + glint.rgb * wink * glint_energy * frozen;
}
