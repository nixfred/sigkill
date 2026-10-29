extends CanvasLayer
## Minimal terminal-style HUD, built in code. Every control ignores the mouse,
## so clicks always reach the player, except the Esc menu while it is open (C16b,
## scripts/hud/pause_menu.gd). The menu is the root's last child, so it sees unhandled
## input before every other part of the HUD and before the player. Over everything sits
## the colorblind-safe palette filter, shown while that setting is on. The top table (C23,
## scripts/hud/spectate_top.gd) sits over the rest while it is up, and gives way to the
## round's summary, the menu, the multiplayer panel and a text box. grep's marks (C25,
## scripts/hud/grep_marks.gd) draw round their targets, over the crosshair, while it is in hand. ICE's
## part (I1, scripts/hud/ice_hud.gd) sits over the rest, under the menu.

const Palette = preload("res://scripts/palette.gd")
const Crosshair = preload("res://scripts/crosshair.gd")
const HitMarker = preload("res://scripts/hit_marker.gd")
const GuideHud = preload("res://scripts/hud/guide_hud.gd")
const RoundHud = preload("res://scripts/round/round_hud.gd")
const NetHud = preload("res://scripts/net/net_hud.gd")
const CombatHud = preload("res://scripts/net/combat_hud.gd")
const WeaponHud = preload("res://scripts/hud/weapon_hud.gd")
const SudoBadge = preload("res://scripts/hud/sudo_badge.gd")
const GrepMarks = preload("res://scripts/hud/grep_marks.gd")
const SpectateTop = preload("res://scripts/hud/spectate_top.gd")
const PauseMenu = preload("res://scripts/hud/pause_menu.gd")
const IceHud = preload("res://scripts/hud/ice_hud.gd")
const BreakerHud = preload("res://scripts/hud/breaker_hud.gd")
const ColorblindShader = preload("res://shaders/colorblind_safe.gdshader")
## Above the HUD and the menu, so the filter recolours all of it.
const FILTER_LAYER := 100

const HINT := "WASD move   Mouse look   Space jump   LMB fire   R respawn   Esc menu   T ask AI   O AI on/off   M net"

var _status: Label
var _engage: Label
var _crosshair  # untyped on purpose: calls ping() from crosshair.gd
var _hit_marker  # untyped on purpose: calls show_hit() from hit_marker.gd
var _guide: GuideHud
var _round: RoundHud
var _net: NetHud
var _combat: CombatHud
var _weapons: WeaponHud
var _sudo: SudoBadge
var _grep: GrepMarks
var _top: SpectateTop
var _menu: PauseMenu
var _ice: IceHud
var _breakers: BreakerHud
var _filter: CanvasLayer
var _player: Node = null
var _marker_weapon: Resource = null


func _ready() -> void:
	var root := Control.new()
	root.name = "Root"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_crosshair = Crosshair.new()
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_crosshair)
	_crosshair.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_hit_marker = HitMarker.new()
	_hit_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hit_marker)
	_hit_marker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_grep = GrepMarks.new()
	_grep.name = "GrepMarks"
	root.add_child(_grep)

	_status = _make_label(root, 20)
	_status.text = "> daemons down: 0/0"
	_status.position = Vector2(18.0, 14.0)

	var hint := _make_label(root, 14)
	hint.text = HINT
	hint.modulate = Color(1.0, 1.0, 1.0, 0.7)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 14)

	_engage = _make_label(root, 28)
	_engage.text = "[ click to engage ]\n\nEsc: menu and settings"
	_engage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_engage.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_engage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_guide = GuideHud.new()
	_guide.name = "GuideHud"
	root.add_child(_guide)

	_round = RoundHud.new()
	_round.name = "RoundHud"
	_round.guide = _guide
	root.add_child(_round)

	_net = NetHud.new()
	_net.name = "NetHud"
	_net.guide = _guide
	_net.round_hud = _round
	root.add_child(_net)

	_combat = CombatHud.new()
	_combat.name = "CombatHud"
	_combat.hud = self
	root.add_child(_combat)

	_weapons = WeaponHud.new()
	_weapons.name = "WeaponHud"
	root.add_child(_weapons)

	_sudo = SudoBadge.new()
	_sudo.name = "SudoBadge"
	root.add_child(_sudo)

	_top = SpectateTop.new()
	_top.name = "SpectateTop"
	_top.round_hud = _round
	_top.combat_hud = _combat
	_top.hud = self
	root.add_child(_top)

	# ICEbreakers (I2): the loaded breaker and the counts bottom left over the sudo badge, an effect's line
	# under the crosshair, the cloak's edge wash.
	_breakers = BreakerHud.new()
	_breakers.name = "BreakerHud"
	_breakers.sudo_badge = _sudo.badge()
	root.add_child(_breakers)

	# ICE (I1): the hunter's adaptation, the credit tag, a jam's notice and a field's corruption, over
	# the rest of the HUD; the health line never covered.
	_ice = IceHud.new()
	_ice.name = "IceHud"
	root.add_child(_ice)
	var scrambled: Array[Control] = [_status, _round.round_label(), _weapons.strip(), _sudo.badge(), _combat.feed_box(), _breakers.box()]
	_ice.scrambled = scrambled
	_ice.health_line = _combat.line_label()
	_ice.weapon_strip = _weapons.strip()

	# Last, so it takes unhandled input first while it is open.
	_menu = PauseMenu.new()
	_menu.name = "PauseMenu"
	_menu.guide = _guide
	_menu.round_hud = _round
	_menu.net_hud = _net
	root.add_child(_menu)

	_filter = CanvasLayer.new()
	_filter.name = "ColorblindFilter"
	_filter.layer = FILTER_LAYER
	var cover := ColorRect.new()
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paint := ShaderMaterial.new()
	paint.shader = ColorblindShader
	cover.material = paint
	_filter.add_child(cover)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_filter)
	GameSettings.current().changed.connect(_on_setting_changed)
	_apply_filter()


