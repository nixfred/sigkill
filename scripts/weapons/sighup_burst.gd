class_name SighupBurst
extends Node3D
## One throw of SIGHUP, the confusion grenade (C32, PRD 5.2): SIGHUP tells a process its terminal hung up,
## so it rereads its config and forgets what it was doing. The device flies as the fork bomb's does (one ray
## a physics frame, no physics body) and goes off where it first meets the level or a body, or in the air
## when its fuse runs out: a hangup burst, its carrier wave running out over the tuning's radius. Every
## number is the SighupTuning in the weapon's projectile slot (resources/sighup.tres).
##
## The wave: from the burst it runs out at wave_speed to its reach (radius_m, wider as root); each thing in
## reach is caught as the front passes it, once a burst, when nothing of the level lies between the burst's
## middle and its middle (behind a wall when the front passes, it is spared). What a catch does:
## a daemon is confused (TargetDummy.take_hup(): its tell called off, its prey dropped, the reload's stall,
## then the confused wander, its lashes at the daemons round it; scripts/fight/daemon_brain.gd); a daemon
## guarded after its last confusion refuses it (counted); a chmod-frozen one takes it and starts confused
## when it thaws. ICE: the hunter is confused as a daemon is and forgets what it learned; a node reloads, its
## field dropped for a while; a wall is not touched; Black ICE ignores it (it runs under nohup): it flashes
## once and the burst's tag says "SIGHUP: ignored (nohup)" (I3's rules stand: never held, never hurt).
## Players (a match): the host judges each it reaches (never the thrower, a dead or a spawn-protected one;
## judge_players), and each one caught is confused on its own screen alone (scripts/player.gd take_hup()).
## It does no damage to anything: its value is control.
##
## Who decides: an authoritative burst (alone, or the host's in a match) goes off on its own and judges; a
## burst on a joiner's screen only draws until the host's word sets it off at the host's place (go_off_at()).
## Daemons are confused only where this screen decides them (decides_daemons): alone, the host's while they
## fight, and the thrower's own screen in a match whose daemons do not (its own idle dummies, as pipe | and
## /dev/null land on them, C30, C31); a joiner's copies of the host's daemons take the host's word.
##
## Cosmetic fiction only: no signal is sent to anything real; SIGHUP is a name.

signal went_off(at: Vector3)
## Something was confused by it (a daemon, the hunter, a node; players are the host's, its own signal).
signal caught(what: Node, at: Vector3)
signal finished

const Tuning = preload("res://scripts/weapons/sighup_tuning.gd")
const Palette = preload("res://scripts/palette.gd")
const GrepLock = preload("res://scripts/weapons/grep_lock.gd")
const LookScript = preload("res://scripts/weapons/sighup_look.gd")
const SfxSynth = preload("res://scripts/sfx_synth.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")
## Every burst joins this group: the tests find them.
const GROUP := &"sighup"
## The node under a scene's root that holds every burst there.
const FIELD := "SighupBursts"
## The level: what stops the device and blocks the wave.
const LEVEL_MASK := 1
## A device stopped by a wall or a ceiling goes off this far off its face.
const REST_OFF_M := 0.3
## Its tag over the burst, the command it is and the modem's last word, and Black ICE's refusal under it.
const TAG_LINES := "$ kill -HUP\nNO CARRIER  %d reloading"
const NOHUP_LINE := "SIGHUP: ignored (nohup)"
## A joiner's copy that flew its whole fuse and more without the host's word ends on its own.
const WORD_WAIT_S := 1.5
## The most a burst may say it confused (the host's word is checked against it).
const COUNT_LAST := 256
## Seconds the burst's look lasts after its wave has reached its edge.
const AFTER_S := 1.2

enum Phase { FLYING, WAVE, DONE }

var tuning: Tuning
var seed := 0
## Who threw it (its player id in a match, 0 alone), and its key for the live cap.
var thrower := 0
var thrower_key := ""
## True: goes off on its own and judges (alone, or the host's). False: draws the host's.
var authoritative := true
## True where this screen confuses the daemons it reaches (see the head of the file).
var decides_daemons := true
## C22's root at the throw: a wider reach.
var root := false
var reach := 7.0
## What the device stops at (the level) and the bodies it goes off on.
var world_mask := LEVEL_MASK
var target_mask := 6
## Never met in flight: the thrower's own body.
var exclude: Array[RID] = []
## judge_players(burst) on the host judges every player the wave has reached (its session), each frame of it.
var judge_players := Callable()
var body_color := Palette.SIGHUP
var light_color := Palette.SIGHUP_TEXT
## Its skin's hot colour (C33): the wave's front, the flash, the pop.
var hot_color := Palette.SIGHUP_HI

var phase := Phase.FLYING
## Seconds since it was thrown, and since it went off.
var age := 0.0
var wave_age := 0.0
## The burst's middle, world space (INF until it goes off).
var center := Vector3.INF
## The counts, for the tag and the checks: things it confused, things that refused it (guarded), things the
## front passed behind the level, nodes it reloaded, hunters it made forget, Black ICE's refusal.
var caught_count := 0
var refused := 0
var spared := 0
var nodes_reloaded := 0
var hunters_forgot := 0
var black_refused := false
## Players the host has confused with it (their ids), so each goes once.
var players_caught := {}

