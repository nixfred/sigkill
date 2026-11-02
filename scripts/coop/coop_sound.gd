class_name CoopSound
extends RefCounted
## Split-screen co-op's sounds (W6), made in code once each and kept (no recorded or downloaded audio): a tile resized (a
## quick swish that rises when it grows and falls when it shrinks, a click as it lands), the split flipped (two swishes
## crossing), a wave forking in (a low rising chord with ticks), a wave cleared (a bright two-note chime), a player downed
## (a falling tone into a stopped hum: a job suspended), a revive's progress (a soft tick), revived (a rising arpeggio:
## the job continued), a player out (a crackling fall), the boss (a deep pulse), wiped (a long falling drone), the run's
## results (an arpeggio).

const RATE := 22050
const LENGTHS := {"grow": 0.24, "shrink": 0.24, "flip": 0.42, "wave": 0.9, "clear": 0.6, "down": 0.9, "tick": 0.06, "revived": 0.7, "out": 0.8, "boss": 1.2, "wiped": 1.6, "results": 1.0}

static var _sounds := {}


static func of(id: String) -> AudioStreamWAV:
	if _sounds.has(id):
		return _sounds[id]
	var seconds: float = LENGTHS.get(id, 0.1)
	var count := int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("coop:" + id)
	var ph := 0.0
	var ph2 := 0.0
	var ph3 := 0.0
	for i in count:
		var s := float(i) / RATE
		var u := s / seconds
		var v := 0.0
		match id:
			"grow", "shrink":
				var up := id == "grow"
				var f := lerpf(300.0, 900.0, u if up else 1.0 - u)
				ph += TAU * f / RATE
				var swish := rng.randf_range(-1.0, 1.0) * 0.22 * sin(PI * minf(u * 1.25, 1.0))
				var click := sin(TAU * 2400.0 * s) * exp(-maxf(s - seconds * 0.8, 0.0) * 90.0) * (0.35 if u > 0.8 else 0.0)
				v = swish + sin(ph) * 0.12 * sin(PI * u) + click
			"flip":
				ph += TAU * lerpf(250.0, 1100.0, u) / RATE
				ph2 += TAU * lerpf(1100.0, 250.0, u) / RATE
				v = (sin(ph) + sin(ph2)) * 0.12 * sin(PI * u) + rng.randf_range(-1.0, 1.0) * 0.12 * sin(PI * u)
			"wave":
				ph += TAU * lerpf(70.0, 110.0, u) / RATE
				ph2 += TAU * lerpf(105.0, 165.0, u) / RATE
				ph3 += TAU * lerpf(140.0, 220.0, u) / RATE
				var tick := rng.randf_range(-1.0, 1.0) * exp(-fmod(s, 0.11) * 80.0) * 0.25
				v = (sin(ph) + sin(ph2) * 0.7 + sin(ph3) * 0.5) * 0.2 * minf(u * 4.0, 1.0) * (1.0 - u * 0.4) + tick
			"clear":
				var f := 880.0 if s < 0.16 else 1320.0
				ph += TAU * f / RATE
				v = sin(ph) * 0.3 * exp(-fmod(s, 0.16 if s < 0.16 else 0.44) * 6.0)
			"down":
				var f := lerpf(700.0, 90.0, pow(u, 0.5))
				ph += TAU * f / RATE
				ph2 += TAU * 60.0 / RATE
				v = sin(ph) * 0.32 * (1.0 - u) + signf(sin(ph2)) * 0.1 * smoothstep(0.4, 0.6, u) * (1.0 - u)
			"tick":
				v = sin(TAU * 1600.0 * s) * exp(-s * 70.0) * 0.25
			"revived":
				var k := mini(floori(s / 0.11), 4)
				var f: float = 392.0 * float([1.0, 1.26, 1.5, 2.0, 2.52][k])
				ph += TAU * f / RATE
				v = sin(ph) * 0.3 * exp(-fmod(s, 0.11) * 5.0) * (1.0 - u * 0.5)
			"out":
				var f := lerpf(500.0, 40.0, u)
				ph += TAU * f / RATE
				v = sin(ph) * 0.25 * (1.0 - u) + rng.randf_range(-1.0, 1.0) * 0.3 * (1.0 - u) * (0.5 + 0.5 * sin(s * 90.0))
			"boss":
				ph += TAU * 48.0 / RATE
				v = sin(ph) * 0.5 * (0.5 + 0.5 * sin(TAU * 2.5 * s)) * minf(u * 5.0, 1.0) * (1.0 - u)
			"wiped":
				ph += TAU * lerpf(220.0, 40.0, u) / RATE
				ph2 += TAU * lerpf(226.0, 41.0, u) / RATE
				v = (sin(ph) + sin(ph2)) * 0.2 * (1.0 - u)
			"results":
				var k := mini(floori(s / 0.16), 4)
				var f: float = 440.0 * float([1.0, 1.19, 1.5, 1.78, 2.0][k])
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
