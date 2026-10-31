class_name OpenerScore
extends RefCounted
## The opener's score (C42; PRD 5.7: "Music and SFX original"): an original track made here in code, note by note, from
## nothing (no sample, loop or recording of anyone's), Doom's heavy metal crossed with the dark synths of a cyberpunk
## Matrix: down-tuned guitars chugging under a double kick, over dark pads and glitching arpeggios. 150 beats a minute,
## E minor. Four parts, each a stream played on the Music bus (so the Music and Master volumes rule it):
##   "bed"      from BED_AT (as the terminal shrinks away) to the forge, 34 bars: a dark pad swelling over a sub as the
##              machine is revealed; a glitching arpeggio through the fall, a muted four-on-the-floor building under it;
##              a pulsing bass and the signal's bell motif under the link; a dissonant cluster, a heartbeat and a
##              tremolo of beating tones as the copy walks up; sucked out to silence just before the forge.
##   "forge"    from the forge (FORGE_BARS bars): palm-muted chugs under the typing of `kill -9` (each key on an
##              eighth), a riser and a snare roll as its letters break up and stream into the rifle, the four coils as
##              four rising tones on the last four sixteenths, then the drop as the rifle locks into the hands: the riff,
##              doubled guitars wide, double kick, snare on two and four; then, as the copy types, it cuts to one
##              ringing chord and a heartbeat.
##   "wait"     a two-bar loop from the end of the forge until the shot: muted chugs, a heartbeat, a tremolo; the shot
##              is on its sixteenth grid.
##   "stinger"  from the shot: the rail's crack and a sub boom, the derezz crumbling, the kill feed's stamp, the whisper
##              ("one of 6666") over a low tritone, dead silence at the black, a reverse swell into the title's slam on
##              beat SLAM_BEATS (the riff again for two bars, the final chord ringing out).
## Made once a run on a worker thread (begin(), as the opener starts: about forty seconds before the bed is needed, so no
## frame ever waits on it), then kept: a replay plays it at once. A note that repeats is made once and mixed in again.
## Each part brought to its own loudness (LOUDNESS, the RMS of what sounds), its peaks rounded off under full scale, so
## none is harsh at full volume. Deterministic: the same notes, the same noise, every run.

const RATE := 32000
const BEAT_S := 0.4
const STEP_S := 0.1
const BAR_S := 1.6
## Where the bed starts on the opener's clock, and each part's length in bars.
const BED_AT := 40.0
const BED_BARS := 34
const FORGE_BARS := 6
const WAIT_BARS := 2
## The stinger: its length; when (beats from the shot) the derezz, the kill feed, the whisper, the black and the slam
## land; and the slam's riff, two bars, then the final chord.
const STINGER_S := 11.2
const DEREZZ_BEATS := 1.0
const FEED_BEATS := 3.0
const WHISPER_BEATS := 6.0
const BLACK_BEATS := 11.0
const SLAM_BEATS := 13.0
## The forge's moments in sixteenths from its start: the keys of `kill -9` (an eighth each, from the second eighth),
## the letters breaking, the coils, the drop, the dare.
const FORGE_KEYS_FROM := 2
const FORGE_BREAK := 24
const FORGE_COILS := 44
const FORGE_DROP := 48
const FORGE_DARE := 80
## The whisper's words.
const WHISPER := "one of 6666"
## Each part's loudness (the RMS of its sounding samples, of full scale).
const LOUDNESS := {"bed": 0.075, "forge": 0.14, "wait": 0.085, "stinger": 0.13}
const PARTS := ["bed", "forge", "wait", "stinger"]
## The pad's notes: a bar and the crossfade into the next; the sub under it (a whole number of cycles a bar, so a bar
## follows a bar seamlessly).
const PAD_S := 1.95
const SUB_HZ := 41.25

