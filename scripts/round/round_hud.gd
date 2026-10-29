extends Control
## Rounds in the arena (C12, PRD 5.4): a round clock, a break between rounds with a summary
## panel, in-round callouts, and the roast announcer switch.
##
## A round lasts round_seconds of play. Its clock runs only while the player is playing:
## the mouse captured and the ask box closed, so a player who steps away is not timed (and
## their AI is not called for an empty round). Then a break of intermission_seconds shows
## the summary panel: the round's numbers and one line about them, from the player's own AI
## (scripts/round/round_announcer.gd, through the session's GuideLink) or from SIGKILL,
## with a thinking spinner while the AI is out. At the end of the break every dummy comes
## back and the next round starts, whatever the AI is doing. While the panel is up the
## guide HUD holds back a long answer to T until the break ends, so the two never overlap.
##
## Round numbers come from scripts/round/round_stats.gd, fed by the game's own signals: the
## cannon's shot_fired, each dummy's downed, the player's jumped and slid, and how far the
## player moved. Callouts during a round (first process down, a streak of hits, a run of
## misses) are game logic only, never the AI: at most one per callout_min_interval_s, any
## sooner one dropped, each shown for callout_seconds.
##
## The multiplayer panel (C13) takes the summary's place at the top of the screen while it
## is up: hold_summary hides the summary until it closes; the break runs on regardless.
##
## B turns the roast announcer on or off: off by default, saved next to the AI opt-in in
## user://settings.cfg (demo data keeps it in memory). Plain key only; ignored while the
## ask box or the AI question is open. Esc and every other key work as before.
##
## The SIGKILL rail (C17): a rail kill with the hit in the target's head zone is called
## out as "kill -9", game logic like every in-round callout, and it is never held back by the
## callout pace: it shows over whatever was up. A new round empties the player's ult meter.
##
## SIGSTOP bullet time (C18): its start is called out "SIGSTOP" and its end "SIGCONT", game
## logic too and never held back by the pace. A round's end stops it at once (solo the world
## is back to full speed for the break) and a new round fills its meter.
##
## The fork bomb (C19): the first blast of each of this player's throws is called out
## ":(){ :|:& };:", game logic, over the pace; a new round gives the bombs back.
##
## fork() (C24): the first fork of a shot of this player's is called out "fork()", at the
## usual pace (a shotgun fires too often to call every shot).
##
## grep (C25): each target this player's grep marks is called out "grep", at the usual pace (a
## shot's worth of marks is one callout).
##
## The rm -rf cannon (C26): each blast of this player's slug is called out "rm -rf" at once,
## whatever the pace: a slow weapon's one big moment, as the fork bomb's first blast is.
##
## cron mines (C27): the first run of each of this player's mines is called out "cron", at the
## usual pace; a new round ends every job of this player's (alone: in a match the host owns them).
##
## The announcer's voice (C16b): each callout rings a short chime on the Announcer bus, and
## its words are the subtitles, shown while the subtitles setting is on (the default).
##
## Black ICE (I3): a flatline alone (the life's flatlined) ends the round at once as a loss: the break's
## summary says so plainly over a darkened screen ("FLATLINED by Black ICE"), and the run is over: the
## next round is round 1 again, which brings the player back. round_ended tells ICE the round is over
## (Black ICE withdraws), and playing() is the round's play clock that times its arrival.

const TuningScript = preload("res://scripts/round/announcer_tuning.gd")
const Stats = preload("res://scripts/round/round_stats.gd")
const Announcer = preload("res://scripts/round/round_announcer.gd")
const BreakerPick = preload("res://scripts/ice/breaker_pick.gd")
## The summary panel's ICEbreaker pick (I2): the AI's, or the scripted guide's line.
const PICK_AI := "next round, load %s (your AI's pick)"
const PICK_SCRIPTED := "ICEbreaker pick: %s"
const Palette = preload("res://scripts/palette.gd")
const Sfx = preload("res://scripts/sfx_synth.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")

