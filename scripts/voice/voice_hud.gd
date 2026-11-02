class_name VoiceHud
extends Control
## Voice commands' HUD (W7, PRD 5.5), drawn in code: the chip, the cover readout and the toasts. It shows a command's
## NAME and what came of it, never a word of what was said: no line of a feed reaches it.
##
## The chip, at the top left under the round's lines, only while a feed is set (the player's own, or the demo's): a pill
## with a dot and VOICE, and its state. Listening, the dot breathes and five bars beside it ripple (the feed's own
## rhythm, not a microphone's: nothing is heard here), with the feed's name ("demo feed" or "your feed") and, under it,
## the honest line: lines arrive a few seconds after they are said. Off, the dot is dim and the reason is plain: no feed
## set, the address refused (loopback only), real-machine data off, the feed down (and when it is tried again), an
## answer it could not read. Under it, counts only: lines heard, the TV's skipped, lines refused.
##
## The cover readout: while your AI's drone is out, "P  cover me" and a bar of its seconds; recharging, the seconds left;
## nothing once it is ready (the key list and the README teach P).
##
## A toast for every command that fires, by voice: a dark card dropping in at the top's middle, torn in slices for its
## first moments as if it came in over a bad line, a strip of the command's own colour down its edge washing into it,
## scanlines over it, its corners bracketed in that colour, a glyph of what it
## does (a shield for cover, a bolt for a breaker, a turning arrow for reload, an eye for the visor, bars for pause, a
## play mark for resume) beside its name large, and under it what came of it ("drone out  10 s", "no breaker loaded",
## "SIGSTOP"); a bar of light sweeps it once, then it fades. Several at once queue. Cosmetic only; it never takes input.

const Palette = preload("res://scripts/palette.gd")
const VoiceMatch = preload("res://scripts/voice/voice_match.gd")

## Each command's colour: the colour of what it sets off.
const COLORS := {
	&"cover": Palette.MINT, &"breaker": Palette.BREAKER_TEXT, &"reload": Palette.ICE, &"visor": Palette.HOSTILE_AMBER,
	&"pause": Palette.TEAL, &"resume": Palette.MINT,
}
## The chip's place and size at 1080 lines; the toast's.
const CHIP_AT := Vector2(18, 124)
const CHIP_H := 26.0
const TOAST_W := 470.0
const TOAST_H := 84.0
const TOAST_TOP := 150.0
## Seconds: a toast's drop in, how long it stays in all, its fade; its torn first moments.
const TOAST_IN := 0.16
const TOAST_S := 2.6
const TOAST_OUT := 0.4
const TEAR_S := 0.2
## The plain lines.
const LATE := "lines arrive a few seconds after they are said"
const COVER := "P  cover me"

var voice: Node = null
var _toasts: Array = []
var _age := 0.0
var _t := 0.0
var _font: Font


func _ready() -> void:
	name = "VoiceHud"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = Palette.mono_font()


## A command fired: its toast queued (by id; `outcome` the game's own words for what came of it).
func toast(id: StringName, outcome: String) -> void:
	if not VoiceMatch.COMMANDS.has(id):
		return
	_toasts.append({"id": id, "outcome": outcome})
	if _toasts.size() > 4:
		_toasts = _toasts.slice(_toasts.size() - 4)
	if _toasts.size() == 1:
		_age = 0.0


## The toast up now, or {} (the checks).
func current_toast() -> Dictionary:
	return _toasts[0] if not _toasts.is_empty() else {}


## The chip's lines as drawn now, or [] while it is hidden (the checks).
func chip_lines() -> PackedStringArray:
	var out := PackedStringArray()
	var state := _state()
	if not state.get("shown", false):
		return out
	out.append("VOICE  " + str(state.get("word", "")))
	out.append(str(state.get("line", "")))
	out.append(str(state.get("counts", "")))
	return out


## The cover readout as drawn now, or "" (the checks).
func cover_line() -> String:
	var state := _state()
	var out := float(state.get("cover_left", 0.0))
	var wait := float(state.get("cover_wait", 0.0))
	if out > 0.0:
		return "%s  %ds" % [COVER, ceili(out)]
	if wait > 0.0:
		return "%s  recharging %ds" % [COVER, ceili(wait)]
	return ""


func _state() -> Dictionary:
	if voice == null or not is_instance_valid(voice) or not voice.has_method("hud_state"):
		return {}
	return voice.hud_state()


func _process(delta: float) -> void:
	_t += delta
	if not _toasts.is_empty():
		_age += delta
		if _age >= TOAST_S:
			_toasts.pop_front()
			_age = 0.0
	queue_redraw()


## Its scale with the window: the arena's own HUD text keeps its size in a small window, so this keeps most of its own.
func _k() -> float:
	return clampf(size.y / 1080.0, 0.82, 1.6)


