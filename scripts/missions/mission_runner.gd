class_name MissionRunner
extends Node
## Plays one mission in the arena (C35, PRD 5.6): the arena's own node beside the daemons' director, made by main.gd.
## What a mission does is its data (scripts/missions/mission_def.gd); this runs any of them the same way.
##
## A mission starts as the arena loads: the Missions menu (or a retry, or the next mission) queues it and reloads the
## arena (queue(), then the scene reloaded: a fresh floor, fresh daemons, a full life), and main.gd begins what was
## queued. While it runs it stays queued, so R (respawn: the arena reloaded) restarts it as a new try. Its flow:
##   INTRO     its card for INTRO_S; its "start" lines and transitions fire
##   RUNNING   its objectives one after another (kill, reach, log, survive), its logs standing to be picked up; its
##             clock runs only while the player is playing (the mouse taken, no menu or box open), as the round clock
##   FAILED    the player derezzed (or flatlined), or its own time ran out; retry() starts it again
##   COMPLETE  every objective done: recorded (scripts/missions/mission_progress.gd: done, the best, its weapons
##             handed out for keeps), the player shielded; next_mission(), to_missions() or free_play() after it
## While it runs the round clock holds (no break, no coaching call), ICE stands down unless the mission has it, and
## the player carries only the mission's loadout, growing as objectives hand weapons over. While its clock is held
## (the Esc menu up, the mouse let go) the player is shielded, so nothing fails a mission behind its own menu.
##
## Alone only (STORY.md, pick 9): begin() refuses in a match, and a match starting mid-mission ends it where it stands.
## Esc and the window's close always work: the Esc menu (scripts/hud/pause_menu.gd) offers resume, restart and quit.
## In ruins (C36): a mission that names a district (MissionDef.ruins) is played with the arena stood in it (scripts/
## ruins/ruins_stage.gd, as the arena loads); begun on an arena that is not, it is queued and the arena reloaded into
## them. There its places may be the district's points by name (place()), and its register shifts change the world
## itself (the ruins' set_register()), not just the HUD.
## Its own daemons and set pieces (C37): a mission with waves or props gets a stage (scripts/missions/mission_stage.gd)
## as it begins; with waves, the arena's own four are taken away first, so every daemon in it is one of its own (each
## told as daemon_spawned, its kills counted as any); the stage's waves add the triggers "wave:<id>" and
## "cleared:<id>", and every trigger reaches the stage (its waves, its breach). The weapons and abilities it has not
## handed over (C37): the player carries only its loadout and what it hands over, and may use only the abilities this
## mission and those before it hand over (MissionDef.allowed_abilities(): SIGSTOP, code-rain vision, sudo; the
## ICEbreakers locked at their director); the HUD shows the rest locked. All of it lifted when it ends where it stands.
## Story lines leave here as line_said() for the HUD (scripts/hud/mission_hud.gd): your AI's to the guide panel, the
## Auditor's and `~`'s to the mission's terminal. Nothing here calls an AI, reads the player's machine or writes a
## file of its own (the one save is MissionProgress's).

signal began(def: MissionDef)
signal objective_began(index: int)
signal objective_done(index: int)
signal progressed(index: int)
signal line_said(who: String, text: String)
signal log_found(entry: Dictionary)
signal handed(weapon: String)
signal register_shifted(from: String, to: String)
signal failed(reason: String)
signal completed(result: Dictionary)
## Ended where it stood: a match starting, or end_here().
signal ended
## One of its own daemons climbed out of a vent (C37): scripts/main.gd counts its kills as the arena's.
signal daemon_spawned(dummy: Node3D)

enum State { IDLE, INTRO, RUNNING, FAILED, COMPLETE }

const GROUP := "mission_runner"
const NODE_NAME := "MissionRunner"
## Seconds of the mission's card before its first objective.
const INTRO_S := 2.6
## How near a terminal log the player walks to pick it up, metres (from the player's middle).
const PICKUP_M := 1.4
## How high above a reach point the player may stand and still be there, metres.
const REACH_HEIGHT_M := 2.5
## Seconds the player is kept from harm once a mission is done, while its screen is up.
const SHIELD_S := 600.0
## Seconds of harm kept off, renewed every frame, while the mission's clock is held.
const HELD_SHIELD_S := 0.5
## Why it failed, in the end screen's words.
const DEREZZED := "derezzed by %s"
const DEREZZED_PLAIN := "derezzed"
const FLATLINED := "flatlined by %s"
const TIMED_OUT := "the timeslice ran out"
## What follows a reload, for main.gd.
const AFTER_MISSIONS := "missions"

