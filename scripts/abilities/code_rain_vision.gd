extends Node
## Code-rain vision (C21, PRD 5.3: "see enemies through walls as glyphs, drains fast"), the
## player's ability: hold V (rebindable in the settings) and every enemy body within
## range_m shows as a silhouette of the walls' own Matrix glyphs, through any wall, while the
## world on your screen dims toward green. Releasing V, an empty meter, a death, a respawn,
## the Esc menu or the ask box (anything that stops the player's input) and leaving a match
## turn it off; none of them changes the meter, and a start needs a new press of V. One of
## these lives under the player (scripts/player.gd makes it), beside SIGSTOP. Its numbers are
## resources/code_rain_vision.tres, its meter's rules scripts/abilities/code_rain_vision_meter.gd,
## and the glyphs come from the code rain's own tuning, resources/code_rain.tres.
##
## The enemies: alone, the arena's target dummies; in a match, the other players, from the
## avatars this machine already draws. Purely local and visual: it reads only positions this
## machine already has, sends nothing, asks the host nothing, and nobody else ever learns of
## it. Your weapons fire as always.
##
## The look: a full-screen layer under the HUD multiplies the picture toward the tint, eased
## in and out over fade_s, never a flash. With the comfort settings (screen shake or motion
## blur turned off) the tint is calmer and the glyphs hold still.
##
## Cosmetic fiction: nothing real is watched, read or signalled.

## Vision came on, and went off (released, emptied, or a hard stop).
signal started
signal ended

const TuningScript = preload("res://scripts/abilities/code_rain_vision_tuning.gd")
const Meter = preload("res://scripts/abilities/code_rain_vision_meter.gd")
const RainTuning = preload("res://scripts/code_rain_tuning.gd")
const GlyphShader = preload("res://shaders/vision_glyphs.gdshader")
const DEFAULT_TUNING_PATH := "res://resources/code_rain_vision.tres"
const RAIN_TUNING_PATH := "res://resources/code_rain.tres"
## Over the 3D world, under the HUD (layer 1), as SIGSTOP's look.
const LOOK_LAYER := 0
## Target dummies: the enemies alone.
const TARGET_GROUP := &"targets"
## A target dummy's middle above its origin (scenes/target_dummy.tscn); a remote player's
## origin is its middle already.
const DUMMY_MIDDLE_M := 0.9
## The walls' glyph values the silhouettes take as they are.
const RAIN_UNIFORMS := ["glyph_size", "column_density", "fall_speed_min", "fall_speed_max", "tail_length", "flicker_rate", "head_color", "tail_color"]

## A CodeRainVisionTuning; null for resources/code_rain_vision.tres. Set before the node
## enters the tree.
var tuning: Resource = null
## The session beside the arena (scripts/net/net_session.gd), set by it when it attaches:
## whether a match is on, and its avatars.
var session: Node = null
## The meter, this machine's alone.
var meter: Meter

var _t: TuningScript
var _rain: RainTuning
var _held := false
var _press := false
var _look := 0.0
var _calm := false
var _was_online := false
var _layer: CanvasLayer
var _cover: ColorRect
var _paint: ShaderMaterial
var _markers: Array[MeshInstance3D] = []
var _marked: Array[Node3D] = []


static func usable_tuning(candidate: Resource) -> TuningScript:
	if candidate is TuningScript:
		var issues: PackedStringArray = candidate.problems()
		if issues.is_empty():
			return candidate
		for issue in issues:
			push_warning("code rain vision tuning: " + issue + "; using the shipped tuning instead")
	var shipped = load(DEFAULT_TUNING_PATH)
	if shipped is TuningScript and shipped.problems().is_empty():
		return shipped
	return TuningScript.new()


func _ready() -> void:
	_t = usable_tuning(tuning)
	var rain = load(RAIN_TUNING_PATH)
	_rain = rain if rain is RainTuning and rain.problems().is_empty() else RainTuning.new()
	meter = Meter.new(_t)
	_build_look()


func tuning_in_use() -> TuningScript:
	return _t


## V held (true) or let go (false). A start is taken on the next physics frame and needs a
## press: holding V on through an empty meter never starts it again.
func hold(on: bool) -> void:
	if on and not _held:
		_press = true
	_held = on


func is_on() -> bool:
	return meter.on


func is_held() -> bool:
	return _held


## True when a press now would start vision.
func can_start() -> bool:
	return meter.can_start()


## How strong the look is now, from 0 to its full strength (calmer with the comfort settings).
func look_strength() -> float:
	return _look * (_t.calm_strength if _calm else _t.strength)


## True while the comfort settings make the look calmer and hold the glyphs still.
func calm() -> bool:
	return _calm


## The enemies shown as silhouettes right now, nearest first.
func marked() -> Array[Node3D]:
	return _marked.duplicate()


## The silhouette standing on `enemy`, or null when it has none.
func marker_of(enemy: Node3D) -> MeshInstance3D:
	var at := _marked.find(enemy)
	return _markers[at] if at >= 0 else null


## The silhouettes' material: every marker shares it.
func marker_material() -> ShaderMaterial:
	return _paint


