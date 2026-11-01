// SIGKILL Audit Trail visor (C43): a process's mark in the tree, a hexagon facing the camera (scripts/visor/
// visor_lines.gd). The instance's transform carries it, read here: the origin is its place, the first column (size,
// kind, flash), the second its colour, the third (alpha). Kinds: 0 init, a double ring round a white-hot core; 1 the hidden
// parent, a black plate with a bright rim and a redaction bar across it (only root may read it); 2 a job, one ring;
// 3 a daemon's socket, a small ring where its line leaves it; 4 a burst, a ring flung out (a sever, an adoption).
// Drawn over the world's colour (mix), never in a shadow, the fog off.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled, skip_vertex_transform;

#include "res://shaders/ruins_common.gdshaderinc"

varying vec2 v_uv;
varying vec4 v_a;
varying vec3 v_col;

float hex(vec2 p, float r) {
	const vec3 k = vec3(-0.866025404, 0.5, 0.577350269);
	p = abs(p);
	p -= 2.0 * min(dot(k.xy, p), 0.0) * k.xy;
	p -= vec2(clamp(p.x, -k.z * r, k.z * r), r);
	return length(p) * sign(p.y);
}

void vertex() {
	vec3 at = MODEL_MATRIX[3].xyz;
	v_a = vec4(MODEL_MATRIX[0].xyz, MODEL_MATRIX[2].x);
	v_col = MODEL_MATRIX[1].xyz;
	// Never more than a slice of the view up close.
	float size = min(v_a.x, distance(at, CAMERA_POSITION_WORLD) * 0.1);
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	vec3 p = at + (right * VERTEX.x + up * VERTEX.y) * size;
	v_uv = VERTEX.xy * 2.0;
	VERTEX = (VIEW_MATRIX * vec4(p, 1.0)).xyz;
}

void fragment() {
	float kind = v_a.y;
	float flash = v_a.z;
	vec2 p = v_uv;
	float aa = fwidth(p.y) * 1.5;
	vec3 col = vec3(0.0);
	float alpha = 0.0;
	vec3 white = vec3(1.0, 0.97, 0.92);
	float spin = TIME * 0.6;
	mat2 turn = mat2(vec2(cos(spin), sin(spin)), vec2(-sin(spin), cos(spin)));
	if (kind < 0.5) {
		float d1 = abs(hex(p, 0.82)) - 0.05;
		float d2 = abs(hex(turn * p, 0.58)) - 0.035;
		float dot_d = length(p) - 0.2;
		float ring = 1.0 - smoothstep(-aa, aa, min(d1, d2));
		float core = 1.0 - smoothstep(-aa, aa, dot_d);
		float halo = exp(-length(p) * 3.0) * 0.6;
		col = (v_col * ring + white * core) * 3.0 + v_col * halo;
		alpha = max(max(ring, core), halo);
	} else if (kind < 1.5) {
		float plate = 1.0 - smoothstep(-aa, aa, hex(p, 0.8));
		float rim = 1.0 - smoothstep(-aa, aa, abs(hex(p, 0.8)) - 0.045);
		float bar = (1.0 - smoothstep(-aa, aa, abs(p.y) - 0.13)) * (1.0 - smoothstep(-aa, aa, abs(p.x) - 0.52));
		float bar_rim = (1.0 - smoothstep(-aa, aa, abs(abs(p.y) - 0.13) - 0.02)) * (1.0 - smoothstep(-aa, aa, abs(p.x) - 0.52));
		float halo = exp(-max(hex(p, 0.8), 0.0) * 6.0) * (1.0 - plate) * 0.5;
		col = vec3(0.0) * plate + v_col * rim * 3.2 + white * bar_rim * 1.6 + v_col * halo;
		col = mix(col, vec3(0.0), bar * (1.0 - bar_rim));
		alpha = max(max(plate * 0.92, rim), halo);
	} else if (kind < 2.5) {
		float ring = 1.0 - smoothstep(-aa, aa, abs(hex(turn * p, 0.72)) - 0.06);
		float inner = 1.0 - smoothstep(-aa, aa, hex(p, 0.22));
		col = v_col * ring * 2.6 + white * inner * 1.6;
		alpha = max(ring, inner * 0.9);
	} else if (kind < 3.5) {
		float ring = 1.0 - smoothstep(-aa, aa, abs(hex(p, 0.7)) - 0.09);
		col = mix(v_col, white, 0.3) * ring * 2.4;
		alpha = ring;
	} else {
		float r = 0.35 + 0.6 * flash;
		float ring = 1.0 - smoothstep(-aa * 2.0, aa * 2.0, abs(hex(p, r)) - 0.05 * (1.0 - flash) - 0.01);
		col = mix(white, v_col, flash) * ring * 3.5;
		alpha = ring * (1.0 - flash);
	}
	col += white * flash * 1.5 * alpha * step(kind, 3.5);
	ALBEDO = col * mix(0.45, 1.0, arena_light);
	ALPHA = clamp(alpha * v_a.w, 0.0, 1.0);
}
