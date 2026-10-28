// SIGKILL floor (A3): dark metal deck plates in world space, so every floor block shares one
// continuous deck. Plates (plate_m square) are parted by thin seams with a faint teal glint in them,
// each plate a shade lighter or darker than the next (in its faint teal glow too), some with an inset
// line round them, and some vent grates glowing teal from below. Over the plates, the old grid: thin
// teal lines every metre, now faint, and a brighter major line every 8 m, a light strip set into the
// deck.
// Every line is anti-aliased with fwidth and loses energy as it shrinks below a pixel, so the far
// floor fades into the dark instead of shimmering; the plates' details give way the same way. Each
// plate's choices come from an integer hash (PCG) of its index.
// Colour defaults only mirror scripts/palette.gd so the material previews in the editor.
// palette.gd sets every value at runtime and is the single source.
shader_type spatial;
render_mode specular_disabled;

uniform vec4 base_color : source_color = vec4(0.0196, 0.0314, 0.0392, 1.0);
uniform vec4 minor_color : source_color = vec4(0.098, 0.827, 0.773, 1.0);
uniform vec4 major_color : source_color = vec4(0.490, 1.0, 0.812, 1.0);
uniform float cell_size : hint_range(0.1, 10.0) = 1.0;
uniform float major_every : hint_range(1.0, 32.0) = 8.0;
uniform float minor_width : hint_range(0.001, 0.2) = 0.02;
uniform float major_width : hint_range(0.001, 0.4) = 0.05;
uniform float minor_energy : hint_range(0.0, 16.0) = 0.05;
uniform float major_energy : hint_range(0.0, 16.0) = 2.2;
uniform float plate_m : hint_range(0.25, 16.0) = 2.0;
uniform float seam_m : hint_range(0.001, 0.2) = 0.03;
uniform float seam_energy : hint_range(0.0, 8.0) = 0.1;
uniform float plate_tone : hint_range(0.0, 1.0) = 0.6;
uniform float plate_glow : hint_range(0.0, 1.0) = 0.008;
uniform float inset_m : hint_range(0.01, 1.0) = 0.16;
uniform float inset_share : hint_range(0.0, 1.0) = 0.4;
uniform float inset_energy : hint_range(0.0, 8.0) = 0.07;
uniform float vent_share : hint_range(0.0, 1.0) = 0.06;
uniform float vent_slot_m : hint_range(0.01, 0.5) = 0.09;
uniform float vent_energy : hint_range(0.0, 8.0) = 0.12;

varying vec3 world_pos;

uint pcg(uint v) {
	uint state = v * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}

// A hash of a plate's index and a salt, from 0 to 1.
float plate_hash(ivec2 plate, int salt) {
	return float(pcg(uint(plate.x & 0x3ff) | (uint(plate.y & 0x3ff) << 10u) | (uint(salt & 0x3ff) << 20u)) & 0xffffu) / 65535.0;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Anti-aliased coverage of a periodic line along one axis.
// coord is the world coordinate divided by the cell size. width_cells is the line width in cells.
float grid_mask(float coord, float width_cells) {
	float fw = max(fwidth(coord), 0.00001);
	float dist = abs(fract(coord - 0.5) - 0.5); // distance to the nearest line, in cells
	float half_w = width_cells * 0.5;
	float cover = 1.0 - smoothstep(half_w - fw, half_w + fw, dist);
	// Once a pixel is wider than the line, spread the line's energy over the pixel.
	return cover * min(1.0, width_cells / fw);
}

// Coverage of a line `width` wide at distance `d` (metres) from it, anti-aliased, fading once a pixel
// is wider than the line.
float line_at(float d, float width) {
	float fw = max(fwidth(d), 0.00001);
	return (1.0 - smoothstep(width * 0.5 - fw, width * 0.5 + fw, d)) * min(1.0, width / fw);
}

void fragment() {
	float major_cell = cell_size * major_every;
	vec2 minor_uv = world_pos.xz / cell_size;
	vec2 major_uv = world_pos.xz / major_cell;
	float minor_line = max(grid_mask(minor_uv.x, minor_width / cell_size), grid_mask(minor_uv.y, minor_width / cell_size));
	float major_line = max(grid_mask(major_uv.x, major_width / major_cell), grid_mask(major_uv.y, major_width / major_cell));

	vec2 in_plate = world_pos.xz / plate_m;
	ivec2 plate = ivec2(floor(in_plate));
	vec2 edge = (0.5 - abs(fract(in_plate) - 0.5)) * plate_m; // metres to the plate's edge on each axis
	float to_edge = min(edge.x, edge.y);
	float seam = line_at(to_edge, seam_m * 2.0);
	float tone = 1.0 + (plate_hash(plate, 1) - 0.5) * plate_tone;
	float inset = step(plate_hash(plate, 2), inset_share) * line_at(abs(to_edge - inset_m), seam_m);
	float vent = 0.0;
	if (plate_hash(plate, 3) < vent_share && to_edge > inset_m) {
		vent = 1.0 - line_at(abs(fract(world_pos.x / vent_slot_m) - 0.5) * vent_slot_m, vent_slot_m * 0.45);
	}

	ALBEDO = base_color.rgb * tone * (1.0 - 0.6 * seam) * (1.0 - 0.5 * vent);
	ROUGHNESS = 1.0;
	EMISSION = minor_color.rgb * (minor_energy * minor_line + seam_energy * seam + inset_energy * inset + vent_energy * vent * 0.5 + plate_glow * tone * tone)
		+ major_color.rgb * (major_energy * major_line);
}