## The mission to begin as the arena next loads ("" none), and its try; what to open after a reload without one.
static var _pending := ""
static var _pending_try := 1
static var _after := ""
## The mission the arena was last reloaded to stand in its ruins for: never reloaded for twice running.
static var _staging := ""
## True from a reload of its own until the next arena's HUD takes it (C36): that arena comes in from black.
static var _fade_in := false

## Set by main.gd: the player, its life alone, the daemons' director, ICE, the round HUD, the session (null alone).
var player: Node3D = null
var life: SoloLife = null
var daemons: DaemonDirector = null
var ice: IceDirector = null
var rounds: Node = null
var session: Node = null
## The ruins the arena stands in (C36, set by main.gd), or null on the arena itself.
var world: RuinsWorld = null
## The ICEbreakers' director (C37, set by main.gd): locked while a mission has not handed them over.
var breakers: Node = null
## The running mission's own daemons and set pieces (C37), or null.
var stage: MissionStage = null

var def: MissionDef = null
var state: State = State.IDLE
## The objective running (its index in the data), and how far along it is: kills, or seconds survived.
var index := -1
var progress := 0.0
## Seconds of play since the first objective, and of the card.
var clock := 0.0
var intro_left := 0.0
## This mission's try: 1, then 2 after a retry...
var attempt := 1
var kills := 0
## The logs picked up, by id, in order.
var logs_found := PackedStringArray()
## The register the place is in now.
var register := "tron"
## What the player may carry now (the loadout and what objectives handed over).
var carried := PackedStringArray()
## The end: {"seconds", "kills", "logs", "logs_total", "attempt", "first", "best", "best_s", "granted", "reason"}.
var result := {}
## Why it failed, in words ("" while it has not).
var reason := ""

var _fired := {}
## Its "at:<seconds>" triggers, [trigger, seconds], found once as it begins.
var _timed: Array = []
var _pickups := {}
var _beacon: MissionBeacon = null
var _targets: Array = []


func _init() -> void:
	name = NODE_NAME


func _ready() -> void:
	add_to_group(GROUP)


## The runner of the arena `node` is in, or null.
static func of(node: Node) -> MissionRunner:
	if node == null or not node.is_inside_tree():
		return null
	for r in node.get_tree().get_nodes_in_group(GROUP):
		var host := (r as Node).get_parent()
		if host != null and (host == node or host.is_ancestor_of(node)):
			return r
	return null


# --- Between arenas: what the next load begins. ---

## Mission `id` to begin as the arena next loads, as try `try`.
static func queue(id: String, try: int = 1) -> void:
	_pending = id
	_pending_try = maxi(try, 1)
	_after = ""


## [id, try] of the mission queued (["", 1] for none), cleared.
static func take_pending() -> Array:
	var out := [_pending, _pending_try]
	_pending = ""
	_pending_try = 1
	return out


static func pending() -> String:
	return _pending


## What to open after this load ("missions": the Missions screen), cleared.
static func take_after() -> String:
	var out := _after
	_after = ""
	return out


## The next arena comes in from black (C36): a reload into a mission from elsewhere (the Missions screen, R mid-mission).
static func mark_fade() -> void:
	_fade_in = true


## True once after a reload of the runner's own (start, retry, next, back to the Missions screen or to the arena),
## for the next arena's HUD to come in from black instead of blinking.
static func take_fade() -> bool:
	var out := _fade_in
	_fade_in = false
	return out


## Nothing queued, nothing to open (tests).
static func clear_pending() -> void:
	_pending = ""
	_pending_try = 1
	_after = ""


# --- One mission. ---

