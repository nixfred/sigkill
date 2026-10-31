class_name MissionHud
extends Control
## What a mission shows (C35, scripts/missions/mission_runner.gd), over the arena, drawn in the HUD's own terminal look
## and for 720 lines (larger windows draw it larger, up to SCALE_LAST):
##   the objective panel  top left, under the kill count: "MISSION 01" and the register it is in, the clock, the
##                        title; the objectives done struck through, the one running typed in with a cursor and
##                        its progress (a pip per kill, a draining bar to survive, the metres to walk); the logs
##                        found. A change flashes it and opens its corner brackets.
##   the terminal         under it: the Auditor's lines in amber and `~`'s in its red, typed in (held back under the
##                        card), fading after a while; a weapon handed over says so in teal.
##   the log reader       right of the crosshair: "$ cat <name>" and the log typed in, then it folds away.
##   the marker           where the running objective is (a reach point, a log still standing): a hexagon and the
##                        metres on screen, an arrow on the edge when it is off screen or behind.
##   the card             as it starts: the band across the screen, "MISSION 01", the title in glitched light, its
##                        register and goal.
##   the shift            a register transition: the screen tears in the new register's colour.
##   the cut              an arena reloaded by the runner (a start, a retry, the next mission, back to the Missions
##                        screen) comes in from black over CUT_S (C36), where it used to blink; and before it goes
##                        (C37) a black frame with the command typed on it ("$ login"), so a district's first build
##                        happens behind black, never as a frozen frame of the menu that started it.
## Your AI's lines go to the guide panel (GuideHud.story_line(): "your AI", one voice), each shown for a time that fits
## its length, the newest winning (C37: a waiting line gives way to it, the one on show after STORY_LEAST_MS). The end screens are scripts/hud/mission_end_screen.gd, up end_hold_s after the last
## objective (C37: the place holds a beat first). Since C37 an objective's hint is a dim line under its progress
## ("{reload}" and the like are the keys as bound), and the register chip is the world's live register in ruins (the
## place itself), so it never reads one thing while the world shows another. Cosmetic: it changes nothing.

const Palette = preload("res://scripts/palette.gd")
const Controls = preload("res://scripts/controls.gd")

const DESIGN_H := 720.0
const SCALE_LAST := 1.5
## The panel's place and width, in design pixels.
const PANEL_AT := Vector2(16, 98)
const PANEL_W := 380.0
## Characters a second: an objective typing in, a terminal line, `~`'s (slower), a log.
const TYPE_CPS := 46.0
const FEED_CPS := 72.0
const TILDE_CPS := 20.0
const LOG_CPS := 110.0
const GOAL_CPS := 120.0
## Seconds a terminal line stays (then fades over FADE_S), a log stays after it has typed, the shift shows.
const FEED_S := 8.0
const FADE_S := 1.0
const LOG_S := 6.0
const SHIFT_S := 1.8
## Seconds an arena the runner reloaded takes to come in from black.
const CUT_S := 0.35
## Where the shift's words stand, a share of the screen's height.
const SHIFT_AT := 0.36
## Where the log reader's top stands, a share of the screen's height.
const LOG_AT := 0.3
## Characters a terminal or log line wraps at.
const FEED_WRAP := 64
const LOG_WRAP := 54
const FEED_LAST := 4
const DONE_SHOWN := 2
## How dense the panels are over the arena: the grid and the skyline must not read through the words.
const PANEL_ALPHA := 0.84
## A story line's time in the guide panel: a floor and so much a character, and a cap, in ms.
const STORY_MS_FLOOR := 3200.0
const STORY_MS_PER_CHAR := 55.0
const STORY_MS_LAST := 9000.0
## A line on show this long gives way to a newer one (C37): your AI keeps up with what is happening, never a line behind.
const STORY_LEAST_MS := 1800.0
const AUDIT_PREFIX := ""
const TILDE_PREFIX := "~ $ "
const HANDED_LINE := ">> %s handed to you  [%s]"
const LOG_HEAD := "$ cat %s"
const KIND_WORDS := {"rogue": "rogue.d", "zombie": "zombie", "swarm": "runaway core", "any": "daemons"}

## The runner whose mission this shows, the guide panel your AI's lines go to, and the player (for the metres).
var runner: MissionRunner = null
var guide: Node = null
var player: Node3D = null

