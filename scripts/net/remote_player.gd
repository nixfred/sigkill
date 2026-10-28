extends Node3D
## Another player, as seen on this machine (C13): a placeholder body in the player side's
## neon, built in code from the palette, with a name tag. It never reads input and never
## collides; the session (scripts/net/net_session.gd) feeds it the positions it receives.
##
## Movement is smoothed by snapshot interpolation: every received position is kept with
## the local time it arrived, and the avatar is drawn `interp_delay_ms` behind the newest
## one, gliding between the two samples around that moment. When positions stop coming
## it keeps going on the last velocity for at most `extrapolate_max_ms`, then holds still.
## Hidden until the first position arrives.
##
## Combat (C14): a hit volume on the targets layer, which rays hit and nothing walks into
## (players collide with the world layer only), carrying the player's id for the host's
## raycast. die() plays the derezz effect (the dummies' own) and hides the avatar; revive()
## brings it back at the spawn. While protected, the body's edges glow mint instead of teal.

const Palette = preload("res://scripts/palette.gd")
const DerezzFx = preload("res://scripts/derezz_fx.gd")
const DerezzTuning = preload("res://scripts/derezz_tuning.gd")
const DEREZZ_PATH := "res://resources/derezz.tres"
const WeaponDefScript = preload("res://scripts/weapons/weapon_def.gd")
## The targets physics layer (3), the dummies' layer: hit by the cannon, walked through.
const HIT_LAYER := 4
const HIT_RADIUS := 0.4
const HIT_HEIGHT := 1.8

const BODY_RADIUS := 0.4
const BODY_HEIGHT := 1.5
const VISOR_SIZE := Vector3(0.5, 0.12, 0.3)
const VISOR_HEIGHT := 0.55
const VISOR_FORWARD := -0.28
const TAG_HEIGHT := 1.25
const FEET := 0.9
## The tag's mark for a player who is root (C22).
const ROOT_TAG := "  root#"
## Samples are kept back to the one just before the drawn moment, whatever the delay and
## the rate; this cap only bounds memory against a flood.
const SAMPLES_LAST := 256
## The most a sequence number may jump past the last one accepted: packets lost for over
## eight minutes at 20 a second. A bigger jump is one bad packet, dropped, so it can never
## put the real stream behind it. The first sample sets the baseline, whatever its number.
const SEQ_JUMP_LAST := 10000
## Sequence numbers are counted up from 1 and never reach this; anything at or past it is
## no sequence number at all, and the session refuses it before it gets here.
const SEQ_LAST := 2147483647
## A sample's shape: {t, pos, yaw, pitch, vel}.

## The id the host knows this player by; the hit volume carries it for the raycast.
var player_id := 0:
	set(value):
		player_id = value
		if _hit != null:
			_hit.set_meta("player_id", value)
## Shown above the body, with the health.
var player_name := "player":
	set(value):
		player_name = value
		_retag()
var health := 100.0:
	set(value):
		health = value
		_retag()
var dead := false
## Root (C22), from the host's word: the visor glows root's red and the tag says "root#".
var root := false
var protected := false:
	set(value):
		protected = value
		if _body != null:
			(_body.material_override as ShaderMaterial).set_shader_parameter("edge_color", Palette.MINT if value else Palette.TEAL)
## Seconds the avatar is drawn behind the newest sample.
var interp_delay_s := 0.1
## Longest it moves on its last velocity with no new sample.
var extrapolate_max_s := 0.2
## Samples received, oldest first.
var samples: Array = []
## Received samples, and samples dropped as older than one already here.
var received := 0
var dropped := 0

var _clock := 0.0
var _last_seq := -1
var _body: MeshInstance3D
var _head: Node3D
var _visor: MeshInstance3D
var _tag: Label3D
var _hit: StaticBody3D
var _hit_shape: CollisionShape3D


