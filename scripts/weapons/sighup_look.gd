extends Node3D
## SIGHUP as drawn (C32): the device in flight and the hangup burst it goes off in, every part made once per
## throw and driven by its burst (scripts/weapons/sighup_burst.gd) each frame through show_state().
## Cosmetic only.
##
## The device: a telephone handset in hard geometry (an eight-sided handle, a cup at each end, the cups'
## grilles lit in the carrier green), tumbling end over end as it flies, sparks shed behind it (the burst
## asks ParticleFx for a trail).
##
## The burst, where it went off: a flash of the carrier's light (a point popping white-green, the light
## lighting everything the wave reaches); a spike of the carrier standing up out of it, the line cut; the
## carrier wave on the floor (shaders/sighup_wave.gdshader: a sine trace wrapped round its front, its
## interference trailing in, static behind it, sectors torn out) and a curtain of static standing on the
## front, as tall as a daemon (shaders/sighup_curtain.gdshader), both running out with the wave to its
## reach, then fading; the HUP particles flung out flat all round; and its tag over it, a modem's last word
## ("$ kill -HUP", "NO CARRIER", how many it confused, and Black ICE's refusal). Unlike ping's lime ring (a
## clean sonar sweep, C28) its ring is a dirty oscilloscope trace with ghosts, static and a wall of
## interference: a line going dead, not a ping.

const Palette = preload("res://scripts/palette.gd")
const Tuning = preload("res://scripts/weapons/sighup_tuning.gd")
const WaveShader = preload("res://shaders/sighup_wave.gdshader")
const CurtainShader = preload("res://shaders/sighup_curtain.gdshader")

## The handset's half-length, its handle's radius and its cups', metres, and its tumble's turns a second.
const DEVICE_M := 0.15
const HANDLE_R := 0.026
const CUP_R := 0.055
const TUMBLE_TURNS := 2.2
## The curtain's height and its mesh's sides; the floor plane's margin past the reach.
const CURTAIN_M := 2.6
const CURTAIN_SIDES := 64
const FLOOR_MARGIN := 1.1
## The flash: its light's energy at the burst, how long it takes to fall away, and its point's size.
const FLASH_ENERGY := 6.0
const FLASH_S := 0.5
const POP_M := 0.35
## The spike of the carrier: its height and its radius, and how long it stands.
const SPIKE_M := 4.5
const SPIKE_R := 0.05
const SPIKE_S := 0.4
## The light that rides with the wave, lighting what it reaches green.
const WAVE_LIGHT := 1.6
## Seconds the wave's look takes to fade once its front has reached its edge.
const AFTER_S := 1.1
## Its tag: the font's size, its pixel's, how far over the burst it floats and how far it rises.
const TAG_FONT := 40
const TAG_PIXEL := 0.007
const TAG_RISE_M := 2.2
const TAG_CLIMB_M := 0.5

var tuning: Tuning
var reach := 7.0
var body_color := Palette.SIGHUP
var hot_color := Palette.SIGHUP_HI
var light_color := Palette.SIGHUP_TEXT

var _device: Node3D
var _burst: Node3D
var _floor: MeshInstance3D
var _curtain: MeshInstance3D
var _spike: MeshInstance3D
var _pop: MeshInstance3D
var _flash: OmniLight3D
var _floor_mat: ShaderMaterial
var _curtain_mat: ShaderMaterial
var _spike_mat: StandardMaterial3D
var _pop_mat: StandardMaterial3D
var _tag: Label3D
var _floor_y := INF
var _foot := 0.0


func setup(with_tuning: Tuning, body: Color, light: Color, reach_m: float) -> void:
	tuning = with_tuning
	body_color = body
	light_color = light
	reach = reach_m
	_build_device()
	_build_burst()


## Its tag's text, when it has changed (the burst's tag_text()).
func set_tag(text: String) -> void:
	if _tag.text != text:
		_tag.text = text


## Its tag now, for the checks: "" while it is not shown.
func tag() -> String:
	return _tag.text if _tag.is_visible_in_tree() else ""


## The device's node, for its trail.
func device() -> Node3D:
	return _device


## The burst's parts, for the checks: the floor's wave, the curtain, the spike, the flash's point and light.
func parts() -> Dictionary:
	return {"floor": _floor, "curtain": _curtain, "spike": _spike, "pop": _pop, "flash": _flash}


