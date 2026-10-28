// SIGKILL daemon core (A2, redone in A2b): the glowing parts of every daemon: a rogue daemon's heart,
// its knees and its burning dorsal shards; a zombie's ember and joints and the voxels it sheds; a
// swarm's nest and every insect's glint; and the shards a hit sprays. Unshaded and over-bright so
// the glow pass blooms it: the type's own colour from the palette (hostile red for a rogue daemon
// and a swarm, hostile amber for a zombie), breathing slowly, guttering for a zombie, flaring
// white-hot on a hit. Faceless: gems of light, no feature.
//
// Every part is one instance of a daemon's MultiMesh; its custom data: x its salt, y its
// brightness, z its presence (below 1 it breaks up cell by cell, as the shell does). It moves with
// the same glitch as the shell (shaders/daemon_glitch.gdshaderinc), so a core never drifts off its
// shell. One material for every daemon: the colour, the gutter and the flash are instance
// uniforms pinned to the shared slots, the time the shared shader global. Defaults only mirror
// scripts/palette.gd, which sets every value at runtime.
shader_type spatial;
render_mode unshaded, world_vertex_coords;

#include "res://shaders/daemon_glitch.gdshaderinc"

uniform float energy : hint_range(0.0, 32.0) = 4.0;
uniform float breath : hint_range(0.0, 1.0) = 0.25;
uniform float breath_hz : hint_range(0.0, 8.0) = 0.6;
uniform float flash_energy : hint_range(0.0, 32.0) = 10.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform float cells_per_m : hint_range(1.0, 100.0) = 28.0;

instance uniform vec4 core_color : source_color, instance_index(4) = vec4(1.0, 0.2, 0.333, 1.0);
instance uniform float gutter : instance_index(5) = 0.0;

varying vec4 part;
varying vec3 world_pos;

void vertex() {
	part = INSTANCE_CUSTOM;
	float g;
	VERTEX += glitch_offset(VERTEX, part, INV_VIEW_MATRIX[0].xyz, g);
	world_pos = VERTEX;
}

void fragment() {
	ivec3 cell = ivec3(floor(world_pos * cells_per_m));
	if (hash2(cell.x * 7 + cell.y * 131 + int(part.x * 997.0), cell.z * 3 + 11) > part.z * 1.1) {
		discard;
	}
	float t = daemon_time();
	float wave = 1.0 + breath * sin(6.2831853 * breath_hz * t + (seed + part.x) * 6.2831853);
	int tick = int(mod(floor(t * 12.0), 1024.0));
	float roll = hash2(tick, int(seed * 997.0) + int(part.x * 251.0));
	float dim = mix(1.0, 0.15 + 0.85 * step(0.35, roll), gutter); // a zombie's ember drops out now and then
	vec3 col = core_color.rgb * energy * wave * dim * part.y;
	ALBEDO = mix(col, flash_color.rgb * flash_energy, hit);
}