func _draw() -> void:
	var k := _k()
	var state := _state()
	var y := CHIP_AT.y * maxf(k, 1.0)
	if state.get("shown", false):
		y = _draw_chip(state, k)
	var cover := cover_line()
	if cover != "":
		_draw_cover(state, Vector2(CHIP_AT.x * k, y + 6.0 * k), k)
	if not _toasts.is_empty():
		_draw_toast(_toasts[0], k)


func _draw_chip(state: Dictionary, k: float) -> float:
	var listening: bool = state.get("listening", false)
	var word: String = state.get("word", "")
	var source: String = state.get("source", "")
	var hue: Color = Palette.MINT if listening else (Palette.HOSTILE_AMBER if state.get("warn", false) else Color(Palette.MINT, 0.55))
	var at := Vector2(CHIP_AT.x * k, CHIP_AT.y * maxf(k, 1.0))  # under the round's lines, which never shrink
	var h := CHIP_H * k
	var fs := int(13 * k)
	var head_w := _font.get_string_size("VOICE", HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * k)).x
	var word_w := _font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var src_w := _font.get_string_size(source, HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * k)).x if source != "" else 0.0
	var bars_w := 34.0 * k
	var w := 14.0 * k + 12.0 * k + head_w + 10.0 * k + bars_w + 8.0 * k + word_w + (14.0 * k + src_w if source != "" else 0.0) + 14.0 * k
	var box := Rect2(at, Vector2(w, h))
	draw_rect(box, Color(Palette.VOID, 0.72))
	_round_ends(box, hue)
	var dot_c := at + Vector2(14.0 * k, h * 0.5)
	var breathe := 0.5 + 0.5 * sin(_t * 3.2)
	if listening:
		draw_circle(dot_c, 7.0 * k * (0.8 + 0.4 * breathe), Color(hue, 0.18))
	draw_circle(dot_c, 4.0 * k, Color(hue, 1.0 if listening else 0.6))
	var x := at.x + 26.0 * k
	draw_string(_font, Vector2(x, at.y + h * 0.5 + 5.0 * k), "VOICE", HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * k), Color(hue, 1.0))
	x += head_w + 10.0 * k
	for i in 5:
		var amp := 0.18
		if listening:
			amp = 0.25 + 0.75 * absf(sin(_t * (2.1 + i * 0.7) + i * 1.3)) * (0.6 + 0.4 * sin(_t * 0.9 + i))
		var bh := maxf(h * 0.62 * amp, 2.0 * k)
		var bx := x + i * 7.0 * k
		draw_rect(Rect2(Vector2(bx, at.y + (h - bh) * 0.5), Vector2(4.0 * k, bh)), Color(hue, 0.9 if listening else 0.4))
	x += bars_w + 8.0 * k
	draw_string(_font, Vector2(x, at.y + h * 0.5 + 4.5 * k), word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Palette.FLASH if listening else hue, 0.95))
	x += word_w
	if source != "":
		x += 14.0 * k
		draw_string(_font, Vector2(x, at.y + h * 0.5 + 4.0 * k), source, HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * k), Color(Palette.TEAL, 0.9))
	var y := at.y + h + 14.0 * k
	var line: String = state.get("line", "")
	if line != "":
		draw_string(_font, Vector2(at.x + 4.0 * k, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * k), Color(hue if not listening else Palette.TEAL, 0.9))
		y += 14.0 * k
	var counts: String = state.get("counts", "")
	if counts != "":
		draw_string(_font, Vector2(at.x + 4.0 * k, y), counts, HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * k), Color(Palette.MINT, 0.6))
		y += 14.0 * k
	return y - 10.0 * k


func _round_ends(box: Rect2, hue: Color) -> void:
	var r := box.size.y * 0.5
	draw_rect(Rect2(box.position + Vector2(r * 0.5, 0), Vector2(box.size.x - r, 1.5)), Color(hue, 0.85))
	draw_rect(Rect2(box.position + Vector2(r * 0.5, box.size.y - 1.5), Vector2(box.size.x - r, 1.5)), Color(hue, 0.85))
	draw_arc(box.position + Vector2(r * 0.5, r), r, PI * 0.5, PI * 1.5, 12, Color(hue, 0.85), 1.5)
	draw_arc(box.end - Vector2(r * 0.5, r), r, -PI * 0.5, PI * 0.5, 12, Color(hue, 0.85), 1.5)