var _font: Font
var _k := 1.0
var _age := 0.0
var _obj_age := 0.0
var _done: Array = []
var _flash := 0.0
var _pop := 0.0
var _feed: Array = []
var _log := {}
var _log_age := -1.0
var _card_age := -1.0
var _shift := {}
var _shift_age := -1.0
var _story: Array = []
var _story_hold := 0.0
var _story_ms := 0.0
var _end_in := -1.0
var _end_kind := ""
var _end: MissionEndScreen
var _drawn := false
## How much of the cut from black is left, 1 to 0.
var _cut := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = Palette.mono_font()
	_end = MissionEndScreen.new()
	_end.name = "MissionEnd"
	add_child(_end)
	_cut = 1.0 if MissionRunner.take_fade() else 0.0


## Shows `r`'s mission from now on.
func set_runner(r: MissionRunner) -> void:
	runner = r
	_end.runner = r
	for pair in [["began", _on_began], ["objective_began", _on_objective_began], ["objective_done", _on_objective_done], ["progressed", _on_progressed], ["line_said", _on_line], ["log_found", _on_log], ["handed", _on_handed], ["register_shifted", _on_shift], ["failed", _on_failed], ["completed", _on_completed], ["ended", _on_ended]]:
		if not r.is_connected(pair[0], pair[1]):
			r.connect(pair[0], pair[1])


func end_screen() -> MissionEndScreen:
	return _end


## Every line on show, for the checks: the panel's, the terminal's, the log's and the card's, as typed so far.
func shown_text() -> PackedStringArray:
	var out := PackedStringArray()
	if not _showing():
		return out
	out.append("MISSION %s" % runner.def.number())
	out.append(runner.def.title)
	if runner.attempt > 1:
		out.append("try %d" % runner.attempt)
	for d in _done:
		out.append("[x] " + str(d["text"]))
	var o := runner.objective()
	if not o.is_empty() and runner.state == MissionRunner.State.RUNNING:
		out.append("> " + _typed(str(o["text"]), _obj_age, TYPE_CPS))
		out.append(progress_text())
		if hint_text() != "":
			out.append(hint_text())
	for line in _feed:
		out.append(_typed(str(line["prefix"]) + str(line["text"]), line["age"], line["cps"]))
	if _log_age >= 0.0:
		out.append(LOG_HEAD % str(_log.get("name", "")))
		out.append(_typed(str(_log.get("text", "")), _log_age, LOG_CPS))
	if _card_age >= 0.0:
		out.append(runner.def.goal)
	return out


## The running objective's progress in words: "rogue.d  1/2", "00:12 / 00:20", "spawn vent  14 m".
func progress_text() -> String:
	var o := runner.objective() if runner != null else {}
	match o.get("kind"):
		"kill":
			return "%s  %d/%d" % [KIND_WORDS.get(o["daemon"], o["daemon"]), int(runner.progress), int(runner.need())]
		"survive":
			return "%s / %s" % [_clock(runner.progress), _clock(runner.need())]
		"reach":
			return "%s  %d m" % [str(o.get("label", "there")), roundi(_metres_to(runner.target_point()))]
		"log":
			var entry := runner.def.log_of(str(o["log"]))
			var at := runner.target_point()
			return ("find %s  %d m" % [str(entry.get("name", "the log")), roundi(_metres_to(at))]) if at != Vector3.INF else "read"
	return ""


## The running objective's hint (C37), its "{action}" keys as bound now; "" for none.
func hint_text() -> String:
	var o := runner.objective() if runner != null else {}
	var hint := str(o.get("hint", ""))
	if hint == "":
		return ""
	for pair in Controls.REBINDABLE:
		var tag := "{%s}" % pair[0]
		if hint.contains(tag):
			hint = hint.replace(tag, Controls.bind_label(GameSettings.current().bind(pair[0])))
	return "# " + hint


## The register the panel's chip shows (C37): the world's live one in ruins, else the mission's.
func register_shown() -> String:
	if runner == null:
		return ""
	if runner.world != null and is_instance_valid(runner.world) and runner.world.register != "":
		return runner.world.register
	return runner.register


## True while the mission's card is up.
func showing_card() -> bool:
	return _card_age >= 0.0


## True while a log is open in the reader.
func showing_log() -> bool:
	return _log_age >= 0.0


## The lines waiting for the guide panel.
func story_waiting() -> int:
	return _story.size()


func _showing() -> bool:
	return runner != null and is_instance_valid(runner) and runner.def != null and runner.state != MissionRunner.State.IDLE


