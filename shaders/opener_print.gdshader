shader_type spatial;
// The rifle printing itself (C42, scripts/opener/forge_beat.gd): every part of the SIGKILL rail rifle's model drawn
// only behind a front sweeping from its back to its muzzle, as the cells of `kill -9` arrive. At the front a white-hot
// band of hex cells; behind it the metal cooling through the forge's heat to its own colour (base) and glow (glow).
// `to_rifle` takes a point into the rifle's own space (its barrel along -Z), so every part prints along one axis.
render_mode cull_back, specular_schlick_ggx;

uniform mat4 to_rifle;
uniform float front = 1.0;
uniform vec3 base : source_color = vec3(0.047, 0.063, 0.078);
uniform vec3 glow : source_color = vec3(0.0);
uniform vec3 hot : source_color = vec3(1.0, 0.95, 0.85);
uniform vec3 heat_color : source_color = vec3(0.098, 0.827, 0.773);
uniform float metal = 0.75;

varying vec3 at;

void vertex() {
	at = (to_rifle * MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// 1 on a hex cell's edge, 0 inside it.
float hex_edge(vec2 p) {
	vec2 q = vec2(p.x * 1.1547, p.y + p.x * 0.57735);
	vec2 f = fract(q);
	float d = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	return 1.0 - smoothstep(0.03, 0.09, d);
}

void fragment() {
	float d = at.z - front;
	if (d < 0.0) {
		discard;
	}
	float band = exp(-d / 0.012);
	float heat = exp(-d / 0.07);
	float cells = hex_edge(at.xy * 110.0 + vec2(at.z * 40.0, 0.0));
	ALBEDO = base * (1.0 - 0.7 * heat);
	METALLIC = metal;
	ROUGHNESS = 0.35;
	EMISSION = glow + hot * band * 5.0 + mix(heat_color, hot, band) * heat * (0.6 + 2.0 * cells);
}
