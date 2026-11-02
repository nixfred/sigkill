class_name CoverDrone
extends Node3D
## "Larry, cover me" (W7, PRD 5.5): your AI's cover drone, a short-lived sentry over the player's shoulder. Called by
## voice (scripts/voice/voice_commands.gd) or the cover key (P), alone, wherever the player's abilities are not gated
## (never in a mission, which hands out its own abilities, and never in co-op, which is weapons only).
##
## It deploys out of the player's shoulder (its ring unfolding, a flash), keeps station high on their right for COVER_S,
## and covers: it picks a daemon it can see within RANGE_M (the nearest, those in front of the player first), locks on for LOCK_S (a sight line drawn from its
## lens, thin and pulsing, whitening as the lock closes, and a tick), then fires one bolt (a tracer, a flash at the lens,
## sparks where it lands) for DAMAGE, and recovers for RECOVER_S. Then it folds its ring and streaks up out of sight.
## Its kills are on the screen as anyone's, and credited as its own (the source "cover"): no sudo charge, no feat
## toward an unlock (scripts/main.gd). Every hit is the game's own, simulated; nothing real is touched.
##
## The look, in the player's own colours (it is on their side): a faceted core of mint light between two dark hex
## plates, a teal ring round it carrying three pods on three arms, turning (fast as it deploys and fires), a lens on its
## front, its own small light, and over it a tag, "your AI  cover  9", counting down.

const Palette = preload("res://scripts/palette.gd")
const VoiceSound = preload("res://scripts/voice/voice_sound.gd")

const SOURCE := "cover"
## Seconds: unfolding, on station, folding and leaving.
const DEPLOY_S := 0.5
const COVER_S := 10.0
const LEAVE_S := 0.65
## Seconds: a lock's tell, and the rest after a shot.
const LOCK_S := 0.55
const RECOVER_S := 0.55
## Metres: how far it sees a daemon, and where it keeps station from the player's eye (right, up, ahead): high on the
## right, out in front, where the player sees it work without it crossing the crosshair.
const RANGE_M := 30.0
const STATION := Vector3(1.25, 0.62, 2.7)
## Its size against the parts' own (the parts are modelled at a metre across, ring to ring).
const SIZE := 0.6
## A shot's damage (a plain daemon has 1 health; an elite 30; a world mode's own more).
const DAMAGE := 20.0
## How fast it follows its station (per second, exponential).
const FOLLOW := 7.0

signal fired(target: Node3D)
signal left

var player: Node3D = null
var phase := "deploy"
var shots := 0
var _t := 0.0
var _phase_t := 0.0
var _target: Node3D = null
var _lock_t := 0.0
var _rest_t := 0.0
var _scan_t := 0.0
var _rig: Node3D
var _ring: Node3D
var _core: MeshInstance3D
var _lens: MeshInstance3D
var _light: OmniLight3D
var _tag: Label3D
var _sight: MeshInstance3D
var _sight_mat: StandardMaterial3D
var _tracer: MeshInstance3D
var _tracer_mat: StandardMaterial3D
var _tracer_t := 0.0
var _flash_t := 0.0
var _burst: MeshInstance3D
var _burst_mat: StandardMaterial3D
var _sfx: AudioStreamPlayer3D
## Whether it left as it should (folded and flew off); freed any other way (the arena reloading under it), it starts the
## recharge as it goes, so a reload never hands a fresh drone straight back (P1).
var _left_sent := false


func _ready() -> void:
	name = "CoverDrone"
	_build()
	if player != null and is_instance_valid(player):
		global_position = _station()
	scale = Vector3.ONE * 0.05
	_play("deploy")


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and not _left_sent:
		VoiceCommands.cover_wait = VoiceCommands.COVER_COOL_S


## Seconds of cover left (0 once it is leaving).
func left_s() -> float:
	if phase == "deploy":
		return COVER_S
	return maxf(COVER_S - _phase_t, 0.0) if phase == "cover" else 0.0


## What it is locked on, if anything.
func target() -> Node3D:
	return _target if _target != null and is_instance_valid(_target) else null


## Sent away at once (the player derezzed, the arena reloading): it folds and leaves.
func dismiss() -> void:
	if phase != "leave":
		_enter("leave")


func _enter(next: String) -> void:
	phase = next
	_phase_t = 0.0
	if next == "leave":
		_drop_target()
		_play("leave")


