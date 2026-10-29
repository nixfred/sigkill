extends Control
## The ICEbreakers' readout (I2), bottom left, right over the sudo badge (the corner of the player's own
## abilities), never on the weapon strip: two short lines in the breakers' ultraviolet. The first is the
## loaded breaker with the key that runs it and how many are carried ("U BRUTE 1", dimmed with none
## left); the second the key that loads the next and all four counts by their initials, the loaded one
## bracketed ("Y [b1] e1 c1 d1": brute, exploit, cloak, decoy). Not over the strip: at 960x540 the
## column over it is the kill feed's (which cannot rise without going under the multiplayer panel) and
## the guide panel's centred column takes the room to its left; here it is clear of both, and the strip
## keeps its whole column for C29's second weapon bank.
##
## While a breaker's effect runs on this player, its line stands under the crosshair (under grep's
## count): "EXPLOIT 4.2s" while hits on the marked seams land harder; "CLOAKED 3.1s" while ICE and the
## daemons cannot see this player, with the screen's edges washed ultraviolet, both blinking in the
## cloak's last cloak_warn_s so the player knows when it ends, and "firing ends it" beside it. A short
## notice over the readout says what just happened: a breaker run, none left of the loaded kind, one
## taken from a pickup. Shown only while breakers are carried (not in practice). It reads the breaker
## director (scripts/ice/breaker_director.gd) every frame and changes nothing.

const Palette = preload("res://scripts/palette.gd")
const Controls = preload("res://scripts/controls.gd")
const Kinds = preload("res://scripts/ice/breakers.gd")
const VignetteShader = preload("res://shaders/damage_vignette.gdshader")

const LOADED_LINE := "%s %s %d"
const COUNTS_LINE := "%s %s"
const COUNT := "%s%d"
const COUNT_LOADED := "[%s%d]"
const EXPLOIT_LINE := "EXPLOIT %.1fs"
const CLOAK_LINE := "CLOAKED %.1fs  firing ends it"
const RAN_NOTICE := "%s run"
const EMPTY_NOTICE := "no %s left"
const PICKED_NOTICE := "+1 %s"
const FONT := 13
const SMALL_FONT := 11
const EFFECT_FONT := 16
## The left margin when the sudo badge is down (the badge's own).
const MARGIN := 14
## The readout's gap over the sudo badge (and its place when the badge is down), and where the effect
## lines stand under the crosshair (below grep's count line, which is 26 px down).
const OVER_BADGE := 4.0
const BADGE_TOP := 60.0
const EFFECT_DROP := 52.0
## How long a notice shows, how dim a breaker with none left is, the cloak's edge wash and its blink.
const NOTICE_S := 1.6
const DIM := 0.45
const WASH := 0.5
const BLINK_HZ := 4.0

## The breaker director whose readout this is (this player's), and the sudo badge it sits over.
var director: Node = null
var sudo_badge: Control = null

var _box: VBoxContainer
var _loaded: Label
var _counts: Label
var _notice: Label
var _notice_left := 0.0
var _effects: VBoxContainer
var _exploit: Label
var _cloak: Label
var _wash: ColorRect
var _wash_paint: ShaderMaterial
var _clock := 0.0
var _hooked: Node = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wash = ColorRect.new()
	_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wash_paint = ShaderMaterial.new()
	_wash_paint.shader = VignetteShader
	_wash_paint.set_shader_parameter("color", Palette.BREAKER)
	_wash.material = _wash_paint
	_wash.visible = false
	add_child(_wash)
	_wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box = VBoxContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_constant_override("separation", 0)
	add_child(_box)
	_notice = _label(_box, SMALL_FONT)
	_loaded = _label(_box, FONT)
	_counts = _label(_box, SMALL_FONT)
	_effects = VBoxContainer.new()
	_effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effects.add_theme_constant_override("separation", 2)
	add_child(_effects)
	_exploit = _label(_effects, EFFECT_FONT)
	_cloak = _label(_effects, EFFECT_FONT)
	for label in [_exploit, _cloak]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_refresh()


func _process(delta: float) -> void:
	_clock = fmod(_clock + delta, 3600.0)
	_notice_left = maxf(_notice_left - delta, 0.0)
	_hook()
	_refresh()


