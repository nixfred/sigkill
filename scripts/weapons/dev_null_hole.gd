class_name DevNullHole
extends Node3D
## One throw of /dev/null, the black-hole grenade (C31, PRD 5.2): everything written to /dev/null is
## discarded. The device flies as the fork bomb's does (one ray a physics frame, no physics body) and opens
## a singularity where it first meets the level or a body, or in the air when its fuse runs out. Every
## number is the DevNullTuning in the weapon's projectile slot (resources/dev_null.tres).
##
## The hole: it grows over open_s, pulls for hold_s, then collapses over collapse_s into its implosion.
## Everything it reaches (within its reach of the core's vertical axis, with nothing of the level between
## the core and its middle) is held: dragged toward the axis at the tuning's pull for its distance (growing
## inward, and over the hole's first ramp_s), swirled round it by swirl_share of that, and stretched toward
## the core as it goes (its art, on every screen). A held daemon does nothing of its own (its brain is held,
## as chmod 000 holds it, C29): a tell or a strike it was in is called off. Inside the horizon a held thing
## takes damage every tick_s, harder the deeper it is (a chmod-frozen daemon takes none: it reaches the
## core whole); reaching the core (core_m of the axis) discards it:
## one hit of discard_damage, which kills a daemon (a chmod-frozen one shatters, C29's rule: the hit is far
## over shatter_damage) and is ICE's own hit cap for a piece of ICE. When the collapse ends, the implosion:
## everything held within pulse_radius_m takes the pulse's damage for its distance.
##
## What it reaches: daemons (walkers dragged along the floor, the swarm through the air), the hunter (pulled
## and hurt like a daemon, I1), the nodes (anchored: never moved, but hurt), cron mines (C27: torn loose and
## drawn to the core, where each one is set off: one last run there, its own blast, its owner's), and, in a
## match, every other player (the drag on its own screen, at most player_pull_cap so a run gets out; the
## host judges its damage and its discard). A wall of white ICE is never moved: inside the horizon it only
## flickers. Black ICE is never pulled, held or hurt, its seals and touch untouched (I3): it flashes once and
## its tag says "/dev/null: device busy". The thrower is never pulled or hurt by its own hole.
##
## Who decides: an authoritative hole (alone, or the host's in a match) opens on its own and judges; a hole
## on a joiner's screen only draws until the host's word opens it at the host's place (open_at()), then
## drags its own player and draws the rest from the host's word. Daemons are moved and hurt only where this
## screen owns them (moves_daemons): alone, the host's while they fight, and the thrower's own screen in a
## match whose daemons do not (its own idle dummies, as pipe | lands on them, C30).
##
## Cosmetic fiction only: nothing real is opened, written, read or discarded; /dev/null is a name.

signal opened(at: Vector3)
## Something reached the core and was discarded (a daemon, a piece of ICE; players are the host's).
signal discarded(what: Node, at: Vector3)
## The implosion, at the core.
signal collapsed(at: Vector3)
signal finished

const Tuning = preload("res://scripts/weapons/dev_null_tuning.gd")
const Palette = preload("res://scripts/palette.gd")
const GrepLock = preload("res://scripts/weapons/grep_lock.gd")
const CronMineScript = preload("res://scripts/weapons/cron_mine.gd")
const LookScript = preload("res://scripts/weapons/dev_null_look.gd")
const SfxSynth = preload("res://scripts/sfx_synth.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")
## Every hole joins this group: the players' drags and the tests find them.
const GROUP := &"dev_null"
## The node under a scene's root that holds every hole there.
const FIELD := "DevNullHoles"
## The level: what stops the device, blocks the pull and stops what it drags.
const LEVEL_MASK := 1
## A held thing's hold, seconds, renewed each physics frame it is held: it outlasts a frame, never the hole.
const HOLD_S := 0.2
## A thing whose middle is more than this above or below the core is out of the hole's reach.
const REACH_HIGH_M := 3.0
## A device stopped by the level rests this far off the face it met.
const REST_OFF_M := 0.3
## A wall's flicker inside the horizon, at most every this many seconds.
const FLICKER_S := 0.45
## A discard's burst: this share of the HOLE particle pool's.
const DISCARD_BURST := 0.4
## Its tag over the core, written as the command it is, and Black ICE's refusal under it (C29's and C30's style).
const TAG_LINES := "$ cat * > /dev/null\n%d held  %d discarded"
const BUSY_LINE := "/dev/null: device busy"
## A joiner's copy that flew its whole fuse and more without the host's word ends on its own.
const WORD_WAIT_S := 1.5

