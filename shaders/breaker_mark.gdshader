// SIGKILL exploit's seam marks (I2): while the player's exploit breaker runs, a diamond of ultraviolet
// light with a dot at its heart over every weak seam (A5's weak() points) of every daemon and piece of
// ICE standing, so the player sees what to aim at. Each mark is one instance of a unit quad in one
// MultiMesh (scripts/ice/exploit_marks.gd), turned to face the camera at the size its instance gives,
// and pulled a little toward the eye so the armour it marks never hides half of it. Additive and
// unlit, depth tested: a wall still hides what is behind it. It pulses on the shared shader clock, each
// mark a little out of step with the next. Defaults only mirror scripts/palette.gd.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

global uniform float daemon_clock;

uniform vec4 color : source_color = vec4(0.4549, 0.0, 0.8, 1.0);
uniform float energy : hint_range(0.0, 16.0) = 3.0;
uniform float pull_m : hint_range(0.0, 2.0) = 0.22;

varying float phase;

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	VERTEX.z += pull_m / max(s, 0.001);
	phase = fract(MODEL_MATRIX[3].x * 0.37 + MODEL_MATRIX[3].z * 0.61);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float diamond = abs(p.x) + abs(p.y);
	float ring = 1.0 - smoothstep(0.0, 0.09, abs(diamond - 0.78));
	float heart = 1.0 - smoothstep(0.1, 0.18, length(p));
	float pulse = 0.7 + 0.3 * sin(daemon_clock * 6.0 + phase * 6.2832);
	ALBEDO = color.rgb * energy * (ring + heart * 0.9) * pulse;
}
