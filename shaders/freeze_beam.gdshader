// SIGKILL chmod 000's beam (C29): a cold beam of light from the emitter to what it strips. Drawn on a
// unit cylinder along Y that scripts/weapons/freeze_beam.gd stretches from the muzzle to the end each
// frame: `length_m` is how long it is now, so its bands keep their size whatever its length. Two layers
// share this shader: a thin hot core (`core` 1) near white, and a wider sheath in the frost opal whose
// light runs in bands toward the target and twists round the beam, thinner at its edges (it fades where
// the cylinder turns away). Additive and unshaded: it only adds light. `strength` fades it in and out.
// Defaults only mirror scripts/palette.gd, which sets every value at runtime.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;

uniform vec4 color : source_color = vec4(0.659, 0.471, 0.518, 1.0);
uniform vec4 hot : source_color = vec4(0.961, 0.816, 0.839, 1.0);
uniform float core = 0.0;
uniform float energy : hint_range(0.0, 32.0) = 3.0;
uniform float band_m : hint_range(0.05, 4.0) = 0.45;
uniform float band_speed : hint_range(0.0, 40.0) = 9.0;
uniform float twist : hint_range(0.0, 20.0) = 3.0;

instance uniform float strength : instance_index(0) = 1.0;
instance uniform float length_m : instance_index(1) = 1.0;

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float along = UV.y * length_m;
	float edge = pow(facing, mix(1.6, 0.6, core));
	if (core > 0.5) {
		ALBEDO = hot.rgb * energy * edge * strength;
	} else {
		float band = fract(along / band_m - TIME * band_speed / band_m * 0.1 + UV.x * twist);
		float rune = smoothstep(0.0, 0.25, band) * (1.0 - smoothstep(0.45, 0.7, band));
		float flick = 0.75 + 0.25 * sin(TIME * 31.0 + along * 7.0);
		vec3 light = color.rgb * (0.35 + 0.9 * rune) + hot.rgb * rune * 0.35;
		ALBEDO = light * energy * edge * flick * strength;
	}
}
