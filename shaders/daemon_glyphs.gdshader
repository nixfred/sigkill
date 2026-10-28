// SIGKILL daemon glyphs (A2): the red terminal glyphs floating round a daemon. Each is a small quad,
// one instance of the daemon's glyph MultiMesh, turned to face the camera, carrying a glyph drawn
// from a 4 by 6 bit grid mirrored left to right (as the code rain's are), re-rolled a few times a
// second. Original and procedural: no font, no texture. The glyph MultiMesh turns slowly as a
// node, so the glyphs orbit with no per-frame data at all.
//
// One material for every daemon: the time is the shared shader global daemon_clock (the game's pace,
// so SIGSTOP slows the flicker), offset by the daemon's seed; its hit flash and its seed are
// instance uniforms pinned to the slots every daemon shader shares (A2b); each glyph's own salt is
// in its instance's custom data. Every hash is an integer hash (PCG) of small integers, the tick
// wrapped at 1024. Defaults only mirror scripts/palette.gd, which sets every value at runtime.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 glyph_color : source_color = vec4(1.0, 0.2, 0.333, 1.0);
uniform float energy : hint_range(0.0, 32.0) = 3.0;
uniform float flicker_rate : hint_range(0.0, 30.0) = 4.0;
uniform float flash_energy : hint_range(0.0, 32.0) = 6.0;

global uniform float daemon_clock;

instance uniform float hit : instance_index(0) = 0.0;
instance uniform float seed : instance_index(3) = 0.0;

varying float salt;

uint pcg(uint v) {
	uint state = v * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}

void vertex() {
	salt = INSTANCE_CUSTOM.x;
	// Face the camera, keeping each glyph's place and size.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	// 6 columns by 8 rows with a one-cell margin: a 4 by 6 glyph inside.
	ivec2 cell = ivec2(floor(UV * vec2(6.0, 8.0)));
	if (cell.x < 1 || cell.x > 4 || cell.y < 1 || cell.y > 6) {
		discard;
	}
	int col = cell.x - 1;
	if (col > 1) {
		col = 3 - col; // mirrored left to right, so it reads like a character
	}
	int tick = int(mod(floor((daemon_clock + seed * 97.0) * flicker_rate + salt * 13.0), 1024.0));
	uint bits = pcg(uint(int(salt * 4093.0) & 0xffff) * 1031u + uint(tick));
	int bit = (cell.y - 1) * 2 + col;
	if (((bits >> uint(bit)) & 1u) == 0u) {
		discard;
	}
	ALBEDO = glyph_color.rgb * mix(energy, flash_energy, hit);
}
