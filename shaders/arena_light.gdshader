// SIGKILL arena light (A3): the arena's light strips, sign letters, conduit flow and beacons. Unshaded
// and over-bright, so the glow pass blooms it; one material per colour and behaviour, shared by every
// strip of it. A slow wave of brightness travels through every strip along the world's diagonal, so
// the arena breathes; with a high pulse and short waves it reads as packets of data flowing down a
// conduit. A beacon blinks instead, each one on its own phase, picked by a hash of where it is.
// Nothing here grows with time: the blink's tick wraps at 1024.
// Defaults only mirror scripts/palette.gd so the material previews in the editor; palette.gd sets
// every value at runtime and is the single source.
// Its time is the arena's clock (A4), the shader global arena_clock stepped at the game's pace by
// scripts/arena/arena_art.gd, so SIGSTOP slows the waves and the blinks with everything else.
shader_type spatial;
render_mode unshaded;

global uniform float arena_clock;
// Black ICE (I3) dims it: arena_light, the arena's light level (1 normal, its lights_low while it is out),
// a shader global set by scripts/ice/blackout.gd.
global uniform float arena_light;

uniform vec4 light_color : source_color = vec4(0.098, 0.827, 0.773, 1.0);
uniform float energy : hint_range(0.0, 32.0) = 2.2;
uniform float pulse : hint_range(0.0, 1.0) = 0.2;
uniform float waves_per_m : hint_range(0.0, 10.0) = 0.12;
uniform float wave_speed : hint_range(0.0, 10.0) = 0.25;
uniform float blink : hint_range(0.0, 1.0) = 0.0;
uniform float blink_hz : hint_range(0.0, 10.0) = 0.6;
uniform float blink_on : hint_range(0.0, 1.0) = 0.35;
uniform float blink_cell_m : hint_range(0.5, 50.0) = 6.0;

varying vec3 world_pos;

uint pcg(uint v) {
	uint state = v * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float along = world_pos.x + world_pos.z + 0.5 * world_pos.y;
	float wave = sin((along * waves_per_m - arena_clock * wave_speed) * TAU);
	float e = energy * (1.0 + pulse * wave);
	if (blink > 0.0) {
		ivec3 cell = ivec3(floor(world_pos / blink_cell_m));
		float phase = float(pcg(uint(cell.x & 0x3ff) | (uint(cell.y & 0x3ff) << 10u) | (uint(cell.z & 0x3ff) << 20u)) & 0xffffu) / 65535.0;
		float t = fract(mod(arena_clock * blink_hz, 1024.0) + phase);
		e *= mix(1.0, step(t, blink_on), blink);
	}
	ALBEDO = light_color.rgb * e * arena_light;
}