func _process(delta: float) -> void:
	_age += delta
	_k = clampf(get_viewport_rect().size.y / DESIGN_H, 1.0, SCALE_LAST)
	_obj_age += delta
	_flash = maxf(_flash - delta * 2.2, 0.0)
	_pop = maxf(_pop - delta * 4.0, 0.0)
	for d in _done:
		d["age"] += delta
	if _card_age < 0.0:
		for line in _feed:
			line["age"] += delta  # held back under the card: it types in as the card goes
	_feed = _feed.filter(func(line) -> bool: return line["age"] < _feed_life(line))
	if _log_age >= 0.0:
		_log_age += delta
		if _log_age > _log_life():
			_log_age = -1.0
	if _card_age >= 0.0:
		_card_age += delta
		if _card_age > MissionRunner.INTRO_S + 0.5:
			_card_age = -1.0
	if _shift_age >= 0.0:
		_shift_age += delta
		if _shift_age > SHIFT_S:
			_shift_age = -1.0
	_story_hold -= delta * 1000.0
	if not _story.is_empty() and _story_hold <= 0.0 and guide != null and is_instance_valid(guide) and guide.has_method("story_line"):
		var text: String = _story[0]
		var ms := clampf(STORY_MS_FLOOR + STORY_MS_PER_CHAR * text.length(), STORY_MS_FLOOR, STORY_MS_LAST)
		if guide.story_line(text, ms):
			_story.pop_front()
			_story_hold = ms
			_story_ms = ms
	if _end_in >= 0.0:
		_end_in -= delta
		if _end_in < 0.0:
			_show_end()
	# Drawn while a mission shows or the cut from black runs, and once more as they stop; never redrawn for nothing in
	# plain arena play.
	_cut = maxf(_cut - delta / CUT_S, 0.0)
	var showing := _showing() or _cut > 0.0 or MissionRunner.mounting() != ""
	if showing or _drawn:
		queue_redraw()
	_drawn = showing


## How much of the cut from black is left (C36): 1 as the arena comes in, 0 once it is clear.
func cut_left() -> float:
	return _cut


# --- The runner's word. ---

func _on_began(_def: MissionDef) -> void:
	_done.clear()
	_feed.clear()
	_story.clear()
	_log_age = -1.0
	_card_age = 0.0
	_shift_age = -1.0
	_end_in = -1.0
	_end.hide_screen()


func _on_objective_began(_index: int) -> void:
	_obj_age = 0.0
	_flash = 1.0


func _on_objective_done(index: int) -> void:
	_done.append({"text": runner.def.objectives[index]["text"], "age": 0.0})
	while _done.size() > DONE_SHOWN:
		_done.pop_front()
	_flash = 1.0


func _on_progressed(_index: int) -> void:
	if runner.objective().get("kind") == "kill":
		_pop = 1.0


func _on_line(who: String, text: String) -> void:
	match who:
		"ai":
			# The newest wins (C37): a line still waiting gives way to it, and the one on show once it has had its moment.
			_story = [text]
			if _story_hold > 0.0 and _story_ms - _story_hold >= STORY_LEAST_MS:
				_story_hold = 0.0
		"tilde":
			_push_feed(TILDE_PREFIX, text, Palette.CRIMSON, TILDE_CPS)
		_:
			_push_feed(AUDIT_PREFIX, text, Palette.HOSTILE_AMBER, FEED_CPS)


func _on_log(entry: Dictionary) -> void:
	_log = entry
	_log_age = 0.0


func _on_handed(weapon: String) -> void:
	for def in WeaponKit.shipped_defs():
		if def.id == weapon:
			_push_feed("", HANDED_LINE % [def.short_name, key_of(def.id)], Palette.TEAL, FEED_CPS)


func _on_shift(from: String, to: String) -> void:
	_shift = {"from": from, "to": to}
	_shift_age = 0.0
	_flash = 1.0


func _on_failed(_reason: String) -> void:
	_end_kind = "failed"
	_end_in = 1.1


func _on_completed(_result: Dictionary) -> void:
	_end_kind = "complete"
	_end_in = runner.def.end_hold_s if runner != null and runner.def != null else 1.5


func _on_ended() -> void:
	_end_in = -1.0
	_card_age = -1.0
	_log_age = -1.0
	_feed.clear()
	_story.clear()
	_end.hide_screen()


func _show_end() -> void:
	if not _showing():
		return
	if _end_kind == "complete":
		_end.show_complete()
	else:
		_end.show_failed()


