extends Control
## What synced combat (C14) shows this player: a line under the net line with their health,
## spawn protection or death and the respawn countdown; a kill feed at the bottom right,
## the last few kills in SIGKILL's words, naming the weapon's signal ("SIGKILL sent by
## Daemon-2" / "to Daemon-1" for the cannon, "SIGTERM sent by ..." for SIGTERM, C16), each
## fading out; a flash of hostile red when they are hit; a mint border while they are
## freshly spawned and safe; and a centred banner while they are dead. The hit marker for a
## confirmed hit is the C6 one, through hud.gd. Everything here follows the host's confirmed
## results, which arrive through the session's signals; nothing is guessed locally. While the
## top table (C23, scripts/hud/spectate_top.gd) is up the banner sits just below it as one
## smaller line. A player its own rm -rf blast killed (C26) reads "rm -rf: Daemon-2" /
## "removed themself", the weapon's self-kill words. A player's shot removing another's cron mine
## (C27) reads "crontab -r: Daemon-3" / "removed Daemon-2's job".
## Shown only while a session is online; solo play saw none of it until C27b. Now the daemons
## fight back, the player's life alone (scripts/fight/solo_life.gd) shows here the same way:
## the health line, the red flash and the mint border, and the death banner ("DEREZZED by
## rogue.d", the respawn counting down); in practice none of it, as before. Every hit also
## presses a hostile red vignette in from the screen's edges (alone or in a match), which stays
## faintly on, pulsing, while health is low; it is colour only, never a warp, and the hit's view
## jolt is the player's, only with screen shake on.

const Session = preload("res://scripts/net/net_session.gd")
const Palette = preload("res://scripts/palette.gd")

const HEALTH_LINE := "health %d"
const PROTECT_LINE := "   spawn protection %.1f s"
const DEAD_LINE := "DEREZZED by %s   respawn in %.1f s"
const BANNER := "[ DEREZZED by %s ]\n\nrespawn in %.1f s"
## The banner while the top table (C23) is up above it: one line, smaller, so it stays clear of
## the guide's panel below it and the kill feed beside it.
const BANNER_LINE := "[ DEREZZED by %s ]   respawn in %.1f s"
## A flatline (I3): touched by Black ICE, no respawn: alone the run is over, in a match out until the
## round ends (the host's).
const FLAT_LINE := "FLATLINED by %s   %s"
const FLAT_BANNER := "[ FLATLINED by %s ]\n\n%s"
const FLAT_BANNER_LINE := "[ FLATLINED by %s ]   %s"
const FLAT_SOLO := "the run is over"
const FLAT_MATCH := "out until the round ends"
const BANNER_FONT := 26
const BANNER_LINE_FONT := 18
const FEED_FIRST := "%s sent by %s"
## The cannon's signal: the feed's word when the weapon is not known.
const DEFAULT_WORD := "SIGKILL"
const FEED_SECOND := "to %s"
## A player its own weapon killed, for a weapon with self-kill words (C26): "rm -rf: Daemon-2" /
## "removed themself".
const FEED_SELF := "%s: %s"
## The second line of a cron mine's removal (C27): whose job it was.
const FEED_JOB := "removed %s's job"
const FEED_FONT := 13
## Room below the feed for the hint line and the weapon strip (C16); a row more for the strip's second
## bank (C29: 104 before). At 960x540 the strip's top is 88 px over its bottom gap, so 112 clears it by
## 2 px and keeps a full feed's top 3 px under the spectate table's last line.
const FEED_BOTTOM_GAP := 112
const FLASH_ALPHA := 0.28
## The vignette (C27b): its strength at a hit, under this share of health its low-health glow,
## and that glow's strength and pulse a second.
const VIGNETTE_HIT := 0.9
const LOW_SHARE := 0.35
const LOW_GLOW := 0.4
const LOW_PULSE_HZ := 0.9
const VignetteShader = preload("res://shaders/damage_vignette.gdshader")
## Who took this player alone, when the daemon has no name.
const SOMETHING := "a daemon"
## The death banner's place: this far down the screen, unless the top table is up above it.
const BANNER_ANCHOR := 0.38
const BORDER_WIDTH := 3

