extends Node3D
## /dev/null as drawn (C31): the device in flight and the hole it opens, every part made once per throw and
## driven by its hole (scripts/weapons/dev_null_hole.gd) each frame through show_state(). Cosmetic only.
##
## The device: a sphere of black glass in a cage of two plum rings turning round it, a white-hot pinhole
## at its heart, sparks shed behind it (the hole asks ParticleFx for a heavy trail).
##
## The hole, at its core: the event horizon and its lensing (shaders/dev_null_lens.gdshader: a camera-
## facing disc, black in its shadow, a white-hot photon ring and the halo round it, the arena behind it
## bent), the accretion ring (shaders/dev_null_disc.gdshader: a flat ring of plum matter, white-hot at its
## inner edge, swirling in, tilted a little off level), the debris (shaders/dev_null_debris.gdshader: a
## MultiMesh of streaks spiralling in from its reach, their paths the shader's), its mark on the floor
## (shaders/dev_null_floor.gdshader: its reach as dashes, its horizon as a ring) and two lights: a plum one
## the ring casts, and a negative one that darkens everything near the core (light falls in). A shape made
## of light and nothing: unlike Black ICE's black crystal spikes and cold slate light (I3), a hole is a
## sphere of nothing in a ring of plum fire.
##
## The implosion (implode()): its own node beside the hole, outliving it by IMPLODE_S: the hole's light
## pulled into a white-hot point, then a flat shock ring flung out over the floor, a burst of the HOLE
## particles drawn in to the core, and "> /dev/null" written over it, fading.

const Palette = preload("res://scripts/palette.gd")
const Tuning = preload("res://scripts/weapons/dev_null_tuning.gd")
const LensShader = preload("res://shaders/dev_null_lens.gdshader")
const DiscShader = preload("res://shaders/dev_null_disc.gdshader")
const DebrisShader = preload("res://shaders/dev_null_debris.gdshader")
const FloorShader = preload("res://shaders/dev_null_floor.gdshader")

## The shadow's radius on screen, metres, at full size; the lens disc's half-size; the ring's outer radius
## and its inner edge's share of it.
const SHADOW_M := 0.55
const LENS_M := 2.7
const DISC_M := 3.4
const DISC_INNER := 0.26
## The ring's tilt off level, degrees, and its turn a second.
const DISC_TILT := 14.0
## Streaks spiralling in.
const DEBRIS := 150
## The lights: the ring's plum and the dark at the core.
const GLOW_ENERGY := 3.2
const GLOW_RANGE_M := 9.0
const DARK_ENERGY := 2.4
const DARK_RANGE_M := 4.5
## The device's size, metres, and its rings' turns a second.
const DEVICE_M := 0.13
const CAGE_TURNS := 1.6
## The implosion's length and its shock ring's reach, metres.
const IMPLODE_S := 1.1
const SHOCK_M := 7.0
const IMPLODE_LINE := "> /dev/null"

var tuning: Tuning
var reach := 9.0
var body_color := Palette.DEV_NULL
var hot_color := Palette.DEV_NULL_HI
var light_color := Palette.DEV_NULL_TEXT

var _device: Node3D
var _cage: Array[Node3D] = []
var _hole: Node3D
var _lens: MeshInstance3D
var _disc: MeshInstance3D
var _debris: MultiMeshInstance3D
var _floor: MeshInstance3D
var _glow: OmniLight3D
var _dark: OmniLight3D
var _lens_mat: ShaderMaterial
var _disc_mat: ShaderMaterial
var _debris_mat: ShaderMaterial
var _floor_mat: ShaderMaterial
var _floor_found := false
var _floor_y := 0.0


func setup(with_tuning: Tuning, body: Color, light: Color, reach_m: float) -> void:
	tuning = with_tuning
	body_color = body
	light_color = light
	reach = reach_m
	_build_device()
	_build_hole()


## The device's node, for its trail.
func device() -> Node3D:
	return _device


## The hole's parts, for the checks: the lens disc, the ring, the debris, the floor mark, the lights.
func parts() -> Dictionary:
	return {"lens": _lens, "disc": _disc, "debris": _debris, "floor": _floor, "glow": _glow, "dark": _dark}


