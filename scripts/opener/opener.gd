class_name Opener
extends CanvasLayer
## The opener (PRD 5.7, "you got tricked into this"), live in the engine, its first 95 seconds so far (C38, C40, C41):
##   0:00 to 0:15  the game freezes on its own last frame, stutters, comes apart and cuts to black and silence (a
##                 fake crash: the game glitching inside its own window, never a dialog, never the desktop, never a
##                 real freeze); then a fake terminal in the player's theme, and `<user>@<host>:~$` types itself.
##   0:15 to 0:35  "thanks for running me." / "you never read the install script, did you?", folder names scroll,
##                 the uptime ticks, "I've been in here since you booted.", and the late-night line from recent
##                 file times.
##   0:35 to 0:50  a fresh prompt, and the terminal ignores typing for 3 seconds; "you're in now." types itself at
##                 it; then the terminal's window shrinks away: the camera pulls back from it, and it is one lit
##                 screen on a wall in a machine the size of a city (C40, scripts/opener/tree_fall.gd).
##   0:50 to 1:10  the fall down the player's directory tree as that city: the folder names the terminal scrolled
##                 on towers, as big as what each holds, the node_modules pit at the bottom, the hottest process
##                 beating red in it; landing on its rim, the hand-off to C41.
##   1:10 to 1:35  (C41) "Linking your agent...": lines of signal climb out of the pit and the HUD comes alive, and the
##                 player's real AI answers live, told only that the game is starting (scripts/opener/opener_link.gd,
##                 scripts/opener/link_beat.gd), or the scripted guide speaks if it cannot; then the scripted guide's
##                 "I've been stuck in here with them. They look like you.", and the copy of the player walks up out of
##                 the pit on a stair of light, wearing their user name, and stands before them (scripts/opener/
##                 pit_beat.gd, scripts/opener/copy_art.gd); the hand-off to C42 (until then the opener fades to black
##                 and hands back to the menu).
## Every word in quotes is the PRD's own (THANKS, INSTALL, SINCE, IN_NOW; C41's LinkBeat.LINKING and GUIDE); the
## late-night line's words are ours,
## built from the file times alone (late_line). Text types itself as a hand types (scripts/opener/typist.gd): its
## own wait for every key, a hesitation before the punchlines, one typo taken back.
##
## The data comes through one seam, OpenerData (scripts/opener/opener_data.gd): `data`, started as this starts and
## taken once, as soon as it is ready or at the tuning's take_by second regardless (while the screen is still the
## crash or black, before anything of it shows), then dropped as this ends. DemoOpenerData (fixed, invented,
## nothing read) is always ready; RealOpenerData (C39, only with the player's yes) reads on its own thread, and
## anything it has not got by then is the demo's. Nothing here reads the machine: no file but res://, no
## environment, no clock, no process, no network; the reader is the one place that does. The city is built from
## the same values (scripts/opener/tree_layout.gd), as the screen goes black, and dropped with them. The copy wears the
## user name the opener already took (cleaned), and nothing else; it goes with the machine as the opener ends, and the
## player's AI is never told it, nor anything else of the data (C41).
##
## A real way out, always: Esc leaves at any moment, mid-crash and mid-typing included (`finished(true)`), and the
## window's close is never touched (Godot's own quit). The main loop never stops: the "freeze" is a picture held on
## screen while every frame still runs and every key is still read. Played from the Esc menu alone, the arena
## behind is paused (`pause_world`) so nothing can hit the player while it plays, and goes on as it was after;
## this layer and its sounds run through the pause. The mouse is hidden while it plays and given back after.
## Flash-safe: the screen's overall brightness follows luma_at(), which never flashes 3 or more times in any
## second (two short drops to black in the crash, then the cut), and the glitch's pattern jerks at glitch_hz; in the
## machine the screen dims as it shrinks, the hot process swells under once a second, and the end fades.
##
## Sound, all made in scripts/sfx_synth.gd: the frozen game's stuck buffer buzzing, its picture's crackle, dead
## silence at the cut, a low hum under the terminal, a keyboard's clicks as the text types itself; the rush as it
## shrinks away, the wind of the fall rising with its speed, the landing, and the hot process's beat.
##
## The hand-off to C41: at handoff_at the camera has landed (fall().landing()) and the machine goes on drawing;
## fall() and layout() are the world and the city, so the next beat can stand a daemon in them.
##
## The hand-off to C42: at forge_at the copy stands before the player (pit().copy(), at PitBeat.stand()), the link has
## said its line (link()) and the guide has said its own; the machine goes on drawing.

signal finished(skipped: bool)

const SfxSynth = preload("res://scripts/sfx_synth.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")
const GlitchShader = preload("res://shaders/opener_glitch.gdshader")
const ScreenShader = preload("res://shaders/opener_screen.gdshader")
const Palette = preload("res://scripts/palette.gd")
const DEFAULT_TUNING_PATH := "res://resources/opener.tres"