## E minor, as MIDI notes: the pad's four chords (one a bar), the copy's cluster, the riff's roots.
const CHORDS := [[52, 59, 66, 67], [48, 55, 59, 64], [45, 52, 59, 60], [47, 54, 57, 60]]
const CLUSTER := [52, 53, 59, 60]
const ARP := [[64, 67, 71, 74, 76, 74, 71, 67], [60, 64, 67, 71, 72, 71, 67, 64], [57, 60, 64, 67, 69, 67, 64, 60], [59, 63, 66, 69, 71, 69, 66, 63]]
## Riffs: [sixteenth, length in sixteenths, root (MIDI), open (else palm-muted)] a bar.
const DROP_RIFF := [
	[[0, 1, 40, false], [1, 1, 40, false], [2, 1, 40, false], [3, 1, 40, false], [4, 1, 40, false], [5, 1, 40, false], [6, 2, 41, true], [8, 1, 40, false], [9, 1, 40, false], [10, 1, 40, false], [11, 1, 40, false], [12, 2, 43, true], [14, 2, 46, true]],
	[[0, 1, 40, false], [1, 1, 40, false], [2, 1, 40, false], [3, 1, 40, false], [4, 2, 45, true], [6, 2, 43, true], [8, 1, 40, false], [9, 1, 40, false], [10, 2, 41, true], [12, 4, 40, true]],
]
const SLAM_RIFF := [
	[[0, 2, 40, true], [2, 1, 40, false], [3, 1, 40, false], [4, 2, 43, true], [6, 1, 40, false], [7, 1, 40, false], [8, 2, 46, true], [10, 1, 40, false], [11, 1, 40, false], [12, 2, 45, true], [14, 2, 43, true]],
	[[0, 1, 40, false], [1, 1, 40, false], [2, 1, 40, false], [3, 1, 40, false], [4, 1, 40, false], [5, 1, 40, false], [6, 1, 40, false], [7, 1, 40, false], [8, 1, 41, false], [9, 1, 41, false], [10, 1, 41, false], [11, 1, 41, false], [12, 2, 43, true], [14, 2, 41, true]],
]
const SEED := 4242

static var _streams := {}
static var _job: OpenerScore = null
static var _task := -1

## The part being made: its name, its two channels, whether it loops; what was made from the notes (cached tones).
var _part := ""
var _l := PackedFloat32Array()
var _r := PackedFloat32Array()
var _loop := false
var _rng := RandomNumberGenerator.new()
var _tones := {}
var _parts := {}


# --- What the opener asks. ---

## Starts making the score on a worker thread, if it is not made or being made.
static func begin() -> void:
	if done() or _task >= 0:
		return
	_job = OpenerScore.new()
	_task = WorkerThreadPool.add_task(_job._make_all, false, "opener score")


## Takes the parts in once the worker is through (the opener calls this each frame). True once done.
static func collect() -> bool:
	if done():
		return true
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_streams = _job._parts
		_job = null
	return done()


## Part `part`'s stream once it is made, else null.
static func stream(part: String) -> AudioStreamWAV:
	return _streams.get(part)


## True once every part is made.
static func done() -> bool:
	return _streams.size() == PARTS.size()


## Everything now (the checks and the tools): waits for the worker, or makes it here.
static func make_all() -> void:
	if done():
		return
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_streams = _job._parts
		_job = null
		return
	var job := OpenerScore.new()
	job._make_all()
	_streams = job._parts


## Forgets every part (the checks), once no worker is making them.
static func forget() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	_streams = {}
	_job = null


## A part's length in seconds as made.
static func part_seconds(part: String) -> float:
	match part:
		"bed":
			return BED_BARS * BAR_S
		"forge":
			return FORGE_BARS * BAR_S
		"wait":
			return WAIT_BARS * BAR_S
	return STINGER_S


# --- The making. ---

func _init() -> void:
	_rng.seed = SEED


func _make_all() -> void:
	for part in PARTS:
		_begin(part)
		match part:
			"bed":
				_bed()
			"forge":
				_forge()
			"wait":
				_wait()
			"stinger":
				_stinger()
		_parts[part] = _to_stream(_l, _r, _loop, LOUDNESS[part])


func _begin(part: String) -> void:
	_part = part
	var n := int(part_seconds(part) * RATE)
	_l = PackedFloat32Array()
	_l.resize(n)
	_r = PackedFloat32Array()
	_r.resize(n)
	_loop = part == "wait"


## Floats to a 16-bit stereo stream at `loudness` (the RMS of its sounding samples), its peaks rounded off.
func _to_stream(left: PackedFloat32Array, right: PackedFloat32Array, looped: bool, loudness: float) -> AudioStreamWAV:
	var sum := 0.0
	var count := 0
	for i in range(0, left.size(), 4):
		var a := absf(left[i]) + absf(right[i])
		if a > 0.0002:
			sum += left[i] * left[i] + right[i] * right[i]
			count += 2
	var gain := loudness / maxf(sqrt(sum / maxf(count, 1)), 0.000001)
	var data := PackedByteArray()
	data.resize(left.size() * 4)
	for i in left.size():
		data.encode_s16(i * 4, int(_soft(left[i] * gain) * 32767.0))
		data.encode_s16(i * 4 + 2, int(_soft(right[i] * gain) * 32767.0))
	var out := AudioStreamWAV.new()
	out.format = AudioStreamWAV.FORMAT_16_BITS
	out.mix_rate = RATE
	out.stereo = true
	out.data = data
	if looped:
		out.loop_mode = AudioStreamWAV.LOOP_FORWARD
		out.loop_begin = 0
		out.loop_end = left.size()
	return out


