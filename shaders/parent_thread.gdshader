shader_type spatial;
// A zombie's thread to its parent (M2, scripts/missions/parent_threads.gd): one segment of a thin arc of amber light,
// a pulse running along it toward the parent, brighter where ping has lit the zombie it comes from. Added light,
// unshaded, never in a shadow.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.58, 0.12);
uniform float energy = 2.2;
// How fast its pulses run, threads a second, and how many ride a thread at once.
uniform float speed = 0.45;
uniform float pulses = 3.0;

varying vec4 data;
varying float along;

void vertex() {
	// x: where along its thread this segment starts (0 at the zombie, 1 at the parent); y: the segment's share of it;
	// z: its brightness; w: its thread's phase. The segment is a unit box along its own y.
	data = INSTANCE_CUSTOM;
	along = VERTEX.y + 0.5;
}

void fragment() {
	float u = data.x + data.y * along;
	float run = fract(u * pulses - TIME * speed + data.w);
	float pulse = pow(run, 10.0) * 1.6;
	// It fades in from the zombie and out into the parent's anchor.
	float ends = smoothstep(0.0, 0.05, u) * (1.0 - smoothstep(0.95, 1.0, u));
	ALBEDO = color * energy * data.z * (0.35 + pulse) * ends;
}