## The PRD's words (PRD 5.7), exactly.
const THANKS := "thanks for running me."
const INSTALL := "you never read the install script, did you?"
const SINCE := "I've been in here since you booted."
const IN_NOW := "you're in now."
## The late-night line (the PRD gives its source, recent file modification times, not its words): the latest file
## time in the past week between midnight and 5 in the morning, as "last night" or its weekday, then the echo.
const LATE_UP := "you were still up at %s %s."
const LATE_ECHO := " so was I."
## No late hour in the week's file times; no file times at all.
const NEVER_LATE := "you're always in bed by midnight."
const NEVER_LATE_ECHO := " I don't sleep."
const NO_TIMES := "I don't sleep."
const NO_TIMES_ECHO := " do you?"
const LATE_HOURS := 5
const WEEK_S := 7 * 86400
const DAY_S := 86400
const WEEKDAYS := ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
## Where the typo goes, and what the hand types before it notices.
const TYPO_WORD := "install"
const TYPO := "isn"
const TYPO_BACK := 2
## Every line's typing is seeded from here, so it types the same way every time.
const SEED := 3112
## Over every layer: the HUD (1), the menu, and the colourblind filter (100); the frozen frame is already filtered,
## and the terminal is the player's own theme's colours, exactly.
const LAYER := 110
## The PRD's windows, in seconds: the crash and the prompt, the lines, the shrink-away, the fall.
const CRASH_WINDOW := Vector2(0.0, 15.0)
const LINES_WINDOW := Vector2(15.0, 35.0)
const SHRINK_WINDOW := Vector2(35.0, 50.0)
const FALL_WINDOW := Vector2(50.0, 70.0)
## The terminal moves into its own viewport this long before the camera starts to pull back, so the screen's
## picture is drawn before the panel shows it.
const LIFT_S := 0.1
## The screen's overall brightness in the machine, for luma_at(): the dark the panel shrinks into.
const MACHINE_LUMA := 0.3
## A frozen frame's stand-in when there is none to take (a headless run): near black.
const NO_FRAME := Color(0.02, 0.02, 0.03)
## How the glitch tints a corrupted band: the daemons' glitch magenta (A4).
const BLEED := Color(1.0, 0.17, 0.84)

enum Phase { LIVE, FROZEN, BLACK, TERMINAL, HOLD, IGNORE, IN, REVEAL, FALL, LANDED, LINK, COPY, DONE }
const PHASE_NAMES := ["live", "frozen", "black", "terminal", "hold", "ignore", "in", "reveal", "fall", "landed", "link", "copy", "done"]

## What it shows of "your machine"; null: DemoOpenerData.
var data: OpenerData = null
## The timeline; null (or one with problems): resources/opener.tres.
var tuning: OpenerTuning = null
## Pause the game behind while it plays (alone, from the menu); never in a match, where the menu offers no opener.
var pause_world := false
## Freeze the game's own last frame for the crash (never in a headless run, which draws nothing).
var freeze_frame := true
## The session's guide link (scripts/guide/guide_link.gd) the link beat asks the player's AI through (C41), or null:
## then the scripted guide. The menu hands it in. Untyped on purpose, so a test's fits.
var guide = null

var _t: OpenerTuning
var _data: OpenerData
var _taken := false
var _palette: OpenerPalette
var _elapsed := 0.0
var _ticks := 0
var _phase := Phase.LIVE
var _events: Array = []
var _actions: Array = []
var _next := 0
var _prompt := ""
var _late := ""
var _uptime_base := 0
var _uptime_line := -1
var _uptime_shown := -1
var _glitch_step := -1
var _paused_world := false
var _world_hidden := false
var _in_dropout := false
var _mouse_held := false
var _mouse_was := Input.MOUSE_MODE_VISIBLE
var _key_round := 0

var _black: ColorRect
var _frame: TextureRect
var _glitch: ShaderMaterial
var _terminal: FakeTerminal
var _screen: ColorRect
var _screen_paint: ShaderMaterial
var _buzz: AudioStreamPlayer
var _crackle: AudioStreamPlayer
var _hum: AudioStreamPlayer
var _keys: Array[AudioStreamPlayer] = []
var _whoosh: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _thud: AudioStreamPlayer
var _beat: AudioStreamPlayer
var _beats := -1

## The machine (C40): the city worked out from the data, the world it is built in, the terminal's own viewport (its
## picture on the screen there), and what shows each; the player's look while falling.
var _layout: TreeLayout
var _fall: TreeFall
var _screen_port: SubViewport
var _world_view: TextureRect
var _screen_view: TextureRect
var _fade: ColorRect
var _lifted := false
var _look := Vector2.ZERO

## The link and the copy (C41): the call to the player's AI, the HUD coming alive, the beat in the machine, the user
## name the copy wears (cleaned, dropped as the opener ends), when the link locked, the copy's steps heard.
var _link: OpenerLink
var _link_beat: LinkBeat
var _pit: PitBeat
var _user := ""
var _asked_at := -1.0
var _locked_at := -1.0
var _steps_heard := 0
var _carrier: AudioStreamPlayer
var _lock: AudioStreamPlayer
var _rise: AudioStreamPlayer
var _steps: Array[AudioStreamPlayer] = []

static var _sounds := {}


func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_t = usable_tuning(tuning)
	_data = data if data != null else DemoOpenerData.new()
	_data.start()
	_link = OpenerLink.new()
	_link.guide = guide
	_palette = OpenerPalette.named(OpenerPalette.DEFAULT_ID).readable()
	_build()
	_mouse_was = Input.mouse_mode
	_mouse_held = true
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_event("live")
	if _data.is_ready():
		_take()


func _exit_tree() -> void:
	_release()


# --- What the checks (and C39 to C42) read. ---

func playing() -> bool:
	return _phase != Phase.DONE


func phase_name() -> String:
	return PHASE_NAMES[_phase]