const DEFAULT_TUNING_PATH := "res://resources/announcer.tres"
const SPINNER := ["|", "/", "-", "\\"]
const SPINNER_FRAME_S := 0.09
## A step longer than this in one physics frame is the fall respawn, not running.
const TELEPORT_M := 2.0
## How long the "not saved" note stays on the round line after B.
const NOTE_S := 3.0
const FIRST_DOWN_LINE := "First process down."
const STREAK_LINE := "%d in a row."
const MISSES_LINE := "%d misses in a row. Let the crosshair settle."
const KILL9_LINE := "kill -9"
const SIGSTOP_LINE := "SIGSTOP"
const SIGCONT_LINE := "SIGCONT"
const FORK_BOMB_LINE := ":(){ :|:& };:"
const FORK_LINE := "fork()"
const GREP_LINE := "grep"
const RM_LINE := "rm -rf"
const CRON_LINE := "cron"
## /dev/null's discard (C31).
const DEV_NULL_LINE := "> /dev/null"
## SIGHUP (C32): its first catch of a burst, the command and the modem's last word.
const SIGHUP_LINE := "kill -HUP  NO CARRIER"
## A flatline's loss (I3): the summary's heading and its line.
const FLATLINE_HEADING := "FLATLINED by %s   RUN OVER   round 1 in %d s"
const FLATLINE_LINE := "Black ICE touched you. The run is over: the next one starts at round 1."
const VEIL_ALPHA := 0.6

enum Phase { ROUND, BREAK }

## A round started (I1: ICE builds its pieces again and forgets its adaptation): its number.
signal round_started(number: int)
## A round ended, its break beginning (I3: Black ICE withdraws): its number.
signal round_ended(number: int)

# Set these before the node enters the tree.
## AnnouncerTuning; null for resources/announcer.tres.
var tuning: Resource = null
## The guide HUD (scripts/hud/guide_hud.gd): the session's link and its cap on calls.
var guide: Control = null
## Set by the multiplayer panel while it is up: the summary panel stays hidden.
var hold_summary := false
## The ICEbreakers' director (I2), set by the HUD: while breakers are carried the round's end asks the
## guide which one to load next too (the round's ICE and breaker numbers ride in its one call), and the
## summary panel shows the pick: the AI's when its line names one, else the scripted guide's.
var breakers: Node = null

var stats: Stats
var announcer: Announcer
var phase: Phase = Phase.ROUND
## In-round callouts shown and dropped by the rate limit, and the last one shown.
var callouts_shown := 0
var callouts_dropped := 0
var last_callout := ""

var _t: Resource
var _player: Node = null
var _targets: Array = []
## This player's life alone and the session beside the arena (C27b): deaths for the round.
var _life: Node = null
var _session: Node = null
var _left_s := 0.0
var _since_callout_s := INF
var _callout_left_s := 0.0
var _note_left_s := 0.0
var _spin_s := 0.0
var _spin_at := 0
var _last_pos := Vector3.INF

var _round_line: Label
var _callout_label: Label
var _panel: PanelContainer
var _heading: Label
var _numbers: Label
var _who: Label
var _line: Label
var _tip_who: Label
var _tip: Label
var _pick: Label
## The ICEbreaker numbers as the round ended (I2), {} with no breakers carried.
var _pick_numbers := {}
var _chime: AudioStreamPlayer
## The round ended as a loss: flatlined alone (I3), the run over; the next round is round 1. And what
## flatlined it, for the heading; the darkened screen behind the summary.
var lost := false
var _lost_to := ""
var _veil: ColorRect
var _style: StyleBoxFlat


func _ready() -> void:
	_t = usable_tuning(tuning)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	get_viewport().size_changed.connect(_fit_panel)
	restart(_t)


## Starts again from round 1 with `with_tuning`; tests use it for short rounds.
func restart(with_tuning: Resource) -> void:
	_t = usable_tuning(with_tuning)
	if announcer != null:
		announcer.intermission_over()
	stats = Stats.new(_t.streak_callout, _t.miss_run_callout)
	announcer = Announcer.new(guide.session_link(), guide.call_cap(), _t.text_max_chars)
	callouts_shown = 0
	callouts_dropped = 0
	last_callout = ""
	lost = false
	_lost_to = ""
	_start_round(1)


static func usable_tuning(candidate: Resource) -> Resource:
	if candidate is TuningScript:
		var issues: PackedStringArray = candidate.problems()
		if issues.is_empty():
			return candidate
		for issue in issues:
			push_warning("announcer tuning: " + issue + "; using the shipped tuning instead")
	var shipped = load(DEFAULT_TUNING_PATH)
	if shipped is TuningScript and shipped.problems().is_empty():
		return shipped
	return TuningScript.new()