enum Phase { FLYING, OPENING, HOLDING, COLLAPSING, DONE }

var tuning: Tuning
var seed := 0
## Who threw it (its player id in a match, 0 alone), and its key for the live cap.
var thrower := 0
var thrower_key := ""
## True: opens on its own and judges (alone, or the host's). False: draws the host's.
var authoritative := true
## True where this screen moves and hurts the daemons and ICE it holds (see the head of the file).
var moves_daemons := true
## C22's root at the throw: a wider reach.
var root := false
var reach := 9.0
## What the device stops at (the level) and the bodies it opens on.
var world_mask := LEVEL_MASK
var target_mask := 6
## Never met in flight: the thrower's own body.
var exclude: Array[RID] = []
## judge_daemon(node, damage, point, way) lands damage on a daemon or a piece of ICE (the thrower's side
## gives it: its own hit path alone, the host's for a joiner's hole). judge_players(hole, what) on the host
## judges every player for "tick", "pulse" (its session).
var judge_daemon := Callable()
var judge_players := Callable()
var body_color := Palette.DEV_NULL
var light_color := Palette.DEV_NULL_TEXT

var phase := Phase.FLYING
## Seconds since it was thrown, and since it opened.
var age := 0.0
var open_age := 0.0
## The core, world space (INF until it opens).
var core := Vector3.INF
## The counts, for the readout and the checks.
var caught_count := 0
var discards := 0
var ticks := 0
var pulses := 0
var mines_set_off := 0
var walls_flickered := 0
var black_refused := false
## What it holds now: node -> {"discarded": bool}.
var held := {}
## Players the host has discarded with it (their ids), so each goes once.
var players_discarded := {}

var _pos := Vector3.ZERO
var _vel := Vector3.ZERO
var _stopped := false
var _tick_left := 0.0
var _flicker := {}
var _look: Node3D
var _hum: AudioStreamPlayer3D
var _boom: AudioStreamPlayer3D
static var _sounds := {}


## A throw under `root_node` (the arena) from `origin` at `velocity` (world space).
static func spawn(root_node: Node, with_tuning: Tuning, origin: Vector3, velocity: Vector3, throw_seed: int, key: String, deciding: bool, thrower_id: int, root_on: bool, skin: String, never: Array[RID] = [], judged_daemon: Callable = Callable(), judged_players: Callable = Callable(), moves: bool = true) -> Node3D:
	var hole = load("res://scripts/weapons/dev_null_hole.gd").new()
	hole.name = "DevNull"
	hole.tuning = with_tuning
	hole.seed = throw_seed
	hole.thrower_key = key
	hole.thrower = thrower_id
	hole.authoritative = deciding
	hole.root = root_on
	hole.reach = with_tuning.reach_for(root_on)
	hole.exclude = never
	hole.judge_daemon = judged_daemon
	hole.judge_players = judged_players
	hole.moves_daemons = moves
	hole.body_color = Palette.skin_body(skin)
	hole.light_color = Palette.skin_beam(skin)
	hole._pos = origin
	hole._vel = velocity
	field_of(root_node).add_child(hole)
	hole.global_position = origin
	return hole


## The node under `root_node` that holds its holes, made on first use.
static func field_of(root_node: Node) -> Node3D:
	var field := root_node.get_node_or_null(FIELD) as Node3D
	if field == null:
		field = Node3D.new()
		field.name = FIELD
		root_node.add_child(field)
	return field


## Holes `key` has live (thrown and not yet closed) under `root_node`.
static func live_of(root_node: Node, key: String) -> int:
	var field := root_node.get_node_or_null(FIELD)
	if field == null:
		return 0
	var n := 0
	for hole in field.get_children():
		if hole is DevNullHole and hole.thrower_key == key and hole.phase != Phase.DONE:
			n += 1
	return n


## The device's velocity for a throw along `aim`: the throw speed along it, and lift.
static func throw_velocity(with_tuning: Tuning, aim: Vector3) -> Vector3:
	return aim.normalized() * with_tuning.throw_speed + Vector3.UP * with_tuning.throw_lift


