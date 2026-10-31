class_name TitleBeat
extends Control
## C42's beat on the screen (PRD 5.7, 1:35 to 2:00), over the machine: the rifle's reticle and how to fire while the copy
## waits for it, the shock of the rifle locking in, the kill feed in SIGKILL's words ("SIGKILL sent by <user>" / "to
## <user>", the feed's two lines, STORY.md's words), the whisper ("one of 6666"), the black, and the title: SIGKILL on the
## nixfred hexagon, the brand's own icon file as it is (packaging/linux/sigkill.svg, the white >_ on the hexagon; never
## redrawn), slamming in on the score's beat (scripts/opener/opener_score.gd: SLAM_BEATS after the shot) out of the dark,
## the name hammered in a letter a sixteenth after it, the title punching on every beat of the riff, tearing on the
## snare, and torn away at the end; under it the machine's grid racing toward the player on the beat, a streak of its
## light through the hexagon, and the last of the copy's voxels rising as embers. Everything is a function of the opener's clock and the shot's moment. The user name is
## handed in (the opener's, cleaned), shown, and dropped with the opener; nothing here reads anything.

const Palette = preload("res://scripts/palette.gd")
## The brand's icon, the file itself (its import makes it big enough to slam full screen).
const LOGO := preload("res://packaging/linux/sigkill.svg")

const TITLE := "SIGKILL"
const FEED_FIRST := "%s sent by %s"
const FEED_SECOND := "to %s"
const FEED_WORD := "SIGKILL"
const WHISPER := "one of 6666"
const HINT := "[%s]  kill -9"
## At 1080 lines: the logo's height, where its middle sits (a share of the height), the name's size and place.
const LOGO_H := 0.4
const LOGO_Y := 0.4
const NAME_PX := 128
const NAME_Y := 0.8
const FEED_PX := 38
const WHISPER_PX := 30
const HINT_PX := 26
## The grid under the title: its horizon (a share of the height), its lines; the embers.
const HORIZON := 0.62
const GRID_LINES := 22
const EMBERS := 70
const RETICLE_R := 24.0
const EDGE := 48.0
## How long the slam takes to land, its shake, its colour split; the sparks; the snare's tear.
const SLAM_S := 0.09
const SHAKE_PX := 26.0
const SPLIT_PX := 30.0
const SPARKS := 44
const TEAR_S := 0.07

var _t: OpenerTuning
var _forge: ForgeBeat
var _user := "user"
var _name_color := Palette.MINT
var _fire_label := "left mouse"
var _elapsed := 0.0
var _shot := -1.0
var _armed := -1.0
var _flash := 0.0
var _scale := 1.0
var _font: Font


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	visible = false


func setup(tuning: OpenerTuning, forge: ForgeBeat, name_color: Color, fire_label: String) -> void:
	_t = tuning
	_forge = forge
	_name_color = name_color
	_fire_label = fire_label
	_font = TreeFall.label_font()


## The user name the kill feed names, twice (cleaned by the opener; "" for none: the demo's).
func set_user(text: String) -> void:
	_user = text if text != "" else "user"


## When the player pressed fire (the reticle closes at once; the shot lands on the next sixteenth).
func set_armed(at: float) -> void:
	if _armed < 0.0:
		_armed = at


## Everything at `elapsed` on the opener's clock: the shot's moment (or -1), and the slam's flash (the brightness
## model's white over the title).
func step(elapsed: float, shot_at: float, flash: float) -> void:
	_elapsed = elapsed
	_shot = shot_at
	_flash = flash
	visible = _t != null and elapsed >= _t.forge_at
	if visible:
		_scale = maxf(get_viewport_rect().size.y / 1080.0, 0.25)
		queue_redraw()


# --- The moments, on the opener's clock. ---

func _since_shot(beats: float) -> float:
	return _elapsed - (_shot + beats * OpenerScore.BEAT_S) if _shot >= 0.0 else -1.0


func black() -> bool:
	return _shot >= 0.0 and _since_shot(OpenerScore.BLACK_BEATS) >= 0.0


func slam_at() -> float:
	return _shot + OpenerScore.SLAM_BEATS * OpenerScore.BEAT_S if _shot >= 0.0 else INF


## When the title starts tearing away, and is gone.
func out_from() -> float:
	return _shot + _t.end_after - 1.2 if _shot >= 0.0 else INF


