extends Control
## /dev/null on the HUD (C31). While this player's hole is open, just over the crosshair (34 px up: under it
## pipe |'s chain and chmod's line have their place, and a chain fired into the knot reads at the same
## time), what it does, as the command it is: "$ cat * > /dev/null  3 held  1 discarded"; Black ICE in its
## reach adds its refusal, "/dev/null: device busy". It fades over FADE_S once the hole has imploded. When
## another player's hole drags this player (a match), the edges wash plum and the line reads
## "> /dev/null: pulling you in  RUN". In the hole's text colour.
##
## Visual only: it reads the player (its last hole, the drag on it) every frame and changes nothing.

const Palette = preload("res://scripts/palette.gd")
const VignetteShader = preload("res://shaders/damage_vignette.gdshader")

const HELD_LINE := "$ cat * > /dev/null  %d held  %d discarded"
const BUSY_LINE := "/dev/null: device busy"
const PULLED_LINE := "> /dev/null: pulling you in  RUN"
## Over the crosshair, pixels.
const LINE_RISE := 34.0
const LINE_FONT := 17
const SMALL_FONT := 13
## How long the readout stays after the implosion, fading.
const FADE_S := 0.8
## The edges' wash at the hardest drag.
const PULL_WASH := 0.45

## The player whose hole to show.
var player: Node = null

var _line: Label
var _small: Label
var _wash: ColorRect
var _wash_paint: ShaderMaterial
var _after := INF
var _last_text := ""


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
	_line = _label(LINE_FONT)
	_small = _label(SMALL_FONT)


func _process(delta: float) -> void:
	_refresh(delta)


## The readout's two lines now ("" when none), for the checks.
func line_text() -> String:
	return _line.text if _line.visible else ""


func small_text() -> String:
	return _small.text if _small.visible else ""


## The edges' wash now (0 none).
func wash() -> float:
	return float(_wash_paint.get_shader_parameter("strength")) if _wash.visible else 0.0


func _refresh(delta: float) -> void:
	_line.visible = false
	_small.visible = false
	_wash.visible = false
	var p := player
	if p == null or not is_instance_valid(p) or p.get("alive") != true:
		return
	var text := ""
	var small := ""
	var drag = p.get("hole_drag")
	if drag is Vector3 and not (drag as Vector3).is_zero_approx():
		var tuning: Resource = _hole_tuning(p)
		var cap: float = tuning.player_pull_cap if tuning != null else 4.0
		_wash.visible = true
		_wash_paint.set_shader_parameter("strength", PULL_WASH * clampf((drag as Vector3).length() / maxf(cap, 0.01), 0.2, 1.0))
		text = PULLED_LINE
	else:
		var hole = p.get("last_hole")
		if hole != null and is_instance_valid(hole) and hole.has_method("is_open") and hole.is_open():
			text = HELD_LINE % [hole.held_now(), hole.discards]
			small = BUSY_LINE if hole.black_refused else ""
			_after = 0.0
			_last_text = text
		elif _after < FADE_S:
			_after += delta
			text = _last_text
	if text == "":
		return
	var alpha := 1.0 - clampf(_after / FADE_S, 0.0, 1.0) if text == _last_text and not _holding(p) else 1.0
	_show(_line, text, size.y * 0.5 - LINE_RISE - LINE_FONT, alpha)
	if small != "":
		_show(_small, small, size.y * 0.5 - LINE_RISE - LINE_FONT - SMALL_FONT - 6.0, alpha)


func _holding(p: Node) -> bool:
	var hole = p.get("last_hole")
	return hole != null and is_instance_valid(hole) and hole.has_method("is_open") and hole.is_open()


func _show(label: Label, text: String, top: float, alpha: float) -> void:
	label.text = text
	label.size = label.get_minimum_size()
	label.position = Vector2((size.x - label.size.x) * 0.5, top)
	label.modulate.a = alpha
	label.visible = true


## The loadout's /dev/null numbers, for the drag's strength on the wash.
func _hole_tuning(p: Node) -> Resource:
	var inv = p.get("inventory")
	if inv == null:
		return null
	for def in inv.defs:
		if def.is_hole():
			return def.hole_tuning()
	return null


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", Palette.mono_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Palette.DEV_NULL_TEXT)
	label.add_theme_color_override("font_outline_color", Palette.VOID)
	label.add_theme_constant_override("outline_size", 4)
	label.visible = false
	add_child(label)
	return label
