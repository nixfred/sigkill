class_name MissionsScreen
extends Control
## The Missions screen (C35), from the Esc menu's Missions (no key of its own): the campaign's seven missions
## (scripts/missions/mission_book.gd) as a listing, `$ ls -l /campaign`, beside the one chosen. Drawn, not a form: the
## void, the frame's brackets, and for each mission its permissions, its number and title, its register, the weapons
## it hands out in each weapon's own light and where it stands: DONE (with its best), NEXT, IN PRODUCTION (open, not
## built yet) or LOCKED. A locked mission's title and goal are redacted bars ("???"), so nothing of the story shows
## before its mission (STORY.md); only the weapons it hands out are told. On the right the chosen one: its number,
## its title typing in, a live window on its register (the grid racing in, the rain falling, the ruins' neon in the
## rain), its goal, what it teaches, and START (REPLAY once done) when it can be played.
##
## Up and Down choose, Enter starts, Esc goes back; the mouse chooses and clicks START (a double click on a row
## starts it). Alone only: in a match the Esc menu's entry is greyed out and nothing starts. Everything on one
## screen, no scroll (Law 17), shrunk whole to fit a small window. Starting one hands its id to the Esc menu
## (started), which queues it and reloads the arena into it (scripts/missions/mission_runner.gd).

signal closed
signal started(id: String)

const Palette = preload("res://scripts/palette.gd")

const TITLE := "SIGKILL // missions"
const LS := "$ ls -l /campaign"
const KEYS := "Up/Down choose   Enter start   Esc back"
const SOLO_NOTE := "solo: missions never run in a match"
const ONLINE_NOTE := "a match is on: missions are solo"
const DONE := "DONE"
const NEXT := "NEXT"
const LOCKED := "LOCKED"
const LATER := "IN PRODUCTION"
const START := "START  >"
const REPLAY := "REPLAY  >"
const LOCKED_WHY := "locked: finish mission %s first"
const LATER_WHY := "open, and not built yet: a later build brings it"
const DRAFT_WHY := "a first cut on today's arena: the full mission lands in a later build"
const REDACTED := "???"
const TEACHES := "TEACHES"
const GLYPHS := "0123456789ABCDEF<>/|$#%&*+=-:;"
## The drawing's size, scaled whole to the window (up to SCALE_LAST).
const DESIGN := Vector2(1080, 600)
const SCALE_LAST := 1.7
const EDGE := 8.0
const LIST_X := 24.0
const LIST_W := 590.0
const ROW_Y := 74.0
const ROW_H := 64.0
const PANE_X := 640.0
const PANE_W := 416.0
const PREVIEW := Rect2(640, 140, 416, 150)
const START_RECT := Rect2(640, 506, 416, 46)
## Seconds: a row sliding in after the one above it, the title typing in.
const STAGGER_S := 0.05
const TYPE_CPS := 28.0

## The progress shown (null: MissionProgress.current()), the session (greyed in a match), the player.
var progress: MissionProgress = null
var session: Node = null
var player: Node = null
## The mission chosen, by its place in the list.
var selected := 0

var _defs: Array = []
var _font: Font
var _age := 0.0
var _open_age := 0.0
var _pick_age := 0.0
var _bar_y := ROW_Y
var _hover := -1
var _origin := Vector2.ZERO
var _k := 1.0


func _ready() -> void:
	if progress == null:
		progress = MissionProgress.current()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_font = Palette.mono_font()
	_defs = MissionBook.campaign()
	visible = false


## Up, the next mission to play chosen (or the first).
func open() -> void:
	_defs = MissionBook.campaign()
	var up := progress.next_up()
	selected = maxi(_defs.find(up), 0) if up != null else 0
	_bar_y = ROW_Y + selected * ROW_H
	_layout()
	_open_age = 0.0
	_pick_age = 0.0
	visible = true
	grab_focus()
	queue_redraw()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


## Chooses mission `index` (its place in the list).
func select(index: int) -> void:
	var was := selected
	selected = clampi(index, 0, _defs.size() - 1)
	if selected != was:
		_pick_age = 0.0
	queue_redraw()


## Where mission `def` stands: "done", "next", "later" (open, not built yet), "locked".
func status_of(def: MissionDef) -> String:
	if progress.is_done(def.id):
		return "done"
	if not progress.is_open(def):
		return "locked"
	return "next" if def.playable else "later"


