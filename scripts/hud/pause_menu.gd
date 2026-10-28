extends Control
## The Esc menu and the settings screen (C16b). Esc opens the menu (the player's own Esc,
## once no box or question took it); Resume, Settings and Quit SIGKILL are on it. Settings
## shows every setting at once in three columns, Controls, Video and Audio, then HUD and
## accessibility, Privacy and AI, and Multiplayer, with no page scroll (Law 17): only the
## list of key binds scrolls, in its own box. Esc goes back a step; changes take effect at
## once and are saved when the settings screen is left (scripts/settings/game_settings.gd,
## the game's one settings file).
##
## Nothing is paused: the menu only stops this player's input (player.input_blocked, which
## also holds the round clock), so a LAN match, the host's simulation and every remote
## player go on as before, and the player can still be hit. While it is open the menu takes
## every key, mouse button and pad button nothing in it used, so no game key acts behind it.
##
## Privacy and AI are their owners' switches, never copies: the AI row is O's toggle (on
## asks the same question by name, Y or N, and the menu steps aside for it), roast is B's,
## and real-machine data is the privacy answer guide_settings.gd keeps, which counts from
## the next launch (off means demo data, as --demo does). The display name is a label only:
## in a match everyone is Daemon-<slot> (C14).

signal closed

const Palette = preload("res://scripts/palette.gd")
const Controls = preload("res://scripts/controls.gd")
const Privacy = preload("res://scripts/boot/guide_settings.gd")

const TITLE := "SIGKILL // menu"
const SETTINGS_TITLE := "SIGKILL // settings"
const RUNNING_ONLINE := "The match keeps running: you can still be hit."
const RUNNING_SOLO := "The round clock waits while this is open."
const CAPTURE_LINE := "Press a key or mouse button for %s. Esc cancels."
const SAVED_LINE := "Saved."
const NOT_SAVED_LINE := "In use for this run; it could not be saved."
const ASKED_LINE := "Answer the question on screen: Y allows, N keeps the AI off."
const REAL_DATA_LATER := "from the next launch"
const REAL_DATA_DEMO := "this run: demo data"
const NAME_NOTE := "a label only: in a match you are Daemon-<slot>"
const QUALITY_LINE := "bloom %s   shadows %s   code rain %s"
const FONT := 13
const HEAD_FONT := 15
const LABEL_W := 132
const CONTROL_W := 176
const VALUE_W := 56
const KEY_NAME_W := 104
const KEY_BUTTON_W := 104
const KEYS_BOX_H := 236
const COLUMN_W := LABEL_W + CONTROL_W + VALUE_W + 8
const MARGIN := 14
const GAP := 16
## Space kept clear around a panel shrunk to fit a small window.
const EDGE := 8.0

## The player whose input the menu stops, and whose camera numbers it shows.
var player: Node = null
## The guide HUD: the session's link and O's toggle.
var guide: Control = null
## The round HUD: B's toggle.
var round_hud: Control = null
## The multiplayer panel, closed when the menu opens.
var net_hud: Control = null
## The session beside the arena: online or not, and its default port.
var session: Node = null
## The settings to show; null: GameSettings.current().
var settings: GameSettings = null
## () -> bool, whether the window has focus. Empty: the window's own answer.
var focus_check := Callable()

var _open := false
var _was_captured := false
var _dirty := false
var _capturing := ""
var _status_text := ""
var _rows := {}
var _keys := {}

var _center: CenterContainer
var _pause: PanelContainer
var _sheet: PanelContainer
var _resume: Button
var _pause_note: Label
var _sheet_note: Label
var _status: Label
var _quality_line: Label
var _ai_button: Button
var _roast: CheckButton
var _real_data: CheckButton
var _real_note: Label
var _name: LineEdit
var _port: SpinBox
var _fov: HSlider
var _fov_value: Label