func _push_feed(prefix: String, text: String, colour: Color, cps: float) -> void:
	_feed.append({"prefix": prefix, "text": text, "colour": colour, "cps": cps, "age": 0.0})
	while _feed.size() > FEED_LAST:
		_feed.pop_front()


func _feed_life(line: Dictionary) -> float:
	return (str(line["prefix"]) + str(line["text"])).length() / float(line["cps"]) + FEED_S + FADE_S


func _log_life() -> float:
	return str(_log.get("text", "")).length() / LOG_CPS + LOG_S


## The key that draws weapon `id` ("3", "Shift+2"), from its slot.
static func key_of(id: String) -> String:
	var defs := WeaponKit.shipped_defs()
	for i in defs.size():
		if defs[i].id == id:
			return str(i + 1) if i < 9 else "Shift+%d" % (i - 8)
	return ""


# --- Drawing. ---

func _draw() -> void:
	if _showing():
		_draw_mission()
	if _cut > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(Palette.VOID, _cut * _cut))
	var mount := MissionRunner.mounting()
	if mount != "":
		draw_rect(Rect2(Vector2.ZERO, size), Palette.VOID)
		var at := Vector2(28.0, size.y - 34.0)
		draw_string(_font, at, mount, HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(16 * _k), Palette.MINT)
		draw_rect(Rect2(at + Vector2(_font.get_string_size(mount, HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(16 * _k)).x + 6.0, -14.0 * _k), Vector2(9.0, 16.0) * _k), Palette.MINT)


func _draw_mission() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_k, _k))
	var view := size / _k
	if runner.state == MissionRunner.State.RUNNING:
		_draw_marker(view)
	var bottom := _draw_panel()
	if _card_age < 0.0:
		_draw_feed(Vector2(PANEL_AT.x, bottom + 12.0))
	if _log_age >= 0.0:
		_draw_log(view)
	if _card_age >= 0.0:
		_draw_card(view)
	if _shift_age >= 0.0:
		_draw_shift(view)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The objective panel; returns its bottom edge.