## Vision off at once, the meter as it is (a death, a respawn, the menu). The hold is let
## go too: a key released while input was stopped never says so, and a new press is needed.
func end_now() -> void:
	_held = false
	if meter.stop():
		ended.emit()
	_show_markers([])


## A death: vision off, the meter left as it was.
func on_death() -> void:
	end_now()


func _physics_process(_delta: float) -> void:
	var real := 1.0 / maxf(float(Engine.physics_ticks_per_second), 1.0)
	var player := get_parent()
	var alive: bool = player == null or player.get("alive") != false
	var blocked: bool = player != null and player.get("input_blocked") == true
	var online := _online()
	if online != _was_online:
		_was_online = online
		end_now()  # a match starting or ending: vision off
	var pressed := _press
	_press = false
	if pressed and alive and not blocked and meter.start():
		started.emit()
	if meter.on and (not _held or not alive or blocked):
		end_now()
	elif not alive or blocked:
		_held = false  # whatever V does meanwhile, the next start is a new press
	if meter.tick(real, alive):
		ended.emit()  # the meter ran out
	_step_look(real)
	_show_markers(_enemies_in_sight() if meter.on else [])


## The look follows vision: up while it is on, down after, over fade_s.
func _step_look(real: float) -> void:
	var calm_now := _comfort()
	if calm_now != _calm:
		_calm = calm_now
		_paint.set_shader_parameter("flicker_rate", 0.0 if _calm else _rain.flicker_rate)
	_look = move_toward(_look, 1.0 if meter.on else 0.0, real / maxf(_t.fade_s, 0.001))
	_cover.color = Color.WHITE.lerp(_t.tint, look_strength())
	_cover.visible = _look > 0.0
	_paint.set_shader_parameter("strength", _look)


## The comfort settings: screen shake or motion blur turned off asks for a calmer screen.
func _comfort() -> bool:
	var s := GameSettings.current()
	return s.value("hud", "screen_shake") == false or s.value("hud", "motion_blur") == false


## Every enemy body within range_m of this player, nearest first, at most MARKERS_LAST, each
## with its middle: [body, middle].
func _enemies_in_sight() -> Array:
	var player := get_parent() as Node3D
	if player == null:
		return []
	var seen := []
	for body in _enemies():
		var middle: Vector3 = body.global_position + (Vector3.UP * DUMMY_MIDDLE_M if body.is_in_group(TARGET_GROUP) else Vector3.ZERO)
		var far := middle.distance_to(player.global_position)
		if far <= _t.range_m:
			seen.append([body, middle, far])
	seen.sort_custom(func(a, b): return a[2] < b[2])
	return seen.slice(0, TuningScript.MARKERS_LAST)


## The enemies of this player: alone, the living target dummies of its own arena; in a
## match, the other players' living avatars.
func _enemies() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if _online():
		for avatar in session.avatars.values():
			if avatar != null and is_instance_valid(avatar) and avatar.visible and not avatar.get("dead"):
				out.append(avatar)
		return out
	var player := get_parent()
	var arena: Node = player.get_parent() if player != null else null
	if arena == null:
		return out
	for body in get_tree().get_nodes_in_group(TARGET_GROUP):
		if body is Node3D and arena.is_ancestor_of(body) and (not body.has_method("is_alive") or body.call("is_alive")):
			out.append(body)
	return out


## Stands a silhouette on each of `seen` ([body, middle] each), hides the rest.
func _show_markers(seen: Array) -> void:
	while _markers.size() < seen.size():
		_markers.append(_marker())
	_marked.clear()
	for i in _markers.size():
		var shown := i < seen.size()
		_markers[i].visible = shown
		if shown:
			_markers[i].global_position = seen[i][1]
			_marked.append(seen[i][0])


func _marker() -> MeshInstance3D:
	var capsule := CapsuleMesh.new()
	capsule.radius = _t.marker_radius_m
	capsule.height = _t.marker_height_m
	capsule.radial_segments = 12
	capsule.rings = 4
	var marker := MeshInstance3D.new()
	marker.name = "VisionMarker%d" % _markers.size()
	marker.mesh = capsule
	marker.material_override = _paint
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.top_level = true
	marker.visible = false
	add_child(marker)
	return marker


func _online() -> bool:
	return session != null and is_instance_valid(session) and session.has_method("is_online") and session.is_online()


## The look (a full-screen layer that multiplies the picture toward the tint, hidden while
## off) and the silhouettes' one material, the walls' glyphs over everything.
func _build_look() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "VisionLook"
	_layer.layer = LOOK_LAYER
	add_child(_layer)
	_cover = ColorRect.new()
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var multiply := CanvasItemMaterial.new()
	multiply.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	_cover.material = multiply
	_cover.color = Color.WHITE
	_layer.add_child(_cover)
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover.visible = false
	_paint = ShaderMaterial.new()
	_paint.shader = GlyphShader
	_paint.render_priority = Material.RENDER_PRIORITY_MAX
	for key in RAIN_UNIFORMS:
		_paint.set_shader_parameter(key, _rain.get(key))
	_paint.set_shader_parameter("energy", _t.marker_energy)
	_paint.set_shader_parameter("strength", 0.0)
	_calm = _comfort()
	_paint.set_shader_parameter("flicker_rate", 0.0 if _calm else _rain.flicker_rate)
