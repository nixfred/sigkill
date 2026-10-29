extends RefCounted
## Procedural placeholder sound effects for every weapon, synthesised here at load time.
## No audio file is downloaded, copied or shipped. Deterministic: the same tuning always
## gives the same sound. Every parameter comes from the weapon's resource.

const Weapon = preload("res://scripts/weapon_tuning.gd")

## AudioStreamPlayer volume treated as silence.
const SILENT_DB := -80.0
const INT16_FULL_SCALE := 32767.0
## Fixed so every build makes the same noise.
const NOISE_SEED := 9
## The reload clack: two short clicks, the second a little higher, this far apart.
const CLACK_GAP_S := 0.11
const CLACK_SECONDS := 0.04
const CLACK_DECAY := 90.0
const CLACK_NOISE := 0.45
const CLACK_SECOND_PITCH := 1.35
const CHIME_SECONDS := 0.16
const CHIME_START_HZ := 880.0
const CHIME_END_HZ := 1320.0
const CHIME_DECAY := 16.0
const CHIME_SECOND_RATIO := 1.5
const CHIME_GAIN := 0.35
const ICE_BURST_SECONDS := 0.35
const ICE_BURST_DECAY := 11.0
const ICE_BURST_NOISE := 0.35


## Player volume in dB for a linear master volume from 0 to 1.
static func volume_db(linear: float) -> float:
	return linear_to_db(linear) if linear > 0.0 else SILENT_DB


## Fire: a laser zap that sweeps down in pitch, with a little noise, dying fast.
static func fire_zap(w: Weapon) -> AudioStreamWAV:
	return _render(w, w.fire_sfx_seconds, w.fire_start_hz, w.fire_end_hz, w.fire_decay, w.fire_noise, 0.0, w.fire_gain)


## Hit: two bright tones at once, very short, so a hit sounds different from a shot.
static func hit_blip(w: Weapon) -> AudioStreamWAV:
	return _render(w, w.hit_sfx_seconds, w.hit_hz, w.hit_hz, w.hit_decay, 0.0, w.hit_second_ratio, w.hit_gain)


## The announcer's callout chime (C16b): a short rising two-tone, on the Announcer bus.
static func callout_chime() -> AudioStreamWAV:
	return _render(Weapon.new(), CHIME_SECONDS, CHIME_START_HZ, CHIME_END_HZ, CHIME_DECAY, 0.0, CHIME_SECOND_RATIO, CHIME_GAIN)


## Reload: a mechanical clack-clack at the weapon's reload pitch. WeaponDef only.
static func reload_clack(w: Weapon) -> AudioStreamWAV:
	var hz: float = w.get("reload_click_hz") if w.get("reload_click_hz") != null else 900.0
	var gain: float = w.get("reload_gain") if w.get("reload_gain") != null else 0.5
	var first := _render(w, CLACK_SECONDS, hz, hz * 0.6, CLACK_DECAY, CLACK_NOISE, 0.0, gain)
	var second := _render(w, CLACK_SECONDS, hz * CLACK_SECOND_PITCH, hz * CLACK_SECOND_PITCH * 0.6, CLACK_DECAY, CLACK_NOISE, 0.0, gain)
	var gap := PackedByteArray()
	gap.resize(maxi(int(CLACK_GAP_S * w.sfx_mix_rate) * 2 - first.data.size(), 0))
	gap.fill(0)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = w.sfx_mix_rate
	stream.stereo = false
	stream.data = first.data + gap + second.data
	return stream


## ICE's tell (I1): a rising crystalline swell `seconds` long, the whole of the tell, sweeping from
## `start_hz` to `end_hz` with a glassy fifth over it and a tremolo quickening as it climbs, louder all
## the way and cut off at its peak, so the ear hears exactly when the tell ends.
static func ice_charge(seconds: float, start_hz: float, end_hz: float, gain: float) -> AudioStreamWAV:
	var rate := Weapon.new().sfx_mix_rate
	var count := maxi(int(seconds * rate), 1)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	var phase2 := 0.0
	var wobble := 0.0
	for i in count:
		var u := float(i) / count
		var freq := start_hz * pow(end_hz / start_hz, u)
		phase = fmod(phase + TAU * freq / rate, TAU)
		phase2 = fmod(phase2 + TAU * freq * 1.5 / rate, TAU)
		wobble = fmod(wobble + TAU * lerpf(5.0, 22.0, u) / rate, TAU)
		var tone := sin(phase) * 0.65 + sin(phase2) * 0.35
		var swell := u * u * (0.75 + 0.25 * sin(wobble))
		var tail := minf((1.0 - u) * 200.0, 1.0)
		data.encode_s16(i * 2, int(clampf(tone * swell * tail * gain, -1.0, 1.0) * INT16_FULL_SCALE))
	return _stream(data, rate)


## ICE firing (I1): a short glassy crack, bright tones over a burst of noise, at `hz`.
static func ice_burst(hz: float, gain: float) -> AudioStreamWAV:
	return _render(Weapon.new(), ICE_BURST_SECONDS, hz * 2.0, hz, ICE_BURST_DECAY, ICE_BURST_NOISE, 2.01, gain)


