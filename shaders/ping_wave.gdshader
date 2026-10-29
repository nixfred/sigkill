// SIGKILL ping's sonar ring (C28): one pulse going out from the player, drawn twice by
// scripts/weapons/ping_pulse.gd with this one shader: a flat ring across the floor (wall false: a
// square, its middle the pulse's centre, its half-width the ring's reach plus one front's width)
// and a low wall standing on the ring's front (wall true: an open cylinder of radius 1 and height 1,
// bright at the floor and fading up, lines climbing it). The node scales the wall to the ring's
// radius every frame and sets the instance uniforms; nothing else changes.
//
// On the floor: the front a bright band a fixed width in metres whatever the radius, a fading wash
// behind it with echo lines every echo_m metres sliding outward with it, and a dim edge circle where
// the ring will stop. Additive and unlit; the level still hides it (depth tested), so the ring reads
// where it is in the room. `strength` fades the whole pulse out at its end. Defaults only mirror
// scripts/palette.gd, which sets the colours at runtime.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform bool wall = false;
uniform vec4 color : source_color = vec4(0.722, 1.0, 0.176, 1.0);
uniform vec4 front_color : source_color = vec4(0.894, 1.0, 0.702, 1.0);
uniform float front_m : hint_range(0.05, 4.0) = 0.5;
uniform float front_energy : hint_range(0.0, 16.0) = 5.0;
uniform float wash_energy : hint_range(0.0, 4.0) = 0.35;
uniform float echo_m : hint_range(0.2, 8.0) = 1.5;
uniform float echo_energy : hint_range(0.0, 8.0) = 0.9;
uniform float edge_energy : hint_range(0.0, 4.0) = 0.6;
uniform float wall_energy : hint_range(0.0, 16.0) = 2.6;
uniform float wall_lines : hint_range(1.0, 40.0) = 9.0;

// The ring's radius now in metres, how far out it will go, and the pulse's strength (1 while it
// grows, fading to 0 after).
instance uniform float radius_m : instance_index(0) = 1.0;
instance uniform float reach_m : instance_index(1) = 1.0;
instance uniform float strength : instance_index(2) = 1.0;

varying float up;

void vertex() {
	// The wall's height from its foot (0) to its top (1): the unit cylinder is centred on its origin.
	up = VERTEX.y + 0.5;
}

void fragment() {
	if (wall) {
		// A bright foot fading up, with lines climbing it.
		float foot = pow(1.0 - up, 2.5);
		float lines = smoothstep(0.7, 1.0, fract(up * wall_lines - radius_m * 0.6));
		ALBEDO = (front_color.rgb * foot * wall_energy + color.rgb * lines * foot * 0.8 * wall_energy) * strength;
	} else {
		// Metres from the centre on the floor, from the square's own UV.
		vec2 p = (UV * 2.0 - 1.0) * (reach_m + front_m);
		float d = length(p);
		if (d > reach_m + front_m) {
			discard;
		}
		float behind = radius_m - d;
		float front = 1.0 - smoothstep(0.0, front_m, abs(behind));
		float inside = step(0.0, behind);
		float wash = inside * exp(-behind / max(radius_m * 0.35, 0.001));
		float echo = inside * smoothstep(0.82, 1.0, fract(behind / echo_m)) * exp(-behind / max(radius_m * 0.5, 0.001));
		float edge = 1.0 - smoothstep(0.0, 0.08, abs(d - reach_m));
		vec3 light = front_color.rgb * front * front_energy + color.rgb * (wash * wash_energy + echo * echo_energy + edge * edge_energy);
		ALBEDO = light * strength;
	}
}
