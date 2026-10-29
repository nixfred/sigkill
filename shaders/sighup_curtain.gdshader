// SIGHUP's curtain of static (C32): an open cylinder standing on the carrier wave's front, as tall as a
// daemon, running out with it: thin lines of interference climbing it, warped round it, bright at its foot
// and thinning to nothing by its top; the carrier's own trace, a sine running round it low; whole slices of
// it dropping out for a tick and coming back. Only lines, never a fill: seen edge-on it stays lines (a fill
// there read as two slabs of green in the first stills).
// Additive: light, nothing solid, so a player inside it sees the arena through it. Its mesh is a unit
// cylinder height_m tall, centred; the burst scales it out with the front and sets age and fade.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 body_color : source_color = vec4(0.0, 0.749, 0.0, 1.0);
uniform vec4 hot_color : source_color = vec4(0.8, 1.0, 0.761, 1.0);
uniform float height_m = 2.6;
uniform float age = 0.0;
uniform float fade = 1.0;
uniform float energy = 1.5;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

varying vec3 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	float h = clamp(local.y / height_m + 0.5, 0.0, 1.0);
	float a = atan(local.z, local.x);
	float rise = pow(1.0 - h, 2.2);
	// Thin lines of interference climbing it, warped round it.
	float bars = smoothstep(0.88, 1.0, fract(h * 14.0 - age * 6.0 + 0.25 * sin(a * 7.0 + age * 9.0)));
	// The carrier's trace, low round it.
	float y = 0.16 + 0.05 * sin(a * 18.0 + age * 24.0);
	float u = (h - y) / 0.018;
	float trace = exp(-u * u);  // squared by hand: pow() of a negative number is undefined in GLSL
	// Slices dropping out for a tick.
	float drop = step(0.22, hash(vec2(floor(a * 14.0 + 14.0), floor(age * 12.0))));
	float light = (bars * 0.7 * rise + trace * 1.6) * drop;
	vec3 c = mix(body_color.rgb, hot_color.rgb, clamp(trace, 0.0, 1.0));
	ALBEDO = c * light * energy * fade;
}
