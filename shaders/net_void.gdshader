// The packet tracer's sky (W5, scripts/packets/packet_net.gd): the void the network hangs in. Black overhead going to a
// deep violet haze at the horizon, a thin teal band along it from the bus far below; a vast faint grid of the globe's
// lines over everything (the map every route is drawn on); clouds of faint light where the busy networks are; and a
// scatter of far machines as points in the protocols' colours, a few of them bigger and bright. No TIME, so its light is
// worked out once and never every frame (as the arena's sky). Every hash an integer hash of small integers.
shader_type sky;

uniform vec4 zenith : source_color = vec4(0.0, 0.0, 0.004, 1.0);
uniform vec4 horizon : source_color = vec4(0.03, 0.02, 0.07, 1.0);
uniform vec4 abyss : source_color = vec4(0.0, 0.008, 0.012, 1.0);
uniform vec4 band : source_color = vec4(0.1, 0.83, 0.77, 1.0);
uniform vec4 grid_color : source_color = vec4(0.25, 0.45, 0.9, 1.0);
uniform vec4 cloud_a : source_color = vec4(0.35, 0.12, 0.6, 1.0);
uniform vec4 cloud_b : source_color = vec4(0.05, 0.35, 0.45, 1.0);

uint pcg(uint v) {
	uint state = v * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}

float cell_hash(ivec3 c) {
	uint h = pcg(uint(c.x & 0x3ff) | (uint(c.y & 0x3ff) << 10u) | (uint(c.z & 0x3ff) << 20u));
	return float(h & 0xffffu) / 65535.0;
}

float value3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	ivec3 c = ivec3(i) + ivec3(512);
	float a = mix(mix(cell_hash(c), cell_hash(c + ivec3(1, 0, 0)), f.x), mix(cell_hash(c + ivec3(0, 1, 0)), cell_hash(c + ivec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(cell_hash(c + ivec3(0, 0, 1)), cell_hash(c + ivec3(1, 0, 1)), f.x), mix(cell_hash(c + ivec3(0, 1, 1)), cell_hash(c + ivec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}

void sky() {
	vec3 d = EYEDIR;
	vec3 rgb;
	if (d.y >= 0.0) {
		rgb = mix(horizon.rgb, zenith.rgb, smoothstep(0.0, 0.45, d.y));
	} else {
		rgb = mix(horizon.rgb, abyss.rgb, smoothstep(0.0, 0.2, -d.y));
	}
	rgb += band.rgb * 0.5 * exp(-abs(d.y + 0.02) / 0.025);
	// The globe's lines: a meridian every 15 degrees, a parallel every 10, thin and faint, brighter at the horizon.
	float lon = atan(d.x, d.z) / 6.2831853 * 24.0;
	float lat = asin(clamp(d.y, -1.0, 1.0)) / 1.5707963 * 9.0;
	float to_line = min(0.5 - abs(fract(lon) - 0.5), 0.5 - abs(fract(lat) - 0.5));
	float grid = 1.0 - smoothstep(0.0, 0.03, to_line);
	rgb += grid_color.rgb * grid * 0.05 * (0.5 + 0.5 * exp(-abs(d.y) * 3.0));
	// Clouds of light where networks are busy.
	float n = value3(d * 3.0) * 0.6 + value3(d * 7.0) * 0.3 + value3(d * 15.0) * 0.1;
	float cloud = smoothstep(0.55, 0.85, n) * smoothstep(-0.2, 0.3, d.y);
	rgb += mix(cloud_b.rgb, cloud_a.rgb, value3(d * 2.0 + 7.0)) * cloud * 0.12;
	// Far machines: points in the protocols' colours.
	if (d.y > -0.05) {
		ivec3 cell = ivec3(floor(d * 300.0)) + ivec3(512);
		float roll = cell_hash(cell);
		if (roll < 0.006) {
			vec3 mid = (vec3(cell - ivec3(512)) + 0.5) / 300.0;
			float r = length(normalize(mid) - d) * 300.0;
			float pick = cell_hash(cell + ivec3(3, 1, 7));
			vec3 c = pick < 0.35 ? vec3(0.36, 0.95, 1.0) : (pick < 0.6 ? vec3(0.62, 0.55, 1.0) : (pick < 0.85 ? vec3(0.35, 1.0, 0.66) : vec3(1.0, 0.75, 0.3)));
			float big = roll < 0.0008 ? 2.5 : 1.0;
			rgb += c * (1.0 - smoothstep(0.0, 0.5 * big, r)) * 1.4 * big;
		}
	}
	COLOR = rgb;
}