## True when mission `index` can be started now: open, built, and no match on.
func can_start(index: int) -> bool:
	if index < 0 or index >= _defs.size() or _online():
		return false
	var def: MissionDef = _defs[index]
	return def.playable and progress.is_open(def)


## Starts the chosen mission (started, then closed). False when it cannot be started.
func start_selected() -> bool:
	if not can_start(selected):
		return false
	var id: String = _defs[selected].id
	visible = false
	started.emit(id)
	return true


## A row's rectangle on screen, for the mouse and the checks.
func row_rect(index: int) -> Rect2:
	return Rect2(_origin + Vector2(LIST_X, ROW_Y + index * ROW_H) * _k, Vector2(LIST_W, ROW_H - 6.0) * _k)


func start_rect() -> Rect2:
	return Rect2(_origin + START_RECT.position * _k, START_RECT.size * _k)


## The whole drawing's rectangle on screen.
func frame_rect() -> Rect2:
	return Rect2(_origin, DESIGN * _k)


## Every text it shows, for the checks.
func texts() -> PackedStringArray:
	var out := PackedStringArray([TITLE, LS])
	for i in _defs.size():
		var def: MissionDef = _defs[i]
		var status := status_of(def)
		out.append("%s %s %s" % [def.number(), REDACTED if status == "locked" else def.title, _status_word(status)])
	var chosen: MissionDef = _defs[selected]
	out.append(_goal_of(chosen))
	out.append(_start_word(selected))
	return out


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close()
		KEY_UP, KEY_DOWN:
			get_viewport().set_input_as_handled()
			select(posmod(selected + (1 if key.keycode == KEY_DOWN else -1), _defs.size()))
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			get_viewport().set_input_as_handled()
			start_selected()


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		_hover = _row_at(motion.position)
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if start_rect().has_point(click.position):
		start_selected()
		return
	var row := _row_at(click.position)
	if row >= 0:
		select(row)
		if click.double_click:
			start_selected()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event is InputEventKey or event is InputEventMouseButton):
		get_viewport().set_input_as_handled()


func _row_at(at: Vector2) -> int:
	for i in _defs.size():
		if row_rect(i).has_point(at):
			return i
	return -1


func _online() -> bool:
	return session != null and is_instance_valid(session) and session.has_method("is_online") and session.is_online()


func _process(delta: float) -> void:
	if not visible:
		return
	_age += delta
	_open_age += delta
	_pick_age += delta
	_bar_y = lerpf(_bar_y, ROW_Y + selected * ROW_H, clampf(delta * 14.0, 0.0, 1.0))
	_layout()
	queue_redraw()


## Its scale and place for the window: the drawing whole, centred, as large as fits (up to SCALE_LAST).
func _layout() -> void:
	var view := get_viewport_rect().size
	_k = clampf(minf((view.x - 2.0 * EDGE) / DESIGN.x, (view.y - 2.0 * EDGE) / DESIGN.y), 0.2, SCALE_LAST)
	_origin = ((view - DESIGN * _k) * 0.5).floor()


# --- Drawing. ---

func _draw() -> void:
	if not visible or _defs.is_empty():
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(Palette.VOID, 0.9))
	draw_set_transform(_origin, 0.0, Vector2(_k, _k))
	var frame := Rect2(Vector2.ZERO, DESIGN)
	draw_rect(frame, Color(Palette.BASE, 0.96))
	var scan := fposmod(_age * 0.12, 1.0) * DESIGN.y
	draw_rect(Rect2(0, scan, DESIGN.x, 1), Color(Palette.TEAL, 0.07))
	draw_rect(frame, Color(Palette.TEAL, 0.5), false, 1.0)
	_brackets(frame.grow(4.0), Palette.TEAL, 18.0)
	_draw_head()
	for i in _defs.size():
		_draw_row(i)
	_draw_pane()
	var foot := _online()
	_text(Vector2(LIST_X, DESIGN.y - 14), KEYS, 11, Color(Palette.MINT, 0.6))
	var note := ONLINE_NOTE if foot else SOLO_NOTE
	_text(Vector2(LIST_X + 330, DESIGN.y - 14), note, 11, Palette.HOSTILE_AMBER if foot else Color(Palette.TEAL, 0.7))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_head() -> void:
	_text(Vector2(LIST_X, 36), TITLE, 18, Palette.TEAL)
	var typed := LS.left(clampi(floori(_open_age * 30.0), 0, LS.length()))
	var at := Vector2(LIST_X + _width(TITLE, 18) + 26, 35)
	_text(at, typed, 13, Palette.MINT)
	if fmod(_age, 0.9) < 0.5:
		draw_rect(Rect2(at.x + _width(typed, 13) + 3, at.y - 11, 8, 14), Color(Palette.MINT, 0.85))
	var done := 0
	for def in _defs:
		done += 1 if progress.is_done(def.id) else 0
	var count := "%d/%d done" % [done, _defs.size()]
	var seg := 26.0
	var right := DESIGN.x - 24.0
	var bar_x := right - _defs.size() * (seg + 4.0)
	for i in _defs.size():
		var def: MissionDef = _defs[i]
		var r := Rect2(bar_x + i * (seg + 4.0), 26, seg, 7)
		var status := status_of(def)
		if status == "done":
			draw_rect(r, Palette.MINT)
		elif status == "next" or status == "later":
			draw_rect(r, Color(Palette.HOSTILE_AMBER, 0.35 + 0.35 * _pulse()))
		else:
			draw_rect(r, Color(Palette.TEAL, 0.4), false, 1.0)
	_text(Vector2(bar_x - _width(count, 12) - 12, 35), count, 12, Palette.MINT)
	draw_rect(Rect2(LIST_X, 52, DESIGN.x - 2 * LIST_X, 1), Color(Palette.TEAL, 0.4))


