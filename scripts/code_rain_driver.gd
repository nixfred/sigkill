extends Node
## Drives the Matrix code rain on the greybox blocks: tells shaders/code_rain.gdshader
## where the live enemies are and how strongly each one counts.
##
## Design: the shader does the spatial work. This node keeps one slot per sampled enemy
## (world position plus a weight from 0 to 1) and uploads the slots to every block
## material as one small uniform array, so the rain pools per pixel around each enemy and
## bleeds through to both sides of a wall. The weight is the part that moves in time: it
## climbs at fade_in_rate while the enemy is alive and falls at fade_out_rate once it
## derezzes, with move_toward, so it converges exactly and never overshoots. Distance does
## the rest, continuously, in the shader. When more enemies are alive than the shader's
## array holds, the nearest ones to the viewer are the ones sampled.
##
## The settings' quality preset (C16b) turns the rain off with set_enabled(false): every
## material is told there are no enemies, so no rain is drawn, and the driver rests.
##
## Cost: runs in _physics_process, so at the fixed physics rate. The lists of blocks and
## enemies are collected only when a block or target enters or leaves the tree, or a block
## rebuilds its material; that collection allocates and uploads once. Every other tick
## allocates nothing: the slot arrays are preallocated and alternate, and nothing is
## uploaded when no slot changed, so a settled arena costs a few comparisons a tick.

const Palette = preload("res://scripts/palette.gd")
const Tuning = preload("res://scripts/code_rain_tuning.gd")
const DEFAULT_TUNING_PATH := "res://resources/code_rain.tres"
## Greybox blocks that carry the code rain shader join this group (scripts/grey_block.gd).
const SURFACE_GROUP := &"code_rain_surfaces"
## Target dummies, the enemies the walls react to.
const TARGET_GROUP := &"targets"
## The driver's own group. scripts/grey_block.gd calls invalidate() on it through this.
const DRIVER_GROUP := &"code_rain_driver"
## Tuning values pushed into every surface material as they are.
const TUNING_UNIFORMS := [
	"falloff_radius", "min_intensity", "max_intensity", "column_density", "glyph_size",
	"fall_speed_min", "fall_speed_max", "tail_length", "flicker_rate", "rain_energy",
	"head_color", "tail_color",
]

## Code rain tuning. Leave empty to use resources/code_rain.tres.
@export var tuning: Resource

## Whose view the nearest enemies are picked for. main.gd sets the player; unset, the origin.
var viewer: Node3D

var _t: Tuning
var _materials: Array[ShaderMaterial] = []
var _targets: Array[Node3D] = []
var _weights := PackedFloat32Array()  # per target, smoothed 0 to 1
var _chosen := PackedInt32Array()  # indices of the sampled targets, nearest first
var _chosen_distance := PackedFloat32Array()  # their squared distances to the viewer
var _slots := PackedVector4Array()  # what the materials hold: xyz position, w weight
var _next := PackedVector4Array()  # scratch for the coming tick, swapped in on change
var _slot_count := 0
var _dirty := true  # the set of blocks or targets changed: collect again next tick
var _uploads := 0  # how many times the slots went to the materials, for tests
var _enabled := true


func _ready() -> void:
	if not (tuning is Tuning):
		tuning = load(DEFAULT_TUNING_PATH)
	_t = tuning as Tuning
	if _t == null:
		push_error("code rain: no tuning resource at " + DEFAULT_TUNING_PATH)
		_t = Tuning.new()
	var issues := _t.problems()
	if not issues.is_empty():
		for issue in issues:
			push_warning("code rain tuning: " + issue + "; using the built-in defaults instead")
		_t = Tuning.new()
	_slots.resize(Tuning.MAX_ENEMIES)
	_next.resize(Tuning.MAX_ENEMIES)
	_chosen.resize(Tuning.MAX_ENEMIES)
	_chosen_distance.resize(Tuning.MAX_ENEMIES)
	add_to_group(DRIVER_GROUP)
	var tree := get_tree()
	tree.node_added.connect(_on_node_changed)
	tree.node_removed.connect(_on_node_changed)


## The tuning in use: the resource given, or the built-in defaults if it was unusable.
func active_tuning() -> Tuning:
	return _t


## Rain intensity the shader shows at a world point, 0 to 1, from the slots as uploaded.
## Mirrors proximity() in shaders/code_rain.gdshader; the headless test holds them together.
func intensity_at(point: Vector3) -> float:
	var clear := 1.0
	for k in _slot_count:
		var s := _slots[k]
		var d := point.distance_to(Vector3(s.x, s.y, s.z))
		clear *= 1.0 - s.w * (1.0 - smoothstep(0.0, _t.falloff_radius, d))
	return lerpf(_t.min_intensity, _t.max_intensity, 1.0 - clear)


