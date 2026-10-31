shader_type spatial;
// The light of the opener's forge and kill (C42, scripts/opener/forge_beat.gd), added to what is under it. Mode 0, cells:
// a MultiMesh of cubes (the letters of `kill -9`, their stream into the rifle, the copy's derezz), each in its instance
// colour, glowing hardest along its edges like a Tron voxel, white hot by INSTANCE_CUSTOM.r, there by .g. Mode 1, the
// beam: a cylinder along its own Y, a white-hot core in a sheath of the beam colour, bands racing along it, `fade` out.
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled, specular_disabled;

uniform float mode = 0.0;
uniform vec3 hot : source_color = vec3(1.0, 0.98, 0.95);
uniform vec3 beam_color : source_color = vec3(0.639, 0.933, 1.0);
uniform float energy = 1.0;
// The beam: its clock (the opener's, so it pauses with it), how far it has burnt out (0 whole, 1 gone).
uniform float clock = 0.0;
uniform float fade = 0.0;

varying vec3 local;
varying flat vec4 custom;
varying vec3 tint;

void vertex() {
	local = VERTEX;
	custom = INSTANCE_CUSTOM;
	tint = COLOR.rgb;
}

void fragment() {
	vec3 rgb = vec3(0.0);
	if (mode < 0.5) {
		vec3 a = clamp(abs(local) * 2.0, 0.0, 1.0);
		float most = max(a.x, max(a.y, a.z));
		float least = min(a.x, min(a.y, a.z));
		float middle = a.x + a.y + a.z - most - least;
		float edge = pow(middle, 7.0);
		vec3 base = mix(tint, hot, clamp(custom.r, 0.0, 1.0));
		rgb = base * (0.28 + 2.2 * edge) * custom.g * energy;
	} else {
		float r = length(local.xz) * 2.0;
		float core = exp(-r * r * 30.0);
		float sheath = exp(-r * r * 3.0);
		float bands = 0.75 + 0.25 * sin(local.y * 60.0 - clock * 90.0);
		rgb = (hot * core * 3.0 + beam_color * sheath * 1.2 * bands) * (1.0 - fade) * energy;
	}
	ALBEDO = rgb;
}