## The drag on a player at `middle` (world space) from every open hole under `root_node` not thrown by
## `me`: metres a second, level (a player is dragged over the floor, never lifted), each hole's at most the
## tuning's player_pull_cap and only in its sight. ZERO when none holds it.
static func drag_on(root_node: Node, middle: Vector3, me: int, space: PhysicsDirectSpaceState3D) -> Vector3:
	var field := root_node.get_node_or_null(FIELD) if root_node != null else null
	if field == null:
		return Vector3.ZERO
	var total := Vector3.ZERO
	for hole in field.get_children():
		if hole is DevNullHole and hole.thrower != me:
			total += hole.player_drag(middle, space)
	return total


func _ready() -> void:
	add_to_group(GROUP)
	_look = LookScript.new()
	_look.name = "Look"
	add_child(_look)
	_look.setup(tuning, body_color, light_color, reach)
	_hum = _player_3d(_sound("hum"), -6.0)
	_boom = _player_3d(_sound("boom"), 0.0)
	var fx := ParticleFx.of(self)
	if fx != null:
		fx.follow(_look.device(), light_color)


func _player_3d(stream: AudioStream, db: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = db
	p.unit_size = 8.0
	p.bus = SettingsApply.EFFECTS
	add_child(p)
	return p


## Its sounds, made once and kept (the I3 note: synthesis at a throw would hitch).
static func _sound(which: String) -> AudioStream:
	if not _sounds.has(which):
		_sounds[which] = SfxSynth.void_hum() if which == "hum" else SfxSynth.void_implosion()
	return _sounds[which]


## True while it holds and pulls: opened and not yet imploded.
func is_open() -> bool:
	return phase == Phase.OPENING or phase == Phase.HOLDING or phase == Phase.COLLAPSING


## How much of its size it has now, 0 to 1: growing as it opens, shrinking into the implosion.
func size_now() -> float:
	match phase:
		Phase.OPENING:
			return clampf(open_age / tuning.open_s, 0.0, 1.0)
		Phase.HOLDING:
			return 1.0
		Phase.COLLAPSING:
			return clampf(1.0 - (open_age - tuning.open_s - tuning.hold_s) / tuning.collapse_s, 0.0, 1.0)
	return 0.0


## Its tag over the core, the command it is (C31): what it holds and has discarded, and Black ICE's refusal.
func tag_text() -> String:
	var text := TAG_LINES % [held_now(), discards]
	return text + ("\n" + BUSY_LINE if black_refused else "")


## Things it holds now (not yet discarded).
func held_now() -> int:
	var n := 0
	for node in held:
		if is_instance_valid(node) and not held[node]["discarded"]:
			n += 1
	return n


func _physics_process(delta: float) -> void:
	if phase == Phase.DONE:
		return
	age += delta
	if phase == Phase.FLYING:
		_fly(delta)
		return
	open_age += delta
	if phase == Phase.OPENING and open_age >= tuning.open_s:
		phase = Phase.HOLDING
	if phase == Phase.HOLDING and open_age >= tuning.open_s + tuning.hold_s:
		phase = Phase.COLLAPSING
	_hold_everything(delta)
	if phase == Phase.COLLAPSING and open_age >= tuning.life_s():
		_implode()


func _process(_delta: float) -> void:
	if _look != null and phase != Phase.DONE:
		_look.show_state(phase, size_now(), open_age, _pos if phase == Phase.FLYING else core)
		if is_open():
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
			_open(_core_over(hit["position"], normal))
		return
	_pos = to
	if age >= tuning.fuse_s:
		_stopped = true
		if authoritative:
			_open(_pos)  # the fuse ran out in the air: it opens where it is


## The core over a device that met the level at `at` on a face with `normal`: core_height_m up from a
## floor (never into the level above it), or REST_OFF_M out from a wall or a ceiling.
func _core_over(at: Vector3, normal: Vector3) -> Vector3:
	if normal.y < 0.7:
		return at + normal * REST_OFF_M
	var up := at + Vector3.UP * tuning.core_height_m
	var ceiling := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.05, up, LEVEL_MASK))
	return up if ceiling.is_empty() else (ceiling["position"] as Vector3) - Vector3.UP * REST_OFF_M


## The host's word: it opened at `at` (world space), on a hole that only draws.
func open_at(at: Vector3) -> void:
	if authoritative or phase != Phase.FLYING or not at.is_finite():
		return
	_pos = at
	_open(at)