## A gentle ceiling: straight through until near the peak, then rounded off under full scale.
static func _soft(x: float) -> float:
	var a := absf(x)
	if a < 0.7:
		return x
	return signf(x) * (0.7 + 0.29 * tanh((a - 0.7) / 0.29))


static func _hz(note: float) -> float:
	return 440.0 * pow(2.0, (note - 69.0) / 12.0)


# --- The parts. ---

func _bed() -> void:
	for bar in BED_BARS:
		var at := bar * BAR_S
		var chord := bar % 4 if bar < 27 else 4
		# The pad and the sub under it: swelling in over the reveal, brightest through the fall, dark for the copy, gone
		# by the forge.
		var level := smoothstep(-0.5, 5.0, bar) * (0.75 if bar < 27 else 0.6) * (1.0 - smoothstep(32.0, 33.6, bar))
		var bright := 0.25 + 0.5 * smoothstep(5.0, 16.0, bar) - 0.35 * smoothstep(17.0, 19.0, bar) - 0.15 * smoothstep(26.0, 28.0, bar)
		_pad(at, chord, level, bright, (0.32 * smoothstep(0.0, 3.0, bar)) if bar < 33 else 0.0)
		# The fall: the arpeggio, a sixteenth at a time, ping-ponging, glitching at every second bar's end.
		if bar >= 6 and bar < 18:
			var notes: Array = ARP[bar % 4]
			for s in 16:
				var glitch := bar % 2 == 1 and s >= 12
				var note: int = notes[s % 8] + (12 if glitch and s % 2 == 1 else 0)
				_arp(at + s * STEP_S, note, 0.22 * smoothstep(5.5, 9.0, bar), s % 2, glitch)
				if glitch:
					_arp(at + s * STEP_S + STEP_S * 0.5, note, 0.16, (s + 1) % 2, true)
		# A muted four-on-the-floor building under the fall, and its hats; a riser into the landing.
		if bar >= 10 and bar < 17:
			for b in 4:
				_kick(at + b * BEAT_S, 0.35 + 0.05 * (bar - 10), false)
				_hat(at + b * BEAT_S + BEAT_S * 0.5, 0.12)
		if bar == 17:
			_riser(at, BAR_S, 0.35)
		# The link: a pulsing bass on the eighths, the signal's bell motif.
		if bar >= 18 and bar < 27:
			for e in 8:
				_bass(at + e * BEAT_S * 0.5, 40, 0.28 * smoothstep(18.0, 20.0, bar))
			if bar % 2 == 0:
				for k in 3:
					_bell(at + k * BEAT_S * 0.75, [76, 71, 79][k], 0.2)
		# The copy: a heartbeat (lub-dub) twice a bar, a tremolo of two beating tones over the cluster.
		if bar >= 27 and bar < 33:
			for beat in [0.0, BEAT_S * 2.0]:
				_kick(at + beat, 0.5 + 0.06 * (bar - 27), true)
				_kick(at + beat + 0.22, 0.32 + 0.04 * (bar - 27), true)
			_tremolo(at, BAR_S, 88, 89, 0.06 + 0.02 * (bar - 27))
		if bar == 33:
			_swell(at, BAR_S - 0.08, 0.3)


func _forge() -> void:
	for s in FORGE_BARS * 16:
		var at := s * STEP_S
		if s < 32:
			# Bars 0 and 1: the chug under the typing, a kick on one and three.
			if s % 2 == 0 and (s < 16 or s % 4 != 2 or s >= 24):
				_guitar(at, 1.5, 40, false, 0.4 + 0.2 * s / 32.0)
			if s % 8 == 0:
				_kick(at, 0.75, false)
			if s == 24:
				_snare(at, 0.5)
		elif s < FORGE_COILS:
			# The snare roll, eighths then sixteenths, louder; the chugs on every sixteenth.
			if s % 2 == 0 or s >= 40:
				_snare(at, 0.25 + 0.4 * (s - 32) / 12.0)
			_guitar(at, 1.0, 40, false, 0.55 + 0.3 * (s - 32) / 12.0)
		elif s < FORGE_DROP:
			# The four coils: four rising tones.
			_bell(at, [76, 79, 83, 88][s - FORGE_COILS], 0.45)
		elif s == FORGE_DARE:
			# The dare: one chord left ringing, a heartbeat under the copy's typing.
			_guitar(at, 16.0, 40, true, 0.7)
			for b in [0.0, 0.22, 0.8, 1.02]:
				_kick(at + b, 0.55 if b < 0.5 else 0.4, true)
	_riser(BAR_S, BAR_S * 2.0 - 0.4, 0.55)
	# The drop: two bars of the riff over a double kick.
	var drop := FORGE_DROP * STEP_S
	_riff(drop, DROP_RIFF, 1.0)
	_drums(drop, 2, 1.0)