## Begins mission `d` here, as try `try`. False, and nothing changes, in a match, for a mission that cannot be played
## yet (unless `force`, the tests' own), or while one runs.
func begin(d: MissionDef, try: int = 1, force: bool = false) -> bool:
	if d == null or _online() or (not d.playable and not force) or running():
		return false
	if d.ruins != "" and not _in_ruins(d.ruins):
		# Its district first: queued, and the arena reloaded to stand in it (once: a set that cannot be stood in is refused).
		if _staging == d.id or RuinsBook.of(d.ruins) == null:
			_staging = ""
			return false
		_staging = d.id
		queue(d.id, try)
		_reload()
		return true
	_staging = ""
	def = d
	state = State.INTRO
	index = -1
	progress = 0.0
	clock = 0.0
	intro_left = INTRO_S
	attempt = maxi(try, 1)
	kills = 0
	logs_found = PackedStringArray()
	register = d.register
	reason = ""
	result = {}
	_fired = {}
	_timed = []
	for on in _triggers_of(d):
		if on.begins_with("at:"):
			_timed.append([on, float(on.trim_prefix("at:"))])
	# Still queued while it runs: R reloads the arena into its next try.
	_pending = d.id
	_pending_try = attempt + 1
	if rounds != null and is_instance_valid(rounds) and rounds.has_method("hold"):
		rounds.hold(true)
	if ice != null and is_instance_valid(ice):
		ice.stand_down = not d.ice
	carried = d.loadout.duplicate()
	_carry()
	_gate(true)
	if not d.waves.is_empty():
		_retire_arena_daemons()
	_targets = get_tree().get_nodes_in_group("targets")
	for dummy in _targets:
		if dummy.has_signal("downed") and not dummy.downed.is_connected(_on_downed):
			dummy.downed.connect(_on_downed)
	if life != null and is_instance_valid(life):
		if not life.died.is_connected(_on_died):
			life.died.connect(_on_died)
		if not life.flatlined.is_connected(_on_flatlined):
			life.flatlined.connect(_on_flatlined)
	if world != null and is_instance_valid(world):
		world.set_register(d.register, 0.0)
	for entry in d.logs:
		var pickup := MissionLogPickup.new()
		pickup.entry = entry
		add_child(pickup)
		pickup.global_position = place(entry["at"])
		_pickups[entry["id"]] = pickup
	if not d.waves.is_empty() or not d.props.is_empty():
		_make_stage(d)
	began.emit(d)
	_fire("start")
	return true


## Every trigger `d` names: its lines', its transitions', its waves' and its breach's (C37).
static func _triggers_of(d: MissionDef) -> PackedStringArray:
	var out := PackedStringArray()
	for item in d.lines + d.transitions + d.waves:
		var on := str(item.get("on", ""))
		if on != "" and not out.has(on):
			out.append(on)
	for p in d.props:
		for key in ["opens", "lights"]:
			var on := str(p.get(key, ""))
			if on != "" and not out.has(on):
				out.append(on)
	return out


## The arena's own daemons go (C37): a mission with waves has only its own. Out of the tree at once, then freed.
func _retire_arena_daemons() -> void:
	var host := get_parent()
	for dummy in get_tree().get_nodes_in_group("targets"):
		if host != null and host.is_ancestor_of(dummy) and (stage == null or not stage.made.has(dummy)):
			dummy.remove_from_group("targets")
			dummy.get_parent().remove_child(dummy)
			dummy.queue_free()


## Its stage (C37): its vents and walls up, its waves waiting for their triggers.
func _make_stage(d: MissionDef) -> void:
	stage = MissionStage.new()
	stage.place = place
	stage.world = world
	stage.player = player
	var host := get_parent()
	stage.targets = host.get_node_or_null("Arena/Targets") as Node3D if host != null else null
	if stage.targets == null:
		stage.targets = stage
	add_child(stage)
	stage.build(d)
	stage.spawned.connect(_on_spawned)
	stage.wave_began.connect(func(id: String) -> void: _fire("wave:" + id))
	stage.wave_cleared.connect(func(id: String) -> void: _fire("cleared:" + id))


func _on_spawned(dummy: Node3D) -> void:
	if dummy.has_signal("downed") and not dummy.downed.is_connected(_on_downed):
		dummy.downed.connect(_on_downed)
	daemon_spawned.emit(dummy)


## The weapons' and abilities' gate (C37): on, the mission's allowed abilities only and the ICEbreakers locked unless
## handed over; off, everything back.
func _gate(on: bool) -> void:
	var allowed := def.allowed_abilities() if on and def != null else PackedStringArray()
	if player != null and is_instance_valid(player) and player.has_method("set_abilities"):
		player.set_abilities(allowed, on)
	if breakers != null and is_instance_valid(breakers):
		breakers.set("locked", on and not allowed.has("breakers"))


## True when the arena stands in ruins `id`.
func _in_ruins(id: String) -> bool:
	return world != null and is_instance_valid(world) and world.ruins != null and world.ruins.id == id


## Where `at` is: a place as it is, or in ruins one of their points by name; Vector3.INF for neither.
func place(at: Variant) -> Vector3:
	if at is Vector3:
		return at
	if at is String and world != null and is_instance_valid(world):
		return world.point(at)
	return Vector3.INF


## Where log `log_id` stands (its pickup's place), or Vector3.INF.
func log_place(log_id: String) -> Vector3:
	return place(def.log_of(log_id).get("at")) if def != null else Vector3.INF


## Where objective `i`'s reach point is, or Vector3.INF.
func reach_place(i: int) -> Vector3:
	if def == null or i < 0 or i >= def.objectives.size():
		return Vector3.INF
	return place(def.objectives[i].get("at"))


