class_name PacketSound
extends RefCounted
## The packet tracer's sounds (W5), made in code once each and kept (no recorded or downloaded audio): boarding (a
## handshake's two chirps, SYN and ACK), a burst (a rising rush), landing (a thump and a click), a hop traced (three
## rising pings), a route coming up (a dial chirp), a refused port (a low buzz), intercepted (static over a low drone), a
## packet lost (a falling whistle into static), retransmitted (a reversed chirp and a zap), misrouted by a stale route (two
## detuned tones falling), a flood (a burst of clicks), the trace complete (an arpeggio).

const RATE := 22050
const LENGTHS := {"board": 0.28, "burst": 0.45, "land": 0.2, "hop": 0.42, "syn": 0.4, "refused": 0.22, "intercepted": 0.55, "lost": 0.95, "retransmit": 0.38, "stale": 0.55, "flood": 0.6, "done": 1.0}

static var _sounds := {}


static func of(id: String) -> AudioStreamWAV:
	if _sounds.has(id):
		return _sounds[id]
	var seconds: float = LENGTHS.get(id, 0.1)
	var count := int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("packet:" + id)
	var ph := 0.0
	var ph2 := 0.0
	for i in count:
		var s := float(i) / RATE
		var u := s / seconds
		var v := 0.0
		match id:
			"board":
				var f := 1200.0 if s < 0.12 else 1800.0
				ph += TAU * f / RATE
				v = sin(ph) * 0.35 * (1.0 if fmod(s, 0.14) < 0.1 else 0.0) * (1.0 - u * 0.5)
			"burst":
				var f := lerpf(200.0, 1400.0, u)
				ph += TAU * f / RATE
				v = (rng.randf_range(-1.0, 1.0) * 0.4 + sin(ph) * 0.15) * sin(PI * u)
			"land":
				ph += TAU * lerpf(140.0, 50.0, u) / RATE
				v = sin(ph) * exp(-s * 18.0) * 0.8 + rng.randf_range(-1.0, 1.0) * exp(-s * 160.0) * 0.5
			"hop":
				var k := floori(s / 0.12)
				var f := 880.0 * pow(1.26, k)
				ph += TAU * f / RATE
				v = sin(ph) * 0.3 * exp(-fmod(s, 0.12) * 30.0) * (1.0 if k < 3 else 0.0)
			"syn":
				var f := lerpf(600.0, 2200.0, u * u)
				ph += TAU * f / RATE
				v = sin(ph) * 0.22 * sin(PI * u)
			"refused":
				ph += TAU * 110.0 / RATE
				v = signf(sin(ph)) * 0.18 * (1.0 - u)
			"intercepted":
				ph += TAU * 70.0 / RATE
				v = (rng.randf_range(-1.0, 1.0) * 0.35 * (0.5 + 0.5 * sin(s * 60.0)) + sin(ph) * 0.4) * (1.0 - u)
			"lost":
				var f := lerpf(1600.0, 120.0, pow(u, 0.6))
				ph += TAU * f / RATE
				v = sin(ph) * 0.35 * (1.0 - u) + rng.randf_range(-1.0, 1.0) * 0.25 * smoothstep(0.3, 1.0, u) * (1.0 - u)
			"retransmit":
				var f := lerpf(2000.0, 500.0, 1.0 - u)
				ph += TAU * f / RATE
				v = sin(ph) * 0.3 * sin(PI * u) + rng.randf_range(-1.0, 1.0) * exp(-maxf(s - 0.3, 0.0) * 60.0) * (0.6 if s > 0.3 else 0.0)
			"stale":
				ph += TAU * lerpf(520.0, 300.0, u) / RATE
				ph2 += TAU * lerpf(540.0, 310.0, u) / RATE
				v = (sin(ph) + sin(ph2)) * 0.18 * (1.0 - u)
			"flood":
				var tick := fmod(s, 0.025)
				v = rng.randf_range(-1.0, 1.0) * exp(-tick * 400.0) * 0.6 * (1.0 - u)
			"done":
				var k := mini(floori(s / 0.16), 4)
				var f: float = 523.25 * float([1.0, 1.26, 1.5, 2.0, 2.52][k])
				ph += TAU * f / RATE
				v = sin(ph) * 0.28 * exp(-fmod(s, 0.16) * 4.0) * (1.0 - u * 0.6)
			_:
				ph += TAU * 1320.0 / RATE
				v = sin(ph) * exp(-s * 60.0) * 0.35
		data.encode_s16(i * 2, int(clampf(v * 0.85, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	_sounds[id] = stream
	return stream
