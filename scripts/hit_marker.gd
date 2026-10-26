extends Control
## Hit marker: four short diagonal ticks around the crosshair, shown only when a shot
## lands and faded out over its lifetime. A miss never shows it, so a hit is unmistakable.
## Timing and sizes come from the weapon tuning, passed in through hud.gd.

const Palette = preload("res://scripts/palette.gd")
const DIAGONALS := [Vector2(1.0, 1.0), Vector2(-1.0, 1.0), Vector2(1.0, -1.0), Vector2(-1.0, -1.0)]

var _seconds := 0.0
var _tick := 0.0
var _gap := 0.0
var _thickness := 0.0
var _left := 0.0


func _ready() -> void:
	resized.connect(queue_redraw)
	set_process(false)


func configure(seconds: float, tick_px: float, gap_px: float, thickness_px: float) -> void:
	_seconds = seconds
	_tick = tick_px
	_gap = gap_px
	_thickness = thickness_px


func show_hit() -> void:
	_left = _seconds
	set_process(true)
	queue_redraw()


## 1 right after a hit, falling to 0 as it fades.
func alpha() -> float:
	if _seconds <= 0.0:
		return 0.0
	return clampf(_left / _seconds, 0.0, 1.0)


func _process(delta: float) -> void:
	_left = maxf(_left - delta, 0.0)
	if _left <= 0.0:
		set_process(false)
	queue_redraw()


func _draw() -> void:
	var a := alpha()
	if a <= 0.0:
		return
	var center := size * 0.5
	var col := Palette.FLASH
	col.a = a
	for d in DIAGONALS:
		var dir := (d as Vector2).normalized()
		draw_line(center + dir * _gap, center + dir * (_gap + _tick), col, _thickness, true)
