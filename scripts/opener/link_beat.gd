class_name LinkBeat
extends Control
## The opener's HUD coming alive (C41; PRD 5.7, 1:10 to 1:35), over the machine: the game's guide HUD as the player
## will meet it in the arena (its "your AI" badge top right, its panel at the bottom), drawn for the first time. The
## badge's frame draws itself in as the signal climbs, its signal bars climbing with it, then lock: the agent's name,
## and "live" with the call's real latency, or the scripted guide and why. The panel wipes open: "Linking your
## agent..." (the PRD's words) types itself, then your AI's line (a small "live" mark on it when it came from the
## player's own AI, STORY.md's one voice), then the scripted guide's line, "I've been stuck in here with them. They look
## like you." (the PRD's words), with its beat before the last words. All of it a plain function of the opener's clock
## and the link's few facts, as the rest of the opener is.
##
## On screen only SIGKILL's own words: fixed lines, an agent name from the guide link's known list, a number, short
## fixed words for why there is no live line. Plain text in Labels, never parsed as rich text. Nothing here reads,
## asks or keeps anything: the opener hands it the link's result.

const Palette = preload("res://scripts/palette.gd")
const HUD_TUNING_PATH := "res://resources/hud.tres"

## The PRD's words, exactly.
const LINKING := "Linking your agent..."
const GUIDE := "I've been stuck in here with them. They look like you."
const TITLE := "your AI"
const BADGE := "your AI: %s"
const BADGE_NONE := "your AI"
const LIVE := "live"
const STATUS_LINKING := "linking %s"
const STATUS_LIVE := "live  answered in %.2f s"
const STATUS_SCRIPTED := "scripted guide (%s)"
const SPINNER := ["|", "/", "-", "\\"]
## The sizes at 1080 lines (scaled with the window): margin, the badge's box, the panel's width, the fonts.
const MARGIN := 40.0
const BADGE_SIZE := Vector2(400.0, 104.0)
const PANEL_W := 900.0
const BADGE_FONT := 30
const STATUS_FONT := 21
const TITLE_FONT := 21
const BODY_FONT := 34
const PILL_FONT := 17
## How fast your AI's line types (it answers quickly), the guide's own pace, and the seeds.
const ANSWER_PACE := 0.03
const GUIDE_PACE := 0.06
const SEED := 4141
## The signal bars, and how often they climb while linking.
const BARS := 5
const BARS_HZ := 6.0

var _t: OpenerTuning
var _badge_color := Palette.TEAL
var _text_color := Palette.MINT
var _off_color := Color(1.0, 0.69, 0.0)
var _panel_alpha := 0.78
var _badge: Label
var _status: Label
var _title: Label
var _pill: Label
var _body: Label
var _linking_keys: Array = []
var _guide_keys: Array = []
var _answer_keys: Array = []
var _answer := ""
var _live := false
var _latency_ms := -1
var _why := ""
var _agent := ""
var _lock_at := -1.0
var _elapsed := 0.0
var _scale := 1.0


func _init() -> void:
	name = "LinkBeat"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hud = load(HUD_TUNING_PATH)
	if hud != null:
		for key in ["badge_color", "text_color", "off_color"]:
			if hud.get(key) is Color:
				set("_" + key, hud.get(key))
		if hud.get("panel_alpha") is float:
			_panel_alpha = hud.get("panel_alpha")


## Its timeline (the opener's tuning); the lines planned to type as a hand does.
func setup(tuning: OpenerTuning) -> void:
	_t = tuning
	_linking_keys = Typist.fit(Typist.plan([LINKING], SEED, GUIDE_PACE), maxf(_t.link_end - _t.link_at, 0.2))
	var cut := GUIDE.find(" They")
	_guide_keys = Typist.fit(Typist.plan([GUIDE.left(cut), _t.guide_beat, GUIDE.substr(cut)], SEED + 1, GUIDE_PACE), maxf(_t.guide_end - _t.guide_at, 0.5))
	_badge = _label(BADGE_FONT, _badge_color)
	_status = _label(STATUS_FONT, _text_color)
	_title = _label(TITLE_FONT, _badge_color)
	_pill = _label(PILL_FONT, Palette.VOID)
	_body = _label(BODY_FONT, _text_color)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	visible = false


## The link's result, as it locked at `at` on the opener's clock: the line, whether it came live, its latency and
## why there is none (OpenerLink's), the agent's name.
func lock(at: float, line: String, live: bool, latency_ms: int, why: String, agent: String) -> void:
	if _lock_at >= 0.0:
		return
	_lock_at = at
	_answer = line
	_live = live
	_latency_ms = latency_ms
	_why = why
	_agent = agent
	_answer_keys = Typist.plan([line], SEED + 2, ANSWER_PACE)


