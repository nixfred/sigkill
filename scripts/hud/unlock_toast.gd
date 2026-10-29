class_name UnlockToast
extends Control
## "UNLOCKED: <name>" (C33): a short toast near the top of the screen the moment a skin or a mod is earned
## (Progress.unlocked, scripts/unlocks/progress.gd). A dark strip whose corners are brackets of the item's own
## light (a skin's body and beam, a mod the weapon's own), dropping in, a bar of light sweeping across it once,
## then fading; its name in the item's beam colour and under it where to wear it. Several earned at once queue,
## each in turn. Cosmetic only, and it never takes input.

const Palette = preload("res://scripts/palette.gd")

const HEAD := "UNLOCKED"
const WHERE_SKIN := "a light skin for %s   Esc > Loadout to wear it"
const WHERE_MOD := "a mod for %s   Esc > Loadout to fit it"
## Seconds: dropping in, held in all, fading out; how far it drops, pixels; its size and place.
const IN_S := 0.18
const SHOW_S := 3.4
const OUT_S := 0.45
const DROP_PX := 18.0
const SIZE := Vector2(460, 70)
const TOP_PX := 92.0
const BRACKET_PX := 14.0
const SWEEP_S := 0.9

var _queue: Array = []
var _left := 0.0
var _age := 0.0
var _body := Palette.MINT
var _beam := Palette.MINT
var _head: Label
var _title: Label
var _where: Label
var _progress: Progress


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	size = SIZE
	_head = _label(11, Vector2(18, 7))
	_title = _label(22, Vector2(18, 19))
	_where = _label(11, Vector2(18, 49))
	visible = false
	_progress = Progress.current()
	if not _progress.unlocked.is_connected(show_unlock):
		_progress.unlocked.connect(show_unlock)


## Earned: `weapon`'s skin or mod `item`, called `title`. Shown now, or after the ones already waiting.
func show_unlock(weapon: String, item: String, title: String) -> void:
	_queue.append([weapon, item, title])
	if _left <= 0.0:
		_next()


## The toast's text now ("" while hidden), for the checks.
func text() -> String:
	return "%s: %s" % [_head.text, _title.text] if visible else ""


func showing() -> bool:
	return visible


func waiting() -> int:
	return _queue.size()


func _next() -> void:
	if _queue.is_empty():
		visible = false
		return
	var got: Array = _queue.pop_front()
	var kit := WeaponKit.of(got[0])
	var index := kit.skin_index(got[1]) if kit != null else -1
	var skin: String = got[1] if index > 0 else (kit.skins[0].skin if kit != null else "teal")
	_body = Palette.skin_body(skin)
	_beam = Palette.skin_beam(skin)
	var short: String = String(got[2]).get_slice("  (", 0)
	var weapon_name: String = got[0]
	for def in WeaponKit.shipped_defs():
		if def.id == got[0]:
			weapon_name = def.short_name
	_head.text = HEAD
	_head.add_theme_color_override("font_color", _body)
	_title.text = short
	_title.add_theme_color_override("font_color", _beam)
	_where.text = (WHERE_SKIN if index > 0 else WHERE_MOD) % weapon_name
	_where.add_theme_color_override("font_color", Palette.MINT)
	_left = SHOW_S
	_age = 0.0
	visible = true
	_place()


func _process(delta: float) -> void:
	if _left <= 0.0:
		return
	_left -= delta
	_age += delta
	if _left <= 0.0:
		_next()
		return
	_place()
	queue_redraw()


func _place() -> void:
	var screen := get_viewport_rect().size
	var drop := clampf(_age / IN_S, 0.0, 1.0)
	position = Vector2((screen.x - SIZE.x) * 0.5, TOP_PX - DROP_PX * (1.0 - drop))
	modulate.a = clampf(_left / OUT_S, 0.0, 1.0) * drop


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, SIZE)
	draw_rect(r, Color(Palette.VOID, 0.82))
	var b := BRACKET_PX
	for corner in [[Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN], [Vector2(SIZE.x, 0), Vector2.LEFT, Vector2.DOWN], [Vector2(0, SIZE.y), Vector2.RIGHT, Vector2.UP], [SIZE, Vector2.LEFT, Vector2.UP]]:
		draw_line(corner[0], corner[0] + corner[1] * b, _body, 2.0)
		draw_line(corner[0], corner[0] + corner[2] * b, _body, 2.0)
	# A bar of the beam's light sweeping across once, and a faint seam along the foot.
	var t := clampf(_age / SWEEP_S, 0.0, 1.0)
	if t < 1.0:
		var x := lerpf(-40.0, SIZE.x, t)
		draw_rect(Rect2(x, 2.0, 40.0, SIZE.y - 4.0), Color(_beam, 0.10 * (1.0 - t)))
		draw_line(Vector2(x + 40.0, 2.0), Vector2(x + 40.0, SIZE.y - 2.0), Color(_beam, 0.8 * (1.0 - t)), 1.5)
	draw_line(Vector2(b + 6.0, SIZE.y - 1.0), Vector2(SIZE.x - b - 6.0, SIZE.y - 1.0), Color(_body, 0.45), 1.0)


func _label(font_size: int, at: Vector2) -> Label:
	var label := Label.new()
	label.position = at
	label.add_theme_font_override("font", Palette.mono_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label