## True from begin() until it fails, is done or ends.
func running() -> bool:
	return state == State.INTRO or state == State.RUNNING


## The objective running now, or {}.
func objective() -> Dictionary:
	if def == null or index < 0 or index >= def.objectives.size():
		return {}
	return def.objectives[index]


## How much the running objective needs: its count, its seconds, or 1.
func need() -> float:
	var o := objective()
	match o.get("kind"):
		"kill":
			return float(o["count"])
		"survive":
			return float(o["seconds"])
	return 1.0


## Where the running objective points, for the HUD's marker: a reach point, or its log while it still stands, or INF.
func target_point() -> Vector3:
	var o := objective()
	if o.get("kind") == "reach":
		return place(o["at"])
	if o.get("kind") == "log" and _pickups.has(o["log"]) and is_instance_valid(_pickups[o["log"]]):
		return (_pickups[o["log"]] as Node3D).global_position
	return Vector3.INF


## The beacon of the reach objective running, or null.
func beacon() -> MissionBeacon:
	return _beacon if _beacon != null and is_instance_valid(_beacon) else null


## The terminal log `log_id` still standing to be picked up, or null.
func pickup(log_id: String) -> MissionLogPickup:
	var p = _pickups.get(log_id)
	return p if p != null and is_instance_valid(p) and not p.taken else null


## True while the mission's clock runs: the player playing, as the round clock counts it.
func engaged() -> bool:
	if player == null or not is_instance_valid(player) or player.get("input_blocked") == true:
		return false
	return player.get("assume_captured") == true or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if not running():
		return
	if _online():
		end_here()
		return
	if state == State.INTRO:
		intro_left -= delta
		if intro_left <= 0.0:
			state = State.RUNNING
			_next_objective()
		return
	if not engaged():
		# Its clock held (the Esc menu, a box, the mouse let go): nothing can fail it behind its own menu.
		if life != null and is_instance_valid(life):
			life.shield(HELD_SHIELD_S)
		return
	clock += delta
	for at in _timed:
		if not _fired.has(at[0]) and clock >= at[1]:
			_fire(at[0])
	if not running():
		return
	if def.fail_time_s > 0.0 and clock >= def.fail_time_s:
		_fail(TIMED_OUT)
		return
	_pick_up_logs()
	if not running():
		return
	var o := objective()
	match o.get("kind"):
		"survive":
			if life == null or not is_instance_valid(life) or life.alive():
				progress = minf(progress + delta, need())
				progressed.emit(index)
				if progress >= need():
					_objective_done()
		"reach":
			var at := place(o["at"])
			var radius: float = float(o.get("radius", MissionDef.REACH_RADIUS))
			var here := player.global_position
			if Vector2(here.x - at.x, here.z - at.z).length() <= radius and absf(here.y - at.y) <= REACH_HEIGHT_M:
				progress = 1.0
				_objective_done()
		"log":
			if logs_found.has(str(o["log"])):
				progress = 1.0
				_objective_done()


func _pick_up_logs() -> void:
	if player == null or not is_instance_valid(player):
		return
	if player.get("alive") == false:
		return
	for log_id in _pickups:
		var p = _pickups[log_id]  # untyped: one picked up frees itself as it folds away
		if p == null or not is_instance_valid(p) or p.taken:
			continue
		if player.global_position.distance_to(p.global_position) <= PICKUP_M:
			p.take()
			logs_found.append(log_id)
			log_found.emit(def.log_of(log_id))
			_fire("log:" + log_id)
			if not running():
				return


func _next_objective() -> void:
	index += 1
	progress = 0.0
	if _beacon != null and is_instance_valid(_beacon):
		_beacon.queue_free()
	_beacon = null
	if index >= def.objectives.size():
		_complete()
		return
	var o := objective()
	if o.get("kind") == "reach":
		_beacon = MissionBeacon.new()
		_beacon.label = str(o.get("label", ""))
		_beacon.radius = float(o.get("radius", MissionDef.REACH_RADIUS))
		add_child(_beacon)
		_beacon.global_position = place(o["at"])
	objective_began.emit(index)
	_fire("begin:" + str(o["id"]))


func _objective_done() -> void:
	var o := objective()
	for w in o.get("gives", []):
		if not carried.has(w):
			carried.append(w)
			handed.emit(w)
	_carry()
	objective_done.emit(index)
	_fire("done:" + str(o["id"]))
	if running():
		_next_objective()