## The agent's name for the badge before the lock ("" for none).
func set_agent(agent: String) -> void:
	_agent = agent


# --- What the checks read. ---

func badge_text() -> String:
	return _badge.text if _badge != null and _badge.visible else ""


func status_text() -> String:
	return _status.text if _status != null and _status.visible else ""


func body_text() -> String:
	return _body.text if _body != null and _body.visible else ""


## True while the "live" mark shows by the line.
func live_mark() -> bool:
	return _pill != null and _pill.visible


## Everything it shows now, for the checks.
func shown_text() -> PackedStringArray:
	var out := PackedStringArray()
	for label in [_badge, _status, _title, _pill, _body]:
		if label != null and label.visible and label.text != "":
			out.append(label.text)
	return out


# --- Running. ---

## Everything at `elapsed` on the opener's clock.
func step(elapsed: float) -> void:
	_elapsed = elapsed
	if _t == null:
		return
	visible = elapsed >= _t.link_at and elapsed < _t.end_at
	if not visible:
		return
	_scale = maxf(get_viewport_rect().size.y / 1080.0, 0.25)
	var alive := _alive()
	var open := _open()
	var dim := 1.0 - smoothstep(_t.forge_at, _t.end_at, elapsed)
	var locked := _lock_at >= 0.0 and elapsed >= _lock_at
	# The badge.
	_badge.visible = alive > 0.35
	_badge.text = (BADGE % _agent) if _agent != "" else BADGE_NONE
	_status.visible = alive > 0.6
	if not locked:
		_status.text = STATUS_LINKING % SPINNER[floori(elapsed * 11.0) % SPINNER.size()]
		_status.add_theme_color_override("font_color", _text_color)
	elif _live:
		_status.text = (STATUS_LIVE % (_latency_ms / 1000.0)) if _latency_ms >= 0 else LIVE
		_status.add_theme_color_override("font_color", _text_color)
	else:
		_status.text = STATUS_SCRIPTED % _why
		_status.add_theme_color_override("font_color", _off_color)
	# The panel: linking, then your AI's line, then the guide's.
	_title.visible = open > 0.9
	_title.text = TITLE
	var guide := elapsed >= _t.guide_at
	_pill.visible = open > 0.9 and locked and _live and not guide
	_pill.text = LIVE
	_body.visible = open > 0.9
	if guide:
		_body.text = Typist.text_of(_upto(_guide_keys, elapsed - _t.guide_at))
		_body.add_theme_color_override("font_color", _text_color)
	elif locked:
		_body.text = Typist.text_of(_upto(_answer_keys, elapsed - _lock_at))
		_body.add_theme_color_override("font_color", _text_color)
	else:
		_body.text = Typist.text_of(_upto(_linking_keys, elapsed - _t.link_at))
		_body.add_theme_color_override("font_color", Color(_text_color, 0.72))
	modulate.a = dim
	_place()
	queue_redraw()


## How far the badge has come alive (0 to 1): with the signal.
func _alive() -> float:
	return smoothstep(_t.signal_at - 0.2, _t.signal_at + 0.9, _elapsed)


## How far the panel has wiped open (0 to 1).
func _open() -> float:
	return smoothstep(_t.link_at, _t.link_at + 0.35, _elapsed)


static func _upto(keys: Array, seconds: float) -> Array:
	var out := []
	for key in keys:
		if key["at"] <= seconds:
			out.append(key)
	return out


func _badge_rect() -> Rect2:
	var view := get_viewport_rect().size
	var size := BADGE_SIZE * _scale
	return Rect2(Vector2(view.x - MARGIN * _scale - size.x, MARGIN * _scale), size)


func _panel_rect() -> Rect2:
	var view := get_viewport_rect().size
	var width := minf(PANEL_W * _scale, view.x - 2.0 * MARGIN * _scale)
	var height := (TITLE_FONT + BODY_FONT * 2.6 + 34.0) * _scale
	return Rect2(Vector2((view.x - width) * 0.5, view.y - MARGIN * _scale * 1.6 - height), Vector2(width, height))


