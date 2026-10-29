extends Control
## chmod 000 on the HUD (C29). While this player's freeze beam runs, one line just under the crosshair (in
## grep's place, 26 px down: the two are never in hand together, and the breakers' effect lines stay
## under it) says what the beam is doing to what it meets, in the frost's text colour: "chmod 000
## rogue.d [######....]" as its freeze meter fills, "PERMISSION DENIED  rogue.d  2.4s" once frozen,
## "chmod: Operation not permitted  Black ICE -38%" (it only slows), "chmod: read-only file system" on a
## wall of white ICE (walls ignore it), "chmod: thawing, retry in 0.9s" while a thawed target's guard
## holds, and "coolant venting" when the tank has run dry.
##
## In a match the beam can be on this player too: its screen's edges frost over in the frost opal as its
## meter fills (the host's word), and frozen a line in the middle says so, "chmod 000: Permission
## denied" over "you are read-only  0.6s", the edges whole.
##
## Visual only: it reads the player (its beam, what it met, its own meter) every frame and changes nothing.

const Palette = preload("res://scripts/palette.gd")
const VignetteShader = preload("res://shaders/damage_vignette.gdshader")

const METER_LINE := "chmod 000  %s [%s%s]"
const DENIED_LINE := "PERMISSION DENIED  %s  %.1fs"
const BLACK_LINE := "chmod: Operation not permitted  Black ICE -%d%%"
const WALL_LINE := "chmod: read-only file system"
const GUARD_LINE := "chmod: thawing, retry in %.1fs"
const VENT_LINE := "coolant venting"
const ME_TITLE := "chmod 000: Permission denied"
const ME_LINE := "you are read-only  %.1fs"
const BAR_FULL := "#"
const BAR_EMPTY := "."
const BAR_CELLS := 10
## Under the crosshair, pixels: grep's count line's place.
const LINE_DROP := 26.0
const LINE_FONT := 14
const TITLE_FONT := 26
## The edges' frost at a full meter and frozen, and how wide.
const CHILL_WASH := 0.45
const FROZEN_WASH := 0.85
## The frozen lines' place, a share of the screen's height.
const ME_TOP := 0.34

## The player whose beam and meter to show.
var player: Node = null

var _line: Label
var _title: Label
var _me: Label
var _wash: ColorRect
var _wash_paint: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wash = ColorRect.new()
	_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wash_paint = ShaderMaterial.new()
	_wash_paint.shader = VignetteShader
	_wash_paint.set_shader_parameter("color", Palette.FROST)
	_wash.material = _wash_paint
	_wash.visible = false
	add_child(_wash)
	_wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_line = _label(LINE_FONT)
	_title = _label(TITLE_FONT)
	_me = _label(LINE_FONT)


func _process(_delta: float) -> void:
	_refresh()


## The line under the crosshair now ("" when none), for the checks.
func line_text() -> String:
	return _line.text if _line.visible else ""


## The frozen lines in the middle now (empty when not frozen).
func frozen_text() -> PackedStringArray:
	return PackedStringArray([_title.text, _me.text]) if _title.visible else PackedStringArray()


## The edges' frost now (0 none).
func wash() -> float:
	return float(_wash_paint.get_shader_parameter("strength")) if _wash.visible else 0.0


func _refresh() -> void:
	var p := player
	var up: bool = p != null and is_instance_valid(p) and p.get("alive") == true
	_line.visible = false
	_title.visible = false
	_me.visible = false
	_wash.visible = false
	if not up:
		return
	_line.text = _beam_line(p)
	_line.visible = _line.text != ""
	if _line.visible:
		_line.position = Vector2((size.x - _line.get_minimum_size().x) * 0.5, size.y * 0.5 + LINE_DROP)
	var frost = p.get("frost")
	if frost == null:
		return
	var frozen: bool = frost.frozen()
	var meter: float = frost.shown()
	if meter > 0.001:
		_wash.visible = true
		_wash_paint.set_shader_parameter("strength", FROZEN_WASH if frozen else CHILL_WASH * meter)
	if frozen:
		_title.text = ME_TITLE
		_me.text = ME_LINE % maxf(frost.frozen_left, 0.0)
		_title.visible = true
		_me.visible = true
		var top := size.y * ME_TOP
		_title.position = Vector2((size.x - _title.get_minimum_size().x) * 0.5, top)
		_me.position = Vector2((size.x - _me.get_minimum_size().x) * 0.5, top + TITLE_FONT + 8.0)


## What the beam is doing to what it meets, or "" while it is not running.
func _beam_line(p: Node) -> String:
	var def = p.weapon_tuning() if p.has_method("weapon_tuning") else null
	if def == null or not def.is_freeze():
		return ""
	var inv = p.get("inventory")
	var tank = inv.coolant(inv.current) if inv != null else null
	if tank != null and tank.venting and (p.get("_fire_held") == true or p.get("hold_fire") == true):
		return VENT_LINE
	if not p.has_method("beaming") or not p.beaming():
		return ""
	var target = p.get("beam_target")
	if target == null or not is_instance_valid(target):
		return ""
	if target.has_meta("player_id"):
		target = target.get_parent()  # an avatar's hit volume: the avatar holds the host's word
	if target is BlackIce:
		return BLACK_LINE % roundi((target as BlackIce).slow * 100.0)
	if target is IceBarrier:
		return WALL_LINE
	var frost = target.get("frost")
	if frost == null:
		return ""
	var who := _name_of(target)
	if frost.frozen():
		return DENIED_LINE % [who, maxf(frost.frozen_left, 0.0)]
	if frost.guard_left > 0.0:
		return GUARD_LINE % frost.guard_left
	var cells := clampi(roundi(frost.chill * BAR_CELLS), 0, BAR_CELLS)
	return METER_LINE % [who, BAR_FULL.repeat(cells), BAR_EMPTY.repeat(BAR_CELLS - cells)]


## A target's name as the HUD gives it: a daemon's tag, a piece of ICE's, a player's.
static func _name_of(target: Node) -> String:
	var tag = target.get("tag_text")
	if tag is String and tag != "":
		return tag
	var who = target.get("player_name")
	return who if who is String else "target"


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", Palette.mono_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Palette.FROST_TEXT)
	label.add_theme_color_override("font_outline_color", Palette.VOID)
	label.add_theme_constant_override("outline_size", 4)
	label.visible = false
	add_child(label)
	return label
