class_name FirstLaunchCard
extends Control
## The first launch's card (C42; PRD 5.7: "First launch: one-line content note plus opt-in"): shown once, before the
## opener plays itself for the first time, over the arena paused behind it. One line of content note, then the question:
## may the intro show the player's real user name and folder names (C39's opener data: read-only and live, never saved,
## logged or sent, never told to the AI). The highlighted default is No: N, Enter on it, or Esc answer no, and the
## opener plays on invented names; Y, or Yes, answers yes. It only answers (answered(yes)); the Esc menu saves the answer
## (scripts/hud/pause_menu.gd, through the privacy answers and scripts/settings/intro_state.gd) and starts the opener.
## Esc never leaves the player stuck here: it is the safe answer, at once. The window's close is never touched. While
## it is up the arena behind is paused (the first launch is alone only), and let go as it answers; the opener that
## follows pauses it again from its freeze, as from the Esc menu.

signal answered(yes: bool)

const Palette = preload("res://scripts/palette.gd")

const TITLE := "SIGKILL // before the intro"
const NOTE := "Content note: the intro fakes a crash and a break-in on this computer, with glitching visuals and loud music. It is all in the game: nothing is touched."
const QUESTION := "May the intro show your real user name and folder names?"
const DETAIL := "Also your host name, uptime, theme colours and recent file times. Read-only and live: names, counts and times, never what is in a file. Never saved, logged or sent, and your AI never sees them."
const NO := "No: invented names"
const YES := "Yes: my real names"
const KEYS := "N, Enter or Esc: no    Y: yes"
const LATER := "Change it any time: Settings, Privacy and AI, \"opener data\"."
const WIDTH := 760
const FONT := 15
const HEAD_FONT := 18
const MARGIN := 22

var _panel: PanelContainer
var _no: Button
var _yes: Button
var _done := true
var _held := false


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var theme_here := Theme.new()
	theme_here.default_font = Palette.mono_font()
	theme_here.default_font_size = FONT
	theme = theme_here
	_build()


## Up, the arena's look dimmed behind it, No focused (the highlighted default).
func open() -> void:
	_done = false
	visible = true
	if not get_tree().paused:
		get_tree().paused = true
		_held = true
	_no.grab_focus()


func is_open() -> bool:
	return visible and not _done


## The buttons, for the checks: [no, yes].
func buttons() -> Array[Button]:
	return [_no, _yes]


## Every line it shows, for the checks.
func shown_text() -> PackedStringArray:
	var out := PackedStringArray()
	for label in find_children("*", "Label", true, false):
		if (label as Label).is_visible_in_tree() and (label as Label).text != "":
			out.append((label as Label).text)
	return out


## Answers once and goes away.
func answer(yes: bool) -> void:
	if _done:
		return
	_done = true
	visible = false
	_let_go()
	answered.emit(yes)


func _exit_tree() -> void:
	_let_go()


func _let_go() -> void:
	if _held:
		_held = false
		if is_inside_tree():
			get_tree().paused = false


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		match key.keycode:
			KEY_ESCAPE, KEY_N:
				get_viewport().set_input_as_handled()
				answer(false)
			KEY_Y:
				get_viewport().set_input_as_handled()
				answer(true)
			KEY_ENTER, KEY_KP_ENTER:
				get_viewport().set_input_as_handled()
				answer(_yes.has_focus())
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		answer(false)


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(Palette.VOID, 0.72)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.VOID, 0.94)
	style.border_color = Palette.TEAL
	style.set_border_width_all(1)
	style.set_content_margin_all(MARGIN)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.custom_minimum_size.x = WIDTH
	center.add_child(_panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	_panel.add_child(stack)
	_line(stack, TITLE, HEAD_FONT, Palette.TEAL)
	_line(stack, NOTE, FONT - 1, Palette.HOSTILE_AMBER)
	_line(stack, QUESTION, HEAD_FONT, Palette.MINT)
	_line(stack, DETAIL, FONT - 1, Color(Palette.MINT, 0.78))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	stack.add_child(row)
	_no = _button(row, NO, true)
	_no.pressed.connect(answer.bind(false))
	_yes = _button(row, YES, false)
	_yes.pressed.connect(answer.bind(true))
	_line(stack, KEYS, FONT - 2, Color(Palette.MINT, 0.6))
	_line(stack, LATER, FONT - 2, Color(Palette.MINT, 0.6))


func _line(parent: Control, text: String, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = WIDTH - 2 * MARGIN
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	parent.add_child(label)
	return label


## A button; the default one filled in teal, so it reads as the highlighted answer.
func _button(parent: Control, text: String, default: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(260, 38)
	button.add_theme_font_size_override("font_size", FONT + 1)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(Palette.TEAL, 0.85) if default else Color(Palette.VOID, 0.9)
	normal.border_color = Palette.TEAL
	normal.set_border_width_all(1)
	# Drawn over the button's own box: a border only.
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Palette.MINT
	focus.set_border_width_all(3)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(Palette.TEAL, 0.95) if default else Color(Palette.TEAL, 0.25)
	for pair in [["normal", normal], ["focus", focus], ["hover", hover], ["pressed", hover]]:
		button.add_theme_stylebox_override(pair[0], pair[1])
	var ink := Palette.VOID if default else Palette.MINT
	for state in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, ink)
	parent.add_child(button)
	return button
