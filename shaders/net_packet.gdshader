// The packet tracer's packets (W5, scripts/packets/packet_net.gd): every packet streaming down the links (one MultiMesh,
// its colour in each instance's custom data) and the one the player rides. A slab of light on a unit box: its header (the
// front quarter) brighter, a dark payload band across its middle, its edges lit. Over-bright, so the glow blooms it.
// Visual only.
shader_type spatial;
render_mode unshaded, shadows_disabled;

uniform vec4 single : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform float boost = 1.0;

varying vec4 tint;
varying vec3 local;

void vertex() {
	tint = single.a > 0.0 ? single : INSTANCE_CUSTOM;
	local = VERTEX;
}

void fragment() {
	float head = smoothstep(0.2, 0.3, -local.z);
	vec2 a = abs(local.xz) * 2.0;
	float edge = smoothstep(0.82, 0.96, max(a.x, a.y));
	float payload = step(abs(local.z), 0.12) * step(abs(local.x), 0.38);
	ALBEDO = tint.rgb * (1.1 + 2.2 * head + 1.4 * edge) * (1.0 - 0.6 * payload) * boost;
}
