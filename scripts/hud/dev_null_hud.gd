extends Control
## /dev/null on the HUD (C31), for the player another player's hole drags (a match): the screen's edges washed
## plum, harder the harder it pulls, and over the crosshair (34 px up: under it pipe |'s chain and chmod's line
## have their place) "> /dev/null: pulling you in  RUN". A hole's thrower reads its own hole on the hole
## itself, its tag over the core (scripts/weapons/dev_null_look.gd); the strip shows its charges.
##
## Visual only: it reads the player (the drag on it) every frame and changes nothing.

const Palette = preload("res://scripts/palette.gd")
const VignetteShader = preload("res://shaders/damage_vignette.gdshader")

const PULLED_LINE := "> /dev/null: pulling you in  RUN"
## Over the crosshair, pixels.
const LINE_RISE := 34.0
const LINE_FONT := 17
## The edges' wash at the hardest drag, and the least while any drags.
const PULL_WASH := 0.45
const WASH_FLOOR := 0.2

## The player whose drag to show.
var player: Node = null

var _line: Label
var _wash: ColorRect
var _wash_paint: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wash = ColorRect.new()
	_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wash_paint = ShaderMaterial.new()
	_wash_paint.shader = VignetteShader
	_wash_paint.set_shader_parameter("color", Palette.DEV_NULL)
	_wash.material = _wash_paint
	_wash.visible = false
	add_child(_wash)
	_wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_line = Label.new()
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line.add_theme_font_override("font", Palette.mono_font())
	_line.add_theme_font_size_override("font_size", LINE_FONT)
	_line.add_theme_color_override("font_color", Palette.DEV_NULL_TEXT)
	_line.add_theme_color_override("font_outline_color", Palette.VOID)
	_line.add_theme_constant_override("outline_size", 4)
	_line.text = PULLED_LINE
	_line.visible = false
	add_child(_line)


func _process(_delta: float) -> void:
	_refresh()


## The warning now ("" when none), for the checks.
func line_text() -> String:
	return _line.text if _line.visible else ""


## The edges' wash now (0 none).
func wash() -> float:
	return float(_wash_paint.get_shader_parameter("strength")) if _wash.visible else 0.0


func _refresh() -> void:
	_line.visible = false
	_wash.visible = false
	var p := player
	if p == null or not is_instance_valid(p) or p.get("alive") != true:
		return
	var drag = p.get("hole_drag")
	if not (drag is Vector3) or (drag as Vector3).is_zero_approx():
		return
	var tuning: Resource = _hole_tuning(p)
	var cap: float = tuning.player_pull_cap if tuning != null else 4.0
	_wash.visible = true
	_wash_paint.set_shader_parameter("strength", PULL_WASH * clampf((drag as Vector3).length() / maxf(cap, 0.01), WASH_FLOOR, 1.0))
	_line.size = _line.get_minimum_size()
	_line.position = Vector2((size.x - _line.size.x) * 0.5, size.y * 0.5 - LINE_RISE - LINE_FONT)
	_line.visible = true


## The loadout's /dev/null numbers, for the drag's strength on the wash.
func _hole_tuning(p: Node) -> Resource:
	var inv = p.get("inventory")
	if inv == null:
		return null
	for def in inv.defs:
		if def.is_hole():
			return def.hole_tuning()
	return null