## The readout's box (I1's HUD corruption scrambles it; the jam notice stands over it).
func box() -> Control:
	return _box


func loaded_text() -> String:
	return _loaded.text if _box.visible else ""


func counts_text() -> String:
	return _counts.text if _box.visible else ""


func notice_text() -> String:
	return _notice.text if _box.visible and _notice_left > 0.0 else ""


## The effect lines shown under the crosshair now.
func effect_text() -> PackedStringArray:
	var out := PackedStringArray()
	for label in [_exploit, _cloak]:
		if label.visible:
			out.append(label.text)
	return out


## How strong the cloak's edge wash is now (0 none).
func wash() -> float:
	return float(_wash_paint.get_shader_parameter("strength")) if _wash.visible else 0.0


func _on() -> bool:
	return director != null and is_instance_valid(director) and director.mode != BreakerDirector.Mode.OFF


## Listens for this director's runs, empty presses and pickups (once per director).
func _hook() -> void:
	if not _on() or _hooked == director:
		return
	_hooked = director
	director.ran.connect(func(kind: int): _say(RAN_NOTICE % Kinds.name_of(kind)))
	director.empty.connect(func(kind: int): _say(EMPTY_NOTICE % Kinds.name_of(kind)))
	director.picked.connect(func(kind: int): _say(PICKED_NOTICE % Kinds.name_of(kind)))


func _say(text: String) -> void:
	_notice.text = text
	_notice_left = NOTICE_S


func _refresh() -> void:
	var on := _on()
	var alive: bool = on and director.player != null and is_instance_valid(director.player) and director.player.get("alive") != false
	_box.visible = on
	_effects.visible = alive
	_wash.visible = alive and director.my_cloak > 0.0
	if not on:
		return
	var b: Breakers = director.mine
	var kind: int = b.loaded
	var run_key := Controls.bind_label(GameSettings.current().bind("run_breaker"))
	var next_key := Controls.bind_label(GameSettings.current().bind("cycle_breaker"))
	_loaded.text = LOADED_LINE % [run_key, Kinds.name_of(kind).to_upper(), b.count(kind)]
	_loaded.modulate.a = 1.0 if b.count(kind) > 0 else DIM
	var parts := PackedStringArray()
	for k in Kinds.NAMES.size():
		parts.append((COUNT_LOADED if k == kind else COUNT) % [Kinds.name_of(k).left(1), b.count(k)])
	_counts.text = COUNTS_LINE % [next_key, " ".join(parts)]
	_notice.modulate.a = 1.0 if _notice_left > 0.0 else 0.0
	# Bottom left, right over the sudo badge.
	var wide := size.x
	var origin := get_global_rect().position
	var badge := sudo_badge.get_global_rect() if sudo_badge != null and sudo_badge.is_visible_in_tree() else Rect2(origin + Vector2(MARGIN, size.y - BADGE_TOP), Vector2.ZERO)
	var need := _box.get_combined_minimum_size()
	_box.size = need
	_box.position = Vector2(badge.position.x - origin.x, badge.position.y - origin.y - need.y - OVER_BADGE)
	# The effects, under the crosshair.
	var warn: bool = director.cloak_warning()
	var blink := 1.0 if not warn or fmod(_clock * BLINK_HZ, 1.0) < 0.6 else 0.25
	_exploit.visible = alive and director.my_exploit > 0.0
	_exploit.text = EXPLOIT_LINE % director.my_exploit
	_cloak.visible = alive and director.my_cloak > 0.0
	_cloak.text = CLOAK_LINE % director.my_cloak
	_cloak.modulate.a = blink
	var lines := _effects.get_combined_minimum_size()
	_effects.size = lines
	_effects.position = Vector2((wide - lines.x) * 0.5, size.y * 0.5 + EFFECT_DROP)
	_wash_paint.set_shader_parameter("strength", WASH * blink if _wash.visible else 0.0)


func _label(parent: Control, font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", Palette.mono_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Palette.BREAKER_TEXT)
	label.add_theme_color_override("font_outline_color", Palette.VOID)
	label.add_theme_constant_override("outline_size", 4)
	parent.add_child(label)
	return label