func _place() -> void:
	var badge := _badge_rect()
	var pad := 16.0 * _scale
	for label in [_badge, _status, _title, _pill, _body]:
		label.add_theme_font_size_override("font_size", roundi(label.get_meta("font", 16) * _scale))
	_badge.position = badge.position + Vector2(pad, pad * 0.7)
	_badge.size = Vector2(badge.size.x - pad * 2.0, BADGE_FONT * _scale * 1.3)
	_status.position = badge.position + Vector2(pad, pad * 0.7 + BADGE_FONT * _scale * 1.35)
	_status.size = Vector2(badge.size.x - pad * 2.0, STATUS_FONT * _scale * 1.3)
	var panel := _panel_rect()
	_title.position = panel.position + Vector2(pad * 1.2, pad * 0.8)
	_title.size = Vector2(200.0 * _scale, TITLE_FONT * _scale * 1.3)
	_pill.position = _title.position + Vector2(_title.get_minimum_size().x + 18.0 * _scale, 0.0)
	_pill.size = Vector2(60.0 * _scale, TITLE_FONT * _scale * 1.3)
	_body.position = panel.position + Vector2(pad * 1.2, pad * 0.8 + TITLE_FONT * _scale * 1.7)
	_body.size = Vector2(panel.size.x - pad * 2.4, BODY_FONT * _scale * 2.6)


func _draw() -> void:
	if _t == null:
		return
	var alive := _alive()
	var open := _open()
	var locked := _lock_at >= 0.0 and _elapsed >= _lock_at
	var line := maxf(1.0, 2.0 * _scale)
	# The badge's box: its corners drawing in, the frame coming up behind them, a scan line passing once.
	var badge := _badge_rect()
	var corner := minf(badge.size.y * 0.45, 40.0 * _scale) * smoothstep(0.0, 0.5, alive)
	var edge := Color(_badge_color, 1.0)
	draw_rect(badge, Color(Palette.VOID, _panel_alpha * smoothstep(0.3, 0.8, alive)))
	draw_rect(badge, Color(_badge_color, 0.35 * smoothstep(0.5, 1.0, alive)), false, line)
	for c in [badge.position, badge.position + Vector2(badge.size.x, 0.0), badge.end, badge.position + Vector2(0.0, badge.size.y)]:
		var sx := 1.0 if c.x <= badge.position.x + 1.0 else -1.0
		var sy := 1.0 if c.y <= badge.position.y + 1.0 else -1.0
		draw_line(c, c + Vector2(corner * sx, 0.0), edge, line * 1.5)
		draw_line(c, c + Vector2(0.0, corner * sy), edge, line * 1.5)
	var scan := (_elapsed - _t.signal_at) / 0.9
	if scan > 0.0 and scan < 1.0:
		var y := badge.position.y + badge.size.y * scan
		draw_line(Vector2(badge.position.x, y), Vector2(badge.end.x, y), Color(_text_color, 0.6 * (1.0 - scan)), line)
	# Its signal bars: climbing while it links, all lit once live, one lit and amber for the scripted guide.
	var lit := 0
	if not locked:
		lit = int(fposmod(_elapsed * BARS_HZ, BARS + 1))
	else:
		lit = BARS if _live else 1
	var bar_w := 7.0 * _scale
	var base := Vector2(badge.end.x - 22.0 * _scale - BARS * bar_w * 1.6, badge.position.y + 46.0 * _scale)
	for i in BARS:
		var h := (8.0 + 6.0 * i) * _scale
		var colour := (_badge_color if locked and _live or not locked else _off_color) if i < lit else Color(_badge_color, 0.18)
		if alive > 0.6:
			draw_rect(Rect2(base + Vector2(i * bar_w * 1.6, -h), Vector2(bar_w, h)), colour)
	# Live: a dot beating by the name.
	if locked and _live and alive > 0.6:
		var beat := 0.5 + 0.5 * cos(TAU * 1.2 * (_elapsed - _lock_at))
		draw_circle(Vector2(base.x - 16.0 * _scale, base.y - 10.0 * _scale), 5.0 * _scale * (0.8 + 0.4 * beat), Color(_text_color, 0.6 + 0.4 * beat))
	# The panel: wiping open from its middle, the guide HUD's own look (the void under it, a thin teal edge).
	if open > 0.0:
		var panel := _panel_rect()
		var w := panel.size.x * open
		var shown := Rect2(panel.position + Vector2((panel.size.x - w) * 0.5, 0.0), Vector2(w, panel.size.y))
		draw_rect(shown, Color(Palette.VOID, _panel_alpha))
		draw_rect(shown, Color(_badge_color, 0.85), false, line)
		if _pill.visible:
			var pill := Rect2(_pill.position - Vector2(6.0, 1.0) * _scale, Vector2(_pill.get_minimum_size().x + 12.0 * _scale, _pill.size.y))
			draw_rect(pill, _badge_color)


func _label(font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", Palette.mono_font())
	label.set_meta("font", font_size)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", Palette.VOID)
	label.add_theme_constant_override("outline_size", 4)
	label.visible = false
	add_child(label)
	return label