func _draw_panel() -> float:
	var def := runner.def
	var reg := register_colour(register_shown())
	var x := PANEL_AT.x
	var y := PANEL_AT.y
	var w := PANEL_W
	var rows := 92.0 + 18.0 * _done.size()
	if runner.state == MissionRunner.State.RUNNING:
		rows += 48.0
		if hint_text() != "":
			rows += 18.0
	elif runner.state == MissionRunner.State.INTRO:
		rows += 20.0
	else:
		rows += 26.0
	var rect := Rect2(x, y, w, rows)
	var jitter := Vector2.ZERO
	if _shift_age >= 0.0 and _shift_age < 0.45:
		jitter = Vector2(sin(_age * 91.0) * 4.0, 0.0)
	rect.position += jitter
	draw_rect(rect, Color(Palette.VOID, PANEL_ALPHA))
	draw_rect(Rect2(rect.position, Vector2(3, rect.size.y)), reg)
	# A scan line down the panel every few seconds.
	var scan := fposmod(_age * 0.33, 1.0)
	draw_rect(Rect2(rect.position + Vector2(3, rect.size.y * scan), Vector2(w - 3, 1)), Color(reg, 0.12))
	_brackets(rect.grow(2.0 + 6.0 * _flash), Color(Palette.TEAL, 0.55 + 0.45 * _flash), 12.0)
	var p := rect.position + Vector2(14, 0)
	_text(p + Vector2(0, 19), "MISSION %s" % def.number(), 11, Palette.TEAL)
	var chip := register_shown().to_upper()
	var chip_w := _width(chip, 10) + 12.0
	var clock := _clock(runner.clock)
	var clock_w := _width(clock, 13)
	var chip_x := rect.end.x - 14.0 - clock_w - 12.0 - chip_w
	draw_rect(Rect2(chip_x, p.y + 8, chip_w, 15), Color(reg, 0.18))
	draw_rect(Rect2(chip_x, p.y + 8, chip_w, 15), reg, false, 1.0)
	_text(Vector2(chip_x + 6, p.y + 19), chip, 10, reg)
	_text(Vector2(rect.end.x - 14.0 - clock_w, p.y + 20), clock, 13, Palette.MINT)
	var title_colour := Palette.MINT.lerp(Palette.FLASH, _flash * 0.6)
	_text(p + Vector2(0, 46), def.title, 22, title_colour)
	if runner.attempt > 1:
		_text(p + Vector2(_width(def.title, 22) + 10, 46), "try %d" % runner.attempt, 11, Palette.HOSTILE_AMBER)
	if def.draft:
		var tag := "draft"
		_text(Vector2(rect.end.x - 14.0 - _width(tag, 10), p.y + 44), tag, 10, Color(Palette.MINT, 0.5))
	draw_rect(Rect2(p.x, p.y + 56, w - 28, 1), Color(Palette.TEAL, 0.45))
	var row_y := p.y + 74
	for d in _done:
		var fresh := clampf(1.0 - d["age"] / 0.5, 0.0, 1.0)
		var words := _clip(str(d["text"]), 42)
		_text(Vector2(p.x, row_y), "[x]", 12, Palette.MINT.lerp(Palette.FLASH, fresh))
		var colour := Color(Palette.MINT, 0.62).lerp(Palette.FLASH, fresh * 0.8)
		_text(Vector2(p.x + 34, row_y), words, 12, colour)
		var strike := minf(d["age"] / 0.25, 1.0) * _width(words, 12)
		draw_rect(Rect2(p.x + 34, row_y - 4, strike, 1), Color(Palette.MINT, 0.45))
		row_y += 18
	match runner.state:
		MissionRunner.State.INTRO:
			_text(Vector2(p.x, row_y), _blink("> linking objectives"), 13, Color(Palette.MINT, 0.7))
		MissionRunner.State.RUNNING:
			var o := runner.objective()
			var typed := _typed(str(o["text"]), _obj_age, TYPE_CPS)
			_text(Vector2(p.x, row_y + 2), "> " + typed, 15, Palette.MINT.lerp(Palette.FLASH, _flash * 0.5))
			if typed.length() < str(o["text"]).length() or fmod(_age, 1.0) < 0.55:
				var cx := p.x + _width("> " + typed, 15) + 2.0
				draw_rect(Rect2(cx, row_y - 10, 8, 14), Color(Palette.MINT, 0.85))
			_draw_progress(Vector2(p.x + 16, row_y + 26), w - 44)
			var hint := hint_text()
			if hint != "":
				_text(Vector2(p.x + 16, row_y + 45), _clip(hint, MissionDef.HINT_LAST + 2), 11, Color(Palette.MINT, 0.55))
		MissionRunner.State.FAILED:
			_text(Vector2(p.x, row_y), "exit 137  " + runner.reason, 13, Palette.HOSTILE_RED)
		MissionRunner.State.COMPLETE:
			_text(Vector2(p.x, row_y), "exit 0  every objective done", 13, Palette.MINT)
	var foot_y := rect.end.y - 9.0
	var count := "objective %d/%d" % [mini(runner.index + 1, def.objectives.size()), def.objectives.size()]
	if runner.state == MissionRunner.State.COMPLETE:
		count = "objectives %d/%d" % [def.objectives.size(), def.objectives.size()]
	_text(Vector2(p.x, foot_y), count, 10, Color(Palette.TEAL, 0.8))
	if not def.logs.is_empty():
		var logs := "logs %d/%d" % [runner.logs_found.size(), def.logs.size()]
		_text(Vector2(rect.end.x - 14.0 - _width(logs, 10), foot_y), logs, 10, Color(Palette.TEAL, 0.8))
	return rect.end.y


func _draw_progress(at: Vector2, w: float) -> void:
	var o := runner.objective()
	var words := progress_text()
	match o.get("kind"):
		"kill":
			var need := int(runner.need())
			var got := int(runner.progress)
			var pip := clampf((w - 150.0) / float(need), 6.0, 14.0)
			for i in need:
				var r := Rect2(at.x + i * (pip + 3.0), at.y - 10, pip, 10)
				if i < got:
					var grow := _pop * 3.0 if i == got - 1 else 0.0
					draw_rect(r.grow(grow), Palette.MINT.lerp(Palette.FLASH, _pop if i == got - 1 else 0.0))
				else:
					draw_rect(r, Color(Palette.TEAL, 0.7), false, 1.0)
			_text(Vector2(at.x + need * (pip + 3.0) + 8.0, at.y), words, 12, Palette.MINT)
		"survive":
			var share := clampf(runner.progress / runner.need(), 0.0, 1.0)
			var bar := w - 130.0
			draw_rect(Rect2(at.x, at.y - 8, bar, 6), Color(Palette.TEAL, 0.25))
			draw_rect(Rect2(at.x, at.y - 8, bar * share, 6), Palette.MINT)
			draw_rect(Rect2(at.x + bar * share - 1.0, at.y - 11, 2, 12), Palette.FLASH)
			_text(Vector2(at.x + bar + 10.0, at.y), words, 12, Palette.MINT)
		_:
			var arrow := _arrow_word()
			_text(at, words + ("  " + arrow if arrow != "" else ""), 12, Palette.MINT)