## The player whose shots, jumps, slides and steps a round counts.
func set_player(player: Node) -> void:
	_player = player
	for pair in [["shot_fired", _on_shot], ["jumped", _on_jumped], ["slid", _on_slid], ["rail_kill", _on_rail_kill], ["fork_bomb_burst", _on_fork_bomb], ["fork_split", _on_fork_split], ["grep_marked", _on_grep_marked], ["rm_blast", _on_rm_blast], ["cron_ran", _on_cron_ran], ["hole_discarded", _on_hole_discarded], ["hup_caught", _on_hup_caught]]:
		if player.has_signal(pair[0]) and not player.is_connected(pair[0], pair[1]):
			player.connect(pair[0], pair[1])
	var stop = player.get("sigstop")
	if stop != null:
		for pair in [["started", _on_sigstop], ["continued", _on_sigcont]]:
			if stop.has_signal(pair[0]) and not stop.is_connected(pair[0], pair[1]):
				stop.connect(pair[0], pair[1])
	_last_pos = Vector3.INF


## This player's life alone (C27b, scripts/fight/solo_life.gd): its deaths count in the round,
## and a new round brings it back full.
func set_life(life: Node) -> void:
	_life = life
	if life != null and life.has_signal("died") and not life.is_connected("died", _on_died):
		life.connect("died", _on_died)
	if life != null and life.has_signal("flatlined") and not life.is_connected("flatlined", _on_flatlined):
		life.connect("flatlined", _on_flatlined)


## The session beside the arena: this player's deaths in a match count in the round too (C27b).
func set_session(session: Node) -> void:
	if session != null and session.has_signal("player_died") and not session.is_connected("player_died", _on_player_died):
		session.connect("player_died", _on_player_died)
	_session = session


## The dummies whose downs a round counts and that come back when a round starts.
func set_targets(targets: Array) -> void:
	_targets = targets.duplicate()
	for dummy in _targets:
		if dummy.has_signal("downed") and not dummy.is_connected("downed", _on_downed):
			dummy.connect("downed", _on_downed)


## True while the round clock runs: the mouse captured (or a test's stand-in for it) and
## the ask box closed.
func engaged() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	if _player.get("input_blocked") == true:
		return false
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or _player.get("assume_captured") == true


func seconds_left() -> float:
	return _left_s


## True while the break's summary panel is up.
func showing_summary() -> bool:
	return phase == Phase.BREAK


## True while the round's play runs (I3: Black ICE's arrival is timed on it): a round on, the player in it.
func playing() -> bool:
	return phase == Phase.ROUND and engaged()


func _physics_process(delta: float) -> void:
	_since_callout_s += delta
	_callout_left_s = maxf(_callout_left_s - delta, 0.0)
	_note_left_s = maxf(_note_left_s - delta, 0.0)
	if phase == Phase.ROUND:
		_track_distance()
		if not engaged():
			return
		stats.tick(delta)
		_left_s -= delta
		if _left_s <= 0.0:
			_end_round()
		return
	announcer.poll()
	_left_s -= delta
	if _left_s <= 0.0:
		_next_round()


func _process(delta: float) -> void:
	if announcer.state == "thinking":
		_spin_s += delta
		if _spin_s >= SPINNER_FRAME_S:
			_spin_s = 0.0
			_spin_at = (_spin_at + 1) % SPINNER.size()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
		return  # plain keys only
	if guide.is_typing() or guide.is_asking_consent():
		return
	if event.is_action_pressed("toggle_roast", false, true):
		get_viewport().set_input_as_handled()
		toggle_roast()


## B: the roast announcer on or off, saved for next time.
func toggle_roast() -> void:
	var link = guide.session_link()
	var saved: bool = link.set_roast(not link.roast_on())
	_note_left_s = 0.0 if saved else NOTE_S
	_refresh()


