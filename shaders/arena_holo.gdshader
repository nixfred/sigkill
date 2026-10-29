// SIGKILL arena holograms (A3): the floating ">_" glyphs over the pylons, one MultiMesh for all of
// them, so they are one draw call. Each glyph turns slowly about its own upright and bobs, on its own
// phase (INSTANCE_CUSTOM.r, 0 to 1), all in the vertex stage, so nothing on the CPU touches them once
// they are placed. Unshaded and over-bright for the glow pass, with dim bands sliding up it like a
// projection. Every motion is arena_clock wrapped at 1024, so nothing in it grows with time.
// Defaults only mirror scripts/palette.gd so the material previews in the editor; palette.gd sets
// every value at runtime and is the single source.
// Its time is the arena's clock (A4), the shader global arena_clock stepped at the game's pace by
// scripts/arena/arena_art.gd, so SIGSTOP slows the glyphs with everything else.
shader_type spatial;
render_mode unshaded;

global uniform float arena_clock;
// Black ICE (I3) dims it: arena_light, the arena's light level (1 normal, its lights_low while it is out),
// a shader global set by scripts/ice/blackout.gd.
global uniform float arena_light;

uniform vec4 holo_color : source_color = vec4(0.49, 1.0, 0.812, 1.0);
uniform float energy : hint_range(0.0, 32.0) = 3.5;
uniform float turn_hz : hint_range(0.0, 2.0) = 0.06;
uniform float bob_m : hint_range(0.0, 2.0) = 0.12;
uniform float bob_hz : hint_range(0.0, 4.0) = 0.25;
uniform float bands_per_m : hint_range(0.0, 40.0) = 9.0;
uniform float band_speed : hint_range(0.0, 8.0) = 0.6;

varying float local_y;

void vertex() {
	float phase = INSTANCE_CUSTOM.r;
	float t = mod(arena_clock, 1024.0);
	float a = (t * turn_hz + phase) * TAU;
	float c = cos(a);
	float s = sin(a);
	VERTEX = vec3(c * VERTEX.x + s * VERTEX.z, VERTEX.y, -s * VERTEX.x + c * VERTEX.z);
	VERTEX.y += bob_m * sin((t * bob_hz + phase) * TAU);
	local_y = VERTEX.y;
}

void fragment() {
	float band = 0.75 + 0.25 * sin((local_y * bands_per_m - mod(arena_clock, 1024.0) * band_speed) * TAU);
	ALBEDO = holo_color.rgb * (energy * band) * arena_light;
}
