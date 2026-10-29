// SIGKILL chmod 000's frost (C29): what the freeze ray strips of its permissions is crusted over in a
// frost opal of its own. scripts/fx/frost_look.gd draws each of a daemon's (or a piece of ICE's) own
// MultiMeshes a second time with this material, pushed out along the normals so the crust sits on the
// creature as it stands, never a stand-in shape; an avatar wears it on a capsule round its body.
//
// The crust is crystalline: the world is cut into cells, each a facet with its own tilt and shade, so
// the light breaks on it; a rim of frost where it turns away, and glints that wink cell by cell on the
// daemons' shared clock. `coverage` is how far the freeze meter has come: the frost creeps up from the
// feet (base_y, over height_m) in a ragged front as it fills; `frozen` takes it whole and bright, the
// crust thicker. A part whose presence is gone (custom z, as the daemon shaders read it) draws nothing.
// Lit by the arena too, so it has the sheen of ice, and its own light so it reads in the dark (Black
// ICE's blackout). Defaults only mirror scripts/palette.gd, which sets every value at runtime.
shader_type spatial;
render_mode world_vertex_coords, cull_back, specular_schlick_ggx;

global uniform float daemon_clock;

uniform vec4 frost : source_color = vec4(0.659, 0.471, 0.518, 1.0);
uniform vec4 glint : source_color = vec4(0.961, 0.816, 0.839, 1.0);
uniform float inflate_m : hint_range(0.0, 0.2) = 0.035;
uniform float albedo_mix : hint_range(0.0, 1.0) = 0.55;
uniform float light_energy : hint_range(0.0, 8.0) = 0.45;
uniform float frozen_energy : hint_range(0.0, 8.0) = 1.1;
uniform float rim_energy : hint_range(0.0, 16.0) = 2.4;
uniform float rim_power : hint_range(0.5, 8.0) = 2.6;
uniform float glint_energy : hint_range(0.0, 32.0) = 7.0;
uniform float glint_share : hint_range(0.0, 1.0) = 0.06;
uniform float cells_per_m : hint_range(1.0, 60.0) = 11.0;
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

void vertex() {
	part = INSTANCE_CUSTOM;
	float thick = max(coverage, frozen);
	VERTEX += NORMAL * inflate_m * (0.35 + 0.65 * thick) * (0.6 + 0.4 * frozen);
	world_pos = VERTEX;
}

void fragment() {
	if (clamp(part.z, 0.0, 1.0) <= 0.001) {
		discard;
	}
	vec3 cell = floor(world_pos * cells_per_m);
	float h = hash3(cell);
	float h2 = hash3(cell + vec3(17.0, 3.0, 9.0));
	// The front: the frost has taken the body up to its coverage, ragged by the cells.
	float up = clamp((world_pos.y - base_y) / max(height_m, 0.01), 0.0, 1.0);
	float reach = max(coverage * (1.0 + front_noise), frozen * 2.0);
	if (up + h * front_noise > reach) {
		discard;
	}
	// Each cell a facet: its own tilt, so the light breaks on it, and its own shade.
	vec3 n = normalize(NORMAL + (vec3(h, h2, hash3(cell + 5.0)) - 0.5) * 0.9);
	NORMAL = n;
	float facing = abs(dot(n, normalize(VIEW)));
	float rim = pow(1.0 - facing, rim_power);
	vec3 base = mix(frost.rgb, glint.rgb, albedo_mix * (0.5 + 0.5 * h));
	ALBEDO = base * (0.6 + 0.4 * frozen);
	ROUGHNESS = 0.18 + 0.2 * h2;
	METALLIC = 0.0;
	SPECULAR = 0.9;
	float wink = step(1.0 - glint_share, fract(h2 * 7.0 + daemon_clock * (0.3 + h)));
	float lit = mix(light_energy, frozen_energy, frozen);
	EMISSION = frost.rgb * lit * (0.6 + 0.4 * h) + glint.rgb * (rim * rim_energy * (0.4 + 0.6 * frozen) + wink * glint_energy * frozen);
}
