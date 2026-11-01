class_name CreditsHandoff
extends Control
## The hand-off to the credits (M7, docs/STORY.md section 7, PRD 5.8): what the finale's win flows into once the player
## takes Credits on its card. The roll itself is C44's (every contributor a process in a live `top`, Fred as PID 1, the
## last row the one that should not be there); until it lands this is the clean hand-off: the void under a Tron grid
## running away to the horizon, `$ top` typed, the table's head and its first row, init, PID 1, adopting the orphans,
## and a line saying the roll comes in a later build. Then STORY.md's beat after the credits: the fake terminal back for
## a moment, a bare `>_` with a blinking cursor and nothing typing itself (the machine is yours again), and the Missions
## screen (finished: the runner's to_missions()), the campaign replayable and every unlock kept.
##
## Enter, Space or Esc moves it on; the mouse is free while it is up and the player's input stopped; the window's close
## always works. Drawn, not a form. Nothing here names the player or reads anything.

signal finished

const Palette = preload("res://scripts/palette.gd")

const DESIGN_H := 720.0
const SCALE_LAST := 1.7
const PROMPT := "$ top"
const HEAD := "  PID USER      %CPU  COMMAND"
const INIT_ROW := "    1 init       0.0  adopting orphans"
const NOTE := "the roll lands in a later build"
const KEYS := "Enter: continue"
const BARE := ">_"
## Seconds: the prompt typing, a row typing, the hold once everything is in, the bare prompt after.
const TYPE_CPS := 24.0
const ROW_AT := 1.2
const HEAD_AT := 0.9
const NOTE_AT := 2.6
const HOLD_S := 7.0
const PROMPT_S := 1.4
## The grid: lines across and along, how far down the screen the horizon sits.
const GRID_LINES := 14
const HORIZON := 0.42

var runner: MissionRunner = null

var _font: Font
var _age := -1.0
var _prompt_age := -1.0
var _blocked: Node = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = Palette.mono_font()
	visible = false