var _pos := Vector3.ZERO
var _vel := Vector3.ZERO
var _stopped := false
## What the front has passed: node -> true.
var _passed := {}
var _look: Node3D
var _hiss: AudioStreamPlayer3D
static var _sounds := {}


## A throw under `root_node` (the arena) from `origin` at `velocity` (world space).
static func spawn(root_node: Node, with_tuning: Tuning, origin: Vector3, velocity: Vector3, throw_seed: int, key: String, deciding: bool, thrower_id: int, root_on: bool, skin: String, never: Array[RID] = [], judged_players: Callable = Callable(), daemons: bool = true) -> Node3D:
	var burst = load("res://scripts/weapons/sighup_burst.gd").new()
	burst.name = "Sighup"
	burst.tuning = with_tuning
	burst.seed = throw_seed
	burst.thrower_key = key
	burst.thrower = thrower_id
	burst.authoritative = deciding
	burst.root = root_on
	burst.reach = with_tuning.reach_for(root_on)
	burst.exclude = never
	burst.judge_players = judged_players
	burst.decides_daemons = daemons
	burst.body_color = Palette.skin_body(skin)
	burst.light_color = Palette.skin_beam(skin)
	burst.hot_color = Palette.skin_hot(skin)
	burst._pos = origin
	burst._vel = velocity
	field_of(root_node).add_child(burst)
	burst.global_position = origin
	return burst


## The node under `root_node` that holds its bursts, made on first use.
static func field_of(root_node: Node) -> Node3D:
	var field := root_node.get_node_or_null(FIELD) as Node3D
	if field == null:
		field = Node3D.new()
		field.name = FIELD
		root_node.add_child(field)
	return field


## Devices `key` has in the air (thrown and not yet gone off) under `root_node`: the live cap's count.
static func live_of(root_node: Node, key: String) -> int:
	var field := root_node.get_node_or_null(FIELD)
	if field == null:
		return 0
	var n := 0
	for burst in field.get_children():
		if burst is SighupBurst and burst.thrower_key == key and burst.phase == Phase.FLYING:
			n += 1
	return n


## The device's velocity for a throw along `aim`: the throw speed along it, and lift.
static func throw_velocity(with_tuning: Tuning, aim: Vector3) -> Vector3:
	return aim.normalized() * with_tuning.throw_speed + Vector3.UP * with_tuning.throw_lift


func _ready() -> void:
	add_to_group(GROUP)
	_look = LookScript.new()
	_look.name = "Look"
	add_child(_look)
	_look.hot_color = hot_color
	_look.setup(tuning, body_color, light_color, reach)
	_hiss = AudioStreamPlayer3D.new()
	_hiss.stream = _sound()
	_hiss.volume_db = -2.0
	_hiss.unit_size = 9.0
	_hiss.bus = SettingsApply.EFFECTS
	add_child(_hiss)
	var fx := ParticleFx.of(self)
	if fx != null:
		fx.follow(_look.device(), light_color)


## Its sound, made once and kept (the I3 note: synthesis at a throw would hitch).
static func _sound() -> AudioStream:
	if not _sounds.has("hangup"):
		_sounds["hangup"] = SfxSynth.hangup()
	return _sounds["hangup"]


## True from the burst until its look is done.
func went() -> bool:
	return phase == Phase.WAVE


## How far its wave's front has run now, metres (0 before it went off).
func front_m() -> float:
	return minf(wave_age * tuning.wave_speed, reach) if phase == Phase.WAVE else 0.0


## Seconds from the burst until its wave reaches its edge.
func wave_s() -> float:
	return tuning.wave_at(reach)


## Its tag over the burst (C32): the command, the count it confused, and Black ICE's refusal.
func tag_text() -> String:
	var text := TAG_LINES % caught_count
	return text + ("\n" + NOHUP_LINE if black_refused else "")


func _physics_process(delta: float) -> void:
	if phase == Phase.DONE:
		return
	age += delta
	if phase == Phase.FLYING:
		_fly(delta)
		return
	wave_age += delta
	if wave_age <= wave_s() + delta:
		_sweep()
		if authoritative and judge_players.is_valid():
			judge_players.call(self)
	if wave_age >= wave_s() + AFTER_S:
		_close()


func _process(_delta: float) -> void:
	if _look != null and phase != Phase.DONE:
		_look.show_state(phase, wave_age, front_m(), _pos if phase == Phase.FLYING else center)
		if phase == Phase.WAVE:
			_look.set_tag(tag_text())


# --- The throw. ---

func _fly(delta: float) -> void:
	if _stopped:
		if not authoritative and age > tuning.fuse_s + WORD_WAIT_S:
			_close()  # the host's word never came
		return
	_vel += Vector3.DOWN * tuning.gravity * delta
	var to := _pos + _vel * delta
	var query := PhysicsRayQueryParameters3D.create(_pos, to, world_mask | (target_mask if authoritative else 0))
	query.exclude = exclude
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var normal: Vector3 = hit["normal"] if not (hit["normal"] as Vector3).is_zero_approx() else Vector3.UP
		_pos = hit["position"] + normal * REST_OFF_M
		_stopped = true
		if authoritative:
			_go_off(_middle_over(hit["position"], normal))
		return
	_pos = to
	if age >= tuning.fuse_s:
		_stopped = true
		if authoritative:
			_go_off(_pos)  # the fuse ran out in the air: it goes off where it is


