extends Control
## Black ICE on the HUD (I3). Its arrival is an event every screen shows for the whole of its tell: a
## warning centred high, "B L A C K   I C E" in its cold colour, flickering in, what it is in one line
## (weapons only flash it, its touch flatlines) and how long until it has formed and how far away. While it
## is out: one line top centre with its seals standing (a broken one's mend counting down) and its distance,
## the scripted guide's word on it under that (scripts/ice/breaker_pick.gd: the exploit and brute combo
## when this player carries it, else the decoy, else the cloak, else run), a tag over it in the world (at
## the screen's edge with an arrow when it is off screen) so its approach always reads, and the screen's
## edges going cold and dark as it comes near. A broken seal and its end are each called out; a flatline
## of this player flashes the screen in its colour (the combat HUD's banner says the rest).
##
## Visual only: it reads ICE's director (scripts/ice/ice_director.gd) and its Black ICE every frame and
## changes nothing.

const Palette = preload("res://scripts/palette.gd")
const BreakerPick = preload("res://scripts/ice/breaker_pick.gd")
const VignetteShader = preload("res://shaders/damage_vignette.gdshader")

const TITLE := "B L A C K   I C E"
const WHAT_LINE := "the machine's last defence: weapons only flash it, its touch flatlines"
const FORMS_LINE := "it forms in %.1f s   %d m away"
const OUT_LINE := "BLACK ICE   seals %d/%d   %d m"
const MEND_LINE := "   mends in %.0f s"
const GUIDE_LINE := "scripted guide: %s"
const TAG := "[ BLACK ICE %d m ]"
const LEFT_TAG := "< BLACK ICE %d m"
const RIGHT_TAG := "BLACK ICE %d m >"
const SEAL_LINE := "SEAL BROKEN   %d left"
const DOWN_LINE := "BLACK ICE DOWN"
const TITLE_FONT := 40
const LINE_FONT := 16
const SMALL_FONT := 14
## The arrival block's top (a share of the screen's height) and the out line's top, pixels.
const ARRIVE_TOP := 0.22
const OUT_TOP := 150.0
## A call-out (a seal, its end) stays this long; the flatline's flash fades over this long.
const CALL_S := 2.4
const FLASH_S := 0.7
## The edges go cold within this far of its touch, at most this strong.
const NEAR_M := 12.0
const NEAR_WASH := 0.6
const EDGE_PX := 24.0
## The title's flicker as it comes in.
const FLICKER_HZ := 11.0
const SCRAMBLE := "#%@&$!?<>/|=+*"
## Its tag over it hides this near when it is in view (it fills the view then), and never stands higher
## than the out line and the scripted guide's word under it.
const TAG_NEAR_M := 6.0
const TAG_BELOW := OUT_TOP + LINE_FONT + SMALL_FONT + 16.0

## ICE's director, set by the HUD, and the breakers' (the scripted guide's numbers).
var ice: Node = null
var breakers: Node = null

var _title: Label
var _what: Label
var _forms: Label
var _out: Label
var _guide: Label
var _tag: Label
var _call: Label
var _wash: ColorRect
var _wash_paint: ShaderMaterial
var _flash: ColorRect
var _clock := 0.0
var _call_left := 0.0
var _flash_left := 0.0
var _seals_seen := -1
var _black_seen: Node = null
var _flatlined_seen := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wash = ColorRect.new()
	_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wash_paint = ShaderMaterial.new()
	_wash_paint.shader = VignetteShader
	_wash_paint.set_shader_parameter("color", Palette.BLACK_ICE)
	_wash.material = _wash_paint
	_wash.visible = false
	add_child(_wash)
	_wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash = ColorRect.new()
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(Palette.BLACK_ICE, 0.0)
	_flash.visible = false
	add_child(_flash)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title = _label(TITLE_FONT)
	_what = _label(LINE_FONT)
	_forms = _label(LINE_FONT)
	_out = _label(LINE_FONT)
	_guide = _label(SMALL_FONT)
	_tag = _label(SMALL_FONT)
	_call = _label(26)
	for label in [_title, _what, _forms, _out, _guide, _call]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_refresh()


func _process(delta: float) -> void:
	_clock = fmod(_clock + delta, 3600.0)
	_call_left = maxf(_call_left - delta, 0.0)
	_flash_left = maxf(_flash_left - delta, 0.0)
	_refresh()


func _on() -> bool:
	return ice != null and is_instance_valid(ice) and ice.mode != IceDirector.Mode.OFF


func _black() -> BlackIce:
	if not _on():
		return null
	var b = ice.get("black")
	return b if b != null and is_instance_valid(b) else null


## What the warning says now, line by line ("" lines left out), for the checks.
func warning_text() -> PackedStringArray:
	var out := PackedStringArray()
	for label in [_title, _what, _forms]:
		if label.visible:
			out.append(label.text)
	return out


## The out line and the scripted guide's word under it, for the checks.
func out_text() -> PackedStringArray:
	var out := PackedStringArray()
	for label in [_out, _guide]:
		if label.visible:
			out.append(label.text)
	return out


func call_text() -> String:
	return _call.text if _call.visible else ""


func tag_text() -> String:
	return _tag.text if _tag.visible else ""


## The edges' cold wash now (0 none), for the checks.
func wash() -> float:
	return float(_wash_paint.get_shader_parameter("strength")) if _wash.visible else 0.0


