class_name RootDoor
extends StaticBody3D
## A door only root may pass (M5, docs/STORY.md mission 5: "a sealed room opens only to root#"): a solid panel across a
## doorway, its frame lit root's red and its mode written on it, that sinks into the floor while the player is root#
## (scripts/abilities/sudo_overcharge.gd) and rises again as root ends. A mission's stage stands one at a "door" prop
## (scripts/missions/mission_stage.gd) and tells it each frame whether the player is root (set_open()); nothing else
## opens it: no weapon, no breaker, no shot. Shut, it is a wall to a step and a shot (the level's own layer); open past
## OPEN_PAST, it stops nothing.
##
## Cosmetic fiction: "root" and "mode 0700" are words on a panel. Nothing real is checked or changed.

const Palette = preload("res://scripts/palette.gd")

const GROUP := "mission_doors"
## Seconds the panel takes to sink out of the way, and to rise back; past this share open it stops nothing.
const OPEN_S := 0.9
const SHUT_S := 0.6
const OPEN_PAST := 0.85
const THICK := 0.36
const FRAME := 0.16
const GLOW := 2.4
const WORDS := "ROOT ONLY"
const MODE := "mode 0700  owner root"

## Across and tall, metres (set before it enters the tree).
var span := Vector2(3.4, 3.6)

var _open := 0.0
var _want := false
var _panel: Node3D
var _shape: CollisionShape3D
var _labels: Array[Label3D] = []


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = 1
	collision_mask = 0
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(span.x, span.y, THICK)
	_shape.shape = box
	_shape.position = Vector3(0, span.y * 0.5, 0)
	add_child(_shape)
	_panel = Node3D.new()
	_panel.name = "Panel"
	add_child(_panel)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.02, 0.022, 0.03)
	dark.metallic = 0.6
	dark.roughness = 0.35
	var slab := MeshInstance3D.new()
	var slab_mesh := BoxMesh.new()
	slab_mesh.size = Vector3(span.x - FRAME * 2.0, span.y - FRAME, THICK * 0.6)
	slab.mesh = slab_mesh
	slab.material_override = dark
	slab.position = Vector3(0, (span.y - FRAME) * 0.5, 0)
	_panel.add_child(slab)
	var lit := StandardMaterial3D.new()
	lit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lit.albedo_color = Palette.HOSTILE_RED * GLOW
	lit.disable_fog = true
	# The frame: both uprights, the lintel, and a bar across the middle; nothing at the foot (it sinks through it).
	for part in [[Vector3(-(span.x - FRAME) * 0.5, span.y * 0.5, 0), Vector3(FRAME, span.y, THICK)], [Vector3((span.x - FRAME) * 0.5, span.y * 0.5, 0), Vector3(FRAME, span.y, THICK)], [Vector3(0, span.y - FRAME * 0.5, 0), Vector3(span.x, FRAME, THICK)], [Vector3(0, span.y * 0.5, 0), Vector3(span.x, FRAME * 0.5, THICK * 0.8)]]:
		var m := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = part[1]
		m.mesh = mesh
		m.material_override = lit
		m.position = part[0]
		_panel.add_child(m)
	for side in [1.0, -1.0]:
		for text in [[WORDS, span.y * 0.5 + 0.55, 0.42], [MODE, span.y * 0.5 - 0.5, 0.16]]:
			var label := Label3D.new()
			label.text = text[0]
			label.font = Palette.mono_font()
			label.font_size = 64
			label.pixel_size = float(text[2]) / 64.0
			label.modulate = Palette.HOSTILE_RED
			label.outline_modulate = Color(0, 0, 0, 0.9)
			label.outline_size = 8
			label.shaded = false
			label.double_sided = false
			label.no_depth_test = false
			label.position = Vector3(0, float(text[1]), side * (THICK * 0.3 + 0.01))
			label.rotation.y = 0.0 if side > 0.0 else PI
			_panel.add_child(label)
			_labels.append(label)


## Open while `on` (the player root): the panel sinks; shut again as it ends.
func set_open(on: bool) -> void:
	_want = on


## How far open it is, 0 shut to 1 sunk out of the way.
func open_share() -> float:
	return _open


## True while it stops a step and a shot.
func blocking() -> bool:
	return _open < OPEN_PAST


func _process(delta: float) -> void:
	var before := _open
	_open = move_toward(_open, 1.0 if _want else 0.0, delta / (OPEN_S if _want else SHUT_S))
	if _open != before:
		var k := _open * _open * (3.0 - 2.0 * _open)
		_panel.position.y = -span.y * k
		var fade := clampf(1.0 - k * 1.6, 0.0, 1.0)
		for label in _labels:
			label.modulate = Color(Palette.HOSTILE_RED, fade)
	_shape.disabled = not blocking()
