// /dev/null's mark on the floor under its hole (C31): its reach drawn as a ring of dashes flowing inward
// (the pull's edge, so a player sees where it starts), the horizon a brighter ring (where it starts to
// hurt), and between them a faint wash darkening toward the core. The plane's UV spans the reach.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 body_color : source_color = vec4(0.67, 0.22, 0.61, 1.0);
uniform vec4 hot_color : source_color = vec4(1.0, 0.85, 0.96, 1.0);
// The horizon's radius as a share of the reach.
uniform float horizon = 0.33;
uniform float size_now = 1.0;
uniform float flow = 0.0;
uniform float energy = 1.6;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	float angle = atan(p.y, p.x);
	// The reach: dashes round the ring, drifting round as the hole turns.
	float dash = step(0.5, fract(angle * 36.0 / 6.2831853 + flow * 0.25));
	float edge = exp(-pow((r - 0.985) / 0.008, 2.0)) * mix(0.25, 1.0, dash);
	// Chevrons flowing inward between the reach and the horizon.
	float chevrons = smoothstep(0.82, 1.0, fract(r * 9.0 + flow * 1.4)) * smoothstep(horizon, horizon + 0.1, r) * (1.0 - smoothstep(0.85, 0.98, r));
	float ring = exp(-pow((r - horizon) / 0.012, 2.0));
	vec3 color = body_color.rgb * (edge * 1.2 + chevrons * 0.35) + hot_color.rgb * ring * 0.9;
	ALBEDO = color * energy * size_now;
}
