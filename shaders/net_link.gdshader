// A link between two machines (W5, the packet tracer: scripts/packets/net_link.gd): a tube of light along its curve, its
// UV.x in metres from its first end, data streaming down it as bright dashes in its protocol's colour. Its state on top:
//   flicker   a link going bad: it stutters out, the dashes stall, it burns amber, and where it will tear (warn_at) a
//             red ring pulses: the warning before a drop
//   tear      dropped: a gap open round tear_at (tear_open metres each way), its edges white-hot, growing to the ends
//   down      no route yet: dim and dashed, its machine still fighting
//   syn       reconnecting: pulses running in from both ends to meet
//   tap       a man-in-the-middle on it: violet round tap_at, the stream bending through it
//   stale     a stale route: grey arrows running the wrong way
// One shader for every link, its numbers per instance. Visual only.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform vec4 tint : source_color = vec4(0.36, 0.95, 1.0, 1.0);
instance uniform float length_m = 50.0;
instance uniform float flow = 18.0;
instance uniform float gap = 3.0;
instance uniform float bright = 1.0;
instance uniform float flicker = 0.0;
instance uniform float warn_at = -1.0;
instance uniform float tear_at = -1.0;
instance uniform float tear_open = 0.0;
instance uniform float down = 0.0;
instance uniform float syn = 0.0;
instance uniform float tap_at = -1.0;
instance uniform float stale = 0.0;
instance uniform float seed = 0.0;

const vec3 AMBER = vec3(1.0, 0.62, 0.12);
const vec3 RST = vec3(1.0, 0.16, 0.22);
const vec3 TAP = vec3(0.82, 0.0, 1.0);
const vec3 STALE = vec3(0.56, 0.63, 0.72);

float hash1(float n) {
	return fract(sin(n * 12.9898 + seed * 78.233) * 43758.5453);
}

void fragment() {
	float x = UV.x;
	float facing = abs(dot(NORMAL, VIEW));
	float core = pow(facing, 1.6);
	float t = TIME;
	vec3 col = tint.rgb;
	if (tear_at >= 0.0 && abs(x - tear_at) < tear_open) {
		discard;
	}
	if (down > 0.5) {
		float dash = step(0.55, fract(x / 1.4));
		ALBEDO = RST * (0.3 + 0.5 * dash) * (0.4 + 0.6 * core);
		ALPHA = 1.0;
	} else {
		// The stream: dashes down the link at its protocol's pace; stalled and stuttering while it goes bad.
		float speed = flow * (1.0 - 0.85 * flicker);
		float dir = stale > 0.5 ? -1.0 : 1.0;
		float u = fract((x - dir * t * speed) / gap);
		float dash = smoothstep(0.0, 0.08, u) * (1.0 - smoothstep(0.22, 0.34, u));
		float body = 0.35 + 0.65 * core;
		col = mix(col, AMBER, flicker * 0.85);
		col = mix(col, STALE, stale);
		float lit = 0.55 * body + 2.6 * dash * core;
		if (flicker > 0.0) {
			float beat = floor(t * 22.0 + x * 0.07);
			lit *= mix(1.0, step(0.38, hash1(beat)), flicker);
		}
		// The warning: a red ring pulsing where it will tear.
		if (warn_at >= 0.0) {
			float ring = 1.0 - smoothstep(0.4, 1.6, abs(x - warn_at));
			float pulse = 0.5 + 0.5 * sin(t * 28.0);
			col = mix(col, RST, ring);
			lit += ring * (2.0 + 3.0 * pulse) * flicker;
		}
		// A tear's edges: white-hot sparks where it broke.
		if (tear_at >= 0.0) {
			float edge = 1.0 - smoothstep(0.0, 1.2, abs(abs(x - tear_at) - tear_open));
			col = mix(col, mix(RST, vec3(1.0), 0.5), edge);
			lit += edge * 4.0;
		}
		// Reconnecting: a SYN running in from each end, the ACK where they meet.
		if (syn > 0.0) {
			float front = syn * length_m * 0.5;
			float s = 1.0 - smoothstep(0.0, 1.5, min(abs(x - front), abs(x - (length_m - front))));
			lit += s * 3.5;
			col = mix(col, vec3(1.0), s * 0.5);
		}
		// Tapped: violet round the man in the middle.
		if (tap_at >= 0.0) {
			float near = 1.0 - smoothstep(1.0, 6.0, abs(x - tap_at));
			col = mix(col, TAP, near);
			lit += near * 1.2;
		}
		// The stale route's arrows: chevrons drawn by the stream itself, running back.
		ALBEDO = col * lit * bright;
		ALPHA = 1.0;
	}
}