## Enemies currently sampled by the shader.
func slot_count() -> int:
	return _slot_count


## The uploaded slots: xyz world position, w weight. Entries past slot_count() are stale.
func slots() -> PackedVector4Array:
	return _slots


## Smoothed weight of one target, 0 to 1, or -1 if it is not a known target.
func weight_of(target: Node3D) -> float:
	var i := _targets.find(target)
	return _weights[i] if i >= 0 else -1.0


## Block materials the rain is driven on.
func surface_count() -> int:
	return _materials.size()


## Targets the driver knows about, alive or not.
func target_count() -> int:
	return _targets.size()


## Times the slots were uploaded to the materials since the driver started.
func upload_count() -> int:
	return _uploads


## Collect the blocks and targets again on the next tick. Blocks call it when their
## material is rebuilt, so the driver never keeps feeding a material nothing shows.
func invalidate() -> void:
	_dirty = true


## The rain on or off (the quality preset). Off uploads no enemies at once.
func set_enabled(on: bool) -> void:
	if on == _enabled:
		return
	_enabled = on
	_upload()


func is_enabled() -> bool:
	return _enabled


func _on_node_changed(node: Node) -> void:
	if node.is_in_group(TARGET_GROUP) or node.is_in_group(SURFACE_GROUP):
		_dirty = true


func _physics_process(delta: float) -> void:
	if _dirty:
		_collect()
	if not _enabled:
		return
	# Weights: each target's rain climbs while it is alive and falls once it is not.
	for i in _targets.size():
		var want := 1.0 if _targets[i].call("is_alive") else 0.0
		var w := _weights[i]
		if w != want:
			var rate: float = _t.fade_in_rate if want > w else _t.fade_out_rate
			_weights[i] = move_toward(w, want, rate * delta)
	# Sample the nearest targets to the viewer among those with any rain left.
	var origin := Vector3.ZERO
	if is_instance_valid(viewer) and viewer.is_inside_tree():
		origin = viewer.global_position
	var cap: int = _t.max_enemies_sampled
	var count := 0
	for i in _targets.size():
		if _weights[i] <= 0.0:
			continue
		var p: Vector3 = _targets[i].call("threat_point")
		var d := origin.distance_squared_to(p)
		# Insert into the nearest-first list, dropping the farthest past the cap.
		var at := count if count < cap else cap - 1
		if at == cap - 1 and count == cap and d >= _chosen_distance[at]:
			continue
		while at > 0 and d < _chosen_distance[at - 1]:
			_chosen[at] = _chosen[at - 1]
			_chosen_distance[at] = _chosen_distance[at - 1]
			at -= 1
		_chosen[at] = i
		_chosen_distance[at] = d
		count = mini(count + 1, cap)
	var changed := count != _slot_count
	for k in count:
		var i := _chosen[k]
		var p: Vector3 = _targets[i].call("threat_point")
		var slot := Vector4(p.x, p.y, p.z, _weights[i])
		_next[k] = slot
		if slot != _slots[k]:
			changed = true
	if changed:
		var filled := _next
		_next = _slots
		_slots = filled
		_slot_count = count
		_upload()


## Gathers every block material and target in the tree. Allocates, so only on change.
func _collect() -> void:
	_dirty = false
	var tree := get_tree()
	_materials.clear()
	for block in tree.get_nodes_in_group(SURFACE_GROUP):
		var mat: ShaderMaterial = block.call("surface_material")
		if mat != null and mat.shader != null and mat.shader.resource_path.get_file() == Palette.CODE_RAIN_SHADER + ".gdshader":
			_materials.append(mat)
	var old_targets := _targets
	var old_weights := _weights
	_targets = []
	_weights = PackedFloat32Array()
	for node in tree.get_nodes_in_group(TARGET_GROUP):
		var target := node as Node3D
		if target == null or not target.has_method("is_alive") or not target.has_method("threat_point"):
			continue
		var was := old_targets.find(target)
		_targets.append(target)
		_weights.append(old_weights[was] if was >= 0 else 0.0)
	for mat in _materials:
		for field in TUNING_UNIFORMS:
			mat.set_shader_parameter(field, _t.get(field))
	_upload()


func _upload() -> void:
	_uploads += 1
	for mat in _materials:
		mat.set_shader_parameter("enemies", _slots)
		mat.set_shader_parameter("enemy_count", _slot_count if _enabled else 0)