## A discard the host judged (a player reaching the core), or the host's word of one on a joiner's screen:
## counted, a burst of debris drawn into the core, and the signal (the thrower's callout).
func told_discard(at: Vector3) -> void:
	discards += 1
	_burst(at)
	discarded.emit(null, at)


## The host's word: it collapsed, on a hole that only draws: the implosion now, whatever this clock says.
func collapse_now() -> void:
	if authoritative or not is_open():
		return
	_implode()


func _open(at: Vector3) -> void:
	core = at
	phase = Phase.OPENING
	open_age = 0.0
	_tick_left = tuning.tick_s
	_hum.play()
	opened.emit(at)


# --- The hole. ---

func _hold_everything(delta: float) -> void:
	var root_node := get_parent().get_parent() if get_parent() != null else null
	if root_node == null:
		return
	var space := get_world_3d().direct_space_state
	_tick_left -= delta
	var tick := _tick_left <= 0.0
	if tick:
		_tick_left += tuning.tick_s
		if authoritative:
			ticks += 1
	var seen := {}
	for body in get_tree().get_nodes_in_group(GrepLock.TARGET_GROUP):
		if body is Node3D and not (body is IcePiece) and root_node.is_ancestor_of(body):
			seen[body] = true
			_hold(body, false, delta, tick, space)
	var ice := IceDirector.of(root_node)
	if ice != null:
		for piece in ice.pieces():
			if not is_instance_valid(piece) or not root_node.is_ancestor_of(piece):
				continue
			seen[piece] = true
			if piece is BlackIce:
				_refuse(piece)
			elif piece is IceBarrier:
				_flicker_wall(piece, delta)
			elif piece is HunterIce:
				_hold(piece, false, delta, tick, space)
			elif piece is IceNode:
				_hold(piece, true, delta, tick, space)
	for node in held.keys():
		if not seen.has(node):
			_let_go(node)
	_pull_mines(root_node, delta, space)
	if tick and authoritative and judge_players.is_valid():
		judge_players.call(self, "tick")


## `body` (a daemon or a piece of ICE; `anchored` for a node) for one physics step: held, dragged,
## stretched, hurt inside the horizon and discarded at the core, or let go when out of reach or sight.
func _hold(body: Node3D, anchored: bool, delta: float, tick: bool, space: PhysicsDirectSpaceState3D) -> void:
	if not GrepLock.alive(body):
		_let_go(body)
		return
	var middle := GrepLock.point_of(body)
	var flat := Vector2(middle.x - core.x, middle.z - core.z)
	var distance := flat.length()
	if distance > reach or absf(middle.y - core.y) > REACH_HIGH_M or not _in_sight(middle, space):
		_let_go(body)
		return
	if not held.has(body):
		_catch(body, anchored)
	var mine: bool = moves_daemons and not _follows(body)
	if not anchored:
		if body.has_method("hold_in_hole"):
			body.hold_in_hole(HOLD_S)
		_stretch(body, middle, distance)
		if mine:
			_drag(body, middle, distance, delta, space)
		var trail = held[body].get("trail")
		if trail != null and is_instance_valid(trail):
			trail.global_position = GrepLock.point_of(body)
	if not mine or held[body]["discarded"]:
		return
	var way := (core - middle).normalized() if middle.distance_to(core) > 0.001 else Vector3.DOWN
	if distance <= tuning.core_m:
		held[body]["discarded"] = true
		if judge_daemon.is_valid():
			judge_daemon.call(body, tuning.discard_damage, middle, way)
		discards += 1
		_burst(core)
		discarded.emit(body, core)
		return
	# chmod 000's frozen (C29) takes nothing on the way in: it reaches the core whole, and shatters there.
	var frozen: bool = body.has_method("chmod_frozen") and body.chmod_frozen()
	if tick and distance < tuning.horizon_m and not frozen and judge_daemon.is_valid():
		# Quietly: no flash, no recoil each tick (the pull is its look); the discard and the pulse flare as hits do.
		body.set("quiet", true)
		judge_daemon.call(body, tuning.dps_at(distance) * tuning.tick_s, middle, way)
		if is_instance_valid(body):
			body.set("quiet", false)


