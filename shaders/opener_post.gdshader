shader_type canvas_item;
// The machine's picture as the opener shows it from C42's forge on (scripts/opener/opener.gd): a punch of chromatic
// split, a shake and torn bands when the rifle locks in and when it fires, and the shot's flash (the brightness model's,
// luma_at(): white added over the picture). All zero is the picture as it is.

uniform float flash = 0.0;
uniform float split = 0.0;
uniform vec2 shake = vec2(0.0);
uniform float tear = 0.0;
uniform float seed = 0.0;

void fragment() {
	vec2 uv = UV + shake;
	float row = floor(uv.y * 28.0);
	float pick = fract(sin(row * 12.9898 + seed * 78.233) * 43758.5453);
	uv.x += (pick > 0.78 ? (pick - 0.89) * 2.0 : 0.0) * tear;
	vec3 c;
	c.r = texture(TEXTURE, uv + vec2(split, 0.0)).r;
	c.g = texture(TEXTURE, uv).g;
	c.b = texture(TEXTURE, uv - vec2(split, 0.0)).b;
	COLOR = vec4(mix(c, vec3(1.0), clamp(flash, 0.0, 1.0)), 1.0);
}
