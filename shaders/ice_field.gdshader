// SIGKILL ICE field (I1): a white ICE node's field, drawn as a dome of crystal lattice at the field's
// full reach (scripts/ice/ice_node.gd scales a unit sphere to its radius). Through the node's tell it
// flickers in, faint and rising, so a player sees exactly how far the field will reach before it
// fires, and can step out of it or behind cover; as the field fires it flashes bright and fades.
// The jam field's lattice is still and even (a lock); the HUD field's is torn by scrambled bands (a
// corruption). Additive and unlit, both faces drawn, depth tested so the level still hides it. The
// colour is an instance uniform, so every node shares this one material; nothing changes per frame
// but the node's instance uniforms. Defaults only mirror scripts/palette.gd.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

global uniform float daemon_clock;

uniform float rim_energy : hint_range(0.0, 16.0) = 2.4;
uniform float lattice_energy : hint_range(0.0, 16.0) = 1.6;
uniform float lattice_cells : hint_range(1.0, 64.0) = 18.0;
uniform float flash_energy : hint_range(0.0, 32.0) = 6.0;

// The ICE's colour, how far into the tell it is (0 to 1, its warning), how bright its firing flash is
// now (1 as it fires, fading to 0), and which field: 0 the jam, 1 the HUD's corruption.
instance uniform vec4 color : source_color, instance_index(0) = vec4(0.094, 0.698, 1.0, 1.0);
instance uniform float warn : instance_index(1) = 0.0;
instance uniform float burst : instance_index(2) = 0.0;
instance uniform float scramble : instance_index(3) = 0.0;

varying vec3 dir;

void vertex() {
	dir = normalize(VERTEX);
}

float h(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

void fragment() {
	float t = daemon_clock;
	float rim = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
	// A hexagonal-ish lattice over the dome: three families of lines on the sphere.
	vec3 d = dir * lattice_cells;
	float a = abs(fract(d.x + d.y * 0.5) - 0.5);
	float b = abs(fract(d.z - d.y * 0.5) - 0.5);
	float c = abs(fract(d.y) - 0.5);
	float lat = 1.0 - smoothstep(0.0, 0.035, min(min(a, b), c));
	// The HUD field's corruption: bands that jump and drop out.
	float band = floor(dir.y * 14.0 + 7.0);
	float tick = floor(t * 12.0);
	float torn = mix(1.0, step(0.35, h(band * 3.7 + tick)), scramble);
	float flicker = 0.55 + 0.45 * step(0.25, h(tick * 1.3 + band * scramble));
	float shown = warn * warn * flicker * torn;
	vec3 light = color.rgb * (rim * rim_energy + lat * lattice_energy) * shown * 0.5;
	light += mix(color.rgb, vec3(1.0), 0.35) * (rim * flash_energy + lat * lattice_energy * 2.0) * burst * torn;
	ALBEDO = light;
}
