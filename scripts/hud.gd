extends CanvasLayer
## Minimal terminal-style HUD, built in code. Every control ignores the mouse,
## so clicks always reach the player.

const Palette = preload("res://scripts/palette.gd")
const Crosshair = preload("res://scripts/crosshair.gd")

const HINT := "WASD move   Mouse look   Space jump   LMB fire   R respawn targets   Esc release mouse"

var _status: Label
var _engage: Label
var _crosshair  # untyped on purpose: calls ping() from crosshair.gd


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


func _process(_delta: float) -> void:
	_engage.visible = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED


func set_targets(remaining: int, total: int) -> void:
	var text := "> daemons down: %d/%d" % [total - remaining, total]
	if total > 0 and remaining <= 0:
		text += "   [clear] press R to respawn"
	_status.text = text


func ping() -> void:
	_crosshair.ping()


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