func out_to() -> float:
	return _shot + _t.end_after - 0.4 if _shot >= 0.0 else INF


# --- What the checks read. ---

func reticle_showing() -> bool:
	return visible and _elapsed >= _t.fire_from and (_shot < 0.0 or _elapsed < _shot + 0.05)


func hint_text() -> String:
	return (HINT % _fire_label) if reticle_showing() and _armed < 0.0 and _elapsed >= _t.fire_from + 0.4 else ""


## The kill feed as shown, its two lines joined by a space, or "".
func feed_text() -> String:
	var s := _since_shot(OpenerScore.FEED_BEATS)
	if s < 0.0 or black():
		return ""
	return (FEED_FIRST % [FEED_WORD, _user]) + " " + (FEED_SECOND % _user)


func whisper_text() -> String:
	var s := _since_shot(OpenerScore.WHISPER_BEATS)
	return WHISPER if s >= 0.0 and s < _whisper_s() and not black() else ""


func title_showing() -> bool:
	return visible and _elapsed >= slam_at() and _elapsed < out_to()


func title_text() -> String:
	return TITLE if title_showing() else ""


func _whisper_s() -> float:
	return (OpenerScore.BLACK_BEATS - OpenerScore.WHISPER_BEATS) * OpenerScore.BEAT_S - 0.6


# --- Drawing. ---

func _draw() -> void:
	if _t == null:
		return
	var view := get_viewport_rect().size
	_draw_drop(view)
	_draw_reticle(view)
	if black():
		draw_rect(Rect2(Vector2.ZERO, view), Color.BLACK)
		if _elapsed >= slam_at():
			_draw_title(view)
		return
	_draw_feed(view)
	_draw_whisper(view)


## The rifle locking in: a ring of teal light out from where it sits, as the drop lands.
func _draw_drop(view: Vector2) -> void:
	if _forge == null:
		return
	var s := _elapsed - _forge.drop_at()
	if s < 0.0 or s > 0.6:
		return
	var at := Vector2(view.x * 0.64, view.y * 0.82)
	var u := s / 0.6
	draw_arc(at, view.x * 0.75 * (1.0 - pow(1.0 - u, 3.0)), 0.0, TAU, 96, Color(Palette.TEAL, 0.7 * (1.0 - u)), 7.0 * _scale * (1.0 - u) + 1.0, true)
	draw_arc(at, view.x * 0.4 * (1.0 - pow(1.0 - u, 2.0)), 0.0, TAU, 72, Color(Palette.MINT, 0.5 * (1.0 - u)), 3.0 * _scale, true)


## The rail's reticle at the middle, beating with the wait; closing the moment fire is pressed; and how to fire.
func _draw_reticle(view: Vector2) -> void:
	if not reticle_showing():
		return
	var c := view * 0.5
	var into := _elapsed - _t.fire_from
	var beat := exp(-fposmod(into, OpenerScore.BEAT_S) * 10.0)
	var close := 1.0 if _armed < 0.0 else maxf(1.0 - (_elapsed - _armed) * 9.0, 0.25)
	var r := RETICLE_R * _scale * (1.0 + 0.12 * beat) * close * (1.6 - 0.6 * smoothstep(0.0, 0.3, into))
	var a := smoothstep(0.0, 0.25, into)
	var colour := Color(Palette.ICE_HI, 0.9 * a)
	for k in 4:
		var from := TAU * k / 4.0 + 0.25
		draw_arc(c, r, from, from + PI / 2.0 - 0.5, 16, colour, 2.5 * _scale, true)
		var dir := Vector2.from_angle(TAU * k / 4.0)
		draw_line(c + dir * r * 1.25, c + dir * r * 1.7, colour, 2.0 * _scale, true)
	draw_circle(c, 3.0 * _scale, Color(Palette.CRIMSON, a))
	var hint := hint_text()
	if hint != "":
		var size := roundi(HINT_PX * _scale)
		var w := _font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var pulse := 0.6 + 0.4 * beat
		_text(Vector2((view.x - w) * 0.5, view.y * 0.86), hint, size, Color(Palette.ICE_HI, pulse * smoothstep(0.4, 0.8, into)))


