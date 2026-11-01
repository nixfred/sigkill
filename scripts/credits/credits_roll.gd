class_name CreditsRoll
extends CanvasLayer
## The credits roll (C44; PRD 5.8, docs/STORY.md section 7): the ending's last beat, the adoption made visible. A live
## `top` on the Tron grid, every contributor a process (scripts/credits/credits_cast.gd), drawn in the game's own
## language, the three registers taking turns behind it. On the score's bars (scripts/credits/credits_score.gd):
##   0.0    black; `$ top -p sigkill --credits` types itself in a terminal window over the grid
##   3.2    top's summary lines and its column heads; the title card, CREDITS
##   6.4    a row every two bars: each one rains in as code (every character a falling stream locking into place), its
##          %CPU climbing, its branch reaching the trunk and a packet of light running up to init, who adopts it; and
##          its hero card beside the table (the giant PID behind, the name dropping in a letter a sixteenth, the
##          handle, the command, what they made), drawn in its register: Tron's clean grid, the Matrix's rain, the
##          ruins' neon with its reflection in the wet
##   32.0   root's threads, a beat each: the open projects the game borrows from, and the engine, with thanks
##   38.4   the adoption: every branch flashing up to init
##   41.6   the row that should not be there, typed in red, its branch reaching for init and refused
##   44.8   `root# `, the rail's reticle and how to fire: the player's own kill -9 (fire, Enter or Space; it types
##          itself after WAIT_S); `kill -9 $(pidof top)`, and the shot
##   shot   the table derezzes into voxels from the prompt outward; black; SIGKILL slams in on the nixfred hexagon (the
##          brand's own icon file, as it is); torn away
##   after  STORY.md's beat after the credits: a bare `>_`, its cursor blinking, nothing typing itself; then finished.
## Esc skips to that bare prompt (and past it). Every other key and click is kept from the game behind it. It sits over
## the HUD and under the colourblind filter; once the screen is black the arena's 3D is not drawn under it, and with
## `pause_world` (the Esc menu's replay) the game behind is paused while it plays. Nothing here reads, names, runs or
## sends anything: its text is the cast's and its own.

signal finished(skipped: bool)

const Palette = preload("res://scripts/palette.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")
const SfxSynth = preload("res://scripts/sfx_synth.gd")
const Controls = preload("res://scripts/controls.gd")
## The brand's icon, the file itself (the opener's title slams the same file): never redrawn, nothing put inside it.
const LOGO := preload("res://packaging/linux/sigkill.svg")

const LAYER := 90
const DESIGN := Vector2(1920.0, 1080.0)
const BAR_S := OpenerScore.BAR_S
const BEAT_S := OpenerScore.BEAT_S
const STEP_S := OpenerScore.STEP_S
## The clock, in seconds from the start, on the score's bars.
const FADE_S := 0.4
const TYPE_AT := 0.4
const TITLE_AT := CreditsScore.TITLE_BAR * BAR_S
const CAST_AT := CreditsScore.CAST_BAR * BAR_S
const CAST_EVERY_S := CreditsScore.CAST_EVERY * BAR_S
const THANKS_AT := CreditsScore.THANKS_BAR * BAR_S
const THREAD_EVERY_S := BEAT_S
const QUIET_AT := CreditsScore.QUIET_BAR * BAR_S
const LAST_AT := CreditsScore.LAST_BAR * BAR_S
const WAIT_AT := CreditsScore.ROLL_BARS * BAR_S
## How long the prompt waits for the player before the command types itself.
const WAIT_S := 9.6
## From the player's press: the command typing, then the shot (on the next sixteenth).
const KILL_TYPE_S := 0.5
## From the shot: the voxels flying, the black, the slam, the title torn away, the bare prompt.
const DEREZZ_S := 2.2
const BLACK_AFTER := 2.4
const SLAM_AFTER := CreditsScore.KILL_SLAM_BEATS * BEAT_S
const OUT_FROM := 7.6
const OUT_TO := 8.4
const BARE_AFTER := 8.8
const BARE_S := 1.0
## A row raining in: how long its streams fall, how long a character burns white once locked; %CPU's climb.
const RAIN_S := 0.7
const BURN_S := 0.35
## A row is settled (drawn whole, a colour a column) this long after it lands.
const SETTLE_S := 0.7
const CLIMB_S := 0.9
## The last row's typing, characters a second.
const LAST_CPS := 14.0
const PROMPT_LINE := "$ top -p sigkill --credits"
const ROOT_PROMPT := "root# "
const COMMAND := "kill -9 $(pidof " + CreditsCast.TOP + ")"
const KILL_HINT := "[%s]  kill -9"
const SKIP_HINT := "Esc: skip"
const TITLE := "SIGKILL"
const CARD_TITLE := "CREDITS"
const CARD_SUB := "every process that built this machine"
const BARE := ">_"
const SUMMARY_1 := "top - 00:00:%02d up 7 missions,  1 user,  load average: %s, %s, %s"
const SUMMARY_2 := "Tasks: %2d total,   1 running, %2d sleeping,   0 stopped,   0 zombie"
## Linear volume of the score on the Music bus.
const SCORE_VOLUME := 0.9
## The code rain's glyphs (plain ASCII, in every mono font).
const GLYPHS := "0123456789abcdef<>/|_-=+*#$%&@!?;:{}[]"
const RAIN_COLUMNS := 64
const RAIN_LONGEST := 16
const SKYLINE := 34
const STREAKS := 90
const EMBERS := 60
const SPARKS := 40
const VOX_PER_CHAR := 3
enum Phase { TYPING, TABLE, WAIT, KILL, TITLE, BARE, DONE }
const PHASE_NAMES := ["typing", "table", "wait", "kill", "title", "bare", "done"]
const REGISTERS := ["tron", "matrix", "cyberpunk"]

## How many times a roll has opened this run (the checks: it plays once per ending, and nowhere else).
static var plays := 0
## The main thread's time in the roll's own drawing last frame, in microseconds (the capture tool reports it).
var draw_us := 0

## Pause the game behind while it plays (the Esc menu's replay; never a match, where the menu offers none).
var pause_world := false
## Where it came from, for the checks: "ending" or "menu".
var reason := ""

var _t := 0.0
var _up := false
var _press := -1.0
var _shot := -1.0
var _bare := -1.0
var _skipped := false
var _rows: Array = []
var _arrive := PackedFloat32Array()
var _canvas: Control
var _font: Font
var _name_font: Font
var _music := {}
var _paused_world := false
var _world_hidden := false
var _mouse_was := Input.MOUSE_MODE_VISIBLE
var _weights := Vector3(1.0, 0.0, 0.0)
var _scroll := 0.0
var _fire_label := "left mouse"
## The derezz: every glyph on screen at the shot, as voxels (its place, colour, size; a seed each).
var _vox_pos := PackedVector2Array()
var _vox_col := PackedColorArray()
var _vox_size := PackedFloat32Array()
var _vox_made := false
var _collect := false
var _origin := Vector2.ZERO
## While collecting: [at, text, colour, size, mono] of every string the table drew this frame.
var _cells: Array = []


func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_rows = CreditsCast.rows()
	_arrive.resize(_rows.size())
	for i in CreditsCast.CAST.size():
		_arrive[i] = CAST_AT + i * CAST_EVERY_S
	for j in CreditsCast.THANKS.size():
		_arrive[CreditsCast.CAST.size() + j] = THANKS_AT + j * THREAD_EVERY_S
	_arrive[_rows.size() - 1] = LAST_AT


func _ready() -> void:
	_font = Palette.mono_font()
	_name_font = TreeFall.label_font()
	_canvas = Control.new()
	_canvas.name = "Roll"
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_canvas.draw.connect(_draw_all)
	add_child(_canvas)
	if InputMap.has_action("fire"):
		var events := InputMap.action_get_events("fire")
		if not events.is_empty():
			_fire_label = Controls.bind_label(Controls.bind_of(events[0]))


# --- Playing it. ---

## Up from its first frame. `why`: "ending" (the finale's) or "menu" (the Esc menu's replay).
func open(why: String) -> void:
	if _up:
		return
	plays += 1
	reason = why
	_t = 0.0
	_press = -1.0
	_shot = -1.0
	_bare = -1.0
	_skipped = false
	_vox_made = false
	_scroll = 0.0
	_weights = Vector3(1.0, 0.0, 0.0)
	_up = true
	visible = true
	CreditsScore.prepare()
	_mouse_was = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	if pause_world and is_inside_tree() and not get_tree().paused:
		get_tree().paused = true
		_paused_world = true
	if _canvas != null:
		_canvas.queue_redraw()


func is_up() -> bool:
	return _up


func elapsed() -> float:
	return _t


## Jumps its clock forward to `seconds` (the checks and the capture tool); never back.
func seek(seconds: float) -> void:
	if _up and seconds > _t:
		_t = seconds
		_step(0.0)