## The session whose results to show; set through set_session.
var session: Node = null
## This player's life alone (C27b); set through set_life.
var life: Node = null
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
var _vignette: ColorRect
var _vignette_paint: ShaderMaterial
var _vignette_clock := 0.0
var _border: PanelContainer
var _banner: Label
## Where the top table put the banner (its top, in pixels), or -1 for its own place.
var _banner_top := -1.0


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
	if s.has_signal("job_removed"):
		s.job_removed.connect(_on_job_removed)
	if s.has_signal("daemon_struck"):
		s.daemon_struck.connect(_on_daemon_struck)
	s.player_respawned.connect(_on_respawn)
	s.combat_changed.connect(_refresh)
	s.changed.connect(_refresh)


## This player's life alone (C27b): its hits flash, its health, death and respawn show here.
func set_life(l: Node) -> void:
	life = l
	if l != null and l.has_signal("hurt") and not l.is_connected("hurt", _on_life_hurt):
		l.connect("hurt", _on_life_hurt)


func _on_life_hurt(_amount: float, _health: float, _by: Node) -> void:
	_flash_left = life.tuning.damage_flash_s
	_refresh()


## How strong the vignette is now, 0 to 1 (C27b).
func vignette_strength() -> float:
	return _vignette_paint.get_shader_parameter("strength") if _vignette.visible else 0.0


## True while the life alone is the one shown (C27b): no match, the daemons fighting back.
func _solo() -> bool:
	return life != null and is_instance_valid(life) and life.shown()


func _exit_tree() -> void:
	_unhook()


## Takes this HUD off the session's signals; the session goes on without it.
func _unhook() -> void:
	if session == null or not is_instance_valid(session):
		return
	for pair in [["shot_confirmed", _on_shot], ["player_died", _on_death], ["player_respawned", _on_respawn], ["combat_changed", _refresh], ["changed", _refresh], ["job_removed", _on_job_removed], ["daemon_struck", _on_daemon_struck]]:
		if session.has_signal(pair[0]) and session.is_connected(pair[0], pair[1]):
			session.disconnect(pair[0], pair[1])


func _on_respawn(_id: int) -> void:
	_refresh()


func _process(delta: float) -> void:
	_vignette_clock = fmod(_vignette_clock + delta, 3600.0)
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


## Spectate as top (C23): with the top table up, the death banner sits `top` pixels from the
## screen's top, just below it, as one smaller line; a negative `top` puts it back in its own
## place and shape.
func place_banner(top: float) -> void:
	var at := top if top >= 0.0 else -1.0
	if at == _banner_top:
		return  # (not the anchors: they are kept as 32-bit floats, never equal to 0.38 here)
	_banner_top = at
	var anchor := 0.0 if top >= 0.0 else BANNER_ANCHOR
	var offset := top if top >= 0.0 else 0.0
	_banner.add_theme_font_size_override("font_size", BANNER_LINE_FONT if top >= 0.0 else BANNER_FONT)
	_banner.anchor_top = anchor  # each pushes the other side along, so both end at `anchor`
	_banner.anchor_bottom = anchor
	_banner.offset_top = offset
	_banner.offset_bottom = offset
	_refresh()  # its text in the new shape at once


## The death banner's rectangle on the screen (as wide as the screen; its text is centred).
func banner_rect() -> Rect2:
	return _banner.get_global_rect()