## The terminal: the Auditor's and `~`'s lines, a weapon handed over.
func _draw_feed(at: Vector2) -> void:
	var y := at.y
	for line in _feed:
		var full: String = str(line["prefix"]) + str(line["text"])
		var typed := _typed(full, line["age"], line["cps"])
		var life := _feed_life(line)
		var alpha := clampf((life - float(line["age"])) / FADE_S, 0.0, 1.0)
		var colour: Color = line["colour"]
		for part in _wrap(typed, FEED_WRAP):
			y += 16.0
			var w := _width(part, 12)
			draw_rect(Rect2(at.x, y - 12, w + 10, 16), Color(Palette.VOID, PANEL_ALPHA * alpha))
			_text(Vector2(at.x + 5, y), part, 12, Color(colour, alpha))
		if typed.length() < full.length() or (line["prefix"] == TILDE_PREFIX and fmod(_age, 0.8) < 0.45):
			var last: String = _wrap(typed, FEED_WRAP)[-1] if typed != "" else ""
			draw_rect(Rect2(at.x + 6 + _width(last, 12), y - 11, 7, 13), Color(colour, alpha))
		y += 4.0


func _draw_log(view: Vector2) -> void:
	var text := str(_log.get("text", ""))
	var lines := PackedStringArray()
	for raw in text.split("\n"):
		lines.append_array(_wrap(raw, LOG_WRAP))
	var w := 440.0
	var h := 44.0 + 18.0 * lines.size()
	var life := _log_life()
	var open := clampf(_log_age / 0.22, 0.0, 1.0)
	var close := clampf((life - _log_age) / 0.3, 0.0, 1.0)
	var k := minf(open, close)
	# Right of the crosshair, under the guide's corner and the unlock toast's strip: the objective panel and the
	# terminal keep the left.
	var at := Vector2(view.x - w - 18.0 + (1.0 - open) * 40.0, view.y * LOG_AT)
	var rect := Rect2(at, Vector2(w, h * k))
	draw_rect(rect, Color(Palette.VOID, 0.9))
	draw_rect(Rect2(at, Vector2(w, 22 * k)), Color(Palette.MINT, 0.16))
	draw_rect(rect, Color(Palette.MINT, 0.9), false, 1.0)
	if k < 0.6:
		return
	for i in 3:
		draw_circle(at + Vector2(12 + i * 13, 11), 3.5, Color(Palette.MINT, 0.5 - i * 0.12))
	_text(at + Vector2(52, 16), LOG_HEAD % str(_log.get("name", "")), 12, Palette.MINT)
	var typed := _typed(text, _log_age, LOG_CPS)
	var left := typed.length()
	var y := at.y + 42.0
	var shown_lines := PackedStringArray()
	for raw in text.split("\n"):
		shown_lines.append_array(_wrap(raw, LOG_WRAP))
	for line in shown_lines:
		if left <= 0:
			break
		var part := line.left(left)
		left -= line.length() + 1
		_text(Vector2(at.x + 14, y), part, 13, Palette.MATRIX_HEAD)
		y += 18.0
	if fmod(_age, 0.9) < 0.5:
		draw_rect(Rect2(at.x + 14, y - 13, 8, 14), Color(Palette.MINT, 0.8))