func _on_downed(dummy: Node3D) -> void:
	if state != State.RUNNING or dummy.get("credited") == false:
		return
	kills += 1
	var o := objective()
	if o.get("kind") != "kill":
		return
	var want: String = o["daemon"]
	if want != "any" and want != kind_of(dummy):
		return
	var of: Array = o.get("of", [])
	if not of.is_empty() and not of.has(str(dummy.get_meta(&"wave", ""))):
		return  # not one of the waves it counts (C37)
	progress = minf(progress + 1.0, need())
	progressed.emit(index)
	if progress >= need():
		_objective_done()


## A daemon's type as the objectives name it: "rogue", "zombie" or "swarm" (its art's).
static func kind_of(dummy: Node) -> String:
	var art = dummy.art_node() if dummy.has_method("art_node") else null
	return String(art.ai_kind) if art != null else "rogue"


func _on_died(cause: String) -> void:
	if running():
		_fail(DEREZZED % cause if cause != "" else DEREZZED_PLAIN)


func _on_flatlined(cause: String) -> void:
	if running():
		_fail(FLATLINED % (cause if cause != "" else "Black ICE"))


func _fail(why: String) -> void:
	state = State.FAILED
	if stage != null and is_instance_valid(stage):
		stage.stop()
	reason = why
	result = {"seconds": clock, "kills": kills, "logs": logs_found.size(), "logs_total": def.logs.size(), "attempt": attempt, "reason": why}
	_clear_world()
	_fire("fail")
	failed.emit(why)


func _complete() -> void:
	state = State.COMPLETE
	if stage != null and is_instance_valid(stage):
		stage.stop()
	_pending = ""
	_pending_try = 1
	var kept := MissionProgress.current().record(def, clock, logs_found.size())
	result = {"seconds": clock, "kills": kills, "logs": logs_found.size(), "logs_total": def.logs.size(), "attempt": attempt, "first": kept["first"], "best": kept["best"], "best_s": MissionProgress.current().best_s.get(def.id, clock), "granted": kept["granted"], "reason": ""}
	if life != null and is_instance_valid(life):
		life.shield(SHIELD_S)
	_clear_world()
	_fire("complete")
	completed.emit(result)


func _fire(trigger: String) -> void:
	if def == null or _fired.has(trigger):
		return
	_fired[trigger] = true
	for line in def.lines:
		if line.get("on") == trigger:
			line_said.emit(str(line["who"]), str(line["text"]))
	for shift in def.transitions:
		if shift.get("on") == trigger and shift.get("to") != register:
			var from := register
			register = shift["to"]
			if world != null and is_instance_valid(world):
				world.set_register(register)
			register_shifted.emit(from, register)
	if stage != null and is_instance_valid(stage):
		stage.fire(trigger)


func _carry() -> void:
	if player != null and is_instance_valid(player) and player.has_method("set_carried"):
		player.set_carried(carried)


func _clear_world() -> void:
	for log_id in _pickups:
		var p = _pickups[log_id]
		if p != null and is_instance_valid(p) and not p.taken:
			p.queue_free()
	_pickups.clear()
	if _beacon != null and is_instance_valid(_beacon):
		_beacon.queue_free()
	_beacon = null


# --- After it: what the end screen and the Esc menu ask for. ---

## The same mission again, as its next try: the arena reloaded into it.
func retry() -> void:
	if def == null:
		return
	queue(def.id, attempt + 1)
	_reload()


## The mission after this one, from its first try.
func next_mission() -> void:
	var after := MissionBook.of(def.next) if def != null and def.next != "" else null
	if after == null or not after.playable:
		return
	queue(after.id, 1)
	_reload()


## Back to the Missions screen, over a fresh arena.
func to_missions() -> void:
	clear_pending()
	_after = AFTER_MISSIONS
	_reload()


## Back to plain arena play, in a fresh arena.
func free_play() -> void:
	clear_pending()
	_reload()


## Ends it where it stands (a match starting): the loadout lifted, the round clock and ICE back as they were.
func end_here() -> void:
	if def == null:
		return
	if running():
		_pending = ""
		_pending_try = 1
	state = State.IDLE
	_clear_world()
	carried = PackedStringArray()
	_carry()
	_gate(false)
	if stage != null and is_instance_valid(stage):
		stage.stop()
	if rounds != null and is_instance_valid(rounds) and rounds.has_method("hold"):
		rounds.hold(false)
	if ice != null and is_instance_valid(ice):
		ice.stand_down = false
	ended.emit()


func _reload() -> void:
	if is_inside_tree() and get_tree().current_scene != null:
		_fade_in = true
		get_tree().reload_current_scene()


func _online() -> bool:
	return session != null and is_instance_valid(session) and session.is_online()
