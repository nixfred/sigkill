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
## in a match everyone is Daemon-<slot> (C14). Light trails (C20) is the match rule a host
## plays by, at once when changed mid-match; a joiner plays by its host's. Gameplay (C27b): the
## daemons' difficulty, and practice (daemons that never attack); in a match both are the
## host's, like light trails.
##
## Loadout (C33): the menu's Loadout opens the loadout screen (scripts/hud/loadout_screen.gd): every weapon's
## skins and mod, earned by playing. Alone, what the player wears changes as it closes. The settings add the
## host's "mods" match rule (multiplayer) and "reset progress", which asks twice before it wipes every unlock.
##
## The game's version (project.godot's, "v0.33.0-prealpha") sits small and dim in the screen's bottom right
## corner while the menu itself is up, as on the boot screen.
##
## Play the opener (C38): the opener's first 35 seconds (scripts/opener/opener.gd) on demo data, over everything,
## with the arena paused behind it; Esc at any moment, or its end, brings this menu back as it was. Alone only: in
## a match the entry is greyed out, since the match cannot pause for it.
##
## Opener data (C39): Privacy and AI's "opener data" switch is the player's opt-in to the opener showing their own
## machine (scripts/opener/real_opener_data.gd: names, entry counts, file times, the theme's colours and the uptime,
## never a file's contents, never kept or sent), off unless turned on, kept by guide_settings.gd as
## opener_real_data. It counts the next time the opener plays; on demo data (--demo, real-machine data off) the
## opener stays on the demo's, and says so.

signal closed

const Palette = preload("res://scripts/palette.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")
const Controls = preload("res://scripts/controls.gd")
const Privacy = preload("res://scripts/boot/guide_settings.gd")
const RelayWire = preload("res://scripts/net/relay_wire.gd")

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
const RELAY_NOTE := "empty: no online rooms, no network call"
const TRAILS_NOTE := "your match when you host; joiners get the host's"
const MODS_NOTE := "mods in your matches; fixed when you start hosting"
const RESET_PROGRESS := "Reset progress"
const RESET_CONFIRM := "Really wipe? click again"
const RESET_ASK := "Wipe every unlock and count? Click Reset progress again within %d s. Nothing else changes."
const RESET_DONE := "Progress wiped: every weapon back to its own skin, nothing earned."
## Seconds the reset's second click is waited for.
const RESET_WAIT_S := 4.0
const OPENER := "Play the opener"
const OPENER_ONLINE := "Not during a match: it pauses the game."
const OPENER_DATA := "opener data"
const OPENER_DATA_NOTE := "names, counts, times, theme, uptime; no contents"
const OPENER_DATA_TIP := "On: the opener shows your user and host names, folder names and how many entries each holds, recent file times, your Omarchy theme's colours and your uptime, read live. It never opens a file to read what is in it, and keeps nothing: nothing is saved, logged or sent. Off: invented demo data, the same beats."
const OPENER_DATA_LATER := "the next time it plays"
const OpenerScene = preload("res://scenes/opener.tscn")
const PRACTICE_NOTE := "practice: no attacks, no ICE; a match plays by its host's"
const RELAY_HINT := "udp://host:9010"
## The graphics toggles (A4) in a grid under the preset, three to a row: [label, key].
const GRAPHICS_TOGGLES := [["bloom", "bloom"], ["shadows", "shadows"], ["code rain", "code_rain"], ["SSAO", "ssao"], ["SSR", "ssr"], ["skyline", "skyline"], ["aberration", "chromatic_aberration"], ["CRT lines", "crt"]]
const TOGGLES_PER_ROW := 3
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
## The version in the corner: its size and how dim.
const VERSION_FONT := 11
const VERSION_ALPHA := 0.6

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
var _ai_button: Button
var _roast: CheckButton
var _real_data: CheckButton
var _real_note: Label
var _opener_data: CheckButton
var _opener_note: Label
var _name: LineEdit
var _port: SpinBox
var _relay: LineEdit
var _fov: HSlider
var _fov_value: Label
var _loadout: LoadoutScreen
var _reset: Button
var _reset_left := 0.0
var _version: Label
var _opener_button: Button
var _opener: Opener = null
## Where the opener's real data comes from once the player has said yes (C39). The tests hand in a reader on a fake
## home folder; nothing else changes it.
var real_opener_source := func() -> OpenerData: return RealOpenerData.for_this_machine()


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
	Progress.current().flush()  # a pause is a good moment to keep what this run has earned (C33)
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
	if showing_opener():
		_opener.skip()
	_capturing = ""
	if _loadout.is_open():
		_loadout.visible = false
		_wear_choices()
	_save_if_changed()
	_open = false
	visible = false
	_block_player(false)
	if _was_captured and _focused():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_was_captured = false
	closed.emit()


