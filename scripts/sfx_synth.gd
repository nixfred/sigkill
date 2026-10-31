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


## /dev/null's hole while it pulls (C31): a loop of VOID_HUM_S seconds (every tone a whole number of cycles
## in it, so the loop has no seam): a deep sub and its beating neighbour under a wind of filtered noise that
## swells twice a second, the air being drawn in.
static func void_hum() -> AudioStreamWAV:
	var rate := LOW_RATE
	var count := int(VOID_HUM_S * rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = NOISE_SEED
	var wind := 0.0
	var slow := 0.0
	for i in count:
		var t := float(i) / rate
		var sub := sin(TAU * 36.0 * t) * 0.55 + sin(TAU * 37.0 * t) * 0.35 + sin(TAU * 72.0 * t) * 0.12
		var n := rng.randf_range(-1.0, 1.0)
		wind = lerpf(wind, n, 0.08)
		slow = lerpf(slow, wind, 0.05)
		var swell := 0.55 + 0.45 * sin(TAU * 2.0 * t)
		data.encode_s16(i * 2, int(clampf((sub * 0.8 + (wind - slow) * 2.2 * swell) * VOID_GAIN, -1.0, 1.0) * INT16_FULL_SCALE))
	var stream := _stream(data, rate)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = count
	return stream


## /dev/null's implosion (C31): a short rush of air drawn in, then a deep falling boom with a crackle in it.
static func void_implosion() -> AudioStreamWAV:
	var rate := LOW_RATE
	var count := int(IMPLOSION_S * rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = NOISE_SEED + 1
	var phase := 0.0
	var low := 0.0
	for i in count:
		var t := float(i) / rate
		var n := rng.randf_range(-1.0, 1.0)
		low = lerpf(low, n, 0.25)
		var rush := (n - low) * smoothstep(0.0, IMPLOSION_RUSH_S, t) * (1.0 if t < IMPLOSION_RUSH_S else exp(-(t - IMPLOSION_RUSH_S) * 40.0))
		var into := maxf(t - IMPLOSION_RUSH_S, 0.0)
		var hz := 28.0 + 70.0 * exp(-into * 6.0)
		phase = fmod(phase + TAU * hz / rate, TAU)
		var boom := sin(phase) * exp(-into * 3.2) * (1.0 if t >= IMPLOSION_RUSH_S else 0.0)
		var crackle := n * exp(-into * 14.0) * 0.35 * (1.0 if t >= IMPLOSION_RUSH_S else 0.0)
		data.encode_s16(i * 2, int(clampf((rush * 0.6 + boom + crackle) * VOID_GAIN * 1.6, -1.0, 1.0) * INT16_FULL_SCALE))
	return _stream(data, rate)


## SIGHUP's hangup (C32): the handset slammed down (a hard plastic click over a thump), a modem's screech as
## the carrier drops (its tones flipping between a mark and a space, falling, in a hiss), then two beeps of a
## busy line, quieter.
static func hangup() -> AudioStreamWAV:
	var rate := LOW_RATE
	var count := int(HANGUP_S * rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = NOISE_SEED + 2
	var phase := 0.0
	var hiss := 0.0
	var tone := 1.0
	var flip := 0.0
	for i in count:
		var t := float(i) / rate
		var n := rng.randf_range(-1.0, 1.0)
		var click := (n * 0.8 + sin(TAU * 170.0 * t) * 0.9) * exp(-t * 90.0)
		var screech := 0.0
		if t >= HANGUP_CLICK_S and t < HANGUP_SCREECH_S:
			var into := t - HANGUP_CLICK_S
			flip -= 1.0 / rate
			if flip <= 0.0:
				flip = rng.randf_range(0.006, 0.016)
				tone = 1.8 if tone < 1.5 else 1.0
			var hz := (1150.0 * tone) * (1.0 - 0.35 * into / (HANGUP_SCREECH_S - HANGUP_CLICK_S))
			phase = fmod(phase + TAU * hz / rate, TAU)
			hiss = lerpf(hiss, n, 0.6)
			screech = (sign(sin(phase)) * 0.35 + sin(phase) * 0.4 + hiss * 0.35) * exp(-into * 3.0)
		var busy := 0.0
		for start: float in HANGUP_BEEPS:
			if t >= start and t < start + HANGUP_BEEP_S:
				var u := t - start
				busy = (sin(TAU * 480.0 * u) + sin(TAU * 620.0 * u)) * 0.22 * smoothstep(0.0, 0.01, u) * (1.0 - smoothstep(HANGUP_BEEP_S - 0.02, HANGUP_BEEP_S, u))
		data.encode_s16(i * 2, int(clampf((click + screech + busy) * HANGUP_GAIN, -1.0, 1.0) * INT16_FULL_SCALE))
	return _stream(data, rate)


const HANGUP_S := 1.45
const HANGUP_CLICK_S := 0.03
const HANGUP_SCREECH_S := 0.55
const HANGUP_BEEPS := [0.68, 1.12]
const HANGUP_BEEP_S := 0.26
const HANGUP_GAIN := 0.5


const VOID_HUM_S := 2.0
const IMPLOSION_S := 1.2
const IMPLOSION_RUSH_S := 0.14
const VOID_GAIN := 0.55


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


## The opener's sounds (C38), made here like every other: a keyboard's keys, the stuck buffer of a frozen game, the
## crackle of its picture coming apart, and the low hum under the fake terminal.

## Key click variants (0 to OPENER_KEYS - 1); -1 is the space bar, -2 a backspace.
const OPENER_KEYS := 6
const OPENER_BUZZ_GRAIN_S := 0.046
const OPENER_CRACKLE_S := 1.2
const OPENER_HUM_S := 2.0


## A key on a keyboard: a short tick (a decaying burst of noise through a resonance at the key's pitch) over a
## small thump; each variant its own pitch and bite, the space bar deeper and longer, a backspace sharper.
static func opener_key(variant: int) -> AudioStreamWAV:
	var rate := 44100
	var seconds := 0.05 if variant == -1 else 0.032
	var count := int(seconds * rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = NOISE_SEED + 31 * (variant + 3)
	var hz := 1700.0 if variant == -1 else (3900.0 if variant == -2 else 2500.0 + 230.0 * variant)
	var thump_hz := 95.0 if variant == -1 else 150.0 + 12.0 * maxi(variant, 0)
	var w := TAU * hz / rate
	var r := 0.965
	var c1 := 2.0 * r * cos(w)
	var c2 := -r * r
	var y1 := 0.0
	var y2 := 0.0
	var peak := 0.0
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t := float(i) / rate
		var burst := rng.randf_range(-1.0, 1.0) * exp(-t * 420.0)
		var y := c1 * y1 + c2 * y2 + burst
		y2 = y1
		y1 = y
		var thump := sin(TAU * thump_hz * t) * exp(-t * 110.0) * 6.0
		samples[i] = y + thump
		peak = maxf(peak, absf(samples[i]))
	for i in count:
		data.encode_s16(i * 2, int(clampf(samples[i] / maxf(peak, 0.001) * 0.8, -1.0, 1.0) * INT16_FULL_SCALE))
	return _stream(data, rate)


## A frozen game's sound: its last 46 ms of audio played over and over, a buzz at the grain's own rate with the
## arena's hum chord and grit in it. Loops until the opener cuts it dead.
static func opener_buzz() -> AudioStreamWAV:
	var rate := LOW_RATE
	var count := int(OPENER_BUZZ_GRAIN_S * rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = NOISE_SEED + 1
	var grit := 0.0
	for i in count:
		var t := float(i) / rate
		grit = lerpf(grit, rng.randf_range(-1.0, 1.0), 0.3)
		var tone := sin(TAU * 55.0 * t) * 0.5 + sin(TAU * 110.0 * t + 0.3) * 0.35 + sin(TAU * 220.0 * t) * 0.22 + sin(TAU * 660.0 * t) * 0.08
		data.encode_s16(i * 2, int(clampf((tone + grit * 0.3) * 0.75, -1.0, 1.0) * INT16_FULL_SCALE))
	var stream := _stream(data, rate)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = count
	return stream


## A picture coming apart: sparse bursts of held, coarsely stepped noise, as a broken decoder's output sounds.
static func opener_crackle() -> AudioStreamWAV:
	var rate := LOW_RATE
	var count := int(OPENER_CRACKLE_S * rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = NOISE_SEED + 2
	var held := 0.0
	var hold := 0
	var gate := 0.0
	for i in count:
		if i % 220 == 0:
			gate = 1.0 if rng.randf() < 0.3 else 0.0
		if hold <= 0:
			held = floorf(rng.randf_range(-1.0, 1.0) * 4.0) / 4.0
			hold = rng.randi_range(1, 40)
		hold -= 1
		data.encode_s16(i * 2, int(clampf(held * gate * 0.7, -1.0, 1.0) * INT16_FULL_SCALE))
	var stream := _stream(data, rate)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = count
	return stream


## The low hum under the fake terminal: mains hum and its harmonics with a little air, a loop that closes on itself.
static func opener_hum() -> AudioStreamWAV:
	var rate := LOW_RATE
	var count := int(OPENER_HUM_S * rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = NOISE_SEED + 3
	var air := 0.0
	for i in count:
		var t := float(i) / rate
		air = lerpf(air, rng.randf_range(-1.0, 1.0), 0.015)
		var swell := 0.85 + 0.15 * sin(TAU * t / OPENER_HUM_S)
		var tone := sin(TAU * 50.0 * t) * 0.5 + sin(TAU * 100.0 * t) * 0.28 + sin(TAU * 150.0 * t + 0.4) * 0.14 + sin(TAU * 250.0 * t) * 0.05
		data.encode_s16(i * 2, int(clampf((tone * swell + air * 0.6) * 0.6, -1.0, 1.0) * INT16_FULL_SCALE))
	var stream := _stream(data, rate)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = count
	return stream


## The opener's machine (C40): the rush as the terminal shrinks away into it, the wind of the fall, the landing, and
## the hottest process beating at the bottom. Made here like every other sound.
const OPENER_WHOOSH_S := 3.4
const OPENER_WIND_S := 2.0
const OPENER_WIND_BLEND_S := 0.3
const OPENER_THUD_S := 0.9
const OPENER_BEAT_S := 0.55


## The camera pulling back from the screen: air rushing away (noise through a resonance falling from bright to dark)
## over a sub tone sinking, a swell that peaks as the dark opens up, then dies away.
static func opener_whoosh() -> AudioStreamWAV:
	var rate := LOW_RATE
	var count := int(OPENER_WHOOSH_S * rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = NOISE_SEED + 40
	var y1 := 0.0
	var y2 := 0.0
	var phase := 0.0
	var samples := PackedFloat32Array()
	samples.resize(count)
	var peak := 0.0
	for i in count:
		var t := float(i) / rate
		var u := t / OPENER_WHOOSH_S
		var hz := 2400.0 * pow(160.0 / 2400.0, u)
		var w := TAU * hz / rate
		var r := 0.985
		var y := 2.0 * r * cos(w) * y1 - r * r * y2 + rng.randf_range(-1.0, 1.0) * 0.06
		y2 = y1
		y1 = y
		phase = fmod(phase + TAU * lerpf(92.0, 36.0, u) / rate, TAU)
		var swell := smoothstep(0.0, 0.42, u) * (1.0 - smoothstep(0.42, 1.0, u))
		samples[i] = (y * 0.9 + sin(phase) * 0.55) * swell
		peak = maxf(peak, absf(samples[i]))
	for i in count:
		data.encode_s16(i * 2, int(clampf(samples[i] / maxf(peak, 0.001) * 0.85, -1.0, 1.0) * INT16_FULL_SCALE))
	return _stream(data, rate)


## Falling: wind, noise darkened and brightened by two slow gusts, its last moment blended into its first so it
## loops without a seam. The opener raises its volume and pitch with the speed.
static func opener_wind() -> AudioStreamWAV:
	var rate := LOW_RATE
	var count := int(OPENER_WIND_S * rate)
	var blend := int(OPENER_WIND_BLEND_S * rate)
	var rng := RandomNumberGenerator.new()
	rng.seed = NOISE_SEED + 41
	var low := 0.0
	var high := 0.0
	var samples := PackedFloat32Array()
	samples.resize(count + blend)
	var peak := 0.0
	for i in count + blend:
		var t := float(i) / rate
		var gust := 0.6 + 0.25 * sin(TAU * t / OPENER_WIND_S) + 0.15 * sin(TAU * 3.0 * t / OPENER_WIND_S + 1.3)
		var n := rng.randf_range(-1.0, 1.0)
		low = lerpf(low, n, 0.035 + 0.05 * gust)
		high = lerpf(high, n, 0.3)
		samples[i] = (low * 2.2 + (high - low) * 0.25 * gust) * gust
		peak = maxf(peak, absf(samples[i]))
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var s := samples[i]
		if i < blend:
			var k := float(i) / blend
			s = s * k + samples[count + i] * (1.0 - k)
		data.encode_s16(i * 2, int(clampf(s / maxf(peak, 0.001) * 0.8, -1.0, 1.0) * INT16_FULL_SCALE))
	var stream := _stream(data, rate)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = count
	return stream


## Landing: a deep thump (a sine sinking fast) and the slap of the floor (a short burst of dark noise).
static func opener_thud() -> AudioStreamWAV:
	var rate := LOW_RATE
	var count := int(OPENER_THUD_S * rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = NOISE_SEED + 42
	var phase := 0.0
	var dark := 0.0
	for i in count:
		var t := float(i) / rate
		phase = fmod(phase + TAU * (34.0 + 46.0 * exp(-t * 9.0)) / rate, TAU)
		dark = lerpf(dark, rng.randf_range(-1.0, 1.0), 0.08)
		var s := sin(phase) * exp(-t * 4.5) * minf(t * 400.0, 1.0) + dark * 2.0 * exp(-t * 30.0)
		data.encode_s16(i * 2, int(clampf(s * 0.8, -1.0, 1.0) * INT16_FULL_SCALE))
	return _stream(data, rate)


## The hottest process's beat: one low, soft thump, with the pit's red swell.
static func opener_beat() -> AudioStreamWAV:
	var rate := LOW_RATE
	var count := int(OPENER_BEAT_S * rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for i in count:
		var t := float(i) / rate
		phase = fmod(phase + TAU * (48.0 + 22.0 * exp(-t * 14.0)) / rate, TAU)
		var s := (sin(phase) + 0.25 * sin(phase * 3.0)) * exp(-t * 7.0) * minf(t * 250.0, 1.0)
		data.encode_s16(i * 2, int(clampf(s * 0.75, -1.0, 1.0) * INT16_FULL_SCALE))
	return _stream(data, rate)


# --- The opener's link and the copy (C41). ---

const OPENER_CARRIER_S := 2.6
const OPENER_LOCK_S := 0.9
const OPENER_RISE_S := 4.2
const OPENER_STEP_S := 0.6


## The link: a carrier finding its line (an old modem's handshake, made here: a tone that sweeps, warbles between two
## pitches faster and faster, then settles into a soft steady hiss of data).
static func opener_carrier() -> AudioStreamWAV:
	var rate := LOW_RATE
	var count := int(OPENER_CARRIER_S * rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = NOISE_SEED + 50
	var phase := 0.0
	var hiss := 0.0
	for i in count:
		var t := float(i) / rate
		var u := t / OPENER_CARRIER_S
		var sweep := lerpf(420.0, 1800.0, smoothstep(0.0, 0.25, u))
		var warble := 1.0 + 0.22 * signf(sin(TAU * lerpf(4.0, 26.0, u) * t)) * smoothstep(0.2, 0.35, u)
		phase = fmod(phase + TAU * sweep * warble / rate, TAU)
		hiss = lerpf(hiss, rng.randf_range(-1.0, 1.0), 0.45)
		var tone := sin(phase) * (1.0 - smoothstep(0.62, 0.8, u))
		var noise := hiss * smoothstep(0.55, 0.75, u) * 0.6
		var envelope := minf(t * 60.0, 1.0) * (1.0 - smoothstep(0.85, 1.0, u))
		data.encode_s16(i * 2, int(clampf((tone * 0.45 + noise) * envelope, -1.0, 1.0) * INT16_FULL_SCALE))
	return _stream(data, rate)


## The link locking: two clean notes rising, a fifth apart, with a short shimmer after.
static func opener_lock() -> AudioStreamWAV:
	var rate := LOW_RATE
	var count := int(OPENER_LOCK_S * rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	var a := 0.0
	var b := 0.0
	for i in count:
		var t := float(i) / rate
		a = fmod(a + TAU * 660.0 / rate, TAU)
		b = fmod(b + TAU * 990.0 / rate, TAU)
		var first := sin(a) * exp(-t * 6.0) * minf(t * 300.0, 1.0)
		var second := (sin(b) + 0.3 * sin(b * 2.0)) * exp(-maxf(t - 0.12, 0.0) * 4.5) * (1.0 if t >= 0.12 else 0.0) * minf(maxf(t - 0.12, 0.0) * 300.0, 1.0)
		data.encode_s16(i * 2, int(clampf((first * 0.45 + second * 0.4), -1.0, 1.0) * INT16_FULL_SCALE))
	return _stream(data, rate)


## The copy rising: a low drone swelling up from nothing, a metal shimmer over it, beating against itself.
static func opener_rise() -> AudioStreamWAV:
	var rate := LOW_RATE
	var count := int(OPENER_RISE_S * rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = NOISE_SEED + 51
	var p1 := 0.0
	var p2 := 0.0
	var p3 := 0.0
	var grit := 0.0
	for i in count:
		var t := float(i) / rate
		var u := t / OPENER_RISE_S
		p1 = fmod(p1 + TAU * 41.0 / rate, TAU)
		p2 = fmod(p2 + TAU * 41.7 / rate, TAU)
		p3 = fmod(p3 + TAU * lerpf(310.0, 370.0, u) / rate, TAU)
		grit = lerpf(grit, rng.randf_range(-1.0, 1.0), 0.2)
		var drone := (sin(p1) + sin(p2)) * 0.5 + 0.3 * sin(p1 * 2.0)
		var shimmer := sin(p3 + 2.0 * sin(p1 * 7.0)) * 0.18 + grit * 0.08
		var swell := smoothstep(0.0, 0.6, u) * (1.0 - smoothstep(0.85, 1.0, u))
		data.encode_s16(i * 2, int(clampf((drone * 0.7 + shimmer) * swell, -1.0, 1.0) * INT16_FULL_SCALE))
	return _stream(data, rate)


## A step of the copy's: a heavy foot coming down on metal (a low knock and a clank ringing off).
static func opener_step() -> AudioStreamWAV:
	var rate := LOW_RATE
	var count := int(OPENER_STEP_S * rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = NOISE_SEED + 52
	var knock := 0.0
	var ring := 0.0
	var dark := 0.0
	for i in count:
		var t := float(i) / rate
		knock = fmod(knock + TAU * (52.0 + 60.0 * exp(-t * 22.0)) / rate, TAU)
		ring = fmod(ring + TAU * 437.0 / rate, TAU)
		dark = lerpf(dark, rng.randf_range(-1.0, 1.0), 0.12)
		var low := sin(knock) * exp(-t * 11.0)
		var clank := (sin(ring) + 0.5 * sin(ring * 2.76)) * exp(-t * 16.0) * 0.35
		var slap := dark * exp(-t * 45.0) * 1.6
		var attack := minf(t * 600.0, 1.0)
		data.encode_s16(i * 2, int(clampf((low * 0.8 + clank + slap) * attack, -1.0, 1.0) * INT16_FULL_SCALE))
	return _stream(data, rate)


## The daemons' and ICE's voices (C42; T1's footage found the arena's enemies near silent): each type's own tell,
## strike, hit and death, made here like every other sound, at LOW_RATE. rogue.d chitters, shrieks and slashes with a
## blade's ring; the zombie groans, booms and crumbles; the runaway's swarm buzzes, dives and bursts into a cascade of
## falling blips (a fork tree coming down); ICE rings like glass (a wall's low, a node's high and electric, the hunter's
## cobalt and metallic: its lock-on chirps and its lance's zap) and shatters. Peaks are normalised to DAEMON_PEAK, so
## no voice is harsh at full volume; scripts/daemons/daemon_voice.gd plays them, on the Effects bus.

## The kinds (DaemonArt.ai_kind) and what each says.
const DAEMON_KINDS := ["rogue", "zombie", "swarm", "barrier", "node", "hunter"]
const DAEMON_WHATS := ["tell", "strike", "hit", "death"]
const DAEMON_PEAK := 0.62


## Kind `kind`'s `what` ("tell", "strike", "hit" or "death"); a kind with no tell or strike of its own (a wall, a node)
## gets its hit for them, and an unknown kind rogue.d's.
static func daemon_voice(kind: String, what: String) -> AudioStreamWAV:
	var rate := LOW_RATE
	var rng := RandomNumberGenerator.new()
	rng.seed = NOISE_SEED + 300 + DAEMON_KINDS.find(kind) * 10 + DAEMON_WHATS.find(what)
	var key := kind if DAEMON_KINDS.has(kind) else "rogue"
	if (key == "barrier" or key == "node") and (what == "tell" or what == "strike"):
		what = "hit"
	var out := PackedFloat32Array()
	match key + ":" + what:
		"rogue:tell":
			# A rising chitter: a reedy tone climbing, chopped into clicks that quicken, louder all the way.
			out = _buffer(0.55, rate)
			var p := 0.0
			var chop := 0.0
			for i in out.size():
				var u := float(i) / out.size()
				var t := float(i) / rate
				p += TAU * (700.0 + 1300.0 * u * u) / rate
				chop += TAU * (24.0 + 26.0 * u) / rate
				var gate := pow(maxf(sin(chop), 0.0), 3.0)
				var reed := sin(p) + 0.45 * sin(p * 2.01 + sin(p * 0.5) * 2.0)
				out[i] = (reed * 0.7 + rng.randf_range(-1.0, 1.0) * 0.3) * gate * (0.25 + 0.75 * u) * minf(t * 40.0, 1.0) * minf((1.0 - u) * 30.0, 1.0)
		"rogue:strike":
			# The slash: a rush of air sweeping up through the blade's path, then its ring.
			out = _buffer(0.42, rate)
			var lp := 0.0
			var hp := 0.0
			var a := 0.0
			var b := 0.0
			for i in out.size():
				var t := float(i) / rate
				var u := float(i) / out.size()
				var n := rng.randf_range(-1.0, 1.0)
				var k := clampf(0.04 + 0.5 * u, 0.0, 0.95)
				lp += (n - lp) * k
				hp = lp - hp * 0.6
				a += TAU * 2310.0 / rate
				b += TAU * 3190.0 / rate
				var air := hp * sin(PI * clampf(t / 0.2, 0.0, 1.0)) * 1.4
				var ring := (sin(a) + 0.6 * sin(b)) * exp(-maxf(t - 0.12, 0.0) * 14.0) * smoothstep(0.1, 0.13, t) * 0.4
				out[i] = air + ring
		"rogue:hit":
			# Chitin cracking: a hard click, a short bright blip, and a glitch stuttering its tail.
			out = _buffer(0.2, rate)
			var p := 0.0
			for i in out.size():
				var t := float(i) / rate
				p += TAU * (1500.0 - 600.0 * t * 5.0) / rate
				var stutter := 1.0 if fmod(t * 55.0, 1.0) < 0.6 or t < 0.05 else 0.15
				out[i] = (rng.randf_range(-1.0, 1.0) * exp(-t * 90.0) * 1.2 + signf(sin(p)) * 0.35 * exp(-t * 18.0)) * stutter
		"rogue:death":
			# A shriek collapsing into a crunch: a bitcrushed tone falling away fast, noise grinding under it.
			out = _buffer(0.95, rate)
			var p := 0.0
			var crunch := 0.0
			for i in out.size():
				var t := float(i) / rate
				var u := float(i) / out.size()
				p += TAU * (1900.0 * pow(0.14, u)) / rate
				var tone := signf(sin(p)) * 0.5 + sin(p * 1.5) * 0.3
				tone = floorf(tone * 6.0) / 6.0
				crunch = lerpf(crunch, rng.randf_range(-1.0, 1.0), 0.35)
				out[i] = (tone * (1.0 - u) + crunch * (0.4 + 0.6 * u) * 0.8) * minf(t * 80.0, 1.0) * pow(1.0 - u, 1.4)
		"zombie:tell":
			# The bolt charging in its cannon arm: a low groan wavering up, an electric whine climbing over it.
			out = _buffer(0.85, rate)
			var g := 0.0
			var w := 0.0
			var lp := 0.0
			for i in out.size():
				var t := float(i) / rate
				var u := float(i) / out.size()
				g += TAU * (68.0 + 50.0 * u + 4.0 * sin(t * 31.0)) / rate
				w += TAU * (320.0 + 1100.0 * u * u) / rate
				var groan := fposmod(g / TAU, 1.0) * 2.0 - 1.0
				lp += (groan - lp) * 0.08
				out[i] = (lp * 1.6 + sin(w) * 0.25 * u) * minf(t * 10.0, 1.0) * minf((1.0 - u) * 25.0, 1.0)
		"zombie:strike":
			# The bolt fired: a heavy boom with a bitcrushed blast on it.
			out = _buffer(0.5, rate)
			var p := 0.0
			for i in out.size():
				var t := float(i) / rate
				p += TAU * (40.0 + 70.0 * exp(-t * 18.0)) / rate
				var blast := floorf(rng.randf_range(-1.0, 1.0) * 4.0) / 4.0 * exp(-t * 16.0)
				out[i] = sin(p) * exp(-t * 6.0) * 1.2 + blast * 0.7
		"zombie:hit":
			# Dull, heavy armour taking it: a clank of low inharmonic metal and a thud.
			out = _buffer(0.26, rate)
			var a := 0.0
			var b := 0.0
			var c := 0.0
			var d := 0.0
			for i in out.size():
				var t := float(i) / rate
				a += TAU * 182.0 / rate
				b += TAU * 263.0 / rate
				c += TAU * 397.0 / rate
				d += TAU * (60.0 + 40.0 * exp(-t * 30.0)) / rate
				out[i] = (sin(a) + 0.7 * sin(b) + 0.5 * sin(c)) * exp(-t * 17.0) * 0.5 + sin(d) * exp(-t * 14.0) + rng.randf_range(-1.0, 1.0) * exp(-t * 70.0) * 0.5
		"zombie:death":
			# A long groan falling, the body coming apart into rubble under it.
			out = _buffer(1.25, rate)
			var g := 0.0
			var rumble := 0.0
			for i in out.size():
				var t := float(i) / rate
				var u := float(i) / out.size()
				g += TAU * (110.0 * pow(0.36, u)) / rate
				var groan := fposmod(g / TAU, 1.0) * 2.0 - 1.0
				rumble = lerpf(rumble, rng.randf_range(-1.0, 1.0), 0.05)
				var clicks := rng.randf_range(-1.0, 1.0) * (1.0 if rng.randf() < 0.004 + 0.02 * u else 0.0)
				out[i] = (groan * 0.5 * (1.0 - u) + rumble * 2.6 * u + clicks * 0.8) * minf(t * 30.0, 1.0) * minf((1.0 - u) * 8.0, 1.0)
		"swarm:tell":
			# The swarm gathering: five detuned buzzing tones beating against each other, swelling and rising.
			out = _buffer(0.62, rate)
			var ph := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0])
			for i in out.size():
				var t := float(i) / rate
				var u := float(i) / out.size()
				var s := 0.0
				for k in 5:
					ph[k] = fposmod(ph[k] + (196.0 + 90.0 * u) * (1.0 + 0.013 * (k - 2)) / rate, 1.0)
					s += ph[k] * 2.0 - 1.0
				out[i] = s * 0.2 * (0.3 + 0.7 * u) * minf(t * 20.0, 1.0) * minf((1.0 - u) * 30.0, 1.0)
		"swarm:strike":
			# The dive: a whine dropping as it comes, the buzz under it.
			out = _buffer(0.42, rate)
			var p := 0.0
			var z := 0.0
			for i in out.size():
				var t := float(i) / rate
				var u := float(i) / out.size()
				p += TAU * (2300.0 * pow(0.22, u)) / rate
				z = fposmod(z + 150.0 / rate, 1.0)
				out[i] = (sin(p) * 0.6 + (z * 2.0 - 1.0) * 0.35) * minf(t * 60.0, 1.0) * (1.0 - u * 0.7)
		"swarm:hit":
			# High chirps scattering: three quick blips.
			out = _buffer(0.16, rate)
			var p := 0.0
			for i in out.size():
				var t := float(i) / rate
				var n := mini(floori(t / 0.05), 2)
				var local := t - n * 0.05
				p += TAU * [2600.0, 3150.0, 2250.0][n] / rate
				out[i] = sin(p) * exp(-local * 70.0) * (1.0 - 0.25 * n)
		"swarm:death":
			# The fork tree coming down: a pop, then a cascade of blips falling in pitch, faster and faster.
			out = _buffer(0.85, rate)
			var p := 0.0
			for i in out.size():
				var t := float(i) / rate
				var u := float(i) / out.size()
				var slot := floori(pow(u, 0.7) * 18.0)
				var local := fposmod(pow(u, 0.7) * 18.0, 1.0)
				p += TAU * (3200.0 * pow(0.1, slot / 18.0)) / rate
				var blip := signf(sin(p)) * 0.4 * exp(-local * 6.0)
				var pop := rng.randf_range(-1.0, 1.0) * exp(-t * 60.0) * 1.3
				out[i] = (blip + pop) * minf((1.0 - u) * 12.0, 1.0)
		"barrier:hit", "node:hit", "hunter:hit":
			# Glass ringing: three inharmonic partials, a wall's low, a node's high with a buzz, the hunter's metallic.
			out = _buffer(0.32, rate)
			var f := {"barrier": [1180.0, 1871.0, 2950.0], "node": [2090.0, 3310.0, 5150.0], "hunter": [880.0, 1430.0, 2210.0]}[key] as Array
			var a := 0.0
			var b := 0.0
			var c := 0.0
			for i in out.size():
				var t := float(i) / rate
				a += TAU * f[0] / rate
				b += TAU * f[1] / rate
				c += TAU * f[2] / rate
				var buzz := (signf(sin(t * TAU * 120.0)) * 0.15 * exp(-t * 20.0)) if key == "node" else 0.0
				out[i] = (sin(a) * exp(-t * 11.0) + 0.6 * sin(b) * exp(-t * 16.0) + 0.4 * sin(c) * exp(-t * 24.0)) * 0.6 + rng.randf_range(-1.0, 1.0) * exp(-t * 120.0) * 0.6 + buzz
		"barrier:death", "node:death", "hunter:death":
			# Shattering: a burst, then a cascade of glass pings at random pitches, thinning out; the hunter a low thud
			# under it, a node a falling zap.
			out = _buffer(1.05, rate)
			var low := 0.0
			var zap := 0.0
			for i in out.size():
				var t := float(i) / rate
				var s := rng.randf_range(-1.0, 1.0) * exp(-t * 14.0) * 0.8
				if key == "hunter":
					low += TAU * (55.0 + 50.0 * exp(-t * 20.0)) / rate
					s += sin(low) * exp(-t * 7.0) * 0.9
				elif key == "node":
					zap += TAU * (1800.0 * pow(0.08, minf(t / 0.5, 1.0))) / rate
					s += signf(sin(zap)) * 0.2 * exp(-t * 5.0)
				out[i] = s
			# Each ping only over its own quarter second.
			var ring := int(0.25 * rate)
			for k in 26:
				var from := int(rng.randf_range(0.0, 0.6) * rng.randf() * rate)
				var step := TAU * rng.randf_range(1700.0, 5200.0) / rate
				var level := rng.randf_range(0.3, 1.0) * 0.3
				var fall := exp(-22.0 / rate)
				var amp := level
				for j in mini(ring, out.size() - from):
					out[from + j] += sin(step * j) * amp
					amp *= fall
		"hunter:tell":
			# Locking on: three rising beeps, then the held tone of the lock.
			out = _buffer(0.7, rate)
			var p := 0.0
			for i in out.size():
				var t := float(i) / rate
				var n := mini(floori(t / 0.14), 3)
				var on := 1.0 if n == 3 or fposmod(t, 0.14) < 0.09 else 0.0
				p += TAU * [1180.0, 1480.0, 1760.0, 2210.0][n] / rate
				out[i] = (sin(p) * 0.7 + signf(sin(p)) * 0.15) * on * (0.5 if n == 3 else 1.0) * minf((0.7 - t) * 40.0, 1.0)
		"hunter:strike":
			# The lance: a hot zap tearing down, crackling.
			out = _buffer(0.4, rate)
			var p := 0.0
			for i in out.size():
				var t := float(i) / rate
				var u := float(i) / out.size()
				p += TAU * (3100.0 * pow(0.13, u)) / rate
				var saw := fposmod(p / TAU, 1.0) * 2.0 - 1.0
				out[i] = (saw * 0.55 + rng.randf_range(-1.0, 1.0) * 0.35 * (1.0 - u)) * minf(t * 200.0, 1.0) * pow(1.0 - u, 1.2)
		_:
			return daemon_voice("rogue", what)
	return _daemon_pcm(out, rate)


static func _buffer(seconds: float, rate: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(maxi(int(seconds * rate), 1))
	return out


## Floats to a 16-bit stream, its peak at DAEMON_PEAK and its very ends faded so nothing clicks.
static func _daemon_pcm(samples: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var peak := 0.0001
	for v in samples:
		peak = maxf(peak, absf(v))
	var scale := DAEMON_PEAK / peak
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	var edge := mini(int(rate * 0.004), samples.size() / 2)
	for i in samples.size():
		var fade := minf(1.0, minf(float(i + 1) / maxf(edge, 1.0), float(samples.size() - i) / maxf(edge, 1.0)))
		data.encode_s16(i * 2, int(clampf(samples[i] * scale * fade, -1.0, 1.0) * INT16_FULL_SCALE))
	return _stream(data, rate)


## The opener's forge and kill (C42): `kill -9` struck key by key (a heavy mechanical key with a teal zap on it), its
## letters charging (a rising electric hum), breaking into cells (a digital scatter), the rifle printing (a crackling
## sizzle climbing), locking into the hands (a heavy clack and a charge), and the copy's own keys as it types "you
## won't." (deeper, distorted). The shot is the rail's own fire (fire_zap) under the score's crack.
const FORGE_KEY_S := 0.22
const FORGE_CHARGE_S := 0.8
const FORGE_BREAK_S := 0.7
const FORGE_PRINT_S := 1.7
const FORGE_LOCK_S := 0.6
const COPY_KEY_S := 0.16


## A key of `kill -9` struck: a hard click, a thump, and a short teal zap falling; `variant` shifts its pitch a little.
static func opener_forge_key(variant: int) -> AudioStreamWAV:
	var rate := LOW_RATE
	var rng := RandomNumberGenerator.new()
	rng.seed = NOISE_SEED + 400 + variant
	var out := _buffer(FORGE_KEY_S, rate)
	var zap := 0.0
	var thump := 0.0
	var shift := 1.0 + 0.06 * (variant % 4)
	for i in out.size():
		var t := float(i) / rate
		zap += TAU * (2600.0 * shift * pow(0.25, minf(t / 0.12, 1.0))) / rate
		thump += TAU * (95.0 + 80.0 * exp(-t * 40.0)) / rate
		out[i] = rng.randf_range(-1.0, 1.0) * exp(-t * 260.0) * 1.3 + sin(thump) * exp(-t * 28.0) * 0.8 + signf(sin(zap)) * 0.22 * exp(-t * 22.0)
	return _daemon_pcm(out, rate)


## The letters charging: an electric hum climbing and swelling, crackling more as it goes.
static func opener_forge_charge() -> AudioStreamWAV:
	var rate := LOW_RATE
	var rng := RandomNumberGenerator.new()
	rng.seed = NOISE_SEED + 410
	var out := _buffer(FORGE_CHARGE_S, rate)
	var p := 0.0
	for i in out.size():
		var u := float(i) / out.size()
		p += TAU * (120.0 + 380.0 * u * u) / rate
		var hum := signf(sin(p)) * 0.3 + sin(p * 2.0) * 0.3
		var crackle := rng.randf_range(-1.0, 1.0) * (1.0 if rng.randf() < 0.02 + 0.2 * u else 0.0)
		out[i] = (hum + crackle * 0.8) * (0.2 + 0.8 * u * u) * minf((1.0 - u) * 60.0, 1.0)
	return _daemon_pcm(out, rate)


## The letters breaking into cells: a burst, then a scatter of tiny digital blips flying apart.
static func opener_forge_break() -> AudioStreamWAV:
	var rate := LOW_RATE
	var rng := RandomNumberGenerator.new()
	rng.seed = NOISE_SEED + 420
	var out := _buffer(FORGE_BREAK_S, rate)
	for i in out.size():
		var t := float(i) / rate
		out[i] = rng.randf_range(-1.0, 1.0) * exp(-t * 25.0)
	for k in 40:
		var from := int(rng.randf_range(0.0, 0.55) * rate)
		var step := TAU * rng.randf_range(900.0, 4200.0) / rate
		var level := rng.randf_range(0.15, 0.4)
		for j in mini(int(0.03 * rate), out.size() - from):
			out[from + j] += signf(sin(step * j)) * level * (1.0 - float(j) / (0.03 * rate))
	return _daemon_pcm(out, rate)


## The rifle printing: a sizzle of sparks, thicker and higher as the print runs down the barrel.
static func opener_forge_print() -> AudioStreamWAV:
	var rate := LOW_RATE
	var rng := RandomNumberGenerator.new()
	rng.seed = NOISE_SEED + 430
	var out := _buffer(FORGE_PRINT_S, rate)
	var lp := 0.0
	var p := 0.0
	for i in out.size():
		var u := float(i) / out.size()
		var n := rng.randf_range(-1.0, 1.0)
		lp += (n - lp) * (0.2 + 0.6 * u)
		p += TAU * (300.0 + 900.0 * u) / rate
		var spark := n * (1.0 if rng.randf() < 0.03 + 0.08 * u else 0.0)
		out[i] = (lp * 0.35 + spark * 0.9 + sin(p) * 0.08) * minf(u * 20.0, 1.0) * minf((1.0 - u) * 15.0, 1.0)
	return _daemon_pcm(out, rate)


## The rifle locking into the hands: a heavy metal clack, its ring, and a charge winding up under it.
static func opener_forge_lock() -> AudioStreamWAV:
	var rate := LOW_RATE
	var rng := RandomNumberGenerator.new()
	rng.seed = NOISE_SEED + 440
	var out := _buffer(FORGE_LOCK_S, rate)
	var a := 0.0
	var b := 0.0
	var w := 0.0
	for i in out.size():
		var t := float(i) / rate
		a += TAU * 211.0 / rate
		b += TAU * 557.0 / rate
		w += TAU * (200.0 + 1400.0 * minf(t / FORGE_LOCK_S, 1.0)) / rate
		var clack := rng.randf_range(-1.0, 1.0) * exp(-t * 120.0) * 1.2 + (sin(a) + 0.6 * sin(b)) * exp(-t * 18.0) * 0.6
		var second := rng.randf_range(-1.0, 1.0) * exp(-maxf(t - 0.07, 0.0) * 140.0) * (1.0 if t > 0.07 else 0.0) * 0.9
		out[i] = clack + second + sin(w) * 0.12 * minf(t * 4.0, 1.0)
	return _daemon_pcm(out, rate)


## A key under the copy's hand: deeper than the player's, a little distorted, with a low hum behind it.
static func opener_copy_key(variant: int) -> AudioStreamWAV:
	var rate := LOW_RATE
	var rng := RandomNumberGenerator.new()
	rng.seed = NOISE_SEED + 450 + variant
	var out := _buffer(COPY_KEY_S, rate)
	var p := 0.0
	var lp := 0.0
	for i in out.size():
		var t := float(i) / rate
		p += TAU * (70.0 + 10.0 * (variant % 3)) / rate
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.3
		out[i] = tanh((lp * exp(-t * 90.0) * 3.0 + sin(p) * exp(-t * 20.0) * 0.8) * 2.0)
	return _daemon_pcm(out, rate)