## Esc: on to the bare prompt now, or past it.
func skip() -> void:
	if not _up:
		return
	if _bare < 0.0:
		_skipped = true
		_bare = _t
		_stop_music()
	else:
		_finish()


## Ends it now, nothing more shown (the Esc menu closing under it).
func end_now() -> void:
	if _up:
		_skipped = true
		_finish()


## The player's own kill -9 (fire, Enter or Space while the prompt waits). False when the prompt is not waiting.
func kill_now() -> bool:
	if not _up or _press >= 0.0 or _bare >= 0.0 or _t < WAIT_AT:
		return false
	_press = _t
	_shot = ceilf((_press + KILL_TYPE_S) / STEP_S - 0.001) * STEP_S
	return true


func phase() -> Phase:
	if not _up:
		return Phase.DONE
	if _bare >= 0.0:
		return Phase.BARE
	if _shot >= 0.0 and _t >= _shot:
		return Phase.KILL if _t < _shot + BLACK_AFTER else Phase.TITLE
	if _t >= WAIT_AT:
		return Phase.WAIT
	if _t >= TITLE_AT:
		return Phase.TABLE
	return Phase.TYPING


func phase_name() -> String:
	return PHASE_NAMES[phase()]


## True while the bare prompt (STORY.md's moment after the credits) is on.
func at_prompt() -> bool:
	return _up and _bare >= 0.0


## True once the command was sent (the player's, or its own).
func shot_fired() -> bool:
	return _shot >= 0.0 and _t >= _shot


## True while SIGKILL and the hexagon are up.
func title_showing() -> bool:
	return _up and _bare < 0.0 and _shot >= 0.0 and _t >= _shot + SLAM_AFTER and _t < _shot + OUT_TO


## Every row's four columns, in the order they arrive.
func rows() -> Array:
	return _rows


## The rows in the table now, each as the table draws it, in order; a row counts once it has fully arrived.
func shown_rows() -> PackedStringArray:
	var out := PackedStringArray()
	if not _up or _bare >= 0.0 or shot_fired():
		return out
	for i in _rows.size():
		if _arrived(i):
			out.append(CreditsCast.row_text(_rows[i]))
	return out


## The hero card's lines now (its name first), or none.
func hero_text() -> PackedStringArray:
	var out := PackedStringArray()
	var h := _hero()
	if h.is_empty() or _bare >= 0.0 or shot_fired():
		return out
	match str(h["kind"]):
		"title":
			out.append(CARD_TITLE)
			out.append(CARD_SUB)
		"cast":
			var c: Array = CreditsCast.CAST[int(h["index"])]
			out.append(str(c[4]))
			out.append(str(c[1]))
			out.append("$ " + str(c[3]))
			out.append(str(c[5]))
		"thanks":
			out.append(CreditsCast.THANKS_NAME)
			for n in CreditsCast.thanks_names():
				out.append(n)
	return out


## Every line it shows now, for the checks.
func shown_text() -> PackedStringArray:
	var out := PackedStringArray()
	if not _up:
		return out
	if _bare >= 0.0:
		out.append(BARE)
		return out
	if title_showing():
		out.append(TITLE)
		return out
	if shot_fired():
		return out
	out.append(_typed(PROMPT_LINE, _t - TYPE_AT, 1.0 / STEP_S))
	if _t >= TITLE_AT:
		out.append(_summary_1())
		out.append(_summary_2())
		out.append(CreditsCast.head_text())
	out.append_array(shown_rows())
	out.append_array(hero_text())
	if _t >= WAIT_AT:
		out.append(ROOT_PROMPT + _command_typed())
		if _press < 0.0:
			out.append(KILL_HINT % _fire_label)
	out.append(SKIP_HINT)
	return out


## Every line it can ever show, for the checks (whatever the clock says).
static func every_line() -> PackedStringArray:
	var out := PackedStringArray([PROMPT_LINE, CreditsCast.head_text(), CARD_TITLE, CARD_SUB, ROOT_PROMPT + COMMAND, KILL_HINT, SKIP_HINT, TITLE, BARE, SUMMARY_1, SUMMARY_2, CreditsCast.THANKS_NAME])
	for row in CreditsCast.rows():
		out.append(CreditsCast.row_text(row))
	for c in CreditsCast.CAST:
		out.append(str(c[4]))
		out.append(str(c[5]))
		out.append(str(c[6]))
	out.append_array(CreditsCast.thanks_names())
	return out


func _finish() -> void:
	if not _up:
		return
	_up = false
	visible = false
	_stop_music()
	if _paused_world:
		_paused_world = false
		if is_inside_tree():
			get_tree().paused = false
	if _world_hidden:
		_world_hidden = false
		if is_inside_tree():
			get_viewport().disable_3d = false
	Input.mouse_mode = _mouse_was
	finished.emit(_skipped)


func _exit_tree() -> void:
	# Freed while up (the arena reloading under it): the world and the 3D view given back all the same.
	if _paused_world and is_inside_tree():
		get_tree().paused = false
	if _world_hidden and is_inside_tree():
		get_viewport().disable_3d = false


func _process(delta: float) -> void:
	if not _up:
		return
	_step(delta)


func _step(delta: float) -> void:
	_t += delta
	CreditsScore.take()
	if _bare < 0.0 and _t >= WAIT_AT + WAIT_S and _press < 0.0:
		kill_now()  # the command types itself: the roll never waits long
	if _bare < 0.0 and _shot >= 0.0 and _t >= _shot + BARE_AFTER:
		_bare = _shot + BARE_AFTER
	if _bare >= 0.0 and _t >= _bare + BARE_S:
		_finish()
		return
	# Once the screen is black, the arena's 3D view is not drawn under it.
	if _t >= FADE_S and not _world_hidden and is_inside_tree() and not get_viewport().disable_3d:
		get_viewport().disable_3d = true
		_world_hidden = true
	_music_step()
	var want := _register_weights()
	var k := clampf(delta * 3.0, 0.0, 1.0) if delta > 0.0 else 1.0
	_weights = _weights.lerp(want, k)
	if _canvas != null:
		_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if not _up:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		if key.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			skip()
			return
		if key.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			kill_now()
	if InputMap.has_action("fire") and event.is_action_pressed("fire") and not event.is_echo():
		kill_now()
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()  # nothing behind it takes a key or a click while it is up


# --- The score. ---

func _music_step() -> void:
	if _bare >= 0.0:
		return
	_play_part("roll", 0.0, CreditsScore.credit_seconds("roll"))
	if _press < 0.0 and _shot < 0.0:
		_play_part("wait", WAIT_AT, INF)
	if _shot >= 0.0 and _t >= _shot:
		var waiting: AudioStreamPlayer = _music.get("wait")
		if waiting != null and waiting.playing:
			waiting.stop()
		_play_part("kill", _shot, CreditsScore.KILL_S)


func _play_part(part: String, at: float, seconds: float) -> void:
	if _t < at or _t >= at + seconds or _music.has(part):
		return
	var stream := CreditsScore.part(part)
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.name = "Score" + part.capitalize()
	player.bus = SettingsApply.MUSIC if AudioServer.get_bus_index(SettingsApply.MUSIC) >= 0 else &"Master"
	player.volume_db = SfxSynth.volume_db(SCORE_VOLUME)
	player.stream = stream
	add_child(player)
	var into := _t - at
	player.play(fposmod(into, stream.get_length()) if part == "wait" else into)
	_music[part] = player


func _stop_music() -> void:
	for part in _music:
		var player: AudioStreamPlayer = _music[part]
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
	_music.clear()


# --- The clock's state. ---

func _arrived(i: int) -> bool:
	if _t < _arrive[i]:
		return false
	if i == _rows.size() - 1:
		return _t >= _arrive[i] + _last_typing_s()
	return _t >= _arrive[i] + SETTLE_S


func _last_typing_s() -> float:
	return float(str(_rows[_rows.size() - 1][3]).length()) / LAST_CPS + 0.3


## The hero card up now: {"kind": "title"|"cast"|"thanks"|"last", "index", "from", "to"}, or {}.
func _hero() -> Dictionary:
	if _t < TITLE_AT:
		return {}
	if _t < CAST_AT:
		return {"kind": "title", "index": -1, "from": TITLE_AT, "to": CAST_AT}
	if _t < THANKS_AT:
		var i := mini(floori((_t - CAST_AT) / CAST_EVERY_S), CreditsCast.CAST.size() - 1)
		var from := CAST_AT + i * CAST_EVERY_S
		return {"kind": "cast", "index": i, "from": from, "to": minf(from + CAST_EVERY_S, THANKS_AT)}
	if _t < QUIET_AT:
		return {"kind": "thanks", "index": -1, "from": THANKS_AT, "to": QUIET_AT}
	if _t >= LAST_AT:
		return {"kind": "last", "index": _rows.size() - 1, "from": LAST_AT, "to": INF}
	return {}


