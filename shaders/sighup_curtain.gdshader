// SIGHUP's curtain of static (C32): an open cylinder standing on the carrier wave's front, as tall as a
// daemon, running out with it. Brightest at its foot and thinning upward; interference bars climbing it,
// warped round it; the carrier's own trace, a sine running round it low; whole slices of it dropping out
// for a tick and coming back; its edge-on sides brighter, so it reads as a ring of light from anywhere.
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
	float rise = pow(1.0 - h, 2.0);
	// Interference bars climbing it, warped round it.
	float bars = smoothstep(0.55, 1.0, fract(h * 9.0 - age * 5.0 + 0.25 * sin(a * 7.0 + age * 9.0)));
	// The carrier's trace, low round it.
	float y = 0.16 + 0.05 * sin(a * 18.0 + age * 24.0);
	float trace = exp(-pow((h - y) / 0.018, 2.0));
	// Slices dropping out for a tick.
	float drop = step(0.22, hash(vec2(floor(a * 14.0 + 14.0), floor(age * 12.0))));
	// Edge-on, brighter: the ring reads from anywhere.
	float rim = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	float light = (bars * 0.3 * rise + trace * 1.6 + rim * rim * rise * 0.7 + rise * 0.06) * drop;
	vec3 c = mix(body_color.rgb, hot_color.rgb, clamp(trace, 0.0, 1.0));
	ALBEDO = c * light * energy * fade;
}
