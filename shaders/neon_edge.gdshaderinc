// SIGKILL neon edge, shared part: near-black faces with glowing edges along the shape's
// outline. Included by neon_edge.gdshader (the plain look, used on the target dummies)
// and code_rain.gdshader (the same look plus Matrix code rain, used on the greybox blocks).
// Two shapes: a box (hex_prism = false) and a regular hexagonal prism (hex_prism = true).
// Edge width is in metres, measured in local space.
//
// How it finds edges without normals or extra geometry: on any flat face one of the
// plane distances is zero (the face itself). The second smallest distance is how far the
// point is from the nearest edge. A box has three plane families. The hexagonal prism has
// four: three side-plane pairs plus the top and bottom caps. On the hexagon the side planes
// meet at 120 degrees, so the plane distance underestimates the true distance along a face
// and the vertical edges come out about 15 percent wider than the rim edges.
//
// half_extents: box = half size on each axis. Hexagon = (apothem, half height, unused).
// Colour defaults only mirror scripts/palette.gd so the material previews in the editor.
// palette.gd sets every value at runtime and is the single source.
// The including shader sets local_pos = VERTEX in its vertex function.

uniform vec4 face_color : source_color = vec4(0.0196, 0.0314, 0.0392, 1.0);
uniform vec4 edge_color : source_color = vec4(0.098, 0.827, 0.773, 1.0);
uniform float edge_width : hint_range(0.001, 0.5) = 0.04;
uniform float edge_energy : hint_range(0.0, 16.0) = 2.0;
uniform bool hex_prism = false;
uniform vec3 half_extents = vec3(1.0);

varying vec3 local_pos;

// Distance in metres from this point to the nearest edge of the shape.
float edge_distance() {
	if (hex_prism) {
		// Side-plane normals sit at 30, 90 and 150 degrees measured from +Z toward +X,
		// which is how CylinderMesh lays out a six-sided prism.
		vec2 p = local_pos.xz;
		float d0 = half_extents.x - abs(dot(p, vec2(0.5, 0.8660254)));
		float d1 = half_extents.x - abs(p.x);
		float d2 = half_extents.x - abs(dot(p, vec2(0.5, -0.8660254)));
		float dy = half_extents.y - abs(local_pos.y);
		float lo_a = min(d0, d1);
		float hi_a = max(d0, d1);
		float lo_b = min(d2, dy);
		float hi_b = max(d2, dy);
		// Second smallest of the four distances.
		return min(max(lo_a, lo_b), min(hi_a, hi_b));
	}
	vec3 d = half_extents - abs(local_pos);
	float smallest = min(d.x, min(d.y, d.z));
	float largest = max(d.x, max(d.y, d.z));
	// Middle of the three distances.
	return d.x + d.y + d.z - smallest - largest;
}

// Anti-aliased coverage of the edge line. Loses energy once a pixel is wider than the line.
float edge_cover(float dist) {
	float fw = max(fwidth(dist), 0.00001);
	float half_w = edge_width * 0.5;
	float cover = 1.0 - smoothstep(half_w - fw, half_w + fw, dist);
	return cover * min(1.0, edge_width / fw);
}
