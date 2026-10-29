extends Control
## Root vs user's prompt badge (C22), bottom left above the key hints: "user$" in the theme's
## mint as every life starts, "root#" in the hostile red while overcharged, with the root
## seconds left beside it; while a sudo charge is held, "sudo ready: Z" (the key as bound)
## beside "user$". As root starts, the badge shows the cosmetic
## "[sudo] password for user: ********" for a moment first. Fiction only: nothing is asked
## for, typed or checked, and "user" is a fixed word, never anyone's name. It reads the
## player's sudo node every frame and changes nothing.

const Palette = preload("res://scripts/palette.gd")
const Controls = preload("res://scripts/controls.gd")

const USER := "user$"
const ROOT := "root#"
const PASSWORD := "[sudo] password for user: ********"
const READY := "sudo ready: %s"
const LEFT := "%.0fs"
const FONT := 16
const SMALL_FONT := 12
const MARGIN := 14
## Room kept below the badge for the key hints.
const BOTTOM_GAP := 22

## The player whose sudo node to show.
var player: Node = null

var _row: HBoxContainer
var _prompt: Label
var _detail: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", 10)
	add_child(_row)
	_row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, MARGIN)
	_row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_row.position.y -= BOTTOM_GAP
	_prompt = _label(FONT, Palette.MINT)
	_detail = _label(SMALL_FONT, Palette.MINT)
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


## The badge itself (I1: an ICE field's HUD corruption scrambles it).
func badge() -> Control:
	return _row


## What the prompt says: "user$", "root#" or, just as root starts, the password line.
func prompt_text() -> String:
	return _prompt.text if _row.visible else ""


## What sits beside it: "sudo ready: Z", root's seconds left, or "".
func detail_text() -> String:
	return _detail.text if _row.visible and _detail.visible else ""


## The prompt's colour now: mint as user, root's red as root.
func prompt_color() -> Color:
	return _prompt.get_theme_color("font_color")


func _refresh() -> void:
	var sudo = player.get("sudo") if player != null and is_instance_valid(player) else null
	_row.visible = sudo != null and is_instance_valid(sudo) and sudo.state != null and player.get("alive") != false
	if not _row.visible:
		return
	var root: bool = sudo.is_root()
	if root and sudo.showing_password():
		_prompt.text = PASSWORD
		_detail.visible = false
	elif root:
		_prompt.text = ROOT
		_detail.text = LEFT % ceilf(sudo.root_left())
		_detail.visible = true
	else:
		_prompt.text = USER
		_detail.text = READY % Controls.bind_label(GameSettings.current().bind("sudo_overcharge"))
		_detail.visible = sudo.charges() > 0
	var color := Palette.HOSTILE_RED if root else Palette.MINT
	_prompt.add_theme_color_override("font_color", color)
	_detail.add_theme_color_override("font_color", color)


func _label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", Palette.mono_font())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Palette.VOID)
	label.add_theme_constant_override("outline_size", 4)
	_row.add_child(label)
	return label
