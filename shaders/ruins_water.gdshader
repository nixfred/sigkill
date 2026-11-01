// SIGKILL ruins water (M6): the drowned plain under the deepest ruins (RuinsSet.water), one plane as wide as the void.
// Black water, a slow swell, rain rings, and the district's lamps held in it as streaks of their own colour running
// toward whoever looks (the brightest WATER_LAMPS lamps, pushed by scripts/ruins/ruins_world.gd with the camera read
// here), broken up by the ripples; a cold rim where it is seen at a glance. Black ICE dims it with the rest
// (arena_light). Nothing here reads anything: a colour, a clock and the lamps.
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

#include "res://shaders/ruins_common.gdshaderinc"

uniform vec4 deep_color : source_color = vec4(0.004, 0.012, 0.045, 1.0);
uniform vec4 rim_color : source_color = vec4(0.45, 0.4, 1.0, 1.0);
// Its own light (M7, the core's sea of heat): black for water that only holds the lamps.
uniform vec4 glow_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
const int MAX_LAMPS = 16;
// xyz a lamp's place (world), w its energy; its colour.
uniform vec4 lamps[MAX_LAMPS];
uniform vec4 lamp_colors[MAX_LAMPS];
uniform int lamp_count = 0;
uniform float streak_gain = 0.18;

varying vec3 world_pos;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float swell = sin(w.x * 0.21 + arena_clock * 0.7) * cos(w.z * 0.17 + arena_clock * 0.5) * 0.12;
	VERTEX.y += swell;
	world_pos = w + vec3(0.0, swell, 0.0);
}

void fragment() {
	vec2 p = world_pos.xz;
	float ripple = ruins_noise(p * 0.35 + vec2(arena_clock * 0.25, 0.0)) * 0.6 + ruins_noise(p * 0.9 - vec2(0.0, arena_clock * 0.4)) * 0.4;
	// Rain rings, as the floor's puddles have them.
	ivec2 dc = ivec2(floor(p / 1.1));
	vec2 dp = fract(p / 1.1) - 0.5;
	float age = fract(arena_clock * 0.8 + ruins_hash(dc.x, dc.y, 41));
	float ring = ruins_line(abs(length(dp) - age * 0.45), 0.02) * (1.0 - age) * step(0.55, ruins_hash(dc.x, dc.y, 42));
	vec3 glow = vec3(0.0);
	vec2 cam = CAMERA_POSITION_WORLD.xz;
	for (int i = 0; i < MAX_LAMPS; i++) {
		if (i >= lamp_count) {
			break;
		}
		vec2 l = lamps[i].xz;
		float h = max(lamps[i].y - world_pos.y, 1.0);
		vec2 to_cam = cam - l;
		float far = max(length(to_cam), 0.001);
		vec2 axis = to_cam / far;
		vec2 rel = p - l;
		float along = dot(rel, axis);
		float perp = dot(rel, vec2(-axis.y, axis.x));
		// The streak runs from the lamp's foot toward whoever looks, brightest a little out from the foot and gone
		// before it reaches them; wider as it goes, broken by the ripples.
		float share = along / far;
		float width = 0.7 + 0.04 * max(along, 0.0);
		float streak = exp(-perp * perp / (2.0 * width * width)) * smoothstep(0.0, 0.12, share) * pow(clamp(1.0 - share, 0.0, 1.0), 1.6) * exp(-max(along, 0.0) / (h * 1.2 + 6.0));
		streak *= 0.5 + 0.5 * ruins_noise(vec2(along * 0.5, perp * 1.6) + vec2(arena_clock * 0.35, 0.0));
		glow += lamp_colors[i].rgb * streak * clamp(lamps[i].w / 7.0, 0.2, 1.4) * streak_gain;
	}
	glow = glow / (1.0 + 0.8 * (glow.r + glow.g + glow.b));  // many lamps never wash it out
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	glow += rim_color.rgb * (fres * (0.05 + 0.05 * ripple) + ring * 0.3);
	ALBEDO = deep_color.rgb * (0.8 + 0.4 * ripple);
	ROUGHNESS = 0.06;
	METALLIC = 0.3;
	SPECULAR = 0.9;
	EMISSION = (glow + glow_color.rgb * (0.7 + 0.3 * ripple + 0.25 * ring)) * arena_light;
}