func _physics_process(delta: float) -> void:
	_t += delta
	_phase_t += delta
	if player == null or not is_instance_valid(player):
		if phase != "leave":
			_enter("leave")
	elif player.get("alive") == false and phase != "leave":
		_enter("leave")
	match phase:
		"deploy":
			var k := clampf(_phase_t / DEPLOY_S, 0.0, 1.0)
			scale = Vector3.ONE * maxf(_back_out(k), 0.05)
			if k >= 1.0:
				_enter("cover")
				_burst_at(_rig.global_position, 1.0)
		"cover":
			_step_cover(delta)
			if _phase_t >= COVER_S:
				_enter("leave")
		"leave":
			var k := clampf(_phase_t / LEAVE_S, 0.0, 1.0)
			scale = Vector3.ONE * maxf(1.0 - k * 0.7, 0.05)
			global_position += Vector3.UP * delta * lerpf(2.0, 26.0, k * k)
			if k >= 1.0:
				_left_sent = true
				left.emit()
				queue_free()
				return
	if phase != "leave" and player != null and is_instance_valid(player):
		var want := _station() + Vector3(0, sin(_t * 2.3) * 0.06, 0)
		global_position = global_position.lerp(want, 1.0 - exp(-FOLLOW * delta))
	_animate(delta)


func _step_cover(delta: float) -> void:
	if _rest_t > 0.0:
		_rest_t -= delta
		return
	if target() == null or not _ok(_target):
		_drop_target()
		_scan_t -= delta
		if _scan_t <= 0.0:
			_scan_t = 0.15
			_target = _pick()
			if _target != null:
				_lock_t = 0.0
				_play("lock")
		return
	_lock_t += delta
	if _lock_t >= LOCK_S:
		_fire(_target)
		_drop_target()
		_rest_t = RECOVER_S


## The daemon to cover the player from: alive, not sealed, not hidden, with a clear line from its lens, the nearest by a
## measure that weighs what is in front of the player (where they are looking) over what is beside them (2.5 times as
## far) or behind them (4 times), so its fire goes where the player can see it land.
func _pick() -> Node3D:
	var best: Node3D = null
	var best_score := INF
	var facing := -player.global_transform.basis.z if player != null and is_instance_valid(player) else Vector3.FORWARD
	facing.y = 0.0
	facing = facing.normalized() if facing.length() > 0.01 else Vector3.FORWARD
	for node in get_tree().get_nodes_in_group("targets"):
		var dummy := node as Node3D
		if dummy == null or not _ok(dummy):
			continue
		var to := _aim_of(dummy) - global_position
		var flat := Vector3(to.x, 0.0, to.z)
		var ahead := flat.normalized().dot(facing) if flat.length() > 0.01 else 1.0
		var score := to.length() * (1.0 + (1.0 - ahead) * 1.5)
		if score < best_score and _clear(dummy):
			best_score = score
			best = dummy
	return best


func _ok(dummy: Node3D) -> bool:
	if dummy == null or not is_instance_valid(dummy) or not dummy.is_inside_tree() or dummy.is_queued_for_deletion():
		return false
	if not dummy.has_method("is_alive") or not dummy.is_alive() or dummy.get("sealed") == true or not dummy.is_visible_in_tree():
		return false
	return global_position.distance_to(_aim_of(dummy)) <= RANGE_M


static func _aim_of(dummy: Node3D) -> Vector3:
	return dummy.threat_point() if dummy.has_method("threat_point") else dummy.global_position