func _wait() -> void:
	for s in WAIT_BARS * 16:
		var at := s * STEP_S
		if s % 2 == 0:
			_guitar(at, 1.4, 40, false, 0.42 if s % 8 != 0 else 0.55)
		if s % 4 == 0:
			_kick(at, 0.45, true)
		_hat(at, 0.05 if s % 2 == 1 else 0.08)
	_tremolo(0.0, WAIT_BARS * BAR_S, 76, 77, 0.08)


func _stinger() -> void:
	_impact(0.0)
	_crumble(DEREZZ_BEATS * BEAT_S, 1.6)
	_stamp(FEED_BEATS * BEAT_S)
	_whisper(WHISPER_BEATS * BEAT_S)
	_drone(WHISPER_BEATS * BEAT_S - 0.3, (BLACK_BEATS - WHISPER_BEATS) * BEAT_S + 0.25, 0.25)
	var slam := SLAM_BEATS * BEAT_S
	_swell(slam - 0.6, 0.6, 0.55)
	_crash(slam, 0.9)
	_sub_drop(slam, 1.6)
	_riff(slam, SLAM_RIFF, 1.0)
	_drums(slam, 2, 1.0)
	var end := slam + 2.0 * BAR_S
	var ring := (STINGER_S - end - 0.2) / STEP_S
	_guitar(end, ring, 40, true, 1.0)
	_kick(end, 1.0, false)
	_crash(end, 0.8)
	_pad(end, 0, 0.45, 0.3, 0.0, STINGER_S - end - 0.1)


## A riff's bars from `at`, doubled (each guitar its own take, a little apart), the bass under each bar.
func _riff(at: float, bars: Array, level: float) -> void:
	for b in bars.size():
		for n in bars[b]:
			var when: float = at + b * BAR_S + n[0] * STEP_S
			var steps: float = n[1] * (0.95 if n[3] else 1.2)
			_guitar(when, steps, n[2], n[3], level * (0.95 if n[3] else 0.85))
		for e in 8:
			_bass(at + b * BAR_S + e * BEAT_S * 0.5, 28, 0.35)


## Bars of metal drums from `at`: a double kick on every sixteenth, the snare on two and four, a crash on each one.
func _drums(at: float, bars: int, level: float) -> void:
	for b in bars:
		var bar := at + b * BAR_S
		_crash(bar, 0.7 * level)
		for s in 16:
			_kick(bar + s * STEP_S, (0.62 if s % 4 == 0 else 0.5) * level, false)
			if s % 2 == 0:
				_hat(bar + s * STEP_S, 0.1 * level)
		for beat in [1, 3]:
			_snare(bar + beat * BEAT_S, 0.85 * level)


# --- Mixing: a tone made once (its two channels) added in at `at`, scaled. ---

func _mix(tone: Array, at: float, gain: float) -> void:
	var tl: PackedFloat32Array = tone[0]
	var tr: PackedFloat32Array = tone[1]
	var from := int(at * RATE)
	var n := _l.size()
	if _loop:
		for j in tl.size():
			var k := posmod(from + j, n)
			_l[k] += tl[j] * gain
			_r[k] += tr[j] * gain
		return
	var count := mini(tl.size(), n - from)
	for j in count:
		_l[from + j] += tl[j] * gain
		_r[from + j] += tr[j] * gain


## A tone of `seconds`, empty, its two channels.
static func _tone(seconds: float) -> Array:
	var l := PackedFloat32Array()
	l.resize(maxi(int(seconds * RATE), 1))
	var r := PackedFloat32Array()
	r.resize(l.size())
	return [l, r]


## The tone named `key`, made by `make` the first time.
func _cached(key: String, make: Callable) -> Array:
	if not _tones.has(key):
		_tones[key] = make.call()
	return _tones[key]


# --- The instruments. ---

## A down-tuned guitar's power chord (root, fifth, octave) through a drive and a cabinet: palm-muted (short, dark,
## chugging) or open (ringing, brighter), `steps` sixteenths long. Doubled: the left and right takes detuned and a few
## milliseconds apart.
func _guitar(at: float, steps: float, root: int, open: bool, level: float) -> void:
	var key := "g%d%s%d" % [root, "o" if open else "m", roundi(steps * 10.0)]
	_mix(_cached(key, _make_guitar.bind(steps * STEP_S, root, open)), at, level)


