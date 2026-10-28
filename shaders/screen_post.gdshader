shader_type canvas_item;
// SIGKILL's screen post effects (A4), drawn over the 3D view and under the HUD while either
// setting is on: chromatic aberration (red and blue pulled apart toward the screen's edges,
// nothing at its middle, so the crosshair's point stays true) and CRT scanlines (dark lines
// every few pixels, a faint aperture grille and a soft vignette). No warp or curve of the
// picture, so what is under the crosshair is what a shot hits. scripts/fx/screen_post.gd sets
// it up; the strengths come from scripts/palette.gd.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
// How far red and blue move at the screen's corners, in pixels at 1080 lines; 0 is off.
uniform float aberration_px = 0.0;
// How dark a scanline gets (0 none), its period in pixels at 1080 lines, the grille's share,
// and the vignette's darkening at the corners.
uniform float scanline_dark = 0.0;
uniform float scanline_px = 3.0;
uniform float grille = 0.0;
uniform float vignette = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	// Scale pixel lengths to this window's height, so the look holds at any resolution.
	float k = res.y / 1080.0;
	vec2 from_mid = uv - 0.5;
	vec3 rgb;
	if (aberration_px > 0.0) {
		// In units of the screen's height, so the pull is round; it grows with the square of the
		// distance from the middle: none at the crosshair, aberration_px at a 16:9 corner.
		vec2 d = from_mid * vec2(res.x / res.y, 1.0);
		vec2 shift = d * dot(d, d) * aberration_px * k * SCREEN_PIXEL_SIZE;
		rgb.r = texture(screen_texture, uv + shift).r;
		rgb.g = texture(screen_texture, uv).g;
		rgb.b = texture(screen_texture, uv - shift).b;
	} else {
		rgb = texture(screen_texture, uv).rgb;
	}
	if (scanline_dark > 0.0) {
		float line = 0.5 + 0.5 * cos(FRAGCOORD.y / max(scanline_px * k, 1.0) * TAU);
		rgb *= 1.0 - scanline_dark * line;
		// A faint aperture grille: the three stripes of a CRT's phosphor mask.
		int stripe = int(mod(floor(FRAGCOORD.x / max(k, 1.0)), 3.0));
		vec3 mask = vec3(stripe == 0 ? 1.0 : 1.0 - grille, stripe == 1 ? 1.0 : 1.0 - grille, stripe == 2 ? 1.0 : 1.0 - grille);
		rgb *= mask * (1.0 + grille * 0.5);
		float edge = dot(from_mid, from_mid) * 2.0;
		rgb *= 1.0 - vignette * edge * edge;
	}
	COLOR = vec4(rgb, 1.0);
}
