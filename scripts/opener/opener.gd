class_name Opener
extends CanvasLayer
## The opener's first 35 seconds (C38; PRD 5.7, "you got tricked into this", 0:00 to 0:35), live in the engine:
##   0:00 to 0:15  the game freezes on its own last frame, stutters, comes apart and cuts to black and silence (a
##                 fake crash: the game glitching inside its own window, never a dialog, never the desktop, never a
##                 real freeze); then a fake terminal in the player's theme, and `<user>@<host>:~$` types itself.
##   0:15 to 0:35  "thanks for running me." / "you never read the install script, did you?", folder names scroll,
##                 the uptime ticks, "I've been in here since you booted.", and the late-night line from recent
##                 file times. Then it holds on the terminal and hands back to the menu (C40 goes on from there).
## Every word in quotes is the PRD's own (THANKS, INSTALL, SINCE); the late-night line's words are ours, built
## from the file times alone (late_line). Text types itself as a hand types (scripts/opener/typist.gd): its own
## wait for every key, a hesitation before the punchlines, one typo taken back.
##
## The data comes through one seam, OpenerData (scripts/opener/opener_data.gd): `data`, started as this starts and
## taken once, as soon as it is ready or at the tuning's take_by second regardless (while the screen is still the
## crash or black, before anything of it shows), then dropped as this ends. DemoOpenerData (fixed, invented,
## nothing read) is always ready; RealOpenerData (C39, only with the player's yes) reads on its own thread, and
## anything it has not got by then is the demo's. Nothing here reads the machine: no file but res://, no
## environment, no clock, no process, no network; the reader is the one place that does.
##
## A real way out, always: Esc leaves at any moment, mid-crash and mid-typing included (`finished(true)`), and the
## window's close is never touched (Godot's own quit). The main loop never stops: the "freeze" is a picture held on
## screen while every frame still runs and every key is still read. Played from the Esc menu alone, the arena
## behind is paused (`pause_world`) so nothing can hit the player while it plays, and goes on as it was after;
## this layer and its sounds run through the pause. The mouse is hidden while it plays and given back after.
## Flash-safe: the screen's overall brightness follows luma_at(), which never flashes 3 or more times in any
## second (two short drops to black in the crash, then the cut), and the glitch's pattern jerks at glitch_hz.
##
## Sound, all made in scripts/sfx_synth.gd: the frozen game's stuck buffer buzzing, its picture's crackle, dead
## silence at the cut, a low hum under the terminal, and a keyboard's clicks as the text types itself.

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
## The PRD's two windows, in seconds: the crash and the prompt, then the lines.
const CRASH_WINDOW := Vector2(0.0, 15.0)
const LINES_WINDOW := Vector2(15.0, 35.0)
## A frozen frame's stand-in when there is none to take (a headless run): near black.
const NO_FRAME := Color(0.02, 0.02, 0.03)
## How the glitch tints a corrupted band: the daemons' glitch magenta (A4).
const BLEED := Color(1.0, 0.17, 0.84)

enum Phase { LIVE, FROZEN, BLACK, TERMINAL, HOLD, DONE }
const PHASE_NAMES := ["live", "frozen", "black", "terminal", "hold", "done"]

## What it shows of "your machine"; null: DemoOpenerData.
var data: OpenerData = null
## The timeline; null (or one with problems): resources/opener.tres.
var tuning: OpenerTuning = null
## Pause the game behind while it plays (alone, from the menu); never in a match, where the menu offers no opener.
var pause_world := false
## Freeze the game's own last frame for the crash (never in a headless run, which draws nothing).
var freeze_frame := true

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

static var _sounds := {}


func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_t = usable_tuning(tuning)
	_data = data if data != null else DemoOpenerData.new()
	_data.start()
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
	return clampf((seconds - _t.terminal_at) / maxf(_t.pop_s, 0.001), 0.0, 1.0)


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
	var colours := _data.palette()
	set_palette(colours if colours != null else OpenerPalette.named(OpenerPalette.DEFAULT_ID))
	_uptime_base = maxi(_data.uptime_s(), 0)
	_build_timeline()
	_event("taken")


func _build_timeline() -> void:
	var t := _t
	var user := OpenerData.clean(_data.user(), OpenerData.NAME_LONGEST)
	var host := OpenerData.clean(_data.host(), OpenerData.NAME_LONGEST)
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
	if _elapsed >= _t.hold_until:
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
	if _hum.playing:
		_hum.volume_db = SfxSynth.volume_db(_t.hum_volume * clampf(inverse_lerp(_t.hum_from, _t.hum_full, _elapsed), 0.0, 1.0))
	if _phase == Phase.TERMINAL or _phase == Phase.HOLD:
		_terminal.pop = luma_at(_elapsed)
	if _phase == Phase.TERMINAL and _elapsed >= _t.rest_at:
		_phase = Phase.HOLD
		_event("hold")


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
	for player in [_buzz, _crackle, _hum] + _keys:
		player.stop()
	_release()
	finished.emit(skipped)


## The game behind un-paused and its 3D view drawn again (if this paused or hid them), the mouse as it was, and the
## data dropped (whatever it read let go): as it ends, and if it is ever freed mid-way.
func _release() -> void:
	if _data != null:
		_data.drop()
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
			_:
				_sounds[sound] = SfxSynth.opener_key(int(sound.trim_prefix("key")))
	return _sounds[sound]