## Where the running objective is: on screen a hexagon and the metres, off it (or behind) an arrow on the edge.
func _draw_marker(view: Vector2) -> void:
	var point := runner.target_point()
	var camera := get_viewport().get_camera_3d()
	if point == Vector3.INF or camera == null:
		return
	var aim := point + Vector3(0, 0.6, 0)
	if camera.global_position.distance_to(aim) < 0.3:
		return  # standing on it: nothing to point at (and no point to project)
	var metres := "%d m" % roundi(_metres_to(point))
	# Behind, or on the camera's own plane (straight under it as it falls, C37): pointed at from its place in the
	# camera's space, never projected (a point on that plane has no place on the screen).
	var local := camera.global_transform.affine_inverse() * aim
	var behind := local.z > -0.05
	var screen := camera.unproject_position(aim) / _k if not behind else view * 0.5
	var margin := 46.0
	var inside := Rect2(Vector2(margin, margin), view - Vector2(margin, margin) * 2.0)
	var pulse := 0.5 + 0.5 * sin(_age * TAU * 1.2)
	if not behind and inside.has_point(screen):
		var r := 13.0 + 3.0 * pulse
		var pts := PackedVector2Array()
		for i in 7:
			var a := TAU * float(i) / 6.0 + PI / 6.0
			pts.append(screen + Vector2(cos(a), sin(a)) * r)
		draw_polyline(pts, Color(Palette.TEAL, 0.9), 2.0)
		draw_circle(screen, 2.5, Palette.FLASH)
		_text(screen + Vector2(-_width(metres, 12) * 0.5, r + 16), metres, 12, Palette.MINT)
		return
	var centre := view * 0.5
	var dir := (screen - centre) if not behind else Vector2(local.x, -local.y)
	if dir.length() < 0.01:
		dir = Vector2(0, 1)
	dir = dir.normalized()
	var reach := minf(absf((inside.size.x * 0.5) / dir.x) if absf(dir.x) > 0.001 else INF, absf((inside.size.y * 0.5) / dir.y) if absf(dir.y) > 0.001 else INF)
	var tip := centre + dir * reach
	var side := Vector2(-dir.y, dir.x)
	var tri := PackedVector2Array([tip + dir * 14.0, tip - dir * 4.0 + side * 10.0, tip - dir * 4.0 - side * 10.0])
	draw_colored_polygon(tri, Color(Palette.TEAL, 0.7 + 0.3 * pulse))
	_text(tip - dir * 26.0 - Vector2(_width(metres, 12) * 0.5, -4), metres, 12, Palette.MINT)


func _draw_card(view: Vector2) -> void:
	var def := runner.def
	var t := _card_age
	var end := MissionRunner.INTRO_S + 0.5
	var alpha := clampf(t / 0.15, 0.0, 1.0) * clampf((end - t) / 0.45, 0.0, 1.0)
	var reg := register_colour(def.register)
	var band_h := 178.0
	var top := view.y * 0.30
	draw_rect(Rect2(0, top, view.x, band_h), Color(Palette.VOID, 0.88 * alpha))
	draw_rect(Rect2(0, top - 18, view.x, 18), Color(Palette.VOID, 0.4 * alpha))
	draw_rect(Rect2(0, top + band_h, view.x, 18), Color(Palette.VOID, 0.4 * alpha))
	var sweep := fposmod(t * 0.9, 1.0) * view.x
	draw_rect(Rect2(sweep - 120.0, top + 2, 240.0, band_h - 4), Color(reg, 0.05 * alpha))
	var spread := clampf(t / 0.5, 0.0, 1.0) * view.x * 0.5
	for edge in [top, top + band_h]:
		draw_rect(Rect2(view.x * 0.5 - spread, edge, spread * 2.0, 1.5), Color(reg, 0.9 * alpha))
	var head := " ".join(("MISSION " + def.number()).split(""))
	_centred(view.x * 0.5, top + 38, head, 14, Color(Palette.TEAL, alpha))
	var title_size := 64
	var title := def.title
	if t < 0.5:
		var slip := (0.5 - t) * 26.0
		_centred(view.x * 0.5 + sin(t * 97.0) * slip, top + 108, title, title_size, Color(Palette.GLITCH_SPLIT, 0.55 * alpha))
		_centred(view.x * 0.5 - cos(t * 71.0) * slip, top + 108, title, title_size, Color(Palette.TEAL, 0.55 * alpha))
	for glow in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
		_centred(view.x * 0.5 + glow.x, top + 108 + glow.y, title, title_size, Color(reg, 0.22 * alpha))
	_centred(view.x * 0.5, top + 108, title, title_size, Color(Palette.MINT.lerp(Palette.FLASH, clampf(1.0 - t * 2.0, 0.0, 1.0)), alpha))
	var sub := "register: %s%s" % [def.register, ("   try %d" % runner.attempt) if runner.attempt > 1 else ""]
	_centred(view.x * 0.5, top + 136, sub, 12, Color(reg, alpha))
	_centred(view.x * 0.5, top + 160, _typed(def.goal, maxf(t - 0.3, 0.0), GOAL_CPS), 14, Color(Palette.MINT, 0.9 * alpha))


