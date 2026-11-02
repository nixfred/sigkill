class_name RefusedFx
extends MeshInstance3D
## A refused hit's mark (P2, M7's shell, which takes nothing but kill -9): a cold hexagon ripple on the plane where the
## shot met it, facing back along the shot (or at the camera when the shot gave no way), in a refusal's steel
## (shaders/refused_ripple.gdshader). It replaces the hot flash a landed hit gives, so a shot the shell refused never
## reads as a hit. Lives LIFE_S, then frees itself. Drawn beside the target, never parented to it, so a target that moves
## or dies leaves it where the shot met.

const RippleShader = preload("res://shaders/refused_ripple.gdshader")
const Palette = preload("res://scripts/palette.gd")
## How long it lives, and how wide it runs out (metres across at its widest).
const LIFE_S := 0.42
const SIZE_M := 2.6
## In front of the point it met, toward the shot, so the target's own surface does not cut it.
const LIFT_M := 0.06
const GROUP := &"refused_fx"

static var _material: ShaderMaterial
static var _mesh: QuadMesh

var _age := 0.0
var _mat: ShaderMaterial


## A ripple where a refused shot met `target` (at `point`, the shot travelling `direction`; ZERO for none).
static func spawn(target: Node3D, point: Vector3, direction: Vector3) -> RefusedFx:
	if target == null or not target.is_inside_tree():
		return null
	var root: Node = target.get_tree().current_scene if target.get_tree().current_scene != null else target.get_parent()
	if root == null:
		return null
	var fx := RefusedFx.new()
	root.add_child(fx)
	var facing := -direction.normalized() if not direction.is_zero_approx() else Vector3.ZERO
	if facing == Vector3.ZERO:
		var cam := target.get_viewport().get_camera_3d() if target.get_viewport() != null else null
		facing = (cam.global_position - point).normalized() if cam != null else Vector3.BACK
	var at := point + facing * LIFT_M
	var up := Vector3.UP if absf(facing.y) < 0.98 else Vector3.RIGHT
	fx.global_transform = Transform3D(Basis.looking_at(-facing, up), at)
	fx.scale = Vector3.ONE * SIZE_M  # after the transform: an orthonormal basis would reset it to a metre
	return fx


func _init() -> void:
	name = "RefusedFx"
	if _mesh == null:
		_mesh = QuadMesh.new()
		_mesh.size = Vector2(1.0, 1.0)
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = RippleShader
		_material.set_shader_parameter("steel", Palette.STEEL)
	_mat = _material.duplicate() as ShaderMaterial
	material_override = _mat
	add_to_group(GROUP)


func _process(delta: float) -> void:
	_age += delta
	_mat.set_shader_parameter("age", clampf(_age / LIFE_S, 0.0, 1.0))
	if _age >= LIFE_S:
		queue_free()


## How far along it is, 0 to 1 (the checks).
func age() -> float:
	return clampf(_age / LIFE_S, 0.0, 1.0)
