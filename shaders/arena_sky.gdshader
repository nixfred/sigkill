// SIGKILL arena sky (A3): the void round the arena. Black overhead, deepening to a dark teal haze at
// the horizon with a thin glowing band along it, and below the horizon an abyss a shade darker; a
// sparse scatter of data points in the upper sky, a few of them hostile red. No TIME, so its light
// is worked out once and never every frame. Every hash is an integer hash (PCG) of small integers.
// Defaults only mirror scripts/palette.gd so the material previews in the editor; palette.gd sets
// every value at runtime and is the single source.
shader_type sky;

uniform vec4 zenith_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.012, 0.063, 0.071, 1.0);
uniform vec4 abyss_color : source_color = vec4(0.004, 0.016, 0.02, 1.0);
uniform vec4 glow_color : source_color = vec4(0.098, 0.827, 0.773, 1.0);
uniform vec4 point_color : source_color = vec4(0.49, 1.0, 0.812, 1.0);
uniform vec4 alert_color : source_color = vec4(1.0, 0.2, 0.333, 1.0);
uniform float haze_height : hint_range(0.01, 1.0) = 0.35;
uniform float glow_energy : hint_range(0.0, 8.0) = 0.35;
uniform float glow_width : hint_range(0.001, 0.5) = 0.03;
uniform float point_cells : hint_range(10.0, 2000.0) = 360.0;
uniform float point_share : hint_range(0.0, 0.2) = 0.004;
uniform float point_energy : hint_range(0.0, 8.0) = 0.9;

uint pcg(uint v) {
	uint state = v * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}

void sky() {
	vec3 d = EYEDIR;
	vec3 rgb;
	if (d.y >= 0.0) {
		rgb = mix(horizon_color.rgb, zenith_color.rgb, smoothstep(0.0, haze_height, d.y));
	} else {
		rgb = mix(horizon_color.rgb, abyss_color.rgb, smoothstep(0.0, haze_height * 0.5, -d.y));
	}
	rgb += glow_color.rgb * glow_energy * exp(-abs(d.y) / glow_width);
	if (d.y > 0.06) {
		ivec3 cell = ivec3(floor(d * point_cells));
		uint h = pcg(uint(cell.x & 0x3ff) | (uint(cell.y & 0x3ff) << 10u) | (uint(cell.z & 0x3ff) << 20u));
		float roll = float(h & 0xffffu) / 65535.0;
		if (roll < point_share) {
			float pick = float((h >> 16u) & 0xffu) / 255.0;
			vec3 ink = pick > 0.92 ? alert_color.rgb : point_color.rgb;
			rgb += ink * point_energy * (0.3 + 0.7 * roll / point_share) * smoothstep(0.06, 0.25, d.y);
		}
	}
	COLOR = rgb;
}