func _make_guitar(seconds: float, root: int, open: bool) -> Array:
	var tail := 0.5 if open else 0.06
	var tone := _tone(seconds + tail + 0.006)
	var cut := 0.42 if open else 0.12
	var drive := 9.0 if open else 6.0
	for side in 2:
		var out: PackedFloat32Array = tone[side]
		var other: PackedFloat32Array = tone[1 - side]
		var offset := int(0.004 * side * RATE)
		var detune := 1.0 + (0.0024 if side == 0 else -0.0021)
		var f0 := _hz(root) * detune / RATE
		var f1 := _hz(root + 7) * detune * 1.001 / RATE
		var f2 := _hz(root + 12) * detune * 0.999 / RATE
		var p0 := 0.13 * side
		var p1 := 0.41
		var p2 := 0.77
		var hp := 0.0
		var hp_in := 0.0
		var lp1 := 0.0
		var lp2 := 0.0
		for j in out.size() - offset:
			var t := float(j) / RATE
			p0 = fposmod(p0 + f0, 1.0)
			p1 = fposmod(p1 + f1, 1.0)
			p2 = fposmod(p2 + f2, 1.0)
			var x := (p0 + p1 + p2) * 2.0 - 3.0
			# Tighten the lows before the drive, as a player's pedal does.
			hp = 0.97 * (hp + x - hp_in)
			hp_in = x
			var env: float
			if open:
				env = minf(t * 400.0, 1.0) * (exp(-t * 1.6) * 0.8 + 0.2)
			else:
				env = minf(t * 500.0, 1.0) * exp(-t * 16.0)
			env *= 1.0 - smoothstep(seconds, seconds + tail, t)
			var y := tanh(hp * drive * env)
			lp1 += (y - lp1) * cut
			lp2 += (lp1 - lp2) * cut
			out[j + offset] += lp2 * 0.5
			other[j + offset] += lp2 * 0.09
	return tone


func _bass(at: float, note: int, level: float) -> void:
	_mix(_cached("b%d" % note, _make_bass.bind(note)), at, level)


func _make_bass(note: int) -> Array:
	var seconds := BEAT_S * 0.45
	var tone := _tone(seconds + 0.05)
	var f := _hz(note) / RATE
	var ph := 0.0
	var lp := 0.0
	for j in tone[0].size():
		var t := float(j) / RATE
		ph = fposmod(ph + f, 1.0)
		lp += (ph * 2.0 - 1.0 - lp) * 0.06
		var v := (lp * 0.7 + sin(TAU * ph) * 0.6) * minf(t * 300.0, 1.0) * exp(-t * 3.0) * (1.0 - smoothstep(seconds, seconds + 0.05, t))
		tone[0][j] = v
		tone[1][j] = v
	return tone


## The pad: chord `chord` (CHORDS, or 4: the copy's cluster) as two detuned saws a tone through a filter `bright` open,
## swelling in and out over its note; the sub under it at `sub` for the bar's own length. The saws are made once a
## chord; the filter, the swell and the levels each time.
func _pad(at: float, chord: int, level: float, bright: float, sub: float, seconds: float = PAD_S) -> void:
	if level <= 0.001 and sub <= 0.001:
		return
	var raw := _cached("pad%d" % chord, _make_pad.bind(chord))
	var rl: PackedFloat32Array = raw[0]
	var rr: PackedFloat32Array = raw[1]
	var from := int(at * RATE)
	var count := mini(mini(int(seconds * RATE), rl.size()), _l.size() - from)
	var bar := int(BAR_S * RATE)
	var cut := clampf(0.02 + 0.12 * bright, 0.01, 0.3)
	var gain := level * 0.16
	var lp_l := 0.0
	var lp_r := 0.0
	for j in count:
		var t := float(j) / RATE
		lp_l += (rl[j] - lp_l) * cut
		lp_r += (rr[j] - lp_r) * cut
		var env := smoothstep(0.0, 0.35, t) * (1.0 - smoothstep(seconds - 0.35, seconds, t)) * gain
		var low := sin(TAU * SUB_HZ * t) * sub if j < bar else 0.0
		_l[from + j] += lp_l * env + low
		_r[from + j] += lp_r * env + low


func _make_pad(chord: int) -> Array:
	var notes: Array = CHORDS[chord] if chord < CHORDS.size() else CLUSTER
	var tone := _tone(PAD_S)
	var steps := PackedFloat32Array()
	var phases := PackedFloat32Array()
	for note in notes:
		for d in [-0.004, 0.0045]:
			steps.append(_hz(note) * (1.0 + d) / RATE)
			phases.append(_rng.randf())
	var tl: PackedFloat32Array = tone[0]
	var tr: PackedFloat32Array = tone[1]
	for j in tl.size():
		var l := 0.0
		var r := 0.0
		for k in steps.size():
			var p := fposmod(phases[k] + steps[k] * j, 1.0) * 2.0 - 1.0
			if k % 2 == 0:
				l += p
			else:
				r += p
		tl[j] = l
		tr[j] = r
	return tone


