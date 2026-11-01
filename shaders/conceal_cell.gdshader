// SIGKILL's palette-only daemon (W3, scripts/daemons/conceal_daemon.gd): the character cells its body is made of, each
// a thin block showing one glyph in one of a terminal's colours, as a colour test prints them. Shown (reveal 1, in the
// palette it belongs to) each cell is lit: its glyph and a frame in its colour, over-bright so the glow pass blooms it.
// Concealed (reveal 0, ANSI's SGR 8: text drawn and hidden), each cell is only a ripple: the frame behind it bent
// through it, a faint rim catching the light, so the creature's shape can be seen moving if you look, and never lit.
// Between, each cell prints in (or wipes out) at its own moment, by its index.
//
// Per cell (a MultiMesh instance): COLOR its colour; INSTANCE_CUSTOM x its glyph, y its brightness, z its presence (0
// gone), w its place in the print order (0 to 1). Visual only.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_always;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float reveal : hint_range(0.0, 1.0) = 1.0;
uniform float clock = 0.0;
uniform float energy = 1.7;
// A hit's white flash, and the strike's red (its tell turns every cell to the hostile red: SGR 31).
uniform float flash = 0.0;
uniform float tell = 0.0;
uniform vec4 tell_color : source_color = vec4(1.0, 0.07, 0.19, 1.0);
// How far the concealed ripple bends what is behind it, in screen widths, and how bright its rim is.
uniform float bend = 0.02;
uniform float rim = 0.2;

varying vec3 local;
varying vec4 info;
varying vec3 tint;

void vertex() {
	local = VERTEX;
	info = INSTANCE_CUSTOM;
	tint = COLOR.rgb;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float shown = clamp((reveal - info.w * 0.8) / 0.2, 0.0, 1.0);
	if (info.z <= 0.01) {
		discard;
	}
	// The glyph on the cell's broad faces: a 3 by 5 grid of dots on or off by its glyph number, and a thin frame.
	vec2 uv = local.xy + 0.5;
	vec2 grid = floor(vec2(uv.x * 3.0, uv.y * 5.0));
	float dot_on = step(0.45, hash(grid + vec2(info.x * 37.0, floor(info.x * 11.0))));
	vec2 in_dot = fract(vec2(uv.x * 3.0, uv.y * 5.0));
	float dot_shape = step(0.18, in_dot.x) * step(in_dot.x, 0.82) * step(0.15, in_dot.y) * step(in_dot.y, 0.85);
	float frame = 1.0 - step(0.08, uv.x) * step(uv.x, 0.92) * step(0.06, uv.y) * step(uv.y, 0.94);
	float glyph = max(dot_on * dot_shape, frame * 0.85);
	vec3 lit = mix(tint, tell_color.rgb, tell) * (0.18 + glyph * energy * info.y) + vec3(flash * 2.0);
	// Concealed: the frame behind bent through the cell, a rim where it faces away.
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.5);
	vec2 wob = vec2(sin(clock * 3.1 + local.y * 9.0 + info.x * 6.0), cos(clock * 2.7 + local.x * 7.0 + info.w * 9.0));
	vec3 behind = texture(screen_texture, SCREEN_UV + wob * bend * (0.6 + fres)).rgb;
	vec3 hidden = behind * 1.06 + vec3(rim * fres) + vec3(glyph * 0.05);
	ALBEDO = vec3(0.0);
	EMISSION = vec3(0.0);
	vec3 col = mix(hidden, lit, shown);
	ALBEDO = col;
	ALPHA = mix(0.92 * info.z, info.z, shown);
}
