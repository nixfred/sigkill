// SIGKILL arena panels (A3): the gunmetal of the arena's trims, caps, ribs, racks, pylons and the
// stepped plinth it stands on. Lit, so the sun and the room light shade each face of a bevel or a
// step differently and the dressing reads as depth; its true edges drawn as thin lines of the player
// side's teal (the shape kit's edged buckets carry each vertex's place in its triangle in CUSTOM0,
// the triangulation's inner edges out of reach), about edge_px wide on screen and fading out with
// distance so far edges never crowd into a shimmer; and a little darker near the floor, where
// grime_m above it, like dirt and contact shadow.
// Defaults only mirror scripts/palette.gd so the material previews in the editor; palette.gd sets
// every value at runtime and is the single source.
shader_type spatial;

// Black ICE (I3) dims it: arena_light, the arena's light level (1 normal, its lights_low while it is out),
// a shader global set by scripts/ice/blackout.gd.
global uniform float arena_light;

uniform vec4 base_color : source_color = vec4(0.063, 0.086, 0.106, 1.0);
uniform vec4 edge_color : source_color = vec4(0.098, 0.827, 0.773, 1.0);
uniform float edge_energy : hint_range(0.0, 16.0) = 0.9;
uniform float edge_px : hint_range(0.0, 8.0) = 1.0;
uniform float edge_fade_m : hint_range(1.0, 400.0) = 45.0;
uniform float metallic_amount : hint_range(0.0, 1.0) = 0.55;
uniform float roughness_amount : hint_range(0.0, 1.0) = 0.45;
uniform float grime : hint_range(0.0, 1.0) = 0.45;
uniform float grime_m : hint_range(0.01, 4.0) = 0.6;

varying vec3 world_pos;
varying vec3 bary;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	bary = CUSTOM0.rgb;
}

void fragment() {
	ALBEDO = base_color.rgb * mix(1.0 - grime, 1.0, smoothstep(0.0, grime_m, world_pos.y));
	METALLIC = metallic_amount;
	ROUGHNESS = roughness_amount;
	vec3 fw = max(fwidth(bary), vec3(0.00001));
	vec3 near = smoothstep(fw * (edge_px - 0.5), fw * (edge_px + 0.5), bary);
	float line = 1.0 - min(min(near.x, near.y), near.z);
	float fade = 1.0 - smoothstep(edge_fade_m * 0.5, edge_fade_m, distance(world_pos, CAMERA_POSITION_WORLD));
	EMISSION = edge_color.rgb * (edge_energy * line * fade) * arena_light;
}