func _clear(dummy: Node3D) -> bool:
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space == null:
		return true
	var to := _aim_of(dummy)
	var query := PhysicsRayQueryParameters3D.create(global_position, to)
	if player is CollisionObject3D:
		query.exclude = [(player as CollisionObject3D).get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider = hit.get("collider")
	if collider == dummy or (collider is Node and dummy.is_ancestor_of(collider)):
		return true
	return (hit["position"] as Vector3).distance_to(to) < 0.8


func _fire(dummy: Node3D) -> void:
	var to := _aim_of(dummy)
	var from := _lens.global_position
	shots += 1
	if "struck_by" in dummy:
		dummy.struck_by = player
	dummy.hit(DAMAGE, to, (to - from).normalized(), SOURCE)
	_tracer_t = 0.09
	_place_beam(_tracer, from, to, 0.028)
	_flash_t = 0.12
	var fx := ParticleFx.of(self)
	if fx != null:
		fx.impact(to, (from - to).normalized(), false, Palette.TEAL)
	_burst_at(to, 0.6)
	_play("shot")
	fired.emit(dummy)


func _drop_target() -> void:
	_target = null
	_lock_t = 0.0
	if _sight != null:
		_sight.visible = false


func _station() -> Vector3:
	var eye: Vector3 = player.eye_position() if player.has_method("eye_position") else player.global_position + Vector3.UP * 1.6
	var basis: Basis = player.global_transform.basis
	var right := basis.x.normalized()
	var ahead := -basis.z.normalized()
	return eye + right * STATION.x + Vector3.UP * STATION.y + ahead * STATION.z


# --- The look. ---

func _animate(delta: float) -> void:
	var spin := 1.6 + (7.0 if phase == "deploy" or _flash_t > 0.0 else 0.0) + (3.0 if target() != null else 0.0)
	_ring.rotate_object_local(Vector3.UP, spin * delta)
	_core.rotate_object_local(Vector3(0.3, 1.0, 0.2).normalized(), 0.9 * delta)
	var aim := target()
	var face := (_aim_of(aim) - global_position) if aim != null else -player.global_transform.basis.z if player != null and is_instance_valid(player) else Vector3.FORWARD
	face.y *= 0.6
	if face.length() > 0.01:
		# The drone itself never turns (it only scales and moves), so the rig's own basis is its facing in the world.
		var want := Basis.looking_at(face.normalized(), Vector3.UP)
		_rig.basis = _rig.basis.orthonormalized().slerp(want.orthonormalized(), 1.0 - exp(-9.0 * delta)).orthonormalized()
	var lock_k := clampf(_lock_t / LOCK_S, 0.0, 1.0) if aim != null else 0.0
	if aim != null:
		_sight.visible = true
		var flicker := 0.75 + 0.25 * sin(_t * 60.0)
		_place_beam(_sight, _lens.global_position, _aim_of(aim), lerpf(0.006, 0.018, lock_k))
		_sight_mat.albedo_color = Color(Palette.TEAL.lerp(Palette.FLASH, lock_k * 0.8), lerpf(0.35, 0.95, lock_k) * flicker)
	_tracer_t = maxf(_tracer_t - delta, 0.0)
	_tracer.visible = _tracer_t > 0.0
	_tracer_mat.albedo_color = Color(Palette.MINT.lerp(Palette.FLASH, 0.6), _tracer_t / 0.09)
	_flash_t = maxf(_flash_t - delta, 0.0)
	_light.light_energy = 0.8 + 4.0 * _flash_t / 0.12 + 1.0 * lock_k
	var core_mat := _core.material_override as StandardMaterial3D
	core_mat.emission_energy_multiplier = 1.8 + 2.5 * lock_k + 5.0 * _flash_t / 0.12
	(_lens.material_override as StandardMaterial3D).emission_energy_multiplier = 1.5 + 5.0 * lock_k + 8.0 * _flash_t / 0.12
	var left := ceili(left_s())
	_tag.text = "your AI  cover  %d" % left if phase == "cover" else ("your AI  cover" if phase == "deploy" else "")
	_tag.modulate.a = 1.0 if phase != "leave" else 0.0
	if _burst.visible:
		var b: float = _burst.get_meta(&"t", 0.0) + delta
		_burst.set_meta(&"t", b)
		var size: float = _burst.get_meta(&"size", 1.0)
		_burst.scale = Vector3.ONE * size * (0.2 + b * 6.0)
		_burst_mat.albedo_color = Color(Palette.MINT, maxf(0.9 - b * 3.6, 0.0))
		if b > 0.25:
			_burst.visible = false


func _burst_at(at: Vector3, size: float) -> void:
	_burst.top_level = true
	_burst.global_position = at
	_burst.set_meta(&"t", 0.0)
	_burst.set_meta(&"size", size)
	_burst.visible = true


static func _back_out(k: float) -> float:
	var c := 1.9
	var x := k - 1.0
	return 1.0 + (c + 1.0) * x * x * x + c * x * x


func _place_beam(beam: MeshInstance3D, from: Vector3, to: Vector3, width: float) -> void:
	var length := from.distance_to(to)
	if length < 0.01:
		beam.visible = false
		return
	beam.top_level = true
	var mid := (from + to) * 0.5
	var forward := (to - from) / length
	var up := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var b := Basis.looking_at(forward, up)
	# Scaled along the beam's own axes (Basis.scaled() would scale along the world's, stretching a sideways beam wide).
	beam.global_transform = Transform3D(Basis(b.x * width, b.y * width, b.z * length), mid)


func _build() -> void:
	_rig = Node3D.new()
	_rig.name = "Rig"
	_rig.scale = Vector3.ONE * SIZE
	add_child(_rig)
	_core = _mesh(_rig, _sphere(0.15, 6, 3), _glow(Palette.MINT, 1.8))
	var plate_mat := _metal()
	for y in [0.085, -0.085]:
		var plate := _mesh(_rig, _hex(0.24, 0.2, 0.05), plate_mat)
		plate.position = Vector3(0, y, 0)
		var rim := _mesh(_rig, _hex(0.25, 0.25, 0.012), _glow(Palette.TEAL, 1.3))
		rim.position = Vector3(0, y + (0.026 if y > 0 else -0.026), 0)
	_ring = Node3D.new()
	_ring.name = "Ring"
	_rig.add_child(_ring)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.34
	torus.outer_radius = 0.375
	torus.rings = 24
	torus.ring_segments = 6
	_mesh(_ring, torus, _glow(Palette.TEAL, 1.4))
	for i in 3:
		var a := TAU * float(i) / 3.0
		var arm := _mesh(_ring, _box(Vector3(0.03, 0.03, 0.2)), plate_mat)
		arm.position = Vector3(cos(a), 0, sin(a)) * 0.25
		arm.rotation.y = -a + PI * 0.5
		var pod := _mesh(_ring, _sphere(0.045, 6, 3), _glow(Palette.MINT, 2.4))
		pod.position = Vector3(cos(a), 0, sin(a)) * 0.375
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.045
	cyl.bottom_radius = 0.06
	cyl.height = 0.09
	cyl.radial_segments = 8
	_lens = _mesh(_rig, cyl, _glow(Palette.FLASH, 2.0))
	_lens.rotation.x = -PI * 0.5
	_lens.position = Vector3(0, 0, -0.17)
	_light = OmniLight3D.new()
	_light.light_color = Palette.TEAL
	_light.omni_range = 3.2
	_light.light_energy = 1.2
	_light.shadow_enabled = false
	add_child(_light)
	_tag = Label3D.new()
	_tag.font = Palette.mono_font()
	_tag.font_size = 32
	_tag.pixel_size = 0.0012
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true
	_tag.fixed_size = false
	_tag.modulate = Palette.MINT
	_tag.outline_modulate = Color(Palette.VOID, 0.85)
	_tag.outline_size = 10
	_tag.position = Vector3(0, 0.3, 0)
	_tag.render_priority = 2
	add_child(_tag)
	_sight_mat = _beam_mat(Palette.TEAL)
	_sight = _mesh(self, _box(Vector3.ONE), _sight_mat)
	_sight.visible = false
	_tracer_mat = _beam_mat(Palette.MINT)
	_tracer = _mesh(self, _box(Vector3.ONE), _tracer_mat)
	_tracer.visible = false
	_burst_mat = _beam_mat(Palette.MINT)
	_burst = _mesh(self, _sphere(0.12, 10, 5), _burst_mat)
	_burst.visible = false
	_sfx = AudioStreamPlayer3D.new()
	_sfx.name = "CoverSound"
	_sfx.bus = &"Effects" if AudioServer.get_bus_index(&"Effects") >= 0 else &"Master"
	_sfx.max_polyphony = 3
	_sfx.unit_size = 6.0
	add_child(_sfx)


func _play(id: String) -> void:
	if _sfx == null or DisplayServer.get_name() == "headless":
		return
	_sfx.stream = VoiceSound.of(id)
	_sfx.play()


static func _mesh(parent: Node, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m


static func _sphere(r: float, segments: int, rings: int) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segments
	s.rings = rings
	return s


static func _hex(top: float, bottom: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = 6
	return c


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color * 0.3
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


static func _metal() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Palette.GUNMETAL_LIGHT
	m.metallic = 0.8
	m.roughness = 0.35
	m.rim_enabled = true
	m.rim = 0.6
	m.rim_tint = 0.8
	return m


static func _beam_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	return m
