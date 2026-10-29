// SIGKILL ping's reveal (C28): a daemon the sonar ring met, drawn through the level as a bright
// outline. scripts/weapons/ping_reveal.gd draws each of the daemon's own MultiMeshes (its shell and
// core sets, posed every frame by its art) a second time with this material, so the outline is the
// creature as it stands and moves, never a stand-in shape.
//
// Drawn with no depth test and additive: no wall hides it and it only adds light. Its edges where
// the parts turn away are bright (a rim), the faces a faint fill, and thin scan bands climb it on
// the daemons' shared clock (so SIGSTOP slows them with the rest). `reveal` fades the whole of it in
// and out per daemon (an instance uniform, so every daemon shares this one material); a part whose
// presence is gone (custom z, as the daemon shaders read it) draws nothing. Defaults only mirror
// scripts/palette.gd, which sets every value at runtime.
shader_type spatial;
render_mode unshaded, world_vertex_coords, depth_test_disabled, depth_draw_never, cull_back, blend_add, shadows_disabled;

global uniform float daemon_clock;

uniform vec4 color : source_color = vec4(0.722, 1.0, 0.176, 1.0);
uniform vec4 scan_color : source_color = vec4(0.894, 1.0, 0.702, 1.0);
uniform float rim_energy : hint_range(0.0, 16.0) = 3.5;
uniform float rim_power : hint_range(0.5, 8.0) = 1.6;
uniform float fill_energy : hint_range(0.0, 4.0) = 0.22;
uniform float scan_energy : hint_range(0.0, 8.0) = 1.2;
uniform float scan_per_m : hint_range(0.5, 40.0) = 5.0;
uniform float scan_width : hint_range(0.01, 0.5) = 0.18;
uniform float scan_speed : hint_range(0.0, 8.0) = 1.6;

instance uniform float reveal : instance_index(0) = 0.0;

varying vec4 part;
varying vec3 world_pos;

void vertex() {
	part = INSTANCE_CUSTOM;
	world_pos = VERTEX;
}

void fragment() {
	float shown = reveal * clamp(part.z, 0.0, 1.0);
	if (shown <= 0.001) {
		discard;
	}
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = pow(1.0 - facing, rim_power);
	float band = fract(world_pos.y * scan_per_m - daemon_clock * scan_speed);
	float scan = smoothstep(1.0 - scan_width, 1.0, band);
	vec3 light = color.rgb * (fill_energy + rim * rim_energy) + scan_color.rgb * scan * scan_energy;
	ALBEDO = light * shown;
}
