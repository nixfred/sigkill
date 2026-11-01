shader_type canvas_item;
// Keybind gunplay's workspace change (W4, scripts/keys/keybind_hud.gd): the new view slides in from the side as a tiling
// desktop's workspaces do. The picture is drawn shifted by what is left of the slide; the strip it leaves is the desktop's
// bare wallpaper (dark, a faint grid), with a lit seam at the new view's edge. Only while a slide runs.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
// 0 the new view all the way off to the right, 1 settled.
uniform float slide = 1.0;
uniform vec4 seam : source_color = vec4(0.72, 1.0, 0.18, 1.0);

void fragment() {
	float off = 1.0 - slide;
	vec2 uv = SCREEN_UV;
	float x = uv.x - off;
	if (x >= 0.0) {
		vec3 c = texture(screen_texture, vec2(x, uv.y)).rgb;
		float edge = 1.0 - smoothstep(0.0, 0.006, x);
		COLOR = vec4(mix(c, seam.rgb * 1.6, edge * off * 2.0), 1.0);
	} else {
		vec2 g = fract(uv * vec2(32.0, 18.0));
		float grid = step(g.x, 0.03) + step(g.y, 0.05);
		COLOR = vec4(vec3(0.015, 0.02, 0.025) + seam.rgb * 0.06 * grid, 1.0);
	}
}
