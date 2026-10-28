shader_type canvas_item;
// SIGKILL's colorblind-safe palette (C16b), drawn over the whole screen when the setting is
// on: the hues that tell sides apart move to the Okabe-Ito pair, which stays apart for the
// common kinds of colour blindness. Hostile red goes to vermillion, hostile amber to yellow,
// and the player side's teal and mint (and the code rain's green) to sky blue. Violet, white
// and black stay. Brightness and saturation are kept, so the glow reads the same.
// scripts/hud.gd sets it up; scripts/palette.gd stays the one source of the game's colours.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
// The target hue of each band, in degrees, and each band's centre and reach.
uniform float red_from = 350.0;
uniform float red_to = 26.0;
uniform float red_reach = 40.0;
uniform float amber_from = 42.0;
uniform float amber_to = 54.0;
uniform float amber_reach = 18.0;
uniform float green_from = 155.0;
uniform float green_to = 202.0;
uniform float green_reach = 50.0;

vec3 rgb_to_hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
	vec4 k = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + k.xyz) * 6.0 - k.www);
	return c.z * mix(k.xxx, clamp(p - k.xxx, 0.0, 1.0), c.y);
}

// Signed shortest turn from a to b, in degrees.
float turn(float a, float b) {
	return mod(b - a + 540.0, 360.0) - 180.0;
}

// How far into a band hue h sits: 1 at its centre, 0 past its reach.
float weight(float h, float centre, float reach) {
	return 1.0 - smoothstep(reach * 0.5, reach, abs(turn(centre, h)));
}

void fragment() {
	vec3 c = texture(screen_texture, SCREEN_UV).rgb;
	vec3 hsv = rgb_to_hsv(c);
	float h = hsv.x * 360.0;
	float wr = weight(h, red_from, red_reach);
	float wa = weight(h, amber_from, amber_reach);
	float wg = weight(h, green_from, green_reach);
	float shift = 0.0;
	if (wr >= wa && wr >= wg) {
		shift = wr * turn(h, red_to);
	} else if (wa >= wg) {
		shift = wa * turn(h, amber_to);
	} else {
		shift = wg * turn(h, green_to);
	}
	hsv.x = mod(h + shift, 360.0) / 360.0;
	COLOR = vec4(hsv_to_rgb(hsv), 1.0);
}
