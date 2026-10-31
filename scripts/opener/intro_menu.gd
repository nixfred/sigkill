class_name IntroMenu
extends Control
## The intro's own Esc menu and its hold-to-skip (C42), over the opener (scripts/opener/opener.gd). Esc pauses the
## intro and shows this: "Resume intro", "Skip intro" (focused, so Esc then Enter skips) and the "Skip the intro next
## time" toggle; Esc again resumes. Holding Space for HOLD_S skips from any moment of it: a key or a click shows how
## (the hint in the corner, for HINT_S), and the ring there fills while Space is held. It only shows and tells
## (resume_pressed, skip_pressed, skip_next_toggled); the opener does the rest, and the Esc menu (scripts/hud/
## pause_menu.gd) keeps the toggle. It reads and writes nothing.

signal resume_pressed
signal skip_pressed
signal skip_next_toggled(on: bool)

const Palette = preload("res://scripts/palette.gd")

const TITLE := "intro paused"
const RESUME := "Resume intro"
const SKIP := "Skip intro"
const SKIP_NEXT := "Skip the intro next time"
const MENU_KEYS := "Esc: resume    Enter: skip    hold Space: skip"
const HINT := "hold Space to skip    Esc: menu"
## Seconds Space is held to skip, and how long the hint stays after a key or a click.
const HOLD_S := 1.0
const HINT_S := 2.6
const FONT := 15
const HEAD_FONT := 18
const WIDTH := 360
const MARGIN := 20
## The hint's ring, at 1080 lines: its radius and width, and the corner's margin.
const RING_R := 16.0
const RING_W := 3.5
const EDGE := 36.0

var _panel: PanelContainer
var _resume: Button
var _skip: Button
var _toggle: CheckButton
var _hint: Label
var _hint_left := 0.0
var _hold := 0.0
var _scale := 1.0


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var theme_here := Theme.new()
	theme_here.default_font = Palette.mono_font()
	theme_here.default_font_size = FONT
	theme = theme_here
	_build()


## The menu up: the intro paused behind it, Skip intro focused, the toggle as given.
func open(skip_next: bool) -> void:
	_toggle.set_pressed_no_signal(skip_next)
	_panel.visible = true
	_hold = 0.0
	_skip.grab_focus()
	queue_redraw()


func close() -> void:
	_panel.visible = false
	if _skip.has_focus() or _resume.has_focus() or _toggle.has_focus():
		get_viewport().gui_release_focus()


func showing() -> bool:
	return _panel != null and _panel.visible


## The toggle as shown.
func skip_next() -> bool:
	return _toggle.button_pressed


## The buttons, for the checks: [resume, skip].
func buttons() -> Array[Button]:
	return [_resume, _skip]


func toggle() -> CheckButton:
	return _toggle


## A key or a click while it plays: the hint shows for a moment.
func poke() -> void:
	_hint_left = HINT_S


## How far Space has been held (0 to 1): the ring; the hint shows while it is held.
func set_hold(share: float) -> void:
	_hold = clampf(share, 0.0, 1.0)
	if _hold > 0.0:
		_hint_left = maxf(_hint_left, 0.4)


## Whether the hint shows now.
func hint_showing() -> bool:
	return _hint != null and _hint.visible


## Moves the hint's clock on (real seconds).
func step(delta: float) -> void:
	_hint_left = maxf(_hint_left - delta, 0.0)
	_scale = maxf(get_viewport_rect().size.y / 1080.0, 0.5)
	_hint.visible = _hint_left > 0.0 and not showing()
	_hint.modulate.a = clampf(_hint_left / 0.4, 0.0, 1.0)
	_hint.add_theme_font_size_override("font_size", roundi(FONT * _scale * 1.2))
	var size := _hint.get_minimum_size()
	var view := get_viewport_rect().size
	_hint.position = Vector2(view.x - EDGE * _scale - size.x - (RING_R * 2.0 + 14.0) * _scale, view.y - EDGE * _scale - size.y)
	queue_redraw()


func _draw() -> void:
	if not _hint.visible:
		return
	var view := get_viewport_rect().size
	var c := Vector2(view.x - EDGE * _scale - RING_R * _scale, view.y - EDGE * _scale - _hint.get_minimum_size().y * 0.5)
	var a := _hint.modulate.a
	draw_arc(c, RING_R * _scale, 0.0, TAU, 40, Color(Palette.MINT, 0.25 * a), RING_W * _scale, true)
	if _hold > 0.0:
		draw_arc(c, RING_R * _scale, -PI / 2.0, -PI / 2.0 + TAU * _hold, 40, Color(Palette.TEAL, a), RING_W * _scale, true)


func _build() -> void:
	_hint = Label.new()
	_hint.text = HINT
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_color_override("font_color", Color(Palette.MINT, 0.85))
	_hint.add_theme_color_override("font_outline_color", Palette.VOID)
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.visible = false
	add_child(_hint)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.VOID, 0.9)
	style.border_color = Palette.TEAL
	style.set_border_width_all(1)
	style.set_content_margin_all(MARGIN)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.custom_minimum_size.x = WIDTH
	_panel.visible = false
	center.add_child(_panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	_panel.add_child(stack)
	var head := Label.new()
	head.text = TITLE
	head.add_theme_font_size_override("font_size", HEAD_FONT)
	head.add_theme_color_override("font_color", Palette.TEAL)
	stack.add_child(head)
	_resume = Button.new()
	_resume.text = RESUME
	_resume.pressed.connect(func() -> void: resume_pressed.emit())
	stack.add_child(_resume)
	_skip = Button.new()
	_skip.text = SKIP
	_skip.pressed.connect(func() -> void: skip_pressed.emit())
	stack.add_child(_skip)
	_toggle = CheckButton.new()
	_toggle.text = SKIP_NEXT
	_toggle.toggled.connect(func(on: bool) -> void: skip_next_toggled.emit(on))
	stack.add_child(_toggle)
	var keys := Label.new()
	keys.text = MENU_KEYS
	keys.add_theme_font_size_override("font_size", FONT - 3)
	keys.add_theme_color_override("font_color", Color(Palette.MINT, 0.6))
	stack.add_child(keys)
