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

const Palette = preload("res://scripts/palette.gd")

const BODY_RADIUS := 0.4
const BODY_HEIGHT := 1.5
const VISOR_SIZE := Vector3(0.5, 0.12, 0.3)
const VISOR_HEIGHT := 0.55
const VISOR_FORWARD := -0.28
const TAG_HEIGHT := 1.25
const FEET := 0.9
const SAMPLES_KEPT := 12
## The most a sequence number may jump past the last one accepted: packets lost for over
## eight minutes at 20 a second. A bigger jump is one bad packet, dropped, so it can never
## put the real stream behind it.
const SEQ_JUMP_LAST := 10000
## A sample's shape: {t, pos, yaw, pitch, vel}.

## Shown above the body.
var player_name := "player":
	set(value):
		player_name = value
		if _tag != null:
			_tag.text = value
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
	visible = false


## A received position: `seq` orders them; an older one, or one too far ahead, is dropped.
func push_sample(seq: int, pos: Vector3, yaw: float, pitch: float, vel: Vector3) -> void:
	received += 1
	if not seq_ok(seq, _last_seq):
		dropped += 1
		return
	_last_seq = seq
	samples.append({"t": _clock, "pos": pos, "yaw": yaw, "pitch": pitch, "vel": vel})
	while samples.size() > SAMPLES_KEPT:
		samples.pop_front()
	if not visible:
		visible = true
		_apply(pos, yaw, pitch)


func _process(delta: float) -> void:
	_clock += delta
	if samples.is_empty():
		return
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


## True for the next sequence number to accept after `last`: newer, and not absurdly so.
static func seq_ok(seq: int, last: int) -> bool:
	return seq > last and seq - last <= SEQ_JUMP_LAST