func _refresh() -> void:
	var b := _black()
	var wide := size.x
	var high := size.y
	if b != _black_seen:
		_black_seen = b
		_seals_seen = b.seals_left if b != null else -1
	var arriving := b != null and b.phase == BlackIce.Phase.ARRIVE
	var out := b != null and b.phase == BlackIce.Phase.OUT
	var me := _me()
	var gap := -1.0
	if b != null and me != null:
		gap = Vector2(me.global_position.x - b.global_position.x, me.global_position.z - b.global_position.z).length()
	# A broken seal, its end.
	if b != null and _seals_seen >= 0 and b.seals_left < _seals_seen:
		_say(DOWN_LINE if b.seals_left <= 0 else SEAL_LINE % b.seals_left)
	if b != null:
		_seals_seen = b.seals_left
	# This player flatlined: the flash.
	var flat: bool = _on() and ice.has_method("flatlined_me") and ice.flatlined_me()
	if flat and not _flatlined_seen:
		_flash_left = FLASH_S
	_flatlined_seen = flat
	# The arrival's warning.
	_title.visible = arriving
	_what.visible = arriving
	_forms.visible = arriving
	if arriving:
		var u := clampf(b.phase_t / 0.8, 0.0, 1.0)
		_title.text = TITLE if u >= 1.0 or fmod(_clock * FLICKER_HZ, 1.0) < u else _scramble(TITLE)
		_title.modulate.a = 1.0 if fmod(_clock * 2.0, 1.0) < 0.8 else 0.7
		_what.text = WHAT_LINE
		_forms.text = FORMS_LINE % [b.tell_left(), roundi(maxf(gap, 0.0))]
		var top := high * ARRIVE_TOP
		_place(_title, top)
		_place(_what, top + TITLE_FONT + 10.0)
		_place(_forms, top + TITLE_FONT + 10.0 + LINE_FONT + 8.0)
	# Out: its line, the scripted guide's word.
	_out.visible = out
	_guide.visible = out
	if out:
		_out.text = OUT_LINE % [b.seals_left, b.tuning.seals, roundi(maxf(gap, 0.0))] + (MEND_LINE % b.mend_left if b.seals_left < b.tuning.seals and b.mend_left > 0.0 else "")
		var n := BreakerPick.numbers(breakers)
		_guide.text = GUIDE_LINE % (BreakerPick.scripted(n)[1] if not n.is_empty() else BreakerPick.BLACK[""])
		_place(_out, OUT_TOP)
		_place(_guide, OUT_TOP + LINE_FONT + 6.0)
	# Its tag in the world, or at the edge.
	_tag.visible = false
	if (arriving or out) and gap >= 0.0:
		_place_tag(b, gap)
	# The edges, colder and darker as it comes near.
	var near := 0.0
	if out and gap >= 0.0:
		near = 1.0 - clampf((gap - b.tuning.touch_m) / maxf(NEAR_M - b.tuning.touch_m, 0.1), 0.0, 1.0)
	var pulse := 0.8 + 0.2 * sin(_clock * TAU * lerpf(0.6, 2.4, near))
	_wash.visible = near > 0.001
	_wash_paint.set_shader_parameter("strength", NEAR_WASH * near * pulse if _wash.visible else 0.0)
	# A call-out, the flash.
	_call.visible = _call_left > 0.0
	if _call.visible:
		_call.modulate.a = clampf(_call_left / 0.5, 0.0, 1.0)
		_place(_call, high * 0.34)
	_flash.visible = _flash_left > 0.0
	_flash.color = Color(Palette.BLACK_ICE, 0.55 * _flash_left / FLASH_S)


func _say(text: String) -> void:
	_call.text = text
	_call_left = CALL_S


func _place(label: Label, top: float) -> void:
	var need := label.get_combined_minimum_size()
	label.size = need
	label.position = Vector2((size.x - need.x) * 0.5, top)


## Its tag over its crown, or at the screen's left or right edge with an arrow when it is off screen.
func _place_tag(b: BlackIce, gap: float) -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return
	var head := b.global_position + Vector3.UP * (b.tuning.height_m + 0.4)
	var meters := roundi(gap)
	var ahead := not cam.is_position_behind(head)
	var at := cam.unproject_position(head) if ahead else Vector2(-1.0, -1.0)
	var screen := get_viewport_rect().size
	var on_screen := ahead and at.x >= EDGE_PX and at.x <= screen.x - EDGE_PX and at.y >= EDGE_PX and at.y <= screen.y - EDGE_PX
	if on_screen and gap < TAG_NEAR_M:
		return  # this near and in view it fills the view: no tag
	if on_screen:
		_tag.text = TAG % meters
	else:
		var right := cam.global_transform.basis.x.dot(head - cam.global_position) > 0.0
		_tag.text = (RIGHT_TAG if right else LEFT_TAG) % meters
	var need := _tag.get_combined_minimum_size()
	_tag.size = need
	if on_screen:
		_tag.position = at - Vector2(need.x * 0.5, need.y) - get_global_rect().position
		_tag.position.y = maxf(_tag.position.y, TAG_BELOW)
	else:
		var right := _tag.text.ends_with(">")
		_tag.position = Vector2(screen.x - EDGE_PX - need.x if right else EDGE_PX, screen.y * 0.5 - need.y * 0.5) - get_global_rect().position
	_tag.visible = true


func _me() -> Node3D:
	var p = ice.get("player") if _on() else null
	return p if p != null and is_instance_valid(p) and p.is_inside_tree() else null


func _scramble(text: String) -> String:
	var out := ""
	var tick := int(_clock * FLICKER_HZ)
	for i in text.length():
		var c := text[i]
		out += c if c == " " or (tick + i * 7) % 3 != 0 else SCRAMBLE[(tick * 5 + i * 3) % SCRAMBLE.length()]
	return out


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", Palette.mono_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Palette.BLACK_ICE_TEXT)
	label.add_theme_color_override("font_outline_color", Palette.VOID)
	label.add_theme_constant_override("outline_size", 5)
	label.visible = false
	add_child(label)
	return label
