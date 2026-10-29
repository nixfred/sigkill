extends Node3D
## /dev/null as drawn (C31): the device in flight and the hole it opens, every part made once per throw and
## driven by its hole (scripts/weapons/dev_null_hole.gd) each frame through show_state(). Cosmetic only.
##
## The device: a sphere of black glass in a cage of two plum rings turning round it, a white-hot pinhole
## at its heart, sparks shed behind it (the hole asks ParticleFx for a heavy trail).
##
## The hole, at its core: the event horizon, a sphere of nothing (opaque, unlit black: it hides what is
## behind it, the ring's near side passing in front of it), and its lensing (shaders/dev_null_lens.gdshader: a
## camera-facing disc, a white-hot photon ring and the halo round the shadow, the arena behind it bent), the accretion ring (shaders/dev_null_disc.gdshader: a flat ring of plum matter, white-hot at its
## inner edge, swirling in, tilted a little off level), the debris (shaders/dev_null_debris.gdshader: a
## MultiMesh of streaks spiralling in from its reach, their paths the shader's), its mark on the floor
## (shaders/dev_null_floor.gdshader: a dark well, its reach as dashes, its horizon a faint line), its tag over the
## core ("$ cat * > /dev/null", what it holds and has discarded, cron's style) and two lights: a plum one
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
const SHADOW_M := 0.75
const LENS_M := 3.4
const DISC_M := 4.2
const DISC_INNER := 0.24
## The ring's tilt off level, degrees, and its turn a second.
const DISC_TILT := 22.0
## Streaks spiralling in.
const DEBRIS := 150
## The lights: the ring's plum and the dark at the core.
const GLOW_ENERGY := 1.3
const GLOW_RANGE_M := 7.0
const DARK_ENERGY := 3.0
const DARK_RANGE_M := 4.5
## The device's size, metres, and its rings' turns a second.
const DEVICE_M := 0.13
const CAGE_TURNS := 1.6
## The implosion's length and its shock ring's reach, metres.
const IMPLODE_S := 1.1
const SHOCK_M := 8.0
## The implosion's point of light: its size at its brightest, and how fast it pops and fades.
const POP_M := 0.5
const POP_S := 0.08
const IMPLODE_LINE := "> /dev/null"
## Its tag: the font's size, its pixel's, and how far over the core it floats, metres.
const TAG_FONT := 40
const TAG_PIXEL := 0.007
const TAG_RISE_M := 2.6

var tuning: Tuning
var reach := 9.0
var body_color := Palette.DEV_NULL
var hot_color := Palette.DEV_NULL_HI
var light_color := Palette.DEV_NULL_TEXT

var _device: Node3D
var _cage: Array[Node3D] = []
var _hole: Node3D
var _core: MeshInstance3D
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
var _tag: Label3D


func setup(with_tuning: Tuning, body: Color, light: Color, reach_m: float) -> void:
	tuning = with_tuning
	body_color = body
	light_color = light
	reach = reach_m
	_build_device()
	_build_hole()


## Its tag's text, when it has changed (the hole's tag_text()).
func set_tag(text: String) -> void:
	if _tag.text != text:
		_tag.text = text


## Its tag now, for the checks: "" while it is not shown.
func tag() -> String:
	return _tag.text if _tag.is_visible_in_tree() else ""


## The device's node, for its trail.
func device() -> Node3D:
	return _device


## The hole's parts, for the checks: the lens disc, the ring, the debris, the floor mark, the lights.
func parts() -> Dictionary:
	return {"core": _core, "lens": _lens, "disc": _disc, "debris": _debris, "floor": _floor, "glow": _glow, "dark": _dark}


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
	# The event horizon: a sphere of nothing, opaque and unlit, so it hides what is behind it and the ring's far
	# side, while the ring's near side passes in front of it.
	var ball := SphereMesh.new()
	ball.radius = SHADOW_M
	ball.height = SHADOW_M * 2.0
	ball.radial_segments = 24
	ball.rings = 12
	var nothing := StandardMaterial3D.new()
	nothing.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	nothing.albedo_color = Color(0.0, 0.0, 0.0)
	_core = MeshInstance3D.new()
	_core.name = "Core"
	_core.mesh = ball
	_core.material_override = nothing
	_hole.add_child(_core)
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
	# Its tag over the core: the command it is, what it holds and has discarded (the hole writes it).
	_tag = Label3D.new()
	_tag.name = "Tag"
	_tag.font = Palette.mono_font()
	_tag.font_size = TAG_FONT
	_tag.pixel_size = TAG_PIXEL
	_tag.outline_size = 8
	_tag.modulate = light_color
	_tag.outline_modulate = Palette.VOID
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.position = Vector3.UP * TAG_RISE_M
	_hole.add_child(_tag)
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
	for node in [_core, _lens, _disc, _debris, _floor]:
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
	_core.scale = Vector3.ONE * maxf(size, 0.01)
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