## A glitching arpeggio note: a narrow pulse crushed to a few bits, short, on one side.
func _arp(at: float, note: int, level: float, side: int, glitch: bool) -> void:
	var tone := _cached("a%d%s" % [note, "g" if glitch else ""], _make_arp.bind(note, glitch))
	_mix([tone[side], tone[1 - side]], at, level)


func _make_arp(note: int, glitch: bool) -> Array:
	var seconds := STEP_S * (0.5 if glitch else 0.9)
	var tone := _tone(seconds)
	var f := _hz(note) / RATE
	var ph := 0.0
	var bits := 4.0 if glitch else 7.0
	for j in tone[0].size():
		var t := float(j) / RATE
		ph = fposmod(ph + f, 1.0)
		var s := roundf((1.0 if ph < 0.28 else -0.6) * exp(-t * 14.0) * bits) / bits
		var v := s * (1.0 - smoothstep(seconds - 0.01, seconds, t))
		tone[0][j] = v
		tone[1][j] = v * 0.35
	return tone


## A bell: a sine and an inharmonic partial, ringing, with two echoes a dotted eighth apart, across the stereo.
func _bell(at: float, note: int, level: float) -> void:
	var tone := _cached("bell%d" % note, _make_bell.bind(note))
	for echo in 3:
		var swap := echo % 2 == 1
		_mix([tone[1] if swap else tone[0], tone[0] if swap else tone[1]], at + echo * 0.3, level * pow(0.45, echo))


func _make_bell(note: int) -> Array:
	var tone := _tone(0.9)
	var f := _hz(note)
	for j in tone[0].size():
		var t := float(j) / RATE
		var v := (sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.76 * t)) * exp(-t * 3.5) * minf(t * 900.0, 1.0) * minf((0.9 - t) * 20.0, 1.0)
		tone[0][j] = v
		tone[1][j] = v * 0.6
	return tone


## Two tones a semitone apart, beating, trembling at eight a second.
func _tremolo(at: float, seconds: float, a: int, b: int, level: float) -> void:
	var tone := _cached("tr%d_%d_%d" % [a, b, roundi(seconds * 10.0)], _make_tremolo.bind(seconds, a, b))
	_mix(tone, at, level)


func _make_tremolo(seconds: float, a: int, b: int) -> Array:
	var tone := _tone(seconds)
	var fa := _hz(a)
	var fb := _hz(b)
	for j in tone[0].size():
		var t := float(j) / RATE
		var env := smoothstep(0.0, 0.2, t) * (1.0 - smoothstep(seconds - 0.2, seconds, t))
		var v := (sin(TAU * fa * t) + sin(TAU * fb * t)) * (0.6 + 0.4 * sin(TAU * 8.0 * t)) * env
		tone[0][j] = v
		tone[1][j] = v * 0.9
	return tone


## A kick: a falling sine and its click; `soft` a heartbeat's (rounder, no click).
func _kick(at: float, level: float, soft: bool) -> void:
	_mix(_cached("ks" if soft else "k", _make_kick.bind(soft)), at, level)


func _make_kick(soft: bool) -> Array:
	var tone := _tone(0.35 if soft else 0.22)
	var ph := 0.0
	for j in tone[0].size():
		var t := float(j) / RATE
		ph += TAU * (48.0 + (70.0 if soft else 120.0) * exp(-t * (18.0 if soft else 32.0))) / RATE
		var v := sin(ph) * exp(-t * (9.0 if soft else 14.0)) * minf((tone[0].size() - j) / 200.0, 1.0)
		if not soft:
			v += _rng.randf_range(-1.0, 1.0) * exp(-t * 400.0) * 0.6
		tone[0][j] = v
		tone[1][j] = v
	return tone


## A snare: its body's two tones and a burst of bright noise, with a short room after it.
func _snare(at: float, level: float) -> void:
	_mix(_cached("s", _make_snare), at, level)


func _make_snare() -> Array:
	var tone := _tone(0.36)
	for tap in [[0.0, 1.0, 1.0, 1.0], [0.023, 0.28, 0.7, 1.0], [0.041, 0.2, 1.0, 0.7], [0.067, 0.14, 0.7, 1.0]]:
		var from := int(tap[0] * RATE)
		var last := 0.0
		for j in int(0.28 * RATE):
			var t := float(j) / RATE
			var n := _rng.randf_range(-1.0, 1.0)
			var bright := n - last
			last = n
			var v: float = ((sin(TAU * 185.0 * t) + 0.6 * sin(TAU * 330.0 * t)) * exp(-t * 26.0) * 0.5 + bright * exp(-t * 16.0) * 0.7) * tap[1]
			tone[0][from + j] += v * tap[2]
			tone[1][from + j] += v * tap[3]
	return tone


