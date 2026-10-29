extends Control
## SIGHUP on the HUD (C32), for the player another player's SIGHUP caught (a match): for a couple of seconds
## its screen is confused, and only what is drawn: the HUD's glass glitching (shaders/sighup_glitch.gdshader:
## rows of carrier-green static tearing across, scanlines rolling at the edges), the crosshair as drawn
## drifting off the middle on a slow wander (a faint dot stays at the true middle: the aim never moves),
## "SIGHUP: hung up  NO CARRIER" over the crosshair (58 px up: /dev/null's warning has 34, chmod's and pipe |'s
## lines are under it), and the AI link's badge hung up (scripts/hud/guide_hud.gd). It eases out over its
## last third. Nothing is inverted, slowed or taken away: every control works as before. The thrower reads
## its own burst on the burst itself (its tag, scripts/weapons/sighup_look.gd); the strip shows its charges.
##
## Visual only: it reads the player (hup_amount(), its drift) every frame and changes nothing but drawing.

const Palette = preload("res://scripts/palette.gd")
const GlitchShader = preload("res://shaders/sighup_glitch.gdshader")

const HUNG_LINE := "SIGHUP: hung up  NO CARRIER"
## Over the crosshair, pixels.
const LINE_RISE := 58.0
const LINE_FONT := 17
## The drift's wander: its two rates, so it never repeats a path.
const DRIFT_HZ := Vector2(0.53, 0.41)
## The line's flicker.
const FLICKER_HZ := 8.0

## The player whose confusion to show, and the crosshair to drift.
var player: Node = null
var crosshair: Node = null

var _line: Label
var _glitch: ColorRect
var _glitch_paint: ShaderMaterial
var _clock := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glitch = ColorRect.new()
	_glitch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glitch_paint = ShaderMaterial.new()
	_glitch_paint.shader = GlitchShader
	_glitch_paint.set_shader_parameter("color", Palette.SIGHUP)
	_glitch.material = _glitch_paint
	_glitch.visible = false
	add_child(_glitch)
	_glitch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_line = Label.new()
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line.add_theme_font_override("font", Palette.mono_font())
	_line.add_theme_font_size_override("font_size", LINE_FONT)
	_line.add_theme_color_override("font_color", Palette.SIGHUP_TEXT)
	_line.add_theme_color_override("font_outline_color", Palette.VOID)
	_line.add_theme_constant_override("outline_size", 4)
	_line.text = HUNG_LINE
	_line.visible = false
	add_child(_line)


func _process(delta: float) -> void:
	_clock = fmod(_clock + delta, 3600.0)
	_refresh()


## The line now ("" when none), for the checks.
func line_text() -> String:
	return _line.text if _line.visible else ""


## The glitch's strength now (0 none).
func glitch() -> float:
	return float(_glitch_paint.get_shader_parameter("strength")) if _glitch.visible else 0.0


func _refresh() -> void:
	var amount := 0.0
	var p := player
	if p != null and is_instance_valid(p) and p.get("alive") == true and p.has_method("hup_amount"):
		amount = p.hup_amount()
	_glitch.visible = amount > 0.0
	_line.visible = amount > 0.0
	if crosshair != null and is_instance_valid(crosshair) and crosshair.has_method("set_drift"):
		var reach: float = float(p.get("hup_drift_px")) if amount > 0.0 else 0.0
		var wander := Vector2(sin(TAU * DRIFT_HZ.x * _clock) + 0.4 * sin(TAU * 1.7 * _clock), sin(TAU * DRIFT_HZ.y * _clock + 1.3) + 0.4 * sin(TAU * 2.3 * _clock)) / 1.4
		crosshair.set_drift((wander * reach * amount).round() if amount > 0.0 else Vector2.ZERO)
	if amount <= 0.0:
		return
	_glitch_paint.set_shader_parameter("strength", amount)
	_glitch_paint.set_shader_parameter("clock", _clock)
	_line.size = _line.get_minimum_size()
	_line.position = Vector2((size.x - _line.size.x) * 0.5, size.y * 0.5 - LINE_RISE - LINE_FONT)
	_line.modulate.a = 0.45 if fmod(_clock * FLICKER_HZ, 1.0) < 0.2 else 1.0
