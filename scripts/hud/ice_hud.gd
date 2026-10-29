extends Control
## ICE on the HUD (I1). Top right, while ICE is on: the hunter's adaptation, "HUNTER ADAPTED: <weapon>
## -NN%" in the hunter's colour, from its round on, once it has learned anything; under it, small,
## the feature's credit tag, "ICE design: @TimProvencio" (PRD 5.8: a feature born from a community
## prompt carries its author's tag on its own HUD, as the Audit Trail visor will carry
## @QuantaCortex's). Over the weapon strip, while a field has jammed one of this player's weapons:
## which, for how long, and that a swap fires. While a field has corrupted this player's HUD: a
## notice of it, and the status line, the round line, the weapon strip, the sudo badge and the kill
## feed scrambled under glacier glyph noise that tears and flickers, a new frame of it many times a
## second; the health line is never covered, so the player always knows their health.
##
## Visual only: what it shows is the ICE director's (scripts/ice/ice_director.gd) and the player's.

const Palette = preload("res://scripts/palette.gd")

const CREDIT := "ICE design: @TimProvencio"
const JAM_LINE := "JAMMED: %s  %.1f s   swap to fire"
const JAM_OTHER := "%s jammed  %.1f s"
const CORRUPT_LINE := "HUD CORRUPTED BY ICE  %.1f s"
## The glyphs the corruption scrambles with, and how many new frames of it a second.
const GLYPHS := "0123456789abcdef#%@&$!?<>/|=+*:;~^"
const CORRUPT_HZ := 14.0
## How far a corrupted part's cover reaches past it, pixels.
const COVER_PX := 6.0
const MARGIN := 18.0
## The block's top, under the guide HUD's two lines in the same corner.
const TOP := 80.0

var ice: Node = null
var player: Node = null
## The HUD's parts the corruption scrambles, and the health line it never covers.
var scrambled: Array[Control] = []
var health_line: Control = null
var weapon_strip: Control = null

var _adapt: Label
var _credit: Label
var _jam: Label
var _notice: Label
var _clock := 0.0
var _rects: Array[Rect2] = []
var _drawn := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_adapt = _label(20, Palette.HUNTER_TEXT)
	_adapt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_credit = _label(13, Palette.GLACIER)
	_credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_credit.modulate = Color(1.0, 1.0, 1.0, 0.75)
	_credit.text = CREDIT
	_jam = _label(18, Palette.GLACIER)
	_jam.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_notice = _label(20, Palette.GLACIER)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _process(delta: float) -> void:
	_clock = fmod(_clock + delta, 3600.0)
	var on: bool = ice != null and is_instance_valid(ice) and ice.mode != IceDirector.Mode.OFF
	var wide := size.x
	_adapt.text = ice.adapt_text() if on else ""
	_adapt.visible = _adapt.text != ""
	_adapt.position = Vector2(wide - MARGIN - _adapt.get_combined_minimum_size().x, TOP)
	_credit.visible = on
	_credit.position = Vector2(wide - MARGIN - _credit.get_combined_minimum_size().x, TOP + (28.0 if _adapt.visible else 0.0))
	_jam.text = jam_text() if on else ""
	_jam.visible = _jam.text != ""
	if _jam.visible:
		var strip := weapon_strip.get_global_rect() if weapon_strip != null and weapon_strip.is_visible_in_tree() else Rect2(wide - 300.0, size.y - 160.0, 280.0, 120.0)
		var at := strip.position - get_global_rect().position
		_jam.position = Vector2(wide - MARGIN - _jam.get_combined_minimum_size().x, at.y - _jam.get_combined_minimum_size().y - 6.0)
	var corrupt: bool = on and ice.corrupting()
	_notice.visible = corrupt
	if corrupt:
		_notice.text = CORRUPT_LINE % ice.corrupt_left
		_notice.position = Vector2((wide - _notice.get_combined_minimum_size().x) * 0.5, 126.0)
		_notice.modulate.a = 0.55 + 0.45 * float(int(_clock * CORRUPT_HZ) % 3 != 0)
	if corrupt:
		_rects = covered_rects()
	else:
		_rects.clear()
	if corrupt or _drawn:
		queue_redraw()
	_drawn = corrupt


