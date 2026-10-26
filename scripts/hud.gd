extends CanvasLayer
## Minimal terminal-style HUD, built in code. Every control ignores the mouse,
## so clicks always reach the player.

const Palette = preload("res://scripts/palette.gd")
const Crosshair = preload("res://scripts/crosshair.gd")
const HitMarker = preload("res://scripts/hit_marker.gd")
const GuideHud = preload("res://scripts/hud/guide_hud.gd")
const RoundHud = preload("res://scripts/round/round_hud.gd")

const HINT := "WASD move   Mouse look   Space jump   LMB fire   R respawn   Esc mouse   T ask AI   O AI on/off"

var _status: Label
var _engage: Label
var _crosshair  # untyped on purpose: calls ping() from crosshair.gd
var _hit_marker  # untyped on purpose: calls show_hit() from hit_marker.gd
var _guide: GuideHud
var _round: RoundHud


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

	_status = _make_label(root, 20)
	_status.text = "> daemons down: 0/0"
	_status.position = Vector2(18.0, 14.0)

	var hint := _make_label(root, 14)
	hint.text = HINT
	hint.modulate = Color(1.0, 1.0, 1.0, 0.7)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 14)

	_engage = _make_label(root, 28)
	_engage.text = "[ click to engage ]\n\nEsc releases the mouse"
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


func _process(_delta: float) -> void:
	# The break's summary panel takes the middle of the screen; a click still engages.
	_engage.visible = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not _guide.is_typing() and not _round.showing_summary()


func set_targets(remaining: int, total: int) -> void:
	_guide.set_targets_left(remaining)
	var text := "> daemons down: %d/%d" % [total - remaining, total]
	if total > 0 and remaining <= 0:
		text += "   [clear] press R to respawn"
	_status.text = text


## The player, whose input the guide HUD blocks while its ask box is open, and whose
## shots, jumps, slides and steps each round counts.
func set_player(player: Node) -> void:
	_guide.player = player
	_round.set_player(player)


## The dummies a round counts downs of, and brings back when the next round starts.
func set_round_targets(targets: Array) -> void:
	_round.set_targets(targets)


func round_hud() -> RoundHud:
	return _round


## A target went down: the guide HUD counts it for the game stats it may send.
func note_kill() -> void:
	_guide.note_kill()


## True while the guide HUD's ask box is open.
func is_typing() -> bool:
	return _guide.is_typing()


func guide() -> GuideHud:
	return _guide


## Hit marker sizes and timing come from the player's weapon tuning.
func set_weapon_tuning(w: Resource) -> void:
	_hit_marker.configure(w.hit_marker_seconds, w.hit_marker_size, w.hit_marker_gap, w.hit_marker_thickness)


## Every shot kicks the crosshair; only a landed shot shows the hit marker.
func on_shot(hit_target: bool) -> void:
	_crosshair.ping()
	if hit_target:
		_hit_marker.show_hit()


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
