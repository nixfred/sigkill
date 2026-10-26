@tool
extends StaticBody3D
## Greybox building block: one box of visible mesh plus matching collision.
## Set `size` and `kind` in the inspector. @tool, so it previews in the editor.

const Palette = preload("res://scripts/palette.gd")
## Blocks that carry the code rain shader join this group for scripts/code_rain_driver.gd.
const RAIN_GROUP := &"code_rain_surfaces"

@export var size: Vector3 = Vector3(4.0, 3.0, 0.4):
	set(value):
		size = value
		_refresh()

@export_enum("wall", "floor", "accent", "crate") var kind: int = 0:
	set(value):
		kind = value
		_refresh()

var _mesh_instance: MeshInstance3D
var _shape_node: CollisionShape3D


func _enter_tree() -> void:
	# Joined here, before the tree's node_added signal fires, so the rain driver sees it.
	if kind != Palette.Surface.FLOOR:
		add_to_group(RAIN_GROUP)
	elif is_in_group(RAIN_GROUP):
		remove_from_group(RAIN_GROUP)


func _ready() -> void:
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "Mesh"
	add_child(_mesh_instance)
	_shape_node = CollisionShape3D.new()
	_shape_node.name = "Shape"
	add_child(_shape_node)
	_refresh()


## The block's material, once it is in the tree.
func surface_material() -> ShaderMaterial:
	return _mesh_instance.material_override as ShaderMaterial if _mesh_instance != null else null


func _refresh() -> void:
	if _mesh_instance == null or _shape_node == null:
		return
	var box := BoxMesh.new()
	box.size = size
	_mesh_instance.mesh = box
	_mesh_instance.material_override = Palette.surface(kind, size)
	var shape := BoxShape3D.new()
	shape.size = size
	_shape_node.shape = shape