## The implosion at `at` (world space): its own node under the hole's field, gone after IMPLODE_S. The hole
## has already drawn itself into its core (its collapse); now a point of white-hot light pops there and dies,
## a shock ring is flung out flat over the floor and a second one, upright, round the core, the HOLE
## particles are drawn in, a flash of its light, and "> /dev/null" written over it, rising and fading.
func implode(at: Vector3) -> void:
	var field := get_parent().get_parent() if get_parent() != null else null
	if field == null or not field.is_inside_tree():
		return
	var boom := Node3D.new()
	boom.name = "DevNullImplosion"
	boom.add_to_group(&"dev_null")
	field.add_child(boom)
	boom.global_position = at
	var pop := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = POP_M
	ball.height = POP_M * 2.0
	ball.radial_segments = 16
	ball.rings = 8
	pop.mesh = ball
	var pop_mat := Palette.unlit_glow(hot_color, 6.0)
	pop.material_override = pop_mat
	pop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pop.scale = Vector3.ONE * 0.1
	boom.add_child(pop)
	var shocks: Array[MeshInstance3D] = []
	var shock_mats: Array[Material] = []
	for upright in [false, true]:
		var torus := TorusMesh.new()
		torus.inner_radius = 0.95
		torus.outer_radius = 1.0
		torus.rings = 64
		torus.ring_segments = 6
		var shock := MeshInstance3D.new()
		shock.mesh = torus
		var mat := Palette.unlit_glow(body_color.lerp(hot_color, 0.3 if upright else 0.15), 3.2 if upright else 2.4)
		shock.material_override = mat
		shock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shock.scale = Vector3.ONE * 0.1
		if upright:
			shock.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		else:
			shock.position = Vector3.DOWN * (tuning.core_height_m - 0.05)
		boom.add_child(shock)
		shocks.append(shock)
		shock_mats.append(mat)
	# The upright ring faces the eye as it grows.
	var view := get_viewport().get_camera_3d() if get_viewport() != null else null
	if view != null:
		var to: Vector3 = view.global_position - at
		shocks[1].rotation = Vector3(PI * 0.5, atan2(to.x, to.z), 0.0)
	var tag := Label3D.new()
	tag.text = IMPLODE_LINE
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 72
	tag.pixel_size = 0.007
	tag.outline_size = 10
	tag.modulate = light_color
	tag.outline_modulate = Color(0, 0, 0, 0.85)
	tag.position = Vector3.UP * 0.9
	boom.add_child(tag)
	var light := OmniLight3D.new()
	light.light_color = hot_color
	light.light_energy = 0.0
	light.omni_range = 10.0
	boom.add_child(light)
	var fx := ParticleFx.of(boom)
	if fx != null:
		fx.hole(at, 1.0)
	var tween := boom.create_tween()
	tween.set_parallel(true)
	tween.tween_property(pop, "scale", Vector3.ONE, POP_S).set_ease(Tween.EASE_OUT)
	tween.tween_property(pop, "scale", Vector3.ONE * 0.02, IMPLODE_S * 0.3).set_delay(POP_S).set_ease(Tween.EASE_IN)
	tween.tween_property(light, "light_energy", 6.0, POP_S)
	tween.tween_property(light, "light_energy", 0.0, IMPLODE_S * 0.6).set_delay(POP_S)
	tween.tween_property(shocks[0], "scale", Vector3(SHOCK_M, 1.0, SHOCK_M), IMPLODE_S * 0.75).set_delay(POP_S).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(shocks[1], "scale", Vector3(SHOCK_M * 0.45, SHOCK_M * 0.45, 1.0), IMPLODE_S * 0.6).set_delay(POP_S).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	for mat in shock_mats:
		tween.tween_property(mat, "albedo_color:a", 0.0, IMPLODE_S * 0.75).set_delay(POP_S + IMPLODE_S * 0.1)
	tween.tween_property(tag, "modulate:a", 0.0, IMPLODE_S * 0.5).set_delay(IMPLODE_S * 0.5)
	tween.tween_property(tag, "position", Vector3.UP * 1.6, IMPLODE_S)
	tween.chain().tween_callback(boom.queue_free)
	_hole.visible = false
	_floor.visible = false