## Seconds since it started, on its own clock (it runs through the pause).
func elapsed() -> float:
	return _elapsed


## Frames it has run.
func ticks() -> int:
	return _ticks


## What happened and when: [[seconds, name]], in order.
func events() -> Array:
	return _events


## When `what` first happened, or -1.
func event_time(what: String) -> float:
	for e in _events:
		if e[1] == what:
			return e[0]
	return -1.0


func terminal() -> FakeTerminal:
	return _terminal


## The machine the opener falls through (C40), or null before it is built (as the screen goes black) and after.
func fall() -> TreeFall:
	return _fall


## The city it is built from, or null.
func layout() -> TreeLayout:
	return _layout


## The link to the player's AI (C41): what it was told, what it said, or why the scripted guide spoke.
func link() -> OpenerLink:
	return _link


## The HUD coming alive (C41), or null before the machine is built and after.
func link_beat() -> LinkBeat:
	return _link_beat


## The beat in the machine (C41): the signal, the copy and its steps; null before the machine is built and after.
func pit() -> PitBeat:
	return _pit


## When the link locked (its line shown), on the opener's clock, or -1.
func locked_at() -> float:
	return _locked_at


## The player's look about while falling (radians: yaw, pitch).
func look() -> Vector2:
	return _look


func palette() -> OpenerPalette:
	return _palette


func timing() -> OpenerTuning:
	return _t


## The prompt as it types itself ("user@workstation:~$ ").
func prompt_text() -> String:
	return _prompt


## The late-night line as built from the file times.
func late_text() -> String:
	return _late


## How far the frozen frame has come apart (0 to 1).
func glitch_amount() -> float:
	return smoothstep(_t.glitch_from, _t.glitch_full, _elapsed) if _phase == Phase.FROZEN else 0.0


## Whether it paused the game behind it (and has not let it go yet).
func paused_world() -> bool:
	return _paused_world


## The frozen frame on screen now, or null.
func frame_texture() -> Texture2D:
	return _frame.texture if _frame != null and _frame.visible else null


## The screen's overall brightness at `seconds`, 0 (black) to 1 (the game, or the terminal in full): the model the
## crash's darkness and the terminal's pop-in are drawn from, so the flash cap is checked on what is drawn.
func luma_at(seconds: float) -> float:
	if seconds < _t.live_s:
		return 1.0
	if seconds < _t.cut_at:
		for at in _t.dropouts:
			if seconds >= at and seconds < at + _t.dropout_s:
				return 0.0
		return 1.0
	if seconds < _t.terminal_at:
		return 0.0
	if seconds >= _t.end_at:
		return 0.0
	var level := clampf((seconds - _t.terminal_at) / maxf(_t.pop_s, 0.001), 0.0, 1.0)
	if seconds >= _t.shrink_at:
		level = lerpf(1.0, MACHINE_LUMA, smoothstep(_t.shrink_at, lerpf(_t.shrink_at, _t.fall_at, 0.5), seconds))
	if seconds >= _t.forge_at:
		level *= 1.0 - clampf((seconds - _t.forge_at) / maxf(_t.end_at - _t.forge_at, 0.001), 0.0, 1.0)
	return level


## Leave now, as Esc does (C42's skip logic calls this).
func skip() -> void:
	_finish(true)


## Whether the data's values have been taken (and the lines built from them).
func taken() -> bool:
	return _taken


## The terminal recoloured in `colours` at once (made readable: OpenerPalette.readable()), its glow with it (none on
## a light theme).
func set_palette(colours: OpenerPalette) -> void:
	if colours == null:
		return
	_palette = colours.readable()
	_terminal.palette = _palette
	_screen_paint.set_shader_parameter("glow", _t.glow if _palette.mode != "light" else 0.0)


## `candidate` if its timeline holds together and keeps the PRD's windows, else the shipped one (or its defaults).
static func usable_tuning(candidate: OpenerTuning) -> OpenerTuning:
	if candidate != null:
		var issues := candidate.problems()
		if issues.is_empty():
			return candidate
		for issue in issues:
			push_warning("opener tuning: " + issue + "; using the shipped tuning instead")
	var shipped := load(DEFAULT_TUNING_PATH) as OpenerTuning
	if shipped != null and shipped.problems().is_empty():
		return shipped
	return OpenerTuning.new()


# --- The words. ---

## The prompt in its colours, bash's own: `<user>@<host>` bold green, `~` bold blue. [[text, colour], ...].
static func prompt_runs(user: String, host: String) -> Array:
	return [[user + "@" + host, "green*"], [":", "foreground"], ["~", "blue*"], ["$ ", "foreground"]]


## "up 3 days, 07:42:15", as the uptime ticks.
static func uptime_text(seconds: int) -> String:
	var days := floori(float(seconds) / DAY_S)
	var rest := posmod(seconds, DAY_S)
	var clock := "%02d:%02d:%02d" % [floori(rest / 3600.0), floori((rest % 3600) / 60.0), rest % 60]
	if days <= 0:
		return "up " + clock
	return "up %d %s, %s" % [days, "day" if days == 1 else "days", clock]


