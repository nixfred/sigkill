class_name CoopHud
extends CanvasLayer
## Split-screen co-op's shared HUD (W6, scripts/coop/coop_hunt.gd), over both tiles: the wave across the top (how many are
## standing), the boss's bar while it stands, the run's big moments as a banner across the middle (a wave forking in, a
## wave cleared, a player stopped or continued, wiped), the last few lines of the run's job control at the bottom, and the
## shared results card at the end: each player's kills, downs, revives and accuracy side by side, the waves and the time.
## Each tile's own HUD (scripts/coop/coop_tile_hud.gd) is made here and put over its tile. Made in code.

const Palette = preload("res://scripts/palette.gd")

## Over the tiles' frame (0), under the game's HUD and its menu (1).
const LAYER := 0
const BANNER_S := 2.4

var mode: CoopHunt = null
var tiles: Array = [null, null, null]
var _root: Control
var _banner := ""
var _banner_color := Color.WHITE
var _banner_t := 0.0
var _clock := 0.0


func _ready() -> void:
	name = "CoopHud"
	layer = LAYER
	_root = Control.new()
	_root.name = "Shared"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.draw.connect(_draw_shared)
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if mode != null and mode.screen != null:
		for seat: int in [1, 2]:
			var t := CoopTileHud.new()
			t.name = "TileHud%d" % seat
			t.mode = mode
			t.seat = seat
			mode.screen.overlay(seat).add_child(t)
			tiles[seat] = t
	if mode != null:
		mode.event.connect(_on_event)


func _on_event(kind: String, text: String) -> void:
	var big := {"wave": Color(1.0, 0.75, 0.3), "clear": CoopScreen.COLOR_HI[1], "down": Color(1.0, 0.3, 0.38), "revived": Color(0.75, 1.0, 0.9), "out": Color(1.0, 0.3, 0.38), "wiped": Color(1.0, 0.25, 0.3), "done": CoopScreen.COLOR_HI[1], "boss": Color(1.0, 0.9, 0.7)}
	if big.has(kind):
		_banner = text
		_banner_color = big[kind]
		_banner_t = BANNER_S


func _process(delta: float) -> void:
	_clock += delta
	_banner_t = maxf(_banner_t - delta, 0.0)
	_root.queue_redraw()


## What the top line says now (for the checks).
func top_line() -> String:
	if mode == null:
		return ""
	match mode.phase:
		"ready":
			return "WAVE 1/%d IN %d" % [CoopHunt.WAVES.size(), int(ceil(CoopHunt.READY_S - mode._phase_t))]
		"break":
			return "WAVE %d/%d IN %d" % [mode.wave + 1, CoopHunt.WAVES.size(), int(ceil(CoopHunt.BREAK_S - mode._phase_t))]
		"wave":
			return "WAVE %d/%d   %d STANDING" % [mode.wave, CoopHunt.WAVES.size(), mode.standing() + mode._queue.size()]
		"done":
			return "ALL WAVES CLEARED"
		"wiped":
			return "WIPED"
	return ""


func _k() -> float:
	return maxf(_root.size.y / 1080.0, 0.5)


