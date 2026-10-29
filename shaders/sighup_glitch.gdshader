// SIGHUP on a confused player's screen (C32, scripts/hud/sighup_hud.gd): the HUD's glass glitching as a line
// drops: thin rows of carrier-green static tearing across it now and then, scanlines rolling at its edges,
// a faint grain over it all. Drawn over the HUD at a low alpha, never a flash of the whole screen: the
// arena stays readable through it. `strength` 0 (none) to 1 (just caught), `clock` the HUD's seconds.
shader_type canvas_item;

uniform vec4 color : source_color = vec4(0.0, 0.749, 0.0, 1.0);
uniform float strength = 0.0;
uniform float clock = 0.0;
uniform float rows = 48.0;
uniform float tear_share = 0.07;
uniform float alpha_most = 0.55;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float tick = floor(clock * 10.0);
	float row = floor(uv.y * rows);
	float tear = step(1.0 - tear_share, hash(vec2(row, tick)));
	float grain = hash(floor(uv * vec2(320.0, 180.0)) + vec2(tick, tick * 0.5));
	float scan = 0.5 + 0.5 * sin(uv.y * 540.0 - clock * 40.0);
	vec2 c = uv - 0.5;
	float edge = smoothstep(0.34, 0.75, length(c * vec2(1.25, 1.0)));
	float a = strength * (tear * (0.25 + 0.35 * grain) + edge * (0.12 + 0.3 * scan) + grain * 0.04);
	COLOR = vec4(color.rgb * (0.55 + 0.9 * grain), clamp(a, 0.0, alpha_most));
}
