shader_type spatial;
// The opener's fake desktop as a screen in the machine (C40): the terminal (scripts/opener/fake_terminal.gd, with its
// own screen shader) drawn into a viewport of its own and shown here, on a panel on the home folder's monolith, as
// the camera pulls back from it (scripts/opener/tree_fall.gd). Unshaded and out of the fog, so the frame the camera
// starts on is the terminal exactly as it was on screen: the move is a camera's, never a fade. As the panel shrinks,
// more of the screen falls in a pixel than one sample can show (the screen has no mipmaps), so it averages its
// footprint (4 by 4 samples) and the text never sparkles. Round the screen, a thin bezel in the theme's accent.
render_mode unshaded, fog_disabled, specular_disabled, cull_back;

uniform sampler2D screen : source_color, filter_linear, repeat_disable;
// The screen's size in pixels, and its share of the panel each way (the rest is the bezel).
uniform vec2 screen_px = vec2(1920.0, 1080.0);
uniform vec2 inner = vec2(1.0, 1.0);
uniform vec3 bezel_color : source_color = vec3(0.478, 0.635, 0.969);
uniform float bezel_energy = 2.2;
// How bright the screen burns: 1 as it starts (exactly the terminal), more once it is a light in the dark.
uniform float bright = 1.0;

void fragment() {
	vec2 q = (UV - 0.5) / inner + 0.5;
	vec2 fw = fwidth(q);
	if (q.x < 0.0 || q.x > 1.0 || q.y < 0.0 || q.y > 1.0) {
		ALBEDO = bezel_color * bezel_energy;
	} else {
		vec2 texels = fw * screen_px;
		vec3 c = vec3(0.0);
		if (max(texels.x, texels.y) < 1.02) {
			// Pixel for texel, as the camera starts: the terminal exactly as it was.
			c = texelFetch(screen, clamp(ivec2(q * screen_px), ivec2(0), ivec2(screen_px) - 1), 0).rgb;
		} else if (max(texels.x, texels.y) < 1.5) {
			c = texture(screen, q).rgb;
		} else {
			for (int i = 0; i < 4; i++) {
				for (int j = 0; j < 4; j++) {
					c += texture(screen, q + (vec2(float(i), float(j)) - 1.5) * fw * 0.25).rgb;
				}
			}
			c /= 16.0;
		}
		ALBEDO = c * bright;
	}
}
