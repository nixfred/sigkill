// SIGKILL daemon trail (A2b): the short light trails a runaway swarm's insects leave. Each is one
// instance of the swarm's trail MultiMesh: a thin sliver from where the insect was (its local y 0)
// to where it is (y 1), added on top, unshaded and over-bright so the glow pass blooms it, the
// type's colour fading out toward the tail and white-hot at the head; its custom data's y its
// brightness. A hit flares them. One material for every swarm, the colour and the flash instance
// uniforms in the shared slots. Defaults only mirror scripts/palette.gd.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform float energy : hint_range(0.0, 32.0) = 4.0;
uniform vec4 head_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);

instance uniform float hit : instance_index(0) = 0.0;
instance uniform vec4 core_color : source_color, instance_index(4) = vec4(1.0, 0.2, 0.333, 1.0);

varying float along;
varying float bright;

void vertex() {
	along = clamp(VERTEX.y, 0.0, 1.0);
	bright = INSTANCE_CUSTOM.y;
}

void fragment() {
	float fade = along * along * bright;
	vec3 col = mix(core_color.rgb, head_color.rgb, along * along * along * 0.6);
	ALBEDO = col * energy * fade * (1.0 + 2.0 * hit);
}
