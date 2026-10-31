class_name MissionEndScreen
extends Control
## A mission's end (C35, scripts/missions/mission_runner.gd), over the arena dimmed under scan lines.
##   complete  "exit 0" types in, the mission's number and title and COMPLETE, its time (and the best, or "new best"),
##             kills, logs found and tries, the weapons it handed out for keeps as chips in each weapon's own light,
##             then [Next: <the next mission>] (focused; "in production" and dimmed while that mission is not built),
##             [Missions] and [Free play].
##   failed    "exit 137" (128 + 9: what a shell says of a process SIGKILL took) in hostile red, why (derezzed by what,
##             or the timeslice ran out), how far it got and the try, then [Retry] (focused), [Missions], [Free play].
## The panel fades in and its lines come one after another. Enter takes the focused choice, Esc goes to the Missions
## screen, the mouse is free while it is up and the player's input stopped; the window's close always works. Each
## choice reloads the arena (the runner's retry(), next_mission(), to_missions(), free_play()).

signal chose(what: String)

const Palette = preload("res://scripts/palette.gd")

const DESIGN_H := 720.0
const WIDTH := 660
const MARGIN := 24
const FONT := 14
const RETRY := "Retry"
const NEXT := "Next: %s  %s"
const NEXT_LATER := "%s  %s: in production"
const MISSIONS := "Missions"
const FREE_PLAY := "Free play"
const COMPLETE := "COMPLETE"
const FAILED := "FAILED"
const HANDED := "HANDED TO YOU"
const ALREADY := "already yours: %s"
const DRAFT_NOTE := "a first cut on today's arena: the full mission lands in a later build"
const KEYS := "Enter chooses   Esc: missions"
## Seconds: the panel growing in, and between one line and the next.
const GROW_S := 0.24
const STAGGER_S := 0.08
const CODE_CPS := 18.0

var runner: MissionRunner = null

var _center: CenterContainer
var _panel: PanelContainer
var _style: StyleBoxFlat
var _stack: VBoxContainer
var _code: Label
var _head: Label
var _why: Label
var _rows: GridContainer
var _chips_head: Label
var _chips: HBoxContainer
var _note: Label
var _first: Button
var _second: Button
var _third: Button
var _kind := ""
var _age := 0.0
var _accent := Palette.MINT
var _blocked: Node = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var theme_here := Theme.new()
	theme_here.default_font = Palette.mono_font()
	theme_here.default_font_size = FONT
	theme = theme_here
	_build()
	visible = false
	get_viewport().size_changed.connect(_fit)


func is_up() -> bool:
	return visible


## "complete" or "failed" while up, else "".
func kind() -> String:
	return _kind if visible else ""


## Its choices in order, for the checks: [first, second, third].
func buttons() -> Array[Button]:
	return [_first, _second, _third]


## Every line it shows, for the checks.
func shown_text() -> PackedStringArray:
	var out := PackedStringArray()
	for label in find_children("*", "Label", true, false):
		if (label as Label).is_visible_in_tree() and (label as Label).text != "":
			out.append((label as Label).text)
	for button in buttons():
		if button.is_visible_in_tree():
			out.append(button.text)
	return out


func show_complete() -> void:
	var def := runner.def
	var r := runner.result
	_kind = "complete"
	_accent = Palette.MINT
	_code.text = "exit 0"
	_head.text = "MISSION %s // %s   %s" % [def.number(), def.title, COMPLETE]
	_why.visible = false
	_clear_rows()
	var best_s: float = r.get("best_s", r["seconds"])
	_row("time", "%s   %s" % [clock_text(r["seconds"]), "new best" if r.get("best", false) else "best " + clock_text(best_s)])
	_row("kills", str(r["kills"]))
	_row("logs", "%d/%d" % [r["logs"], r["logs_total"]])
	_row("tries", str(r["attempt"]))
	for chip in _chips.get_children():
		chip.queue_free()
	var granted: PackedStringArray = r.get("granted", PackedStringArray())
	_chips_head.visible = not granted.is_empty() or not def.grants.is_empty()
	_chips.visible = not granted.is_empty()
	if not granted.is_empty():
		_chips_head.text = HANDED
		for w in granted:
			_chip(w)
	elif not def.grants.is_empty():
		var names := PackedStringArray()
		for w in def.grants:
			names.append(short_of(w))
		_chips_head.text = ALREADY % ", ".join(names)
	_note.text = DRAFT_NOTE if def.draft else ""
	_note.visible = def.draft
	var after := MissionBook.of(def.next) if def.next != "" else null
	_first.visible = after != null
	if after != null:
		_first.text = (NEXT % [after.number(), after.title]) if after.playable else (NEXT_LATER % [after.number(), after.title])
		_first.disabled = not after.playable
	_second.text = MISSIONS
	_third.text = FREE_PLAY
	_open()