func _build_device() -> void:
	_device = Node3D.new()
	_device.name = "Device"
	add_child(_device)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Palette.GUNMETAL_LIGHT
	metal.metallic = 0.7
	metal.roughness = 0.3
	metal.rim_enabled = true
	metal.rim = 0.5
	metal.rim_tint = 0.3
	var lit := Palette.unlit_glow(body_color, 3.2)
	var hot := Palette.unlit_glow(hot_color, 4.0)
	# The handle: eight-sided, along the device's Z.
	var handle := CylinderMesh.new()
	handle.top_radius = HANDLE_R
	handle.bottom_radius = HANDLE_R
	handle.height = DEVICE_M * 1.6
	handle.radial_segments = 8
	handle.rings = 1
	_part(handle, metal, Vector3.ZERO, Vector3(PI * 0.5, 0.0, 0.0))
	# A cup at each end, opening down, its grille lit.
	for end in [-1.0, 1.0]:
		var cup := CylinderMesh.new()
		cup.top_radius = CUP_R * 0.55
		cup.bottom_radius = CUP_R
		cup.height = CUP_R * 0.9
		cup.radial_segments = 8
		cup.rings = 1
		var at := Vector3(0.0, -CUP_R * 0.55, end * DEVICE_M)
		_part(cup, metal, at, Vector3.ZERO)
		var grille := CylinderMesh.new()
		grille.top_radius = CUP_R * 0.8
		grille.bottom_radius = CUP_R * 0.8
		grille.height = 0.006
		grille.radial_segments = 8
		grille.rings = 1
		_part(grille, lit if end < 0.0 else hot, at + Vector3.DOWN * (CUP_R * 0.46), Vector3.ZERO)
	# A carrier light on the spine.
	var led := SphereMesh.new()
	led.radius = 0.018
	led.height = 0.036
	led.radial_segments = 8
	led.rings = 4
	_part(led, hot, Vector3(0.0, HANDLE_R, 0.0), Vector3.ZERO)


func _part(mesh: Mesh, material: Material, at: Vector3, turn: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	node.rotation = turn
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_device.add_child(node)
	return node


func _build_burst() -> void:
	_burst = Node3D.new()
	_burst.name = "Burst"
	_burst.visible = false
	add_child(_burst)
	_floor_mat = ShaderMaterial.new()
	_floor_mat.shader = WaveShader
	_floor_mat.set_shader_parameter("body_color", body_color)
	_floor_mat.set_shader_parameter("hot_color", hot_color)
	_floor_mat.set_shader_parameter("reach", reach)
	_floor_mat.set_shader_parameter("half_m", reach + FLOOR_MARGIN)
	var ground := PlaneMesh.new()
	ground.size = Vector2.ONE * (reach + FLOOR_MARGIN) * 2.0
	_floor = MeshInstance3D.new()
	_floor.name = "Wave"
	_floor.mesh = ground
	_floor.material_override = _floor_mat
	_floor.custom_aabb = AABB(Vector3(-reach - FLOOR_MARGIN, -0.5, -reach - FLOOR_MARGIN), Vector3((reach + FLOOR_MARGIN) * 2.0, 1.0, (reach + FLOOR_MARGIN) * 2.0))
	add_child(_floor)
	_floor.visible = false
	_curtain_mat = ShaderMaterial.new()
	_curtain_mat.shader = CurtainShader
	_curtain_mat.set_shader_parameter("body_color", body_color)
	_curtain_mat.set_shader_parameter("hot_color", hot_color)
	_curtain_mat.set_shader_parameter("height_m", CURTAIN_M)
	var wall := CylinderMesh.new()
	wall.top_radius = 1.0
	wall.bottom_radius = 1.0
	wall.height = CURTAIN_M
	wall.radial_segments = CURTAIN_SIDES
	wall.rings = 1
	wall.cap_top = false
	wall.cap_bottom = false
	_curtain = MeshInstance3D.new()
	_curtain.name = "Curtain"
	_curtain.mesh = wall
	_curtain.material_override = _curtain_mat
	_curtain.custom_aabb = AABB(Vector3(-1.0, -CURTAIN_M * 0.5, -1.0), Vector3(2.0, CURTAIN_M, 2.0))
	add_child(_curtain)
	_curtain.visible = false
	var spike := CylinderMesh.new()
	spike.top_radius = SPIKE_R * 0.2
	spike.bottom_radius = SPIKE_R
	spike.height = SPIKE_M
	spike.radial_segments = 8
	spike.rings = 1
	_spike_mat = Palette.unlit_glow(hot_color, 4.0)
	_spike = MeshInstance3D.new()
	_spike.name = "Spike"
	_spike.mesh = spike
	_spike.material_override = _spike_mat
	_spike.position = Vector3.UP * SPIKE_M * 0.5
	_burst.add_child(_spike)
	var ball := SphereMesh.new()
	ball.radius = POP_M
	ball.height = POP_M * 2.0
	ball.radial_segments = 16
	ball.rings = 8
	_pop_mat = Palette.unlit_glow(hot_color, 6.0)
	_pop = MeshInstance3D.new()
	_pop.name = "Pop"
	_pop.mesh = ball
	_pop.material_override = _pop_mat
	_burst.add_child(_pop)
	_flash = OmniLight3D.new()
	_flash.name = "Flash"
	_flash.light_color = body_color.lerp(hot_color, 0.35)
	_flash.shadow_enabled = false
	_burst.add_child(_flash)
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
	_burst.add_child(_tag)
	for node in [_floor, _curtain, _spike, _pop]:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The burst at `at` (world space): the floor under it found once (the wave and the curtain stand on it; a
## burst in the air runs its curtain round itself), the static flung out.
func burst(at: Vector3) -> void:
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 3.0, 1))
	_floor_y = (hit["position"] as Vector3).y + 0.03 if not hit.is_empty() else INF
	_foot = _floor_y if is_finite(_floor_y) else at.y - CURTAIN_M * 0.35
	var fx := ParticleFx.of(self)
	if fx != null:
		fx.hup(at, 1.0)


