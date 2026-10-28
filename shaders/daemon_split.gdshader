// SIGKILL daemon split (A2b): the RGB split of every daemon's glitch, the shell's second pass. It
// draws a shell part's true edges again in the split colour, added on top, offset sideways on
// screen, so a glitching daemon shows a red edge and a cyan echo beside it, the classic split of a
// broken signal. It shows only while the part glitches (a roll per part on a few ticks a second, or
// while the daemon is hit or rematerialising) and always faintly on a ghost; otherwise every vertex
// of the part goes to one point off screen, so it draws nothing. The copy is pulled a little toward the camera so the shell it splits off
// never hides it; a wall in front still does.
//
// One material, the shell's next pass, so it reads the same pinned instance uniforms and the same
// glitch as the shell (shaders/daemon_glitch.gdshaderinc). Defaults only mirror scripts/palette.gd.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, world_vertex_coords, shadows_disabled;

#include "res://shaders/daemon_glitch.gdshaderinc"

uniform vec4 split_color : source_color = vec4(0.302, 0.882, 1.0, 1.0);
uniform float split_energy : hint_range(0.0, 16.0) = 3.0;
uniform float split_px : hint_range(0.0, 32.0) = 6.0;
uniform float edge_px : hint_range(0.0, 8.0) = 1.4;
uniform float pull_m : hint_range(0.0, 1.0) = 0.12;
uniform float ghost_split : hint_range(0.0, 1.0) = 0.35;

varying vec3 bary;
varying float amount;
varying vec4 part;

void vertex() {
	part = INSTANCE_CUSTOM;
	float g;
	VERTEX += glitch_offset(VERTEX, part, INV_VIEW_MATRIX[0].xyz, g);
	// Whether this part splits now is one roll for the whole part (never per vertex, or a triangle
	// would be torn between on and off screen): on a few ticks a second, always while hit or
	// rematerialising, faintly on a ghost.
	int tick = int(mod(floor(daemon_time() * glitch_rate), 1024.0));
	float rolled = step(1.0 - glitch_share * 2.0, hash2(tick + int(seed * 997.0) + 300, int(part.x * 4093.0)));
	amount = max(max(rolled, glitch_strength()), ghost_split * step(0.01, part.w));
	bary = CUSTOM0.rgb;
	if (amount < 0.01 || part.z < 0.5) {
		// Nothing to split: every vertex off screen, so no fragment is drawn.
		POSITION = vec4(2.0, 2.0, 2.0, 1.0);
	} else {
		vec3 v = VERTEX + normalize(CAMERA_POSITION_WORLD - VERTEX) * pull_m;
		POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(v, 1.0));
		float side = hash2(int(mod(floor(daemon_time() * glitch_rate), 1024.0)), int(part.x * 4093.0)) < 0.5 ? -1.0 : 1.0;
		POSITION.x += side * split_px * amount * 2.0 / VIEWPORT_SIZE.x * POSITION.w;
	}
}

void fragment() {
	vec3 fw = max(fwidth(bary), vec3(0.00001));
	vec3 near = smoothstep(fw * (edge_px - 0.5), fw * (edge_px + 0.5), bary);
	float line = 1.0 - min(min(near.x, near.y), near.z);
	if (line < 0.04) {
		discard;
	}
	ALBEDO = split_color.rgb * split_energy * line * min(amount, 1.0);
}