func _build_device() -> void:
	_device = Node3D.new()
	_device.name = "Device"
	add_child(_device)
	var shell := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = DEVICE_M
	sphere.height = DEVICE_M * 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	shell.mesh = sphere
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.01, 0.01, 0.012)
	glass.metallic = 0.6
	glass.roughness = 0.08
	glass.rim_enabled = true
	glass.rim = 0.6
	glass.rim_tint = 0.0
	shell.material_override = glass
	_device.add_child(shell)
	var pin := MeshInstance3D.new()
	var dot := SphereMesh.new()
	dot.radius = DEVICE_M * 0.22
	dot.height = DEVICE_M * 0.44
	pin.mesh = dot
	pin.material_override = Palette.unlit_glow(hot_color, 4.0)
	pin.position = Vector3(0.0, 0.0, DEVICE_M * 0.82)
	_device.add_child(pin)
	for k in 2:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = DEVICE_M * 1.28
		torus.outer_radius = DEVICE_M * 1.42
		torus.rings = 24
		torus.ring_segments = 5
		ring.mesh = torus
		ring.material_override = Palette.unlit_glow(body_color, 3.5)
		ring.rotation = Vector3(deg_to_rad(70.0 * k + 10.0), deg_to_rad(40.0 * k), 0.0)
		_device.add_child(ring)
		_cage.append(ring)
	for child in _device.get_children():
		(child as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_hole() -> void:
	_hole = Node3D.new()
	_hole.name = "Hole"
	_hole.visible = false
	add_child(_hole)
	_lens_mat = ShaderMaterial.new()
	_lens_mat.shader = LensShader
	_lens_mat.render_priority = -2  # drawn first of its own: the ring and the debris go over the bent view
	_lens_mat.set_shader_parameter("shadow", SHADOW_M / LENS_M)
	_lens_mat.set_shader_parameter("einstein", SHADOW_M * 1.45 / LENS_M)
	_lens_mat.set_shader_parameter("halo", SHADOW_M * 1.32 / LENS_M)
	_lens_mat.set_shader_parameter("ring_color", hot_color)
	_lens_mat.set_shader_parameter("halo_color", body_color.lerp(hot_color, 0.25))
	_lens = _quad("Lens", Vector2.ONE * LENS_M * 2.0, _lens_mat)
	_lens.custom_aabb = AABB(-Vector3.ONE * LENS_M, Vector3.ONE * LENS_M * 2.0)
	_disc_mat = ShaderMaterial.new()
	_disc_mat.shader = DiscShader
	_disc_mat.set_shader_parameter("hot_color", hot_color)
	_disc_mat.set_shader_parameter("body_color", body_color)
	_disc_mat.set_shader_parameter("inner", DISC_INNER)
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * DISC_M * 2.0
	_disc = MeshInstance3D.new()
	_disc.name = "Disc"
	_disc.mesh = plane
	_disc.material_override = _disc_mat
	_disc.rotation = Vector3(deg_to_rad(DISC_TILT), 0.0, deg_to_rad(DISC_TILT * 0.4))
	_hole.add_child(_disc)
	_debris_mat = ShaderMaterial.new()
	_debris_mat.shader = DebrisShader
	_debris_mat.set_shader_parameter("hot_color", hot_color)
	_debris_mat.set_shader_parameter("body_color", body_color)
	_debris_mat.set_shader_parameter("reach", reach)
	_debris_mat.set_shader_parameter("core_r", SHADOW_M * 0.9)
	var streak := QuadMesh.new()
	streak.size = Vector2.ONE
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.use_custom_data = true
	many.mesh = streak
	many.instance_count = DEBRIS
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for i in DEBRIS:
		many.set_instance_transform(i, Transform3D.IDENTITY)
		many.set_instance_custom_data(i, Color(rng.randf(), rng.randf(), rng.randf(), rng.randf()))
	_debris = MultiMeshInstance3D.new()
	_debris.name = "Debris"
	_debris.multimesh = many
	_debris.material_override = _debris_mat
	_debris.custom_aabb = AABB(Vector3(-reach, -3.0, -reach), Vector3(reach * 2.0, 6.0, reach * 2.0))
	_hole.add_child(_debris)
	_floor_mat = ShaderMaterial.new()
	_floor_mat.shader = FloorShader
	_floor_mat.set_shader_parameter("body_color", body_color)
	_floor_mat.set_shader_parameter("hot_color", hot_color)
	_floor_mat.set_shader_parameter("horizon", tuning.horizon_m / reach)
	var ground := PlaneMesh.new()
	ground.size = Vector2.ONE * reach * 2.0
	_floor = MeshInstance3D.new()
	_floor.name = "Floor"
	_floor.mesh = ground
	_floor.material_override = _floor_mat
	add_child(_floor)
	_floor.visible = false
	_glow = OmniLight3D.new()
	_glow.name = "Glow"
	_glow.light_color = body_color.lerp(hot_color, 0.2)
	_glow.omni_range = GLOW_RANGE_M
	_glow.shadow_enabled = false
	_hole.add_child(_glow)
	_dark = OmniLight3D.new()
	_dark.name = "Dark"
	_dark.light_negative = true
	_dark.omni_range = DARK_RANGE_M
	_dark.shadow_enabled = false
	_hole.add_child(_dark)
	for node in [_lens, _disc, _debris, _floor]:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _quad(node_name: String, size: Vector2, material: Material) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.mesh = quad
	mesh.material_override = material
	_hole.add_child(mesh)
	return mesh


## Its state this frame: the device flying at `at`, or the hole at its core `at`, `size` of its full size,
## `age` seconds since it opened.
func show_state(phase: int, size: float, age: float, at: Vector3) -> void:
	if not at.is_finite():
		return
	var flying := phase == 0
	_device.visible = flying
	_hole.visible = not flying and size > 0.001
	if flying:
		_device.global_position = at
		var turn := TAU * CAGE_TURNS * get_process_delta_time()
		for i in _cage.size():
			_cage[i].rotate_object_local(Vector3.UP if i == 0 else Vector3.RIGHT, turn * (1.0 if i == 0 else -1.3))
		_floor.visible = false
		return
	_hole.global_position = at
	_lens.scale = Vector3.ONE  # the lens takes the size in its shader: its bent view reaches as far
	_disc.scale = Vector3.ONE * lerpf(0.2, 1.0, size)
	_disc.rotate_object_local(Vector3.UP, -0.6 * get_process_delta_time())
	for mat in [_lens_mat, _disc_mat, _debris_mat, _floor_mat]:
		mat.set_shader_parameter("size_now", size)
		mat.set_shader_parameter("flow", age)
	_glow.light_energy = GLOW_ENERGY * size
	_dark.light_energy = DARK_ENERGY * size
	_place_floor(at, size)


## Its mark on the floor straight under the core, found once.
func _place_floor(at: Vector3, size: float) -> void:
	if not _floor_found:
		_floor_found = true
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * (tuning.core_height_m + 2.5), 1))
		_floor_y = (hit["position"] as Vector3).y + 0.03 if not hit.is_empty() else INF
	_floor.visible = is_finite(_floor_y) and size > 0.001
	if _floor.visible:
		_floor.global_position = Vector3(at.x, _floor_y, at.z)


