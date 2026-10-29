extends Control
## Crosshair drawn in code. Pops briefly (arms spread, colour brightens) when a shot lands.
## Its style and colour are settings (C16b): a cross, a dot, a circle or a cross with a dot,
## in one of palette.gd's crosshair colours.
## SIGHUP (C32): while the player is confused the HUD drifts it off the middle (set_drift()); the aim never
## moves, so a faint dot stays at the true middle the whole time.

const Palette = preload("res://scripts/palette.gd")
const DOT := 1.6
const BIG_DOT := 2.6
const RING := 8.0

const GAP := 6.0
const ARM := 9.0
const PING_SECONDS := 0.15

var _ping := 0.0


var _style := "cross"
var _color: Color = Palette.MINT
## SIGHUP's drift (C32): pixels off the middle the crosshair is drawn now.
var _drift := Vector2.ZERO
## The true middle's faint dot while it drifts.
const TRUE_DOT := 1.4
const TRUE_ALPHA := 0.4


func _ready() -> void:
	resized.connect(queue_redraw)
	set_process(false)
	GameSettings.current().changed.connect(_on_setting_changed)
	_on_setting_changed("hud", "")


## The style and colour drawn now, for tests.
func look() -> Array:
	return [_style, _color]


func _on_setting_changed(section: String, _key: String) -> void:
	if section != "hud" and section != "":
		return
	var s := GameSettings.current()
	_style = s.value("hud", "crosshair_style")
	_color = Palette.CROSSHAIR.get(s.value("hud", "crosshair_color"), Palette.MINT)
	queue_redraw()


## SIGHUP (C32): draw it `offset` pixels off the middle (ZERO: back on it). The aim is never touched.
func set_drift(offset: Vector2) -> void:
	if offset != _drift:
		_drift = offset
		queue_redraw()


## Pixels off the middle it is drawn now (C32).
func drift() -> Vector2:
	return _drift


func ping() -> void:
	_ping = PING_SECONDS
	set_process(true)


func _process(delta: float) -> void:
	_ping = maxf(_ping - delta, 0.0)
	if _ping <= 0.0:
		set_process(false)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5 + _drift
	if _drift != Vector2.ZERO:
		draw_circle(size * 0.5, TRUE_DOT, Color(_color, TRUE_ALPHA))  # the aim, where it always is
	var t := _ping / PING_SECONDS
	var col := _color.lerp(Palette.FLASH, t)
	var inner := GAP + 5.0 * t
	var outer := inner + ARM
	if _style == "cross" or _style == "cross_dot":
		draw_line(center + Vector2(inner, 0.0), center + Vector2(outer, 0.0), col, 2.0)
		draw_line(center - Vector2(inner, 0.0), center - Vector2(outer, 0.0), col, 2.0)
		draw_line(center + Vector2(0.0, inner), center + Vector2(0.0, outer), col, 2.0)
		draw_line(center - Vector2(0.0, inner), center - Vector2(0.0, outer), col, 2.0)
	if _style == "circle":
		draw_arc(center, RING + 4.0 * t, 0.0, TAU, 32, col, 2.0, true)
	draw_circle(center, (BIG_DOT if _style == "dot" or _style == "cross_dot" else DOT) + t, col)
