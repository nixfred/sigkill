// /dev/null's accretion ring (C31): a flat ring of matter round the core, swirling in. Its inner edge
// white-hot, then the hole's plum, cooling and thinning to nothing at its outer edge; turbulent streams
// winding in on log spirals, faster near the core; the side whose matter swings toward the camera
// brighter (beaming). Additive: light, nothing solid. The plane's UV spans the ring's outer edge.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 hot_color : source_color = vec4(1.0, 0.85, 0.96, 1.0);
uniform vec4 body_color : source_color = vec4(0.67, 0.22, 0.61, 1.0);
// The ring's inner edge as a share of its outer radius.
uniform float inner = 0.3;
uniform float energy = 3.0;
uniform float size_now = 1.0;
uniform float flow = 0.0;
// How hard its streams wind and how many arms.
uniform float twist = 2.6;
uniform float arms = 3.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float lo = inner;
	if (r > 1.0 || r < lo * 0.92) {
		discard;
	}
	float angle = atan(p.y, p.x);
	// Orbit faster inside (Kepler-ish), streams on log spirals.
	float spin = flow * 1.6 / pow(max(r, 0.05), 1.5);
	float a = angle + spin + log(max(r, 0.01)) * twist;
	float streams = 0.55 + 0.45 * sin(a * arms);
	float grain = vnoise(vec2(a * 4.0, r * 18.0 - flow * 3.0)) * 0.6 + vnoise(vec2(a * 11.0, r * 40.0)) * 0.4;
	float t = clamp((r - lo) / (1.0 - lo), 0.0, 1.0);
	vec3 color = mix(hot_color.rgb, body_color.rgb, smoothstep(0.0, 0.35, t));
	color = mix(color, body_color.rgb * 0.35, smoothstep(0.55, 1.0, t));
	float edge_in = smoothstep(lo * 0.92, lo * 1.02, r);
	float edge_out = 1.0 - smoothstep(0.6, 1.0, r);
	// Beaming: matter swinging toward the camera shines brighter.
	vec3 cam = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	vec3 tangent = normalize(vec3(-sin(angle), 0.0, cos(angle)));
	float toward = dot(tangent, normalize(cam - local_pos));
	float beam = 1.0 + 0.55 * toward;
	float glow = edge_in * edge_out * mix(0.35, 1.0, streams) * mix(0.6, 1.2, grain) * beam * (1.6 - t);
	ALBEDO = color * glow * energy * size_now;
}