## The late-night line's segments from file times (local wall-clock seconds) and now, the echo after a beat:
## the latest time in the past week before 5 in the morning, "last night" when it is from today or yesterday,
## else its weekday ("on tuesday"); with none late, or none at all, a line that needs none.
static func late_line(times: PackedInt64Array, now: int, beat: float) -> Array:
	var latest := -1
	for at in times:
		if now > 0 and (at > now or at < now - WEEK_S):
			continue
		var hour: int = Time.get_datetime_dict_from_unix_time(at)["hour"]
		if hour < LATE_HOURS and at > latest:
			latest = at
	if latest < 0:
		return [NEVER_LATE, beat, NEVER_LATE_ECHO] if not times.is_empty() else [NO_TIMES, beat, NO_TIMES_ECHO]
	var when := Time.get_datetime_dict_from_unix_time(latest)
	var clock := "%02d:%02d" % [when["hour"], when["minute"]]
	var night := "last night"
	if now > 0:
		var days := floori(float(now) / DAY_S) - floori(float(latest) / DAY_S)
		if days > 1:
			night = "on " + WEEKDAYS[when["weekday"]]
	var head := (LATE_UP % [clock, night]) if now > 0 else ("you were still up at %s." % clock)
	return [head, beat, LATE_ECHO]


# --- The timeline. ---

## The data's values, taken once: its palette (or the default), its uptime, and every line built from its names and
## times. Its "taken" event marks when.
func _take() -> void:
	if _taken:
		return
	_taken = true
	_data.settle()
	var colours := _data.palette()
	set_palette(colours if colours != null else OpenerPalette.named(OpenerPalette.DEFAULT_ID))
	_uptime_base = maxi(_data.uptime_s(), 0)
	_build_timeline()
	_event("taken")


func _build_timeline() -> void:
	var t := _t
	var user := OpenerData.clean(_data.user(), OpenerData.NAME_LONGEST)
	var host := OpenerData.clean(_data.host(), OpenerData.NAME_LONGEST)
	_user = user if user != "" else DemoOpenerData.USER
	var runs := prompt_runs(user if user != "" else DemoOpenerData.USER, host if host != "" else DemoOpenerData.HOST)
	_prompt = ""
	for run in runs:
		_prompt += run[0]
	_typed("prompt", t.prompt_at, t.prompt_end, [_prompt], t.prompt_pace, SEED, runs, false)
	_typed("thanks", t.thanks_at, t.thanks_end, [THANKS], t.line_pace, SEED + 1, [[THANKS, "foreground"]], false)
	var comma := INSTALL.find(",") + 1
	var head := INSTALL.left(comma)
	var word := head.find(TYPO_WORD)
	var install := [head.left(word), Typist.typo(TYPO, TYPO_BACK), head.substr(word + TYPO.length() - TYPO_BACK), t.install_beat, INSTALL.substr(comma)]
	_typed("install", t.install_at, t.install_end, install, t.line_pace, SEED + 2, [[INSTALL, "foreground"]], true)
	_folders(t.folders_at, t.folders_end)
	_actions.append({"at": t.uptime_at, "op": "uptime"})
	var since_cut := SINCE.find(" since")
	_typed("since", t.since_at, t.since_end, [SINCE.left(since_cut), t.since_beat, SINCE.substr(since_cut)], t.line_pace, SEED + 3, [[SINCE, "foreground"]], false)
	var late := late_line(_data.file_times(), _data.now(), t.late_beat)
	_late = Typist.text_of_segments(late)
	_typed("late", t.late_at, t.late_end, late, t.line_pace, SEED + 4, [[_late, "foreground"]], true)
	_actions.append({"at": t.rest_at, "op": "newline", "event": "rest"})
	# The shrink-away (C40): a fresh prompt on the cursor's line at once, as a shell gives one, ignoring what is
	# typed at it; then "you're in now." types itself there.
	_actions.append({"at": t.hold_until, "op": "runs", "runs": runs})
	_typed("in", t.in_at, t.in_end, [IN_NOW], t.line_pace, SEED + 5, [[IN_NOW, "foreground"]], false)


## A line that types itself from `at`, done by `end` at the latest, in its runs' colours; on a new line first if
## `own_line`. Its first and last keys are its "<id>_start" and "<id>_done".
func _typed(id: String, at: float, end: float, segments: Array, pace: float, seed: int, runs: Array, own_line: bool) -> void:
	var keys := Typist.fit(Typist.plan(segments, seed, pace), maxf(end - at, 0.05))
	if own_line:
		_actions.append({"at": at, "op": "newline"})
	var pos := 0
	for i in keys.size():
		var key: String = keys[i]["key"]
		var action := {"at": at + keys[i]["at"], "op": "key", "key": key, "attr": "foreground"}
		if key == Typist.BACKSPACE:
			pos = maxi(pos - 1, 0)
		else:
			action["attr"] = _run_attr(runs, pos)
			pos += 1
		if i == 0:
			action["event"] = id + "_start"
		if i == keys.size() - 1:
			action["event2"] = id + "_done"
		_actions.append(action)


## The folder names scrolling past from `at`, the last by `end`, speeding up as they go.
func _folders(at: float, end: float) -> void:
	var names := PackedStringArray()
	for folder in _data.folders():
		var shown := OpenerData.clean(folder, OpenerData.FOLDER_LONGEST)
		if shown != "":
			names.append(shown)
		if names.size() >= _t.folders_most:
			break
	if names.is_empty():
		return
	var gaps := PackedFloat32Array()
	var total := 0.0
	for i in names.size():
		var gap := lerpf(_t.folder_gap_first, _t.folder_gap_last, float(i) / maxf(names.size() - 1, 1))
		gaps.append(gap)
		total += gap
	var k := minf(1.0, (end - at) / maxf(total, 0.001))
	var when := at
	for i in names.size():
		when += gaps[i] * k
		var action := {"at": when, "op": "print", "text": "~/" + names[i], "attr": "blue"}
		if i == 0:
			action["event"] = "folders_start"
		if i == names.size() - 1:
			action["event2"] = "folders_done"
		_actions.append(action)