## The ICEbreakers' own sounds (I2), by name: "brute" a heavy downward thump with a crack of noise,
## "exploit" a bright rising chirp, "cloak" an airy falling hush, "decoy" a two-note call, "empty" a dull
## click (H with none of the loaded kind), "cycle" a short tick (Y), "pickup" a bright chime, "uncloak" a
## rising hush as a cloak ends. Each is one of BREAKER_SOUNDS' [seconds, from Hz, to Hz, decay, noise,
## second tone's ratio, gain].
static func breaker(word: String) -> AudioStreamWAV:
	var s: Array = BREAKER_SOUNDS.get(word, BREAKER_SOUNDS["empty"])
	return _render(Weapon.new(), s[0], s[1], s[2], s[3], s[4], s[5], s[6])


const BREAKER_SOUNDS := {
	"brute": [0.45, 190.0, 48.0, 7.0, 0.45, 1.5, 0.6],
	"exploit": [0.32, 520.0, 1560.0, 6.0, 0.05, 2.0, 0.32],
	"cloak": [0.5, 900.0, 180.0, 5.5, 0.7, 1.5, 0.3],
	"decoy": [0.36, 660.0, 990.0, 8.0, 0.08, 0.5, 0.32],
	"empty": [0.06, 160.0, 120.0, 60.0, 0.5, 0.0, 0.3],
	"cycle": [0.035, 1400.0, 1200.0, 80.0, 0.2, 0.0, 0.22],
	"pickup": [0.22, 980.0, 1960.0, 12.0, 0.0, 1.5, 0.34],
	"uncloak": [0.4, 220.0, 880.0, 7.0, 0.6, 1.5, 0.3],
}