func _register_weights() -> Vector3:
	var h := _hero()
	var reg := "tron"
	if not h.is_empty():
		match str(h["kind"]):
			"cast":
				reg = str(CreditsCast.CAST[int(h["index"])][6])
			"thanks":
				reg = "matrix"
	return Vector3(1.0 if reg == "tron" else 0.0, 1.0 if reg == "matrix" else 0.0, 1.0 if reg == "cyberpunk" else 0.0)


## The scene's light now: the registers' blended, going red as the last row comes.
func _accent() -> Color:
	var c := Palette.TEAL * _weights.x + Palette.MATRIX_GREEN * _weights.y + Palette.HOT_MAGENTA * _weights.z
	return Color(c.lerp(Palette.CRIMSON, _red()), 1.0)


func _accent_hi() -> Color:
	var c := Palette.MINT * _weights.x + Palette.MATRIX_HEAD * _weights.y + Palette.SKIN_CGA_CYAN * _weights.z
	return Color(c.lerp(Palette.HOSTILE_RED, _red()), 1.0)


func _red() -> float:
	return 0.65 * smoothstep(LAST_AT, LAST_AT + 0.5, _t)


static func _register_colour(reg: String) -> Color:
	match reg:
		"matrix":
			return Palette.MATRIX_GREEN
		"cyberpunk":
			return Palette.HOT_MAGENTA
	return Palette.TEAL


static func _register_hi(reg: String) -> Color:
	match reg:
		"matrix":
			return Palette.MATRIX_HEAD
		"cyberpunk":
			return Palette.SKIN_CGA_CYAN
	return Palette.MINT


func _summary_1() -> String:
	var n := 0
	for i in _rows.size():
		if _t >= _arrive[i]:
			n += 1
	var load := clampf(n / 10.0, 0.0, 9.0)
	return SUMMARY_1 % [int(_t) % 60, "%.2f" % load, "%.2f" % (load * 0.7), "%.2f" % (load * 0.4)]


func _summary_2() -> String:
	var n := 0
	for i in _rows.size():
		if _t >= _arrive[i]:
			n += 1
	return SUMMARY_2 % [n + 1, n]


func _command_typed() -> String:
	if _press < 0.0:
		return ""
	return COMMAND.left(clampi(ceili((_t - _press) / KILL_TYPE_S * COMMAND.length()), 0, COMMAND.length()))


static func _typed(text: String, age: float, cps: float) -> String:
	return text.left(clampi(floori(maxf(age, 0.0) * cps), 0, text.length()))


static func _hash(a: float, b: float = 0.0) -> float:
	return fposmod(sin(a * 12.9898 + b * 78.233) * 43758.5453, 1.0)


static func _glyph(seed: float) -> String:
	return GLYPHS[floori(_hash(seed, 3.1) * GLYPHS.length()) % GLYPHS.length()]


# --- Drawing. ---

func _scale(view: Vector2) -> float:
	return maxf(minf(view.y / DESIGN.y, view.x / DESIGN.x), 0.3)


func _draw_all() -> void:
	if not _up:
		return
	var began := Time.get_ticks_usec()
	_draw_frame()
	draw_us = Time.get_ticks_usec() - began


func _draw_frame() -> void:
	var view := _canvas.size
	var k := _scale(view)
	var fade := clampf(_t / FADE_S, 0.0, 1.0)
	_canvas.draw_rect(Rect2(Vector2.ZERO, view), Color(0.0, 0.0, 0.0, fade))
	if _bare >= 0.0:
		_draw_bare(view, k)
		return
	if _shot >= 0.0 and _t >= _shot + BLACK_AFTER:
		if _t >= _shot + SLAM_AFTER:
			_draw_title(view, k)
		return
	var out := 1.0
	if _shot >= 0.0 and _t >= _shot:
		out = 1.0 - clampf((_t - _shot) / 1.2, 0.0, 1.0)
	_draw_backdrop(view, k, fade * out)
	if _shot >= 0.0 and _t >= _shot and _vox_made:
		_draw_voxels(view, k)
		_draw_flash(view, k)
	else:
		_collect = _shot >= 0.0 and _t >= _shot and not _vox_made
		_cells.clear()
		var table := _draw_table(view, k, fade)
		_draw_hero(view, k, table)
		_draw_prompt(view, k, table)
		if _collect:
			_make_voxels(k)
			_collect = false
	_draw_overlay(view, k)
	var hint_px := roundi(13.0 * k) + 2
	var hw := _font.get_string_size(SKIP_HINT, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_px).x
	_canvas.draw_string(_font, Vector2(view.x - hw - 22.0 * k, view.y - 18.0 * k), SKIP_HINT, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_px, Color(Palette.MINT, 0.38 * fade))


## The grid running away to the horizon, the code rain, and (in the ruins' register) the skyline and its rain.
func _draw_backdrop(view: Vector2, k: float, a: float) -> void:
	if a <= 0.0:
		return
	var accent := _accent()
	var hi := _accent_hi()
	var horizon := view.y * 0.6
	var beat := fposmod(_t / BEAT_S, 1.0)
	# The skyline, the ruins' register: dead towers along the horizon, a few windows lit, their edges in neon.
	var cyber := _weights.z * a
	if cyber > 0.01:
		for i in SKYLINE:
			var w := view.x / SKYLINE * (0.7 + 0.5 * _hash(i, 1.0))
			var x := view.x * float(i) / SKYLINE + (_hash(i, 2.0) - 0.5) * 18.0 * k
			var h := view.y * (0.08 + 0.34 * pow(_hash(i, 3.0), 1.4))
			_canvas.draw_rect(Rect2(x, horizon - h, w, h), Color(0.03, 0.0, 0.05, 0.95 * cyber))
			var edge := Palette.HOT_MAGENTA if i % 3 else Palette.SKIN_CGA_CYAN
			_canvas.draw_rect(Rect2(x, horizon - h, w, 2.0 * k + 1.0), Color(edge, 0.85 * cyber))
			_canvas.draw_rect(Rect2(x, horizon - h, 1.5 * k, h), Color(edge, 0.3 * cyber))
			for wy in 6:
				for wx in 3:
					if _hash(i * 7.0 + wx, wy * 3.0) > 0.74:
						var lit := 0.35 + 0.65 * _hash(i + wx, floorf(_t * 0.7) + wy)
						_canvas.draw_rect(Rect2(x + w * (0.18 + wx * 0.28), horizon - h + h * (0.12 + wy * 0.13), w * 0.12, h * 0.05), Color(Palette.SODIUM if (wx + wy) % 3 else Palette.SKIN_CGA_CYAN, 0.55 * lit * cyber))
		# Rain across it all, slanting.
		for i in STREAKS:
			var sx := fposmod(_hash(i, 5.0) * view.x - _t * 140.0 * k, view.x)
			var sy := fposmod(_hash(i, 6.0) * view.y + _t * view.y * (0.9 + 0.6 * _hash(i, 7.0)), view.y * 1.1) - view.y * 0.05
			var len := (26.0 + 30.0 * _hash(i, 8.0)) * k
			_canvas.draw_line(Vector2(sx, sy), Vector2(sx - len * 0.28, sy + len), Color(Palette.SKIN_CGA_CYAN, 0.16 * cyber), 1.0 * k + 0.5, true)
	# The grid: lines fanning from the vanishing point, and across, rushing in a cell a beat.
	var centre := view.x * 0.5
	var grid := Color(accent, 0.0)
	for i in 23:
		var lean := (float(i) / 22.0 - 0.5) * 2.0
		grid.a = 0.26 * a
		_canvas.draw_line(Vector2(centre + lean * view.x * 0.09, horizon), Vector2(centre + lean * view.x * 1.5, view.y), grid, 1.5 * k, true)
	for i in 14:
		var z := (i + 1.0 - beat) / 14.0
		var y := horizon + (view.y - horizon) * pow(z, 2.6)
		grid.a = 0.36 * a * z
		_canvas.draw_line(Vector2(0.0, y), Vector2(view.x, y), grid, 1.5 * k, true)
	for i in 7:
		_canvas.draw_rect(Rect2(0.0, horizon - i * 3.0 * k, view.x, 6.0 * k), Color(accent, 0.035 * a))
	_canvas.draw_rect(Rect2(0.0, horizon, view.x, 1.5 * k), Color(hi, 0.7 * a))
	for i in 10:
		_canvas.draw_rect(Rect2(0.0, horizon - i * 6.0 * k, view.x, 6.0 * k), Color(accent, 0.05 * (1.0 - i / 10.0) * a))
	# Tron's light cycles: two trails racing along the floor, one each way.
	var tron := _weights.x * a
	if tron > 0.01:
		for c in 2:
			var u := fposmod(_t * (0.32 + 0.11 * c) + c * 0.5, 1.0)
			var y := horizon + (view.y - horizon) * (0.5 + 0.32 * c)
			var head := view.x * (u if c == 0 else 1.0 - u)
			var tail := 0.35 * view.x * (1.0 if c == 0 else -1.0)
			_glow_line(Vector2(head - tail, y), Vector2(head, y), Color(Palette.MINT if c == 0 else Palette.HOSTILE_AMBER, 0.75 * tron), 2.5 * k)
			_canvas.draw_circle(Vector2(head, y), 4.0 * k, Color(Color.WHITE, tron))
	# The code rain: every column a stream, its head bright, thicker in the Matrix's register.
	var rain := (0.06 + 0.2 * _weights.y + 0.04 * _weights.z) * a
	var gpx := roundi(15.0 * k) + 3
	var gh := gpx * 1.15
	var tint := Palette.MATRIX_GREEN.lerp(Palette.HOT_MAGENTA, _weights.z * 0.6)
	for c in RAIN_COLUMNS:
		var x := view.x * (float(c) + 0.5) / RAIN_COLUMNS + (_hash(c, 11.0) - 0.5) * 10.0 * k
		var n := 6 + floori(_hash(c, 12.0) * (RAIN_LONGEST - 6))
		var speed := (110.0 + 260.0 * _hash(c, 13.0)) * k * (1.0 + 0.6 * _weights.y)
		var head := fposmod(_hash(c, 14.0) * view.y * 2.0 + _t * speed, view.y + n * gh) - gh
		for j in n:
			var y := head - j * gh
			if y < -gh or y > view.y + gh:
				continue
			var ch := _glyph(c * 31.0 + j * 7.0 + floorf(_t * (6.0 + 6.0 * _hash(c, 15.0))))
			var col := Palette.MATRIX_HEAD if j == 0 else tint
			_canvas.draw_char(_font, Vector2(x, y), ch, gpx, Color(col, rain * (1.4 if j == 0 else 1.0 - float(j) / n)))


