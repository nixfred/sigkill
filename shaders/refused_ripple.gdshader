shader_type spatial;
// A refused hit (P2, M7's shell: anything but kill -9): a cold hexagon ripple on the plane where the shot met it, facing
// the shot, drawn by scripts/fx/refused_fx.gd. Two hexagon rings run out from the point and fade, a faint hexagon lattice
// lights behind them for a moment: a guard taking the blow, in a refusal's steel, never the hot flash of a hit that lands.

render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 steel : source_color = vec4(0.663, 0.741, 0.839, 1.0);
// 0 as it meets, 1 gone.
uniform float age = 0.0;

varying vec2 p;

void vertex() {
	p = VERTEX.xy;
}

// The distance to the middle measured as a hexagon (a flat-topped one): constant along each of its six sides.
float hex_of(vec2 q) {
	q = abs(q);
	return max(q.x * 0.866025 + q.y * 0.5, q.y);
}

void fragment() {
	float d = hex_of(p * 2.0);  // the quad is one unit across: 1 at its edge's hexagon
	float out1 = mix(0.12, 0.95, sqrt(age));
	float out2 = mix(0.05, 0.7, age * age);
	float ring1 = 1.0 - smoothstep(0.02, 0.06, abs(d - out1));
	float ring2 = 1.0 - smoothstep(0.01, 0.04, abs(d - out2));
	// The lattice: a hexagon grid that flashes behind the first ring and dies as it passes.
	vec2 g = p * 10.0;
	vec2 cell = vec2(g.x + g.y * 0.57735, g.y * 1.1547);
	float lattice = smoothstep(0.42, 0.5, max(abs(fract(cell.x) - 0.5), abs(fract(cell.y) - 0.5)));
	float behind = (1.0 - smoothstep(0.0, 0.2, out1 - d)) * step(d, out1);
	float fade = 1.0 - age;
	float glow = (ring1 * 1.0 + ring2 * 0.6) * fade + lattice * behind * 0.35 * fade;
	glow *= 1.0 - smoothstep(0.92, 1.0, d);
	ALBEDO = steel.rgb * 2.2 * glow;
	ALPHA = clamp(glow, 0.0, 1.0);
}