func _ready() -> void:
	var hex := CylinderMesh.new()
	hex.radial_segments = 6
	hex.top_radius = BODY_RADIUS
	hex.bottom_radius = BODY_RADIUS
	hex.height = BODY_HEIGHT
	_body = MeshInstance3D.new()
	_body.name = "Body"
	_body.mesh = hex
	_body.material_override = Palette.ally_material(BODY_RADIUS, BODY_HEIGHT)
	# The avatar's origin is the other player's: the centre of a 1.8 m capsule. Feet at -0.9.
	_body.position.y = BODY_HEIGHT * 0.5 - FEET
	add_child(_body)
	_head = Node3D.new()
	_head.name = "Head"
	_head.position.y = VISOR_HEIGHT
	add_child(_head)
	var box := BoxMesh.new()
	box.size = VISOR_SIZE
	_visor = MeshInstance3D.new()
	_visor.name = "Visor"
	_visor.mesh = box
	_visor.material_override = Palette.glow(Palette.MINT, 2.4)
	_visor.position.z = VISOR_FORWARD
	_head.add_child(_visor)
	_tag = Label3D.new()
	_tag.name = "Tag"
	_tag.text = player_name
	_tag.font = Palette.mono_font()
	_tag.font_size = 40
	_tag.pixel_size = 0.006
	_tag.outline_size = 10
	_tag.modulate = Palette.MINT
	_tag.outline_modulate = Palette.VOID
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.position.y = TAG_HEIGHT
	add_child(_tag)
	_retag()
	_hit = StaticBody3D.new()
	_hit.name = "Hit"
	_hit.collision_layer = HIT_LAYER
	_hit.collision_mask = 0
	_hit.set_meta("player_id", player_id)
	var capsule := CapsuleShape3D.new()
	capsule.radius = HIT_RADIUS
	capsule.height = HIT_HEIGHT
	_hit_shape = CollisionShape3D.new()
	_hit_shape.shape = capsule
	_hit_shape.disabled = true  # nothing to hit until the player's first position is known
	_hit.add_child(_hit_shape)
	add_child(_hit)
	visible = false


## A received position: `seq` orders them; an older one, or one too far ahead, is dropped.
func push_sample(seq: int, pos: Vector3, yaw: float, pitch: float, vel: Vector3) -> void:
	received += 1
	if not seq_ok(seq, _last_seq):
		dropped += 1
		return
	_last_seq = seq
	samples.append({"t": _clock, "pos": pos, "yaw": yaw, "pitch": pitch, "vel": vel})
	_trim()
	if not visible:
		visible = true
		_apply(pos, yaw, pitch)
		if not dead:
			_hit_shape.set_deferred("disabled", false)


func _process(delta: float) -> void:
	_clock += delta
	if samples.is_empty():
		return
	_trim()
	var at := _clock - interp_delay_s
	var newest: Dictionary = samples[-1]
	if at >= newest["t"]:
		var ahead := minf(at - newest["t"], extrapolate_max_s)
		_apply(newest["pos"] + newest["vel"] * ahead, newest["yaw"], newest["pitch"])
		return
	var later: Dictionary = newest
	var earlier: Dictionary = samples[0]
	for i in range(samples.size() - 1, 0, -1):
		if samples[i - 1]["t"] <= at:
			earlier = samples[i - 1]
			later = samples[i]
			break
	if at <= earlier["t"] or later["t"] <= earlier["t"]:
		_apply(earlier["pos"], earlier["yaw"], earlier["pitch"])
		return
	var w := clampf((at - earlier["t"]) / (later["t"] - earlier["t"]), 0.0, 1.0)
	_apply(earlier["pos"].lerp(later["pos"], w), lerp_angle(earlier["yaw"], later["yaw"], w), lerpf(earlier["pitch"], later["pitch"], w))


func _apply(pos: Vector3, yaw: float, pitch: float) -> void:
	position = pos
	rotation = Vector3(0.0, yaw, 0.0)
	_head.rotation = Vector3(pitch, 0.0, 0.0)