## The kill feed, in the game's words, slammed in from the right at the bottom of the screen.
func _draw_feed(view: Vector2) -> void:
	var s := _since_shot(OpenerScore.FEED_BEATS)
	if s < 0.0:
		return
	var size := roundi(FEED_PX * _scale)
	var first_word := FEED_WORD + " "
	var sent := "sent by "
	var line1_w := _font.get_string_size(first_word + sent + _user, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var line2 := FEED_SECOND % _user
	var line2_w := _font.get_string_size(line2, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var slide := 140.0 * _scale * pow(1.0 - clampf(s / 0.1, 0.0, 1.0), 2.0)
	var jitter := (sin(s * 90.0) * 6.0 * _scale) * exp(-s * 12.0)
	var right := view.x - EDGE * _scale + slide
	var y := view.y * 0.72
	var hot := exp(-s * 10.0)
	var box := Rect2(right - maxf(line1_w, line2_w) - 24.0 * _scale, y - size * 1.2, maxf(line1_w, line2_w) + 36.0 * _scale, size * 2.9)
	draw_rect(box, Color(0.0, 0.0, 0.0, 0.55))
	draw_rect(Rect2(box.position, Vector2(4.0 * _scale, box.size.y)), Palette.ICE_HI.lerp(Color.WHITE, hot))
	var x := right - line1_w + jitter
	x = _text(Vector2(x, y), first_word, size, Palette.ICE_HI.lerp(Color.WHITE, hot))
	x = _text(Vector2(x, y), sent, size, Color(Palette.MINT, 0.85).lerp(Color.WHITE, hot))
	_text(Vector2(x, y), _user, size, _name_color.lerp(Color.WHITE, hot))
	var x2 := right - line2_w - jitter
	var to := "to "
	x2 = _text(Vector2(x2, y + size * 1.25), to, size, Color(Palette.MINT, 0.85).lerp(Color.WHITE, hot))
	_text(Vector2(x2, y + size * 1.25), _user, size, _name_color.lerp(Color.WHITE, hot))


## The whisper: spaced out, dim, low, trembling, there and gone.
func _draw_whisper(view: Vector2) -> void:
	var s := _since_shot(OpenerScore.WHISPER_BEATS)
	if s < 0.0 or s > _whisper_s():
		return
	var a := smoothstep(0.0, 0.35, s) * (1.0 - smoothstep(_whisper_s() - 0.5, _whisper_s(), s))
	var size := roundi(WHISPER_PX * _scale)
	var gap := size * 0.45
	var total := 0.0
	for ch in WHISPER:
		total += _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + gap
	var x := (view.x - total + gap) * 0.5
	for i in WHISPER.length():
		var ch := WHISPER[i]
		var wobble := Vector2(sin(s * 23.0 + i * 1.9), sin(s * 17.0 + i * 2.7)) * 1.5 * _scale
		_text(Vector2(x, view.y * 0.46) + wobble, ch, size, Color(0.78, 0.86, 0.9, a * 0.85))
		x += _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + gap


## The title: the hexagon slamming in out of the dark, its colours split and the screen shaking as it lands, sparks and
## rings flying off; the name hammered in a letter a sixteenth; a punch on every beat, a tear on every snare; torn away.
func _draw_title(view: Vector2) -> void:
	var s := _elapsed - slam_at()
	var beat_s := OpenerScore.BEAT_S
	var punch := 0.0
	if s >= 0.0:
		punch = 0.035 * exp(-fposmod(s, beat_s) * 11.0)
	var land := 1.0 + 2.6 * pow(1.0 - clampf(s / SLAM_S, 0.0, 1.0), 2.0)
	var settle := 1.0 - 0.07 * sin(PI * clampf((s - SLAM_S) / 0.22, 0.0, 1.0)) if s > SLAM_S else 1.0
	var out := clampf((_elapsed - out_from()) / maxf(out_to() - out_from(), 0.01), 0.0, 1.0)
	var shake := Vector2(sin(s * 61.0), cos(s * 47.0)) * SHAKE_PX * _scale * exp(-s * 7.0)
	var final_hit := s - 2.0 * OpenerScore.BAR_S
	if final_hit >= 0.0:
		shake += Vector2(sin(final_hit * 59.0), cos(final_hit * 43.0)) * SHAKE_PX * 0.6 * _scale * exp(-final_hit * 8.0)
		punch += 0.06 * exp(-final_hit * 7.0)
	var h := view.y * LOGO_H * land * settle * (1.0 + punch)
	var w := h * LOGO.get_width() / maxf(LOGO.get_height(), 1.0)
	var c := Vector2(view.x * 0.5, view.y * LOGO_Y) + shake
	var rect := Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h))
	var fade := clampf(s / SLAM_S, 0.0, 1.0) * (1.0 - out)
	_draw_grid(view, s, fade)
	_draw_embers(view, s, fade)
	# A glow of the brand's teal behind it, smooth, swelling with each punch.
	for k in 16:
		var r := h * (1.25 - 0.05 * k)
		draw_circle(c, r, Color(Palette.TEAL, 0.012 * fade * (1.0 + 5.0 * punch)))
	# A streak of its light straight through it, as a lens takes a bright light.
	var streak := fade * (0.55 + 3.0 * punch)
	for k in 4:
		var thick := (1.0 + 5.0 * k) * _scale
		draw_rect(Rect2(0.0, c.y - thick * 0.5, view.x, thick), Color(Palette.MINT.lerp(Palette.TEAL, k / 3.0), 0.22 * streak / (1.0 + k)))
	# Its colours split as it lands (and on the final hit), then the icon itself, torn into strips on the snare.
	var split := SPLIT_PX * _scale * (exp(-s * 6.0) + (exp(-final_hit * 7.0) if final_hit >= 0.0 else 0.0)) + 40.0 * _scale * out
	if split > 0.5:
		draw_texture_rect(LOGO, Rect2(rect.position + Vector2(-split, 0.0), rect.size), false, Color(1.0, 0.15, 0.3, 0.55 * fade))
		draw_texture_rect(LOGO, Rect2(rect.position + Vector2(split, 0.0), rect.size), false, Color(0.1, 0.9, 1.0, 0.55 * fade))
	var tear := _tear(s) + out * 3.0
	var strips := 7
	for k in strips:
		var src := Rect2(0.0, LOGO.get_height() * k / strips, LOGO.get_width(), LOGO.get_height() / float(strips))
		var dst := Rect2(rect.position.x, rect.position.y + h * k / strips, w, h / strips + 0.5)
		var shift := sin(k * 12.9898 + floorf(s / TEAR_S) * 3.1) * 36.0 * _scale * tear
		dst.position.x += shift
		draw_texture_rect_region(LOGO, dst, src, Color(1.0, 1.0, 1.0, fade))
	# The rings and the sparks off the landing.
	if s < 0.7:
		var u := s / 0.7
		for k in 2:
			var r := view.x * (0.25 + 0.55 * k) * (1.0 - pow(1.0 - u, 3.0))
			draw_arc(c, r, 0.0, TAU, 96, Color(Palette.MINT, 0.6 * (1.0 - u)), (8.0 - 4.0 * k) * _scale * (1.0 - u) + 1.0, true)
		for i in SPARKS:
			var a := TAU * i / SPARKS + sin(i * 7.31) * 0.2
			var speed := (0.5 + 0.5 * absf(sin(i * 3.7))) * view.x * 0.7
			var from := c + Vector2.from_angle(a) * (h * 0.45 + speed * u * 0.6)
			var to := from + Vector2.from_angle(a) * (40.0 + 60.0 * absf(sin(i * 1.3))) * _scale * (1.0 - u)
			draw_line(from, to, Color(Palette.ICE_HI if i % 3 else Palette.CRIMSON, 0.9 * (1.0 - u)), 3.0 * _scale, true)
	# The name, a letter a sixteenth from the next beat, each dropping in white hot.
	var size := roundi(NAME_PX * _scale)
	var name_w := _font.get_string_size(TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x := (view.x - name_w) * 0.5 + shake.x * 0.6
	for i in TITLE.length():
		var ch := TITLE[i]
		var in_s := s - beat_s - i * OpenerScore.STEP_S
		var cw := _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		if in_s >= 0.0:
			var drop := -70.0 * _scale * pow(1.0 - clampf(in_s / 0.06, 0.0, 1.0), 2.0)
			var hot := exp(-in_s * 9.0)
			var y := view.y * NAME_Y + drop + shake.y * 0.6 + sin(i * 9.1 + floorf(s / TEAR_S)) * 10.0 * _scale * (_tear(s) + out * 2.0)
			var colour := Palette.MINT.lerp(Color.WHITE, hot)
			# Its ghosts a few pixels either side, the split of a signal not quite in step.
			var ghost := (3.0 + 14.0 * hot + 30.0 * out) * _scale
			draw_string(_font, Vector2(x - ghost, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(Palette.CRIMSON, 0.35 * (1.0 - out)))
			draw_string(_font, Vector2(x + ghost, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.2, 0.9, 1.0, 0.3 * (1.0 - out)))
			draw_string_outline(_font, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, roundi(22.0 * _scale), Color(Palette.TEAL, 0.22 * (1.0 - out)))
			draw_string_outline(_font, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, roundi(8.0 * _scale), Color(Palette.TEAL, 0.5 * (1.0 - out)))
			draw_string(_font, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(colour, 1.0 - out))
		x += cw
	# Scanlines over it all, and the slam's flash (the brightness model's): a burst of the hexagon's light out from it,
	# white at its heart, never a grey wash over the dark.
	for y in range(0, int(view.y), maxi(roundi(3.0 * _scale), 2)):
		draw_line(Vector2(0.0, y), Vector2(view.x, y), Color(0.0, 0.0, 0.0, 0.12), 1.0)
	if _flash > 0.0:
		for k in 18:
			var r := view.x * (0.9 - 0.048 * k)
			draw_circle(c, r, Color(Palette.MINT.lerp(Color.WHITE, k / 17.0), _flash * 0.11))


## The machine's grid under the title, in perspective, racing toward the player a cell each beat, fading to the horizon.
func _draw_grid(view: Vector2, s: float, fade: float) -> void:
	var horizon := view.y * HORIZON
	var centre := view.x * 0.5
	var colour := Color(Palette.TEAL, 0.0)
	var beat := fposmod(maxf(s, 0.0) / OpenerScore.BEAT_S, 1.0)
	for k in GRID_LINES:
		var lean := (float(k) / (GRID_LINES - 1) - 0.5) * 2.0
		colour.a = 0.16 * fade
		draw_line(Vector2(centre + lean * view.x * 0.08, horizon), Vector2(centre + lean * view.x * 1.4, view.y), colour, 1.5 * _scale, true)
	for k in 12:
		var z := (k + 1.0 - beat) / 12.0
		var y := horizon + (view.y - horizon) * pow(z, 2.6)
		colour.a = 0.2 * fade * z
		draw_line(Vector2(0.0, y), Vector2(view.x, y), colour, 1.5 * _scale, true)
	# A haze along the horizon.
	for k in 6:
		draw_rect(Rect2(0.0, horizon - k * 3.0 * _scale, view.x, 6.0 * _scale), Color(Palette.TEAL, 0.03 * fade))


## The last of the copy's voxels rising slowly as embers, crimson and teal, flickering out.
func _draw_embers(view: Vector2, s: float, fade: float) -> void:
	for i in EMBERS:
		var speed := 0.03 + 0.05 * absf(sin(i * 4.13))
		var y := view.y * (1.05 - fposmod(absf(sin(i * 2.71)) + maxf(s, 0.0) * speed, 1.1))
		var x := view.x * absf(sin(i * 7.37)) + sin(s * 0.9 + i) * 12.0 * _scale
		var size := (3.5 + 6.0 * absf(sin(i * 1.91))) * _scale
		var a := fade * (0.55 + 0.4 * sin(s * 6.0 + i * 2.3)) * clampf(y / view.y * 1.4, 0.0, 1.0)
		draw_rect(Rect2(x, y, size, size), Color(Palette.CRIMSON if i % 3 == 0 else Palette.TEAL, a))


## How hard the title tears now: on the snare (beats two and four of each bar of the riff), for TEAR_S.
func _tear(s: float) -> float:
	if s < 0.0 or s > 2.0 * OpenerScore.BAR_S:
		return 0.0
	var beat := floori(s / OpenerScore.BEAT_S)
	var into := fposmod(s, OpenerScore.BEAT_S)
	return 1.0 if beat % 2 == 1 and into < TEAR_S else 0.0


## `text` at `at` (its baseline) in `colour`; returns where the next text goes.
func _text(at: Vector2, text: String, size: int, colour: Color) -> float:
	draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, roundi(6.0 * _scale), Color(0.0, 0.0, 0.0, 0.8 * colour.a))
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)
	return at.x + _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
