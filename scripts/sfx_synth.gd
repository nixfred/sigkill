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


## Player volume in dB for a linear master volume from 0 to 1.
static func volume_db(linear: float) -> float:
	return linear_to_db(linear) if linear > 0.0 else SILENT_DB


## Fire: a laser zap that sweeps down in pitch, with a little noise, dying fast.
static func fire_zap(w: Weapon) -> AudioStreamWAV:
	return _render(w, w.fire_sfx_seconds, w.fire_start_hz, w.fire_end_hz, w.fire_decay, w.fire_noise, 0.0, w.fire_gain)


## Hit: two bright tones at once, very short, so a hit sounds different from a shot.
static func hit_blip(w: Weapon) -> AudioStreamWAV:
	return _render(w, w.hit_sfx_seconds, w.hit_hz, w.hit_hz, w.hit_decay, 0.0, w.hit_second_ratio, w.hit_gain)


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
