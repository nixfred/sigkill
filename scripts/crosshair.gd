extends Control
## Crosshair drawn in code. Pops briefly (arms spread, colour brightens) when a shot lands.
## Its style and colour are settings (C16b): a cross, a dot, a circle or a cross with a dot,
## in one of palette.gd's crosshair colours.

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


func ping() -> void:
	_ping = PING_SECONDS
	set_process(true)


func _process(delta: float) -> void:
	_ping = maxf(_ping - delta, 0.0)
	if _ping <= 0.0:
		set_process(false)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
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
