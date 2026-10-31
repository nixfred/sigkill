// SIGKILL ruins haze (C36): smoke, steam and data fog drifting through the ruins and the void round them, on flat
// cards (scripts/ruins/ruins_world.gd lays them out). Each card is a soft drift of noise, rolling slowly, its edges
// fading out, faded where it meets the level so it never shows a line, tinted by the register. The vertex colour: r
// the card's own phase; g how much it rises (steam); b its slot (0 haze, 1 steam). UV: its place on the card.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://shaders/ruins_common.gdshaderinc"

uniform sampler2D depth_texture : hint_depth_texture, filter_linear;
uniform vec4 haze_tron : source_color = vec4(0.06, 0.4, 0.4, 1.0);
uniform vec4 haze_cyber : source_color = vec4(0.42, 0.16, 0.6, 1.0);
uniform vec4 haze_matrix : source_color = vec4(0.0, 0.42, 0.1, 1.0);
uniform vec3 haze_energy = vec3(0.10, 0.22, 0.14);
uniform vec4 steam_color : source_color = vec4(0.55, 0.6, 0.7, 1.0);
uniform float fade_m = 3.0;

varying vec3 world_pos;
varying vec4 paint;

void vertex() {
	paint = COLOR;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 w3 = ruins_weights(world_pos);
	float t = arena_clock;
	vec2 uv = UV;
	float rise = paint.g;
	vec2 drift = vec2(t * 0.012 + paint.r * 9.0, -t * (0.02 + rise * 0.18));
	float n = ruins_fbm(uv * vec2(3.0, 2.0) + drift);
	n = smoothstep(0.35, 0.85, n);
	vec2 c = uv * 2.0 - 1.0;
	float edge = clamp(1.0 - dot(c * vec2(1.0, 0.8), c * vec2(1.0, 0.8)), 0.0, 1.0);
	if (paint.b > 0.5) {
		edge *= smoothstep(1.0, 0.2, uv.y) * smoothstep(0.0, 0.3, uv.y);
	}
	float depth = texture(depth_texture, SCREEN_UV).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	float scene_z = -view.z / view.w;
	float near = clamp((scene_z - (-VERTEX.z)) / fade_m, 0.0, 1.0);
	float camera_fade = smoothstep(1.0, 6.0, -VERTEX.z);
	vec3 col = paint.b > 0.5 ? steam_color.rgb * (0.18 + 0.1 * w3.y) : (haze_tron.rgb * (w3.x * haze_energy.x) + haze_cyber.rgb * (w3.y * haze_energy.y) + haze_matrix.rgb * (w3.z * haze_energy.z));
	ALBEDO = col * n * edge * near * camera_fade * arena_light;
}