func _process(_delta: float) -> void:
	# The hit marker takes the drawn weapon's sizes and timing.
	if _player != null and is_instance_valid(_player) and _player.has_method("weapon_tuning") and _player.weapon_tuning() != _marker_weapon:
		set_weapon_tuning(_player.weapon_tuning())
	# The break's summary panel takes the middle of the screen; a click still engages.
	_engage.visible = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not _guide.is_typing() and not _net.is_typing() and not _round.showing_summary() and not _net.is_open() and not _menu.is_open() and not _top.is_showing()


func set_targets(remaining: int, total: int) -> void:
	_guide.set_targets_left(remaining)
	var text := "> daemons down: %d/%d" % [total - remaining, total]
	if total > 0 and remaining <= 0:
		text += "   [clear] press R to respawn"
	_status.text = text


## The player, whose input the guide HUD blocks while its ask box is open, and whose
## shots, jumps, slides and steps each round counts, and whose weapons the strip shows.
func set_player(player: Node) -> void:
	_player = player
	_weapons.player = player
	_sudo.player = player
	_grep.player = player
	_top.player = player
	_guide.player = player
	_round.set_player(player)
	_net.player = player
	_menu.player = player
	_ice.player = player
	if player.has_signal("menu_requested"):
		player.menu_requested.connect(open_menu)


## This player's life alone (C27b): its health, the hit flash and the death banner on the combat
## HUD, its deaths in the round.
func set_solo_life(life: Node) -> void:
	_combat.set_life(life)
	_round.set_life(life)
	_top.set_life(life)


## The session beside the arena, for the multiplayer panel and the combat HUD.
func set_net_session(session: Node) -> void:
	_net.session = session
	_combat.set_session(session)
	_round.set_session(session)
	_menu.session = session
	_top.session = session


## ICE's director beside the arena (I1), for its part of the HUD.
func set_ice(ice: Node) -> void:
	_ice.ice = ice


func ice_hud() -> IceHud:
	return _ice


## The ICEbreakers' director beside the arena (I2), for its readout, and the guide's numbers for its
## breaker pick.
func set_breakers(breakers: Node) -> void:
	_breakers.director = breakers
	_guide.breakers = breakers
	_round.breakers = breakers


func breaker_hud() -> BreakerHud:
	return _breakers


func combat_hud() -> CombatHud:
	return _combat


func weapon_hud() -> WeaponHud:
	return _weapons


## Root vs user's prompt badge (C22).
func sudo_badge() -> SudoBadge:
	return _sudo


## grep's brackets and count (C25).
func grep_marks() -> GrepMarks:
	return _grep


## The top table (C23).
func spectate_top() -> SpectateTop:
	return _top


## True while something else has the screen and the top table stays hidden: the round's
## break summary, the menu, the multiplayer panel or a text box.
func top_held_back() -> bool:
	return _round.showing_summary() or _menu.is_open() or _net.is_open() or is_typing()


## The host confirmed a hit by this player: the C6 hit marker, nothing else.
func confirm_hit() -> void:
	_hit_marker.show_hit()


func net_hud() -> NetHud:
	return _net


func pause_menu() -> PauseMenu:
	return _menu


## Esc reached the player with nothing else open: the menu comes up.
func open_menu() -> void:
	if not is_typing():
		_menu.open()


## True while the colorblind-safe palette filter is drawn.
func colorblind_filter_on() -> bool:
	return _filter.visible


func _on_setting_changed(section: String, _key: String) -> void:
	if section == "hud" or section == "":
		_apply_filter()


func _apply_filter() -> void:
	_filter.visible = GameSettings.current().value("hud", "colorblind")


## The dummies a round counts downs of, and brings back when the next round starts.
func set_round_targets(targets: Array) -> void:
	_round.set_targets(targets)
	_top.set_targets(targets)  # alone, the top table's daemons (C23)


func round_hud() -> RoundHud:
	return _round


## A target went down: the guide HUD counts it for the game stats it may send.
func note_kill() -> void:
	_guide.note_kill()


## True while the guide HUD's ask box or the multiplayer panel's address box is open.
func is_typing() -> bool:
	return _guide.is_typing() or _net.is_typing()


func guide() -> GuideHud:
	return _guide


## Hit marker sizes and timing come from the drawn weapon's tuning.
func set_weapon_tuning(w: Resource) -> void:
	_marker_weapon = w
	_hit_marker.configure(w.hit_marker_seconds, w.hit_marker_size, w.hit_marker_gap, w.hit_marker_thickness)


## Every shot kicks the crosshair. Solo, a landed shot shows the hit marker; in a LAN
## match the marker is the host's word alone (confirm_hit), never the local cannon's
## guess, so a dummy hit on this machine's own copy of the arena shows none.
func on_shot(hit_target: bool) -> void:
	_crosshair.ping()
	if hit_target and not _online():
		_hit_marker.show_hit()


## True while the session beside the arena is hosting or joined.
func _online() -> bool:
	var session = _net.session
	return session != null and is_instance_valid(session) and session.is_online()


## 1 right after a hit, 0 once the hit marker has faded. Used by tests/cannon_test.gd.
func hit_marker_alpha() -> float:
	return _hit_marker.alpha()


func _make_label(parent: Control, font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", Palette.mono_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Palette.MINT)
	label.add_theme_color_override("font_outline_color", Palette.VOID)
	label.add_theme_constant_override("outline_size", 4)
	parent.add_child(label)
	return label
