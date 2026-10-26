extends Control
## What synced combat (C14) shows this player: a line under the net line with their health,
## spawn protection or death and the respawn countdown; a kill feed at the bottom right,
## the last few kills in SIGKILL's words, naming the weapon's signal ("SIGKILL sent by
## Daemon-2" / "to Daemon-1" for the cannon, "SIGTERM sent by ..." for SIGTERM, C16), each
## fading out; a flash of hostile red when they are hit; a mint border while they are
## freshly spawned and safe; and a centred banner while they are dead. The hit marker for a
## confirmed hit is the C6 one, through hud.gd. Everything here follows the host's confirmed
## results, which arrive through the session's signals; nothing is guessed locally.
## Shown only while a session is online; solo play sees none of it.

const Session = preload("res://scripts/net/net_session.gd")
const Palette = preload("res://scripts/palette.gd")

const HEALTH_LINE := "health %d"
const PROTECT_LINE := "   spawn protection %.1f s"
const DEAD_LINE := "DEREZZED by %s   respawn in %.1f s"
const BANNER := "[ DEREZZED by %s ]\n\nrespawn in %.1f s"
const FEED_FIRST := "%s sent by %s"
## The cannon's signal: the feed's word when the weapon is not known.
const DEFAULT_WORD := "SIGKILL"
const FEED_SECOND := "to %s"
const FEED_FONT := 13
## Room below the feed for the hint line and the weapon strip (C16).
const FEED_BOTTOM_GAP := 104
const FLASH_ALPHA := 0.28
const BORDER_WIDTH := 3

## The session whose results to show; set through set_session.
var session: Node = null
## The hud.gd that owns the hit marker.
var hud: CanvasLayer = null
## The kill feed, newest first: {killer, victim, word, left}, the names and the weapon's
## signal as they were at the kill.
var entries: Array = []

var _flash_left := 0.0
var _line: Label
var _feed: VBoxContainer
var _feed_labels: Array = []
var _flash: ColorRect
var _border: PanelContainer
var _banner: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_refresh()


func set_session(s: Node) -> void:
	_unhook()
	session = s
	entries.clear()
	_flash_left = 0.0
	if s == null:
		return
	# Methods, never lambdas: the session outlives this HUD (R reloads the arena under a
	# live match), and a lambda left on its signal would run on a freed HUD.
	s.shot_confirmed.connect(_on_shot)
	s.player_died.connect(_on_death)
	s.player_respawned.connect(_on_respawn)
	s.combat_changed.connect(_refresh)
	s.changed.connect(_refresh)


func _exit_tree() -> void:
	_unhook()


## Takes this HUD off the session's signals; the session goes on without it.
func _unhook() -> void:
	if session == null or not is_instance_valid(session):
		return
	for pair in [["shot_confirmed", _on_shot], ["player_died", _on_death], ["player_respawned", _on_respawn], ["combat_changed", _refresh], ["changed", _refresh]]:
		if session.is_connected(pair[0], pair[1]):
			session.disconnect(pair[0], pair[1])


func _on_respawn(_id: int) -> void:
	_refresh()


func _process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left = maxf(_flash_left - delta, 0.0)
	var fade: float = session.combat_tuning_in_use().kill_feed_fade_s if session != null and is_instance_valid(session) else 6.0
	var i := 0
	while i < entries.size():
		entries[i]["left"] -= delta
		if entries[i]["left"] <= 0.0:
			entries.remove_at(i)
		else:
			i += 1
	_refresh(fade)


func flash_left() -> float:
	return _flash_left


func line_text() -> String:
	return _line.text if _line.visible else ""


func banner_text() -> String:
	return _banner.text if _banner.visible else ""


## The kill feed as shown, newest first, both lines of each entry joined by a space.
func feed_text() -> PackedStringArray:
	var out := PackedStringArray()
	for label in _feed_labels:
		if label.visible and label.text != "":
			out.append(label.text.replace("\n", " "))
	return out