## The loadout screen (C33), over the menu.
func open_loadout() -> void:
	if not _open:
		open()
	_pause.visible = false
	_sheet.visible = false
	_loadout.player = player
	_loadout.session = session
	_loadout.open()


func showing_loadout() -> bool:
	return _open and _loadout.is_open()


## The opener (C38): its first 35 seconds, on the demo data or (C39) the player's own (_opener_source), the menu
## out of sight and the arena paused behind it until it ends or Esc. Alone only; in a match nothing happens (null).
func open_opener() -> Opener:
	if _online():
		return null
	if not _open:
		open()
	if showing_opener():
		return _opener
	_capturing = ""
	_loadout.visible = false
	_sheet.visible = false
	visible = false
	_opener = OpenerScene.instantiate()
	_opener.data = _opener_source()
	_opener.pause_world = true
	_opener.finished.connect(_on_opener_finished)
	add_child(_opener)
	return _opener


## The opener's data (C39): the player's own only when they said yes ("opener data") and this run is not on demo
## data (the guide link's demo: --demo, or real-machine data off, checked again here); otherwise, and whenever there
## is no guide link to ask, the demo's.
func _opener_source() -> OpenerData:
	var link = _link()
	if link == null or link.demo:
		return DemoOpenerData.new()
	if not Privacy.real_data_on(link.settings_path) or not Privacy.opener_real_on(link.settings_path):
		return DemoOpenerData.new()
	return real_opener_source.call()


func showing_opener() -> bool:
	return _opener != null and is_instance_valid(_opener) and _opener.playing()


## The opener playing now, or null.
func opener() -> Opener:
	return _opener if _opener != null and is_instance_valid(_opener) else null


func _on_opener_finished(_skipped: bool) -> void:
	if _opener != null and is_instance_valid(_opener):
		_opener.queue_free()
	_opener = null
	visible = true
	if _open:
		_show_pause()


func loadout_screen() -> LoadoutScreen:
	return _loadout


## The version in the corner as shown ("v0.33.0-prealpha"), or "" while it is hidden.
func version_text() -> String:
	return _version.text if _version != null and _version.is_visible_in_tree() else ""


## The loadout screen closed: alone, the player wears what it chose now (a match holds the host's look).
func _on_loadout_closed() -> void:
	_wear_choices()
	if _open:
		_show_pause()


func _wear_choices() -> void:
	if not _online() and player != null and is_instance_valid(player) and player.has_method("wear"):
		player.wear(player.chosen_look())


## Reset progress (C33): the first click asks, a second within RESET_WAIT_S wipes every unlock and count.
func _on_reset_progress() -> void:
	if _reset_left <= 0.0:
		_reset_left = RESET_WAIT_S
		_reset.text = RESET_CONFIRM
		_say(RESET_ASK % roundi(RESET_WAIT_S))
		return
	_reset_left = 0.0
	_reset.text = RESET_PROGRESS
	Progress.current().reset()
	_wear_choices()
	_say(RESET_DONE)