func _draw_row(i: int) -> void:
	var def: MissionDef = _defs[i]
	var status := status_of(def)
	var e := clampf((_open_age - i * STAGGER_S) / 0.22, 0.0, 1.0)
	var slide := (1.0 - e) * -36.0
	var y := ROW_Y + i * ROW_H
	var rect := Rect2(LIST_X + slide, y, LIST_W, ROW_H - 6.0)
	var reg := MissionHud.register_colour(def.register)
	var locked := status == "locked"
	if i == _hover and i != selected:
		draw_rect(rect, Color(Palette.TEAL, 0.06 * e))
	if i == selected:
		var bar := Rect2(LIST_X, _bar_y, LIST_W, ROW_H - 6.0)
		draw_rect(bar, Color(reg if not locked else Palette.TEAL, 0.13))
		draw_rect(Rect2(bar.position, Vector2(3, bar.size.y)), reg if not locked else Color(Palette.TEAL, 0.6))
		_brackets(bar.grow(2.0), Color(Palette.MINT, 0.8), 9.0)
	var a := e
	var perm := "drwx------" if not locked else "d---------"
	_text(Vector2(rect.position.x + 12, y + 24), perm, 11, Color(Palette.TEAL, (0.75 if not locked else 0.35) * a))
	_text(Vector2(rect.position.x + 104, y + 27), def.number(), 22, Color(Palette.MINT if not locked else Palette.TEAL, (1.0 if not locked else 0.45) * a))
	var title_x := rect.position.x + 150
	if locked:
		_redacted(Vector2(title_x, y + 10), maxf(_width(def.title, 20), 70.0), 20.0, a, i)
	else:
		_text(Vector2(title_x, y + 27), def.title, 20, Color(Palette.MINT if status != "done" else Palette.MINT.lerp(Palette.FLASH, 0.3), a))
	# What it hands out, in each weapon's own light; a locked one's too: weapons are no spoiler.
	var cx := title_x
	for w in def.grants:
		var name := MissionEndScreen.short_of(w)
		var wdef := MissionEndScreen.def_of(w)
		var beam: Color = wdef.skin_beam() if wdef != null else Palette.MINT
		_text(Vector2(cx, y + 47), "+" + name, 10, Color(beam, (0.9 if not locked else 0.45) * a))
		cx += _width("+" + name, 10) + 10.0
	if def.grants.is_empty():
		_text(Vector2(cx, y + 47), "everything you have", 10, Color(Palette.MINT, 0.45 * a))
	var chip := def.register.to_upper()
	var chip_w := _width(chip, 10) + 12.0
	var chip_x := rect.end.x - 196.0
	draw_rect(Rect2(chip_x, y + 14, chip_w, 15), Color(reg, 0.16 * a))
	draw_rect(Rect2(chip_x, y + 14, chip_w, 15), Color(reg, (0.9 if not locked else 0.4) * a), false, 1.0)
	_text(Vector2(chip_x + 6, y + 25), chip, 10, Color(reg, (1.0 if not locked else 0.45) * a))
	var word := _status_word(status)
	var colour := _status_colour(status)
	if status == "next":
		colour = colour.lerp(Palette.FLASH, 0.35 * _pulse())
	_text(Vector2(rect.end.x - 12.0 - _width(word, 12), y + 25), word, 12, Color(colour, a))
	var detail := ""
	if status == "done" and progress.best_s.has(def.id):
		detail = "best " + MissionEndScreen.clock_text(progress.best_s[def.id])
	elif status == "next" and def.draft:
		detail = "first cut"
	if detail != "":
		_text(Vector2(rect.end.x - 12.0 - _width(detail, 10), y + 44), detail, 10, Color(Palette.MINT, 0.6 * a))


