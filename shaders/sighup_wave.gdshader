// SIGHUP's carrier wave on the floor (C32): the line's carrier running out from the burst. Its front a
// thin bright trace, an oscilloscope's sine wrapped round the ring and running round it; behind it the
// interference, three ghosts of the front trailing in, each its own wobble, broken into dashes that drop
// out and come back; the floor it has swept speckled with static that fades behind the front; now and
// then a sector of all of it torn out for a tick, the line dropping. Additive: light, nothing solid. The
// plane is centred on the burst and half_m across each way; front, age and fade are the burst's.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 body_color : source_color = vec4(0.0, 0.749, 0.0, 1.0);
uniform vec4 hot_color : source_color = vec4(0.8, 1.0, 0.761, 1.0);
uniform float half_m = 7.7;
uniform float reach = 7.0;
// How far the front has run, metres; seconds since the burst; 1 while it runs, easing to 0 after.
uniform float front = 0.0;
uniform float age = 0.0;
uniform float fade = 1.0;
uniform float energy = 2.4;
// The trace: its sine's cycles round the ring and its height, metres.
uniform float cycles = 26.0;
uniform float wobble_m = 0.1;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// An integer hash of a cell, 0 to 1: the static's (a sin hash of a large cell index breaks down on the GPU and
// lit half the floor in the first stills).
float cell_hash(ivec2 c) {
	uint h = (uint(c.x) * 1597334677u) ^ (uint(c.y) * 3812015801u);
	h = (h ^ (h >> 16u)) * 2246822519u;
	h ^= h >> 13u;
	return float(h & 0xffffu) / 65535.0;
}

// exp(-(x / w)^2): a soft line `w` wide. Squared by hand: pow() of a negative number is undefined in GLSL
// (by the spec; whatever a driver makes of it).
float gauss(float x, float w) {
	float u = x / w;
	return exp(-u * u);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0 * half_m;
	float r = length(p);
	if (r > reach + 0.4 || r > front + 0.6) {
		discard;
	}
	float a = atan(p.y, p.x);
	// The front: a sine trace running round the ring.
	float wob = wobble_m * sin(a * cycles + age * 30.0) + wobble_m * 0.5 * sin(a * cycles * 2.3 - age * 47.0);
	float d = r - (front + wob);
	float trace = gauss(d, 0.045);
	float halo = gauss(d, 0.12) * 0.25;  // thin: a wide one, seen from just outside the ring, read as a plate
	// Interference: ghosts of the front trailing in, in dashes that drop out.
	float ghosts = 0.0;
	for (int k = 1; k <= 3; k++) {
		float fk = float(k);
		float lag = fk * (0.5 + 0.18 * fk);
		float gd = r - (front - lag + 0.07 * sin(a * (12.0 + 7.0 * fk) - age * (18.0 + 6.0 * fk)));
		float dash = step(0.38, vnoise(vec2(a * 8.0 * fk + fk * 11.0, age * 7.0 + fk * 3.1)));
		ghosts += gauss(gd, 0.03) * dash * (0.75 / fk) * step(lag, front);
	}
	// Static over the swept floor, fine and sparse, thinning behind the front.
	ivec2 cell = ivec2(floor(p * 24.0)) + ivec2(int(floor(age * 24.0)) * 7, int(floor(age * 24.0)) * 13);
	float grain = step(0.965, cell_hash(cell));
	float swept = step(r, front) * (1.0 - smoothstep(0.0, 3.0, front - r));
	// A stretch of the trace torn out now and then: the line dropping (the trace alone, never the floor).
	float tear = step(0.9, hash(vec2(floor(a * 9.0 + 9.0), floor(age * 13.0))));
	float light = (trace * 1.5 + halo + ghosts) * (1.0 - 0.8 * tear) + grain * swept * 0.35;
	vec3 c = mix(body_color.rgb, hot_color.rgb, clamp(trace * 0.85, 0.0, 1.0));
	ALBEDO = c * light * energy * fade;
}