func view_pitch() -> float:
	return _head.rotation.x


## The newest received position, or where the avatar stands.
## True when `point` is in this avatar's head zone (C17): the top of its hit capsule,
## WeaponDef's HEAD_ZONE_M deep.
func is_head_hit(point: Vector3) -> bool:
	return point.y >= _hit.global_position.y + HIT_HEIGHT * 0.5 - WeaponDefScript.HEAD_ZONE_M


func latest_position() -> Vector3:
	return samples[-1]["pos"] if not samples.is_empty() else position


## Where the player looked in the newest sample, a unit vector in arena space (body yaw, view
## pitch), or ZERO when nothing has come yet (C19: the host judges a throw's aim by it).
func latest_view() -> Vector3:
	if samples.is_empty():
		return Vector3.ZERO
	var newest: Dictionary = samples[-1]
	return (Basis(Vector3.UP, newest["yaw"]) * Basis(Vector3.RIGHT, newest["pitch"]) * Vector3.FORWARD).normalized()


func hit_rid() -> RID:
	return _hit.get_rid()


## Down: the derezz plays where the body stood, pushed along the killing shot, and the
## avatar hides until revive(). The effect lives beside the avatar, so it outlives nothing
## it should not.
func die(shot_dir: Vector3) -> void:
	if dead:
		return
	dead = true
	_body.visible = false
	_head.visible = false
	_tag.visible = false
	_hit_shape.set_deferred("disabled", true)
	var d = load(DEREZZ_PATH)
	if not (d is DerezzTuning) or not d.problems().is_empty():
		d = DerezzTuning.new()
	var fx := DerezzFx.new()
	get_parent().add_child(fx)
	var along := Vector3(shot_dir.x, 0.0, shot_dir.z)
	fx.start(global_position + Vector3(0.0, -FEET, 0.0), BODY_RADIUS, BODY_HEIGHT, along.normalized() if not along.is_zero_approx() else Vector3.FORWARD, d)


## Down as far as this side knows, with no shot to show: hidden, no effect.
func hide_dead() -> void:
	if dead:
		return
	dead = true
	_body.visible = false
	_head.visible = false
	_tag.visible = false
	_hit_shape.set_deferred("disabled", true)


## Back at `pos`: shown, hittable, with no stale positions to glide from.
func revive(pos: Vector3) -> void:
	dead = false
	samples.clear()
	_apply(pos, rotation.y, 0.0)
	_body.visible = true
	_head.visible = true
	_tag.visible = true
	_hit_shape.set_deferred("disabled", false)
	visible = true


func _retag() -> void:
	if _tag != null:
		_tag.text = "%s  %d%s" % [player_name, roundi(health), ROOT_TAG if root else ""]


## Root's look on this avatar (C22): a red visor and "root#" on its tag while on.
func set_root(on: bool) -> void:
	root = on
	if _visor != null:
		var glow := _visor.material_override as StandardMaterial3D
		if glow != null:
			glow.emission = Palette.HOSTILE_RED if on else Palette.MINT
			glow.albedo_color = (Palette.HOSTILE_RED if on else Palette.MINT).darkened(0.65)
	_retag()


## Drops samples older than the one just before the drawn moment, and bounds the buffer.
func _trim() -> void:
	var at := _clock - interp_delay_s
	while samples.size() > 2 and samples[1]["t"] <= at:
		samples.pop_front()
	while samples.size() > SAMPLES_LAST:
		samples.pop_front()


## True for a sequence number to accept after `last`: any first one, else newer and not
## absurdly far ahead. `seq` is in range already (the session refuses the rest).
static func seq_ok(seq: int, last: int) -> bool:
	if seq < 0 or seq >= SEQ_LAST:
		return false
	if last < 0:
		return true
	return seq > last and seq - last <= SEQ_JUMP_LAST
