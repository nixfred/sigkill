extends StaticBody3D
## Static target dummy: a hexagonal prism standing in for a rogue process.
## One clean hit and it flashes, shrinks and despawns. It never moves or attacks.
## The tag text is invented flavour only; it never reflects anything on the player's system.

const Palette = preload("res://scripts/palette.gd")

## Emitted once, on the hit that removes the dummy.
signal downed(dummy: Node3D)

const DESPAWN_SECONDS := 0.2

@export var tag_text: String = "<defunct>"
@export var max_health: float = 1.0

var _health := 1.0
var _dead := false
var _material: ShaderMaterial

@onready var _body: MeshInstance3D = $Body
@onready var _shape: CollisionShape3D = $Shape
@onready var _tag: Label3D = $Tag


func _ready() -> void:
	_health = max_health
	var hex := _body.mesh as CylinderMesh
	_material = Palette.hostile_material(hex.top_radius, hex.height)
	_body.material_override = _material

	_tag.text = tag_text
	_tag.font = Palette.mono_font()
	_tag.font_size = 48
	_tag.pixel_size = 0.006
	_tag.outline_size = 10
	_tag.modulate = Palette.MINT
	_tag.outline_modulate = Palette.VOID
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED


## Called by the player's cannon through the ray hit.
func hit(damage: float, _point: Vector3 = Vector3.ZERO) -> void:
	if _dead:
		return
	_health -= damage
	if _health > 0.0:
		_pulse()
		return
	_dead = true
	_shape.set_deferred("disabled", true)
	downed.emit(self)
	_despawn()


func _pulse() -> void:
	_material.set_shader_parameter("edge_color", Palette.HOSTILE_AMBER)
	_material.set_shader_parameter("edge_energy", 8.0)
	var tween := create_tween()
	tween.tween_property(_material, "shader_parameter/edge_energy", Palette.HOSTILE_ENERGY, 0.12)
	tween.parallel().tween_property(_material, "shader_parameter/edge_color", Palette.HOSTILE_RED, 0.12)


func _despawn() -> void:
	_material.set_shader_parameter("edge_color", Palette.FLASH)
	_material.set_shader_parameter("edge_energy", 10.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_body, "scale", Vector3.ONE * 0.05, DESPAWN_SECONDS)
	tween.tween_property(_tag, "modulate:a", 0.0, DESPAWN_SECONDS)
	tween.tween_property(_tag, "outline_modulate:a", 0.0, DESPAWN_SECONDS)
	tween.chain().tween_callback(queue_free)
