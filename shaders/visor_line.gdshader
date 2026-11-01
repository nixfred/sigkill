// SIGKILL Audit Trail visor (C43; the visor's design is Albert's, @QuantaCortex): one lineage line, a child process to
// its parent, drawn from a strip of SEGMENTS (scripts/visor/visor_lines.gd). Each instance carries its line in its
// transform, read here, not used as a transform: the origin is the child's point, the first column the parent's, the
// second (heat, half width, grown), the third (phase, burn, brightness); its custom data (depth share, lift). The strip bends over a
// bezier arc between them and turns its face to the camera. Light runs along it toward the root in packets, faster and
// whiter the hotter the child (its CPU); a fork grows in from the parent with a bright front; a sever burns it from the
// parent down to the child like a fuse, the burnt length sagging and falling as embers. The colour is the register's:
// amber over Tron's teal, ice white over the rain's violet, hot pink over the Matrix's green (ruins_weights, so the
// finale's mix of the three colours each line by where it stands). Added light, never in a shadow, the fog off, dimmed
// by Black ICE's dark with the rest.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled, skip_vertex_transform;

#include "res://shaders/ruins_common.gdshaderinc"

uniform vec3 hue_tron : source_color = vec3(1.0, 0.5, 0.1);
uniform vec3 hue_cyber : source_color = vec3(0.55, 0.95, 1.0);
uniform vec3 hue_matrix : source_color = vec3(1.0, 0.32, 0.72);
uniform float energy = 3.0;
// Metres between the packets running toward the root.
uniform float packet_m = 2.6;
// How far a line is still drawn, metres: it fades out from the first to the second.
uniform vec2 fade_m = vec2(70.0, 130.0);

varying vec3 v_world;
varying float v_t;
varying float v_side;
varying float v_len;
varying vec4 v_a;
varying vec4 v_b;

void vertex() {
	vec3 a = MODEL_MATRIX[3].xyz;
	vec3 b = MODEL_MATRIX[0].xyz;
	vec4 c1 = vec4(MODEL_MATRIX[1].xyz, INSTANCE_CUSTOM.y);
	vec4 c2 = vec4(MODEL_MATRIX[2].xyz, INSTANCE_CUSTOM.x);
	float t = VERTEX.x;
	float side = VERTEX.y;
	float len = max(distance(a, b), 0.001);
	vec3 c = (a + b) * 0.5 + vec3(0.0, c1.w + 0.35 + len * 0.14, 0.0);
	float u = 1.0 - t;
	vec3 p = u * u * a + 2.0 * u * t * c + t * t * b;
	vec3 tangent = 2.0 * u * (c - a) + 2.0 * t * (b - c);
	tangent = length(tangent) > 0.0001 ? normalize(tangent) : vec3(0.0, 1.0, 0.0);
	float burn = c2.y;
	if (burn > 0.0) {
		float head = 1.0 - clamp(burn, 0.0, 1.0);
		if (t > head) {
			float age = (t - head) * 0.9 + max(burn - 1.0, 0.0) * 1.2;
			p.y -= 3.2 * age * age;
		}
	}
	vec3 to_cam = CAMERA_POSITION_WORLD - p;
	vec3 across = cross(tangent, to_cam);
	across = length(across) > 0.0001 ? normalize(across) : vec3(1.0, 0.0, 0.0);
	// A touch wider far off, so a line never thins to nothing on the screen; never wider than a sliver of the view up
	// close, so a line passing the camera never smears across it.
	float half_w = min(c1.y * (1.0 + clamp(length(to_cam) / 40.0, 0.0, 1.5)), length(to_cam) * 0.0045);
	p += across * side * half_w;
	v_world = p;
	v_t = t;
	v_side = side;
	v_len = len;
	v_a = c1;
	v_b = c2;
	VERTEX = (VIEW_MATRIX * vec4(p, 1.0)).xyz;
}

void fragment() {
	float heat = clamp(v_a.x, 0.0, 1.0);
	float grown = v_a.z;
	float phase = v_b.x;
	float burn = v_b.y;
	float bright = v_b.z;
	float depth_share = v_b.w;
	if (v_t < 1.0 - grown) {
		discard;
	}
	vec3 w = ruins_weights(v_world);
	vec3 hue = hue_tron * w.x + hue_cyber * w.y + hue_matrix * w.z;
	float core = 1.0 - abs(v_side);
	float body = core * core;
	float spine = pow(core, 9.0);
	// Packets toward the root (t rises toward the parent).
	float s = v_t * v_len;
	float flow = fract(s / packet_m - TIME * (0.8 + 2.2 * heat) + phase);
	float packet = smoothstep(0.78, 0.96, flow) * (1.0 - smoothstep(0.96, 1.0, flow));
	vec3 white = vec3(1.0, 0.97, 0.92);
	// Nearer the root, the trunk: a little brighter.
	float trunk = 0.75 + 0.35 * (1.0 - depth_share);
	vec3 col = mix(hue, white, 0.18 + 0.3 * heat) * (0.5 * body + 1.1 * spine) * trunk;
	col += white * packet * (0.7 + 1.1 * heat) * body;
	// A fork's front, growing in.
	if (grown < 1.0) {
		float d = (v_t - (1.0 - grown)) * v_len;
		col += white * exp(-d * d * 6.0) * 3.0 * body;
	}
	if (burn > 0.0) {
		float head = 1.0 - clamp(burn, 0.0, 1.0);
		if (v_t > head) {
			float age = (v_t - head) * 0.8 + max(burn - 1.0, 0.0) * 1.4;
			float flicker = 0.6 + 0.4 * sin(TIME * 47.0 + v_t * 90.0 + phase * 31.0);
			vec3 ember = mix(vec3(1.0, 0.42, 0.1), vec3(0.45, 0.04, 0.01), clamp(age * 1.6, 0.0, 1.0));
			col = ember * body * max(0.0, 1.0 - age * 1.25) * flicker * 1.4;
		}
		if (burn <= 1.0) {
			float d = (v_t - head) * v_len;
			col += vec3(1.0, 0.88, 0.62) * exp(-d * d * 3.0) * 4.0 * body;
		}
	}
	float ends = smoothstep(0.0, 0.025, v_t) * (1.0 - smoothstep(0.975, 1.0, v_t));
	float seen = distance(v_world, CAMERA_POSITION_WORLD);
	float far = (1.0 - smoothstep(fade_m.x, fade_m.y, seen)) * smoothstep(1.0, 4.5, seen);
	ALBEDO = col * energy * bright * ends * far * mix(0.45, 1.0, arena_light);
}