func _draw_shared() -> void:
	if mode == null or not is_instance_valid(mode) or not mode.running:
		return
	var k := _k()
	var font := Palette.mono_font()
	var s := _root.size
	_bar(k, font, s)
	if mode.phase == "results":
		_results(k, font, s)
		return
	# The big moment, across the middle.
	if _banner_t > 0.0 and _banner != "":
		var a := clampf(_banner_t / 0.4, 0.0, 1.0) * clampf((BANNER_S - _banner_t) / 0.15 + 0.2, 0.0, 1.0)
		var fs := int(round(34.0 * k))
		var w := font.get_string_size(_banner, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var y := s.y * 0.30
		var band := Rect2(Vector2(0, y - fs * 1.2), Vector2(s.x, fs * 1.75))
		_root.draw_rect(band, Color(0.0, 0.0, 0.0, 0.55 * a))
		_root.draw_line(band.position, Vector2(band.end.x, band.position.y), Color(_banner_color, 0.7 * a), maxf(1.0, 2.0 * k))
		_root.draw_line(Vector2(0, band.end.y), band.end, Color(_banner_color, 0.7 * a), maxf(1.0, 2.0 * k))
		_root.draw_string(font, Vector2(s.x * 0.5 - w * 0.5, y), _banner, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(_banner_color, a))


## The shared bar across the top, as a tiling desktop's bar: left, the two players as workspaces (lit while up, red while
## stopped, the active tile's marked); middle, the wave and how many stand, or the boss's bar while it stands; right, the
## run's last line of job control and its time.
func _bar(k: float, font: Font, s: Vector2) -> void:
	if mode.screen == null:
		return
	var bar := mode.screen.bar_rect()
	_root.draw_rect(bar, Color(0.012, 0.016, 0.02, 0.94))
	_root.draw_line(Vector2(bar.position.x, bar.end.y), bar.end, Color(1.0, 1.0, 1.0, 0.08), maxf(1.0, k))
	var fs := int(round(15.0 * k))
	var mid_y := bar.position.y + bar.size.y * 0.5 + fs * 0.36
	# Left: SIGKILL, then a pill per player.
	var x := bar.position.x + 12.0 * k
	_root.draw_string(font, Vector2(x, mid_y), "SIGKILL", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 1.0, 1.0, 0.85))
	x += font.get_string_size("SIGKILL", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 16.0 * k
	for seat: int in [1, 2]:
		var st := mode.state(seat)
		var hue: Color = CoopScreen.COLOR[seat] if st == "up" else Color(1.0, 0.25, 0.32)
		var label := "%d  p%d %s" % [seat, seat, CoopScreen.PROMPT[seat]] if st == "up" else "%d  p%d %s" % [seat, seat, "Stopped" if st == "down" else "Killed"]
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 18.0 * k
		var pill := Rect2(Vector2(x, bar.position.y + 4.0 * k), Vector2(w, bar.size.y - 8.0 * k))
		var active := seat == mode.screen.focus
		_root.draw_rect(pill, Color(hue, 0.28 if active else 0.12))
		if active:
			_root.draw_line(Vector2(pill.position.x, pill.end.y), pill.end, hue, maxf(1.5, 2.0 * k))
		_root.draw_string(font, Vector2(x + 9.0 * k, mid_y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, hue.lightened(0.35))
		x += w + 8.0 * k
	# Middle: the wave, or the boss.
	var b := mode.boss()
	if b != null and is_instance_valid(b) and b.is_alive() and mode.phase == "wave":
		var share := clampf(b.health() / float(CoopHunt.HEALTH["boss"]), 0.0, 1.0)
		var label := "PEGGED  core 0  %d%%" % int(round(100.0 - share * 30.0))
		var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var bw := 300.0 * k
		var left := s.x * 0.5 - (lw + bw + 14.0 * k) * 0.5
		_root.draw_string(font, Vector2(left, mid_y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.75, 0.7))
		var r := Rect2(Vector2(left + lw + 14.0 * k, bar.position.y + bar.size.y * 0.5 - 5.0 * k), Vector2(bw, 10.0 * k))
		_root.draw_rect(r, Color(0.0, 0.0, 0.0, 0.8))
		var hot := Color(1.0, 0.2, 0.28).lerp(Color(1.0, 0.94, 0.78), (0.5 + 0.5 * sin(_clock * 7.0)) * (1.0 - share))
		_root.draw_rect(Rect2(r.position, Vector2(bw * share, r.size.y)), hot)
		var n := "%d / %d   %d STANDING" % [int(ceil(b.health())), int(CoopHunt.HEALTH["boss"]), mode.standing() + mode._queue.size()]
		_root.draw_string(font, Vector2(r.end.x + 12.0 * k, mid_y), n, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.82, 0.45))
	else:
		var top := top_line()
		var tw := font.get_string_size(top, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs * 1.1)).x
		_root.draw_string(font, Vector2(s.x * 0.5 - tw * 0.5, mid_y + 1.0 * k), top, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs * 1.1), Color(1.0, 0.82, 0.45))
	# Right: the last line of job control, the time.
	var t := float(CoopHunt.stats.get("time", 0.0))
	var clock := "%d:%02d" % [int(t) / 60, int(t) % 60]
	var cw := font.get_string_size(clock, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_root.draw_string(font, Vector2(bar.end.x - cw - 12.0 * k, mid_y), clock, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 1.0, 1.0, 0.85))
	var last := ""
	for e in mode.events:
		if e["kind"] != "tile":
			last = "$ " + str(e["text"])
	if last != "":
		var room := bar.end.x - cw - 30.0 * k - (s.x * 0.5 + 330.0 * k)
		var lfs := int(round(13.0 * k))
		while last.length() > 8 and font.get_string_size(last, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x > room:
			last = last.substr(0, last.length() - 4) + "..."
		var lw2 := font.get_string_size(last, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x
		if room > 60.0 * k:
			_root.draw_string(font, Vector2(bar.end.x - cw - 24.0 * k - lw2, mid_y), last, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, Color(0.75, 0.85, 0.82, 0.8))


## The shared results card: the run's head line, each player's column, the team's line, how to go again.
func _results(k: float, font: Font, s: Vector2) -> void:
	_root.draw_rect(Rect2(Vector2.ZERO, s), Color(0.0, 0.0, 0.0, 0.5))
	var w := minf(1180.0 * k, s.x - 40.0)
	var h := 560.0 * k
	var card := Rect2(s * 0.5 - Vector2(w, h) * 0.5, Vector2(w, h))
	_root.draw_rect(card, Color(0.012, 0.018, 0.024, 0.97))
	var wiped := bool(CoopHunt.stats.get("wiped", false))
	var edge := Color(1.0, 0.3, 0.38) if wiped else CoopScreen.COLOR_HI[1]
	_root.draw_rect(card, Color(edge, 0.85), false, maxf(1.0, 2.0 * k))
	var bar := Rect2(card.position, Vector2(card.size.x, 34.0 * k))
	_root.draw_rect(bar, Color(0.03, 0.045, 0.055))
	var fs := int(round(16.0 * k))
	_root.draw_string(font, bar.position + Vector2(14.0 * k, 23.0 * k), "coop@sigkill:/arena$ jobs -l   (results)", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.75, 0.82, 0.85))
	var lines := mode.result_lines()
	var head := lines[0]
	var hfs := int(round(40.0 * k))
	var hw := font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, hfs).x
	_root.draw_string(font, Vector2(s.x * 0.5 - hw * 0.5, card.position.y + 100.0 * k), head, HORIZONTAL_ALIGNMENT_LEFT, -1, hfs, edge)
	# Each player's column.
	var colw := (card.size.x - 60.0 * k) * 0.5
	for seat: int in [1, 2]:
		var x := card.position.x + 20.0 * k + (seat - 1) * (colw + 20.0 * k)
		var y := card.position.y + 150.0 * k
		var box := Rect2(Vector2(x, y), Vector2(colw, 300.0 * k))
		var hue: Color = CoopScreen.COLOR[seat]
		var hi: Color = CoopScreen.COLOR_HI[seat]
		_root.draw_rect(box, Color(hue, 0.07))
		_root.draw_rect(box, Color(hue, 0.6), false, maxf(1.0, 1.5 * k))
		var nfs := int(round(30.0 * k))
		_root.draw_string(font, Vector2(x + 18.0 * k, y + 44.0 * k), "p%d  %s" % [seat, CoopScreen.PROMPT[seat]], HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, hi)
		var r: Dictionary = mode.per[seat]
		var rows := [
			["kills", str(int(r.get("kills", 0)))],
			["downs", str(int(r.get("downs", 0)))],
			["revives", str(int(r.get("revives", 0)))],
			["accuracy", "%d%%  (%d shots)" % [int(round(mode.accuracy(seat) * 100.0)), mode.shots(seat)]],
		]
		var rfs := int(round(24.0 * k))
		var ry := y + 100.0 * k
		for row in rows:
			_root.draw_string(font, Vector2(x + 22.0 * k, ry), row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, rfs, Color(0.7, 0.78, 0.8))
			var vw := font.get_string_size(row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, rfs).x
			_root.draw_string(font, Vector2(box.end.x - vw - 22.0 * k, ry), row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, rfs, hi)
			ry += rfs * 1.75
	var team := lines[lines.size() - 1]
	var tfs := int(round(22.0 * k))
	var tw := font.get_string_size(team, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x
	_root.draw_string(font, Vector2(s.x * 0.5 - tw * 0.5, card.end.y - 62.0 * k), team, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, Color(1.0, 0.82, 0.45))
	var again := "Enter (or A) runs it again    Esc, Leave split-screen co-op"
	var afs := int(round(16.0 * k))
	var aw := font.get_string_size(again, HORIZONTAL_ALIGNMENT_LEFT, -1, afs).x
	_root.draw_string(font, Vector2(s.x * 0.5 - aw * 0.5, card.end.y - 24.0 * k), again, HORIZONTAL_ALIGNMENT_LEFT, -1, afs, Color(1, 1, 1, 0.6))
