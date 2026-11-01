class_name CreditsScore
extends OpenerScore
## The credits' score (C44; PRD 5.8, "Art and audio original"): made here in code, note by note, on the opener's own
## instruments (scripts/opener/opener_score.gd: its pads, glitching arpeggios, bells, drums and the title's riff), so
## the game's last music answers its first. 150 beats a minute, E minor, a bar 1.6 s. Three parts on the Music bus:
##   "roll"  under the table, to the moment the prompt waits (ROLL_BARS bars): a pad swelling under `$ top` typing
##           itself (a tick a key), a bell motif for the title card, then a bar a chord through the cast with a
##           glitching arpeggio, a four-on-the-floor coming in under it, a bell rising a step for each row as it lands;
##           brighter through the threads (a bell a beat for each); the adoption, quiet; then the row that should not
##           be there: the copy's cluster, a tremolo and a low tritone.
##   "wait"  a two-bar loop while the prompt waits for the player's kill -9: the opener's own stand-off, muted chugs, a
##           heartbeat, a tremolo.
##   "kill"  from the shot: the rail's crack, the derezz crumbling, a reverse swell into the slam (SLAM_BEATS after the
##           shot) and the title's riff, then the last chord ringing out.
## Made once a run on a worker thread (prepare(): as the finale begins, or the Esc menu opens on a finished campaign),
## then kept; the roll joins it where it is if it lands late. Deterministic. Quitting while it is being made stops it
## at its next note (stop(), from the window's close), as the opener's does.

const CREDIT_PARTS := ["roll", "wait", "kill"]
const CREDIT_LOUDNESS := {"roll": 0.085, "wait": 0.08, "kill": 0.13}
## The roll's length in bars: the prompt waits from its end. Two bars a cast row (W2: nine rows, so 30; the credits
## test holds THANKS_BAR to CAST_BAR + CAST_EVERY a row, so a new contributor cannot land under the threads).
const ROLL_BARS := 30
## The bars the roll's beats land on (scripts/credits/credits_roll.gd keeps its clock by them).
const TITLE_BAR := 2
const CAST_BAR := 4
const CAST_EVERY := 2
const THANKS_BAR := 22
const QUIET_BAR := 26
const LAST_BAR := 28
## The kill: the slam this many beats after the shot, the riff two bars, the chord ringing out to its end.
const KILL_SLAM_BEATS := 8.0
const KILL_S := 9.6
## The bell each cast row lands on, rising.
const ROW_BELLS := [64, 67, 71, 74, 76, 79, 83, 88, 91]
## The threads' bells, a beat each.
const THREAD_BELLS := [76, 79, 81, 83, 86, 88, 91, 93]

static var _credit_streams := {}
static var _credit_job: CreditsScore = null
static var _credit_task := -1


# --- What the roll asks. ---

## Starts making the parts on a worker thread, if they are not made or being made.
static func prepare() -> void:
	if ready_now() or _credit_task >= 0:
		return
	_credit_job = CreditsScore.new()
	_credit_task = WorkerThreadPool.add_task(_credit_job._make_credits, false, "credits score")


## Takes the parts in once the worker is through (the roll calls this each frame). True once made.
static func take() -> bool:
	if ready_now():
		return true
	if _credit_task >= 0 and WorkerThreadPool.is_task_completed(_credit_task):
		WorkerThreadPool.wait_for_task_completion(_credit_task)
		_credit_task = -1
		if not _credit_job._cancel:
			_credit_streams = _credit_job._parts
		_credit_job = null
	return ready_now()


## Part `part`'s stream once made, else null.
static func part(name: String) -> AudioStreamWAV:
	return _credit_streams.get(name)


static func ready_now() -> bool:
	return _credit_streams.size() == CREDIT_PARTS.size()


## Everything now (the checks and the tools): waits for the worker, or makes it here.
static func make_now() -> void:
	if ready_now():
		return
	if _credit_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_credit_task)
		_credit_task = -1
		var cancelled := _credit_job._cancel
		if not cancelled:
			_credit_streams = _credit_job._parts
		_credit_job = null
		if not cancelled:
			return
	var job := CreditsScore.new()
	job._make_credits()
	_credit_streams = job._parts


## Stops a score still being made (the game quitting): the worker gives up at its next note.
static func stop() -> void:
	if _credit_job != null and _credit_task >= 0:
		_credit_job._cancel = true


## Forgets every part (the checks), once no worker is making them.
static func drop() -> void:
	if _credit_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_credit_task)
		_credit_task = -1
	_credit_streams = {}
	_credit_job = null


static func credit_seconds(name: String) -> float:
	match name:
		"roll":
			return ROLL_BARS * BAR_S
		"wait":
			return WAIT_BARS * BAR_S
	return KILL_S


# --- The making. ---

