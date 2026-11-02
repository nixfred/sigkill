shader_type canvas_item;
// The packet tracer's ride on the screen (W5, scripts/packets/packet_tracer_hud.gd): streaks of light racing out from the
// middle of the view while a packet carries the player (more, longer and faster in a burst), and while the link under
// the rider goes bad a vignette pulsing amber, red as it tears. Only drawn while there is something to draw.

uniform float amount = 0.0;
uniform float clock = 0.0;
uniform vec4 tint : source_color = vec4(0.45, 1.0, 0.9, 1.0);
uniform float danger = 0.0;
uniform vec4 danger_tint : source_color = vec4(1.0, 0.62, 0.12, 1.0);

float hash1(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void fragment() {
	vec2 aspect = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	vec2 p = (UV - 0.5) * aspect;
	float r = length(p);
	float a = atan(p.y, p.x) / 6.2831853 + 0.5;
	float lane = floor(a * 140.0);
	float pick = hash1(lane);
	float on = step(1.0 - (0.18 + 0.3 * amount), pick);
	float run = fract(r * (2.0 + 2.0 * pick) - clock * (2.2 + 3.0 * amount) - pick * 9.0);
	float streak = on * smoothstep(0.0, 0.08, run) * (1.0 - smoothstep(0.1, 0.45, run));
	float edge = smoothstep(0.16, 0.55, r);
	float thin = 1.0 - smoothstep(0.0, 0.35, abs(fract(a * 140.0) - 0.5) * 2.0 - 0.3);
	float s = streak * edge * thin * amount;
	float vig = smoothstep(0.35, 0.8, r) * danger * (0.55 + 0.45 * sin(clock * 18.0));
	vec3 col = mix(tint.rgb, danger_tint.rgb, clamp(vig * 2.0, 0.0, 1.0));
	COLOR = vec4(col * (1.0 + s), clamp(s * 0.6 + vig * 0.5, 0.0, 0.85));
}