func show_failed() -> void:
	var def := runner.def
	var r := runner.result
	_kind = "failed"
	_accent = Palette.HOSTILE_RED
	_code.text = "exit 137"
	_head.text = "MISSION %s // %s   %s" % [def.number(), def.title, FAILED]
	_why.text = str(r.get("reason", ""))
	_why.visible = true
	_clear_rows()
	var at := clampi(runner.index, 0, def.objectives.size() - 1)
	_row("objective", "%d/%d  %s" % [at + 1, def.objectives.size(), str(def.objectives[at]["text"])])
	_row("time", clock_text(r["seconds"]))
	_row("try", str(r["attempt"]))
	for chip in _chips.get_children():
		chip.queue_free()
	_chips_head.visible = false
	_chips.visible = false
	_note.visible = false
	_first.visible = true
	_first.text = RETRY
	_first.disabled = false
	_second.text = MISSIONS
	_third.text = FREE_PLAY
	_open()


func hide_screen() -> void:
	if not visible:
		return
	visible = false
	_kind = ""
	_block(false)


## One of its choices: "retry" or "next" (the first button), "missions", "free_play".
func choose(what: String) -> void:
	if not visible:
		return
	hide_screen()
	chose.emit(what)
	if runner == null or not is_instance_valid(runner):
		return
	match what:
		"retry":
			runner.retry()
		"next":
			runner.next_mission()
		"missions":
			runner.to_missions()
		"free_play":
			runner.free_play()