## The terminal window and the table in it; returns its geometry for the rest: {"win", "x", "cw", "lh", "fs", "rows_top",
## "rows_bottom", "first", "row_y": {row: y}}.
func _draw_table(view: Vector2, k: float, a: float) -> Dictionary:
	var fs := roundi(19.0 * k) + 1
	var cw := _font.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var lh := fs * 1.72
	var pad := 18.0 * k
	var cols := 78
	var win := Rect2(view.x * 0.03, view.y * 0.07, cw * cols + pad * 2.0 + cw * 3.0, view.y * 0.86)
	var accent := _accent()
	var hi := _accent_hi()
	var grow := clampf((_t - 0.05) / 0.3, 0.0, 1.0)
	var shake := Vector2.ZERO
	if _t >= LAST_AT and _t < LAST_AT + 0.5:
		shake = Vector2(sin(_t * 97.0), cos(_t * 71.0)) * 7.0 * k * (1.0 - (_t - LAST_AT) / 0.5)
	win.position += shake
	# The window: near black over the grid, its frame in the register's light, corners lit.
	_canvas.draw_rect(Rect2(win.position, Vector2(win.size.x, win.size.y * grow)), Color(0.0, 0.012, 0.016, 0.62 * a))
	_canvas.draw_rect(Rect2(win.position, Vector2(win.size.x, 3.0 * k)), Color(hi, 0.35 * a))
	for g in 5:
		_canvas.draw_rect(Rect2(win.position + Vector2(0.0, 3.0 * k + g * 4.0 * k), Vector2(win.size.x, 4.0 * k)), Color(accent, 0.05 * (5 - g) / 5.0 * a))
	_canvas.draw_rect(Rect2(win.position, Vector2(win.size.x, win.size.y * grow)), Color(accent, 0.45 * a), false, 1.5 * k)
	_brackets(Rect2(win.position, Vector2(win.size.x, win.size.y * grow)), 26.0 * k, Color(hi, 0.9 * a), 3.0 * k)
	var x := win.position.x + pad
	var gutter := cw * 3.0
	var y := win.position.y + pad + fs
	# `$ top -p sigkill --credits`, typed a sixteenth a key.
	var typed := _typed(PROMPT_LINE, _t - TYPE_AT, 1.0 / STEP_S)
	_text(Vector2(x, y), typed, fs, Color(Palette.MINT, a))
	if typed.length() < PROMPT_LINE.length() and fmod(_t, 0.6) < 0.35:
		var tw := _font.get_string_size(typed, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_canvas.draw_rect(Rect2(Vector2(x + tw + 3.0, y - fs * 0.85), Vector2(fs * 0.55, fs * 1.05)), Color(Palette.MINT, a))
	var out := {"win": win, "x": x + gutter, "cw": cw, "lh": lh, "fs": fs, "row_y": {}}
	var head_y := y + lh * 3.6
	var rows_top := head_y + lh * 0.9
	var rows_bottom := win.end.y - lh * 1.6
	out["rows_top"] = rows_top
	out["rows_bottom"] = rows_bottom
	if _t < TITLE_AT:
		return out
	# top's summary lines, then its column heads on a lit bar.
	var in_head := clampf((_t - TITLE_AT) / 0.25, 0.0, 1.0)
	_text(Vector2(x, y + lh * 1.25), _summary_1(), fs, Color(Palette.MINT, 0.78 * a * in_head))
	_text(Vector2(x, y + lh * 2.2), _summary_2(), fs, Color(Palette.MINT, 0.78 * a * in_head))
	_canvas.draw_rect(Rect2(x - cw * 0.5, head_y - fs * 0.95, (cols + 2.0) * cw * in_head, fs * 1.32), Color(accent, 0.88 * a))
	_text(Vector2(x + gutter, head_y), CreditsCast.head_text(), fs, Color(0.0, 0.0, 0.0, a * in_head), false)
	# The rows: as many as fit, scrolled so the newest is always in sight.
	var fit := maxi(floori((rows_bottom - rows_top) / lh), 1)
	var count := 0
	for i in _rows.size():
		if _t >= _arrive[i] - RAIN_S:
			count = i + 1
	var want := float(maxi(count - fit, 0))
	_scroll = lerpf(_scroll, want, clampf(get_process_delta_time() * 5.0, 0.0, 1.0)) if absf(_scroll - want) > 0.01 else want
	var h := _hero()
	var selected := int(h.get("index", -1)) if str(h.get("kind", "")) == "cast" else -1
	for i in count:
		var ry := rows_top + (i - _scroll) * lh + fs
		if ry < rows_top - lh * 0.2 or ry > rows_bottom + fs:
			continue
		var edge := clampf((ry - rows_top + lh * 0.2) / lh, 0.0, 1.0)
		out["row_y"][i] = ry
		_draw_row(i, Vector2(x + gutter, ry), cw, fs, lh, a * edge, i == selected)
	_draw_tree(out, a)
	return out


## Row `i` at `at` (its baseline): raining in, then its four columns in their colours; the last row typed in red.
func _draw_row(i: int, at: Vector2, cw: float, fs: int, lh: float, a: float, selected: bool) -> void:
	var last := i == _rows.size() - 1
	var cast := i < CreditsCast.CAST.size()
	var age := _t - _arrive[i]
	var reg := str(CreditsCast.CAST[i][6]) if cast else "matrix"
	var accent := Palette.CRIMSON if last else _register_colour(reg)
	var hi := Palette.HOSTILE_RED.lerp(Color.WHITE, 0.2) if last else _register_hi(reg)
	var fields: Array = (_rows[i] as Array).duplicate()
	if cast and age < CLIMB_S:
		fields[2] = CreditsCast.cpu_text(float(CreditsCast.CAST[i][2]) * ease(clampf(age / CLIMB_S, 0.0, 1.0), 0.4))
	var text := CreditsCast.row_text(fields)
	# Its bar: lit as it lands, held while its card is up (top's selected row).
	var flash := exp(-maxf(age, 0.0) * 3.0) if age >= 0.0 else 0.0
	var bar := maxf(0.4 * flash, 0.16 if selected else 0.0)
	if bar > 0.0:
		_canvas.draw_rect(Rect2(at.x - cw * 0.5, at.y - fs * 0.95, cw * 76.0, fs * 1.3), Color(accent, bar * a))
	if selected:
		_canvas.draw_rect(Rect2(at.x - cw * 0.9, at.y - fs * 0.95, 3.0, fs * 1.3), Color(hi, a))
	if age >= 0.0 and age < 0.45 and not last:
		# A sweep of light across the row as it lands.
		var sx := at.x - cw * 0.5 + cw * 76.0 * ease(age / 0.45, 0.5)
		_canvas.draw_rect(Rect2(sx - cw * 8.0, at.y - fs * 0.95, cw * 8.0, fs * 1.3), Color(hi, 0.18 * a))
		_canvas.draw_rect(Rect2(sx - 2.0, at.y - fs * 1.1, 3.0, fs * 1.6), Color(Color.WHITE, 0.9 * a))
	if last:
		_draw_last_row(at, cw, fs, text, a)
		return
	var dim := 1.0 if cast else 0.6
	if age >= SETTLE_S:
		# Settled: four strings, a colour a column.
		var cols := _columns(text)
		var colours := [Color(accent.lerp(Color.WHITE, 0.25), 0.8 * dim * a), Color(hi, dim * a), Color(Palette.HOSTILE_AMBER.lerp(Color.WHITE, 0.35), 0.9 * dim * a), Color(0.92, 0.97, 1.0, 0.86 * dim * a)]
		for c in 4:
			_text(Vector2(at.x + cols[c][0] * cw, at.y), cols[c][1], fs, colours[c], false)
		return
	# Raining in: a stream for every character, falling to its place and locking there, white hot, then cooling.
	for c in text.length():
		var ch := text[c]
		if ch == " ":
			continue
		var lock := -0.28 * RAIN_S + c * 0.004 + 0.16 * _hash(i * 13.0 + c, 2.0)
		var cx := at.x + c * cw
		if age < lock:
			var fall := clampf((age - (lock - RAIN_S * 0.6)) / (RAIN_S * 0.6), 0.0, 1.0)
			if fall <= 0.0:
				continue
			var hy := lerpf(at.y - lh * 6.0, at.y, fall)
			for j in 4:
				var gy := hy - j * fs * 1.05
				_canvas.draw_char(_font, Vector2(cx, gy), _glyph(c * 3.0 + j + floorf(_t * 14.0)), fs, Color(Palette.MATRIX_HEAD if j == 0 else Palette.MATRIX_GREEN, a * fall * (1.0 - j * 0.24)))
		else:
			var burn := clampf((age - lock) / BURN_S, 0.0, 1.0)
			var col := Color.WHITE.lerp(hi, burn)
			col.a = a * dim
			_canvas.draw_char(_font, Vector2(cx, at.y), ch, fs, col)
			if _collect:
				_cells.append([Vector2(cx, at.y), ch, col, fs, true])


## The row that should not be there: typed at its own pace, crimson, shaking, its PID and user there at once.
func _draw_last_row(at: Vector2, cw: float, fs: int, text: String, a: float) -> void:
	var age := _t - _arrive[_rows.size() - 1]
	var lead := CreditsCast.row_text([str(CreditsCast.LAST[0]), CreditsCast.LAST[1], CreditsCast.LAST[2], ""]).length()
	var shown := lead + floori(maxf(age - 0.3, 0.0) * LAST_CPS) if age >= 0.0 else 0
	var line := text.left(clampi(shown, 0, text.length()))
	var jitter := Vector2(sin(_t * 61.0) * 2.0, cos(_t * 53.0) * 1.0) * (1.0 + 4.0 * exp(-maxf(age, 0.0) * 4.0))
	_text(at + jitter + Vector2(-3.0, 0.0), line, fs, Color(0.2, 0.9, 1.0, 0.25 * a), false)
	_text(at + jitter, line, fs, Color(Palette.CRIMSON.lerp(Color.WHITE, 0.15 + 0.2 * sin(_t * 9.0)), a))
	if line.length() < text.length() and fmod(_t, 0.5) < 0.3:
		var tw := _font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_canvas.draw_rect(Rect2(at + jitter + Vector2(tw + 2.0, -fs * 0.85), Vector2(fs * 0.55, fs * 1.05)), Color(Palette.CRIMSON, a))


## A row's text cut into its four columns: [[first character, text], ...].
static func _columns(text: String) -> Array:
	var p := CreditsCast.PID_W
	var u := p + 2 + CreditsCast.USER_W
	var c := u + 2 + CreditsCast.CPU_W
	return [[0, text.substr(0, p)], [p + 2, text.substr(p + 2, CreditsCast.USER_W)], [u + 2, text.substr(u + 2, CreditsCast.CPU_W)], [c + 2, text.substr(c + 2)]]


## The lineage in the gutter: init's trunk down the rows, a branch to each, a packet of light running up to init as each
## is adopted; through the adoption every branch flashes in turn; the last row's branch reaches for the trunk and fails.
func _draw_tree(geo: Dictionary, a: float) -> void:
	var ys: Dictionary = geo["row_y"]
	if ys.is_empty():
		return
	var cw: float = geo["cw"]
	var fs: int = geo["fs"]
	var tx: float = geo["x"] - cw * 2.2
	var top: float = geo["rows_top"]
	var accent := _accent()
	var hi := _accent_hi()
	var k := fs / 22.0
	var last := _rows.size() - 1
	var low := top
	var root_y := top + fs * 0.65 - _scroll * float(geo["lh"])
	for i in ys:
		if i != last:
			low = maxf(low, float(ys[i]) - fs * 0.35)
	if low <= top:
		return
	var trunk_top := maxf(root_y, top)
	_glow_line(Vector2(tx, trunk_top), Vector2(tx, low), Color(accent, 0.7 * a), 2.0 * k)
	if ys.has(0):
		var pulse := 0.0
		for i in range(1, last):
			var s := _t - (_arrive[i] + 0.6)
			if s >= 0.0 and s < 0.5:
				pulse = maxf(pulse, 1.0 - s / 0.5)
		_canvas.draw_circle(Vector2(tx, float(ys[0]) - fs * 0.35), (4.0 + 5.0 * pulse) * k, Color(hi.lerp(Color.WHITE, pulse), a))
	for i in ys:
		var by: float = float(ys[i]) - fs * 0.35
		var age := _t - _arrive[i]
		if i == 0:
			continue
		if i == last:
			# Reaching for init, and refused: sparking short of the trunk.
			var reach := clampf(age / 0.8, 0.0, 1.0)
			var from := Vector2(tx + cw * 1.7, by)
			var to := Vector2(lerpf(from.x, tx + cw * 0.5, reach), by)
			if fmod(_t * 7.0, 1.0) < 0.75:
				_glow_line(from, to, Color(Palette.CRIMSON, 0.9 * a), 2.0 * k)
			for s in 3:
				var sp := to + Vector2(-_hash(s, floorf(_t * 20.0)) * cw * 0.6, (_hash(s, floorf(_t * 20.0) + 1.0) - 0.5) * fs * 0.6)
				_canvas.draw_rect(Rect2(sp, Vector2(2.0, 2.0) * k), Color(Palette.HOSTILE_RED, a * 0.9))
			continue
		var grow := clampf(age / 0.3, 0.0, 1.0)
		var flash := 0.0
		if _t >= QUIET_AT and _t < LAST_AT:
			var wave := fposmod((_t - QUIET_AT) * 1.2 - float(last - i) * 0.08, 1.0)
			flash = exp(-wave * 8.0)
		_glow_line(Vector2(tx, by), Vector2(tx + cw * 1.7 * grow, by), Color(accent.lerp(hi, flash), (0.6 + 0.4 * flash) * a), (2.0 + 2.0 * flash) * k)
		# The packet: from the branch up the trunk to init.
		var run := (age - 0.25) / 0.6
		var quiet_run := -1.0
		if _t >= QUIET_AT and _t < LAST_AT:
			quiet_run = fposmod((_t - QUIET_AT) * 0.8 + _hash(i, 4.0), 1.0)
		for r in [run, quiet_run]:
			if r >= 0.0 and r < 1.0:
				var py := lerpf(by, maxf(root_y, top), r)
				_canvas.draw_circle(Vector2(tx, py), 3.5 * k, Color(Color.WHITE, a * (1.0 - r * 0.4)))
				_canvas.draw_circle(Vector2(tx, py), 8.0 * k, Color(hi, 0.25 * a))


## The hero card beside the table, and the line from its row to it.
func _draw_hero(view: Vector2, k: float, geo: Dictionary) -> void:
	var h := _hero()
	if h.is_empty():
		return
	var win: Rect2 = geo["win"]
	var left := win.end.x + view.x * 0.035
	var card := Rect2(left, view.y * 0.16, view.x * 0.965 - left, view.y * 0.6)
	var age := _t - float(h["from"])
	var to := float(h["to"])
	var out := clampf((_t - (to - 0.3)) / 0.3, 0.0, 1.0) if to < INF else 0.0
	var a := clampf(age / 0.2, 0.0, 1.0) * (1.0 - out)
	if a <= 0.0:
		return
	var shift := Vector2(60.0 * k * out * out, 0.0)
	card.position += shift
	var kind := str(h["kind"])
	if kind == "last":
		_draw_ghost_pid(card, k, str(CreditsCast.LAST[0]), Palette.CRIMSON, a, true)
		return
	var reg := "tron"
	if kind == "cast":
		reg = str(CreditsCast.CAST[int(h["index"])][6])
	elif kind == "thanks":
		reg = "matrix"
	var accent := _register_colour(reg)
	var hi := _register_hi(reg)
	# Its frame: corners growing out, a scan running down it.
	var open := ease(clampf(age / 0.25, 0.0, 1.0), 0.3)
	var frame := Rect2(card.get_center() - card.size * 0.5 * open, card.size * open)
	_brackets(frame, 34.0 * k, Color(hi, 0.85 * a), 3.0 * k)
	var scan := fposmod(age * 0.55, 1.0)
	_canvas.draw_rect(Rect2(frame.position.x, frame.position.y + frame.size.y * scan, frame.size.x, 2.0 * k), Color(accent, 0.12 * a))
	var x := card.position.x + 34.0 * k
	var wide := card.size.x - 68.0 * k
	match kind:
		"title":
			_draw_ghost_pid(card, k, CreditsCast.TOP, accent, a * 0.6, false)
			var y := card.position.y + card.size.y * 0.5
			var size := _fit_size(CARD_TITLE, 170.0 * k, wide)
			_halo(Vector2(x + wide * 0.45, y - size * 0.3), size * 1.8, accent, a * clampf(age / 0.4, 0.0, 1.0))
			_draw_name(Vector2(x, y), CARD_TITLE, size, age, accent, hi, a, reg)
			_text(Vector2(x, y + size * 0.62), _typed(CARD_SUB, age - 0.8, 40.0), roundi(24.0 * k) + 1, Color(hi, 0.85 * a))
		"cast":
			var c: Array = CreditsCast.CAST[int(h["index"])]
			_draw_ghost_pid(card, k, str(c[0]), accent, a, false)
			var tag_px := roundi(17.0 * k) + 1
			_text(Vector2(x, card.position.y + 44.0 * k), "PID %d   [%s]" % [int(c[0]), reg], tag_px, Color(hi, 0.75 * a))
			var size := _fit_size(str(c[4]), 150.0 * k, wide)
			var y := card.position.y + card.size.y * 0.5 - size * 0.05
			_halo(Vector2(x + _name_font.get_string_size(str(c[4]), HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(size)).x * 0.5, y - size * 0.3), size * 1.6, accent, a * clampf(age / 0.4, 0.0, 1.0))
			_draw_name(Vector2(x, y), str(c[4]), size, age, accent, hi, a, reg)
			var handle_a := clampf((age - 0.55) / 0.25, 0.0, 1.0)
			# Their handle under the name; where the name is the handle (Larry, the producer), their line instead.
			var second := str(c[1]) if str(c[1]) != str(c[4]) else str(c[5])
			var hp := roundi(minf(40.0 * k, wide / maxf(second.length() * 0.62, 1.0))) + 1
			_text(Vector2(x, y + size * 0.42 + hp), second, hp, Color(hi, a * handle_a))
			var under := y + size * 0.42 + hp + 22.0 * k
			_canvas.draw_rect(Rect2(x, under, wide * ease(handle_a, 0.3), 2.0 * k), Color(accent, 0.7 * a))
			var cmd := "$ " + str(c[3])
			var cp := roundi(minf(24.0 * k, wide / maxf(cmd.length() * 0.61, 1.0))) + 1
			_text(Vector2(x, under + 18.0 * k + cp), _typed(cmd, age - 0.8, 34.0), cp, Color(Palette.MINT, 0.95 * a))
			if second != str(c[5]):
				var line_a := clampf((age - 1.4) / 0.3, 0.0, 1.0)
				_canvas.draw_multiline_string(_font, Vector2(x, under + 30.0 * k + cp * 2.2), str(c[5]), HORIZONTAL_ALIGNMENT_LEFT, wide, roundi(22.0 * k) + 1, 3, Color(0.92, 0.97, 1.0, 0.78 * a * line_a))
			_link(geo, int(h["index"]), Vector2(card.position.x, y - size * 0.3), accent, hi, a)
		"thanks":
			var y := card.position.y + card.size.y * 0.2
			var size := _fit_size(CreditsCast.THANKS_NAME, 110.0 * k, wide)
			_halo(Vector2(x + wide * 0.4, y - size * 0.3), size * 1.8, accent, a * clampf(age / 0.4, 0.0, 1.0))
			_draw_name(Vector2(x, y), CreditsCast.THANKS_NAME, size, age, accent, hi, a, reg)
			var names := CreditsCast.thanks_names()
			var px := roundi(25.0 * k) + 1
			for j in names.size():
				var s := _t - _arrive[CreditsCast.CAST.size() + j]
				if s < 0.0:
					continue
				var col := j % 2
				var at := Vector2(x + col * wide * 0.5, y + size * 0.5 + (floorf(j / 2.0) + 1.0) * px * 1.9)
				_text(at, names[j], px, Color(Color.WHITE.lerp(hi, clampf(s / 0.4, 0.0, 1.0)), a * clampf(s / 0.15, 0.0, 1.0)))


## The giant PID behind a card, outlined, drifting; the last one red, torn into strips.
func _draw_ghost_pid(card: Rect2, k: float, text: String, colour: Color, a: float, torn: bool) -> void:
	var size := roundi(minf(330.0 * k, card.size.x / maxf(text.length() * 0.62, 1.0)))
	var w := _name_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := Vector2(card.end.x - w - 10.0 * k - fposmod(_t * 9.0 * k, 30.0 * k), card.get_center().y + size * 0.36)
	if torn:
		at = Vector2(card.get_center().x - w * 0.5, card.get_center().y + size * 0.36)
		var alpha := a * (0.5 + 0.3 * sin(_t * 13.0))
		for s in 6:
			var off := Vector2((_hash(s, floorf(_t * 12.0)) - 0.5) * 40.0 * k, 0.0)
			_canvas.draw_string_outline(_name_font, at + off, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, roundi(3.0 * k) + 1, Color(colour, alpha * 0.35))
		_canvas.draw_string(_name_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(colour, alpha * 0.22))
		return
	_canvas.draw_string(_name_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(colour, 0.045 * a))
	_canvas.draw_string_outline(_name_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, roundi(2.5 * k) + 1, Color(colour, 0.22 * a))


## A name dropping in a letter a sixteenth, white hot, its glow and its two ghosts; in the Matrix register each letter
## cycles through the rain's glyphs before it locks; in the ruins' it flickers like a sign and is reflected in the wet.
func _draw_name(at: Vector2, text: String, size: float, age: float, accent: Color, hi: Color, a: float, reg: String) -> void:
	var px := roundi(size)
	var x := at.x
	for i in text.length():
		var ch := text[i]
		var cw := _name_font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var in_s := age - 0.12 - i * STEP_S * 0.5
		if in_s < 0.0:
			x += cw
			continue
		var drop := -50.0 * (px / 100.0) * pow(1.0 - clampf(in_s / 0.08, 0.0, 1.0), 2.0)
		var hot := exp(-in_s * 7.0)
		var shown := ch
		if reg == "matrix" and in_s < 0.35 and ch != " ":
			shown = _glyph(i * 5.0 + floorf(_t * 18.0)).to_upper()
		var flicker := 1.0
		if reg == "cyberpunk" and _hash(i, floorf(_t * 9.0)) > 0.93:
			flicker = 0.35
		var y := at.y + drop
		var col := hi.lerp(Color.WHITE, 0.55 + 0.45 * hot)
		col.a = a * flicker
		var ghost := (2.0 + 10.0 * hot) * (px / 100.0)
		_canvas.draw_string(_name_font, Vector2(x - ghost, y), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(Palette.CRIMSON if reg != "matrix" else Palette.MATRIX_GREEN, 0.3 * a * flicker))
		_canvas.draw_string(_name_font, Vector2(x + ghost, y), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(0.2, 0.9, 1.0, 0.26 * a * flicker))
		_canvas.draw_string_outline(_name_font, Vector2(x, y), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, px, roundi(px * 0.18), Color(accent, 0.2 * a * flicker))
		_canvas.draw_string_outline(_name_font, Vector2(x, y), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, px, roundi(px * 0.07), Color(accent, 0.5 * a * flicker))
		_canvas.draw_string(_name_font, Vector2(x, y), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
		if reg == "cyberpunk":
			# Its reflection in the wet street under it: upside down, faint, rippling.
			var ripple := sin(_t * 5.0 + i * 1.3) * 3.0 * (px / 100.0)
			_canvas.draw_set_transform(Vector2(x + ripple, y + px * 0.28), 0.0, Vector2(1.0, -0.55))
			_canvas.draw_string(_name_font, Vector2.ZERO, shown, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(accent, 0.16 * a * flicker))
			_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if _collect:
			_cells.append([Vector2(x, y), ch, col, px, false])
		x += cw


## The line from the selected row to its card: an elbow in the register's light, a packet running along it.
func _link(geo: Dictionary, row: int, to: Vector2, accent: Color, hi: Color, a: float) -> void:
	var ys: Dictionary = geo["row_y"]
	if not ys.has(row):
		return
	var cw: float = geo["cw"]
	var fs: int = geo["fs"]
	var win: Rect2 = geo["win"]
	var from := Vector2(win.end.x - cw * 0.5, float(ys[row]) - fs * 0.35)
	var mid := Vector2(lerpf(from.x, to.x, 0.5), from.y)
	var bend := Vector2(mid.x, to.y)
	var k := fs / 22.0
	_glow_line(from, mid, Color(accent, 0.6 * a), 1.5 * k)
	_glow_line(mid, bend, Color(accent, 0.6 * a), 1.5 * k)
	_glow_line(bend, to, Color(accent, 0.6 * a), 1.5 * k)
	var run := fposmod(_t * 0.9, 1.0)
	var total := from.distance_to(mid) + mid.distance_to(bend) + bend.distance_to(to)
	var d := run * total
	var p := to
	if d < from.distance_to(mid):
		p = from.lerp(mid, d / maxf(from.distance_to(mid), 0.01))
	elif d < from.distance_to(mid) + mid.distance_to(bend):
		p = mid.lerp(bend, (d - from.distance_to(mid)) / maxf(mid.distance_to(bend), 0.01))
	else:
		p = bend.lerp(to, (d - from.distance_to(mid) - mid.distance_to(bend)) / maxf(bend.distance_to(to), 0.01))
	_canvas.draw_circle(p, 3.0 * k, Color(Color.WHITE, a))
	_canvas.draw_circle(p, 7.0 * k, Color(hi, 0.3 * a))
	_canvas.draw_circle(to, 4.0 * k, Color(hi, a))


## `root# ` at the bottom of the window, the command typing once the player fires; the rail's reticle and how to fire
## while it waits.
func _draw_prompt(view: Vector2, k: float, geo: Dictionary) -> void:
	if _t < WAIT_AT:
		return
	var win: Rect2 = geo["win"]
	var fs: int = geo["fs"]
	var at := Vector2(float(geo["x"]) - float(geo["cw"]) * 3.0, win.end.y - fs * 1.0)
	var line := ROOT_PROMPT + _command_typed()
	_text(at, ROOT_PROMPT, fs, Color(Palette.HOSTILE_RED, 1.0))
	var pw := _font.get_string_size(ROOT_PROMPT, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_text(at + Vector2(pw, 0.0), _command_typed(), fs, Color(Palette.ICE_HI, 1.0))
	var lw := _font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if fmod(_t, 0.8) < 0.45 and (_shot < 0.0 or _t < _shot):
		_canvas.draw_rect(Rect2(at + Vector2(lw + 2.0, -fs * 0.85), Vector2(fs * 0.55, fs * 1.05)), Palette.ICE_HI)
	_origin = at + Vector2(lw * 0.5, -fs * 0.3)
	if _press >= 0.0:
		return
	# The rail's reticle over the card where the last PID burns, beating with the wait, and how to fire.
	var into := _t - WAIT_AT
	var left := win.end.x + view.x * 0.035
	var c := Vector2(lerpf(left, view.x * 0.965, 0.5), view.y * 0.46)
	var beat := exp(-fposmod(into, BEAT_S) * 10.0)
	var r := 30.0 * k * (1.0 + 0.12 * beat) * (1.6 - 0.6 * smoothstep(0.0, 0.3, into))
	var colour := Color(Palette.ICE_HI, 0.9 * smoothstep(0.0, 0.25, into))
	for q in 4:
		var from := TAU * q / 4.0 + 0.25
		_canvas.draw_arc(c, r, from, from + PI / 2.0 - 0.5, 16, colour, 2.5 * k, true)
		var dir := Vector2.from_angle(TAU * q / 4.0)
		_canvas.draw_line(c + dir * r * 1.25, c + dir * r * 1.7, colour, 2.0 * k, true)
	_canvas.draw_circle(c, 3.0 * k, Color(Palette.CRIMSON, colour.a))
	var hint := KILL_HINT % _fire_label
	var hp := roundi(26.0 * k) + 1
	var hw := _font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hp).x
	_text(Vector2(c.x - hw * 0.5, c.y + r * 2.6 + hp), hint, hp, Color(Palette.ICE_HI, (0.6 + 0.4 * beat) * smoothstep(0.4, 0.8, into)))


## The derezz: every glyph that was on screen, as voxels, the wave going out from the prompt.
func _make_voxels(k: float) -> void:
	_vox_pos.clear()
	_vox_col.clear()
	_vox_size.clear()
	for cell in _cells:
		var at: Vector2 = cell[0]
		var text: String = cell[1]
		var col: Color = cell[2]
		var size: int = cell[3]
		var mono: bool = cell[4]
		var f := _font if mono else _name_font
		var x := at.x
		for i in text.length():
			var ch := text[i]
			var cw := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			if ch != " ":
				var block := maxf(size * 0.34, 2.0)
				for v in VOX_PER_CHAR:
					_vox_pos.append(Vector2(x + cw * (0.2 + 0.3 * float(v % 2)), at.y - size * (0.15 + 0.25 * v)))
					_vox_col.append(Color(col.lerp(Color.WHITE, 0.15), maxf(col.a, 0.85)))
					_vox_size.append(block)
			x += cw
	_vox_made = true


## Collects every string the table drew this frame (for the voxels), and draws it: `outline` a dark edge for legibility.
func _text(at: Vector2, text: String, size: int, colour: Color, outline: bool = true) -> void:
	if text == "" or colour.a <= 0.0:
		return
	if outline:
		_canvas.draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(roundi(size * 0.22), 2), Color(0.0, 0.0, 0.0, 0.7 * colour.a))
	_canvas.draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)
	if _collect:
		_cells.append([at, text, colour, size, true])


