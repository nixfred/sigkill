// SIGKILL floor grid: black floor, thin emissive teal grid (1 m cells) and brighter major
// lines every 8 m. Works in world space, so every floor block shares one continuous grid.
// Lines are anti-aliased with fwidth and lose energy as they shrink below a pixel, so the far
// floor fades to black instead of shimmering.
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
uniform float minor_energy : hint_range(0.0, 16.0) = 1.0;
uniform float major_energy : hint_range(0.0, 16.0) = 2.2;

varying vec3 world_pos;

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

void fragment() {
	float major_cell = cell_size * major_every;
	vec2 minor_uv = world_pos.xz / cell_size;
	vec2 major_uv = world_pos.xz / major_cell;
	float minor_line = max(grid_mask(minor_uv.x, minor_width / cell_size), grid_mask(minor_uv.y, minor_width / cell_size));
	float major_line = max(grid_mask(major_uv.x, major_width / major_cell), grid_mask(major_uv.y, major_width / major_cell));
	ALBEDO = base_color.rgb;
	ROUGHNESS = 1.0;
	EMISSION = minor_color.rgb * (minor_energy * minor_line) + major_color.rgb * (major_energy * major_line);
}