func _draw_cover(state: Dictionary, at: Vector2, k: float) -> void:
	var out := float(state.get("cover_left", 0.0))
	var wait := float(state.get("cover_wait", 0.0))
	var fs := int(12 * k)
	var hue := Palette.MINT if out > 0.0 else Color(Palette.TEAL, 0.75)
	var y := at.y + 12.0 * k
	draw_string(_font, Vector2(at.x + 4.0 * k, y), COVER, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, hue)
	var bx := at.x + 4.0 * k + _font.get_string_size(COVER, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 10.0 * k
	var bw := 120.0 * k
	var share := out / maxf(float(state.get("cover_s", 10.0)), 0.1) if out > 0.0 else 1.0 - wait / maxf(float(state.get("cover_cool", 40.0)), 0.1)
	draw_rect(Rect2(Vector2(bx, y - 8.0 * k), Vector2(bw, 7.0 * k)), Color(Palette.VOID, 0.6))
	draw_rect(Rect2(Vector2(bx, y - 8.0 * k), Vector2(bw * clampf(share, 0.0, 1.0), 7.0 * k)), Color(hue, 0.95 if out > 0.0 else 0.55))
	var text := "%ds" % ceili(out) if out > 0.0 else "recharging %ds" % ceili(wait)
	draw_string(_font, Vector2(bx + bw + 8.0 * k, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, hue)


func _draw_toast(toast: Dictionary, k: float) -> void:
	var id: StringName = toast["id"]
	var hue: Color = COLORS.get(id, Palette.MINT)
	var name_text := VoiceMatch.name_of(id).to_upper()
	var outcome: String = toast["outcome"]
	var a := 1.0
	var drop := 0.0
	if _age < TOAST_IN:
		var u := _age / TOAST_IN
		a = u
		drop = (1.0 - u) * -24.0
	elif _age > TOAST_S - TOAST_OUT:
		a = clampf((TOAST_S - _age) / TOAST_OUT, 0.0, 1.0)
	var w := TOAST_W * k
	var h := TOAST_H * k
	var at := Vector2((size.x - w) * 0.5, TOAST_TOP * k + drop * k)
	var tearing := _age < TEAR_S
	var slices := 6 if tearing else 1
	for s in slices:
		var sy := h * float(s) / float(slices)
		var sh := h / float(slices)
		var off := 0.0
		if tearing:
			off = sin(float(s) * 12.9 + _t * 80.0) * 14.0 * k * (1.0 - _age / TEAR_S)
		draw_rect(Rect2(at + Vector2(off, sy), Vector2(w, sh)), Color(Palette.VOID, 0.93 * a))
	# The command's own light: a strip down its left edge, a wash fading in from it, a hairline frame; scanlines over all.
	draw_rect(Rect2(at, Vector2(5.0 * k, h)), Color(hue, 0.95 * a))
	var steps := 32
	for i in steps:
		var u := float(i) / float(steps)
		draw_rect(Rect2(at + Vector2(5.0 * k + w * 0.75 * u, 0), Vector2(w * 0.75 / float(steps) + 1.0, h)), Color(hue, 0.1 * pow(1.0 - u, 1.6) * a))
	draw_rect(Rect2(at, Vector2(w, h)), Color(hue, 0.35 * a), false, 1.0)
	var line_y := 0.0
	while line_y < h:
		draw_rect(Rect2(at + Vector2(0, line_y), Vector2(w, 1.0)), Color(0.0, 0.0, 0.0, 0.22 * a))
		line_y += 3.0 * k
	# A ghost split off its edges while it tears (red and blue), the bad line's mark.
	if tearing:
		var g := (1.0 - _age / TEAR_S) * a
		draw_rect(Rect2(at + Vector2(-5.0 * k, 0), Vector2(3.0 * k, h)), Color(Palette.HOSTILE_RED, 0.6 * g))
		draw_rect(Rect2(at + Vector2(w + 2.0 * k, 0), Vector2(3.0 * k, h)), Color(Palette.COBALT, 0.6 * g))
	# Brackets of the command's light at its corners, and a hairline under its head.
	var bl := 18.0 * k
	var bw := 3.0 * k
	for corner in [at, at + Vector2(w, 0), at + Vector2(0, h), at + Vector2(w, h)]:
		var sx := 1.0 if corner.x <= at.x + 1.0 else -1.0
		var sy := 1.0 if corner.y <= at.y + 1.0 else -1.0
		draw_rect(Rect2(corner + Vector2(0 if sx > 0 else -bl, 0 if sy > 0 else -bw), Vector2(bl, bw)), Color(hue, a))
		draw_rect(Rect2(corner + Vector2(0 if sx > 0 else -bw, 0 if sy > 0 else -bl), Vector2(bw, bl)), Color(hue, a))
	# The sweep: a bar of light across it once.
	var sweep := clampf((_age - TOAST_IN) / 0.7, 0.0, 1.0)
	if sweep > 0.0 and sweep < 1.0:
		var sx2 := at.x + w * sweep
		draw_rect(Rect2(Vector2(sx2 - 30.0 * k, at.y), Vector2(30.0 * k, h)), Color(hue, 0.16 * a))
		draw_rect(Rect2(Vector2(sx2 - 2.0 * k, at.y), Vector2(2.0 * k, h)), Color(Palette.FLASH, 0.5 * a))
	# The glyph's tile.
	var tile := Rect2(at + Vector2(12.0 * k, 12.0 * k), Vector2(h - 24.0 * k, h - 24.0 * k))
	draw_rect(tile, Color(hue, 0.12 * a))
	draw_rect(tile, Color(hue, 0.8 * a), false, 1.5 * k)
	_glyph(id, tile.get_center(), tile.size.x * 0.34, hue, a, k)
	var tx := tile.end.x + 16.0 * k
	draw_string(_font, Vector2(tx, at.y + 22.0 * k), "VOICE  >", HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * k), Color(Palette.TEAL, 0.9 * a))
	var heard_w := _font.get_string_size("heard", HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * k)).x
	draw_string(_font, Vector2(at.x + w - heard_w - 16.0 * k, at.y + 22.0 * k), "heard", HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * k), Color(Palette.TEAL, 0.7 * a))
	for i in 6:
		var amp := 0.3 + 0.7 * absf(sin(_t * 9.0 + i * 1.7)) * clampf(1.0 - _age / 1.2, 0.15, 1.0)
		var bh := 12.0 * k * amp
		draw_rect(Rect2(Vector2(at.x + w - heard_w - 22.0 * k - (6 - i) * 5.0 * k, at.y + 18.0 * k - bh * 0.5), Vector2(3.0 * k, bh)), Color(hue, 0.8 * a))
	draw_string(_font, Vector2(tx, at.y + 52.0 * k), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(30 * k), Color(hue, a))
	draw_string(_font, Vector2(tx, at.y + 72.0 * k), outcome, HORIZONTAL_ALIGNMENT_LEFT, w - (tx - at.x) - 12.0 * k, int(12 * k), Color(Palette.FLASH, 0.85 * a))


