// SIGKILL ICE crystal (I1): the solid body of every piece of ICE (white ICE's walls and nodes, hunter
// ICE). Not glowing wire and not a box: closed faceted crystal with mass, near-black cold glass that
// takes the arena's light on its facets (low roughness, a strong specular), each facet a shade of its
// own; a little of the ICE's colour (edge_color: glacier for white ICE, cobalt for a hunter) lives
// inside it, brighter in a few facets than the rest, as light caught in a cut stone; a thin line of
// that colour on its true edges (the facets' seams), and a cold rim where it turns away. The ICE's
// real light is in its seams and cores (the ice light look, shaders/daemon_core.gdshader).
//
// Cracks: its custom data's w, 0 whole to 1 shattering. A crack spreads from a point of its own
// (the part's salt) across the facet's face: a network of fracture lines (the edges of a cellular
// pattern in the part's own space, so it stays on the part as it moves), glowing in the ICE's colour
// with a white-hot core, the glass going frosted round them; more lines and wider the deeper it goes.
//
// Every part is one instance of a piece's MultiMesh (scripts/daemons/daemon_art.gd's rig), posed by
// its transform alone; its custom data: x its salt, y its tone, z its presence (1 whole, 0 gone:
// between, it breaks up cell by cell as it shatters or a broken pane falls), w its crack. ICE does not
// glitch: it is the system's own code, still and exact. A hit flares it white.
//
// One material for every piece: the colour and the flash are instance uniforms pinned to the slots
// every daemon shader shares (hit 0, seed 3, edge_color 6), the time the shared shader global. Defaults
// only mirror scripts/palette.gd, which sets every value at runtime and is the single source.
shader_type spatial;

#include "res://shaders/daemon_glitch.gdshaderinc"

uniform vec4 crystal : source_color = vec4(0.024, 0.047, 0.09, 1.0);
uniform float metallic_amount : hint_range(0.0, 1.0) = 0.2;
uniform float roughness_amount : hint_range(0.0, 1.0) = 0.12;
uniform float specular_amount : hint_range(0.0, 1.0) = 0.8;
uniform float tint : hint_range(0.0, 1.0) = 0.3;
uniform float facet_energy : hint_range(0.0, 4.0) = 0.3;
uniform float facet_power : hint_range(0.5, 8.0) = 3.0;
uniform float edge_energy : hint_range(0.0, 8.0) = 0.9;
uniform float edge_px : hint_range(0.0, 8.0) = 1.0;
uniform float edge_near_m : hint_range(0.0, 100.0) = 4.0;
uniform float edge_far_m : hint_range(0.0, 200.0) = 16.0;
uniform float edge_far : hint_range(0.0, 1.0) = 0.2;
uniform float rim_energy : hint_range(0.0, 8.0) = 0.35;
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;
uniform float crack_energy : hint_range(0.0, 16.0) = 3.5;
uniform float crack_cells : hint_range(1.0, 20.0) = 3.0;
uniform float crack_width : hint_range(0.0, 0.5) = 0.06;
uniform vec4 flash_color : source_color = vec4(0.85, 0.95, 1.0, 1.0);
uniform float flash_energy : hint_range(0.0, 32.0) = 5.0;
uniform float cells_per_m : hint_range(1.0, 100.0) = 28.0;

instance uniform vec4 edge_color : source_color, instance_index(6) = vec4(0.094, 0.698, 1.0, 1.0);

varying vec3 world_pos;
varying vec3 local_pos;
varying vec3 bary;
varying vec4 part;
varying flat float facet;

void vertex() {
	part = INSTANCE_CUSTOM;
	local_pos = VERTEX;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	bary = CUSTOM0.rgb;
	// Each facet's own share of the inner light: a hash of its flat normal and the part's salt.
	ivec3 n = ivec3(round(NORMAL * 8.0));
	facet = hash2(n.x * 31 + n.y * 7 + int(part.x * 509.0), n.z * 13 + int(seed * 997.0));
}

// The cellular pattern's edge at `p` (2D): how far from the nearest border between two cells.
float crack_lines(vec2 p, int salt) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float first = 8.0;
	float second = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			ivec2 c = ivec2(cell) + ivec2(x, y);
			vec2 at = vec2(float(x), float(y)) + vec2(hash2(c.x + salt, c.y + 3), hash2(c.y + salt, c.x + 17));
			float d = length(at - f);
			if (d < first) {
				second = first;
				first = d;
			} else if (d < second) {
				second = d;
			}
		}
	}
	return second - first;
}

void fragment() {
	// Presence: below 1 the part breaks up in world-space cells, as the daemons' armour does.
	ivec3 cell = ivec3(floor(world_pos * cells_per_m));
	if (hash2(cell.x * 7 + cell.y * 131 + int(part.x * 997.0), cell.z * 3 + int(seed * 997.0)) > part.z * 1.1) {
		discard;
	}
	// The true edges, about edge_px wide on screen at any distance: the facets' seams.
	vec3 fw = max(fwidth(bary), vec3(0.00001));
	vec3 near = smoothstep(fw * (edge_px - 0.5), fw * (edge_px + 0.5), bary);
	float line = 1.0 - min(min(near.x, near.y), near.z);
	// Far off, the seams' line fades to a trace of itself, so a piece reads as a solid, never a wire.
	line *= mix(1.0, edge_far, smoothstep(edge_near_m, edge_far_m, distance(world_pos, CAMERA_POSITION_WORLD)));
	// The crack: from the part's own point across its face, more lines and wider the deeper it goes.
	float crack = clamp(part.w, 0.0, 1.0);
	float lines = 0.0;
	if (crack > 0.001) {
		int salt = int(part.x * 4093.0);
		vec2 origin = vec2(hash2(salt, 5), hash2(salt, 9)) - 0.5;
		vec2 face = local_pos.xz;
		float reach = smoothstep(0.0, 1.0, crack) * 1.4;
		float spread = 1.0 - smoothstep(reach * 0.6, reach, length(face - origin));
		float edge = crack_lines(face * crack_cells * (1.0 + crack) + vec2(float(salt % 97), 0.0), salt);
		float width = crack_width * (0.5 + crack);
		lines = (1.0 - smoothstep(width * 0.4, width, edge)) * spread;
	}
	float tone = 1.0 + tint * (part.y - 0.5) * 2.0;
	ALBEDO = crystal.rgb * tone;
	METALLIC = metallic_amount;
	ROUGHNESS = mix(roughness_amount, 0.6, lines * 0.7);
	SPECULAR = specular_amount;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	vec3 ice = edge_color.rgb;
	vec3 glow = ice * (facet_energy * pow(facet, facet_power) + edge_energy * line + rim_energy * rim);
	glow += mix(ice, vec3(1.0), 0.3 * lines) * crack_energy * lines * (0.6 + 0.4 * crack);
	// A hit: its seams and rim flare in its own colour, a little toward white; never the whole face, so a
	// wall under fire never blooms into a white sheet.
	glow += mix(ice, flash_color.rgb, 0.35) * flash_energy * hit * (0.1 + line + 0.6 * rim);
	EMISSION = glow;
}
