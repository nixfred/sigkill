// SIGKILL ruins lights (C36): every light set into the ruins, unshaded and bright enough to bloom, in the register's
// colours. The vertex colour carries each light's own data (scripts/ruins/ruins_pieces.gd paints it):
//   r  its phase, 0 to 1: where it is in its blink, its flicker's dice, a screen line's place in its typing
//   g  its health: 1 steady, under DYING it stutters, under DEAD it is all but out
//   b  its slot, in eighths: 0 a status LED, 1 a strip, 2 a sign's first colour, 3 its second, 4 a beacon, 5 a screen's
//      text, 6 a white-hot spark, 7 the void's glow far below
//   a  its energy, an eighth of ENERGY_MOST a step
// Every slot has a colour per register (tron, cyberpunk, matrix), blended by ruins_common's weights. Corruption kills
// the status lights, strips and screens: a register's decay is the share of them it puts out (none in tron), each light
// by a frailty of its own from its phase, those just past the line stuttering; so a shift to the ruins puts most of
// them out and a shift back lights them again. Signs and beacons stay lit, the dead megacorps' lights on a timer
// nobody owns. A register shift tears it in bands. Colour defaults mirror scripts/ruins/ruins_register.gd.
shader_type spatial;
render_mode unshaded, cull_disabled;

#include "res://shaders/ruins_common.gdshaderinc"

const float ENERGY_MOST = 10.0;
const float DYING = 0.85;
const float DEAD = 0.25;

uniform vec4 tron_slots[8];
uniform vec4 cyber_slots[8];
uniform vec4 matrix_slots[8];
// The share of the lights that die (status, strip, screen) each register puts out: tron, cyberpunk, matrix.
uniform vec3 decay = vec3(0.0, 0.62, 0.4);
// How bright each register's lights are, on the whole.
uniform vec3 register_energy = vec3(1.0, 1.0, 0.9);
// The whole surface's power (C37): 1 lit; a breach's remnant sign has a material of its own, dark until a mission
// lights it.
uniform float power = 1.0;

varying vec3 world_pos;
varying vec4 paint;

void vertex() {
	paint = COLOR;
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float tear = ruins_tear_band(w);
	if (tear > 0.0) {
		VERTEX += (inverse(MODEL_MATRIX) * vec4(sin(w.y * 13.0 + arena_clock * 50.0) * 0.18 * tear, 0.0, 0.0, 0.0)).xyz;
	}
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 w3 = ruins_weights(world_pos);
	int slot = clamp(int(round(paint.b * 8.0)), 0, 7);
	float phase = paint.r;
	float health = paint.g;
	float energy = paint.a * ENERGY_MOST;
	bool dies = slot == 0 || slot == 1 || slot == 5;
	if (dies) {
		float d = dot(decay, w3);
		float frail = fract(phase * 91.7 + 0.37);
		if (frail < d) {
			health = min(health, 0.1 + 0.7 * smoothstep(d - 0.1, d, frail));
		}
	}
	int salt = int(phase * 4093.0);
	float t = arena_clock;
	float on = 1.0;
	if (health < DEAD) {
		// All but out: a dull ember, now and then a flash as it tries to come back.
		on = 0.04 + 0.9 * step(0.996, ruins_hash(int(floor(t * 9.0)), salt, 11));
	} else if (health < DYING) {
		// Stuttering: the worse its health, the more often it drops.
		float drop = mix(0.65, 0.08, (health - DEAD) / (DYING - DEAD));
		on = step(drop, ruins_hash(int(floor(t * 14.0 + phase * 7.0)), salt, 12)) * (0.6 + 0.4 * ruins_hash(int(floor(t * 30.0)), salt, 13));
	} else if (slot == 0) {
		// A status LED: a slow steady blink of its own, or lit.
		float rate = 0.4 + 2.2 * fract(phase * 13.7);
		on = phase < 0.5 ? 1.0 : (0.35 + 0.65 * step(0.35, fract(t * rate + phase * 5.0)));
	} else if (slot == 4) {
		// A beacon: a slow pulse.
		on = 0.25 + 0.75 * pow(0.5 + 0.5 * sin(t * 2.1 + phase * TAU), 4.0);
	} else if (slot == 5) {
		// A screen's line: typed out, held, cleared, in its turn.
		float cycle = fract(t * 0.18 + phase);
		on = step(fract(phase * 9.0), cycle * 1.6) * (0.75 + 0.25 * step(0.5, fract(t * 7.0 + phase * 3.0)));
	} else if (slot == 7) {
		on = 0.7 + 0.3 * sin(t * 0.7 + world_pos.x * 0.05);
	}
	vec3 col = tron_slots[slot].rgb * w3.x + cyber_slots[slot].rgb * w3.y + matrix_slots[slot].rgb * w3.z;
	// A share of the status lights, strips and screens take the register's second colour: warm against cold.
	if (dies && fract(phase * 37.3 + 0.11) < 0.35) {
		col = tron_slots[3].rgb * w3.x + cyber_slots[3].rgb * w3.y + matrix_slots[3].rgb * w3.z;
	}
	float reg = dot(register_energy, w3);
	float tear = ruins_tear_band(world_pos);
	on = mix(on, step(0.5, fract(world_pos.x * 2.0 + t * 30.0)), tear * 0.6);
	ALBEDO = col * (energy * on * reg) * arena_light * power;
}