func _draw_pane() -> void:
	var def: MissionDef = _defs[selected]
	var status := status_of(def)
	var locked := status == "locked"
	var reg := MissionHud.register_colour(def.register)
	var x := PANE_X
	var head := " ".join(("MISSION " + def.number()).split(""))
	_text(Vector2(x, 84), head, 12, Palette.TEAL)
	var chip := def.register.to_upper()
	var chip_w := _width(chip, 10) + 12.0
	draw_rect(Rect2(x + PANE_W - chip_w, 72, chip_w, 15), Color(reg, 0.18))
	draw_rect(Rect2(x + PANE_W - chip_w, 72, chip_w, 15), reg, false, 1.0)
	_text(Vector2(x + PANE_W - chip_w + 6, 83), chip, 10, reg)
	if locked:
		_redacted(Vector2(x, 98), 220.0, 30.0, 1.0, selected + 20)
		_text(Vector2(x + 232, 124), REDACTED, 24, Color(Palette.HOSTILE_RED, 0.7))
	else:
		var typed := def.title.left(clampi(floori(_pick_age * TYPE_CPS) + 1, 0, def.title.length()))
		if _pick_age < 0.3:
			var slip := (0.3 - _pick_age) * 30.0
			_text(Vector2(x + slip, 126), typed, 34, Color(Palette.GLITCH_SPLIT, 0.5))
			_text(Vector2(x - slip, 126), typed, 34, Color(Palette.TEAL, 0.5))
		_text(Vector2(x, 126), typed, 34, Palette.MINT)
	_draw_preview(PREVIEW, def, locked)
	var y := 318.0
	for line in MissionHud._wrap(_goal_of(def), 46):
		_text(Vector2(x, y), line, 14, Color(Palette.MINT, 0.95 if not locked else 0.5))
		y += 19.0
	y = maxf(y + 10.0, 386.0)
	_text(Vector2(x, y), TEACHES, 11, Palette.TEAL)
	y += 8.0
	var cx := x
	var cy := y
	for w in def.grants:
		var wdef := MissionEndScreen.def_of(w)
		var beam: Color = wdef.skin_beam() if wdef != null else Palette.MINT
		var words := MissionEndScreen.short_of(w)
		var cw := _width(words, 12) + 16.0
		if cx + cw > x + PANE_W:
			cx = x
			cy += 28.0
		draw_rect(Rect2(cx, cy, cw, 22), Color(beam, 0.13))
		draw_rect(Rect2(cx, cy, cw, 22), Color(beam, 0.85), false, 1.0)
		_text(Vector2(cx + 8, cy + 16), words, 12, beam)
		cx += cw + 8.0
	for ability in def.abilities:
		var cw := _width(ability, 12) + 16.0
		if cx + cw > x + PANE_W:
			cx = x
			cy += 28.0
		draw_rect(Rect2(cx, cy, cw, 22), Color(Palette.MINT, 0.6), false, 1.0)
		_text(Vector2(cx + 8, cy + 16), ability, 12, Palette.MINT)
		cx += cw + 8.0
	if def.grants.is_empty() and def.abilities.is_empty():
		_text(Vector2(cx, cy + 16), "nothing new: everything you have", 12, Color(Palette.MINT, 0.7))
	var why := ""
	match status:
		"done":
			why = "DONE   best %s   logs %d/%d" % [MissionEndScreen.clock_text(progress.best_s.get(def.id, 0.0)), int(progress.best_logs.get(def.id, 0)), def.logs.size()]
		"next":
			why = DRAFT_WHY if def.draft else "NEXT UP"
		"later":
			why = LATER_WHY
		"locked":
			why = LOCKED_WHY % ("%02d" % (def.order - 1))
	var why_lines := MissionHud._wrap(why, 52)
	var why_y := START_RECT.position.y - 12.0 - 14.0 * (why_lines.size() - 1)
	for line in why_lines:
		_text(Vector2(x, why_y), line, 11, _status_colour(status))
		why_y += 14.0
	var r := START_RECT
	var ok := can_start(selected)
	if ok:
		var glow := 0.5 + 0.5 * _pulse()
		for i in 3:
			draw_rect(r.grow(2.0 + i * 3.0), Color(Palette.TEAL, 0.08 * glow * (3 - i)), false, 2.0)
		draw_rect(r, Color(Palette.TEAL, 0.88))
	else:
		draw_rect(r, Color(Palette.VOID, 0.9))
		draw_rect(r, Color(Palette.TEAL, 0.35), false, 1.0)
	var word := _start_word(selected)
	_text(r.position + Vector2((r.size.x - _width(word, 16)) * 0.5, 30), word, 16, Palette.VOID if ok else Color(Palette.MINT, 0.4))