func _open() -> void:
	_age = 0.0
	_style.border_color = _accent
	_code.add_theme_color_override("font_color", _accent)
	_code.visible_characters = 0
	visible = true
	_block(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_fit()
	var focus := _first if _first.visible and not _first.disabled else _second
	focus.grab_focus()
	queue_redraw()


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
	_age += delta
	var grow := clampf(_age / GROW_S, 0.0, 1.0)
	_panel.modulate.a = grow  # alpha only: a container sets its children's scale and place back
	_code.visible_characters = clampi(floori(_age * CODE_CPS), 0, _code.text.length())
	var i := 0
	for child in _stack.get_children():
		if child == _code or not (child is CanvasItem):
			continue
		(child as CanvasItem).modulate.a = clampf((_age - GROW_S - i * STAGGER_S) / 0.16, 0.0, 1.0)
		i += 1
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		choose("missions")


func _unhandled_input(event: InputEvent) -> void:
	# Nothing behind it takes a key or a click while it is up.
	if visible and (event is InputEventKey or event is InputEventMouseButton):
		get_viewport().set_input_as_handled()


func _draw() -> void:
	if not visible:
		return
	var view := size
	draw_rect(Rect2(Vector2.ZERO, view), Color(Palette.VOID, 0.72))
	var y := fposmod(_age * 40.0, 4.0)
	while y < view.y:
		draw_rect(Rect2(0, y, view.x, 1), Color(_accent, 0.035))
		y += 4.0
	var sweep := fposmod(_age * 0.25, 1.0) * view.y
	draw_rect(Rect2(0, sweep, view.x, 2), Color(_accent, 0.08))
	var glow := clampf(_age / GROW_S, 0.0, 1.0)
	var c := view * 0.5
	for i in 6:
		var half := Vector2(WIDTH * 0.5 + 30 + i * 26, 190 + i * 22) * _scale()
		draw_rect(Rect2(c - half, half * 2.0), Color(_accent, 0.022 * glow))


## Its size for the window's: 720 lines as drawn, larger windows larger (up to twice).
func _fit() -> void:
	if _center == null:
		return
	var k := _scale()
	_center.pivot_offset = _center.size * 0.5
	_center.scale = Vector2(k, k)


func _scale() -> float:
	return clampf(get_viewport_rect().size.y / DESIGN_H, 1.0, 2.0)


func _build() -> void:
	_center = CenterContainer.new()
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center.resized.connect(_fit)
	_panel = PanelContainer.new()
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(Palette.VOID, 0.93)
	_style.border_color = Palette.MINT
	_style.set_border_width_all(2)
	_style.set_content_margin_all(MARGIN)
	_style.shadow_color = Color(Palette.VOID, 0.6)
	_style.shadow_size = 12
	_panel.add_theme_stylebox_override("panel", _style)
	_panel.custom_minimum_size.x = WIDTH
	_center.add_child(_panel)
	_stack = VBoxContainer.new()
	_stack.add_theme_constant_override("separation", 10)
	_panel.add_child(_stack)
	_code = _label(_stack, "", 54, Palette.MINT)
	_head = _label(_stack, "", 16, Palette.TEAL)
	_why = _label(_stack, "", 14, Palette.HOSTILE_AMBER)
	_rows = GridContainer.new()
	_rows.columns = 2
	_rows.add_theme_constant_override("h_separation", 22)
	_rows.add_theme_constant_override("v_separation", 4)
	_stack.add_child(_rows)
	_chips_head = _label(_stack, HANDED, 11, Palette.TEAL)
	_chips = HBoxContainer.new()
	_chips.add_theme_constant_override("separation", 10)
	_stack.add_child(_chips)
	_note = _label(_stack, "", 11, Color(Palette.MINT, 0.6))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_stack.add_child(row)
	_first = _button(row, true)
	_first.pressed.connect(func() -> void: choose("retry" if _kind == "failed" else "next"))
	_second = _button(row, false)
	_second.pressed.connect(choose.bind("missions"))
	_third = _button(row, false)
	_third.pressed.connect(choose.bind("free_play"))
	_label(_stack, KEYS, 11, Color(Palette.MINT, 0.55))


func _clear_rows() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()


func _row(key: String, value: String) -> void:
	_label(_rows, key, 13, Color(Palette.TEAL, 0.9)).custom_minimum_size.x = 110
	_label(_rows, value, 15, Palette.MINT)


func _chip(weapon: String) -> void:
	var def := def_of(weapon)
	var beam: Color = def.skin_beam() if def != null else Palette.MINT
	var chip := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(beam, 0.14)
	style.border_color = beam
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	chip.add_theme_stylebox_override("panel", style)
	_chips.add_child(chip)
	var words := _label(chip, "%s  [%s]" % [short_of(weapon), MissionHud.key_of(weapon)], 14, beam)
	words.autowrap_mode = TextServer.AUTOWRAP_OFF


## The shipped weapon with id `weapon`, or null.
static func def_of(weapon: String) -> WeaponDef:
	for def in WeaponKit.shipped_defs():
		if def.id == weapon:
			return def
	return null


## Weapon `weapon`'s short name ("kill -9").
static func short_of(weapon: String) -> String:
	var def := def_of(weapon)
	return def.short_name if def != null else weapon


## `seconds` as a clock to the tenth: "01:42.3".
static func clock_text(seconds: float) -> String:
	var tenths := maxi(roundi(seconds * 10.0), 0)
	return "%02d:%02d.%d" % [tenths / 600, (tenths / 10) % 60, tenths % 10]


func _label(parent: Control, text: String, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if parent == _stack:
		label.custom_minimum_size.x = WIDTH - 2 * MARGIN
	parent.add_child(label)
	return label


## A choice; the first filled in the theme's teal, so Enter's answer reads at a glance.
func _button(parent: Control, filled: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(180, 40)
	button.add_theme_font_size_override("font_size", FONT + 1)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(Palette.TEAL, 0.85) if filled else Color(Palette.VOID, 0.9)
	normal.border_color = Palette.TEAL
	normal.set_border_width_all(1)
	normal.set_content_margin_all(8)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Palette.MINT
	focus.set_border_width_all(3)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(Palette.TEAL, 0.95) if filled else Color(Palette.TEAL, 0.25)
	var off := normal.duplicate() as StyleBoxFlat
	off.bg_color = Color(Palette.VOID, 0.9)
	off.border_color = Color(Palette.TEAL, 0.35)
	for pair in [["normal", normal], ["focus", focus], ["hover", hover], ["pressed", hover], ["disabled", off]]:
		button.add_theme_stylebox_override(pair[0], pair[1])
	var ink := Palette.VOID if filled else Palette.MINT
	for state in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, ink)
	button.add_theme_color_override("font_disabled_color", Color(Palette.MINT, 0.4))
	parent.add_child(button)
	return button