func _process(delta: float) -> void:
	if _reset_left > 0.0:
		_reset_left -= delta
		if _reset_left <= 0.0 and _reset != null:
			_reset.text = RESET_PROGRESS
			if _status_text.begins_with(RESET_ASK.left(20)):
				_say("")


func open_settings() -> void:
	if not _open:
		open()
	_pause.visible = false
	_loadout.visible = false
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
	if not _open or _loadout.is_open() or showing_opener():
		return  # the loadout screen and the opener take their own keys (Esc goes back to the menu)
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
	_loadout.visible = false
	_pause.visible = true
	_opener_button.disabled = _online()
	_opener_button.tooltip_text = OPENER_ONLINE if _online() else ""
	# The save that leaving the settings just made, said where it can be seen.
	var saved := _status_text == SAVED_LINE or _status_text == NOT_SAVED_LINE
	_pause_note.text = (RUNNING_ONLINE if _online() else RUNNING_SOLO) + ("\n" + _status_text if saved else "")
	_resume.grab_focus()
	_fit()


func _save_if_changed() -> void:
	# A box still being typed in takes its text first (the relay box takes it on focus out),
	# so leaving with the cursor in it never loses what was typed.
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if focused != null and is_ancestor_of(focused):
		focused.release_focus()
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
		if widget is CheckButton or widget is CheckBox:
			(widget as BaseButton).set_pressed_no_signal(v)
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
	if not _relay.has_focus():
		_relay.text = settings.value("multiplayer", "relay_url")
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
		_opener_data.disabled = true
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
	_opener_data.disabled = false
	_opener_data.set_pressed_no_signal(Privacy.opener_real_on(link.settings_path))
	_opener_note.text = REAL_DATA_DEMO if link.demo else ""


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


func _on_opener_data_toggled(on: bool) -> void:
	var link = _link()
	if link != null:
		_say(("Opener data %s: %s." % [_word(on), REAL_DATA_DEMO if link.demo else OPENER_DATA_LATER]) if Privacy.save_opener_real(on, link.settings_path) else NOT_SAVED_LINE)
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
	for pair in [["Resume", close], ["Loadout", open_loadout], [OPENER, open_opener], ["Settings", open_settings], ["Quit SIGKILL", _on_quit]]:
		var button := _button(stack, pair[0], 0)
		button.pressed.connect(pair[1])
		if _resume == null:
			_resume = button
		if pair[0] == OPENER:
			_opener_button = button
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
	_build_gameplay(middle)
	var right := _column(columns)
	_build_hud(right)
	_build_privacy(right)
	_build_multiplayer(right)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	sheet.add_child(foot)
	_button(foot, "Back", 0).pressed.connect(_show_pause)
	_button(foot, "Defaults", 0).pressed.connect(_on_defaults)
	_reset = _button(foot, RESET_PROGRESS, 0)
	_reset.pressed.connect(_on_reset_progress)
	_status = _label(foot, "", FONT, Palette.HOSTILE_AMBER)
	_status.clip_text = true
	_status.custom_minimum_size.x = COLUMN_W * 2
	_sheet.visible = false
	# The version, small and dim in the screen's bottom right corner while the menu itself is up
	# (never over the settings sheet, which can fill the window, or the loadout screen).
	_version = _label(self, SettingsApply.version_tag(), VERSION_FONT, Color(Palette.MINT, VERSION_ALPHA))
	_version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, MARGIN)
	_version.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_pause.visibility_changed.connect(func() -> void: _version.visible = _pause.visible)
	_loadout = LoadoutScreen.new()
	_loadout.name = "Loadout"
	add_child(_loadout)
	_loadout.closed.connect(_on_loadout_closed)


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
	# Graphics (A4): the preset, each thing it sets as a toggle of its own beside the two post
	# effects, and the particle level. "custom" shows when the toggles match no preset; it is
	# never picked.
	_option(col, "quality", "video", "quality", ["low", "medium", "high", GameSettings.CUSTOM])
	(_rows["video/quality"]["widget"] as OptionButton).set_item_disabled(3, true)
	var grid := GridContainer.new()
	grid.columns = TOGGLES_PER_ROW
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 0)
	col.add_child(grid)
	for pair in GRAPHICS_TOGGLES:
		var box := CheckBox.new()
		box.text = pair[0]
		box.custom_minimum_size.x = (COLUMN_W - 12) / TOGGLES_PER_ROW
		box.add_theme_color_override("font_color", Palette.MINT)
		box.toggled.connect(func(on): _change("video", pair[1], on))
		grid.add_child(box)
		_rows["video/" + pair[1]] = {"section": "video", "key": pair[1], "widget": box}
	_option(col, "particles", "video", "particles", ["low", "medium", "high"])


