// SIGKILL daemon glitch, shared part (A2b): the time, the per-daemon values and the glitch every
// daemon shader moves its vertices by. Included by daemon_shell.gdshader, daemon_split.gdshader
// and daemon_core.gdshader, which all declare render_mode world_vertex_coords, so VERTEX is in
// world space when they call glitch_offset() and the push can follow the camera's right.
//
// The time is one shader global, daemon_clock (project.godot's shader globals), which the daemons'
// code steps once a frame at the game's pace, so SIGSTOP slows every daemon's shaders; each daemon
// offsets it by its own seed, so no two glitch in step. Nothing is sent per daemon per frame.
//
// The instance uniforms are pinned to the same slots in every daemon shader (hit 0, locked 1,
// unstable 2, seed 3, core_color 4, gutter 5, edge_color 6, hup 7: SIGHUP's confusion, C32), so a part
// drawn with more than one of them (a shell and its split pass) never reads another's slot.
//
// The glitch, heavier than A2's: on a few ticks a second some horizontal bands of a daemon jump
// sideways; thin scanline bands tear across the screen; now and then a whole part snaps off its
// place for a tick. All of it far more often and further while the daemon is hit or
// rematerialising. Every hash is an integer hash (PCG) of small integers, every tick wrapped at
// 1024, so nothing grows with time. Defaults only mirror scripts/palette.gd, which sets them.

global uniform float daemon_clock;

instance uniform float hit : instance_index(0) = 0.0;
instance uniform float locked : instance_index(1) = 0.0;
instance uniform float unstable : instance_index(2) = 0.0;
instance uniform float seed : instance_index(3) = 0.0;
// SIGHUP (C32): 0 not confused, 1 reloading its config, 2 wandering confused.
instance uniform float hup : instance_index(7) = 0.0;

uniform float glitch_rate : hint_range(1.0, 60.0) = 9.0;
uniform float glitch_share : hint_range(0.0, 1.0) = 0.08;
uniform float glitch_bands_per_m : hint_range(1.0, 40.0) = 7.0;
uniform float jitter_m : hint_range(0.0, 0.3) = 0.035;
uniform float tear_rate : hint_range(1.0, 60.0) = 14.0;
uniform float tear_share : hint_range(0.0, 1.0) = 0.05;
uniform float tear_bands_per_m : hint_range(1.0, 80.0) = 24.0;
uniform float tear_m : hint_range(0.0, 0.3) = 0.06;
uniform float part_share : hint_range(0.0, 1.0) = 0.02;
uniform float part_jump_m : hint_range(0.0, 0.3) = 0.05;

uint pcg(uint v) {
	uint state = v * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}

// A hash of two small integers, from 0 to 1.
float hash2(int a, int b) {
	return float(pcg(uint(a & 0xffff) * 65537u + uint(b & 0xffff)) & 0xffffu) / 65535.0;
}

// This daemon's time: the shared clock, offset by its seed.
float daemon_time() {
	return daemon_clock + seed * 97.0;
}

// How hard the daemon glitches now: hit, or rematerialising.
float glitch_strength() {
	return max(hit, unstable);
}

// The glitch's push on a vertex at world position `w` of the part whose custom data is `part`
// (x its salt), `right` the camera's right: the jumping band, the scanline tear and the part's
// snap, as a world offset. `glitching` comes back 1 inside a jumping band.
vec3 glitch_offset(vec3 w, vec4 part, vec3 right, out float glitching) {
	float t = daemon_time();
	float strength = glitch_strength();
	int salt = int(seed * 997.0);
	int tick = int(mod(floor(t * glitch_rate), 1024.0));
	int band = int(floor(w.y * glitch_bands_per_m)) + 512;
	glitching = step(1.0 - mix(glitch_share, 0.6, strength), hash2(tick + salt, band));
	float push = (hash2(tick + salt + 41, band + 77) - 0.5) * 2.0 * jitter_m * (1.0 + 5.0 * strength);
	int tear_tick = int(mod(floor(t * tear_rate), 1024.0));
	int tear_band = int(floor(w.y * tear_bands_per_m)) + 512;
	float tearing = step(1.0 - mix(tear_share, 0.45, strength), hash2(tear_tick + salt + 17, tear_band));
	float tear = (hash2(tear_tick + salt + 5, tear_band + 3) - 0.5) * 2.0 * tear_m * (1.0 + 3.0 * strength) * tearing;
	int id = int(part.x * 4093.0);
	float snapping = step(1.0 - mix(part_share, 0.3, strength), hash2(tick + salt + 101, id));
	vec3 snap = vec3(hash2(tick + 7, id + 1), hash2(tick + 13, id + 2), hash2(tick + 19, id + 3)) - 0.5;
	return normalize(right) * (push * glitching + tear) + snap * 2.0 * part_jump_m * (1.0 + 3.0 * strength) * snapping;
}
