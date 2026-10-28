extends Control
## grep's marks on screen (C25): while grep is in hand, a thin bracket in grep's own colour
## round each marked target with a small "match" tag over it, a bracket round the target a lock
## is building on that closes from bracket_open_px to bracket_marked_px as the lock builds, and
## just under the crosshair the count, "grep -c: N", N the marks held. Every size is the
## weapon's own (resources/grep_seeker.tres). It reads the player's lock node every frame and
## changes nothing.

const Palette = preload("res://scripts/palette.gd")
const GrepLock = preload("res://scripts/weapons/grep_lock.gd")
const WeaponDefScript = preload("res://scripts/weapons/weapon_def.gd")

const COUNT_LINE := "grep -c: %d"
const TAG := "match"
const FONT := 13
const TAG_FONT := 11
## How far under the screen's middle the count line starts, in pixels: clear of the crosshair.
const COUNT_DROP := 26.0
## A bracket's corner arms are this share of its side; its line this thick.
const ARM := 0.35
const LINE := 1.5
## The tag sits this far above its bracket.
const TAG_GAP := 4.0

## The player whose marks to show.
var player: Node = null

var _count: Label
## What the last frame showed: [{rect, marked}], for _draw and the tests.
var _brackets: Array = []
var _color := Palette.COBALT


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_count = Label.new()
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.add_theme_font_override("font", Palette.mono_font())
	_count.add_theme_font_size_override("font_size", FONT)
	_count.add_theme_color_override("font_outline_color", Palette.VOID)
	_count.add_theme_constant_override("outline_size", 4)
	add_child(_count)
	_count.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_count.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_count.visible = false


func _process(_delta: float) -> void:
	_refresh()


## The count line as shown ("grep -c: 2"), or "" while grep is not in hand.
func count_text() -> String:
	return _count.text if _count.visible else ""


## The brackets shown this frame, marks first then the lock building: [{rect, marked}], each
## rect in screen pixels.
func brackets() -> Array:
	return _brackets.duplicate(true)


func _refresh() -> void:
	_brackets = []
	var def: WeaponDefScript = player.weapon_tuning() if player != null and is_instance_valid(player) and player.has_method("weapon_tuning") else null
	var lock: GrepLock = player.get("grep") if def != null else null
	var shown: bool = def != null and def.is_seeker() and lock != null and player.get("alive") != false
	_count.visible = shown
	if shown:
		_color = def.skin_body()
		_count.text = COUNT_LINE % lock.count()
		_count.add_theme_color_override("font_color", def.skin_beam())
		_count.position.y = size.y * 0.5 + COUNT_DROP
		var camera := player.get_node_or_null("Head/Camera") as Camera3D
		if camera != null:
			for m in lock.marks:
				_add(camera, m["target"], def.bracket_marked_px, true)
			if lock.locking != null:
				_add(camera, lock.locking, lerpf(def.bracket_open_px, def.bracket_marked_px, lock.progress()), false)
	queue_redraw()


## `target` untyped: a mark's target may have been freed since (an avatar whose player left).
func _add(camera: Camera3D, target, half: float, marked: bool) -> void:
	if not GrepLock.alive(target):
		return
	var at := GrepLock.point_of(target)
	if camera.is_position_behind(at):
		return
	var middle := camera.unproject_position(at)
	_brackets.append({"rect": Rect2(middle - Vector2(half, half), Vector2(half, half) * 2.0), "marked": marked})


func _draw() -> void:
	var font := Palette.mono_font()
	for b in _brackets:
		var r: Rect2 = b["rect"]
		var arm := r.size.x * ARM
		for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			var sx := 1.0 if corner.x == r.position.x else -1.0
			var sy := 1.0 if corner.y == r.position.y else -1.0
			draw_line(corner, corner + Vector2(arm * sx, 0.0), _color, LINE)
			draw_line(corner, corner + Vector2(0.0, arm * sy), _color, LINE)
		if b["marked"]:
			draw_string(font, Vector2(r.position.x, r.position.y - TAG_GAP), TAG, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_FONT, _color)
