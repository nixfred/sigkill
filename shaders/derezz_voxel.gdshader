// SIGKILL derezz voxel (A2): every cube of a derezz, a daemon's or a player's. Glowing Tron edges
// round a dimmer face, in the voxel's own colour (red-hot or obsidian, its instance colour); as the
// voxel fades its faces fall away cell by cell, the edges last, so a cube derezzes instead of only
// shrinking. Unshaded and over-bright so the glow pass blooms it. The motion, the size, the colour
// and the fade are the effect's own, unchanged: the fade is the instance colour's alpha, as before.
// One material for every derezz. BoxMesh lays its six faces out 3 by 2 in UV, so each face's own
// square is a cell of the UV. The hash is an integer hash (PCG) of the voxel's index and a cell.
// Defaults only mirror scripts/palette.gd and resources/derezz.tres, which set every value.
shader_type spatial;
render_mode unshaded, cull_back;

uniform float energy : hint_range(0.0, 32.0) = 4.0;
uniform float edge_width : hint_range(0.0, 0.5) = 0.14;
uniform float face_share : hint_range(0.0, 2.0) = 0.45;
uniform float edge_boost : hint_range(0.0, 8.0) = 1.8;
uniform float cells : hint_range(1.0, 8.0) = 3.0;

varying vec4 tint;
varying flat int voxel;

uint pcg(uint v) {
	uint state = v * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}

void vertex() {
	tint = COLOR;
	voxel = INSTANCE_ID;
}

void fragment() {
	vec2 face = fract(UV * vec2(3.0, 2.0));
	vec2 f = abs(face * 2.0 - 1.0);
	float e = max(f.x, f.y);
	float fw = max(fwidth(e), 0.0001);
	float edge = smoothstep(1.0 - edge_width - fw, 1.0 - edge_width, e);
	ivec2 cell = ivec2(floor(face * cells));
	float roll = float(pcg(uint(voxel & 0xffff) * 977u + uint(cell.x * 7 + cell.y * 131)) & 0xffffu) / 65535.0;
	// Cells drop out as the fade falls; an edge holds on longest.
	if (roll > tint.a * (1.0 + 0.6 * edge) * 1.15) {
		discard;
	}
	ALBEDO = tint.rgb * energy * mix(face_share, edge_boost, edge);
	ALPHA = tint.a;
}