static func _run_attr(runs: Array, pos: int) -> String:
	var at := 0
	for run in runs:
		at += String(run[0]).length()
		if pos < at:
			return run[1]
	return runs[-1][1] if not runs.is_empty() else "foreground"


# --- Running. ---

func _process(delta: float) -> void:
	if _phase == Phase.DONE:
		return
	_elapsed += delta / maxf(Engine.time_scale, 0.01)
	_ticks += 1
	if not _taken and (_elapsed >= _t.take_by or _data.is_ready()):
		_take()
	_step_crash()
	_step_actions()
	_step_uptime()
	_step_screen()
	_step_machine(delta / maxf(Engine.time_scale, 0.01))
	_step_link(delta / maxf(Engine.time_scale, 0.01))
	if _elapsed >= _t.end_at:
		_finish(false)


func _step_crash() -> void:
	if _phase == Phase.LIVE and _elapsed >= _t.live_s:
		_freeze()
	if _phase == Phase.FROZEN and _elapsed >= _t.cut_at:
		_cut()
	if _phase == Phase.FROZEN:
		var amount := glitch_amount()
		var step := floori(_elapsed * _t.glitch_hz)
		var level := luma_at(_elapsed)
		if level <= 0.0 and not _in_dropout:
			_event("dropout")
		_in_dropout = level <= 0.0
		_glitch.set_shader_parameter("amount", amount)
		_glitch.set_shader_parameter("dark", 1.0 - level)
		if step != _glitch_step:
			_glitch_step = step
			_glitch.set_shader_parameter("seed", float(step))
			# The stuck buffer slips a little in pitch with each jerk of the picture.
			_buzz.pitch_scale = 1.0 - amount * 0.07 * float((step * 7919) % 5) / 4.0
		if amount > 0.0 and not _crackle.playing:
			_crackle.play()
		_crackle.volume_db = SfxSynth.volume_db(_t.crackle_volume * amount)
	if _phase == Phase.BLACK:
		if _elapsed >= _t.hum_from and not _hum.playing:
			_hum.play()
		if _elapsed >= _t.terminal_at:
			_phase = Phase.TERMINAL
			_terminal.visible = true
			_screen.visible = true
			_event("terminal")
	if _phase == Phase.BLACK and _fall == null:
		_build_machine()
	if _hum.playing:
		var away := 1.0 - smoothstep(_t.shrink_at, _t.fall_at - 2.0, _elapsed)
		_hum.volume_db = SfxSynth.volume_db(_t.hum_volume * clampf(inverse_lerp(_t.hum_from, _t.hum_full, _elapsed), 0.0, 1.0) * away)
	if _phase == Phase.TERMINAL or _phase == Phase.HOLD:
		_terminal.pop = luma_at(_elapsed)
	if _phase == Phase.TERMINAL and _elapsed >= _t.rest_at:
		_phase = Phase.HOLD
		_event("hold")
	if _phase == Phase.HOLD and _elapsed >= _t.hold_until:
		_phase = Phase.IGNORE
		_event("ignore")
	if _phase == Phase.IGNORE and _elapsed >= _t.hold_until + _t.ignore_s:
		_phase = Phase.IN
		_event("ignore_done")


func _freeze() -> void:
	_phase = Phase.FROZEN
	_frame.texture = _take_frame()
	_black.visible = true
	_frame.visible = true
	# From here on this covers the whole screen: the arena's 3D view is not drawn under it (given back as it ends).
	if not get_viewport().disable_3d:
		get_viewport().disable_3d = true
		_world_hidden = true
	_glitch.set_shader_parameter("lines", maxf(_frame.size.y, 1.0))
	if pause_world and not get_tree().paused:
		get_tree().paused = true
		_paused_world = true
	_buzz.play()
	_event("freeze")


# --- The machine (C40). ---

## The city from the data's folders and counts (taken and settled: the same the terminal scrolled), and the world
## it is built in, while the screen is black; drawn once there so its first real frame never stalls.
func _build_machine() -> void:
	_layout = TreeLayout.build(_data.folders(), _data.folder_counts())
	_fall = TreeFall.new()
	_fall.name = "Machine"
	_fall.shrink_at = _t.shrink_at
	_fall.fall_at = _t.fall_at
	_fall.land_at = _t.land_at
	var hot := OpenerData.clean(_data.top_process(), TreeLayout.LABEL_LONGEST)
	_fall.process_name = hot if hot != "" else DemoOpenerData.TOP_PROCESS
	add_child(_fall)
	_screen_port = SubViewport.new()
	_screen_port.name = "TerminalScreen"
	_screen_port.disable_3d = true
	_screen_port.transparent_bg = false
	_screen_port.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_screen_port)
	_screen_view = _view("TerminalView", _screen_port.get_texture())
	_world_view = _view("MachineView", _fall.get_texture())
	# The HUD coming alive (C41), over the machine and under the fade.
	_link_beat = LinkBeat.new()
	add_child(_link_beat)
	_link_beat.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_link_beat.setup(_t)
	_fade = ColorRect.new()
	_fade.name = "Fade"
	_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	_full(_fade)
	_fade.visible = true
	_size_ports()
	get_viewport().size_changed.connect(_size_ports)
	_fall.build(_layout, _palette, GameSettings.current().graphics()["bloom"])
	_fall.set_screen(_screen_port.get_texture(), Vector2(_screen_port.size))
	# The link's signal and the copy (C41), in the machine's world, hidden until their moments.
	_pit = PitBeat.new()
	_pit.build(_palette, _t, _fall.void_color())
	_fall.add_child(_pit)
	_fall.render_target_update_mode = SubViewport.UPDATE_ONCE
	_event("machine")