func _on_shot(shooter: int, hit: int, _origin: Vector3, _end_point: Vector3) -> void:
	if session == null:
		return
	if hit != 0 and shooter == session.my_id and hud != null and is_instance_valid(hud):
		hud.confirm_hit()
	if hit == session.my_id and hit != shooter:
		_flash_left = session.combat_tuning_in_use().damage_flash_s


func _on_death(victim: int, killer: int) -> void:
	if session == null:
		return
	var word: String = session.last_kill_word.get(victim, "")
	entries.push_front({"killer": _name(killer), "victim": _name(victim), "word": word if word != "" else DEFAULT_WORD, "left": session.combat_tuning_in_use().kill_feed_fade_s})
	while entries.size() > session.combat_tuning_in_use().kill_feed_length:
		entries.pop_back()
	_refresh()


func _name(id: int) -> String:
	return session.players.get(id, {}).get("name", "Daemon-?")


func _refresh(fade: float = -1.0) -> void:
	if _line == null:
		return
	var online: bool = session != null and is_instance_valid(session) and session.is_online()
	_line.visible = online
	_flash.visible = online and _flash_left > 0.0
	if not online:
		# The match is over: nothing of it carries into the next one. (A player merely
		# leaving keeps the session online, and the feed with it.)
		entries.clear()
		_flash_left = 0.0
		_border.visible = false
		_banner.visible = false
		for label in _feed_labels:
			label.visible = false
		return
	var me: int = session.my_id
	var dead: bool = session.dead.get(me, false)
	var protect: float = session.protect_left.get(me, 0.0)
	if dead:
		var killer: String = session.last_killer_name.get(me, _name(session.last_killer.get(me, 0)))
		var left: float = session.respawn_left.get(me, 0.0)
		_line.text = DEAD_LINE % [killer, left]
		_banner.text = BANNER % [killer, left]
	else:
		_line.text = HEALTH_LINE % roundi(session.health.get(me, 0.0)) + (PROTECT_LINE % protect if protect > 0.0 else "")
	_line.add_theme_color_override("font_color", Palette.HOSTILE_AMBER if dead else Palette.MINT)
	_banner.visible = dead
	_border.visible = not dead and protect > 0.0
	_flash.color = Color(Palette.HOSTILE_RED, FLASH_ALPHA * (_flash_left / maxf(session.combat_tuning_in_use().damage_flash_s, 0.001)))
	for i in _feed_labels.size():
		var label: Label = _feed_labels[i]
		if i < entries.size():
			var entry: Dictionary = entries[i]
			label.text = (FEED_FIRST % [entry.get("word", DEFAULT_WORD), entry["killer"]]) + "\n" + (FEED_SECOND % entry["victim"])
			var full: float = fade if fade > 0.0 else session.combat_tuning_in_use().kill_feed_fade_s
			label.modulate = Color(1, 1, 1, clampf(entry["left"] / minf(1.0, full), 0.0, 1.0))
			label.visible = true
		else:
			label.text = ""
			label.visible = false


func _build() -> void:
	_flash = ColorRect.new()
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(Palette.HOSTILE_RED, 0.0)
	_flash.visible = false
	add_child(_flash)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_border = PanelContainer.new()
	_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Palette.MINT
	style.set_border_width_all(BORDER_WIDTH)
	_border.add_theme_stylebox_override("panel", style)
	_border.visible = false
	add_child(_border)
	_border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_line = _label(self, 14, Palette.MINT)
	_line.position = Vector2(18.0, 92.0)
	_line.visible = false
	_banner = _label(self, 26, Palette.HOSTILE_AMBER)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.anchor_left = 0.0
	_banner.anchor_right = 1.0
	_banner.anchor_top = 0.38
	_banner.anchor_bottom = 0.38
	_banner.offset_left = 0.0
	_banner.offset_right = 0.0
	_banner.visible = false
	_feed = VBoxContainer.new()
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feed.alignment = BoxContainer.ALIGNMENT_END
	add_child(_feed)
	_feed.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 18)
	_feed.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_feed.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_feed.position.y -= FEED_BOTTOM_GAP
	for i in 20:
		var label := _label(_feed, FEED_FONT, Palette.HOSTILE_AMBER)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.visible = false
		_feed_labels.append(label)


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