## A live window on register `def.register`: the grid racing in, the rain falling, the ruins' neon in the rain, or
## (`locked`) no signal.
func _draw_preview(r: Rect2, def: MissionDef, locked: bool) -> void:
	draw_rect(r, Palette.VOID)
	var reg := def.register
	if locked:
		var seed := int(_age * 12.0)
		for i in 60:
			var px := r.position.x + float((seed * 37 + i * 101) % int(r.size.x))
			var py := r.position.y + float((seed * 53 + i * 67) % int(r.size.y))
			draw_rect(Rect2(px, py, 3 + (i % 5), 2), Color(Palette.TEAL, 0.12 + 0.1 * float(i % 3)))
		_text(r.position + Vector2(r.size.x * 0.5 - _width("NO SIGNAL", 14) * 0.5, r.size.y * 0.55), "NO SIGNAL", 14, Color(Palette.HOSTILE_RED, 0.6 + 0.3 * _pulse()))
	else:
		if reg == "all":
			reg = ["tron", "matrix", "cyberpunk"][int(_age / 1.4) % 3]
		match reg:
			"matrix":
				_preview_rain(r)
			"cyberpunk":
				_preview_ruins(r)
			_:
				_preview_grid(r)
	draw_rect(r, Color(MissionHud.register_colour(def.register), 0.8), false, 1.0)
	_brackets(r.grow(3.0), Color(Palette.MINT, 0.5), 8.0)


func _preview_grid(r: Rect2) -> void:
	var horizon := r.position.y + r.size.y * 0.38
	var vp := Vector2(r.position.x + r.size.x * 0.5, horizon)
	for i in 5:
		draw_rect(Rect2(r.position.x, horizon - 2.0 - i * 5.0, r.size.x, 5), Color(Palette.TEAL, 0.07 - i * 0.012))
	draw_rect(Rect2(r.position.x, horizon - 1, r.size.x, 2), Color(Palette.TEAL, 0.9))
	for i in range(-10, 11):
		var foot := Vector2(vp.x + i * r.size.x * 0.12, r.end.y)
		# Cut where it leaves the window's side: no line drawn past the preview's frame.
		var end := foot
		if foot.x < r.position.x or foot.x > r.end.x:
			var edge := r.position.x if foot.x < r.position.x else r.end.x
			end = vp.lerp(foot, (edge - vp.x) / (foot.x - vp.x))
		draw_line(vp, end, Color(Palette.TEAL, 0.35), 1.0)
	for j in 9:
		var t := fposmod(float(j) / 9.0 + _age * 0.35, 1.0)
		var y := horizon + (r.end.y - horizon) * t * t
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(Palette.TEAL, 0.15 + 0.6 * t), 1.0)
	for i in 5:
		var bx := r.position.x + 30.0 + i * 82.0
		var bh := 18.0 + float((i * 37) % 30)
		draw_rect(Rect2(bx, horizon - bh, 26, bh), Color(Palette.TEAL, 0.5), false, 1.0)
	var streak := fposmod(_age * 0.6, 1.0)
	var sy := horizon + (r.end.y - horizon) * 0.7
	draw_line(Vector2(r.position.x + r.size.x * streak - 60, sy), Vector2(r.position.x + r.size.x * streak, sy), Palette.MINT, 2.0)