func _ready() -> void:
	if settings == null:
		settings = GameSettings.current()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var theme_here := Theme.new()
	theme_here.default_font = Palette.mono_font()
	theme_here.default_font_size = FONT
	theme = theme_here
	_build()
	get_viewport().size_changed.connect(_fit)
	visible = false


func is_open() -> bool:
	return _open


func showing_settings() -> bool:
	return _open and _sheet.visible


func is_capturing() -> bool:
	return _capturing != ""


## The last line under the settings: a refusal, a conflict note, "Saved."...
func status_text() -> String:
	return _status_text


## The menu up: the mouse freed, the player's input stopped, the multiplayer panel down.
func open() -> void:
	if _open:
		return
	_open = true
	_status_text = ""
	_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or (player != null and is_instance_valid(player) and player.get("assume_captured") == true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_block_player(true)
	if net_hud != null and is_instance_valid(net_hud) and net_hud.has_method("close"):
		net_hud.close()
	_show_pause()
	visible = true
	_fit()


## The menu down: settings saved if they changed, the player's input back, the mouse
## captured again if it was when the menu opened and the window has focus.
func close() -> void:
	if not _open:
		return
	_capturing = ""
	_save_if_changed()
	_open = false
	visible = false
	_block_player(false)
	if _was_captured and _focused():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_was_captured = false
	closed.emit()


func open_settings() -> void:
	if not _open:
		open()
	_pause.visible = false
	_sheet.visible = true
	_status_text = ""
	_refresh()
	_fit()


## A window smaller than the panel on show (960x540, say) shrinks it to fit, whole and
## centred: never a page scroll, never a clipped row. The centring box is what scales (a
## container resets its children's scale), sized so that, scaled, it covers the window.
func _fit() -> void:
	if _center == null:
		return
	var screen := get_viewport_rect().size
	var panel: PanelContainer = _sheet if _sheet.visible else _pause
	var need: Vector2 = panel.get_combined_minimum_size()
	var k := 1.0
	if need.x > 0.0 and need.y > 0.0:
		k = clampf(minf((screen.x - 2.0 * EDGE) / need.x, (screen.y - 2.0 * EDGE) / need.y), 0.1, 1.0)
	_center.scale = Vector2(k, k)
	_center.position = Vector2.ZERO
	_center.size = screen / k


## How much the panel on show is shrunk to fit the window: 1 at 1280x720 and up.
func fit_scale() -> float:
	return _center.scale.x


## Starts listening for the next key or mouse button for `action`.
func begin_rebind(action: String) -> void:
	if not Controls.rebindable(action):
		return
	_capturing = action
	_say(CAPTURE_LINE % _shown_name(action))
	_refresh()


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if _capturing != "":
		var button := event is InputEventKey or event is InputEventMouseButton
		if button:
			get_viewport().set_input_as_handled()
		if not button or not event.is_pressed() or event.is_echo():
			return
		var action := _capturing
		_capturing = ""
		if _is_escape(event) and not (event as InputEventKey).ctrl_pressed:
			_say("")
		else:
			_take_bind(action, event)
		_refresh()
		return
	if _is_escape(event) and event.is_pressed() and not event.is_echo():
		get_viewport().set_input_as_handled()
		if _sheet.visible:
			_save_if_changed()
			_show_pause()
		else:
			close()


func _unhandled_input(event: InputEvent) -> void:
	if _open and (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton):
		get_viewport().set_input_as_handled()


func _take_bind(action: String, event: InputEvent) -> void:
	var why := settings.set_bind(action, event)
	if why != "":
		_say(why)
		return
	_dirty = true
	var clash: PackedStringArray = settings.conflicts().get(action, PackedStringArray())
	_say("%s: %s" % [_shown_name(action), Controls.bind_label(settings.bind(action))] + ("   conflict: also %s" % ", ".join(clash) if not clash.is_empty() else ""))


func _show_pause() -> void:
	_save_if_changed()
	_sheet.visible = false
	_pause.visible = true
	# The save that leaving the settings just made, said where it can be seen.
	var saved := _status_text == SAVED_LINE or _status_text == NOT_SAVED_LINE
	_pause_note.text = (RUNNING_ONLINE if _online() else RUNNING_SOLO) + ("\n" + _status_text if saved else "")
	_resume.grab_focus()
	_fit()


func _save_if_changed() -> void:
	if not _dirty:
		return
	_dirty = false
	_say(SAVED_LINE if settings.save() else NOT_SAVED_LINE)


func _change(section: String, key: String, v: Variant) -> void:
	if settings.set_value(section, key, v):
		_dirty = true
	_refresh()


func _say(text: String) -> void:
	_status_text = text
	if _status != null:
		_status.text = text


func _online() -> bool:
	return session != null and is_instance_valid(session) and session.is_online()


func _link():
	return guide.session_link() if guide != null and is_instance_valid(guide) else null


func _block_player(on: bool) -> void:
	if player != null and is_instance_valid(player) and "input_blocked" in player:
		player.input_blocked = on


func _focused() -> bool:
	if not focus_check.is_null():
		return focus_check.call()
	return get_window().has_focus()


static func _is_escape(event: InputEvent) -> bool:
	var key := event as InputEventKey
	return key != null and (key.keycode == KEY_ESCAPE or key.physical_keycode == KEY_ESCAPE)


static func _shown_name(action: String) -> String:
	for pair in Controls.REBINDABLE:
		if pair[0] == action:
			return pair[1]
	return action


# --- What the rows show. ---

func _refresh() -> void:
	if _sheet == null or not _sheet.visible:
		return
	for id in _rows:
		var row: Dictionary = _rows[id]
		var v = settings.value(row["section"], row["key"])
		var widget: Control = row["widget"]
		if widget is CheckButton:
			(widget as CheckButton).set_pressed_no_signal(v)
		elif widget is OptionButton:
			(widget as OptionButton).select(row["choices"].find(v))
		elif widget is HSlider and id != "video/fov":
			(widget as HSlider).set_value_no_signal(v)
			row["value"].text = row["format"].call(v)
	var fov: int = settings.value("video", "fov")
	var shown_fov := fov if fov != 0 else _tuning_fov()
	_fov.set_value_no_signal(shown_fov)
	_fov_value.text = "%d%s" % [shown_fov, "" if fov != 0 else " std"]
	var port: int = settings.value("multiplayer", "port")
	_port.set_value_no_signal(port if port != 0 else _tuning_port())
	if not _name.has_focus():
		_name.text = settings.value("multiplayer", "display_name")
	var q := settings.quality()
	_quality_line.text = QUALITY_LINE % [_word(q["bloom"]), _word(q["shadows"]), _word(q["code_rain"])]
	var clashes := settings.conflicts()
	for action in _keys:
		var parts: Dictionary = _keys[action]
		parts["button"].text = "..." if _capturing == action else Controls.bind_label(settings.bind(action))
		parts["clash"].text = ("also " + ", ".join(clashes[action])) if clashes.has(action) else ""
		parts["clash"].tooltip_text = parts["clash"].text
	_refresh_privacy()
	_sheet_note.text = RUNNING_ONLINE if _online() else RUNNING_SOLO


func _refresh_privacy() -> void:
	var link = _link()
	if link == null:
		_ai_button.text = "no AI link"
		_ai_button.disabled = true
		_roast.disabled = true
		_real_data.disabled = true
		return
	_ai_button.disabled = false
	if link.demo:
		_ai_button.text = "on (demo)" if link.ai_on() else "off (demo)"
	elif not link.is_ready():
		_ai_button.text = "linking..."
	elif link.adapter == null:
		_ai_button.text = "no AI found"
		_ai_button.disabled = true
	else:
		_ai_button.text = ("on: " + link.display_name()) if link.ai_on() else "off"
	_roast.disabled = round_hud == null or not is_instance_valid(round_hud)
	_roast.set_pressed_no_signal(link.roast_on())
	_real_data.disabled = false
	_real_data.set_pressed_no_signal(Privacy.real_data_on(link.settings_path))
	_real_note.text = REAL_DATA_DEMO if link.demo else REAL_DATA_LATER


func _tuning_fov() -> int:
	if player != null and is_instance_valid(player) and player.has_method("standard_fov"):
		return roundi(player.standard_fov())
	return 80


func _tuning_port() -> int:
	if session != null and is_instance_valid(session) and session.has_method("tuning_in_use"):
		return session.tuning_in_use().port
	return 9009


static func _word(on: bool) -> String:
	return "on" if on else "off"


# --- The privacy switches: their owners' own. ---

func _on_ai_pressed() -> void:
	if guide == null or not is_instance_valid(guide):
		return
	guide.toggle_ai()
	if guide.is_asking_consent():
		_say(ASKED_LINE)
		close()
		return
	_refresh()


func _on_roast_toggled(on: bool) -> void:
	var link = _link()
	if link != null and round_hud != null and is_instance_valid(round_hud) and link.roast_on() != on:
		round_hud.toggle_roast()
	_refresh()


func _on_real_data_toggled(on: bool) -> void:
	var link = _link()
	if link != null:
		_say(("Real-machine data %s %s." % [_word(on), REAL_DATA_LATER]) if Privacy.save_real_data(on, link.settings_path) else NOT_SAVED_LINE)
	_refresh()


func _on_defaults() -> void:
	settings.reset()
	_dirty = true
	_say("Every setting is back to its default. Privacy answers are unchanged.")
	_refresh()


func _on_reset_keys() -> void:
	settings.reset_binds()
	_dirty = true
	_say("Every key is back to its default.")
	_refresh()


func _on_quit() -> void:
	close()
	# The way a window close goes, so the guide link unloads what the game loaded (C11b).
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	get_tree().quit()


# --- Building. ---

func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(Palette.VOID, 0.62)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_center = center
	_pause = _panel(center)
	var stack := _vbox(_pause, 8)
	_label(stack, TITLE, HEAD_FONT, Palette.TEAL)
	_pause_note = _label(stack, RUNNING_SOLO, FONT, Palette.MINT)
	for pair in [["Resume", close], ["Settings", open_settings], ["Quit SIGKILL", _on_quit]]:
		var button := _button(stack, pair[0], 0)
		button.pressed.connect(pair[1])
		if _resume == null:
			_resume = button
	_sheet = _panel(center)
	var sheet := _vbox(_sheet, 6)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", GAP)
	sheet.add_child(head)
	_label(head, SETTINGS_TITLE, HEAD_FONT, Palette.TEAL)
	_sheet_note = _label(head, RUNNING_SOLO, FONT, Palette.MINT)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", GAP)
	sheet.add_child(columns)
	_build_controls(_column(columns))
	var middle := _column(columns)
	_build_video(middle)
	_build_audio(middle)
	var right := _column(columns)
	_build_hud(right)
	_build_privacy(right)
	_build_multiplayer(right)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	sheet.add_child(foot)
	_button(foot, "Back", 0).pressed.connect(_show_pause)
	_button(foot, "Defaults", 0).pressed.connect(_on_defaults)
	_status = _label(foot, "", FONT, Palette.HOSTILE_AMBER)
	_status.clip_text = true
	_status.custom_minimum_size.x = COLUMN_W * 2
	_sheet.visible = false


func _build_controls(col: VBoxContainer) -> void:
	_label(col, "CONTROLS", HEAD_FONT, Palette.TEAL)
	_check(col, "invert Y", "controls", "invert_y")
	_slider(col, "mouse sens", "controls", "mouse_sensitivity", 0.1, 5.0, 0.05, func(v): return "%.2fx" % v)
	_slider(col, "aim (ADS) sens", "controls", "ads_sensitivity", 0.1, 5.0, 0.05, func(v): return "%.2fx" % v)
	_option(col, "crouch", "controls", "crouch_mode", ["hold", "toggle"])
	_option(col, "aim", "controls", "aim_mode", ["hold", "toggle"])
	var keys_head := HBoxContainer.new()
	col.add_child(keys_head)
	_label(keys_head, "KEYS", HEAD_FONT, Palette.TEAL).custom_minimum_size.x = KEY_NAME_W + KEY_BUTTON_W
	_button(keys_head, "Reset keys", 0).pressed.connect(_on_reset_keys)
	var box := ScrollContainer.new()
	box.name = "KeyList"
	box.custom_minimum_size = Vector2(COLUMN_W, KEYS_BOX_H)
	box.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(box)
	var list := _vbox(box, 2)
	for pair in Controls.REBINDABLE:
		var row := HBoxContainer.new()
		list.add_child(row)
		_label(row, pair[1], FONT, Palette.MINT).custom_minimum_size.x = KEY_NAME_W
		var button := _button(row, "", KEY_BUTTON_W)
		button.pressed.connect(begin_rebind.bind(pair[0]))
		var clash := _label(row, "", FONT - 1, Palette.HOSTILE_AMBER)
		clash.clip_text = true
		clash.mouse_filter = Control.MOUSE_FILTER_PASS
		clash.custom_minimum_size.x = COLUMN_W - KEY_NAME_W - KEY_BUTTON_W - 12
		_keys[pair[0]] = {"button": button, "clash": clash}
	_label(col, "Esc menu   1-9 weapons   wheel cycles\narrows move   right stick looks", FONT - 2, Palette.TEAL)


func _build_video(col: VBoxContainer) -> void:
	_label(col, "VIDEO", HEAD_FONT, Palette.TEAL)
	_option(col, "window", "video", "window_mode", ["windowed", "fullscreen", "borderless"])
	_slider(col, "resolution", "video", "resolution_scale", 0.5, 1.0, 0.05, func(v): return "%d%%" % roundi(v * 100.0))
	_option(col, "fps cap", "video", "fps_cap", [0, 30, 60, 75, 90, 120, 144, 165, 240], ["none", "30", "60", "75", "90", "120", "144", "165", "240"])
	_check(col, "vsync", "video", "vsync")
	var row := _row(col, "field of view")
	_fov = HSlider.new()
	_fov.min_value = GameSettings.FOV_FIRST
	_fov.max_value = GameSettings.FOV_LAST
	_fov.step = 1.0
	_fov.custom_minimum_size.x = CONTROL_W
	_fov.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_fov.value_changed.connect(func(v): _change("video", "fov", int(v)))
	row.add_child(_fov)
	_fov_value = _label(row, "", FONT, Palette.MINT)
	_fov_value.custom_minimum_size.x = VALUE_W
	_option(col, "quality", "video", "quality", ["low", "medium", "high"])
	_quality_line = _label(col, "", FONT - 1, Palette.TEAL)


func _build_audio(col: VBoxContainer) -> void:
	_label(col, "AUDIO", HEAD_FONT, Palette.TEAL)
	for pair in [["master", "master"], ["effects", "effects"], ["music", "music"], ["announcer", "announcer"]]:
		_slider(col, pair[0], "audio", pair[1], 0.0, 1.0, 0.05, func(v): return "%d%%" % roundi(v * 100.0))


func _build_hud(col: VBoxContainer) -> void:
	_label(col, "HUD AND ACCESSIBILITY", HEAD_FONT, Palette.TEAL)
	_option(col, "crosshair", "hud", "crosshair_style", ["cross", "dot", "circle", "cross_dot"], ["cross", "dot", "circle", "cross + dot"])
	_option(col, "crosshair color", "hud", "crosshair_color", ["mint", "white", "yellow", "magenta", "cyan"])
	_check(col, "colorblind-safe", "hud", "colorblind")
	_check(col, "screen shake", "hud", "screen_shake")
	_check(col, "motion blur", "hud", "motion_blur")
	_check(col, "subtitles", "hud", "subtitles")


func _build_privacy(col: VBoxContainer) -> void:
	_label(col, "PRIVACY AND AI", HEAD_FONT, Palette.TEAL)
	var ai := _row(col, "AI")
	_ai_button = _button(ai, "", CONTROL_W)
	_ai_button.pressed.connect(_on_ai_pressed)
	var roast := _row(col, "roast announcer")
	_roast = CheckButton.new()
	_roast.toggled.connect(_on_roast_toggled)
	roast.add_child(_roast)
	var real := _row(col, "real-machine data")
	_real_data = CheckButton.new()
	_real_data.toggled.connect(_on_real_data_toggled)
	real.add_child(_real_data)
	_real_note = _label(real, REAL_DATA_LATER, FONT - 2, Palette.TEAL)


func _build_multiplayer(col: VBoxContainer) -> void:
	_label(col, "MULTIPLAYER", HEAD_FONT, Palette.TEAL)
	var name_row := _row(col, "display name")
	_name = LineEdit.new()
	_name.max_length = GameSettings.NAME_LAST
	_name.placeholder_text = GameSettings.NAME_DEFAULT
	_name.custom_minimum_size.x = CONTROL_W
	_name.text_changed.connect(func(text): _change("multiplayer", "display_name", text))
	_name.focus_exited.connect(_refresh)
	name_row.add_child(_name)
	_label(col, NAME_NOTE, FONT - 2, Palette.TEAL)
	var port_row := _row(col, "default port")
	_port = SpinBox.new()
	_port.min_value = GameSettings.PORT_FIRST
	_port.max_value = GameSettings.PORT_LAST
	_port.step = 1.0
	_port.custom_minimum_size.x = CONTROL_W
	_port.value_changed.connect(func(v): _change("multiplayer", "port", int(v)))
	port_row.add_child(_port)
	_check(col, "net stats", "multiplayer", "net_stats")


func _row(col: VBoxContainer, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	col.add_child(row)
	_label(row, text, FONT, Palette.MINT).custom_minimum_size.x = LABEL_W
	return row


func _check(col: VBoxContainer, text: String, section: String, key: String) -> void:
	var row := _row(col, text)
	var check := CheckButton.new()
	check.toggled.connect(func(on): _change(section, key, on))
	row.add_child(check)
	_rows[section + "/" + key] = {"section": section, "key": key, "widget": check}


func _slider(col: VBoxContainer, text: String, section: String, key: String, lo: float, hi: float, step: float, format: Callable) -> void:
	var row := _row(col, text)
	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.custom_minimum_size.x = CONTROL_W
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(func(v): _change(section, key, v))
	row.add_child(slider)
	var shown := _label(row, "", FONT, Palette.MINT)
	shown.custom_minimum_size.x = VALUE_W
	_rows[section + "/" + key] = {"section": section, "key": key, "widget": slider, "value": shown, "format": format}


func _option(col: VBoxContainer, text: String, section: String, key: String, choices: Array, names: Array = []) -> void:
	var row := _row(col, text)
	var option := OptionButton.new()
	for i in choices.size():
		option.add_item(str(names[i] if i < names.size() else choices[i]), i)
	option.custom_minimum_size.x = CONTROL_W
	option.item_selected.connect(func(at): _change(section, key, choices[at]))
	row.add_child(option)
	_rows[section + "/" + key] = {"section": section, "key": key, "widget": option, "choices": choices}


func _column(parent: Control) -> VBoxContainer:
	var col := _vbox(parent, 3)
	col.custom_minimum_size.x = COLUMN_W
	return col


func _vbox(parent: Control, separation: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	parent.add_child(box)
	return box


func _panel(parent: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.VOID, 0.92)
	style.border_color = Palette.TEAL
	style.set_border_width_all(1)
	style.set_content_margin_all(MARGIN)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel


func _button(parent: Control, text: String, width: int) -> Button:
	var button := Button.new()
	button.text = text
	if width > 0:
		button.custom_minimum_size.x = width
		button.clip_text = true
	parent.add_child(button)
	return button


func _label(parent: Control, text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label