## Up: the hand-off from its first frame.
func open() -> void:
	_age = 0.0
	_prompt_age = -1.0
	visible = true
	_block(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	queue_redraw()


func is_up() -> bool:
	return visible


## True while the bare prompt (STORY.md's moment after the credits) is on.
func at_prompt() -> bool:
	return visible and _prompt_age >= 0.0


## On to the bare prompt now (a key), or past it.
func skip() -> void:
	if not visible:
		return
	if _prompt_age < 0.0:
		_prompt_age = 0.0
	else:
		_finish()


## Every line it shows now, for the checks.
func shown_text() -> PackedStringArray:
	var out := PackedStringArray()
	if not visible:
		return out
	if _prompt_age >= 0.0:
		out.append(BARE)
		return out
	out.append(_typed(PROMPT, _age))
	if _age >= HEAD_AT:
		out.append(HEAD)
	if _age >= ROW_AT:
		out.append(_typed(INIT_ROW, _age - ROW_AT))
	if _age >= NOTE_AT:
		out.append(NOTE)
		out.append(KEYS)
	return out


func _finish() -> void:
	if not visible:
		return
	visible = false
	_age = -1.0
	_prompt_age = -1.0
	_block(false)
	finished.emit()


func _block(on: bool) -> void:
	var player = runner.player if runner != null and is_instance_valid(runner) else null
	if on and player != null and is_instance_valid(player) and "input_blocked" in player:
		player.input_blocked = true
		_blocked = player
	elif not on and _blocked != null and is_instance_valid(_blocked):
		_blocked.input_blocked = false
		_blocked = null


func _process(delta: float) -> void:
	if not visible:
		return
	if _prompt_age >= 0.0:
		_prompt_age += delta
		if _prompt_age >= PROMPT_S:
			_finish()
			return
	else:
		_age += delta
		if _age >= NOTE_AT + HOLD_S:
			_prompt_age = 0.0
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE or key.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		skip()


func _unhandled_input(event: InputEvent) -> void:
	# Nothing behind it takes a key or a click while it is up.
	if visible and (event is InputEventKey or event is InputEventMouseButton):
		get_viewport().set_input_as_handled()


func _draw() -> void:
	if not visible:
		return
	var view := size
	draw_rect(Rect2(Vector2.ZERO, view), Palette.VOID)
	var k := clampf(view.y / DESIGN_H, 1.0, SCALE_LAST)
	if _prompt_age >= 0.0:
		# After the credits (STORY.md): a bare prompt, its cursor blinking, nothing typing itself.
		var size_px := roundi(22 * k)
		var at := Vector2(view.x * 0.06, view.y * 0.5)
		draw_string(_font, at, BARE, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px, Palette.MINT)
		if fmod(_prompt_age, 1.0) < 0.55:
			var w := _font.get_string_size(BARE + " ", HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px).x
			draw_rect(Rect2(at + Vector2(w, -size_px * 0.85), Vector2(size_px * 0.55, size_px * 1.05)), Palette.MINT)
		return
	# The Tron grid running away to the horizon, its lines sweeping toward the viewer.
	var horizon := view.y * HORIZON
	var fade := clampf(_age / 0.6, 0.0, 1.0)
	draw_rect(Rect2(0, horizon, view.x, 1.5), Color(Palette.TEAL, 0.5 * fade))
	for i in GRID_LINES:
		var u := fposmod(float(i) / GRID_LINES + _age * 0.08, 1.0)
		var y := horizon + (view.y - horizon) * u * u
		draw_rect(Rect2(0, y, view.x, 1.0), Color(Palette.TEAL, (0.08 + 0.3 * u) * fade))
	var vanish := Vector2(view.x * 0.5, horizon)
	for i in range(-GRID_LINES, GRID_LINES + 1):
		var x := view.x * 0.5 + float(i) * view.x * 0.08
		draw_line(vanish, Vector2(x + float(i) * view.x * 0.5, view.y), Color(Palette.TEAL, 0.12 * fade), 1.0)
	var glow := Color(Palette.TEAL, 0.06 * fade)
	for j in 5:
		draw_rect(Rect2(0, horizon - 8.0 - j * 6.0, view.x, 6.0), Color(glow, glow.a * (1.0 - float(j) / 5.0)))
	# The table: `$ top` typed, its head, init's row, the note.
	var size_px := roundi(16 * k)
	var x := view.x * 0.12
	var y := view.y * 0.14
	var line_h := size_px * 1.6
	var typed := _typed(PROMPT, _age)
	draw_string(_font, Vector2(x, y), typed, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px, Palette.MINT)
	if typed.length() < PROMPT.length() and fmod(_age, 0.8) < 0.45:
		var w := _font.get_string_size(typed, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px).x
		draw_rect(Rect2(Vector2(x + w + 4.0, y - size_px * 0.85), Vector2(size_px * 0.55, size_px * 1.05)), Palette.MINT)
	if _age >= HEAD_AT:
		draw_string(_font, Vector2(x, y + line_h * 1.5), HEAD, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px, Color(Palette.TEAL, 0.9))
		draw_rect(Rect2(x, y + line_h * 1.5 + 6.0, view.x * 0.76, 1.0), Color(Palette.TEAL, 0.5))
	if _age >= ROW_AT:
		var row := _typed(INIT_ROW, _age - ROW_AT)
		var pulse := 0.6 + 0.4 * sin(_age * 3.0)
		draw_string(_font, Vector2(x, y + line_h * 2.6), row, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px, Palette.MATRIX_HEAD.lerp(Palette.MINT, pulse))
	if _age >= NOTE_AT:
		var a := clampf((_age - NOTE_AT) / 0.4, 0.0, 1.0)
		draw_string(_font, Vector2(x, y + line_h * 4.2), NOTE, HORIZONTAL_ALIGNMENT_LEFT, -1.0, roundi(13 * k), Color(Palette.MINT, 0.55 * a))
		var keys_px := roundi(12 * k)
		var kw := _font.get_string_size(KEYS, HORIZONTAL_ALIGNMENT_LEFT, -1.0, keys_px).x
		draw_string(_font, Vector2(view.x - kw - 24.0 * k, view.y - 22.0 * k), KEYS, HORIZONTAL_ALIGNMENT_LEFT, -1.0, keys_px, Color(Palette.MINT, 0.5 * a))


static func _typed(text: String, age: float) -> String:
	return text.left(clampi(floori(maxf(age, 0.0) * TYPE_CPS), 0, text.length()))
