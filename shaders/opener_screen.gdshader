shader_type canvas_item;
// The opener's fake terminal as a screen (C38): a soft glow round its bright text (only what is brighter than the
// threshold blooms, so the background stays its own colour and the text stays sharp under it), faint scanlines, a
// soft vignette, and, for one moment at a time, a band of rows torn sideways (the illusion cracking: C38's last
// beat, C40's way out). Drawn over the terminal by scripts/opener/opener.gd, with strengths from
// resources/opener.tres; the glow is off on a light theme, where everything would bloom. Nothing warps or strobes.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
// How much of the halo is added, its reach in pixels at 1080 lines, and the brightness it starts at.
uniform float glow = 0.0;
uniform float glow_px = 3.0;
uniform float glow_from = 0.3;
// How dark a scanline gets (0 none) and its period in pixels at 1080 lines.
uniform float scanline_dark = 0.0;
uniform float scanline_px = 3.0;
// The corners' darkening.
uniform float vignette = 0.0;
// A band of rows shifted sideways by `tear` (a share of the width; 0 none), at height tear_y, tear_h tall.
uniform float tear = 0.0;
uniform float tear_y = 0.5;
uniform float tear_h = 0.03;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	float k = res.y / 1080.0;
	if (tear != 0.0 && abs(uv.y - tear_y) < tear_h) {
		uv.x += tear;
	}
	vec3 rgb = texture(screen_texture, uv).rgb;
	if (glow > 0.0) {
		vec2 d = glow_px * k * SCREEN_PIXEL_SIZE;
		vec3 halo = vec3(0.0);
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.785398;
			vec2 o = vec2(cos(a), sin(a));
			halo += max(texture(screen_texture, uv + o * d).rgb - glow_from, 0.0);
			halo += max(texture(screen_texture, uv + o * d * 2.2).rgb - glow_from, 0.0) * 0.5;
		}
		rgb += halo / 12.0 * glow;
	}
	if (scanline_dark > 0.0) {
		rgb *= 1.0 - scanline_dark * (0.5 + 0.5 * cos(FRAGCOORD.y / max(scanline_px * k, 1.0) * TAU));
	}
	vec2 from_mid = SCREEN_UV - 0.5;
	float edge = dot(from_mid, from_mid) * 2.0;
	rgb *= 1.0 - vignette * edge * edge;
	COLOR = vec4(rgb, 1.0);
}
