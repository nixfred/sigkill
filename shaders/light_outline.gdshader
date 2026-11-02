shader_type spatial;
// A light theme's outline (P2, W3's Latte zombie): drawn as a mesh's material_overlay by scripts/themes/light_outline.gd
// on a zombie's every piece while a light theme shows, and on nothing else. The theme's grade is one screen-space pass by
// colour, and a zombie's near-black armour has the void's lightness, so under a light theme both turn to paper and the
// zombie melts into the sky. This draws the piece again a little bigger, its front faces culled (an inverted hull), so a
// rim shows round its silhouette, in a saturated red the grade takes to the theme's own red, as it does every daemon's.
//
// A daemon is drawn as MultiMeshes of unit shapes, each part an instance scaled to its size (scripts/daemons/
// daemon_art.gd), so the push is made in world space, where a part's own scale cannot make the rim uneven: each vertex
// goes out along its direction from its part's centre, not its normal. The parts are boxes and prisms with hard edges,
// and a corner's three normals would tear the hull open there; a corner's one position never does. A part not posed yet
// (an instance collapsed to a point) stays a point. The push grows with distance, so the rim stays about the same width
// on screen near and far.

render_mode unshaded, cull_front, shadows_disabled, world_vertex_coords;

// The rim's colour before the grade (set by light_outline.gd: a saturated red, the grade's way to the theme's red).
uniform vec4 ink : source_color = vec4(1.0, 0.05, 0.1, 1.0);
// The rim's width, as a share of the distance to the camera (0.004: about three pixels at 1080p).
uniform float width = 0.004;

void vertex() {
	vec3 out_from = VERTEX - MODEL_MATRIX[3].xyz;
	if (length(out_from) > 0.0001) {
		float dist = max(length(VERTEX - CAMERA_POSITION_WORLD), 0.5);
		VERTEX += normalize(out_from) * width * dist;
	}
}

void fragment() {
	ALBEDO = ink.rgb;
}
