shader_type spatial;
// Light on the pit's floor in the opener (C41, scripts/opener/pit_beat.gd), added to what is under it. Mode 0, the
// link's lock: rings of the AI's light running out across the floor from the pit's rim as the answer lands, past the
// player and away. Mode 1, the copy's steps: a hexagon of its red under each foot as it lands, a stair of them up out
// of the pit and prints across the floor, each bright edged with a faint cell grid inside, flaring as the foot comes
// down.
//
// Mode 0 is one flat square centred on the pit's axis; its own x and z are metres from the axis. Mode 1 is a MultiMesh
// of flat hexagons a unit across their corners; INSTANCE_CUSTOM r how bright, g the landing's flare.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, specular_disabled;

uniform float mode = 0.0;
uniform vec3 ring_color : source_color = vec3(0.098, 0.827, 0.773);
uniform vec3 step_color : source_color = vec3(1.0, 0.071, 0.188);
uniform vec3 hot_color : source_color = vec3(1.0, 0.82, 0.8);
// Mode 0: seconds since the lock (below 0, nothing), the pit's radius, how fast the rings run and how wide they are.
uniform float since = -1.0;
uniform float pit_r = 30.0;
uniform float ring_speed = 22.0;
uniform float ring_m = 1.2;

varying vec2 local;
varying flat vec4 custom;

void vertex() {
	local = VERTEX.xz;
	custom = INSTANCE_CUSTOM;
}

// How far in from a flat-sided hexagon's edge (corners on +-x, a unit across them): 0 at the edge, 1 at the middle.
float hex_in(vec2 p) {
	vec2 q = abs(p);
	float d = max(q.x * 0.866025 + q.y * 0.5, q.y);
	return 1.0 - d / 0.433013;
}

void fragment() {
	vec3 rgb = vec3(0.0);
	if (mode < 0.5) {
		if (since >= 0.0) {
			float r = length(local);
			float out_of_pit = smoothstep(pit_r, pit_r + 1.0, r);
			for (int k = 0; k < 2; k++) {
				float t = since - float(k) * 0.28;
				if (t < 0.0) {
					continue;
				}
				float at = pit_r + t * ring_speed;
				float band = exp(-pow((r - at) / ring_m, 2.0));
				float trail = r < at ? exp(-(at - r) / 4.0) * 0.1 : 0.0;
				// Fainter the farther it has run from the rim, so it washes past the player as a wave, never a flood.
				float far = exp(-max(at - pit_r, 0.0) / 9.0);
				rgb += ring_color * (band * 1.5 + trail) * exp(-t * 1.5) * far * (k == 0 ? 1.0 : 0.55);
			}
			rgb *= out_of_pit;
		}
	} else {
		float inside = hex_in(local);
		if (inside > 0.0) {
			float edge = exp(-inside * 14.0) * 2.2;
			float rim = smoothstep(0.0, 0.05, inside) * exp(-inside * 4.0) * 0.6;
			vec2 cell = fract(local * 7.0) - 0.5;
			float grid = step(0.42, max(abs(cell.x), abs(cell.y))) * 0.12;
			float glow = custom.r;
			rgb = step_color * (edge + rim + grid + 0.05) * glow + hot_color * exp(-inside * 9.0) * custom.g * 1.5;
		}
	}
	ALBEDO = rgb;
}