## The rectangle the banner's centred text takes on the screen, or an empty one while hidden.
func banner_text_rect() -> Rect2:
	if not _banner.visible:
		return Rect2()
	var font := _banner.get_theme_font("font")
	var size := _banner.get_theme_font_size("font_size")
	var wide := 0.0
	for line in _banner.text.split("\n"):
		wide = maxf(wide, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	var rect := _banner.get_global_rect()
	return Rect2(rect.position.x + (rect.size.x - wide) * 0.5, rect.position.y, wide, _banner.get_combined_minimum_size().y)


func line_text() -> String:
	return _line.text if _line.visible else ""


## The health line and the kill feed themselves (I1: an ICE field's HUD corruption scrambles the feed
## and never the health line).
func line_label() -> Label:
	return _line


func feed_box() -> Control:
	return _feed


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
	entries.push_front({"killer": _name(killer), "victim": _name(victim), "word": word if word != "" else DEFAULT_WORD, "self": session.last_kill_self.get(victim, "") if killer == victim else "", "left": session.combat_tuning_in_use().kill_feed_fade_s})
	while entries.size() > session.combat_tuning_in_use().kill_feed_length:
		entries.pop_back()
	_refresh()


## The host says this player's shot struck one of its daemons (C27b): the C6 hit marker.
func _on_daemon_struck(_index: int, _killed: bool) -> void:
	if hud != null and is_instance_valid(hud):
		hud.confirm_hit()


## A player's shot removed another player's cron mine (C27): a feed line, as a kill's.
func _on_job_removed(remover: int, owner: int, word: String) -> void:
	if session == null:
		return
	entries.push_front({"killer": _name(remover), "victim": _name(owner), "word": word, "self": FEED_JOB % _name(owner), "left": session.combat_tuning_in_use().kill_feed_fade_s})
	while entries.size() > session.combat_tuning_in_use().kill_feed_length:
		entries.pop_back()
	_refresh()


func _name(id: int) -> String:
	return session.players.get(id, {}).get("name", "Daemon-?")


func _refresh(fade: float = -1.0) -> void:
	if _line == null:
		return
	var online: bool = session != null and is_instance_valid(session) and session.is_online()
	var solo := not online and _solo()
	_line.visible = online or solo
	_flash.visible = (online or solo) and _flash_left > 0.0
	if solo:
		_refresh_solo()
		return
	if not online:
		# The match is over: nothing of it carries into the next one. (A player merely
		# leaving keeps the session online, and the feed with it.)
		entries.clear()
		_flash_left = 0.0
		_border.visible = false
		_banner.visible = false
		_vignette.visible = false
		for label in _feed_labels:
			label.visible = false
		return
	var me: int = session.my_id
	var dead: bool = session.dead.get(me, false)
	var protect: float = session.protect_left.get(me, 0.0)
	if dead and session.has_method("flatlined") and session.flatlined(me):
		var cause: String = session.last_killer_name.get(me, IceDirector.BLACK_NAME)
		_line.text = FLAT_LINE % [cause, FLAT_MATCH]
		_banner.text = (FLAT_BANNER_LINE if _banner_top >= 0.0 else FLAT_BANNER) % [cause, FLAT_MATCH]
	elif dead:
		var killer: String = session.last_killer_name.get(me, _name(session.last_killer.get(me, 0)))
		var left: float = session.respawn_left.get(me, 0.0)
		_line.text = DEAD_LINE % [killer, left]
		_banner.text = (BANNER_LINE if _banner_top >= 0.0 else BANNER) % [killer, left]
	else:
		_line.text = HEALTH_LINE % roundi(session.health.get(me, 0.0)) + (PROTECT_LINE % protect if protect > 0.0 else "")
	_line.add_theme_color_override("font_color", Palette.HOSTILE_AMBER if dead else Palette.MINT)
	_banner.visible = dead
	_border.visible = not dead and protect > 0.0
	_flash.color = Color(Palette.HOSTILE_RED, FLASH_ALPHA * (_flash_left / maxf(session.combat_tuning_in_use().damage_flash_s, 0.001)))
	_set_vignette(_flash_left / maxf(session.combat_tuning_in_use().damage_flash_s, 0.001), 0.0 if dead else session.health.get(me, 0.0) / maxf(session.combat_tuning_in_use().max_health, 1.0))
	for i in _feed_labels.size():
		var label: Label = _feed_labels[i]
		if i < entries.size():
			var entry: Dictionary = entries[i]
			if entry.get("self", "") != "":
				label.text = (FEED_SELF % [entry.get("word", DEFAULT_WORD), entry["killer"]]) + "\n" + entry["self"]
			else:
				label.text = (FEED_FIRST % [entry.get("word", DEFAULT_WORD), entry["killer"]]) + "\n" + (FEED_SECOND % entry["victim"])
			var full: float = fade if fade > 0.0 else session.combat_tuning_in_use().kill_feed_fade_s
			label.modulate = Color(1, 1, 1, clampf(entry["left"] / minf(1.0, full), 0.0, 1.0))
			label.visible = true
		else:
			label.text = ""
			label.visible = false


## True while the round's summary shows a flatline's loss (I3): the death banner gives it the screen.
func _loss_shown() -> bool:
	if hud == null or not is_instance_valid(hud) or not hud.has_method("round_hud"):
		return false
	var round = hud.round_hud()
	return round != null and round.get("lost") == true and round.showing_summary()


## The life alone (C27b): the health line or the death line and banner, the flash, the border.
func _refresh_solo() -> void:
	entries.clear()
	for label in _feed_labels:
		label.visible = false
	var dead: bool = not life.alive()
	var protect: float = life.protect_left()
	if dead and life.get("flatlined_now") == true:
		# Alone a flatline ends the run: the loss summary says so, and the banner gives it the screen.
		var cause: String = life.cause if life.cause != "" else IceDirector.BLACK_NAME
		_line.text = FLAT_LINE % [cause, FLAT_SOLO]
		_banner.text = (FLAT_BANNER_LINE if _banner_top >= 0.0 else FLAT_BANNER) % [cause, FLAT_SOLO]
	elif dead:
		var killer: String = life.cause if life.cause != "" else SOMETHING
		var left: float = life.respawn_left()
		_line.text = DEAD_LINE % [killer, left]
		_banner.text = (BANNER_LINE if _banner_top >= 0.0 else BANNER) % [killer, left]
	else:
		_line.text = HEALTH_LINE % roundi(life.health()) + (PROTECT_LINE % protect if protect > 0.0 else "")
	_line.add_theme_color_override("font_color", Palette.HOSTILE_AMBER if dead else Palette.MINT)
	_banner.visible = dead and not _loss_shown()
	_border.visible = not dead and protect > 0.0
	var flash_s: float = maxf(life.tuning.damage_flash_s, 0.001)
	_flash.color = Color(Palette.HOSTILE_RED, FLASH_ALPHA * (_flash_left / flash_s))
	_set_vignette(_flash_left / flash_s, 0.0 if dead else life.health() / maxf(life.max_health(), 1.0))


## The vignette from `hit` (the flash's share left, 0 to 1) and `share` (health left, 0 to 1; 0
## while dead, when nothing glows).
func _set_vignette(hit: float, share: float) -> void:
	var low := 0.0
	if share > 0.0 and share < LOW_SHARE:
		low = LOW_GLOW * (1.0 - share / LOW_SHARE) * (0.75 + 0.25 * sin(TAU * LOW_PULSE_HZ * _vignette_clock))
	var strength := maxf(VIGNETTE_HIT * clampf(hit, 0.0, 1.0), low)
	_vignette.visible = strength > 0.0
	_vignette_paint.set_shader_parameter("strength", strength)


func _build() -> void:
	_vignette_paint = ShaderMaterial.new()
	_vignette_paint.shader = VignetteShader
	_vignette_paint.set_shader_parameter("color", Palette.HOSTILE_RED)
	_vignette = ColorRect.new()
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.material = _vignette_paint
	_vignette.visible = false
	add_child(_vignette)
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	_banner = _label(self, BANNER_FONT, Palette.HOSTILE_AMBER)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.anchor_left = 0.0
	_banner.anchor_right = 1.0
	_banner.anchor_top = BANNER_ANCHOR
	_banner.anchor_bottom = BANNER_ANCHOR
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