func _start_round(number: int) -> void:
	stats.reset(number)
	if _player != null and is_instance_valid(_player) and _player.has_method("reset_meter"):
		_player.reset_meter()
	if _player != null and is_instance_valid(_player) and _player.has_method("refill_sigstop"):
		_player.refill_sigstop()
	if _player != null and is_instance_valid(_player) and _player.has_method("refill_bombs"):
		_player.refill_bombs()
	if _player != null and is_instance_valid(_player) and _player.has_method("clear_jobs"):
		_player.clear_jobs()  # a new round ends this player's cron jobs (C27; alone only)
	phase = Phase.ROUND
	_left_s = _t.round_seconds
	_since_callout_s = INF
	_callout_left_s = 0.0
	_spin_at = 0
	_last_pos = Vector3.INF
	_refresh()
	round_started.emit(stats.round_number)


func _end_round() -> void:
	if _player != null and is_instance_valid(_player) and _player.has_method("end_sigstop"):
		_player.end_sigstop()
	phase = Phase.BREAK
	_left_s = _t.intermission_seconds
	_callout_left_s = 0.0
	_spin_at = 0
	_pick_numbers = BreakerPick.numbers(breakers)
	announcer.round_ended(stats.payload(), _pick_numbers)
	_refresh()
	round_ended.emit(stats.round_number)


func _next_round() -> void:
	announcer.intermission_over()
	for dummy in _targets:
		if is_instance_valid(dummy) and dummy.has_method("reset_for_round"):
			dummy.reset_for_round()
	if _life != null and is_instance_valid(_life) and _life.has_method("reset_for_round"):
		_life.reset_for_round()  # alone, back at full health (C27b)
	var next := 1 if lost else stats.round_number + 1  # a flatline's loss: a new run (I3)
	lost = false
	_lost_to = ""
	_start_round(next)


func _track_distance() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var at: Vector3 = _player.global_position
	if _last_pos.is_finite() and engaged():
		var step := Vector2(at.x - _last_pos.x, at.z - _last_pos.z).length()
		if step < TELEPORT_M:
			stats.add_distance(step)
	_last_pos = at


func _on_shot(hit: bool) -> void:
	if phase == Phase.ROUND:
		_callout(stats.on_shot(hit))


func _on_downed(dummy: Node3D) -> void:
	if phase == Phase.ROUND and dummy.get("credited") != false:  # this player's own kill (C27b)
		_callout(stats.on_derezz())


## This player was derezzed alone (C27b).
func _on_died(_cause: String) -> void:
	if phase == Phase.ROUND:
		stats.on_death()


## Flatlined alone by Black ICE (I3): the round ends now, as a loss, and the run with it.
func _on_flatlined(cause: String) -> void:
	if phase != Phase.ROUND:
		return
	lost = true
	_lost_to = cause
	_end_round()


## A player died in a match: this player's own deaths count (C27b).
func _on_player_died(victim: int, _killer: int) -> void:
	if phase == Phase.ROUND and _session != null and is_instance_valid(_session) and victim == _session.my_id:
		stats.on_death()


func _on_jumped() -> void:
	if phase == Phase.ROUND:
		stats.on_jump()


func _on_slid() -> void:
	if phase == Phase.ROUND:
		stats.on_slide()


## A rail kill: a headshot is called out as "kill -9" over anything that was up.
func _on_rail_kill(headshot: bool) -> void:
	if headshot and phase == Phase.ROUND:
		_callout("kill_9", true)


## SIGSTOP started and SIGCONT: called out at once, whatever the pace.
func _on_sigstop() -> void:
	_callout("sigstop", true)


func _on_sigcont() -> void:
	_callout("sigcont", true)


## The first blast of a throw of the fork bomb: called out at once, whatever the pace.
func _on_fork_bomb() -> void:
	_callout("fork_bomb", true)


func _on_fork_split() -> void:
	_callout("fork")


func _on_grep_marked() -> void:
	_callout("grep")


## A blast of this player's rm -rf slug: called out at once, whatever the pace.
func _on_rm_blast() -> void:
	_callout("rm_rf", true)


## Something this player's /dev/null discarded (C31): called out at once, as the fork bomb is.
func _on_hole_discarded() -> void:
	_callout("dev_null", true)


## The first thing a burst of this player's SIGHUP confused (C32): called out at once, as the fork bomb is.
func _on_hup_caught() -> void:
	_callout("sighup", true)


## The first run of a mine of this player's: called out at the usual pace.
func _on_cron_ran() -> void:
	_callout("cron")