func _view(node_name: String, texture: Texture2D) -> TextureRect:
	var view := TextureRect.new()
	view.name = node_name
	view.texture = texture
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE
	_full(view)
	return view


## Both viewports the window's size; the screen's panel the window's shape.
func _size_ports() -> void:
	if _fall == null:
		return
	var pixels := get_viewport().get_visible_rect().size
	var whole := Vector2i(maxi(roundi(pixels.x), 2), maxi(roundi(pixels.y), 2))
	_fall.size = whole
	_screen_port.size = whole
	_fall.set_aspect(float(whole.x) / whole.y)
	_fall.set_screen(_screen_port.get_texture(), Vector2(whole))


func _step_machine(delta: float) -> void:
	if _fall == null or _phase == Phase.DONE:
		return
	if _phase == Phase.IN and not _lifted and _elapsed >= _t.shrink_at - LIFT_S:
		_lift()
	if _phase == Phase.IN and _elapsed >= _t.shrink_at:
		_phase = Phase.REVEAL
		_world_view.visible = true
		_screen_view.visible = false
		_whoosh.play()
		_event("reveal")
	if _phase == Phase.REVEAL and _elapsed >= _t.fall_at:
		_phase = Phase.FALL
		# The screen is behind the camera from here on: its picture stays as it was, no longer drawn.
		_screen_port.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_wind.volume_db = SfxSynth.volume_db(0.0)
		_wind.play()
		_event("fall")
	if _phase == Phase.FALL and _elapsed >= _t.land_at:
		_phase = Phase.LANDED
		_wind.stop()
		_thud.play()
		_event("land")
	if _phase == Phase.LANDED and _elapsed >= _t.handoff_at and event_time("handoff") < 0.0:
		_event("handoff")
	if _phase == Phase.LANDED and _elapsed >= _t.link_at:
		_phase = Phase.LINK
		_event("link")
	if _phase == Phase.LINK and _elapsed >= _t.copy_at:
		_phase = Phase.COPY
		_event("copy")
	if _phase == Phase.REVEAL or _phase == Phase.FALL or _phase == Phase.LANDED or _phase == Phase.LINK or _phase == Phase.COPY:
		_look = TreeFall.settle_look(_look, delta)
		var seeing := _look + PitBeat.scripted_look(_elapsed, _t)
		_fall.pit_dim = smoothstep(_t.copy_at - 0.5, _t.copy_at + 2.5, _elapsed)
		_fall.step(_elapsed, seeing)
		_pit.step(_elapsed, seeing, _fall.eye())
		var speed := _fall.speed_at(_elapsed)
		if _wind.playing:
			var k := clampf(speed / 40.0, 0.0, 1.0)
			_wind.volume_db = SfxSynth.volume_db(_t.wind_volume * k)
			_wind.pitch_scale = lerpf(0.6, 1.25, k)
		var beat := floori(_elapsed * TreeFall.BEAT_HZ)
		if _phase != Phase.REVEAL and beat != _beats and _elapsed > lerpf(_t.fall_at, _t.land_at, 0.45):
			_beats = beat
			_beat.volume_db = SfxSynth.volume_db(_t.beat_volume * smoothstep(_t.fall_at, _t.land_at, _elapsed))
			_beat.play()
		_fade.color.a = clampf((_elapsed - _t.forge_at) / maxf(_t.end_at - _t.forge_at, 0.001), 0.0, 1.0)


# --- The link and the copy (C41). ---

## The call to the player's AI from ask_at (it runs on through the fall, never shown), the HUD coming alive with the
## signal, the lock as its line shows (no sooner than answer_from; at answer_by the scripted line if no answer came),
## the guide's line, the copy's rise and each of its steps, and the hand-off to C42.
func _step_link(delta: float) -> void:
	if _phase == Phase.DONE:
		return
	if _asked_at < 0.0 and _elapsed >= _t.ask_at:
		_asked_at = _elapsed
		_link.begin(_elapsed)
		_event("ask")
	if _asked_at >= 0.0:
		_link.step(_elapsed, delta * 1000.0, _t.answer_by)
	if _link_beat == null or _pit == null:
		return
	if _link_beat.badge_text() == "" and _asked_at >= 0.0:
		_link_beat.set_agent(_link.agent())
	_link_beat.step(_elapsed)
	if _elapsed >= _t.signal_at and event_time("signal") < 0.0:
		_event("signal")
		_carrier.play()
	if _locked_at < 0.0 and _elapsed >= _t.answer_from and _link.done():
		_locked_at = _elapsed
		_pit.set_lock(_elapsed)
		_link_beat.lock(_elapsed, _link.line(), _link.live(), _link.latency_ms(), _link.why(), _link.agent())
		_event("answer" if _link.live() else "scripted")
		_lock.play()
	if _elapsed >= _t.guide_at and event_time("guide_start") < 0.0:
		_event("guide_start")
	if _elapsed >= _t.guide_end and event_time("guide_done") < 0.0:
		_event("guide_done")
	if _elapsed >= _t.copy_at and event_time("rise") < 0.0:
		_pit.set_name_tag(_user)
		_rise.play()
		_event("rise")
	var heard := _pit.steps_by(_elapsed)
	if heard > _steps_heard:
		_steps_heard = heard
		var foot := _steps[heard % _steps.size()]
		foot.volume_db = SfxSynth.volume_db(_t.step_volume * lerpf(0.4, 1.0, float(heard) / PitBeat.STEPS))
		foot.play()
		if event_time("step") < 0.0:
			_event("step")
	if _elapsed >= _t.copy_stop and event_time("stand") < 0.0:
		_event("stand")
	if _elapsed >= _t.forge_at and event_time("forge") < 0.0:
		_event("forge")