func _hat(at: float, level: float) -> void:
	_mix(_cached("h", _make_hat), at, level)


func _make_hat() -> Array:
	var tone := _tone(0.06)
	var last := 0.0
	for j in tone[0].size():
		var t := float(j) / RATE
		var n := _rng.randf_range(-1.0, 1.0)
		var v := (n - last) * exp(-t * 70.0)
		last = n
		tone[0][j] = v * 0.8
		tone[1][j] = v
	return tone


## A crash: bright noise and six clashing square partials, ringing out.
func _crash(at: float, level: float) -> void:
	_mix(_cached("c", _make_crash), at, level)


func _make_crash() -> Array:
	var tone := _tone(2.2)
	var parts := PackedFloat32Array([313.0, 461.0, 587.0, 743.0, 911.0, 1199.0])
	var last := 0.0
	for j in tone[0].size():
		var t := float(j) / RATE
		var n := _rng.randf_range(-1.0, 1.0)
		var metal := 0.0
		for f in parts:
			metal += 1.0 if fposmod(f * 3.1 * t, 1.0) < 0.5 else -1.0
		var v := ((n - last) * 0.8 + metal * 0.05) * exp(-t * 2.2) * minf(t * 2000.0, 1.0) * 0.6
		last = n
		tone[0][j] = v
		tone[1][j] = v * 0.92
	return tone


## Noise rising into a moment, and a saw climbing with it.
func _riser(at: float, seconds: float, level: float) -> void:
	var tone := _tone(seconds)
	var lp := 0.0
	var ph := 0.0
	for j in tone[0].size():
		var t := float(j) / RATE
		var u := t / seconds
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * (0.03 + 0.6 * u * u)
		ph = fposmod(ph + (110.0 + 880.0 * u * u) / RATE, 1.0)
		var v := (lp * 1.4 + (ph * 2.0 - 1.0) * 0.25) * u * u
		tone[0][j] = v
		tone[1][j] = v
	_mix(tone, at, level)


## A reversed cymbal: bright noise swelling to its peak at the end and cut there.
func _swell(at: float, seconds: float, level: float) -> void:
	var tone := _tone(seconds)
	var last := 0.0
	for j in tone[0].size():
		var t := float(j) / RATE
		var n := _rng.randf_range(-1.0, 1.0)
		var v := (n - last) * pow(t / seconds, 3.0)
		last = n
		tone[0][j] = v
		tone[1][j] = v
	_mix(tone, at, level)


## The rail's shot: a crack, a zap tearing down, a sub boom, and a crash.
func _impact(at: float) -> void:
	var tone := _tone(1.6)
	var zap := 0.0
	var boom := 0.0
	var last := 0.0
	for j in tone[0].size():
		var t := float(j) / RATE
		var n := _rng.randf_range(-1.0, 1.0)
		zap = fposmod(zap + (4200.0 * pow(0.05, minf(t / 0.28, 1.0))) / RATE, 1.0)
		boom += TAU * (34.0 + 60.0 * exp(-t * 9.0)) / RATE
		var v := (n - last) * exp(-t * 30.0) * 1.2 + (zap * 2.0 - 1.0) * exp(-t * 8.0) * 0.5 + sin(boom) * exp(-t * 2.4) * 1.1
		last = n
		tone[0][j] = v
		tone[1][j] = v
	_mix(tone, at, 1.0)
	_crash(at, 0.7)


## The derezz: a crumbling of countless small clicks falling away, thinning out, across the stereo.
func _crumble(at: float, seconds: float) -> void:
	var tone := _tone(seconds + 0.01)
	var tl: PackedFloat32Array = tone[0]
	var tr: PackedFloat32Array = tone[1]
	var size := tl.size() - 40
	for j in size:
		var u := float(j) / size
		if _rng.randf() < 0.05 * (1.0 - u):
			var v := _rng.randf_range(-1.0, 1.0) * (1.0 - u) * 0.7
			var pan := _rng.randf()
			for k in 40:
				var w := v * exp(-k * 0.2)
				tl[j + k] += w * pan
				tr[j + k] += w * (1.0 - pan)
	_mix(tone, at, 1.0)


## The kill feed's stamp: a hard digital blip chord and a click.
func _stamp(at: float) -> void:
	var tone := _tone(0.25)
	for j in tone[0].size():
		var t := float(j) / RATE
		var s := (1.0 if fposmod(880.0 * t, 1.0) < 0.5 else -1.0) * 0.4 + (1.0 if fposmod(1318.5 * t, 1.0) < 0.5 else -1.0) * 0.3
		var v := s * exp(-t * 22.0) * 0.5 + _rng.randf_range(-1.0, 1.0) * exp(-t * 300.0) * 0.6
		tone[0][j] = v
		tone[1][j] = v
	_mix(tone, at, 1.0)