## Each command's glyph, drawn round `c` at radius `r`.
func _glyph(id: StringName, c: Vector2, r: float, hue: Color, a: float, k: float) -> void:
	var col := Color(hue, a)
	var lw := 2.5 * k
	match id:
		&"cover":
			var pts := PackedVector2Array()
			for i in 7:
				var ang := -PI * 0.5 + TAU * float(i) / 6.0
				pts.append(c + Vector2(cos(ang), sin(ang)) * r)
			draw_polyline(pts, col, lw)
			draw_circle(c, r * 0.32, col)
			draw_arc(c, r * 0.62, 0.0, TAU, 18, Color(hue, 0.6 * a), 1.5 * k)
		&"breaker":
			var bolt := PackedVector2Array([c + Vector2(r * 0.25, -r), c + Vector2(-r * 0.45, r * 0.1), c + Vector2(r * 0.05, r * 0.1), c + Vector2(-r * 0.25, r), c + Vector2(r * 0.5, -r * 0.15), c + Vector2(0.0, -r * 0.15)])
			draw_colored_polygon(bolt, col)
		&"reload":
			var spin := _t * 4.0
			draw_arc(c, r * 0.8, spin, spin + PI * 1.5, 20, col, lw)
			var tip := c + Vector2(cos(spin + PI * 1.5), sin(spin + PI * 1.5)) * r * 0.8
			var along := Vector2(-sin(spin + PI * 1.5), cos(spin + PI * 1.5))
			var out := (tip - c).normalized()
			draw_colored_polygon(PackedVector2Array([tip + along * r * 0.35, tip + out * r * 0.3, tip - out * r * 0.3]), col)
		&"visor":
			var eye := PackedVector2Array()
			for i in 17:
				var u := float(i) / 16.0
				eye.append(c + Vector2(lerpf(-r, r, u), -sin(u * PI) * r * 0.55))
			for i in range(16, -1, -1):
				var u := float(i) / 16.0
				eye.append(c + Vector2(lerpf(-r, r, u), sin(u * PI) * r * 0.55))
			draw_polyline(eye, col, lw)
			draw_circle(c, r * 0.28, col)
		&"pause":
			draw_rect(Rect2(c + Vector2(-r * 0.6, -r * 0.75), Vector2(r * 0.4, r * 1.5)), col)
			draw_rect(Rect2(c + Vector2(r * 0.2, -r * 0.75), Vector2(r * 0.4, r * 1.5)), col)
		&"resume":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.5, -r * 0.8), c + Vector2(r * 0.8, 0), c + Vector2(-r * 0.5, r * 0.8)]), col)
