class_name ProcHuntHud
extends CanvasLayer
## The process hunt's HUD (W1): a panel where a mission's would stand, a live `top` of the arena's enemies (the hottest
## first, the boss in its heat), what its table is (the demo's, or the player's machine read only), the counts, and the
## last few things the table did (a fork, an exit, a kill, a reap, a pegged core), each kill marked simulated; and, when a
## core is pegged, a banner across the top for a few seconds (the boss is an event). Under the HUD's own layer, so the
## Esc menu covers it. Draws only what the hunt says; reads nothing.

const Palette = preload("res://scripts/palette.gd")
const PANEL_AT := Vector2(16, 98)
const PANEL_W := 372.0
const ROWS := 6
## Below this viewport width the panel is compact: fewer rows and lines, so a small window keeps its view.
const COMPACT_W := 1280.0
const ROWS_COMPACT := 3
const LINES_COMPACT := 2
const LINE := 17.0
const BANNER_S := 3.2
const ALPHA := 0.8
const TITLE := "PROCESS HUNT"
const DEMO := "demo table"
const REAL := "your machine, read only"
const NOTE := "kills are simulated: nothing real is signaled"

var hunt: ProcHunt = null

var _view: Control
var _font: Font
var _banner := ""
var _banner_at := -100.0


func _ready() -> void:
	layer = 0
	_font = Palette.mono_font()
	_view = Control.new()
	_view.name = "ProcHuntView"
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.draw.connect(_draw_view)
	add_child(_view)
	if hunt != null:
		hunt.event.connect(_on_event)


func _process(_delta: float) -> void:
	_view.queue_redraw()


func _on_event(kind: String, text: String) -> void:
	if kind == "pegged":
		_banner = text
		_banner_at = hunt.clock()


## The banner's text while it shows ("" when none), for the checks.
func banner() -> String:
	return _banner if hunt != null and hunt.clock() - _banner_at < BANNER_S else ""


func _draw_view() -> void:
	if hunt == null or not hunt.running:
		return
	var v := _view
	var real := hunt.layer == "real"
	var compact := v.size.x < COMPACT_W
	var rows := hunt.hottest(ROWS_COMPACT if compact else ROWS)
	var lines: Array = hunt.events.slice(maxi(hunt.events.size() - LINES_COMPACT, 0)) if compact else hunt.events
	var h := 88.0 + LINE * (rows.size() + 1) + 10.0 + LINE * lines.size() + 16.0
	var rect := Rect2(PANEL_AT, Vector2(PANEL_W, h))
	v.draw_rect(rect, Color(Palette.VOID, ALPHA))
	v.draw_rect(Rect2(rect.position, Vector2(3, h)), Palette.VERMILION)
	var scan := fposmod(hunt.clock() * 0.35, 1.0)
	v.draw_rect(Rect2(rect.position + Vector2(3, h * scan), Vector2(PANEL_W - 3, 1)), Color(Palette.VERMILION, 0.12))
	var x := PANEL_AT.x + 14.0
	var y := PANEL_AT.y + 24.0
	v.draw_string(_font, Vector2(x, y), TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.VERMILION)
	var chip := REAL if real else DEMO
	var cw := _font.get_string_size(chip, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 12.0
	var cx := PANEL_AT.x + PANEL_W - cw - 12.0
	v.draw_rect(Rect2(cx, y - 13, cw, 16), Color(Palette.MINT if not real else Palette.HOSTILE_AMBER, 0.16))
	v.draw_rect(Rect2(cx, y - 13, cw, 16), Palette.MINT if not real else Palette.HOSTILE_AMBER, false, 1.0)
	v.draw_string(_font, Vector2(cx + 6, y), chip, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Palette.MINT if not real else Palette.HOSTILE_AMBER)
	y += 22.0
	var counts := _counts()
	v.draw_string(_font, Vector2(x, y), "procs %d   up %d   swarms %d   boss %d" % [hunt.process_count(), counts[0], counts[1], counts[2]], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.MINT)
	y += 16.0
	v.draw_string(_font, Vector2(x, y), NOTE, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(Palette.MINT, 0.6))
	y += 12.0
	v.draw_rect(Rect2(x, y, PANEL_W - 28, 1), Color(Palette.TEAL, 0.45))
	y += LINE
	v.draw_string(_font, Vector2(x, y), "%-7s %-15s %6s" % ["PID", "COMMAND", "%CPU"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.TEAL)
	for r in rows:
		y += LINE
		var hot := float(r[2]) / 100.0
		var colour: Color = Palette.VERMILION if r[3] == "nest" or r[3] == "drone" else Palette.MINT
		if r[3] == "boss":
			colour = Palette.CRIMSON.lerp(Palette.HEAT_HI, clampf(ProcMap.heat_for(float(r[2])), 0.0, 1.0))
		elif r[3] == "zombie":
			colour = Palette.HOSTILE_AMBER
		v.draw_rect(Rect2(x - 4, y - 12, (PANEL_W - 20) * clampf(hot, 0.0, 1.0), 15), Color(colour, 0.13))
		v.draw_string(_font, Vector2(x, y), "%-7d %-15s %6.1f" % [r[0], str(r[1]).left(15), r[2]], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, colour)
	y += 10.0
	v.draw_rect(Rect2(x, y, PANEL_W - 28, 1), Color(Palette.TEAL, 0.3))
	for i in lines.size():
		y += LINE
		var e: Dictionary = lines[i]
		var age: float = hunt.clock() - float(e["t"])
		var alpha := clampf(1.2 - age / 12.0, 0.35, 1.0)
		var colour := Palette.MINT
		match str(e["kind"]):
			"fork":
				colour = Palette.TEAL
			"exit":
				colour = Color(Palette.MINT, 0.7)
			"kill":
				colour = Palette.FLASH
			"reaped":
				colour = Palette.HOSTILE_AMBER
			"pegged":
				colour = Palette.CRIMSON
		v.draw_string(_font, Vector2(x, y), str(e["text"]), HORIZONTAL_ALIGNMENT_LEFT, PANEL_W - 24, 12, Color(colour, alpha))
	# The pegged core's banner: across the top, a few seconds.
	var b := banner()
	if b != "":
		var age := hunt.clock() - _banner_at
		var a := clampf(minf(age * 4.0, (BANNER_S - age) * 2.0), 0.0, 1.0)
		var size := 30
		var w := _font.get_string_size(b, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var at := Vector2((v.size.x - w) * 0.5, 150.0)
		var flick := 0.85 + 0.15 * sin(age * 40.0)
		v.draw_rect(Rect2(at.x - 18, at.y - 32, w + 36, 44), Color(Palette.VOID, 0.75 * a))
		v.draw_rect(Rect2(at.x - 18, at.y - 32, w + 36, 2), Color(Palette.CRIMSON, a))
		v.draw_rect(Rect2(at.x - 18, at.y + 10, w + 36, 2), Color(Palette.CRIMSON, a))
		v.draw_string(_font, at, b, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(Palette.HEAT_HI.lerp(Palette.CRIMSON, 0.35), a * flick))


## [enemies up, swarms, bosses].
func _counts() -> Array:
	var up := 0
	var swarms := 0
	var bosses := 0
	var all := hunt.enemies()
	for key in all:
		up += 1
		match str(all[key]["role"]):
			"nest":
				swarms += 1
			"boss":
				bosses += 1
	return [up, swarms, bosses]