func _draw_shift(view: Vector2) -> void:
	var t := _shift_age / SHIFT_S
	var to := str(_shift.get("to", ""))
	var colour := register_colour(to)
	draw_rect(Rect2(Vector2.ZERO, view), Color(colour, 0.16 * (1.0 - t)))
	if t < 0.4:
		var seed := int(_shift_age * 30.0)
		for i in 12:
			var h := 2.0 + float((seed * 31 + i * 17) % 13)
			var y := float((seed * 53 + i * 97) % int(maxf(view.y, 1.0)))
			var x := float((seed * 11 + i * 29) % 140) - 70.0
			draw_rect(Rect2(x, y, view.x, h), Color(colour, 0.32 * (1.0 - t / 0.4)))
	var alpha := clampf((1.0 - t) * 2.0, 0.0, 1.0)
	# Above the crosshair and under the unlock toast's strip, which a mission's end can bring at the same moment.
	_centred(view.x * 0.5, view.y * SHIFT_AT, "REGISTER SHIFT", 12, Color(Palette.MINT, alpha))
	_centred(view.x * 0.5, view.y * SHIFT_AT + 34, "%s  >>  %s" % [_shift.get("from", ""), to], 28, Color(colour, alpha))


# --- Helpers. ---

## The colour of register `register` (STORY.md section 1): the grid's teal, the rain's green, the ruins' neon pink.
static func register_colour(register: String) -> Color:
	match register:
		"matrix":
			return Palette.MATRIX_GREEN
		"cyberpunk":
			return Palette.ROSE
		"all":
			return Palette.FLASH
	return Palette.TEAL


static func _clock(seconds: float) -> String:
	var s := maxi(floori(seconds), 0)
	return "%02d:%02d" % [s / 60, s % 60]


static func _typed(text: String, age: float, cps: float) -> String:
	return text.left(clampi(floori(age * cps), 0, text.length()))


static func _clip(text: String, last: int) -> String:
	return text if text.length() <= last else text.left(last - 3) + "..."


## `text` cut into lines of at most `width` characters, at spaces where it can.
static func _wrap(text: String, width: int) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for whole in text.split(" "):
		var word := whole
		while word.length() > width:
			if line != "":
				out.append(line)
				line = ""
			out.append(word.left(width))
			word = word.substr(width)
		if line == "":
			line = word
		elif line.length() + 1 + word.length() <= width:
			line += " " + word
		else:
			out.append(line)
			line = word
	out.append(line)
	return out


func _blink(text: String) -> String:
	return text + ("_" if fmod(_age, 0.8) < 0.45 else " ")


func _metres_to(point: Vector3) -> float:
	if point == Vector3.INF or player == null or not is_instance_valid(player):
		return 0.0
	var here := player.global_position
	return Vector2(here.x - point.x, here.z - point.z).length()


## Which way to turn for the running objective's point, as an arrow: ahead, left, right or behind.
func _arrow_word() -> String:
	var point := runner.target_point()
	if point == Vector3.INF or player == null or not is_instance_valid(player):
		return ""
	var to := point - player.global_position
	to.y = 0.0
	if to.length() < 0.5:
		return ""
	var facing := -player.global_transform.basis.z
	facing.y = 0.0
	var angle := rad_to_deg(facing.signed_angle_to(to.normalized(), Vector3.UP))
	if absf(angle) < 30.0:
		return "^"
	if absf(angle) > 135.0:
		return "v"
	return "<" if angle > 0.0 else ">"


func _text(at: Vector2, text: String, size: int, colour: Color) -> void:
	draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(Palette.VOID, colour.a * 0.9))
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)


func _centred(cx: float, y: float, text: String, size: int, colour: Color) -> void:
	_text(Vector2(cx - _width(text, size) * 0.5, y), text, size, colour)


func _width(text: String, size: int) -> float:
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func _brackets(rect: Rect2, colour: Color, arm: float) -> void:
	for corner in [[rect.position, Vector2(1, 1)], [Vector2(rect.end.x, rect.position.y), Vector2(-1, 1)], [Vector2(rect.position.x, rect.end.y), Vector2(1, -1)], [rect.end, Vector2(-1, -1)]]:
		var at: Vector2 = corner[0]
		var d: Vector2 = corner[1]
		draw_line(at, at + Vector2(arm * d.x, 0), colour, 1.5)
		draw_line(at, at + Vector2(0, arm * d.y), colour, 1.5)