## The terminal and its screen into a viewport of their own (their picture, shown at once as it was, the window's
## size, pixel for pixel), which the panel in the machine shows; the machine drawn from now on.
func _lift() -> void:
	_lifted = true
	_screen_port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_fall.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_fall.step(_t.shrink_at, Vector2.ZERO)
	for control in [_terminal, _screen]:
		control.reparent(_screen_port, false)
		control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen_view.visible = true
	_event("lift")


func _cut() -> void:
	_phase = Phase.BLACK
	_frame.visible = false
	_frame.texture = null  # the frozen frame is let go: it lived only in memory, only for the crash
	_buzz.stop()
	_crackle.stop()
	_event("cut")


func _step_actions() -> void:
	while _next < _actions.size() and _actions[_next]["at"] <= _elapsed:
		var action: Dictionary = _actions[_next]
		_next += 1
		if action.has("event"):
			_event(action["event"])
		match action["op"]:
			"key":
				if action["key"] == Typist.BACKSPACE:
					_terminal.back()
					_click(-2)
				else:
					_terminal.put(action["key"], action["attr"])
					_click(-1 if action["key"] == " " else _next % SfxSynth.OPENER_KEYS)
			"print":
				_terminal.print_line(action["text"], action["attr"])
			"newline":
				_terminal.newline()
			"runs":
				for run in action["runs"]:
					for ch in String(run[0]):
						_terminal.put(ch, run[1])
			"uptime":
				_uptime_line = _terminal.print_line(uptime_text(_uptime_now()), "yellow")
				_uptime_shown = _uptime_now()
				_event("uptime")
		if action.has("event2"):
			_event(action["event2"])


func _uptime_now() -> int:
	return _uptime_base + floori(_elapsed)


func _step_uptime() -> void:
	if _uptime_line < 0:
		return
	var now := _uptime_now()
	if now != _uptime_shown:
		_uptime_shown = now
		_terminal.set_line(_uptime_line, uptime_text(now), "yellow")


func _step_screen() -> void:
	var torn := _elapsed >= _t.tear_at and _elapsed < _t.tear_at + _t.tear_s
	if torn and event_time("tear") < 0.0:
		_event("tear")
		var rows := _terminal.text().split("\n").size()
		var area := _terminal.text_rect()
		var y := area.position.y + (maxi(rows - 2, 0) + 0.5) * _terminal.line_px()
		_screen_paint.set_shader_parameter("tear_y", y / maxf(_terminal.size.y, 1.0))
		_screen_paint.set_shader_parameter("tear_h", 0.6 * _terminal.line_px() / maxf(_terminal.size.y, 1.0))
	_screen_paint.set_shader_parameter("tear", _t.tear_shift if torn else 0.0)


func _finish(skipped: bool) -> void:
	if _phase == Phase.DONE:
		return
	_phase = Phase.DONE
	_event("skipped" if skipped else "done")
	for player in [_buzz, _crackle, _hum, _whoosh, _wind, _thud, _beat, _carrier, _lock, _rise] + _keys + _steps:
		player.stop()
	_link.stop()
	_release()
	finished.emit(skipped)


## The game behind un-paused and its 3D view drawn again (if this paused or hid them), the mouse as it was, and the
## data dropped (whatever it read let go): as it ends, and if it is ever freed mid-way.
func _release() -> void:
	if _data != null:
		_data.drop()
	if _link != null:
		_link.stop()
	# The user name the copy wore goes with the data; the copy and its name tag go with the machine (C41).
	_user = ""
	_pit = null
	if _link_beat != null:
		_link_beat.visible = false
		_link_beat.queue_free()
		_link_beat = null
	# The city and the machine built from the data go with it, and nothing goes on showing their pictures.
	_layout = null
	for view in [_world_view, _screen_view]:
		if view != null:
			view.visible = false
			view.texture = null
	if _fall != null:
		if is_inside_tree() and get_viewport().size_changed.is_connected(_size_ports):
			get_viewport().size_changed.disconnect(_size_ports)
		_fall.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_fall.queue_free()
		_fall = null
	if _paused_world:
		_paused_world = false
		if is_inside_tree():
			get_tree().paused = false
	if _world_hidden:
		_world_hidden = false
		if is_inside_tree():
			get_viewport().disable_3d = false
	if _mouse_held:
		_mouse_held = false
		Input.mouse_mode = _mouse_was


