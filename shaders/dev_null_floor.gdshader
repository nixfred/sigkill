// /dev/null's mark on the floor under its hole (C31): the floor sinking into a well, darkening toward the
// core as light falls in; its reach a thin ring of plum dashes drifting round (the pull's edge, so a player
// sees where it starts); faint dashes flowing inward across the well; the horizon a faint line where the
// damage starts. The plane's UV spans the reach.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 body_color : source_color = vec4(0.67, 0.22, 0.61, 1.0);
uniform vec4 hot_color : source_color = vec4(1.0, 0.85, 0.96, 1.0);
// The horizon's radius as a share of the reach.
uniform float horizon = 0.33;
uniform float size_now = 1.0;
uniform float flow = 0.0;
uniform float energy = 1.1;
// How dark the well is at its middle.
uniform float well = 0.7;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	float angle = atan(p.y, p.x);
	// The well: darker toward the middle, nothing at the reach.
	float dark = well * pow(1.0 - smoothstep(0.0, 0.85, r), 1.6);
	// The reach: thin dashes round the ring, drifting round as the hole turns.
	float dash = step(0.55, fract(angle * 48.0 / 6.2831853 + flow * 0.35));
	float edge = exp(-pow((r - 0.988) / 0.0035, 2.0)) * dash * 0.8;
	// Faint dashes flowing in across the well, on spokes.
	float spoke = step(0.92, fract(angle * 24.0 / 6.2831853));
	float flowing = spoke * smoothstep(0.7, 1.0, fract(r * 6.0 + flow * 1.2)) * smoothstep(horizon, horizon + 0.15, r) * (1.0 - smoothstep(0.8, 0.95, r));
	float line = exp(-pow((r - horizon) / 0.005, 2.0)) * 0.35;
	float light = edge + flowing * 0.4 + line;
	vec3 color = mix(body_color.rgb, hot_color.rgb, line) * energy;
	ALBEDO = color * light / max(light + dark, 0.0001);
	ALPHA = clamp(dark + light, 0.0, 1.0) * size_now;
}
