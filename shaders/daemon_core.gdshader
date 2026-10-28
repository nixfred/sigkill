// SIGKILL daemon core (A2): the glowing heart inside every daemon, and the hot tails of a swarm's
// drones. Unshaded and over-bright so the glow pass blooms it: the type's own colour from the
// palette (hostile red for a rogue daemon and a swarm, hostile amber for a zombie), breathing
// slowly, guttering for a zombie, flaring white-hot on a hit. Faceless: a gem of light, no feature.
//
// One material for every daemon: the colour, the breath, the gutter and the flash are instance
// uniforms, so no daemon compiles a shader of its own. The gutter is an integer hash (PCG) of a
// tick wrapped at 1024. Defaults only mirror scripts/palette.gd, which sets every value at runtime.
shader_type spatial;
render_mode unshaded;

uniform float energy : hint_range(0.0, 32.0) = 4.0;
uniform float breath : hint_range(0.0, 1.0) = 0.18;
uniform float breath_hz : hint_range(0.0, 8.0) = 0.6;
uniform float flash_energy : hint_range(0.0, 32.0) = 10.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);

instance uniform vec4 core_color : source_color = vec4(1.0, 0.2, 0.333, 1.0);
instance uniform float clock = 0.0;
instance uniform float hit = 0.0;
instance uniform float gutter = 0.0;
instance uniform float seed = 0.0;

uint pcg(uint v) {
	uint state = v * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}

void fragment() {
	float wave = 1.0 + breath * sin(6.2831853 * breath_hz * clock + seed * 6.2831853);
	int tick = int(mod(floor(clock * 12.0), 1024.0));
	float roll = float(pcg(uint(tick) * 7919u + uint(int(seed * 997.0) & 0xffff)) & 0xffffu) / 65535.0;
	float dim = mix(1.0, 0.15 + 0.85 * step(0.35, roll), gutter); // a zombie's core drops out now and then
	vec3 col = core_color.rgb * energy * wave * dim;
	ALBEDO = mix(col, flash_color.rgb * flash_energy, hit);
}