## `body` caught (once each time it comes into reach): counted, and a dragged one given a trail of sparks in
## the hole's light, behind it as it is drawn in (a marker riding its middle that a ParticleFx trail follows,
## when the pool has one free); an anchored node has none.
func _catch(body: Node3D, anchored: bool) -> void:
	var entry := {"discarded": false, "trail": null}
	caught_count += 1
	if not anchored:
		var fx := ParticleFx.of(self)
		if fx != null:
			var marker := Node3D.new()
			marker.name = "Trail"
			add_child(marker)
			marker.global_position = GrepLock.point_of(body)
			if fx.follow(marker, light_color):
				entry["trail"] = marker
			else:
				marker.queue_free()
	held[body] = entry


## The drag on `body` this step: toward the core's axis and swirled round it; walkers kept on their floor,
## the swarm and the hunter drawn to the core's height too, but never down out of the core's sight (behind
## a low wall: they come in over it); never into the level.
func _drag(body: Node3D, middle: Vector3, distance: float, delta: float, space: PhysicsDirectSpaceState3D) -> void:
	var speed := tuning.pull_at(distance, reach, open_age) * (1.0 + 1.5 * (1.0 - size_now()) * float(phase == Phase.COLLAPSING))
	var inward := Vector3(core.x - middle.x, 0.0, core.z - middle.z)
	inward = inward.normalized() if inward.length() > 0.0001 else Vector3.ZERO
	var step := minf(speed * delta, distance)
	var motion := inward * step + Vector3.UP.cross(inward) * speed * tuning.swirl_share * delta
	if _flies(body):
		motion.y = clampf(core.y - middle.y, -speed * delta, speed * delta)
		if not _in_sight(middle + motion, space):
			motion.y = 0.0  # never drawn down behind cover out of the core's sight: it comes in over it
	if not _clear(middle, middle + motion, space):
		motion = inward * step
		if not _clear(middle, middle + motion, space):
			return
	body.global_position += motion


## Its art drawn out toward the core, more the deeper it is (every screen draws its own).
func _stretch(body: Node3D, middle: Vector3, distance: float) -> void:
	var art = body.call("art_node") if body.has_method("art_node") else body.get("art")
	if art == null or not is_instance_valid(art) or not art.has_method("stretch_toward"):
		return
	var depth := clampf(1.0 - distance / reach, 0.0, 1.0) * size_now()
	art.stretch_toward(core - middle, depth)


func _let_go(node: Node) -> void:
	if not held.has(node):
		return
	var trail = held[node].get("trail")
	if trail != null and is_instance_valid(trail):
		trail.queue_free()  # its spark trail lets go with it
	held.erase(node)
	if is_instance_valid(node):
		var art = node.call("art_node") if node.has_method("art_node") else node.get("art")
		if art != null and is_instance_valid(art) and art.has_method("stretch_toward"):
			art.stretch_toward(Vector3.ZERO, 0.0)


## Black ICE (I3): never pulled, held or hurt; it flashes once, and the readout says so.
func _refuse(piece: Node3D) -> void:
	if black_refused or not piece.has_method("present_now") or not piece.present_now():
		return
	var at: Vector3 = (piece as IcePiece).aim_point()
	if Vector2(at.x - core.x, at.z - core.z).length() > reach:
		return
	black_refused = true
	if piece.get("art") != null and piece.art.has_method("flash"):
		piece.art.flash()


## A wall of white ICE inside the horizon only flickers: never moved, never hurt.
func _flicker_wall(piece: Node3D, delta: float) -> void:
	var at: Vector3 = (piece as IcePiece).aim_point()
	if piece.get("broken") == true or Vector2(at.x - core.x, at.z - core.z).length() > tuning.horizon_m + 2.0:
		return
	_flicker[piece] = _flicker.get(piece, 0.0) - delta
	if _flicker[piece] > 0.0:
		return
	_flicker[piece] = FLICKER_S
	walls_flickered += 1
	if piece.get("art") != null and piece.art.has_method("flash"):
		piece.art.flash()


