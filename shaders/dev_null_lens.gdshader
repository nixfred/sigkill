// /dev/null's event horizon and lensing (C31): a camera-facing disc at the hole's core. Inside the shadow
// it is black, light falling into nothing; round it the photon ring, a thin white-hot line, and the
// halo (the far side of the accretion ring bent over the top and under the bottom, as a hole's gravity
// bends light), and out to the disc's edge the arena behind it, bent: each point shows what lies in the
// direction a point lens would bend it from (an Einstein ring at einstein, the image turned inside out
// within it), easing back to the plain view at the edge. The screen behind it is the opaque pass only.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
// The shadow's radius, the Einstein ring's and the halo's, each a share of the disc's half-size.
uniform float shadow = 0.2;
uniform float einstein = 0.3;
uniform float halo = 0.34;
uniform vec4 ring_color : source_color = vec4(1.0, 0.85, 0.96, 1.0);
uniform vec4 halo_color : source_color = vec4(0.67, 0.22, 0.61, 1.0);
uniform float energy = 4.0;
// 0 to 1: how far the hole has opened (or collapsed); flow: seconds since it opened.
uniform float size_now = 1.0;
uniform float flow = 0.0;

float noise1(float x) {
	float i = floor(x);
	float f = fract(x);
	float a = fract(sin(i * 127.1) * 43758.5453);
	float b = fract(sin((i + 1.0) * 127.1) * 43758.5453);
	return mix(a, b, f * f * (3.0 - 2.0 * f));
}

void vertex() {
	// Faces the camera, keeping its place and its scale.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz), INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	vec2 dir = r > 0.0001 ? p / r : vec2(0.0, 1.0);
	float s = shadow * size_now;
	float e = max(einstein * size_now, s + 0.001);
	// The bend: the source a point lens shows here, eased back to the plain view at the disc's edge.
	float beta = r - e * e / max(r, 0.0001);
	float bent = mix(beta, r, smoothstep(0.55, 1.0, r));
	vec2 uv_per_px = vec2(dFdx(UV.x), dFdy(UV.y));
	vec2 px = (dir * (bent - r) * 0.5) / max(abs(uv_per_px), vec2(1e-6)) * sign(uv_per_px);
	vec2 at = SCREEN_UV + px / VIEWPORT_SIZE;
	vec3 seen = textureLod(screen_texture, clamp(at, vec2(0.001), vec2(0.999)), 0.0).rgb;
	// Light near the ring is drawn out and dimmed a little, as light skimming the hole is.
	seen *= mix(0.55, 1.0, smoothstep(s, e * 1.6, r));
	float angle = atan(p.y, p.x);
	float ring = exp(-pow((r - s * 1.06) / (0.012 + 0.01 * size_now), 2.0));
	float swirl = noise1(angle * 3.0 + flow * 2.4) * 0.6 + noise1(angle * 9.0 - flow * 5.0) * 0.4;
	float halo_band = exp(-pow((r - halo * size_now) / (0.035 * size_now + 0.004), 2.0)) * (0.45 + 0.75 * swirl);
	vec3 color = seen + ring_color.rgb * ring * energy * 1.4 + halo_color.rgb * halo_band * energy;
	// The shadow: nothing comes back from it.
	float black = 1.0 - smoothstep(s * 0.96, s * 1.02, r);
	color = mix(color, vec3(0.0), black);
	ALBEDO = color;
	ALPHA = (1.0 - smoothstep(0.9, 1.0, r)) * clamp(size_now * 4.0, 0.0, 1.0);
}
