class_name LoadoutStage
extends SubViewport
## The loadout screen's turntable (C33): a weapon's own first-person model (A1, scripts/viewmodels/), shown
## large and alone in a world of its own, slowly turning over a small dark plinth on a black glass floor that
## reflects it, the void beyond. A cool key light from above the camera, a pool of the skin's light falling on
## it from above, a rim light behind it in the skin's colour and a thin ring of that light round the plinth's
## edge; the arena's look (AgX, glow) so the seams bloom as they do in the hand. light() repaints the model and
## the stage's light in any skin at once (a skin card under the pointer lights it live); show_weapon() builds the
## model of a weapon as it is worn. Cosmetic only: nothing here is a weapon in play.

const Palette = preload("res://scripts/palette.gd")

## How fast it turns, radians a second, where it starts (a three-quarter view, the muzzle toward the camera's
## left) and how it sits: its longest side this long, tipped this far toward the camera so its top shows.
const TURN_RATE := 0.42
const START_YAW := 1.85
const FIT_M := 0.7
const TILT := 0.2
## The camera: where it stands and what it looks at, and its field of view.
const CAMERA_AT := Vector3(0.0, 0.3, 1.62)
const CAMERA_LOOK := Vector3(0.0, -0.04, 0.0)
const CAMERA_FOV := 30.0
## The model glows this many times its first-person energy: it sits further from the eye here.
const GLOW_BOOST := 1.6
## The plinth under it (dark, matte: no light of its own) and its ring of the skin's light at its edge.
const PLINTH_R := 0.3
const PLINTH_H := 0.05
const RING_W := 0.004
const RING_ENERGY := 2.2
## The glass floor: near black, glossy, reflecting the model and the ring.
const FLOOR_M := 12.0
const FLOOR_COLOR := Color(0.012, 0.016, 0.022)
const FLOOR_METALLIC := 0.55
const FLOOR_ROUGHNESS := 0.32
## The lights: the key, the pool from above in the skin's colour, the rim behind in it.
const KEY_ENERGY := 1.7
const POOL_ENERGY := 1.1
const RIM_ENERGY := 3.0

## The model on show (a Viewmodel), and the weapon it shows.
var model: Viewmodel
var def: Resource
## The skin it is lit in now.
var skin := ""
var _pivot: Node3D
var _rim: OmniLight3D
var _pool: SpotLight3D
var _ring_mat: StandardMaterial3D
var _plinth: MeshInstance3D
var _ring: MeshInstance3D
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
	env.ambient_light_energy = 0.3
	env.glow_enabled = true
	env.ssr_enabled = true
	env.fog_enabled = false
	world.environment = env
	add_child(world)
	var camera := Camera3D.new()
	camera.fov = CAMERA_FOV
	camera.near = 0.02
	camera.look_at_from_position(CAMERA_AT, CAMERA_LOOK)
	add_child(camera)
	var key := DirectionalLight3D.new()
	key.light_color = Color(0.86, 0.93, 1.0)
	key.light_energy = KEY_ENERGY
	key.rotation = Vector3(-0.8, -0.5, 0.0)
	add_child(key)
	_pool = SpotLight3D.new()
	_pool.light_energy = POOL_ENERGY
	_pool.spot_range = 2.8
	_pool.spot_angle = 15.0
	_pool.position = Vector3(0.0, 2.1, 0.2)
	_pool.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	add_child(_pool)
	_rim = OmniLight3D.new()
	_rim.light_energy = RIM_ENERGY
	_rim.omni_range = 1.4
	_rim.position = Vector3(-0.25, 0.55, -0.75)
	add_child(_rim)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = FLOOR_COLOR
	glass.metallic = FLOOR_METALLIC
	glass.roughness = FLOOR_ROUGHNESS
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(FLOOR_M, FLOOR_M)
	ground.mesh = plane
	ground.material_override = glass
	ground.name = "Glass"
	add_child(ground)
	var matte := StandardMaterial3D.new()
	matte.albedo_color = Palette.VOID
	matte.metallic = 0.2
	matte.roughness = 0.85
	_plinth = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = PLINTH_R
	disc.bottom_radius = PLINTH_R + 0.015
	disc.height = PLINTH_H
	disc.radial_segments = 48
	_plinth.mesh = disc
	_plinth.material_override = matte
	_plinth.name = "Plinth"
	add_child(_plinth)
	_ring_mat = Palette.unlit_glow(Palette.TEAL, RING_ENERGY)
	_ring = _ring_of(PLINTH_R + 0.012, RING_W, _ring_mat)
	add_child(_ring)
	_pivot = Node3D.new()
	_pivot.name = "Turntable"
	add_child(_pivot)


## Shows `weapon` (a WeaponDef as worn: its skin, its mod) on the turntable, the last one freed, from its
## three-quarter view again.
func show_weapon(weapon: Resource) -> void:
	def = weapon
	_turn = 0.0
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
## stage's pool, rim light and ring with it.
func light(skin_name: String) -> void:
	skin = skin_name
	var body := Palette.skin_body(skin_name)
	var beam := Palette.skin_beam(skin_name)
	if model != null and is_instance_valid(model) and def != null:
		model.set_look(body, beam, def.viewmodel_glow_energy * GLOW_BOOST)
	_rim.light_color = body
	_pool.light_color = beam
	_ring_mat.albedo_color = Color(body * RING_ENERGY, 1.0)


## Seconds turned so far, for the checks.
func turned() -> float:
	return _turn


func _process(delta: float) -> void:
	_turn += delta
	if _pivot != null:
		_pivot.rotation = Vector3(TILT, START_YAW + _turn * TURN_RATE, 0.0)
	if model != null and is_instance_valid(model):
		model.idle(delta)


## Centres the model on the turntable, scales it to FIT_M along its longest side, and sets the plinth and the
## glass floor just under its lowest point.
func _fit() -> void:
	_pivot.rotation = Vector3.ZERO
	var box := _bounds()
	if box.size == Vector3.ZERO:
		return
	var k := FIT_M / maxf(box.size[box.get_longest_axis_index()], 0.001)
	model.scale = Vector3.ONE * k
	model.position = -box.get_center() * k
	var low := -box.size.y * k * 0.5 - 0.05
	_plinth.position.y = low - PLINTH_H * 0.5
	_ring.position.y = low - PLINTH_H * 0.5
	get_node("Glass").position.y = low - PLINTH_H


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


static func _ring_of(radius: float, width: float, mat: Material) -> MeshInstance3D:
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
