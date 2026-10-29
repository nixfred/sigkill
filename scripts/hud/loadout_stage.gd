class_name LoadoutStage
extends SubViewport
## The loadout screen's turntable (C33): a weapon's own first-person model (A1, scripts/viewmodels/), shown
## large and alone in a world of its own, slowly turning on a dark plinth over the arena's own grid floor. A cool
## key light from above the camera, a rim light behind it in the skin's colour and two thin rings of that light
## on the plinth; the arena's look (AgX, glow) so the seams bloom as they do in the hand. light() repaints the
## model in any skin at once (a skin card under the pointer lights it live); show_weapon() builds the model of a
## weapon as it is worn. Cosmetic only: nothing here is a weapon in play.

const Palette = preload("res://scripts/palette.gd")

## How fast it turns, radians a second, and how it sits: its longest side this long, tipped this far toward
## the camera so its top shows.
const TURN_RATE := 0.42
const FIT_M := 0.66
const TILT := 0.16
## The camera: how far back and up, and its field of view.
const CAMERA_AT := Vector3(0.0, 0.16, 1.18)
const CAMERA_FOV := 34.0
## The model glows this many times its first-person energy: it sits further from the eye here.
const GLOW_BOOST := 1.35
## The plinth under it and its two rings of the skin's light.
const PLINTH_R := 0.46
const PLINTH_H := 0.035
const RING_R := 0.44
const RING_W := 0.006
const RING_ENERGY := 3.2
const HALO_R := 0.56
const HALO_ENERGY := 1.2
const RIM_ENERGY := 2.6
const KEY_ENERGY := 1.15
const FILL_ENERGY := 0.35
const FLOOR_M := 6.0

## The model on show (a Viewmodel), and the weapon it shows.
var model: Viewmodel
var def: Resource
## The skin it is lit in now.
var skin := ""
var _pivot: Node3D
var _rim: OmniLight3D
var _ring_mat: StandardMaterial3D
var _halo_mat: StandardMaterial3D
var _plinth: MeshInstance3D
var _rings: Node3D
var _turn := 0.0


func _init() -> void:
	own_world_3d = true
	transparent_bg = false
	msaa_3d = Viewport.MSAA_4X
	size = Vector2i(640, 400)
	render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE


func _ready() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	Palette.apply_arena_environment(env)
	env.background_mode = Environment.BG_COLOR
	env.background_color = Palette.VOID
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Palette.BASE
	env.ambient_light_energy = 0.4
	env.glow_enabled = true
	world.environment = env
	add_child(world)
	var camera := Camera3D.new()
	camera.fov = CAMERA_FOV
	camera.near = 0.02
	camera.position = CAMERA_AT
	camera.look_at_from_position(CAMERA_AT, Vector3.ZERO)
	add_child(camera)
	var key := DirectionalLight3D.new()
	key.light_color = Color(0.86, 0.93, 1.0)
	key.light_energy = KEY_ENERGY
	key.rotation = Vector3(-0.75, -0.55, 0.0)
	add_child(key)
	var fill := OmniLight3D.new()
	fill.light_color = Palette.TEAL
	fill.light_energy = FILL_ENERGY
	fill.omni_range = 3.0
	fill.position = Vector3(0.9, 0.3, 0.6)
	add_child(fill)
	_rim = OmniLight3D.new()
	_rim.light_energy = RIM_ENERGY
	_rim.omni_range = 2.2
	_rim.position = Vector3(-0.2, 0.35, -0.75)
	add_child(_rim)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(FLOOR_M, FLOOR_M)
	ground.mesh = plane
	ground.material_override = Palette.surface(Palette.Surface.FLOOR, Vector3(FLOOR_M, 0.1, FLOOR_M))
	ground.position.y = -0.32
	add_child(ground)
	_plinth = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = PLINTH_R
	disc.bottom_radius = PLINTH_R + 0.02
	disc.height = PLINTH_H
	disc.radial_segments = 48
	_plinth.mesh = disc
	_plinth.material_override = Palette.viewmodel_metal(Palette.GUNMETAL, Palette.TEAL, true, true)
	_plinth.position.y = -0.3
	add_child(_plinth)
	_rings = Node3D.new()
	add_child(_rings)
	_ring_mat = Palette.unlit_glow(Palette.TEAL, RING_ENERGY)
	_halo_mat = Palette.unlit_glow(Palette.TEAL, HALO_ENERGY)
	_rings.add_child(_ring(RING_R, RING_W, _ring_mat))
	_rings.add_child(_ring(HALO_R, RING_W * 0.6, _halo_mat))
	_pivot = Node3D.new()
	_pivot.name = "Turntable"
	add_child(_pivot)


## Shows `weapon` (a WeaponDef as worn: its skin, its mod) on the turntable, the last one freed.
func show_weapon(weapon: Resource) -> void:
	def = weapon
	if model != null and is_instance_valid(model):
		model.queue_free()
	model = Viewmodel.make(weapon)
	model.visible = true
	model.position = Vector3.ZERO
	model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pivot.add_child(model)
	_fit()
	light(weapon.light_skin)


## The model lit in skin `skin_name` (a palette skin name) at once, its seams, trim, rim and hot parts, and the
## stage's rim light and rings with it.
func light(skin_name: String) -> void:
	skin = skin_name
	var body := Palette.skin_body(skin_name)
	var beam := Palette.skin_beam(skin_name)
	if model != null and is_instance_valid(model) and def != null:
		model.set_look(body, beam, def.viewmodel_glow_energy * GLOW_BOOST)
	_rim.light_color = body
	_ring_mat.albedo_color = Color(body * RING_ENERGY, 1.0)
	_halo_mat.albedo_color = Color(beam * HALO_ENERGY, 1.0)
	(_plinth.material_override as ShaderMaterial).set_shader_parameter("neon", body)


## Seconds turned so far, for the checks.
func turned() -> float:
	return _turn


func _process(delta: float) -> void:
	_turn += delta
	if _pivot != null:
		_pivot.rotation = Vector3(TILT, _turn * TURN_RATE, 0.0)
	if model != null and is_instance_valid(model):
		model.idle(delta)


## Centres the model on the turntable and scales it to FIT_M along its longest side, its lowest point over the
## plinth.
func _fit() -> void:
	_pivot.rotation = Vector3.ZERO
	var box := _bounds()
	if box.size == Vector3.ZERO:
		return
	var k := FIT_M / maxf(box.size[box.get_longest_axis_index()], 0.001)
	model.scale = Vector3.ONE * k
	model.position = -box.get_center() * k
	_plinth.position.y = -box.size.y * k * 0.5 - 0.12
	_rings.position.y = _plinth.position.y + PLINTH_H * 0.5 + 0.002


## The model's every mesh, in the turntable's space.
func _bounds() -> AABB:
	var out := AABB()
	var first := true
	var inverse := _pivot.global_transform.affine_inverse()
	for node in [model] + model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node == null or mesh_node.mesh == null or not mesh_node.is_inside_tree():
			continue
		var box: AABB = (inverse * mesh_node.global_transform) * mesh_node.mesh.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out


static func _ring(radius: float, width: float, mat: Material) -> MeshInstance3D:
	var torus := TorusMesh.new()
	torus.inner_radius = radius - width
	torus.outer_radius = radius + width
	torus.rings = 64
	torus.ring_segments = 6
	var node := MeshInstance3D.new()
	node.mesh = torus
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node