func _build_audio(col: VBoxContainer) -> void:
	_label(col, "AUDIO", HEAD_FONT, Palette.TEAL)
	for pair in [["master", "master"], ["effects", "effects"], ["music", "music"], ["announcer", "announcer"]]:
		_slider(col, pair[0], "audio", pair[1], 0.0, 1.0, 0.05, func(v): return "%d%%" % roundi(v * 100.0))


## The daemons fighting back (C27b): how hard, or not at all; and ICE (I1) on or off, beside them.
func _build_gameplay(col: VBoxContainer) -> void:
	_label(col, "GAMEPLAY", HEAD_FONT, Palette.TEAL)
	_option(col, "difficulty", "gameplay", "difficulty", ["easy", "normal", "hard"])
	_check(col, "practice", "gameplay", "practice")
	_check(col, "ICE", "gameplay", "ice")
	_label(col, PRACTICE_NOTE, FONT - 2, Palette.TEAL)


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
	var opener := _row(col, OPENER_DATA)
	opener.tooltip_text = OPENER_DATA_TIP
	opener.mouse_filter = Control.MOUSE_FILTER_PASS
	_opener_data = CheckButton.new()
	_opener_data.tooltip_text = OPENER_DATA_TIP
	_opener_data.toggled.connect(_on_opener_data_toggled)
	opener.add_child(_opener_data)
	_opener_note = _label(opener, "", FONT - 2, Palette.TEAL)
	_label(col, OPENER_DATA_NOTE, FONT - 2, Palette.TEAL)


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
	var relay_row := _row(col, "relay")
	_relay = LineEdit.new()
	_relay.max_length = RelayWire.URL_LAST
	_relay.placeholder_text = RELAY_HINT
	_relay.custom_minimum_size.x = CONTROL_W
	# Taken whole, when the box is left or Enter pressed: half a URL is never tried.
	_relay.text_submitted.connect(func(text): _set_relay(text))
	_relay.focus_exited.connect(func(): _set_relay(_relay.text))
	relay_row.add_child(_relay)
	_label(col, RELAY_NOTE, FONT - 2, Palette.TEAL)
	_check(col, "net stats", "multiplayer", "net_stats")
	_check(col, "light trails", "multiplayer", "light_trails")
	_label(col, TRAILS_NOTE, FONT - 2, Palette.TEAL)
	_check(col, "mods", "multiplayer", "mods")
	_label(col, MODS_NOTE, FONT - 2, Palette.TEAL)


## The relay URL as typed, trimmed; refused (and said why) unless empty or a relay URL:
## udp://, ws:// or wss://host[:port] (C16c, C16d).
func _set_relay(text: String) -> void:
	var url := text.strip_edges()
	if url == settings.value("multiplayer", "relay_url"):
		_refresh()
		return
	if settings.set_value("multiplayer", "relay_url", url):
		_dirty = true
		_say("Relay %s: it counts from your next host or join." % ("cleared" if url == "" else "set"))
	else:
		_say("A relay is udp://host, ws://host or wss://host (each with an optional :port), or empty for none.")
	_refresh()


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
