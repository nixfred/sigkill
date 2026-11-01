class_name ThemeShiftHud
extends CanvasLayer
## The theme shift's HUD (W3): a panel where a mission's would stand (the theme, its colours' source, the level, what is
## fighting and what lurks concealed, the theme's time, the theme's sixteen colours as a terminal's colour test prints
## them, the last few events); the shift's banner (`$ export THEME=<next>` typing itself, then the new theme's name over a
## colour test printing across the top); and the results card at the run's end. Drawn in the game's own colours, under
## the grade (scripts/themes/theme_grade.gd), which puts it in the theme with everything else. Reads only the mode.

const Palette = preload("res://scripts/palette.gd")
const PANEL_AT := Vector2(16, 98)
const PANEL_W := 400.0
const COMPACT_W := 1280.0
const LINE := 17.0
const ALPHA := 0.8
const TITLE := "THEME SHIFT"
const DEMO := "built-in themes"
const REAL := "+ your theme"
const SWATCH := 14.0
## The banner's colour test across the top: its blocks' height, and how long it takes to print.
const STRIP_H := 26.0
const STRIP_S := 0.9

var mode: ThemeShift = null
var _view: Control
var _font: Font


func _ready() -> void:
	layer = 0
	_font = Palette.mono_font()
	_view = Control.new()
	_view.name = "ThemeShiftView"
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.draw.connect(_draw_view)
	add_child(_view)


func _process(_delta: float) -> void:
	_view.queue_redraw()


## Every line the panel shows now, for the checks.
func lines() -> PackedStringArray:
	var out := PackedStringArray()
	if mode == null or not mode.running or mode.theme == "":
		return out
	var real := ThemeShift.layer == "real"
	out.append(TITLE + "  " + (REAL if real else DEMO))
	var p := mode.look_of(mode.theme).palette
	out.append(ThemeBook.name_of(mode.theme))
	out.append("level %d of %d   %s   colours: %s" % [ThemeShift.level + 1, ThemeShift.run.size(), p.mode, p.inspired_by])
	out.append("\"%s\"" % str(ThemeBook.WORLDS.get(mode.theme, ThemeBook.WORLDS[ThemeBook.YOURS])["motto"]))
	match mode.phase:
		"fight":
			out.append("FIGHT   the theme holds %s" % _clock_text(mode.time_left()))
		"shift":
			out.append("SHIFTING to %s" % ThemeBook.name_of(mode.next_theme))
		"ambush":
			out.append("AMBUSH   %s left" % _clock_text(mode.time_left()))
		"results":
			out.append("DONE")
	out.append("fighting %d   lurking concealed %d" % [mode.fighting(), mode.lurking()])
	if mode.lurking() > 0:
		var keys := {}
		for e in mode.enemies:
			if bool(e["phased"]) and is_instance_valid(e["body"]) and e["body"].is_alive():
				keys[ThemeBook.name_of(str(e["key"]))] = true
		out.append("  they show in: %s" % ", ".join(PackedStringArray(keys.keys())))
	return out


## The results card's lines (the checks): a row a theme, then the run's totals.
func result_lines() -> PackedStringArray:
	var out := PackedStringArray()
	out.append("%-18s %6s %7s %8s %7s" % ["THEME", "KILLS", "CAUGHT", "SLIPPED", "TIME"])
	var kills := 0
	var caught := 0
	var slipped := 0
	var time := 0.0
	for s in ThemeShift.stats:
		out.append("%-18s %6d %7d %8d %7s" % [ThemeBook.name_of(str(s["theme"])).left(18), int(s["kills"]), int(s["caught"]), int(s["slipped"]), _clock_text(float(s["time"]))])
		kills += int(s["kills"])
		caught += int(s["caught"])
		slipped += int(s["slipped"])
		time += float(s["time"])
	out.append("%-18s %6d %7d %8d %7s" % ["ALL %d THEMES" % ThemeShift.stats.size(), kills, caught, slipped, _clock_text(time)])
	return out


static func _clock_text(s: float) -> String:
	var whole := int(ceil(s))
	return "%d:%02d" % [whole / 60, whole % 60]


func _draw_view() -> void:
	if mode == null or not mode.running or mode.theme == "":
		return
	var v := _view
	var compact := v.size.x < COMPACT_W
	if mode.phase == "results":
		_draw_results(v)
		return
	_draw_panel(v, compact)
	if mode.phase == "shift":
		_draw_banner(v, compact)


func _draw_panel(v: Control, compact: bool) -> void:
	var main := lines()
	var notes: Array = mode.events.slice(maxi(mode.events.size() - (1 if compact else 3), 0))
	var accent := Palette.TEAL
	var h := 30.0 + LINE * (main.size() - 1) + 8.0 + SWATCH + 10.0 + LINE * notes.size() + 14.0
	var rect := Rect2(PANEL_AT, Vector2(PANEL_W, h))
	v.draw_rect(rect, Color(Palette.VOID, ALPHA))
	v.draw_rect(Rect2(rect.position, Vector2(3, h)), accent)
	var scan := fposmod(mode.clock() * 0.35, 1.0)
	v.draw_rect(Rect2(rect.position + Vector2(3, h * scan), Vector2(PANEL_W - 3, 1)), Color(accent, 0.12))
	var x := PANEL_AT.x + 14.0
	var y := PANEL_AT.y + 24.0
	v.draw_string(_font, Vector2(x, y), TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, accent)
	var real := ThemeShift.layer == "real"
	var chip := REAL if real else DEMO
	var chip_c := Palette.HOSTILE_AMBER if real else Palette.MINT
	var cw := _font.get_string_size(chip, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 12.0
	var cx := PANEL_AT.x + PANEL_W - cw - 12.0
	v.draw_rect(Rect2(cx, y - 13, cw, 16), Color(chip_c, 0.16))
	v.draw_rect(Rect2(cx, y - 13, cw, 16), chip_c, false, 1.0)
	v.draw_string(_font, Vector2(cx + 6, y), chip, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, chip_c)
	for i in range(1, main.size()):
		y += LINE + (4.0 if i == 1 else 0.0)
		var size := 20 if i == 1 else 13
		var colour := Palette.FLASH if i == 1 else (Palette.HOSTILE_AMBER if main[i].begins_with("SHIFTING") or main[i].begins_with("AMBUSH") else Palette.MINT)
		v.draw_string(_font, Vector2(x, y), main[i], HORIZONTAL_ALIGNMENT_LEFT, PANEL_W - 24, size, colour)
	# The theme's time as a bar under the phase line.
	if mode.phase == "fight" or mode.phase == "ambush":
		var whole := ThemeShift.fight_s if mode.phase == "fight" else ThemeShift.ambush_s
		var k := clampf(mode.time_left() / maxf(whole, 0.01), 0.0, 1.0)
		v.draw_rect(Rect2(x, y + 5, (PANEL_W - 28) * k, 2), Color(accent, 0.8))
	# The theme's sixteen colours, a terminal's colour test.
	y += 10.0
	var sw := mode.look_of(mode.theme).swatches()
	var step := (PANEL_W - 28) / float(sw.size())
	for i in sw.size():
		v.draw_rect(Rect2(x + step * i, y, step - 2.0, SWATCH), sw[i])
	y += SWATCH
	y += 8.0
	v.draw_rect(Rect2(x, y, PANEL_W - 28, 1), Color(accent, 0.3))
	for e in notes:
		y += LINE
		var age: float = mode.clock() - float(e["t"])
		v.draw_string(_font, Vector2(x, y), str(e["text"]), HORIZONTAL_ALIGNMENT_LEFT, PANEL_W - 24, 12, Color(Palette.MINT, clampf(1.2 - age / 12.0, 0.4, 1.0)))


## The shift: the line typing itself, then the new theme's name, its colours printing across the top.
func _draw_banner(v: Control, compact: bool) -> void:
	var t := mode.shift_t
	var to := mode.next_theme if mode.next_theme != "" else mode.theme
	var line := "$ export THEME=%s" % ThemeBook.slug_of(to)
	var typed := clampi(int(line.length() * t / ThemeShift.TYPE_S), 0, line.length())
	var big := 26 if compact else 38
	var w := _font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
	var at := Vector2((v.size.x - w) * 0.5, v.size.y * 0.36)
	v.draw_rect(Rect2(at.x - 18, at.y - big - 8, w + 36, big + 22), Color(Palette.VOID, 0.6))
	v.draw_string(_font, at, line.left(typed), HORIZONTAL_ALIGNMENT_LEFT, -1, big, Palette.MINT)
	if typed < line.length() or fposmod(t * 3.0, 1.0) < 0.5:
		var cx := at.x + _font.get_string_size(line.left(typed), HORIZONTAL_ALIGNMENT_LEFT, -1, big).x + 4.0
		v.draw_rect(Rect2(cx, at.y - big * 0.8, big * 0.5, big * 0.95), Palette.MINT)
	if t < ThemeShift.TYPE_S:
		return
	var u := t - ThemeShift.TYPE_S
	# The colour test across the top, block by block.
	var sw := mode.look_of(to).swatches()
	var shown := clampi(int(sw.size() * u / STRIP_S) + 1, 0, sw.size())
	var bw := v.size.x / float(sw.size())
	for i in shown:
		v.draw_rect(Rect2(bw * i, 0, bw - 2.0, STRIP_H), sw[i])
	# The name, large, and where its colours come from.
	var name := ThemeBook.name_of(to).to_upper()
	var huge := 40 if compact else 72
	var nw := _font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, huge).x
	var na := Vector2((v.size.x - nw) * 0.5, at.y + huge + 28)
	var fade := clampf(u / 0.25, 0.0, 1.0)
	v.draw_string(_font, na + Vector2(4, 4), name, HORIZONTAL_ALIGNMENT_LEFT, -1, huge, Color(Palette.VOID, 0.8 * fade))
	v.draw_string(_font, na, name, HORIZONTAL_ALIGNMENT_LEFT, -1, huge, Color(Palette.TEAL.lerp(Color.WHITE, 0.2), fade))
	var p := mode.look_of(to).palette
	var credit := "colours: %s   %s" % [p.inspired_by, str(ThemeBook.WORLDS.get(to, ThemeBook.WORLDS[ThemeBook.YOURS])["motto"])]
	var cw := _font.get_string_size(credit, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	v.draw_string(_font, Vector2((v.size.x - cw) * 0.5, na.y + 30), credit, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(Palette.MINT, fade))


func _draw_results(v: Control) -> void:
	var rows := result_lines()
	var size := 16 if v.size.x >= COMPACT_W else 12
	var lh := size + 8.0
	var w := 0.0
	for r in rows:
		w = maxf(w, _font.get_string_size(r, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	w += 48.0
	var h := 70.0 + lh * rows.size() + 40.0
	var at := Vector2((v.size.x - w) * 0.5, (v.size.y - h) * 0.5)
	v.draw_rect(Rect2(at, Vector2(w, h)), Color(Palette.VOID, 0.86))
	v.draw_rect(Rect2(at, Vector2(w, 3)), Palette.TEAL)
	v.draw_string(_font, at + Vector2(24, 40), "THEME SHIFT COMPLETE", HORIZONTAL_ALIGNMENT_LEFT, -1, size + 10, Palette.TEAL)
	var y := at.y + 74.0
	for i in rows.size():
		var colour := Palette.FLASH if i == 0 or i == rows.size() - 1 else Palette.MINT
		if i == rows.size() - 1:
			v.draw_rect(Rect2(at.x + 24, y - size - 4, w - 48, 1), Color(Palette.TEAL, 0.5))
		v.draw_string(_font, Vector2(at.x + 24, y), rows[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)
		y += lh
	v.draw_string(_font, Vector2(at.x + 24, y + 14), "[Enter] run it again    [Esc] menu", HORIZONTAL_ALIGNMENT_LEFT, -1, size - 2, Palette.HOSTILE_AMBER)
