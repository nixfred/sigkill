// SIGKILL daemon shell (A2, redone in A2b): the obsidian of every daemon's parts: a rogue daemon's
// crystal legs and segments, a zombie's wireframe bones and its ghosts, a swarm's insects. Black
// glass: glossy, nearly no colour of its own, catching the arena's light on its facets; its true
// edges drawn as lines in the daemon's edge colour (the shape kit's edged buckets carry each
// vertex's place in its triangle in CUSTOM0, the triangulation's own inner edges out of reach), a
// faint rim where it turns away, and thin scanlines climbing it. A grep lock sweeps a cobalt band
// down it; a hit flares it. Faceless: no feature is drawn, only light on facets and lines.
//
// Every part is one instance of a daemon's MultiMesh, posed each frame by its transform alone; its
// custom data says how it is drawn: x its salt; y wire (1: its edges alone, a wireframe); z its
// presence (1 whole, 0 gone: between, it breaks up cell by cell, edges last, as it derezzes or
// re-forms); w a ghost copy (0 none, else the ghost's place in the trail, drawn as split-coloured
// wire, fainter the further back). The glitch (shaders/daemon_glitch.gdshaderinc) moves its
// vertices: jumping bands, scanline tears and snapping parts; a jumping band's scanlines also
// split into the edge colour and the split colour, and the split pass (daemon_split.gdshader)
// draws its edges again offset on screen.
//
// One material for every daemon of every type: what differs per daemon comes in instance uniforms
// pinned to fixed slots, and the time is the shared shader global, so no daemon ever compiles a
// shader of its own and nothing is sent per daemon per frame. Defaults only mirror
// scripts/palette.gd, which sets every value at runtime and is the single source.
shader_type spatial;
render_mode world_vertex_coords;

#include "res://shaders/daemon_glitch.gdshaderinc"

uniform vec4 obsidian : source_color = vec4(0.012, 0.016, 0.02, 1.0);
uniform vec4 flash_color : source_color = vec4(1.0, 0.69, 0.0, 1.0);
uniform vec4 lock_color : source_color = vec4(0.302, 0.49, 1.0, 1.0);
uniform vec4 split_color : source_color = vec4(0.302, 0.882, 1.0, 1.0);
uniform float edge_energy : hint_range(0.0, 16.0) = 3.0;
uniform float edge_px : hint_range(0.0, 8.0) = 1.4;
uniform float wire_px : hint_range(0.0, 8.0) = 1.8;
uniform float wire_energy : hint_range(0.0, 16.0) = 2.8;
uniform float ghost_energy : hint_range(0.0, 16.0) = 1.8;
uniform float rim_energy : hint_range(0.0, 16.0) = 0.6;
uniform float rim_power : hint_range(0.5, 8.0) = 5.0;
uniform float scan_energy : hint_range(0.0, 16.0) = 0.35;
uniform float scan_per_m : hint_range(1.0, 200.0) = 12.0;
uniform float scan_width : hint_range(0.01, 0.5) = 0.05;
uniform float scan_speed : hint_range(0.0, 4.0) = 0.35;
uniform float flash_energy : hint_range(0.0, 32.0) = 6.0;
uniform float lock_energy : hint_range(0.0, 16.0) = 3.0;
uniform float split_m : hint_range(0.0, 0.1) = 0.02;
uniform float cells_per_m : hint_range(1.0, 100.0) = 28.0;

instance uniform vec4 edge_color : source_color, instance_index(6) = vec4(1.0, 0.2, 0.333, 1.0);

varying vec3 world_pos;
varying vec3 bary;
varying float glitching;
varying vec4 part;

// Coverage of thin scanlines at height y (metres), anti-aliased.
float scan(float y) {
	float d = abs(fract(y * scan_per_m) - 0.5) * 2.0; // 0 on a line, 1 halfway to the next
	float fw = max(fwidth(y * scan_per_m) * 2.0, 0.0001);
	return 1.0 - smoothstep(scan_width, scan_width + fw, d);
}

void vertex() {
	part = INSTANCE_CUSTOM;
	float g;
	VERTEX += glitch_offset(VERTEX, part, INV_VIEW_MATRIX[0].xyz, g);
	glitching = g;
	world_pos = VERTEX;
	bary = CUSTOM0.rgb;
}

void fragment() {
	float t = daemon_time();
	float strength = glitch_strength();
	float ghost = part.w;
	float wire = max(part.y, step(0.01, ghost));
	// The true edges, about edge_px wide on screen at any distance (wider for a wire part).
	float px = mix(edge_px, wire_px, wire);
	vec3 fw = max(fwidth(bary), vec3(0.00001));
	vec3 near = smoothstep(fw * (px - 0.5), fw * (px + 0.5), bary);
	float line = 1.0 - min(min(near.x, near.y), near.z);
	// Presence: below 1 the part breaks up in world-space cells, its faces first, its edges last.
	ivec3 cell = ivec3(floor(world_pos * cells_per_m));
	float roll = hash2(cell.x * 7 + cell.y * 131 + int(part.x * 997.0), cell.z * 3 + int(seed * 997.0));
	if (roll > part.z * (1.0 + 0.8 * line) * 1.1) {
		discard;
	}
	// A wire part, or a ghost, is its edges alone.
	if (wire > 0.5 && line < 0.04) {
		discard;
	}
	ALBEDO = obsidian.rgb;
	METALLIC = 0.3;
	ROUGHNESS = 0.08;
	SPECULAR = 0.9;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	float y = world_pos.y - t * scan_speed;
	float split = split_m * glitching * (1.0 + 3.0 * strength);
	float lines = scan(y);
	vec3 edge_rgb = edge_color.rgb;
	float energy = mix(edge_energy, wire_energy, part.y);
	if (ghost > 0.01) {
		// Ghosts alternate the split colour and the edge colour down the trail, fainter further back.
		int k = int(round(ghost * 4.0));
		edge_rgb = (k % 2 == 1) ? split_color.rgb : edge_color.rgb;
		energy = ghost_energy * (1.15 - ghost);
	}
	// The glitch's split: the scanline drawn a little above in the edge colour and a little below
	// in the split colour.
	vec3 scan_rgb = edge_rgb * lines + glitching * (edge_rgb * scan(y + split) + split_color.rgb * scan(y - split)) * 0.5;
	vec3 glow = edge_rgb * (energy * line + rim_energy * rim * (1.0 - wire)) + scan_rgb * scan_energy * (1.0 - wire);
	glow = mix(glow, flash_color.rgb * flash_energy * (0.4 + rim + line), hit);
	// A grep lock: a cobalt band sweeping down the shell once a second.
	float sweep = 1.0 - smoothstep(0.0, 0.12, abs(fract(world_pos.y * 0.5 + t) - 0.5));
	glow += lock_color.rgb * lock_energy * locked * (0.25 * rim + sweep + line);
	EMISSION = glow;
}
