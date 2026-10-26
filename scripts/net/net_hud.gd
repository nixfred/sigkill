extends Control
## The multiplayer panel (C13): M opens it, and inside it H hosts, J asks for an address,
## K asks for a room code or a sigkill://join/ invite link (C15), L leaves, Esc closes. Plain keys only, counted only while the panel is up; Ctrl, Alt
## and Super chords are ignored. The panel sits at the top of the screen, where the
## round summary goes, and the round HUD holds its summary back while it is up.
##
## The address box works like the T ask box: while it is open the mouse is free and the
## player takes no game input; Enter joins, Esc cancels. What is typed stays on this
## screen (the panel shows it back) and goes nowhere but to the session as the address to
## connect to. Every message is a fixed line of SIGKILL's, with the session's own words:
## "couldn't reach host", "version mismatch: host 2, you 1", "host full", "host left".
## A net line under the daemon count shows the session at a glance. A host with a live
## rendezvous also sees its room code and invite link; with none (the game's NullRendezvous
## today) a code typed after K is answered "Online rooms aren't live yet. Use LAN join
## (address)." and nothing is sent anywhere.

const Session = preload("res://scripts/net/net_session.gd")
const Palette = preload("res://scripts/palette.gd")

const TITLE := "multiplayer"
const OFF_LINE := "Play with a friend on your LAN or tailnet. One hosts, the other joins by the host's address."
const OFF_KEYS := "[H] host on port %d   [J] join by address   [K] room code   [Esc] close"
const HOST_LINE := "Hosting on port %d. Share your LAN or tailnet address with your friend."
const HOST_KEYS := "[L] stop hosting   [Esc] close"
const JOINED_LINE := "Joined %s."
const JOINED_KEYS := "[L] leave   [Esc] close"
const CONNECTING_LINE := "Connecting to %s"
const CONNECTING_KEYS := "[Esc] cancel"
const BOX_TITLE := "join: the host's address, with an optional :port"
const ROOM_BOX_TITLE := "join: a room code (6 characters) or a sigkill://join/ link"
const ROOM_LINE := "Room code %s   invite %s   (new code in %d:%02d)"
const ROOM_WAIT_LINE := "Getting a room code..."
const LOOKUP_LINE := "Looking up %s"
const NET_ROOM := "   room %s"
const NET_LOOKUP := "net: finding room"
const BOX_KEYS := "Enter joins   Esc cancels"
const PLAYERS_LINE := "players %d/%d: %s"
const NET_OFF := "net: off   M multiplayer"
const NET_HOSTING := "net: hosting :%d   players %d/%d"
const NET_NOTICE := "   %s"
const NET_JOINED := "net: joined   players %d/%d"
const NET_CONNECTING := "net: connecting"
const SPINNER := ["|", "/", "-", "\\"]
const SPINNER_S := 0.09
const PANEL_WIDTH := 560
const PANEL_TOP := 120
const BOX_CHARS := 260

## The guide HUD (scripts/hud/guide_hud.gd): its box and prompts, which the panel yields
## to, and its lock on the player's input while a box is open.
var guide: Control = null
## The round HUD (scripts/round/round_hud.gd), whose summary waits while the panel is up.
var round_hud: Control = null
## The player, whose input is blocked while the address box is open.
var player: Node = null
## () -> bool, whether the window has focus. Empty: the window's own answer.
var focus_check := Callable()
## The session to drive; null: the one beside the current scene, found when ready.
var session: Node = null

var _open := false
var _typing := false
## What the open box asks for: "address" (J) or "room" (K).
var _box_mode := "address"
var _was_captured := false
var _recaptures := 0
var _spin_s := 0.0
var _spin_at := 0

var _line: Label
var _panel: PanelContainer
var _title: Label
var _body: Label
var _keys: Label
var _edit: LineEdit


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	get_viewport().size_changed.connect(_fit_panel)
	_refresh()


func _process(delta: float) -> void:
	var s := _session()
	if s != null and s.is_connecting():
		_spin_s += delta
		if _spin_s >= SPINNER_S:
			_spin_s = 0.0
			_spin_at = (_spin_at + 1) % SPINNER.size()
	_refresh()


