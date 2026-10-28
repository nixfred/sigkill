shader_type canvas_item;
// SIGSTOP bullet time (C18): the slow-mo look, drawn over the 3D world and under the HUD, on
// this player's own screen only. Motion trails smear the picture toward the middle, fading
// copy by copy, then it goes grey and shifts toward the theme's teal. scripts/abilities/
// sigstop.gd sets every value at run time from resources/sigstop.tres and scripts/palette.gd;
// the defaults here only preview. At strength 0 the picture is untouched.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float desaturate : hint_range(0.0, 1.0) = 0.7;
uniform float tint : hint_range(0.0, 1.0) = 0.3;
uniform float trail : hint_range(0.0, 0.2) = 0.04;
uniform vec4 theme_color : source_color = vec4(0.098, 0.827, 0.773, 1.0);

const int TAPS = 6;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 sum = texture(screen_texture, uv).rgb;
	float weight = 1.0;
	for (int i = 1; i <= TAPS; i++) {
		float k = float(i) / float(TAPS);
		vec2 at = mix(uv, vec2(0.5), trail * strength * k);
		float w = 1.0 - 0.8 * k;
		sum += texture(screen_texture, at).rgb * w;
		weight += w;
	}
	vec3 picture = sum / weight;
	float grey = dot(picture, vec3(0.299, 0.587, 0.114));
	vec3 washed = mix(picture, vec3(grey), desaturate * strength);
	vec3 shifted = mix(washed, grey * theme_color.rgb * 1.5, tint * strength);
	COLOR = vec4(shifted, 1.0);
}