func _preview_rain(r: Rect2) -> void:
	var cols := int(r.size.x / 13.0)
	for c in cols:
		var speed := 40.0 + float((c * 53) % 70)
		var head := fposmod(_age * speed + float((c * 97) % 200), r.size.y + 90.0)
		for g in 9:
			var gy := head - g * 13.0
			if gy < 12.0 or gy > r.size.y - 2.0:
				continue
			var ch := GLYPHS[(c * 7 + g * 3 + int(_age * 6.0)) % GLYPHS.length()]
			var colour := Palette.MATRIX_HEAD if g == 0 else Color(Palette.MATRIX_GREEN, 0.85 - g * 0.09)
			_text(Vector2(r.position.x + 4 + c * 13.0, r.position.y + gy), ch, 12, colour)


func _preview_ruins(r: Rect2) -> void:
	var base := r.end.y - 22.0
	for i in 9:
		var bw := 30.0 + float((i * 29) % 24)
		var bh := 40.0 + float((i * 47) % 70)
		var bx := r.position.x + 6.0 + i * 45.0
		draw_rect(Rect2(bx, base - bh, bw, bh), Color(Palette.BASE.lightened(0.04), 1.0))
		draw_rect(Rect2(bx, base - bh, bw, bh), Color(Palette.TEAL, 0.18), false, 1.0)
		var on := fmod(_age * (1.3 + i * 0.37) + i, 3.0) > 0.25
		var sign_colour := Palette.ROSE if i % 2 == 0 else Palette.HOSTILE_AMBER
		if on:
			draw_rect(Rect2(bx + 5, base - bh + 10, bw - 10, 6), Color(sign_colour, 0.85))
			draw_rect(Rect2(bx + 5, base + 6, bw - 10, 3), Color(sign_colour, 0.3))
	draw_rect(Rect2(r.position.x, base, r.size.x, 1), Color(Palette.ROSE, 0.4))
	for i in 46:
		var sx := r.position.x + 6.0 + fposmod(float(i * 41) + _age * 30.0, r.size.x - 12.0)
		var sy := r.position.y + fposmod(float(i * 67) + _age * 260.0, r.size.y - 14.0)
		draw_line(Vector2(sx, sy), Vector2(sx - 4.0, sy + 12.0), Color(Palette.MINT, 0.22), 1.0)


func _redacted(at: Vector2, w: float, h: float, alpha: float, seed: int) -> void:
	draw_rect(Rect2(at, Vector2(w, h)), Color(Palette.HOSTILE_RED, 0.16 * alpha))
	var flick := int(_age * 9.0) + seed * 13
	for i in int(w / 9.0):
		if (flick + i * 7) % 5 == 0:
			draw_rect(Rect2(at.x + i * 9.0, at.y + 3, 6, h - 6), Color(Palette.HOSTILE_RED, 0.35 * alpha))
	draw_rect(Rect2(at, Vector2(w, h)), Color(Palette.HOSTILE_RED, 0.45 * alpha), false, 1.0)


func _goal_of(def: MissionDef) -> String:
	return "[ redacted ]" if status_of(def) == "locked" else def.goal


func _start_word(index: int) -> String:
	var def: MissionDef = _defs[index]
	if _online():
		return "SOLO ONLY"
	match status_of(def):
		"done":
			return REPLAY if def.playable else DONE
		"next":
			return START
		"later":
			return LATER
	return LOCKED


static func _status_word(status: String) -> String:
	return {"done": DONE, "next": NEXT, "later": LATER, "locked": LOCKED}.get(status, status)


static func _status_colour(status: String) -> Color:
	match status:
		"done":
			return Palette.MINT
		"next":
			return Palette.HOSTILE_AMBER
		"later":
			return Color(Palette.TEAL, 0.9)
	return Color(Palette.HOSTILE_RED, 0.75)


func _pulse() -> float:
	return 0.5 + 0.5 * sin(_age * TAU * 0.9)


func _text(at: Vector2, text: String, font_size: int, colour: Color) -> void:
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colour)


func _width(text: String, font_size: int) -> float:
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _brackets(rect: Rect2, colour: Color, arm: float) -> void:
	for corner in [[rect.position, Vector2(1, 1)], [Vector2(rect.end.x, rect.position.y), Vector2(-1, 1)], [Vector2(rect.position.x, rect.end.y), Vector2(1, -1)], [rect.end, Vector2(-1, -1)]]:
		var at: Vector2 = corner[0]
		var d: Vector2 = corner[1]
		draw_line(at, at + Vector2(arm * d.x, 0), colour, 2.0)
		draw_line(at, at + Vector2(0, arm * d.y), colour, 2.0)