## Cron mines (C27) in its reach: torn loose and drawn to the core; one there is set off (its last run,
## its own blast, its owner's) where the mine decides, and only drawn here on a joiner's screen.
func _pull_mines(root_node: Node, delta: float, space: PhysicsDirectSpaceState3D) -> void:
	var field := root_node.get_node_or_null(CronMineScript.FIELD)
	if field == null:
		return
	for mine in field.get_children():
		if mine.get_script() != CronMineScript or not mine.running():
			continue
		var at: Vector3 = mine.global_position
		var flat := Vector2(at.x - core.x, at.z - core.z).length()
		if flat > reach or absf(at.y - core.y) > REACH_HIGH_M or not _in_sight(at, space):
			continue
		var to_core := core - at
		if to_core.length() <= tuning.core_m:
			if mine.authoritative:
				mine.set_off()
				mines_set_off += 1
			continue
		var speed := tuning.pull_at(flat, reach, open_age)
		mine.global_position = at + to_core.normalized() * minf(speed * delta, to_core.length())


## This hole's drag on a player whose middle is at `middle`: ZERO unless open, in reach and in sight.
func player_drag(middle: Vector3, space: PhysicsDirectSpaceState3D) -> Vector3:
	if not is_open() or not core.is_finite():
		return Vector3.ZERO
	var inward := Vector3(core.x - middle.x, 0.0, core.z - middle.z)
	var distance := inward.length()
	if distance > reach or absf(middle.y - core.y) > REACH_HIGH_M or distance < 0.001 or not _in_sight(middle, space):
		return Vector3.ZERO
	var speed := minf(tuning.pull_at(distance, reach, open_age), tuning.player_pull_cap)
	var way := inward / distance
	return way * speed + Vector3.UP.cross(way) * speed * tuning.swirl_share * 0.5


## How this hole reaches a player whose middle is at `middle` (the host's judge): {distance, in} with
## `in` true when it is held (in reach, in sight).
func reaches(middle: Vector3, space: PhysicsDirectSpaceState3D) -> Dictionary:
	var distance := Vector2(middle.x - core.x, middle.z - core.z).length()
	var ok := is_open() and distance <= reach and absf(middle.y - core.y) <= REACH_HIGH_M and _in_sight(middle, space)
	return {"distance": distance, "in": ok}


## The implosion: the pulse's damage on everything still held within its radius, the end of every hold,
## the boom and the burst; then it is done.
func _implode() -> void:
	if phase == Phase.DONE:
		return
	if authoritative or moves_daemons:
		pulses += 1
	for node in held.keys():
		if not is_instance_valid(node) or held[node]["discarded"] or not GrepLock.alive(node):
			continue
		var middle := GrepLock.point_of(node)
		var distance := middle.distance_to(core)
		if moves_daemons and not _follows(node) and distance <= tuning.pulse_radius_m and judge_daemon.is_valid():
			judge_daemon.call(node, tuning.pulse_at(distance), middle, (core - middle).normalized())
	if authoritative and judge_players.is_valid():
		judge_players.call(self, "pulse")
	for node in held.keys():
		_let_go(node)
	_hum.stop()
	_boom.play()
	_look.implode(core)
	collapsed.emit(core)
	_close()


func _close() -> void:
	if phase == Phase.DONE:
		return
	phase = Phase.DONE
	finished.emit()
	# The boom plays out on its own; the hole goes once it has.
	var wait := _boom.stream.get_length() if _boom.playing and _boom.stream != null else 0.0
	if wait > 0.0 and is_inside_tree():
		get_tree().create_timer(wait).timeout.connect(queue_free)
	else:
		queue_free()


# --- Helpers. ---

## A discard's burst: a share of the HOLE particles drawn into the core.
func _burst(at: Vector3) -> void:
	var fx := ParticleFx.of(self)
	if fx != null:
		fx.hole(at, DISCARD_BURST)


func _in_sight(middle: Vector3, space: PhysicsDirectSpaceState3D) -> bool:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(core, middle, LEVEL_MASK)).is_empty()


func _clear(from: Vector3, to: Vector3, space: PhysicsDirectSpaceState3D) -> bool:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, LEVEL_MASK)).is_empty()


## True for a joiner's copy of the host's daemon (C27b): it plays the host's word, never this screen's.
func _follows(body: Node) -> bool:
	return body.has_method("_follows") and body.call("_follows") == true or body is IcePiece and (body as IcePiece).director != null and not (body as IcePiece).director.decides()


## The swarm and the hunter fly: drawn to the core's height too; walkers stay on their floor.
func _flies(body: Node) -> bool:
	if body is HunterIce:
		return true
	var brain = body.get("brain")
	return brain != null and brain.get("kind") == "swarm"
