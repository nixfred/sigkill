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
## The last shot's marker was a refusal (P2): a steel hexagon round the crosshair, not the four ticks.
var _blocked := false


func _ready() -> void:
	resized.connect(queue_redraw)
	set_process(false)


func configure(seconds: float, tick_px: float, gap_px: float, thickness_px: float) -> void:
	_seconds = seconds
	_tick = tick_px
	_gap = gap_px
	_thickness = thickness_px


func show_hit() -> void:
	_blocked = false
	_left = _seconds
	set_process(true)
	queue_redraw()


## A refused shot (P2): the shot met the target and took nothing off it, so it is not a hit: a steel hexagon, open at
## its sides, round the crosshair instead of the ticks.
func show_blocked() -> void:
	_blocked = true
	_left = _seconds
	set_process(true)
	queue_redraw()


## True while the marker up is a refusal's (the checks).
func blocked() -> bool:
	return _blocked and alpha() > 0.0


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
	if _blocked:
		var steel := Color(Palette.STEEL, a)
		var r := _gap + _tick * 0.6
		for i in 6:
			if i == 0 or i == 3:
				continue  # open at its sides: a guard, not a target
			var p0 := center + Vector2.from_angle(TAU * i / 6.0 - PI / 2.0) * r
			var p1 := center + Vector2.from_angle(TAU * (i + 1) / 6.0 - PI / 2.0) * r
			draw_line(p0, p1, steel, _thickness, true)
		return
	var col := Palette.FLASH
	col.a = a
	for d in DIAGONALS:
		var dir := (d as Vector2).normalized()
		draw_line(center + dir * _gap, center + dir * (_gap + _tick), col, _thickness, true)