## chmod 000's beam (C29): a cold hiss, a loop of HISS_S seconds: bright noise through a slowly sweeping
## band with a thin high whine and a faint crackle of ice in it, steady so it can run as long as the beam.
static func freeze_hiss() -> AudioStreamWAV:
	var rate := LOW_RATE
	var count := int(HISS_S * rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = NOISE_SEED
	var low := 0.0
	var high := 0.0
	for i in count:
		var t := float(i) / rate
		var n := rng.randf_range(-1.0, 1.0)
		low = lerpf(low, n, 0.35)
		high = n - low
		var sweep := 0.6 + 0.4 * sin(TAU * t / HISS_S * 2.0)
		var whine := sin(TAU * 1800.0 * t) * 0.12 + sin(TAU * 2700.0 * t) * 0.06
		var crackle := rng.randf_range(-1.0, 1.0) if rng.randf() < 0.004 else 0.0
		data.encode_s16(i * 2, int(clampf((high * sweep * 0.7 + whine + crackle * 0.6) * HISS_GAIN, -1.0, 1.0) * INT16_FULL_SCALE))
	var stream := _stream(data, rate)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = count
	return stream


const HISS_S := 0.5
const HISS_GAIN := 0.5


## pipe |'s crackle (C30): a chain's stream snapping from link to link, made once per shooter: a bright
## electric crackle (bursts of noise, each a little later and weaker, PACKETS of them as the stream reaches
## each link) over a quick chirp of data stepping down in pitch, packet by packet, dying fast.
static func pipe_crackle() -> AudioStreamWAV:
	var rate := LOW_RATE
	var count := int(CRACKLE_S * rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = NOISE_SEED
	var phase := 0.0
	var low := 0.0
	for i in count:
		var t := float(i) / rate
		var packet := mini(int(t / CRACKLE_STEP_S), CRACKLE_PACKETS - 1)
		var into := t - packet * CRACKLE_STEP_S
		var hz := CRACKLE_START_HZ * pow(CRACKLE_FALL, packet)
		phase = fmod(phase + TAU * hz / rate, TAU)
		var chirp := (1.0 if sin(phase) >= 0.0 else -1.0) * 0.22 * exp(-into * 40.0) * pow(0.8, packet)
		var n := rng.randf_range(-1.0, 1.0)
		low = lerpf(low, n, 0.55)
		var snap := (n - low) * exp(-into * 26.0) * pow(0.82, packet) if rng.randf() < 0.6 else 0.0
		var tail := exp(-t * 7.0)
		data.encode_s16(i * 2, int(clampf((chirp + snap * 0.8) * tail * CRACKLE_GAIN, -1.0, 1.0) * INT16_FULL_SCALE))
	return _stream(data, rate)


const CRACKLE_S := 0.38
const CRACKLE_STEP_S := 0.045
const CRACKLE_PACKETS := 6
const CRACKLE_START_HZ := 1900.0
const CRACKLE_FALL := 0.78
const CRACKLE_GAIN := 0.8


## The arena's hum (I3): a low, steady server-room drone, a loop of HUM_S seconds (every tone a whole
## number of cycles in it, so the loop has no seam): a mains hum and its octave and fifth, swelling slowly,
## with a breath of air. It plays under everything on the Music bus until Black ICE takes it away.
static func arena_hum() -> AudioStreamWAV:
	var rate := LOW_RATE
	var count := int(HUM_S * rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = NOISE_SEED
	var air := 0.0
	for i in count:
		var t := float(i) / rate
		var swell := 0.8 + 0.2 * sin(TAU * t / HUM_S)
		var tone := sin(TAU * 55.0 * t) * 0.5 + sin(TAU * 110.0 * t) * 0.3 + sin(TAU * 165.0 * t) * 0.12 + sin(TAU * 220.0 * t + 0.6) * 0.08
		air = lerpf(air, rng.randf_range(-1.0, 1.0), 0.02)
		data.encode_s16(i * 2, int(clampf((tone * swell + air * 0.5) * HUM_GAIN, -1.0, 1.0) * INT16_FULL_SCALE))
	var stream := _stream(data, rate)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = count
	return stream


const HUM_S := 4.0
## The hum, the drone and the fall hold nothing above a few hundred hertz: half the usual rate does.
const LOW_RATE := 22050
const HUM_GAIN := 0.3


## Black ICE's sounds (I3), by name: "arrive" a deep fall `seconds` long (its whole arrival: a low tone
## sinking under a growing rumble, cut at the tell's end); "drone" its presence, a loop of low beating
## tones heard near it; "crack" a seal breaking, a glassy crack over a boom; "break" its end, a long
## shattering fall; "mend" a seal closing, a cold rising tone; "withdraw" its sinking away.
static func black_ice(word: String, seconds: float = 6.0) -> AudioStreamWAV:
	match word:
		"arrive":
			return _fall(seconds, 160.0, 34.0, 0.75)
		"drone":
			var rate := LOW_RATE
			var count := int(DRONE_S * rate)
			var data := PackedByteArray()
			data.resize(count * 2)
			for i in count:
				var t := float(i) / rate
				var tone := sin(TAU * 41.0 * t) * 0.55 + sin(TAU * 43.0 * t) * 0.35 + sin(TAU * 82.5 * t) * 0.1
				data.encode_s16(i * 2, int(clampf(tone * 0.7, -1.0, 1.0) * INT16_FULL_SCALE))
			var stream := _stream(data, rate)
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = count
			return stream
	var s: Array = BLACK_ICE_SOUNDS.get(word, BLACK_ICE_SOUNDS["crack"])
	return _render(Weapon.new(), s[0], s[1], s[2], s[3], s[4], s[5], s[6])


const DRONE_S := 2.0
const BLACK_ICE_SOUNDS := {
	"crack": [0.7, 1400.0, 90.0, 5.0, 0.55, 2.7, 0.7],
	"break": [1.6, 420.0, 28.0, 2.2, 0.65, 1.5, 0.75],
	"mend": [0.6, 180.0, 540.0, 4.0, 0.1, 1.5, 0.4],
	"withdraw": [1.4, 90.0, 30.0, 2.0, 0.4, 1.5, 0.5],
}


## A deep fall `seconds` long from `start_hz` to `end_hz`: a sinking tone with its octave under a
## rumble that grows all the way, cut off at the end so the ear hears where it lands.
static func _fall(seconds: float, start_hz: float, end_hz: float, gain: float) -> AudioStreamWAV:
	var rate := LOW_RATE
	var count := maxi(int(seconds * rate), 1)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = NOISE_SEED
	var phase := 0.0
	var rumble := 0.0
	for i in count:
		var u := float(i) / count
		var freq := start_hz * pow(end_hz / start_hz, sqrt(u))
		phase = fmod(phase + TAU * freq / rate, TAU)
		rumble = lerpf(rumble, rng.randf_range(-1.0, 1.0), 0.01)
		var tone := sin(phase) * 0.6 + sin(phase * 0.5) * 0.4
		var swell := minf(u * 6.0, 1.0) * (0.5 + 0.5 * u)
		var tail := minf((1.0 - u) * 120.0, 1.0)
		data.encode_s16(i * 2, int(clampf((tone * 0.7 + rumble * 2.5 * u) * swell * tail * gain, -1.0, 1.0) * INT16_FULL_SCALE))
	return _stream(data, rate)


static func _stream(data: PackedByteArray, rate: int) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream


static func _render(w: Weapon, seconds: float, start_hz: float, end_hz: float, decay: float, noise: float, second_ratio: float, gain: float) -> AudioStreamWAV:
	var rate := w.sfx_mix_rate
	var count := maxi(int(seconds * rate), 1)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = NOISE_SEED
	var phase := 0.0
	var phase2 := 0.0
	for i in count:
		var t := float(i) / rate
		var freq := start_hz * pow(end_hz / start_hz, float(i) / count)
		phase = fmod(phase + TAU * freq / rate, TAU)
		var tone := sin(phase)
		if second_ratio > 0.0:
			phase2 = fmod(phase2 + TAU * freq * second_ratio / rate, TAU)
			tone = (tone + sin(phase2)) * 0.5
		var attack := minf(t / w.sfx_attack_seconds, 1.0) if w.sfx_attack_seconds > 0.0 else 1.0
		var sample := (tone * (1.0 - noise) + rng.randf_range(-1.0, 1.0) * noise) * exp(-decay * t) * attack * gain
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * INT16_FULL_SCALE))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream
