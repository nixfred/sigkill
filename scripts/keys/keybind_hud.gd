class_name KeybindHud
extends CanvasLayer
## Keybind gunplay's HUD (W4): a panel where a mission's would stand (the mode, its table's layer, the drill or wave and its
## time, what the drill asks and its chord as keycaps, how many are learned, the last few events); the shortcut strip at
## the bottom (each weapon's key as a keycap, its cooldown draining down it, all of it lit while the stand-in is held, the
## stand-in's own cap at its left saying it is Super here); the card a chord shows when it is used (a terminal window in
## the game's style: the real chord as keycaps, Omarchy's meaning large, what it does here, how it was played, where the
## meaning comes from; "NEW" the first time); the drill's banner; full screen's border thrown out to the screen's edges;
## a workspace's slide and its number; Omarchy's keybindings list (SUPER + K); the results card. Reads only the mode.

const Palette = preload("res://scripts/palette.gd")
const SlideShader = preload("res://shaders/workspace_slide.gdshader")
const PANEL_AT := Vector2(16, 98)
const PANEL_W := 404.0
const COMPACT_W := 1280.0
const LINE := 17.0
const ALPHA := 0.82
const TITLE := "KEYBIND GUNPLAY"
const DEMO := "built-in shortcuts"
const REAL := "your binds"
const CARD_IN_S := 0.14
const BANNER_S := 1.6
## The strip's weapons, in order, and what each is called under its cap.
const STRIP := ["terminal", "close", "split", "float", "fullscreen", "workspace", "keys"]
const SHORT := {"terminal": "terminal", "close": "close", "split": "split", "float": "float", "fullscreen": "full", "workspace": "workspace", "keys": "keys"}

var mode: KeybindGunplay = null
var _view: Control
var _slide: ColorRect
var _slide_mat: ShaderMaterial
var _font: Font
## Frames the slide is drawn settled (doing nothing) as the HUD comes up, so its shader is ready before the first slide.
var _warm := 3


func _ready() -> void:
	layer = 0  # under the HUD's own layer, so the Esc menu is over it (as the theme shift's)
	_font = Palette.mono_font()
	_slide_mat = ShaderMaterial.new()
	_slide_mat.shader = SlideShader
	_slide = ColorRect.new()
	_slide.name = "WorkspaceSlide"
	_slide.material = _slide_mat
	_slide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slide.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slide.visible = false
	add_child(_slide)
	_view = Control.new()
	_view.name = "KeybindView"
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.draw.connect(_draw_view)
	add_child(_view)


func _process(_delta: float) -> void:
	if mode != null and mode.slide_t >= 0.0:
		_slide.visible = true
		var u := clampf(mode.slide_t / KeybindGunplay.SLIDE_S, 0.0, 1.0)
		_slide_mat.set_shader_parameter("slide", 1.0 - pow(1.0 - u, 3.0))
	elif _warm > 0:
		_warm -= 1
		_slide.visible = true
		_slide_mat.set_shader_parameter("slide", 1.0)
	else:
		_slide.visible = false
	_view.queue_redraw()


## Every line the panel shows now, for the checks.
func lines() -> PackedStringArray:
	var out := PackedStringArray()
	if mode == null or not mode.running:
		return out
	out.append(TITLE + "  " + (REAL if KeybindGunplay.layer == "real" else DEMO))
	out.append("SUPER is your desktop's: hold %s for it here" % KeyBook.STANDIN_NAME)
	match mode.phase:
		"drill", "done":
			var id: String = KeyBook.DRILLS[mode.drill]
			out.append("DRILL %d of %d   %s" % [mode.drill + 1, KeyBook.DRILLS.size(), "LEARNED" if mode.phase == "done" else _clock_text(mode.time_left())])
			out.append(str(KeybindGunplay.DRILL_ASK[id]))
			out.append("%s   %s" % [KeyBook.chord_for(KeybindGunplay.table, id), str(KeyBook.WEAPONS[id]["meaning"])])
		"wave":
			out.append("WAVE %d of %d   %s" % [mode.wave + 1, KeybindGunplay.WAVES.size(), _clock_text(mode.time_left())])
			out.append("every shortcut live: %d daemons standing" % mode.standing())
		"results":
			out.append("DONE")
	out.append("learned %d of %d   cards read %d" % [mode.learned().size(), KeyBook.DRILLS.size(), KeybindGunplay.seen.size()])
	return out


## The card's lines (the checks): its chord, Omarchy's meaning, what it does here, how it was played.
func card_lines() -> PackedStringArray:
	var out := PackedStringArray()
	if mode == null or mode.card.is_empty():
		return out
	var c := mode.card
	out.append(str(c["combo"]))
	out.append(str(c["meaning"]))
	out.append("here: " + str(c["here"]))
	out.append("played: %s   (%s stands in for SUPER)" % [str(c["played"]), KeyBook.STANDIN_NAME])
	return out


## The results card's lines (the checks): a row a shortcut, then the totals.
func result_lines() -> PackedStringArray:
	var out := PackedStringArray()
	if mode == null:
		return out
	out.append("%-16s %-30s %5s %6s %8s %8s" % ["CHORD", "OMARCHY MEANING", "USES", "KILLS", "DRILL", "LEARNED"])
	var learned := mode.learned()
	var uses := 0
	var kills := 0
	for id in KeyBook.DRILLS:
		var s: Dictionary = KeybindGunplay.stats.get(id, {})
		var d := str(s.get("drill", ""))
		out.append("%-16s %-30s %5d %6d %8s %8s" % [KeyBook.chord_for(KeybindGunplay.table, id), str(KeyBook.WEAPONS[id]["meaning"]).left(30), int(s.get("uses", 0)), int(s.get("kills", 0)), d if d != "" else "-", "yes" if learned.has(id) else "no"])
		uses += int(s.get("uses", 0))
		kills += int(s.get("kills", 0))
	out.append("%-16s %-30s %5d %6d %8s %8s" % ["ALL", "%d of %d learned, %d cards read" % [learned.size(), KeyBook.DRILLS.size(), KeybindGunplay.seen.size()], uses, kills, "", ""])
	return out


static func _clock_text(s: float) -> String:
	var whole := int(ceil(s))
	return "%d:%02d" % [whole / 60, whole % 60]


func _draw_view() -> void:
	if mode == null or not mode.running:
		return
	var v := _view
	var compact := v.size.x < COMPACT_W
	if mode.phase == "results":
		_draw_results(v, compact)
		return
	_draw_panel(v, compact)
	_draw_strip(v, compact)
	_draw_banner(v, compact)
	_draw_full(v)
	_draw_workspace(v, compact)
	if mode.list_open:
		_draw_list(v, compact)
	if not mode.card.is_empty() and not mode.list_open:
		_draw_card(v, compact)


# --- Pieces. ---

## A keycap: a raised key, its face lit when `lit`.
func _cap(v: Control, at: Vector2, text: String, size: int, lit: bool, accent: Color, alpha: float = 1.0) -> float:
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var w := maxf(tw + size * 0.9, size * 1.7)
	var h := size * 1.75
	var r := Rect2(at, Vector2(w, h))
	v.draw_rect(Rect2(at + Vector2(0, h * 0.12), r.size), Color(Palette.VOID, 0.85 * alpha))
	v.draw_rect(r, Color(accent, (0.32 if lit else 0.1) * alpha))
	v.draw_rect(Rect2(at + Vector2(0, h - 4), Vector2(w, 4)), Color(accent, (0.55 if lit else 0.25) * alpha))
	v.draw_rect(r, Color(accent, (1.0 if lit else 0.55) * alpha), false, 2.0 if lit else 1.0)
	v.draw_string(_font, at + Vector2((w - tw) * 0.5, h * 0.66), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(Palette.FLASH if lit else accent.lerp(Color.WHITE, 0.3), alpha))
	return w


## A chord as keycaps ("SUPER" + "W"), its width.
func _chord(v: Control, at: Vector2, combo: String, size: int, lit: bool, accent: Color, alpha: float = 1.0) -> float:
	var parts := combo.split(" + ")
	var x := at.x
	for i in parts.size():
		if i > 0:
			v.draw_string(_font, Vector2(x + 6, at.y + size * 1.15), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(accent, alpha))
			x += size * 0.9 + 6
		x += _cap(v, Vector2(x, at.y), KeyBook.cap_of(parts[i]), size, lit, accent, alpha) + 4
	return x - at.x


func _draw_panel(v: Control, compact: bool) -> void:
	var main := lines()
	var notes: Array = mode.events.slice(maxi(mode.events.size() - (1 if compact else 3), 0))
	var accent := Palette.TEAL
	var chord_h := 40.0 if mode.phase == "drill" or mode.phase == "done" else 0.0
	var h := 30.0 + LINE * (main.size() - 1) + 10.0 + chord_h + LINE * notes.size() + 14.0
	var rect := Rect2(PANEL_AT, Vector2(PANEL_W, h))
	v.draw_rect(rect, Color(Palette.VOID, ALPHA))
	v.draw_rect(Rect2(rect.position, Vector2(3, h)), accent)
	var scan := fposmod(mode.clock() * 0.35, 1.0)
	v.draw_rect(Rect2(rect.position + Vector2(3, h * scan), Vector2(PANEL_W - 3, 1)), Color(accent, 0.12))
	var x := PANEL_AT.x + 14.0
	var y := PANEL_AT.y + 24.0
	v.draw_string(_font, Vector2(x, y), TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, accent)
	var real := KeybindGunplay.layer == "real"
	var chip := REAL if real else DEMO
	var chip_c := Palette.HOSTILE_AMBER if real else Palette.MINT
	var cw := _font.get_string_size(chip, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 12.0
	var cx := PANEL_AT.x + PANEL_W - cw - 12.0
	v.draw_rect(Rect2(cx, y - 13, cw, 16), Color(chip_c, 0.16))
	v.draw_rect(Rect2(cx, y - 13, cw, 16), chip_c, false, 1.0)
	v.draw_string(_font, Vector2(cx + 6, y), chip, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, chip_c)
	for i in range(1, main.size()):
		y += LINE
		var line: String = main[i]
		var colour := Palette.MINT
		var size := 13
		if line.begins_with("DRILL") or line.begins_with("WAVE"):
			colour = Palette.FLASH
			size = 16
			y += 3
		elif i == 1:
			colour = Color(Palette.MINT, 0.75)
			size = 12
		if line.contains("LEARNED"):
			colour = Palette.LIME
		v.draw_string(_font, Vector2(x, y), line, HORIZONTAL_ALIGNMENT_LEFT, PANEL_W - 24, size, colour)
		if (line.begins_with("DRILL") or line.begins_with("WAVE")) and mode.time_left() > 0.0:
			var whole := KeybindGunplay.drill_s if mode.phase == "drill" else KeybindGunplay.wave_s
			v.draw_rect(Rect2(x, y + 5, (PANEL_W - 28) * clampf(mode.time_left() / maxf(whole, 0.01), 0.0, 1.0), 2), Color(accent, 0.8))
	if chord_h > 0.0:
		y += 10.0
		var id: String = KeyBook.DRILLS[mode.drill]
		_chord(v, Vector2(x, y), KeyBook.chord_for(KeybindGunplay.table, id), 13, mode.phase == "done", KeyFx.color_of(id))
		v.draw_string(_font, Vector2(x + 168, y + 16), "played: %s + %s" % [KeyBook.STANDIN_NAME, KeyBook.cap_of(KeyBook.key_token(KeyBook.chord_for(KeybindGunplay.table, id)))], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(Palette.MINT, 0.8))
		y += chord_h - 10.0
	y += 4.0
	v.draw_rect(Rect2(x, y, PANEL_W - 28, 1), Color(accent, 0.3))
	for e in notes:
		y += LINE
		var age: float = mode.clock() - float(e["t"])
		v.draw_string(_font, Vector2(x, y), str(e["text"]), HORIZONTAL_ALIGNMENT_LEFT, PANEL_W - 24, 12, Color(Palette.MINT, clampf(1.2 - age / 12.0, 0.4, 1.0)))


## The shortcut strip: the stand-in's cap, then each weapon's key, cooling down its face.
func _draw_strip(v: Control, compact: bool) -> void:
	var size := 13 if compact else 16
	var held := mode.chord
	var widths := 0.0
	var items: Array = []
	for id in STRIP:
		var combo := KeyBook.chord_for(KeybindGunplay.table, id)
		if combo == "":
			continue
		var tok := KeyBook.cap_of(KeyBook.key_token(combo))
		var w := maxf(_font.get_string_size(tok, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + size * 0.9, size * 1.7)
		w = maxf(w, _font.get_string_size(str(SHORT[id]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 6)
		items.append([id, tok, w])
		widths += w + 10.0
	var lead := 150.0 if not compact else 120.0
	var total := lead + widths
	var at := Vector2((v.size.x - total) * 0.5, v.size.y - (132.0 if not compact else 104.0) - (6.0 if held else 0.0))
	var back := Rect2(at - Vector2(12, 10), Vector2(total + 24, size * 1.75 + 34))
	v.draw_rect(back, Color(Palette.VOID, 0.6 if not held else 0.8))
	if held:
		v.draw_rect(back, Color(Palette.LIME, 0.9), false, 2.0)
	# The stand-in: its cap, and that it is Super here.
	var sw := _cap(v, at, KeyBook.STANDIN_NAME, size, held, Palette.LIME)
	v.draw_string(_font, at + Vector2(sw + 8, size * 0.9), "= SUPER", HORIZONTAL_ALIGNMENT_LEFT, -1, 12 if not compact else 10, Color(Palette.LIME, 1.0 if held else 0.7))
	v.draw_string(_font, at + Vector2(sw + 8, size * 1.75), "held" if held else "hold it", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(Palette.LIME, 0.9 if held else 0.5))
	var x := at.x + lead
	for item in items:
		var id: String = item[0]
		var w: float = item[2]
		var accent := KeyFx.color_of(id)
		var left := float(mode.cooling.get(id, 0.0))
		var whole := maxf(float(KeyBook.WEAPONS[id]["cool"]), 0.01)
		var drawn := _cap(v, Vector2(x, at.y), str(item[1]), size, held and left <= 0.0, accent, 1.0 if left <= 0.0 else 0.55)
		if left > 0.0:
			var share := clampf(left / whole, 0.0, 1.0)
			v.draw_rect(Rect2(x, at.y, drawn, size * 1.75 * share), Color(Palette.VOID, 0.6))
			v.draw_string(_font, Vector2(x + 3, at.y + size * 1.75 - 4), "%.0f" % ceil(left), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Palette.HOSTILE_AMBER)
		var label := str(SHORT[id])
		var lw := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		v.draw_string(_font, Vector2(x + (drawn - lw) * 0.5, at.y + size * 1.75 + 15), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(accent, 0.9))
		x += maxf(w, drawn) + 10.0


## The card: a terminal window with the chord as keycaps, Omarchy's meaning, what it did here, how it was played.
func _draw_card(v: Control, compact: bool) -> void:
	var c := mode.card
	var t := float(c["t"])
	var first := bool(c.get("first", false))
	var life := 4.0 if first else 2.2
	var alpha := clampf((life - t) / 0.35, 0.0, 1.0)
	var u := clampf(t / CARD_IN_S, 0.0, 1.0)
	var id := str(c["weapon"])
	var accent := KeyFx.color_of(id) if id != "" else Palette.MINT
	var big := 30 if not compact else 20
	var cap := 18 if not compact else 13
	var w := 560.0 if not compact else 400.0
	var meaning := str(c["meaning"])
	w = maxf(w, _font.get_string_size(meaning, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x + 48.0)
	var h := (232.0 if not compact else 172.0)
	var at := Vector2(v.size.x - w - (40.0 if not compact else 16.0) + (1.0 - (1.0 - pow(1.0 - u, 3.0))) * 80.0, v.size.y * (0.2 if not compact else 0.16))
	var r := Rect2(at, Vector2(w, h))
	v.draw_rect(Rect2(at + Vector2(6, 6), r.size), Color(Palette.VOID, 0.5 * alpha))
	v.draw_rect(r, Color(0.008, 0.012, 0.016, 0.9 * alpha))
	v.draw_rect(r, Color(accent, alpha), false, 2.0)
	# The terminal's prompt: the shortcut asked for, as Omarchy's own list prints it.
	var x := at.x + 18.0
	var y := at.y + 26.0
	v.draw_string(_font, Vector2(x, y), "KEYBINDING   %s" % ("your desktop" if KeybindGunplay.layer == "real" else "Omarchy default"), HORIZONTAL_ALIGNMENT_LEFT, w - 36, 12, Color(Palette.MINT, 0.6 * alpha))
	if first:
		var tag := "NEW"
		var tw := _font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 14
		v.draw_rect(Rect2(at.x + w - tw - 14, at.y + 12, tw, 18), Color(Palette.LIME, 0.9 * alpha))
		v.draw_string(_font, Vector2(at.x + w - tw - 7, at.y + 26), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(Palette.VOID, alpha))
	y += 14.0
	_chord(v, Vector2(x, y), str(c["combo"]), cap, true, accent, alpha)
	y += cap * 1.75 + big + 10.0
	var typed := clampi(int(meaning.length() * clampf(t / 0.12, 0.0, 1.0)) + 1, 0, meaning.length())
	v.draw_string(_font, Vector2(x, y), meaning.left(typed), HORIZONTAL_ALIGNMENT_LEFT, w - 36, big, Color(Palette.FLASH, alpha))
	y += 26.0 if not compact else 20.0
	var here := "here: " + str(c["here"])
	v.draw_string(_font, Vector2(x, y), here, HORIZONTAL_ALIGNMENT_LEFT, w - 36, 14 if not compact else 11, Color(accent.lerp(Color.WHITE, 0.25), alpha))
	y += 22.0 if not compact else 17.0
	var cool := float(c.get("cooling", 0.0))
	var foot := "played: %s   %s" % [str(c["played"]), ("cooling %.1fs" % cool) if cool > 0.0 else "Omarchy default"]
	if KeybindGunplay.layer == "real":
		foot = "played: %s   %s" % [str(c["played"]), ("cooling %.1fs" % cool) if cool > 0.0 else "your desktop's bind"]
	v.draw_string(_font, Vector2(x, y), foot, HORIZONTAL_ALIGNMENT_LEFT, w - 36, 12 if not compact else 10, Color(Palette.HOSTILE_AMBER if cool > 0.0 else Palette.MINT, 0.75 * alpha))


## The drill's banner as it starts, and LEARNED when it is done.
func _draw_banner(v: Control, compact: bool) -> void:
	if mode.phase != "drill" and mode.phase != "done":
		return
	var t := mode.phase_time()
	if mode.phase == "drill" and t > BANNER_S:
		return
	var id: String = KeyBook.DRILLS[mode.drill]
	var done := mode.phase == "done"
	var alpha := clampf(minf(t / 0.2, ((KeybindGunplay.DONE_S if done else BANNER_S) - t) / 0.4), 0.0, 1.0)
	var big := 26 if compact else 40
	var head := ("LEARNED  " if done else "DRILL %d/%d  " % [mode.drill + 1, KeyBook.DRILLS.size()]) + str(KeyBook.WEAPONS[id]["meaning"])
	var hw := _font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
	var at := Vector2((v.size.x - hw) * 0.5, v.size.y * 0.17)
	var accent := Palette.LIME if done else KeyFx.color_of(id)
	v.draw_rect(Rect2(at.x - 24, at.y - big - 14, hw + 48, big + 96), Color(Palette.VOID, 0.62 * alpha))
	v.draw_rect(Rect2(at.x - 24, at.y - big - 14, hw + 48, 3), Color(accent, alpha))
	v.draw_string(_font, at + Vector2(3, 3), head, HORIZONTAL_ALIGNMENT_LEFT, -1, big, Color(Palette.VOID, 0.8 * alpha))
	v.draw_string(_font, at, head, HORIZONTAL_ALIGNMENT_LEFT, -1, big, Color(accent.lerp(Color.WHITE, 0.2), alpha))
	var combo := KeyBook.chord_for(KeybindGunplay.table, id)
	var cs := 16 if compact else 22
	var est := 0.0
	for p in combo.split(" + "):
		est += maxf(_font.get_string_size(KeyBook.cap_of(p), HORIZONTAL_ALIGNMENT_LEFT, -1, cs).x + cs * 0.9, cs * 1.7) + cs * 0.9 + 10
	var cx := (v.size.x - est) * 0.5
	_chord(v, Vector2(cx, at.y + 14), combo, cs, true, accent, alpha)
	var ask := ("hold %s + %s:  " % [KeyBook.STANDIN_NAME, KeyBook.cap_of(KeyBook.key_token(combo))]) + str(KeybindGunplay.DRILL_ASK[id])
	var aw := _font.get_string_size(ask, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	v.draw_string(_font, Vector2((v.size.x - aw) * 0.5, at.y + 14 + cs * 1.75 + 24), ask, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(Palette.MINT, alpha))


## Full screen: a window's border thrown from the crosshair out to the screen's edges, a flash, then gone.
func _draw_full(v: Control) -> void:
	if mode.full_t < 0.0:
		return
	var t := mode.full_t
	var accent := KeyFx.color_of("fullscreen")
	var mid := v.size * 0.5
	var u := clampf(t / KeybindGunplay.FULL_HIT_S, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - u, 3.0)
	var half := Vector2(lerpf(60.0, v.size.x * 0.5 - 6.0, e), lerpf(36.0, v.size.y * 0.5 - 6.0, e))
	var fade := clampf(1.0 - (t - KeybindGunplay.FULL_HIT_S) / 0.7, 0.0, 1.0)
	var r := Rect2(mid - half, half * 2.0)
	# Ghost frames trailing the border out, as a window's open animation leaves them.
	for k in [3, 2, 1]:
		var g := 1.0 - pow(1.0 - clampf(u - 0.12 * k, 0.0, 1.0), 3.0)
		var gh := Vector2(lerpf(60.0, v.size.x * 0.5 - 6.0, g), lerpf(36.0, v.size.y * 0.5 - 6.0, g))
		v.draw_rect(Rect2(mid - gh, gh * 2.0), Color(accent, 0.28 * fade / k), false, 3.0)
	v.draw_rect(r, Color(accent.lerp(Color.WHITE, 0.3), fade), false, 10.0)
	v.draw_rect(r.grow(-16), Color(accent, 0.5 * fade), false, 2.0)
	if t >= KeybindGunplay.FULL_HIT_S:
		var flash := clampf(1.0 - (t - KeybindGunplay.FULL_HIT_S) / 0.16, 0.0, 1.0)
		v.draw_rect(Rect2(Vector2.ZERO, v.size), Color(accent.lerp(Color.WHITE, 0.6), 0.28 * flash))
	var label := "FULL SCREEN"
	v.draw_string(_font, r.position + Vector2(24, 44), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(accent.lerp(Color.WHITE, 0.3), fade))


## The workspace's number, big, as it slides in (and its seam's colour).
func _draw_workspace(v: Control, compact: bool) -> void:
	if mode.slide_t < 0.0:
		return
	var alpha := clampf(1.0 - mode.slide_t / KeybindGunplay.SLIDE_S, 0.0, 1.0)
	var text := "workspace %d" % (mode.workspace + 1)
	var big := 34 if compact else 52
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
	v.draw_string(_font, Vector2((v.size.x - tw) * 0.5, v.size.y * 0.42), text, HORIZONTAL_ALIGNMENT_LEFT, -1, big, Color(Palette.LIME, alpha))


## Omarchy's keybindings list (SUPER + K): the table, two columns, the weapons in their colours.
func _draw_list(v: Control, compact: bool) -> void:
	var rows: Array = []
	for key in KeybindGunplay.table:
		rows.append(KeybindGunplay.table[key])
	rows.sort_custom(func(a, b): return _list_key(a) < _list_key(b))
	var size := 12 if compact else 13
	var lh := size + 5.0
	var top := 98.0
	var bottom := v.size.y - (190.0 if not compact else 150.0)
	var per := maxi(int((bottom - top - 40.0) / lh), 4)
	var cols := 2 if rows.size() > per else 1
	var col_w := 330.0 if not compact else 250.0
	var w := col_w * cols + 24.0
	var shown := mini(rows.size(), per * cols)
	var h := 40.0 + lh * mini(per, int(ceil(shown / float(cols)))) + 10.0
	var at := Vector2(v.size.x - w - 16.0, top)
	v.draw_rect(Rect2(at, Vector2(w, h)), Color(Palette.VOID, 0.88))
	v.draw_rect(Rect2(at, Vector2(w, h)), Color(Palette.MINT, 0.9), false, 2.0)
	v.draw_string(_font, at + Vector2(12, 24), "Keybindings  (%s)" % (REAL if KeybindGunplay.layer == "real" else "Omarchy defaults"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Palette.MINT)
	for i in shown:
		var e: Dictionary = rows[i]
		var col := i / per
		var row := i % per
		var p := at + Vector2(12 + col * col_w, 44 + row * lh + size)
		var id := str(e["weapon"])
		var colour := KeyFx.color_of(id) if id != "" else Color(Palette.MINT, 0.6)
		v.draw_string(_font, p, "%-12s %s" % ["SUPER+" + KeyBook.cap_of(KeyBook.key_token(str(e["combo"]))), str(e["meaning"])], HORIZONTAL_ALIGNMENT_LEFT, col_w - 10, size, colour)
	if shown < rows.size():
		v.draw_string(_font, at + Vector2(12, h - 6), "+%d more" % (rows.size() - shown), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(Palette.MINT, 0.6))


## The list's order: the weapons first, then by chord.
static func _list_key(e: Dictionary) -> String:
	var w := str(e["weapon"])
	var rank := KeyBook.DRILLS.find(w)
	if rank < 0:
		rank = 6 if w == "keys" else (7 if w == "goto" else 8)
	return "%d%s" % [rank, str(e["combo"])]


func _draw_results(v: Control, compact: bool) -> void:
	var rows := result_lines()
	var size := 15 if not compact else 10
	var lh := size + 9.0
	var w := 0.0
	for r in rows:
		w = maxf(w, _font.get_string_size(r, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	w += 48.0
	var h := 78.0 + lh * rows.size() + 70.0
	var at := Vector2((v.size.x - w) * 0.5, (v.size.y - h) * 0.5)
	v.draw_rect(Rect2(at, Vector2(w, h)), Color(Palette.VOID, 0.88))
	v.draw_rect(Rect2(at, Vector2(w, h)), Color(Palette.TEAL, 0.9), false, 2.0)
	v.draw_rect(Rect2(at, Vector2(w, 3)), Palette.TEAL)
	var learned := mode.learned()
	v.draw_string(_font, at + Vector2(24, 40), "KEYBIND GUNPLAY COMPLETE", HORIZONTAL_ALIGNMENT_LEFT, -1, size + 10, Palette.TEAL)
	v.draw_string(_font, at + Vector2(24, 62), "you learned %d of %d shortcuts: they work the same on your desktop, with SUPER" % [learned.size(), KeyBook.DRILLS.size()], HORIZONTAL_ALIGNMENT_LEFT, w - 48, size - 2, Palette.MINT)
	var y := at.y + 96.0
	for i in rows.size():
		var colour := Palette.FLASH if i == 0 or i == rows.size() - 1 else Palette.MINT
		if i > 0 and i < rows.size() - 1:
			colour = Palette.LIME if rows[i].ends_with("yes") else Color(Palette.MINT, 0.6)
		if i == rows.size() - 1:
			v.draw_rect(Rect2(at.x + 24, y - size - 4, w - 48, 1), Color(Palette.TEAL, 0.5))
		v.draw_string(_font, Vector2(at.x + 24, y), rows[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)
		y += lh
	v.draw_string(_font, Vector2(at.x + 24, y + 6), "shortcuts: %s" % KeyBook.SOURCE, HORIZONTAL_ALIGNMENT_LEFT, w - 48, size - 3, Color(Palette.MINT, 0.6))
	v.draw_string(_font, Vector2(at.x + 24, y + 30), "[Enter] run it again    [Esc] menu", HORIZONTAL_ALIGNMENT_LEFT, -1, size - 2, Palette.HOSTILE_AMBER)
