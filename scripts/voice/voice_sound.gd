class_name VoiceSound
extends RefCounted
## Voice commands' sounds (W7), made in code once each and kept (no recorded or downloaded audio): a command heard (a
## quick rising two-note blip, a modem's handshake in miniature), the feed found (three soft rising ticks) and lost (a
## falling tick), and your AI's cover drone: deployed (a rising whirr with a click as its ring locks open), locking on (a
## short high tick), firing (a bright snap over a low thump), and leaving (a falling whirr).

const RATE := 22050
const LENGTHS := {"heard": 0.26, "found": 0.36, "lost": 0.3, "deploy": 0.62, "lock": 0.07, "shot": 0.2, "leave": 0.55}

static var _sounds := {}


static func of(id: String) -> AudioStreamWAV:
	if _sounds.has(id):
		return _sounds[id]
	var seconds: float = LENGTHS.get(id, 0.1)
	var count := int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("voice:" + id)
	var ph := 0.0
	var ph2 := 0.0
	for i in count:
		var s := float(i) / RATE
		var u := s / seconds
		var v := 0.0
		match id:
			"heard":
				var f := 660.0 if s < 0.09 else 990.0
				ph += TAU * f / RATE
				ph2 += TAU * f * 2.01 / RATE
				var env := exp(-fmod(s, 0.09 if s < 0.09 else 0.17) * 14.0)
				v = (sin(ph) * 0.26 + sin(ph2) * 0.07) * env
			"found":
				var k := mini(floori(s / 0.12), 2)
				var f: float = 523.0 * float([1.0, 1.26, 1.5][k])
				ph += TAU * f / RATE
				v = sin(ph) * 0.18 * exp(-fmod(s, 0.12) * 22.0)
			"lost":
				ph += TAU * lerpf(700.0, 260.0, u) / RATE
				v = sin(ph) * 0.18 * (1.0 - u)
			"deploy":
				ph += TAU * lerpf(180.0, 1250.0, pow(u, 0.7)) / RATE
				ph2 += TAU * 37.0 / RATE
				var whirr := sin(ph) * 0.2 * (0.6 + 0.4 * sin(ph2 * 6.0)) * minf(u * 6.0, 1.0)
				var click := sin(TAU * 3200.0 * s) * exp(-maxf(s - seconds * 0.82, 0.0) * 120.0) * (0.4 if u > 0.82 else 0.0)
				v = whirr * (1.0 - smoothstep(0.75, 0.9, u)) + click + rng.randf_range(-1.0, 1.0) * 0.05 * (1.0 - u)
			"lock":
				v = sin(TAU * 2600.0 * s) * exp(-s * 55.0) * 0.22
			"shot":
				ph += TAU * lerpf(2100.0, 600.0, u) / RATE
				ph2 += TAU * lerpf(120.0, 55.0, u) / RATE
				v = sin(ph) * 0.25 * exp(-s * 26.0) + sin(ph2) * 0.35 * exp(-s * 16.0) + rng.randf_range(-1.0, 1.0) * 0.12 * exp(-s * 40.0)
			"leave":
				ph += TAU * lerpf(1100.0, 140.0, u) / RATE
				v = sin(ph) * 0.18 * (1.0 - u) * minf(u * 8.0, 1.0)
			_:
				ph += TAU * 1320.0 / RATE
				v = sin(ph) * exp(-s * 60.0) * 0.3
		data.encode_s16(i * 2, int(clampf(v * 0.85, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	_sounds[id] = stream
	return stream