func _draw_voxels(view: Vector2, k: float) -> void:
	var s := _t - _shot
	var speed := view.x * 1.1
	var g := 1500.0 * k
	for i in _vox_pos.size():
		var p0 := _vox_pos[i]
		var delay := p0.distance_to(_origin) / speed
		var u := s - delay
		var col := _vox_col[i]
		var size := _vox_size[i]
		if u < 0.0:
			_canvas.draw_rect(Rect2(p0, Vector2(size, size)), col)
			continue
		if u > 1.6:
			continue
		var dir := (p0 - _origin).normalized() if p0 != _origin else Vector2.UP
		var kick := (180.0 + 420.0 * _hash(i, 21.0)) * k
		var v := dir * kick + Vector2((_hash(i, 22.0) - 0.5) * 260.0 * k, -(240.0 + 380.0 * _hash(i, 23.0)) * k)
		var p := p0 + v * u + Vector2(0.0, 0.5 * g * u * u)
		var hot := exp(-u * 9.0)
		var c := col.lerp(Color.WHITE, hot)
		c.a = col.a * (1.0 - u / 1.6)
		var sz := size * (1.0 - 0.45 * u / 1.6) * (1.0 + 0.6 * hot)
		_canvas.draw_rect(Rect2(p - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), c)


## The shot's flash: a ring of the rail's light out from the prompt, the screen whitening for a moment.
func _draw_flash(view: Vector2, k: float) -> void:
	var s := _t - _shot
	if s < 0.0 or s > 0.9:
		return
	var u := s / 0.9
	_canvas.draw_rect(Rect2(Vector2.ZERO, view), Color(Palette.ICE_HI, 0.35 * exp(-s * 14.0)))
	for q in 2:
		var r := view.x * (0.3 + 0.6 * q) * (1.0 - pow(1.0 - u, 3.0))
		_canvas.draw_arc(_origin, r, 0.0, TAU, 96, Color(Palette.ICE_HI if q == 0 else Palette.CRIMSON, 0.7 * (1.0 - u)), (8.0 - 4.0 * q) * k * (1.0 - u) + 1.0, true)


