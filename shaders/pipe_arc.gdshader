// SIGKILL pipe |'s arcs (C30): the stream of one process's stdout flowing into the next one's stdin, drawn
// link to link. scripts/weapons/pipe_arc.gd builds every arc each frame as a jagged ribbon turned to face
// the eye (one ImmediateMesh): UV.x runs across it (0 to 1), UV.y along it in metres from where the stream
// left; COLOR.r is the arc's strength (it fades out), COLOR.g its weight (the main arc 1, its thinner side
// filaments less), COLOR.b 1 for a packet. Across a ribbon, a thin hot core in the highlight inside a soft
// sheath of brass; along it, bands of data a packet_m apart racing from source to sink at packet_speed, in
// step with the packets: short bars laid across the main arc, wider than it, drawn here as solid hot light
// (the pipe's "|"). A fast flicker over it all. Additive and unshaded: it only adds light. Defaults only
// mirror scripts/palette.gd and scripts/weapons/pipe_arc.gd, which set every value at runtime.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;

uniform vec4 color : source_color = vec4(0.655, 0.576, 0.0, 1.0);
uniform vec4 hot : source_color = vec4(0.984, 0.925, 0.722, 1.0);
uniform float energy : hint_range(0.0, 32.0) = 3.2;
uniform float core_width : hint_range(0.0, 0.5) = 0.26;
uniform float packet_m : hint_range(0.05, 4.0) = 0.55;
uniform float packet_width : hint_range(0.0, 0.5) = 0.09;
uniform float packet_speed : hint_range(0.0, 80.0) = 18.0;
uniform float packet_energy : hint_range(0.0, 8.0) = 1.6;
// The stream's own clock, seconds (the script's, so the bands ride with its packets).
uniform float flow_s = 0.0;

void fragment() {
	float x = abs(UV.x - 0.5) * 2.0;
	float strength = COLOR.r;
	float weight = COLOR.g;
	float core = 1.0 - smoothstep(0.0, core_width, x);
	float sheath = pow(max(1.0 - x, 0.0), 2.4);
	float t = fract((UV.y - flow_s * packet_speed) / packet_m);
	float packet = 1.0 - smoothstep(0.0, packet_width, min(t, 1.0 - t));
	float flick = 0.78 + 0.22 * sin(TIME * 61.0 + UV.y * 13.0);
	vec3 light = color.rgb * sheath * (0.55 + 1.1 * packet) + hot.rgb * (core * (0.8 + 0.6 * packet) + packet * sheath * 0.45);
	vec3 bar = hot.rgb * packet_energy * (1.0 - x * x);
	ALBEDO = (COLOR.b > 0.5 ? bar : light * weight * flick) * energy * strength;
}