func _input(event: InputEvent) -> void:
	# Before anything else sees the key: Esc closes the address box; while the panel is
	# up, H, J and L are its keys and no one else's.
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if _typing:
		if key.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_close_box()
		return
	if not _open or key.ctrl_pressed or key.alt_pressed or key.meta_pressed or _guide_busy():
		return
	var s := _session()
	if s == null:
		return
	match key.keycode:
		KEY_H:
			get_viewport().set_input_as_handled()
			if not s.is_online() and not s.is_connecting():
				s.host()
		KEY_J:
			get_viewport().set_input_as_handled()
			if not s.is_online() and not s.is_connecting():
				_open_box("address")
		KEY_K:
			get_viewport().set_input_as_handled()
			if not s.is_online() and not s.is_connecting():
				_open_box("room")
		KEY_L:
			get_viewport().set_input_as_handled()
			if s.is_online():
				s.leave()
		KEY_ESCAPE:
			if s.is_connecting():
				s.leave()
			_open = false  # not handled: Esc still frees the mouse as usual
			_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if _typing or _guide_busy():
		return
	if event.is_action_pressed("net_menu", false, true):
		get_viewport().set_input_as_handled()
		toggle()


func _exit_tree() -> void:
	_block_player(false)
	if guide != null and is_instance_valid(guide):
		guide.other_box_open = false
	if round_hud != null and is_instance_valid(round_hud):
		round_hud.hold_summary = false


## The panel up, as a launch --join opens it to show what came of the join.
func open() -> void:
	_open = true
	_refresh()


## M: the panel up or down.
func toggle() -> void:
	if _typing:
		return
	_open = not _open
	_refresh()


func is_open() -> bool:
	return _open


func is_typing() -> bool:
	return _typing


func recaptures() -> int:
	return _recaptures


## The net line under the daemon count.
func line_text() -> String:
	return _line.text


## Everything the panel shows, line by line, or "" when it is down.
func panel_text() -> String:
	if not _panel.visible:
		return ""
	var out := PackedStringArray()
	for label in [_title, _body, _keys]:
		if label.visible and label.text != "":
			out.append(label.text)
	return "\n".join(out)


func _session() -> Node:
	if session != null and is_instance_valid(session):
		return session
	return null


## True while the guide HUD's box or a question of its own is up: the panel yields.
func _guide_busy() -> bool:
	return guide != null and is_instance_valid(guide) and guide.is_prompting()


func _open_box(mode: String) -> void:
	if _typing or _guide_busy():
		return
	_box_mode = mode
	_typing = true
	_was_captured = _mouse_captured()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_block_player(true)
	if guide != null and is_instance_valid(guide):
		guide.other_box_open = true
	_edit.text = ""
	_edit.visible = true
	_edit.editable = true
	_edit.grab_focus()
	_refresh()


func _close_box() -> void:
	if not _typing:
		return
	_typing = false
	_edit.release_focus()
	_edit.visible = false
	_edit.editable = false
	_block_player(false)
	if guide != null and is_instance_valid(guide):
		guide.other_box_open = false
	if _was_captured and _focused():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_recaptures += 1
	_was_captured = false
	_refresh()


func _submit(text: String) -> void:
	_close_box()
	var s := _session()
	if s == null or text.strip_edges().is_empty():
		return
	_spin_at = 0
	if _box_mode == "room":
		s.join_room(text)
	else:
		s.join(text)
	_refresh()


func _mouse_captured() -> bool:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return true
	return player != null and player.get("assume_captured") == true


func _focused() -> bool:
	if not focus_check.is_null():
		return focus_check.call()
	return get_window().has_focus()


func _block_player(on: bool) -> void:
	if player != null and is_instance_valid(player) and "input_blocked" in player:
		player.input_blocked = on