func _event(what: String) -> void:
	_events.append([_elapsed, what])


## The game's own last frame, held in memory for the crash only (never saved), or a near-black stand-in.
func _take_frame() -> Texture2D:
	if freeze_frame and DisplayServer.get_name() != "headless":
		var image := get_viewport().get_texture().get_image()
		if image != null and not image.is_empty():
			return ImageTexture.create_from_image(image)
	var still := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	still.fill(NO_FRAME)
	return ImageTexture.create_from_image(still)


# --- Input: Esc leaves, nothing else does anything. ---

func _input(event: InputEvent) -> void:
	if _phase == Phase.DONE:
		return
	if _is_escape(event):
		get_viewport().set_input_as_handled()
		_finish(true)
		return
	# The fake terminal ignores typing, and nothing behind it acts on a key or a click while it plays.
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()
	# Falling, the player may look about a little (TreeFall.LOOK_MOST), never steer.
	if event is InputEventMouseMotion and (_phase == Phase.FALL or _phase == Phase.LANDED or _phase == Phase.LINK or _phase == Phase.COPY):
		_look = TreeFall.add_look(_look, (event as InputEventMouseMotion).relative)


static func _is_escape(event: InputEvent) -> bool:
	var key := event as InputEventKey
	if key != null:
		return key.pressed and not key.echo and (key.keycode == KEY_ESCAPE or key.physical_keycode == KEY_ESCAPE)
	return event.is_action_pressed("ui_cancel")


# --- Building. ---

func _build() -> void:
	_black = ColorRect.new()
	_black.name = "Black"
	_black.color = Color.BLACK
	_full(_black)
	_frame = TextureRect.new()
	_frame.name = "FrozenFrame"
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_glitch = ShaderMaterial.new()
	_glitch.shader = GlitchShader
	_glitch.set_shader_parameter("bleed", BLEED)
	_frame.material = _glitch
	_full(_frame)
	_terminal = FakeTerminal.new()
	_terminal.name = "Terminal"
	_terminal.palette = _palette
	_terminal.pop = 0.0
	_full(_terminal)
	_screen = ColorRect.new()
	_screen.name = "Screen"
	_screen_paint = ShaderMaterial.new()
	_screen_paint.shader = ScreenShader
	_screen_paint.set_shader_parameter("glow_px", _t.glow_px)
	_screen_paint.set_shader_parameter("glow_from", _t.glow_from)
	_screen_paint.set_shader_parameter("scanline_dark", _t.scanline_dark)
	_screen_paint.set_shader_parameter("scanline_px", _t.scanline_px)
	_screen_paint.set_shader_parameter("vignette", _t.vignette)
	_screen.material = _screen_paint
	_full(_screen)
	set_palette(_palette)
	_buzz = _player("Buzz", "buzz", _t.buzz_volume)
	_crackle = _player("Crackle", "crackle", 0.0)
	_hum = _player("Hum", "hum", 0.0)
	for i in 3:
		_keys.append(_player("Key%d" % (i + 1), "", _t.key_volume))
	_whoosh = _player("Whoosh", "whoosh", _t.whoosh_volume)
	_wind = _player("Wind", "wind", 0.0)
	_thud = _player("Thud", "thud", _t.thud_volume)
	_beat = _player("Beat", "beat", _t.beat_volume)
	_carrier = _player("Carrier", "carrier", _t.link_volume)
	_lock = _player("Lock", "lock", _t.lock_volume)
	_rise = _player("Rise", "rise", _t.rise_volume)
	for i in 2:
		_steps.append(_player("Step%d" % (i + 1), "step", _t.step_volume))


func _full(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.visible = false
	add_child(control)
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _player(node_name: String, sound: String, volume: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = node_name
	player.bus = SettingsApply.EFFECTS if AudioServer.get_bus_index(SettingsApply.EFFECTS) >= 0 else &"Master"
	player.volume_db = SfxSynth.volume_db(volume)
	if sound != "":
		player.stream = _sound(sound)
	add_child(player)
	return player


## A key's click on the next of the key players, in turn: variant -1 the space bar, -2 a backspace.
func _click(variant: int) -> void:
	var player := _keys[_key_round % _keys.size()]
	_key_round += 1
	player.stream = _sound("key%d" % variant)
	player.play()


## The opener's sounds, made once a run and kept.
static func _sound(sound: String) -> AudioStreamWAV:
	if not _sounds.has(sound):
		match sound:
			"buzz":
				_sounds[sound] = SfxSynth.opener_buzz()
			"crackle":
				_sounds[sound] = SfxSynth.opener_crackle()
			"hum":
				_sounds[sound] = SfxSynth.opener_hum()
			"whoosh":
				_sounds[sound] = SfxSynth.opener_whoosh()
			"wind":
				_sounds[sound] = SfxSynth.opener_wind()
			"thud":
				_sounds[sound] = SfxSynth.opener_thud()
			"beat":
				_sounds[sound] = SfxSynth.opener_beat()
			"carrier":
				_sounds[sound] = SfxSynth.opener_carrier()
			"lock":
				_sounds[sound] = SfxSynth.opener_lock()
			"rise":
				_sounds[sound] = SfxSynth.opener_rise()
			"step":
				_sounds[sound] = SfxSynth.opener_step()
			_:
				_sounds[sound] = SfxSynth.opener_key(int(sound.trim_prefix("key")))
	return _sounds[sound]
