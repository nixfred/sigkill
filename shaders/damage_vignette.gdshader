shader_type canvas_item;
// The hit vignette (C27b): hostile red pressing in from the screen's edges when this player is
// hit, its middle always clear. Colour only: it never samples or moves the picture, so nothing
// warps and the crosshair's point stays true.

uniform vec4 color : source_color = vec4(1.0, 0.2, 0.333, 1.0);
// 0 none, 1 the strongest.
uniform float strength = 0.0;

void fragment() {
	vec2 d = (UV - vec2(0.5)) * vec2(1.0, 0.82);
	float edge = smoothstep(0.28, 0.72, length(d));
	COLOR = vec4(color.rgb, color.a * edge * edge * clamp(strength, 0.0, 1.0));
}