func _refresh() -> void:
	if _line == null:
		return
	var s := _session()
	if round_hud != null and is_instance_valid(round_hud):
		round_hud.hold_summary = _open or _typing
	if s == null:
		_line.text = NET_OFF
		_panel.visible = false
		return
	var count: int = s.players.size()
	var cap: int = s.tuning_in_use().max_players
	match s.state:
		Session.State.HOSTING:
			_line.text = NET_HOSTING % [s.listen_port(), count, cap] + (NET_ROOM % s.room_code if s.room_code != "" else "") + (NET_NOTICE % s.notice if s.notice != "" else "")
		Session.State.JOINED:
			_line.text = NET_JOINED % [count, cap]
		Session.State.RESOLVING, Session.State.CONNECTING:
			_line.text = NET_CONNECTING
		Session.State.ROOM:
			_line.text = NET_LOOKUP
		Session.State.FAILED:
			_line.text = "net: " + s.error
		_:
			_line.text = NET_OFF
	_panel.visible = _open or _typing
	if not _panel.visible:
		return
	_title.text = TITLE
	_title.add_theme_color_override("font_color", Palette.TEAL)
	_body.visible = not _typing
	if _typing:
		_title.text = ROOM_BOX_TITLE if _box_mode == "room" else BOX_TITLE
		_keys.text = BOX_KEYS
		return
	var color := Palette.MINT
	match s.state:
		Session.State.HOSTING:
			_body.text = (HOST_LINE % s.listen_port()) + _room_text(s) + "\n" + PLAYERS_LINE % [count, cap, s.roster_text()] + ("\n" + s.notice if s.notice != "" else "")
			_keys.text = HOST_KEYS
		Session.State.JOINED:
			_body.text = (JOINED_LINE % s.address_text) + "\n" + PLAYERS_LINE % [count, cap, s.roster_text()]
			_keys.text = JOINED_KEYS
		Session.State.RESOLVING, Session.State.CONNECTING, Session.State.ROOM:
			_body.text = ((LOOKUP_LINE if s.state == Session.State.ROOM else CONNECTING_LINE) % s.address_text) + "  " + SPINNER[_spin_at]
			_keys.text = CONNECTING_KEYS
		Session.State.FAILED:
			_body.text = s.error
			color = Palette.HOSTILE_AMBER
			_keys.text = OFF_KEYS % s.tuning_in_use().port
		_:
			_body.text = OFF_LINE
			_keys.text = OFF_KEYS % s.tuning_in_use().port
	_body.add_theme_color_override("font_color", color)


## The room code line under the hosting line, only with a live rendezvous: the code, or the
## wait while one is being registered. After a failed registration the notice says why.
func _room_text(s: Node) -> String:
	if s.room_code != "":
		var left: int = maxi(ceili(s.room_expires_s), 0)
		return "\n" + ROOM_LINE % [s.room_code, Session.RoomCode.link(s.room_code), left / 60, left % 60]
	if s.is_getting_room_code():
		return "\n" + ROOM_WAIT_LINE
	return ""


func _build() -> void:
	_line = _label(self, 14, Palette.MINT)
	_line.position = Vector2(18.0, 68.0)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.VOID, 0.82)
	style.border_color = Palette.TEAL
	style.set_border_width_all(1)
	style.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(stack)
	_title = _label(stack, 15, Palette.TEAL)
	_body = _label(stack, 14, Palette.MINT)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_edit = LineEdit.new()
	_edit.add_theme_font_override("font", Palette.mono_font())
	_edit.add_theme_font_size_override("font_size", 15)
	_edit.context_menu_enabled = false
	_edit.max_length = BOX_CHARS
	_edit.visible = false
	_edit.editable = false
	_edit.text_submitted.connect(_submit)
	stack.add_child(_edit)
	_keys = _label(stack, 13, Palette.MINT)
	_panel.visible = false
	_fit_panel()


func _fit_panel() -> void:
	if _panel == null:
		return
	var screen := get_viewport_rect().size
	var width := mini(PANEL_WIDTH, int(screen.x) - 36)
	_panel.custom_minimum_size = Vector2(maxi(width, 0), 0)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.position.y = PANEL_TOP


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