## Shows a callout unless one was shown less than callout_min_interval_s ago (`now`: show it
## whatever the pace, as "kill -9" is).
func _callout(word: String, now: bool = false) -> void:
	if word == "":
		return
	if _since_callout_s < _t.callout_min_interval_s and not now:
		callouts_dropped += 1
		return
	_since_callout_s = 0.0
	callouts_shown += 1
	match word:
		"first_derezz":
			last_callout = FIRST_DOWN_LINE
		"streak":
			last_callout = STREAK_LINE % stats.streak
		"misses":
			last_callout = MISSES_LINE % stats.misses_in_a_row
		"kill_9":
			last_callout = KILL9_LINE
		"sigstop":
			last_callout = SIGSTOP_LINE
		"sigcont":
			last_callout = SIGCONT_LINE
		"fork_bomb":
			last_callout = FORK_BOMB_LINE
		"fork":
			last_callout = FORK_LINE
		"grep":
			last_callout = GREP_LINE
		"rm_rf":
			last_callout = RM_LINE
		"cron":
			last_callout = CRON_LINE
		"dev_null":
			last_callout = DEV_NULL_LINE
		"sighup":
			last_callout = SIGHUP_LINE
	_callout_left_s = _t.callout_seconds
	_ring()
	_refresh()


## The callout's chime, on the Announcer bus.
func _ring() -> void:
	if _chime != null:
		_chime.play()


## True while the subtitles setting shows the announcer's words.
func subtitles_on() -> bool:
	return GameSettings.current().value("hud", "subtitles")


## The round line, for tests.
func round_text() -> String:
	return _round_line.text


## The callout on screen, or "".
func callout_text() -> String:
	return _callout_label.text if _callout_label.visible else ""


## Everything the summary panel shows, line by line, or "" when it is down.
func summary_text() -> String:
	if not _panel.visible:
		return ""
	var out := PackedStringArray()
	for label in [_heading, _numbers, _who, _line, _tip_who, _tip, _pick]:
		if label.visible:
			out.append(label.text)
	return "\n".join(out)


## The label the AI's or SIGKILL's line is shown in.
func line_label() -> Label:
	return _line


## The round's own line, top left ("ROUND 2   1:26 left ..."): I1's HUD corruption scrambles it.
func round_label() -> Label:
	return _round_line


func _refresh() -> void:
	if _round_line == null:
		return
	guide.hold_answer = phase == Phase.BREAK
	var roast := "on" if guide.session_link().roast_on() else "off"
	var note := "  (not saved)" if _note_left_s > 0.0 else ""
	if phase == Phase.ROUND:
		var left := maxi(ceili(_left_s), 0)
		_round_line.text = "ROUND %d   %d:%02d left%s   B roast: %s%s" % [stats.round_number, left / 60, left % 60, "" if engaged() else " (paused)", roast, note]
	else:
		_round_line.text = "ROUND %d OVER   B roast: %s%s" % [stats.round_number, roast, note]
	_callout_label.text = last_callout
	_callout_label.visible = phase == Phase.ROUND and _callout_left_s > 0.0 and subtitles_on()
	_panel.visible = phase == Phase.BREAK and not hold_summary
	_veil.visible = _panel.visible and lost
	_style.border_color = Palette.HOSTILE_RED if lost else Palette.TEAL
	if not _panel.visible:
		return
	var shown: Dictionary = announcer.payload
	var demo: bool = announcer.state == "demo"
	_heading.text = "ROUND %d OVER%s   next round in %d s" % [int(shown.get("round_number", 0)), "   (demo data)" if demo else "", maxi(ceili(_left_s), 0)]
	_heading.add_theme_color_override("font_color", Palette.HOSTILE_RED if lost else Palette.TEAL)
	if lost:
		_heading.text = FLATLINE_HEADING % [_lost_to if _lost_to != "" else "Black ICE", maxi(ceili(_left_s), 0)]
	var first := float(shown.get("time_to_first_derezz_s", -1.0))
	_numbers.text = "shots %d   hits %d   accuracy %.1f%%\nprocesses down %d   best streak %d   first down %s\nmoved %.1f m   slides %d   jumps %d   derezzed %d" % [
		int(shown.get("shots", 0)), int(shown.get("hits", 0)), float(shown.get("accuracy_pct", 0.0)),
		int(shown.get("derezzes", 0)), int(shown.get("longest_streak", 0)), ("%.1f s" % first) if first >= 0.0 else "none",
		float(shown.get("distance_m", 0.0)), int(shown.get("slides", 0)), int(shown.get("jumps", 0)), int(shown.get("deaths", 0))]
	var ai: bool = announcer.state == "ai" or demo or announcer.state == "thinking"
	_who.text = announcer.title() + ("  " + SPINNER[_spin_at] if announcer.state == "thinking" else "")
	_who.add_theme_color_override("font_color", Palette.TEAL if ai else Palette.HOSTILE_AMBER)
	_line.text = Announcer.DEMO_ROAST if demo else announcer.text
	if lost and _line.text == "":
		_line.text = FLATLINE_LINE
	_line.visible = _line.text != ""
	_tip_who.visible = demo
	_tip.visible = demo
	if demo:
		_who.text = "your AI (%s) roasts:" % guide.session_link().display_name()
		_tip_who.text = "your AI (%s) coaches:" % guide.session_link().display_name()
		_tip.text = Announcer.DEMO_TIP
	_pick.visible = not _pick_numbers.is_empty()
	_pick.text = pick_text()