## The covers drawn now (empty while the HUD is not corrupted).
func drawn_rects() -> Array[Rect2]:
	return _rects


## The adaptation's line now, "" when none shows.
func adapt_line() -> String:
	return _adapt.text if _adapt != null and _adapt.visible else ""


func credit_text() -> String:
	return _credit.text if _credit != null and _credit.visible else ""


## The jam's notice: the weapon in hand jammed, or the first other one still jammed; "" for none.
func jam_text() -> String:
	if player == null or not is_instance_valid(player) or not player.has_method("ice_jams"):
		return ""
	var jams: Dictionary = player.ice_jams()
	if jams.is_empty():
		return ""
	var current: int = player.inventory.current
	if jams.has(current):
		return JAM_LINE % [player.inventory.defs[current].short_name, jams[current]]
	var slot: int = jams.keys()[0]
	return JAM_OTHER % [player.inventory.defs[slot].short_name, jams[slot]]


## The parts of the HUD the corruption covers now (this HUD's own space), each a little larger than
## the part; never the health line.
func covered_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var origin := get_global_rect().position
	for part in scrambled:
		if part == null or not is_instance_valid(part) or not part.is_visible_in_tree():
			continue
		var r := part.get_global_rect()
		if r.size.x < 1.0 or r.size.y < 1.0:
			continue
		r.position -= origin
		out.append(r.grow(COVER_PX))
	var keep := health_rect()
	if keep.size != Vector2.ZERO:
		for i in out.size():
			out[i] = _clear_of(out[i], keep)
	return out


## The health line's place (this HUD's own space), or an empty rect when it is not shown.
func health_rect() -> Rect2:
	if health_line == null or not is_instance_valid(health_line) or not health_line.is_visible_in_tree():
		return Rect2()
	var r := health_line.get_global_rect()
	r.position -= get_global_rect().position
	return r.grow(2.0)


## `r` cut back so it never reaches `keep`: the side of it that overlaps given up.
static func _clear_of(r: Rect2, keep: Rect2) -> Rect2:
	if not r.intersects(keep):
		return r
	if r.position.y < keep.position.y:
		r.size.y = maxf(keep.position.y - r.position.y, 0.0)
	else:
		var bottom := r.end.y
		r.position.y = keep.end.y
		r.size.y = maxf(bottom - r.position.y, 0.0)
	return r


func _draw() -> void:
	if _rects.is_empty():
		return
	var font := Palette.mono_font()
	var tick := int(_clock * CORRUPT_HZ)
	for i in _rects.size():
		var r := _rects[i]
		if r.size.y < 2.0:
			continue
		draw_rect(r, Color(0.0, 0.02, 0.05, 0.86))
		var rows := maxi(int(r.size.y / 15.0), 1)
		for row in rows:
			var roll := _roll(tick, i, row)
			var shift := (roll - 0.5) * 18.0 if roll > 0.7 else 0.0
			var line := ""
			var count := int(r.size.x / 9.0)
			for c in count:
				line += GLYPHS[int(_roll(tick, i * 131 + row, c) * GLYPHS.length()) % GLYPHS.length()] if _roll(tick + 3, row, c + i) > 0.18 else " "
			var tint := Palette.GLACIER
			tint.a = 0.35 + 0.65 * _roll(tick, row, i + 7)
			draw_string(font, Vector2(r.position.x + 2.0 + shift, r.position.y + 13.0 + row * 15.0), line, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 4.0, 13, tint)
		# A tear across it now and then.
		if _roll(tick, i, 99) > 0.55:
			var y := r.position.y + r.size.y * _roll(tick, i, 101)
			draw_rect(Rect2(r.position.x - 4.0, y, r.size.x + 8.0, 2.0), Color(Palette.GLACIER, 0.8))


## A number from 0 to 1 fixed by three integers: the corruption's own dice, a new set each tick.
static func _roll(a: int, b: int, c: int) -> float:
	return float(hash(Vector3i(a, b, c)) & 0xffff) / 65535.0


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", Palette.mono_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Palette.VOID)
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)
	return label