func _make_credits() -> void:
	for name in CREDIT_PARTS:
		if _cancel:
			return
		_part = name
		var n := int(credit_seconds(name) * RATE)
		_l = PackedFloat32Array()
		_l.resize(n)
		_r = PackedFloat32Array()
		_r.resize(n)
		_loop = name == "wait"
		match name:
			"roll":
				_roll()
			"wait":
				_wait()  # the opener's own stand-off
			"kill":
				_kill()
		if _cancel:
			return
		_parts[name] = _to_stream(_l, _r, _loop, CREDIT_LOUDNESS[name])


func _roll() -> void:
	# `$ top -p sigkill --credits` typing itself: a tick a key, on the sixteenths.
	for s in 26:
		_hat(0.4 + s * STEP_S, 0.07 + 0.03 * (s % 2))
	for bar in ROLL_BARS:
		var at := bar * BAR_S
		var last := bar >= LAST_BAR
		var quiet := bar >= QUIET_BAR and not last
		# The pad a bar: in from the first bar, the cluster for the last row.
		var level := smoothstep(-0.5, 3.0, bar) * (0.55 if quiet else 0.7)
		var bright := 0.3 + 0.4 * smoothstep(3.0, 12.0, bar) + (0.15 if bar >= THANKS_BAR and bar < QUIET_BAR else 0.0) - (0.35 if last else 0.0)
		_pad(at, 4 if last else bar % 4, level, bright, 0.3 * smoothstep(1.0, 4.0, bar))
		if bar == TITLE_BAR:
			_crash(at, 0.35)
			for k in 3:
				_bell(at + k * BEAT_S * 0.75, [76, 71, 79][k], 0.26)
		# The cast: a glitching arpeggio a sixteenth, a bell as each row lands, the beat coming in under it.
		if bar >= CAST_BAR and bar < QUIET_BAR:
			var notes: Array = ARP[bar % 4]
			for s in 16:
				var glitch := bar % 2 == 1 and s >= 12
				var note: int = notes[s % 8] + (12 if glitch and s % 2 == 1 else 0)
				_arp(at + s * STEP_S, note, 0.18 * smoothstep(CAST_BAR - 0.5, CAST_BAR + 3.0, bar), s % 2, glitch)
			if bar >= CAST_BAR + 2:
				for b in 4:
					_kick(at + b * BEAT_S, 0.36 + (0.08 if bar >= THANKS_BAR else 0.0), false)
					_hat(at + b * BEAT_S + BEAT_S * 0.5, 0.1)
			if bar >= CAST_BAR + 6:
				for e in 8:
					_bass(at + e * BEAT_S * 0.5, 40 if bar % 4 < 2 else 36, 0.2)
			if bar >= THANKS_BAR:
				_snare(at + BEAT_S, 0.35)
				_snare(at + BEAT_S * 3.0, 0.35)
		if bar >= CAST_BAR and bar < THANKS_BAR and (bar - CAST_BAR) % CAST_EVERY == 0:
			var row := (bar - CAST_BAR) / CAST_EVERY
			_bell(at, ROW_BELLS[mini(row, ROW_BELLS.size() - 1)], 0.3)
			_crash(at, 0.12)
		if bar == THANKS_BAR - 1:
			_riser(at, BAR_S, 0.28)
		if bar >= THANKS_BAR and bar < THANKS_BAR + 2:
			for b in 4:
				_bell(at + b * BEAT_S, THREAD_BELLS[(bar - THANKS_BAR) * 4 + b], 0.18)
		if bar == THANKS_BAR:
			_crash(at, 0.5)
		# The adoption: quiet, a heartbeat.
		if quiet:
			for beat in [0.0, BEAT_S * 2.0]:
				_kick(at + beat, 0.38, true)
				_kick(at + beat + 0.22, 0.24, true)
		# The row that should not be there.
		if bar == LAST_BAR:
			_stamp(at)
			_drone(at, 2.0 * BAR_S, 0.28)
		if last:
			_tremolo(at, BAR_S, 88, 89, 0.07 + 0.03 * (bar - LAST_BAR))


func _kill() -> void:
	_impact(0.0)
	_crumble(BEAT_S, 1.8)
	var slam := KILL_SLAM_BEATS * BEAT_S
	_swell(slam - 0.6, 0.6, 0.55)
	_crash(slam, 0.9)
	_sub_drop(slam, 1.6)
	_riff(slam, SLAM_RIFF, 1.0)
	_drums(slam, 2, 1.0)
	var end := slam + 2.0 * BAR_S
	var ring := (KILL_S - end - 0.2) / STEP_S
	_guitar(end, ring, 40, true, 1.0)
	_kick(end, 1.0, false)
	_crash(end, 0.8)
	_pad(end, 0, 0.45, 0.3, 0.0, KILL_S - end - 0.1)
