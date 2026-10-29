// /dev/null's debris (C31): streaks of light spiralling in from the hole's reach to its core, one per
// MultiMesh instance, each on its own path from its custom data (start radius, start angle, height,
// speed), endlessly: each falls in, winding faster as it nears the core, and starts again at the edge.
// Drawn as a thin streak along its way, facing the camera, plum at the edge and white-hot at the core.
// No CPU per frame: the paths are the shader's.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 hot_color : source_color = vec4(1.0, 0.85, 0.96, 1.0);
uniform vec4 body_color : source_color = vec4(0.67, 0.22, 0.61, 1.0);
uniform float reach = 9.0;
uniform float core_r = 0.5;
uniform float size_now = 1.0;
uniform float flow = 0.0;
uniform float energy = 4.0;
uniform float width = 0.035;

varying float heat;
varying float fade;

vec3 path(float s, vec4 c) {
	float r0 = mix(0.35, 1.0, c.r) * reach;
	float r = mix(r0, core_r, pow(s, 1.7));
	float turns = 1.2 + 2.2 * c.a;
	float angle = c.g * 6.2831853 + turns * 6.2831853 * pow(s, 2.2);
	float y = (c.b - 0.5) * 2.4 * (1.0 - s) * (1.0 - s);
	return vec3(cos(angle) * r, y, sin(angle) * r);
}

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	float rate = 0.18 + 0.32 * c.a;
	float s = fract(flow * rate + c.g * 7.13 + c.r * 3.1);
	vec3 p = path(s, c);
	vec3 q = path(min(s + 0.015, 1.0), c);
	vec3 way = q - p;
	way = length(way) > 0.0001 ? normalize(way) : vec3(0.0, 0.0, 1.0);
	vec3 cam = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	vec3 side = cross(way, cam - p);
	side = length(side) > 0.0001 ? normalize(side) : vec3(1.0, 0.0, 0.0);
	float len = (0.12 + 0.55 * s) * size_now;
	VERTEX = p * size_now + side * VERTEX.x * width + way * VERTEX.y * len;
	heat = s;
	fade = smoothstep(0.0, 0.12, s) * (1.0 - smoothstep(0.86, 1.0, s));
}

void fragment() {
	float across = 1.0 - abs(UV.x - 0.5) * 2.0;
	float along = smoothstep(0.0, 0.5, UV.y);
	vec3 color = mix(body_color.rgb, hot_color.rgb, smoothstep(0.5, 0.95, heat));
	ALBEDO = color * across * along * fade * energy * size_now;
}