## The burst's middle over a device that met the level at `at` on a face with `normal`: burst_lift_m up
## from a floor (never into the level over it), or REST_OFF_M out from a wall or a ceiling.
func _middle_over(at: Vector3, normal: Vector3) -> Vector3:
	if normal.y < 0.7:
		return at + normal * REST_OFF_M
	var up := at + Vector3.UP * tuning.burst_lift_m
	var ceiling := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.05, up, LEVEL_MASK))
	return up if ceiling.is_empty() else (ceiling["position"] as Vector3) - Vector3.UP * REST_OFF_M


## The host's word: it went off at `at` (world space), on a burst that only draws.
func go_off_at(at: Vector3) -> void:
	if authoritative or phase != Phase.FLYING or not at.is_finite():
		return
	_pos = at
	_go_off(at)


## The host's word on a burst that only draws: it has confused `count` things so far; each new one the signal
## (the thrower's callout at its first) and the tag's count.
func told_caught(count: int, at: Vector3) -> void:
	if authoritative:
		return
	while caught_count < mini(count, COUNT_LAST):
		caught_count += 1
		caught.emit(null, at)


func _go_off(at: Vector3) -> void:
	center = at
	phase = Phase.WAVE
	wave_age = 0.0
	_hiss.play()
	_look.burst(at)
	went_off.emit(at)


# --- The wave. ---

## Everything the front has reached since the last step: caught once, if the burst's middle can see it.
func _sweep() -> void:
	var root_node := get_parent().get_parent() if get_parent() != null else null
	if root_node == null:
		return
	var space := get_world_3d().direct_space_state
	var front := front_m()
	for body in get_tree().get_nodes_in_group(GrepLock.TARGET_GROUP):
		if not (body is Node3D) or body is IcePiece or not root_node.is_ancestor_of(body) or _passed.has(body):
			continue
		if not GrepLock.alive(body) or not body.has_method("take_hup"):
			continue
		var middle := GrepLock.point_of(body)
		if middle.distance_to(center) > front:
			continue
		_passed[body] = true
		if not _in_sight(middle, space):
			spared += 1
			continue
		if not decides_daemons or (body.has_method("_follows") and body.call("_follows") == true):
			continue  # a joiner's copy of the host's daemon: the host's word confuses it
		if body.take_hup(tuning, thrower):
			caught_count += 1
			caught.emit(body, middle)
		else:
			refused += 1
	var ice := IceDirector.of(root_node)
	if ice == null:
		return
	for piece in ice.pieces():
		if not is_instance_valid(piece) or not root_node.is_ancestor_of(piece) or _passed.has(piece):
			continue
		var at: Vector3 = (piece as IcePiece).aim_point()
		if at.distance_to(center) > front:
			continue
		_passed[piece] = true
		if piece is BlackIce:
			_refuse(piece)
			continue
		if piece is IceBarrier or piece.broken or not authoritative:
			continue  # a wall is not touched (C32); ICE on a joiner is the host's word
		if not _in_sight(at, space):
			spared += 1
			continue
		if piece.take_hup(tuning, thrower):
			caught_count += 1
			if piece is IceNode:
				nodes_reloaded += 1
			elif piece is HunterIce:
				hunters_forgot += 1
			caught.emit(piece, at)
		else:
			refused += 1


## Black ICE (I3): it runs under nohup, so a hangup means nothing to it: never confused, held or hurt, its
## seals and touch untouched; it flashes once, and the tag says so.
func _refuse(piece: Node3D) -> void:
	if black_refused or not piece.has_method("present_now") or not piece.present_now():
		return
	black_refused = true
	if piece.get("art") != null and piece.art.has_method("flash"):
		piece.art.flash()


## How this burst reaches a player whose middle is at `middle` (the host's judge): true once its front has
## passed it, within its reach, with nothing of the level between.
func reaches(middle: Vector3, space: PhysicsDirectSpaceState3D) -> bool:
	if phase != Phase.WAVE or not center.is_finite():
		return false
	var distance := middle.distance_to(center)
	return distance <= front_m() and distance <= reach and _in_sight(middle, space)


func _close() -> void:
	if phase == Phase.DONE:
		return
	phase = Phase.DONE
	finished.emit()
	# The hiss plays out on its own; the burst goes once it has.
	var wait := _hiss.stream.get_length() - _hiss.get_playback_position() if _hiss.playing and _hiss.stream != null else 0.0
	if wait > 0.0 and is_inside_tree():
		_look.visible = false
		get_tree().create_timer(wait).timeout.connect(queue_free)
	else:
		queue_free()


func _in_sight(middle: Vector3, space: PhysicsDirectSpaceState3D) -> bool:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(center, middle, LEVEL_MASK)).is_empty()