## The summary panel's ICEbreaker pick (I2): the AI's when its line names a breaker, else the scripted
## guide's; "" with no breakers carried.
func pick_text() -> String:
	if _pick_numbers.is_empty():
		return ""
	var named := BreakerPick.kind_in(announcer.text) if announcer.state == "ai" else ""
	if named != "":
		return PICK_AI % named
	return PICK_SCRIPTED % BreakerPick.scripted(_pick_numbers)[1]


func _build() -> void:
	SettingsApply.ensure_buses()
	_chime = AudioStreamPlayer.new()
	_chime.stream = Sfx.callout_chime()
	_chime.bus = SettingsApply.ANNOUNCER
	add_child(_chime)
	_round_line = _label(self, _t.round_font_size, Palette.MINT)
	_round_line.position = Vector2(18.0, 44.0)
	_callout_label = _label(self, _t.callout_font_size, Palette.HOSTILE_AMBER)
	_callout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Across the whole width, just above the crosshair, under the top panels.
	_callout_label.anchor_left = 0.0
	_callout_label.anchor_right = 1.0
	_callout_label.anchor_top = 0.45
	_callout_label.anchor_bottom = 0.45
	_callout_label.offset_left = 0.0
	_callout_label.offset_right = 0.0
	_callout_label.visible = false
	# A flatline's loss (I3): the screen darkened behind the summary, so the loss reads plainly.
	_veil = ColorRect.new()
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.color = Color(Palette.VOID, VEIL_ALPHA)
	_veil.visible = false
	add_child(_veil)
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.VOID, 0.82)
	style.border_color = Palette.TEAL
	style.set_border_width_all(1)
	style.set_content_margin_all(12)
	_style = style
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(stack)
	_heading = _label(stack, _t.summary_font_size + 3, Palette.TEAL)
	_numbers = _label(stack, _t.summary_font_size, Palette.MINT)
	_who = _label(stack, _t.summary_font_size, Palette.TEAL)
	_line = _label(stack, _t.summary_font_size, Palette.MINT)
	_tip_who = _label(stack, _t.summary_font_size, Palette.TEAL)
	_tip = _label(stack, _t.summary_font_size, Palette.MINT)
	_pick = _label(stack, _t.summary_font_size, Palette.BREAKER_TEXT)
	_pick.visible = false
	for label in [_numbers, _line, _tip, _pick]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.visible = false
	_fit_panel()


## The summary panel: centred near the top, as wide as the tuning says but never wider
## than the screen, growing downwards as its text grows.
func _fit_panel() -> void:
	if _panel == null:
		return
	var screen := get_viewport_rect().size
	var width := mini(_t.summary_width, int(screen.x) - 36)
	_panel.custom_minimum_size = Vector2(maxi(width, 0), 0)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.position.y = _t.summary_top


func _label(parent: Control, size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", Palette.mono_font())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Palette.VOID)
	label.add_theme_constant_override("outline_size", 4)
	parent.add_child(label)
	return label
