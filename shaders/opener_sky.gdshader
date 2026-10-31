shader_type sky;
// The dark the opener's machine stands in (C40, scripts/opener/tree_fall.gd): near black overhead and level with
// the eye, sinking into a red-violet glow below, where the pit is and the hottest process beats. The fog fades
// everything far into this (aerial perspective), so far towers sink into the same dark the sky is.
uniform vec3 zenith : source_color = vec3(0.008, 0.01, 0.02);
uniform vec3 horizon : source_color = vec3(0.02, 0.024, 0.045);
uniform vec3 abyss : source_color = vec3(0.05, 0.012, 0.03);
uniform vec3 glow : source_color = vec3(0.6, 0.12, 0.2);
uniform float pulse = 0.0;

void sky() {
	float y = EYEDIR.y;
	vec3 c = mix(horizon, zenith, smoothstep(0.0, 0.75, y));
	c = mix(c, abyss, smoothstep(-0.05, -0.8, y));
	c += glow * pow(max(-y, 0.0), 9.0) * (0.7 + 0.3 * pulse);
	COLOR = c;
}