## The implosion at `at` (world space): its own node under the hole's field, gone after IMPLODE_S.
func implode(at: Vector3) -> void:
	var field := get_parent().get_parent() if get_parent() != null else null
	if field == null or not field.is_inside_tree():
		return
	var boom := Node3D.new()
	boom.name = "DevNullImplosion"
	boom.add_to_group(&"dev_null")
	field.add_child(boom)
	boom.global_position = at
	# The hole's light pulled into a point, then gone.
	var flash := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = SHADOW_M * 1.6
	ball.height = SHADOW_M * 3.2
	flash.mesh = ball
	var flash_mat := Palette.unlit_glow(hot_color, 7.0)
	flash.material_override = flash_mat
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	boom.add_child(flash)
	# The shock ring flung out over the floor.
	var torus := TorusMesh.new()
	torus.inner_radius = 0.94
	torus.outer_radius = 1.0
	torus.rings = 48
	torus.ring_segments = 6
	var shock := MeshInstance3D.new()
	shock.mesh = torus
	var shock_mat := Palette.unlit_glow(body_color.lerp(hot_color, 0.4), 4.0)
	shock.material_override = shock_mat
	shock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shock.scale = Vector3.ONE * 0.2
	boom.add_child(shock)
	var tag := Label3D.new()
	tag.text = IMPLODE_LINE
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = false
	tag.font_size = 72
	tag.pixel_size = 0.006
	tag.outline_size = 10
	tag.modulate = light_color
	tag.outline_modulate = Color(0, 0, 0, 0.85)
	tag.position = Vector3.UP * 0.9
	boom.add_child(tag)
	var light := OmniLight3D.new()
	light.light_color = hot_color
	light.light_energy = 8.0
	light.omni_range = 10.0
	boom.add_child(light)
	var fx := ParticleFx.of(boom)
	if fx != null:
		fx.hole(at, 1.0)
	var tween := boom.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * 0.05, IMPLODE_S * 0.25).set_ease(Tween.EASE_IN)
	tween.tween_property(shock, "scale", Vector3(SHOCK_M, 1.0, SHOCK_M), IMPLODE_S * 0.8).set_delay(IMPLODE_S * 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(shock_mat, "albedo_color:a", 0.0, IMPLODE_S * 0.8).set_delay(IMPLODE_S * 0.2)
	tween.tween_property(light, "light_energy", 0.0, IMPLODE_S)
	tween.tween_property(tag, "modulate:a", 0.0, IMPLODE_S * 0.6).set_delay(IMPLODE_S * 0.4)
	tween.tween_property(tag, "position", Vector3.UP * 1.5, IMPLODE_S)
	tween.chain().tween_callback(boom.queue_free)
	_hole.visible = false
	_floor.visible = false
