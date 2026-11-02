shader_type canvas_item;
// A split-screen co-op tile's view (W6, scripts/coop/coop_screen.gd): the tile's 3D picture as its SubViewport drew it,
// with the tile's own moments over it. `down` (0 to 1) is its player downed: the picture drained of colour toward a cold
// grey, a red pulse at its edges and a slow roll of scanlines; `flash` (0 to 1) is the tile just resized or flipped:
// a brief brighten in the player's own colour from the edges in; `hurt` (0 to 1) a hit's red flash at the edges. Made
// in code; nothing is sampled but the tile's own picture.

uniform float down : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float hurt : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.1, 0.83, 0.77, 1.0);
uniform float clock = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 d = UV - vec2(0.5);
	float edge = smoothstep(0.18, 0.72, length(d * vec2(1.0, 1.15)));
	// Downed: drained, cold, red at the edges, scanlines rolling.
	float grey = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 cold = vec3(grey * 0.78, grey * 0.84, grey * 0.95);
	c.rgb = mix(c.rgb, cold, down * 0.85);
	float pulse = 0.55 + 0.45 * sin(clock * 5.0);
	c.rgb = mix(c.rgb, vec3(1.0, 0.08, 0.16), down * edge * 0.55 * pulse);
	float scan = 0.5 + 0.5 * sin((UV.y * 220.0 - clock * 9.0));
	c.rgb *= 1.0 - down * 0.18 * scan;
	// A hit: a red flash at the edges.
	c.rgb = mix(c.rgb, vec3(1.0, 0.12, 0.2), hurt * edge * 0.6);
	// A resize or a flip: the player's colour washing in from the edges, bright.
	c.rgb += tint.rgb * flash * (0.12 + 0.5 * edge);
	COLOR = vec4(c.rgb, 1.0);
}
