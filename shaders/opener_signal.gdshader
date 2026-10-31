shader_type spatial;
// The opener's link (C41, scripts/opener/pit_beat.gd): lines of signal climbing out of the pit as the player's AI is
// linked, one quad an instance stood on end and turned about its own long axis to face the camera (as the C40 streams
// are). A bright head races up from the bottom with a fading tail, leaving a faint trace lit behind it; when the link
// locks every line flares once and fades. Added to what is behind it; it fades with distance as the fog would.
//
// Per instance: the transform's Y axis is the line's length (bottom to top), X its width; INSTANCE_CUSTOM r its
// delay (seconds after the climb starts), g its speed (metres a second), b how bright.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform, fog_disabled, specular_disabled;

uniform vec3 line_color : source_color = vec3(0.098, 0.827, 0.773);
uniform vec3 head_color : source_color = vec3(0.49, 1.0, 0.812);
// Seconds since the climb started (below 0, nothing), and since the link locked (below 0, not yet).
uniform float climb = -1.0;
uniform float lock = -1.0;
// The whole beat's strength, 0 to 1 (it fades away as the copy comes).
uniform float strength = 0.0;
uniform float tail_m = 26.0;
uniform float fog_density = 0.0028;

varying float up_m;
varying float across;
varying float dist;
varying flat vec4 custom;
varying flat float len_m;

void vertex() {
	vec3 mid = MODEL_MATRIX[3].xyz;
	vec3 axis = MODEL_MATRIX[1].xyz;
	float len = max(length(axis), 0.001);
	vec3 a = axis / len;
	float width = length(MODEL_MATRIX[0].xyz);
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 side = cross(a, normalize(cam - mid));
	side = length(side) < 0.0001 ? vec3(1.0, 0.0, 0.0) : normalize(side);
	vec3 world = mid + a * (VERTEX.y * len) + side * (VERTEX.x * width);
	up_m = (VERTEX.y + 0.5) * len;
	across = VERTEX.x * 2.0;
	len_m = len;
	dist = distance(world, cam);
	custom = INSTANCE_CUSTOM;
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	NORMAL = normalize((VIEW_MATRIX * vec4(cam - world, 0.0)).xyz);
}

void fragment() {
	float t = climb - custom.r;
	float head = t * custom.g;
	float behind = head - up_m;
	float core = exp(-abs(across) * 3.0);
	// The head and its tail, only below the head; the trace it leaves, dim, over the whole way it has climbed.
	float tail = behind >= 0.0 ? exp(-behind / tail_m) : 0.0;
	float tip = exp(-abs(behind) * 0.9);
	float trace = behind >= 0.0 && t > 0.0 ? 0.12 : 0.0;
	// Packets running up the trace after the head, a dash every few metres.
	float dash = step(0.75, fract((up_m - t * custom.g * 0.55) / 7.0)) * 0.22 * step(0.0, behind);
	float flare = lock >= 0.0 ? exp(-lock * 1.6) * (1.0 - exp(-lock * 18.0)) * 1.4 : 0.0;
	float ends = smoothstep(0.0, 1.5, up_m) * smoothstep(0.0, 8.0, len_m - up_m);
	float fade = exp(-dist * fog_density);
	float on = t > 0.0 ? 1.0 : 0.0;
	vec3 rgb = line_color * (tail * 1.3 + trace + dash + flare * step(0.0, behind)) + head_color * tip * 2.4;
	ALBEDO = rgb * core * ends * fade * on * custom.b * strength;
}