## A low tritone under the whisper.
func _drone(at: float, seconds: float, level: float) -> void:
	var tone := _tone(seconds)
	for j in tone[0].size():
		var t := float(j) / RATE
		var env := smoothstep(0.0, 0.4, t) * (1.0 - smoothstep(seconds - 0.12, seconds, t))
		var v := (sin(TAU * _hz(28) * t) + 0.6 * sin(TAU * _hz(34) * t) + 0.2 * sin(TAU * _hz(46) * t * 1.002)) * env
		tone[0][j] = v
		tone[1][j] = v
	_mix(tone, at, level)


## The title's slam: a sub falling away under it.
func _sub_drop(at: float, seconds: float) -> void:
	var tone := _tone(seconds)
	var ph := 0.0
	for j in tone[0].size():
		var t := float(j) / RATE
		ph += TAU * (_hz(28) * pow(0.7, t / seconds)) / RATE
		var v := sin(ph) * exp(-t * 1.6) * 0.9 * minf((seconds - t) * 30.0, 1.0)
		tone[0][j] = v
		tone[1][j] = v
	_mix(tone, at, 1.0)


## The whisper, "one of 6666" spoken as breath ("one of six six six six"): noise through two moving formant
## resonances for the vowels, bright hiss for the s, a burst for the k, each word a shade apart in the stereo.
func _whisper(at: float) -> void:
	# [seconds, F1, F2, loudness, hiss]: w-uh-n, uh-v, then s-i-k-s four times.
	var sounds: Array = [[0.09, 300.0, 650.0, 0.5, 0.0], [0.2, 640.0, 1190.0, 1.0, 0.0], [0.08, 260.0, 1600.0, 0.4, 0.0], [0.07, 0.0, 0.0, 0.0, 0.0], [0.13, 600.0, 1150.0, 0.9, 0.0], [0.07, 300.0, 1100.0, 0.3, 0.15], [0.1, 0.0, 0.0, 0.0, 0.0]]
	for word in 4:
		sounds.append_array([[0.12, 0.0, 0.0, 0.0, 1.0], [0.11, 400.0, 1990.0, 0.9, 0.0], [0.035, 0.0, 0.0, 0.0, 0.0], [0.03, 0.0, 0.0, 0.0, 0.55], [0.1, 0.0, 0.0, 0.0, 0.85], [0.12 if word < 3 else 0.05, 0.0, 0.0, 0.0, 0.0]])
	var total := 0.0
	for s in sounds:
		total += s[0]
	var tone := _tone(total + 0.1)
	var y1 := 0.0
	var y2 := 0.0
	var z1 := 0.0
	var z2 := 0.0
	var f1 := 500.0
	var f2 := 1500.0
	var amp := 0.0
	var hiss := 0.0
	var last := 0.0
	var k := 0
	var into := 0.0
	var c0 := 0.0
	var c1 := 0.0
	var c2 := 0.0
	var c3 := 0.0
	for j in tone[0].size():
		var t := float(j) / RATE
		while k < sounds.size() - 1 and t >= into + sounds[k][0]:
			into += sounds[k][0]
			k += 1
		var s: Array = sounds[k]
		if s[1] > 0.0:
			f1 = lerpf(f1, s[1], 0.004)
			f2 = lerpf(f2, s[2], 0.004)
		amp = lerpf(amp, s[3], 0.006)
		hiss = lerpf(hiss, s[4], 0.02)
		if j % 32 == 0:
			var r1 := exp(-PI * 90.0 / RATE)
			var r2 := exp(-PI * 140.0 / RATE)
			c0 = 2.0 * r1 * cos(TAU * f1 / RATE)
			c1 = r1 * r1
			c2 = 2.0 * r2 * cos(TAU * f2 / RATE)
			c3 = r2 * r2
		var n := _rng.randf_range(-1.0, 1.0)
		# Two resonators on the breath.
		var a := n * 0.12 + c0 * y1 - c1 * y2
		y2 = y1
		y1 = a
		var b := n * 0.1 + c2 * z1 - c3 * z2
		z2 = z1
		z1 = b
		var high := n - last
		last = n
		var v := (a * 0.6 + b * 0.5) * amp * 0.5 + high * hiss * 0.18
		var side := float(clampi(k / 6, 0, 4) % 2)
		tone[0][j] = v * (0.85 + 0.1 * side)
		tone[1][j] = v * (0.95 - 0.1 * side)
	_mix(tone, at, 1.0)
