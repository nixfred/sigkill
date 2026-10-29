// SIGKILL daemon armour (A5): the solid body of every daemon. Tron Legacy, not glowing wire: closed
// near-black gunmetal plates, carapace, limbs, blades and drone pucks with real mass, lit by the
// arena (its sun, its lamps) on their facets and bevels; a faint cool catch-light on their true
// edges, as a machined bevel would take it, never a line of the type's colour; a rim of the type's
// own colour (edge_color) only where a plate turns away, so a dark body still reads against a dark
// room. The type's light lives in its seams and weak points (the core look, daemon_core.gdshader),
// never on the armour. A grep lock sweeps a cobalt band down it; a hit flares it amber.
//
// Every part is one instance of a daemon's MultiMesh, posed each frame by its transform alone; its
// custom data: x its salt, y its tone (each plate a shade lighter or darker than the next), z its
// presence (1 whole, 0 gone: between, it breaks up cell by cell as it derezzes or re-forms), w how
// scorched it is (battle damage: darker, matte, its rim dulled). The glitch
// (shaders/daemon_glitch.gdshaderinc) moves its vertices, calmer at rest than the obsidian's (the
// palette's armour shares), tearing as hard on a hit or a respawn.
//
// One material for every daemon of every type: what differs per daemon comes in instance uniforms
// pinned to the shared slots, and the time is the shared shader global, so no daemon ever compiles a
// shader of its own and nothing is sent per daemon per frame. Defaults only mirror
// scripts/palette.gd, which sets every value at runtime and is the single source.
shader_type spatial;
render_mode world_vertex_coords;

#include "res://shaders/daemon_glitch.gdshaderinc"

uniform vec4 armor : source_color = vec4(0.051, 0.059, 0.075, 1.0);
uniform float metallic_amount : hint_range(0.0, 1.0) = 0.55;
uniform float roughness_amount : hint_range(0.0, 1.0) = 0.32;
uniform float tint : hint_range(0.0, 1.0) = 0.35;
uniform vec4 bevel_color : source_color = vec4(0.62, 0.74, 0.8, 1.0);
uniform float bevel_energy : hint_range(0.0, 4.0) = 0.22;
uniform float edge_px : hint_range(0.0, 8.0) = 1.4;
uniform float rim_energy : hint_range(0.0, 8.0) = 0.7;
uniform float rim_power : hint_range(0.5, 8.0) = 3.5;
uniform float scorch_dark : hint_range(0.0, 1.0) = 0.7;
uniform vec4 flash_color : source_color = vec4(1.0, 0.69, 0.0, 1.0);
uniform float flash_energy : hint_range(0.0, 32.0) = 6.0;
uniform vec4 lock_color : source_color = vec4(0.302, 0.49, 1.0, 1.0);
uniform float lock_energy : hint_range(0.0, 16.0) = 3.0;
uniform float cells_per_m : hint_range(1.0, 100.0) = 28.0;

instance uniform vec4 edge_color : source_color, instance_index(6) = vec4(1.0, 0.2, 0.333, 1.0);

varying vec3 world_pos;
varying vec3 bary;
varying vec4 part;

void vertex() {
	part = INSTANCE_CUSTOM;
	float g;
	VERTEX += glitch_offset(VERTEX, part, INV_VIEW_MATRIX[0].xyz, g);
	world_pos = VERTEX;
	bary = CUSTOM0.rgb;
}

void fragment() {
	float t = daemon_time();
	// The true edges, about edge_px wide on screen at any distance: a faint machined catch-light.
	vec3 fw = max(fwidth(bary), vec3(0.00001));
	vec3 near = smoothstep(fw * (edge_px - 0.5), fw * (edge_px + 0.5), bary);
	float line = 1.0 - min(min(near.x, near.y), near.z);
	// Presence: below 1 the plate breaks up in world-space cells, as the obsidian does.
	ivec3 cell = ivec3(floor(world_pos * cells_per_m));
	float roll = hash2(cell.x * 7 + cell.y * 131 + int(part.x * 997.0), cell.z * 3 + int(seed * 997.0));
	if (roll > part.z * 1.1) {
		discard;
	}
	float scorch = clamp(part.w, 0.0, 1.0);
	float tone = 1.0 + tint * (part.y - 0.5) * 2.0;
	ALBEDO = armor.rgb * tone * (1.0 - scorch_dark * scorch);
	METALLIC = metallic_amount * (1.0 - 0.6 * scorch);
	ROUGHNESS = mix(roughness_amount, 0.85, scorch);
	SPECULAR = 0.6;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	vec3 glow = edge_color.rgb * rim_energy * rim * (1.0 - 0.7 * scorch) + bevel_color.rgb * bevel_energy * line * (1.0 - scorch);
	glow = mix(glow, flash_color.rgb * flash_energy * (0.3 + rim + 0.5 * line), hit);
	// A grep lock: a cobalt band sweeping down the armour once a second.
	float sweep = 1.0 - smoothstep(0.0, 0.12, abs(fract(world_pos.y * 0.5 + t) - 0.5));
	glow += lock_color.rgb * lock_energy * locked * (0.25 * rim + sweep + line);
	EMISSION = glow;
}
