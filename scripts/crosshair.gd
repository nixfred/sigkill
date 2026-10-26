extends Control
## Crosshair drawn in code. Pops briefly (arms spread, colour brightens) when a shot lands.

const Palette = preload("res://scripts/palette.gd")

const GAP := 6.0
const ARM := 9.0
const PING_SECONDS := 0.15

var _ping := 0.0


func _ready() -> void:
	resized.connect(queue_redraw)
	set_process(false)


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
	var col := Palette.MINT.lerp(Palette.FLASH, t)
	var inner := GAP + 5.0 * t
	var outer := inner + ARM
	draw_line(center + Vector2(inner, 0.0), center + Vector2(outer, 0.0), col, 2.0)
	draw_line(center - Vector2(inner, 0.0), center - Vector2(outer, 0.0), col, 2.0)
	draw_line(center + Vector2(0.0, inner), center + Vector2(0.0, outer), col, 2.0)
	draw_line(center - Vector2(0.0, inner), center - Vector2(0.0, outer), col, 2.0)
	draw_circle(center, 1.6, col)
