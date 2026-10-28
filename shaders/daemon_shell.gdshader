// SIGKILL daemon shell (A2): the obsidian of every daemon's shards, blades, chunks and drones.
// Black glass: glossy, nearly no colour of its own, catching the arena's light on its facets; its
// true edges drawn as thin lines of hostile red (the shape kit's edged buckets carry each vertex's
// place in its triangle in CUSTOM0, the triangulation's own inner edges out of reach), a faint rim
// where it turns away, and thin red scanlines climbing it. A glitch: on a few
// ticks a second some horizontal bands of it jump sideways and their scanlines split into red and
// blue, much more often and further while it is hit or rematerialising. A grep lock sweeps a cobalt
// band down it. Faceless: no feature is drawn, only light on facets and lines.
//
// One material for every daemon of every type: what differs per daemon comes in instance uniforms
// (its own clock, which runs at the game's pace and so slows with SIGSTOP; the hit flash; the lock;
// the rematerialise glitch; a seed), so no daemon ever compiles a shader of its own. Every hash is an
// integer hash (PCG) of small integers, the tick wrapped at 1024, so nothing grows with time.
// Defaults only mirror scripts/palette.gd so the material previews in the editor; palette.gd sets
// every value at runtime and is the single source.
shader_type spatial;

uniform vec4 obsidian : source_color = vec4(0.012, 0.016, 0.02, 1.0);
uniform vec4 edge : source_color = vec4(1.0, 0.2, 0.333, 1.0);
uniform vec4 flash_color : source_color = vec4(1.0, 0.69, 0.0, 1.0);
uniform vec4 lock_color : source_color = vec4(0.302, 0.49, 1.0, 1.0);
uniform vec4 split_color : source_color = vec4(0.302, 0.882, 1.0, 1.0);
uniform float edge_energy : hint_range(0.0, 16.0) = 2.4;
uniform float edge_px : hint_range(0.0, 8.0) = 1.3;
uniform float rim_energy : hint_range(0.0, 16.0) = 0.5;
uniform float rim_power : hint_range(0.5, 8.0) = 5.0;
uniform float scan_energy : hint_range(0.0, 16.0) = 0.3;
uniform float scan_per_m : hint_range(1.0, 200.0) = 12.0;
uniform float scan_width : hint_range(0.01, 0.5) = 0.05;
uniform float scan_speed : hint_range(0.0, 4.0) = 0.35;
uniform float flash_energy : hint_range(0.0, 32.0) = 6.0;
uniform float lock_energy : hint_range(0.0, 16.0) = 3.0;
uniform float glitch_rate : hint_range(1.0, 60.0) = 9.0;
uniform float glitch_share : hint_range(0.0, 1.0) = 0.05;
uniform float glitch_bands_per_m : hint_range(1.0, 40.0) = 7.0;
uniform float jitter_m : hint_range(0.0, 0.2) = 0.018;
uniform float split_m : hint_range(0.0, 0.1) = 0.012;

instance uniform float clock = 0.0;
instance uniform float hit = 0.0;
instance uniform float locked = 0.0;
instance uniform float unstable = 0.0;
instance uniform float seed = 0.0;

varying vec3 world_pos;
varying vec3 bary;
varying float glitching;

uint pcg(uint v) {
	uint state = v * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}

// A hash of two small integers, from 0 to 1.
float hash2(int a, int b) {
	return float(pcg(uint(a & 0xffff) * 65537u + uint(b & 0xffff)) & 0xffffu) / 65535.0;
}

// Coverage of thin scanlines at height y (metres), anti-aliased.
float scan(float y) {
	float d = abs(fract(y * scan_per_m) - 0.5) * 2.0; // 0 on a line, 1 halfway to the next
	float fw = max(fwidth(y * scan_per_m) * 2.0, 0.0001);
	return 1.0 - smoothstep(scan_width, scan_width + fw, d);
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float strength = max(hit, unstable);
	int tick = int(mod(floor(clock * glitch_rate), 1024.0));
	int band = int(floor(w.y * glitch_bands_per_m)) + 512;
	int salt = int(seed * 997.0);
	float roll = hash2(tick + salt, band);
	float chance = mix(glitch_share, 0.6, strength);
	glitching = step(1.0 - chance, roll);
	float push = (hash2(tick + salt + 41, band + 77) - 0.5) * 2.0 * jitter_m * (1.0 + 5.0 * strength);
	VERTEX.x += push * glitching;
	world_pos = w;
	bary = CUSTOM0.rgb;
}

void fragment() {
	ALBEDO = obsidian.rgb;
	METALLIC = 0.3;
	ROUGHNESS = 0.08;
	SPECULAR = 0.9;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	float y = world_pos.y - clock * scan_speed;
	float split = split_m * glitching * (1.0 + 3.0 * max(hit, unstable));
	float lines = scan(y);
	// The glitch's split: the line drawn a little above in red and a little below in the split colour.
	vec3 scan_rgb = edge.rgb * lines + glitching * (edge.rgb * scan(y + split) + split_color.rgb * scan(y - split)) * 0.5;
	// The true edges, about edge_px wide on screen at any distance.
	vec3 fw = max(fwidth(bary), vec3(0.00001));
	vec3 near = smoothstep(fw * (edge_px - 0.5), fw * (edge_px + 0.5), bary);
	float line = 1.0 - min(min(near.x, near.y), near.z);
	vec3 glow = edge.rgb * (edge_energy * line + rim_energy * rim) + scan_rgb * scan_energy;
	glow = mix(glow, flash_color.rgb * flash_energy * (0.4 + rim), hit);
	// A grep lock: a cobalt band sweeping down the shell once a second.
	float sweep = 1.0 - smoothstep(0.0, 0.12, abs(fract(world_pos.y * 0.5 + clock) - 0.5));
	glow += lock_color.rgb * lock_energy * locked * (0.25 * rim + sweep);
	EMISSION = glow;
}
