// The packet tracer's islands (W5, scripts/packets/packet_net.gd): every solid thing of the network drawn by this one
// shader, its numbers per instance, so it compiles once for the whole mode. The mesh is a unit box or a unit cylinder
// scaled to its size (`box`, metres), so its neon edges stay a constant width. What it is by `part`:
//   0  a deck's top: black glass with a lit grid, circuit traces in the machine's accent and pulses running along them,
//      its rim burning
//   1  an island's underside: dark crystal hanging into the void, veins of the accent through it and data dripping off
//      its tip
//   2  a machine's body (a rack, a router, a chip, a drive): near black with neon edges and rows of status lights
//      blinking on its faces
//   3  a lit panel: the accent itself, over-bright (a trackpad, a keycap's legend, a pin's tip, a port's pad)
//   4  the bus far below the network: a vast grid fading into the fog, pulses racing along its lines
// Visual only.
shader_type spatial;
render_mode specular_disabled, shadows_disabled;

instance uniform vec4 accent : source_color = vec4(0.1, 0.83, 0.77, 1.0);
instance uniform vec3 box = vec3(1.0);
instance uniform float part = 2.0;
instance uniform float seed = 0.0;
instance uniform float energy = 1.0;

varying vec3 local_pos;
varying vec3 world_pos;

float hash1(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 3.17) * 43758.5453);
}

void vertex() {
	local_pos = VERTEX * box;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Distance in metres from this point to the nearest edge of the box.
float edge_distance() {
	vec3 d = box * 0.5 - abs(local_pos);
	float smallest = min(d.x, min(d.y, d.z));
	float largest = max(d.x, max(d.y, d.z));
	return d.x + d.y + d.z - smallest - largest;
}

float line_cover(float dist, float width) {
	float fw = max(fwidth(dist), 0.00001);
	return (1.0 - smoothstep(width * 0.5 - fw, width * 0.5 + fw, dist)) * min(1.0, width / fw);
}

void fragment() {
	vec3 base = vec3(0.012, 0.016, 0.02);
	vec3 glow = vec3(0.0);
	float t = TIME;
	int p = int(part + 0.5);
	if (p == 0) {
		// The deck: a grid every 2 m, finer traces in between, pulses running along the grid's lines.
		vec2 w = world_pos.xz;
		vec2 g = abs(fract(w / 2.0) - 0.5) * 2.0;
		float grid = max(line_cover(1.0 - g.x, 0.035), line_cover(1.0 - g.y, 0.035));
		vec2 cellp = floor(w / 2.0);
		float trace = 0.0;
		float hx = hash1(cellp);
		if (hx > 0.55) {
			vec2 f = fract(w / 2.0);
			float along = hx > 0.78 ? f.x : f.y;
			float across = hx > 0.78 ? f.y : f.x;
			trace = line_cover(abs(across - 0.5), 0.05) * step(0.2, along) * step(along, 0.85);
			trace += line_cover(length(f - vec2(hx > 0.78 ? 0.85 : 0.5, hx > 0.78 ? 0.5 : 0.85)) - 0.06, 0.04);
		}
		float pulse_x = smoothstep(0.92, 1.0, fract(w.x * 0.05 - t * 0.6 + seed));
		float pulse_z = smoothstep(0.92, 1.0, fract(w.y * 0.05 + t * 0.45 + seed * 1.3));
		float rim = line_cover(edge_distance(), 0.16);
		glow = accent.rgb * (grid * (0.45 + 2.4 * max(pulse_x * g.y, pulse_z * g.x)) + trace * 0.9 + rim * 3.2) * energy;
		base = vec3(0.01, 0.014, 0.018);
	} else if (p == 1) {
		// The underside: crystal facets lit by veins, the light dripping down off it.
		float h = -local_pos.y / max(box.y, 0.001);
		float vein = sin(world_pos.x * 1.7 + world_pos.z * 0.9 + sin(world_pos.y * 0.8 + seed) * 2.0);
		vein = line_cover(abs(vein), 0.18);
		float drip_col = floor(world_pos.x * 1.3 + world_pos.z * 0.7);
		float drip = step(0.86, hash1(vec2(drip_col, 7.0))) * smoothstep(0.75, 1.0, fract(world_pos.y * 0.12 + t * (0.4 + hash1(vec2(drip_col, 3.0)))));
		float rim = line_cover(edge_distance(), 0.1);
		glow = accent.rgb * (vein * (0.6 + 0.4 * h) + drip * 1.8 + rim * 1.2) * energy;
		base = vec3(0.008, 0.01, 0.014);
	} else if (p == 2) {
		// A machine: neon edges, and rows of status lights on its faces, each blinking on its own beat.
		float edge = line_cover(edge_distance(), 0.07);
		vec2 face = abs(local_pos.y) < box.y * 0.5 - 0.01 ? (abs(local_pos.x) > box.x * 0.5 - 0.01 ? local_pos.zy : local_pos.xy) : local_pos.xz;
		vec2 cellp = floor(face * vec2(5.0, 4.0));
		vec2 f = fract(face * vec2(5.0, 4.0));
		float lamp = step(0.35, f.x) * step(f.x, 0.62) * step(0.42, f.y) * step(f.y, 0.58);
		float blink = step(0.5, fract(t * (0.6 + 2.4 * hash1(cellp)) + hash1(cellp + 3.1)));
		float on = step(0.45, hash1(cellp + 11.0)) * lamp * blink;
		float side = abs(local_pos.y) < box.y * 0.5 - 0.02 ? 1.0 : 0.0;
		glow = accent.rgb * (edge * 2.6 + on * 1.6 * side) * energy;
		base = vec3(0.016, 0.02, 0.026);
	} else if (p == 3) {
		glow = accent.rgb * 2.2 * energy;
		base = accent.rgb * 0.1;
	} else {
		// The bus: a grid a metre to the cell's 8 m, pulses racing down its lines.
		vec2 w = world_pos.xz / 8.0;
		vec2 g = abs(fract(w) - 0.5) * 2.0;
		float grid = max(line_cover(1.0 - g.x, 0.04), line_cover(1.0 - g.y, 0.04));
		vec2 lane = floor(w);
		float rx = smoothstep(0.96, 1.0, fract(world_pos.x * 0.01 + t * (0.3 + hash1(vec2(lane.y, 1.0))) + hash1(vec2(lane.y, 9.0))));
		float rz = smoothstep(0.96, 1.0, fract(world_pos.z * 0.01 - t * (0.25 + hash1(vec2(lane.x, 2.0))) + hash1(vec2(lane.x, 5.0))));
		float run = max(rx * step(0.7, hash1(vec2(lane.y, 4.0))) * step(g.y, 0.2), rz * step(0.7, hash1(vec2(lane.x, 6.0))) * step(g.x, 0.2));
		glow = accent.rgb * (grid * 0.35 + run * 2.5) * energy;
		base = vec3(0.004, 0.006, 0.008);
	}
	ALBEDO = base;
	ROUGHNESS = p == 0 ? 0.35 : 0.9;
	EMISSION = glow;
}
