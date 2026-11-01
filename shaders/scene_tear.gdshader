shader_type canvas_item;
// The reload's tear (W3, scripts/fx/scene_tear.gd): the last frame of the old arena held over the reload, glitching
// while the next one builds behind it, then torn away in bands of uneven height, each sliding off its own side at its
// own moment, split red from blue as it goes, so the new arena shows through the gaps.

// 0 whole, 1 every band gone.
uniform float away = 0.0;
// 0 still, 1 glitching hard (while it holds).
uniform float jitter = 0.0;
uniform float seed = 0.0;
uniform float clock = 0.0;
const float BANDS = 22.0;

float hash(float n) {
	return fract(sin(n * 12.9898 + seed * 78.233) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float row = floor(uv.y * BANDS + hash(floor(uv.y * BANDS * 0.5)) * 0.9);
	float delay = hash(row) * 0.35;
	float q = clamp((away - delay) / 0.65, 0.0, 1.0);
	q = q * q;
	float dir = hash(row + 31.0) > 0.5 ? 1.0 : -1.0;
	float tick = floor(clock * 18.0);
	float shake = (hash(row + tick * 3.7) - 0.5) * 0.03 * jitter * step(0.7, hash(row * 1.3 + tick));
	vec2 at = vec2(uv.x - dir * q * 1.25 + shake, uv.y);
	if (at.x < 0.0 || at.x > 1.0) {
		discard;
	}
	float split = 0.004 * (jitter + 3.0 * q);
	vec4 c = texture(TEXTURE, at);
	c.r = texture(TEXTURE, at + vec2(split, 0.0)).r;
	c.b = texture(TEXTURE, at - vec2(split, 0.0)).b;
	// Scanlines and a darkening while it holds, so it reads as a frame frozen, not a game running.
	float line = 0.5 + 0.5 * cos(FRAGCOORD.y * 2.1);
	c.rgb *= 1.0 - 0.18 * jitter * line;
	c.rgb *= 1.0 - 0.25 * jitter;
	c.a = 1.0;
	COLOR = c;
}