## SIGKILL on the hexagon: the brand's icon slamming in out of the black, its colours split as it lands, the name
## hammered in a letter a sixteenth after it, a punch on every beat; the grid racing in under it, embers rising; torn
## away at the end.
func _draw_title(view: Vector2, k: float) -> void:
	var s := _t - (_shot + SLAM_AFTER)
	var out := clampf((_t - (_shot + OUT_FROM)) / (OUT_TO - OUT_FROM), 0.0, 1.0)
	var punch := 0.035 * exp(-fposmod(s, BEAT_S) * 11.0)
	var land := 1.0 + 2.6 * pow(1.0 - clampf(s / 0.09, 0.0, 1.0), 2.0)
	var shake := Vector2(sin(s * 61.0), cos(s * 47.0)) * 26.0 * k * exp(-s * 7.0)
	var h := view.y * 0.4 * land * (1.0 + punch)
	var w := h * LOGO.get_width() / maxf(LOGO.get_height(), 1.0)
	var c := Vector2(view.x * 0.5, view.y * 0.4) + shake
	var rect := Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h))
	var fade := clampf(s / 0.09, 0.0, 1.0) * (1.0 - out)
	# The grid racing in on the beat, and the embers.
	var horizon := view.y * 0.62
	var beat := fposmod(maxf(s, 0.0) / BEAT_S, 1.0)
	for i in 22:
		var lean := (float(i) / 21.0 - 0.5) * 2.0
		_canvas.draw_line(Vector2(view.x * 0.5 + lean * view.x * 0.08, horizon), Vector2(view.x * 0.5 + lean * view.x * 1.4, view.y), Color(Palette.TEAL, 0.16 * fade), 1.5 * k, true)
	for i in 12:
		var z := (i + 1.0 - beat) / 12.0
		var y := horizon + (view.y - horizon) * pow(z, 2.6)
		_canvas.draw_line(Vector2(0.0, y), Vector2(view.x, y), Color(Palette.TEAL, 0.2 * fade * z), 1.5 * k, true)
	for i in EMBERS:
		var sp := 0.03 + 0.05 * absf(sin(i * 4.13))
		var ey := view.y * (1.05 - fposmod(absf(sin(i * 2.71)) + maxf(s, 0.0) * sp, 1.1))
		var ex := view.x * absf(sin(i * 7.37)) + sin(s * 0.9 + i) * 12.0 * k
		var es := (3.5 + 6.0 * absf(sin(i * 1.91))) * k
		var ea := fade * (0.55 + 0.4 * sin(s * 6.0 + i * 2.3)) * clampf(ey / view.y * 1.4, 0.0, 1.0)
		_canvas.draw_rect(Rect2(ex, ey, es, es), Color(Palette.CRIMSON if i % 3 == 0 else Palette.TEAL, ea))
	for i in 16:
		_canvas.draw_circle(c, h * (1.25 - 0.05 * i), Color(Palette.TEAL, 0.012 * fade * (1.0 + 5.0 * punch)))
	var streak := fade * (0.55 + 3.0 * punch)
	for i in 4:
		var thick := (1.0 + 5.0 * i) * k
		_canvas.draw_rect(Rect2(0.0, c.y - thick * 0.5, view.x, thick), Color(Palette.MINT.lerp(Palette.TEAL, i / 3.0), 0.22 * streak / (1.0 + i)))
	var split := 30.0 * k * exp(-s * 6.0) + 40.0 * k * out
	if split > 0.5:
		_canvas.draw_texture_rect(LOGO, Rect2(rect.position + Vector2(-split, 0.0), rect.size), false, Color(1.0, 0.15, 0.3, 0.55 * fade))
		_canvas.draw_texture_rect(LOGO, Rect2(rect.position + Vector2(split, 0.0), rect.size), false, Color(0.1, 0.9, 1.0, 0.55 * fade))
	var strips := 7
	for i in strips:
		var src := Rect2(0.0, LOGO.get_height() * i / strips, LOGO.get_width(), LOGO.get_height() / float(strips))
		var dst := Rect2(rect.position.x, rect.position.y + h * i / strips, w, h / strips + 0.5)
		dst.position.x += sin(i * 12.9898 + floorf(s / 0.07) * 3.1) * 36.0 * k * out * 3.0
		_canvas.draw_texture_rect_region(LOGO, dst, src, Color(1.0, 1.0, 1.0, fade))
	if s < 0.7:
		var u := s / 0.7
		for q in 2:
			_canvas.draw_arc(c, view.x * (0.25 + 0.55 * q) * (1.0 - pow(1.0 - u, 3.0)), 0.0, TAU, 96, Color(Palette.MINT, 0.6 * (1.0 - u)), (8.0 - 4.0 * q) * k * (1.0 - u) + 1.0, true)
		for i in SPARKS:
			var ang := TAU * i / SPARKS + sin(i * 7.31) * 0.2
			var spd := (0.5 + 0.5 * absf(sin(i * 3.7))) * view.x * 0.7
			var from := c + Vector2.from_angle(ang) * (h * 0.45 + spd * u * 0.6)
			var to := from + Vector2.from_angle(ang) * (40.0 + 60.0 * absf(sin(i * 1.3))) * k * (1.0 - u)
			_canvas.draw_line(from, to, Color(Palette.ICE_HI if i % 3 else Palette.CRIMSON, 0.9 * (1.0 - u)), 3.0 * k, true)
	var size := roundi(128.0 * k)
	var name_w := _name_font.get_string_size(TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x := (view.x - name_w) * 0.5 + shake.x * 0.6
	for i in TITLE.length():
		var ch := TITLE[i]
		var in_s := s - BEAT_S - i * STEP_S
		var cw := _name_font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		if in_s >= 0.0:
			var drop := -70.0 * k * pow(1.0 - clampf(in_s / 0.06, 0.0, 1.0), 2.0)
			var hot := exp(-in_s * 9.0)
			var y := view.y * 0.8 + drop + shake.y * 0.6
			var ghost := (3.0 + 14.0 * hot + 30.0 * out) * k
			_canvas.draw_string(_name_font, Vector2(x - ghost, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(Palette.CRIMSON, 0.35 * (1.0 - out)))
			_canvas.draw_string(_name_font, Vector2(x + ghost, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.2, 0.9, 1.0, 0.3 * (1.0 - out)))
			_canvas.draw_string_outline(_name_font, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, roundi(22.0 * k), Color(Palette.TEAL, 0.22 * (1.0 - out)))
			_canvas.draw_string_outline(_name_font, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, roundi(8.0 * k), Color(Palette.TEAL, 0.5 * (1.0 - out)))
			_canvas.draw_string(_name_font, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(Palette.MINT.lerp(Color.WHITE, hot), 1.0 - out))
		x += cw
	_draw_scanlines(view, k, 0.12)


## STORY.md's beat after the credits: the bare prompt, its cursor blinking, nothing typing itself.
func _draw_bare(view: Vector2, k: float) -> void:
	var age := _t - _bare
	var px := roundi(26.0 * k) + 2
	var at := Vector2(view.x * 0.06, view.y * 0.5)
	_canvas.draw_string(_font, at, BARE, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Palette.MINT)
	if fmod(age, 1.0) < 0.55:
		var w := _font.get_string_size(BARE + " ", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		_canvas.draw_rect(Rect2(at + Vector2(w, -px * 0.85), Vector2(px * 0.55, px * 1.05)), Palette.MINT)


## Scanlines and the edges darkened, over the roll.
func _draw_overlay(view: Vector2, k: float) -> void:
	_draw_scanlines(view, k, 0.09)
	for i in 6:
		var e := (6 - i) * 14.0 * k
		_canvas.draw_rect(Rect2(0.0, 0.0, view.x, e), Color(0.0, 0.0, 0.0, 0.07))
		_canvas.draw_rect(Rect2(0.0, view.y - e, view.x, e), Color(0.0, 0.0, 0.0, 0.07))


func _draw_scanlines(view: Vector2, k: float, a: float) -> void:
	var step := maxi(roundi(3.0 * k), 2)
	for y in range(0, int(view.y), step):
		_canvas.draw_line(Vector2(0.0, y), Vector2(view.x, y), Color(0.0, 0.0, 0.0, a), 1.0)


## Corner brackets round `r`.
func _brackets(r: Rect2, arm: float, colour: Color, width: float) -> void:
	if r.size.x <= 1.0 or r.size.y <= 1.0:
		return
	var a := minf(arm, minf(r.size.x, r.size.y) * 0.5)
	for corner in [[r.position, Vector2(1, 1)], [Vector2(r.end.x, r.position.y), Vector2(-1, 1)], [Vector2(r.position.x, r.end.y), Vector2(1, -1)], [r.end, Vector2(-1, -1)]]:
		var p: Vector2 = corner[0]
		var d: Vector2 = corner[1]
		_canvas.draw_line(p, p + Vector2(d.x * a, 0.0), colour, width)
		_canvas.draw_line(p, p + Vector2(0.0, d.y * a), colour, width)


## A soft glow of `colour` round `at`, `r` across.
func _halo(at: Vector2, r: float, colour: Color, a: float) -> void:
	if a <= 0.0:
		return
	for i in 12:
		_canvas.draw_circle(at, r * (1.0 - i / 12.0) * 0.5, Color(colour, 0.018 * a))


## A line with its glow under it.
func _glow_line(from: Vector2, to: Vector2, colour: Color, width: float) -> void:
	_canvas.draw_line(from, to, Color(colour, colour.a * 0.18), width * 4.0, true)
	_canvas.draw_line(from, to, colour, width, true)


## The biggest size, up to `most`, at which `text` fits `wide` pixels in the names' font.
func _fit_size(text: String, most: float, wide: float) -> float:
	var at_100 := _name_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 100).x
	return minf(most, wide / maxf(at_100 / 100.0, 0.01))