## Its state this frame: the device flying at `at`, or the burst at `at`, `age` seconds after it went off,
## its front `front` metres out.
func show_state(phase: int, age: float, front: float, at: Vector3) -> void:
	if not at.is_finite():
		return
	var flying := phase == 0
	_device.visible = flying
	_burst.visible = not flying
	if flying:
		_device.global_position = at
		_device.rotate_object_local(Vector3.RIGHT, TAU * TUMBLE_TURNS * get_process_delta_time())
		_floor.visible = false
		_curtain.visible = false
		return
	var wave_s := tuning.wave_at(reach)
	var fade := 1.0 - smoothstep(wave_s, wave_s + AFTER_S, age)
	_burst.global_position = at
	_floor.visible = is_finite(_floor_y) and fade > 0.0
	if _floor.visible:
		_floor.global_position = Vector3(at.x, _floor_y, at.z)
	_floor_mat.set_shader_parameter("front", front)
	_floor_mat.set_shader_parameter("age", age)
	_floor_mat.set_shader_parameter("fade", fade)
	_curtain.visible = front > 0.05 and fade > 0.0
	_curtain.global_position = Vector3(at.x, _foot + CURTAIN_M * 0.5, at.z)
	_curtain.scale = Vector3(maxf(front, 0.05), 1.0, maxf(front, 0.05))
	_curtain_mat.set_shader_parameter("age", age)
	_curtain_mat.set_shader_parameter("fade", fade)
	var flash := 1.0 - clampf(age / FLASH_S, 0.0, 1.0)
	_flash.light_energy = FLASH_ENERGY * flash * flash + WAVE_LIGHT * fade
	_flash.omni_range = maxf(front + 2.0, 3.0)
	_pop.visible = age < FLASH_S
	_pop.scale = Vector3.ONE * maxf(flash, 0.01)
	_spike.visible = age < SPIKE_S
	_spike.scale = Vector3(1.0 - age / SPIKE_S, 1.0, 1.0 - age / SPIKE_S) if age < SPIKE_S else Vector3.ONE
	_spike.global_position = Vector3(at.x, _foot + SPIKE_M * 0.5, at.z)
	_tag.position = Vector3.UP * (TAG_RISE_M + TAG_CLIMB_M * clampf(age / (wave_s + AFTER_S), 0.0, 1.0))
	_tag.modulate.a = clampf(fade * 1.5, 0.0, 1.0)
	_tag.outline_modulate.a = _tag.modulate.a
