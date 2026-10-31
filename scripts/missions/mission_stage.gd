class_name MissionStage
extends Node3D
## A mission's own daemons and set pieces (C37, MissionDef.waves and .props), made by its runner (scripts/missions/
## mission_runner.gd) as it begins and gone with the arena it stood in:
##   vents     spawn vents in the floor leaking green code (scripts/ruins/ruins_vent.gd), where its daemons come from
##   ICE walls white ICE (scripts/ice/ice_barrier.gd) with no director: no hit lands on it, so it cannot be passed yet
##   breach    its ruins' breach: split open (RuinsWorld.open_breach()) and the remnant's sign lit (light_remnant()) on
##             the triggers its data names
##   waves     each on its trigger (fire()) or after the wave it follows has no more than its "left" standing: its
##             daemons climb out of its vents in turn, "every" seconds apart, each a target dummy (scenes/
##             target_dummy.tscn) of its type and its wave's health that never respawns (so a mission's daemons are
##             finite: never more than its waves' counts), its elites seeds that roll its type's elite, and each, whole,
##             hunting the player at
##             once and never giving up (DaemonBrain.alert(), relentless)
## It says so as it goes (spawned, wave_began, wave_cleared), and the runner turns those into the mission's triggers
## ("wave:<id>", "cleared:<id>"). Seeds are fixed by the mission, the wave and the daemon's place in it in demo, test
## and capture runs, else rolled. Fiction only: it reads nothing, writes nothing, runs nothing.

signal spawned(dummy: Node3D)
signal wave_began(id: String)
signal wave_cleared(id: String)

const Dummy = preload("res://scripts/target_dummy.gd")
const DummyScene := preload("res://scenes/target_dummy.tscn")
const ART := {
	"rogue": preload("res://scripts/daemons/rogue_daemon.gd"),
	"zombie": preload("res://scripts/daemons/zombie_process.gd"),
	"swarm": preload("res://scripts/daemons/runaway_swarm.gd"),
}
const TAGS := {"rogue": "rogue.d", "zombie": "zombie", "swarm": "runaway"}
## Seconds a daemon takes to climb out of its vent.
const CLIMB_S := 1.1
## How far from its vent's middle a daemon climbs out, metres, so two out of one vent never stand in each other.
const SPREAD_M := 0.5
## A vent's grate, metres square.
const VENT_M := 1.5
## Seeds tried for an elite (or for none) before the first is taken anyway.
const SEED_TRIES := 400

var def: MissionDef = null
var world: RuinsWorld = null
## Where a place in its data is (the runner's place()), and where its daemons stand (the arena's Targets).
var place: Callable
var targets: Node3D = null
## The player, for a new daemon's first look.
var player: Node3D = null
## No more daemons once stopped: the mission done or failed.
var stopped := false
## Every daemon it made, in order, and how many of them.
var made: Array = []

var _vents := {}
var _walls: Array = []
var _waves := {}
var _order: PackedStringArray = []
var _fired := {}


## Builds `d`'s set pieces here: its vents and its walls (its waves wait for their triggers).
func build(d: MissionDef) -> void:
	def = d
	name = "MissionStage"
	for p in d.props:
		match p.get("kind"):
			"vent":
				var vent := RuinsVent.new()
				vent.name = "Vent_" + str(p["id"])
				vent.size = VENT_M
				add_child(vent)
				vent.global_position = _floor(place.call(p["at"]))
				_vents[p["id"]] = vent
			"ice_wall":
				var wall := IceBarrier.new()
				wall.name = "Ice_" + str(p["id"])
				wall.span = p.get("span", Vector2(3.0, 3.5))
				wall.spawn_seed = hash("%s:%s" % [d.id, p["id"]]) & DaemonArt.SEED_LAST
				add_child(wall)
				wall.global_position = _floor(place.call(p["at"]))
				wall.rotation.y = deg_to_rad(float(p.get("yaw", 0.0)))
				_walls.append(wall)
	for w in d.waves:
		_order.append(w["id"])
		_waves[w["id"]] = {"def": w, "state": "waiting", "next": 0, "wait": 0.0, "alive": [], "down": 0}


## Trigger `trigger` fired: the waves it starts, the breach it opens, the remnant it lights.
func fire(trigger: String) -> void:
	if _fired.has(trigger):
		return
	_fired[trigger] = true
	for id in _order:
		var wave: Dictionary = _waves[id]
		if wave["state"] == "waiting" and str(wave["def"].get("on", "")) == trigger:
			_start(id)
	for p in def.props:
		if p.get("kind") != "breach" or world == null or not is_instance_valid(world):
			continue
		if str(p.get("opens", "")) == trigger:
			world.open_breach()
		if str(p.get("lights", "")) == trigger:
			world.light_remnant()


## No more daemons: its waves stop where they are (those standing stay).
func stop() -> void:
	stopped = true


## Vent `id`, or null.
func vent(id: String) -> RuinsVent:
	return _vents.get(id)


## Its ICE walls.
func walls() -> Array:
	return _walls


## Wave `id`'s state: "waiting", "running" (still climbing out), "out" (all out, some standing) or "cleared".
func wave_state(id: String) -> String:
	return _waves[id]["state"] if _waves.has(id) else ""


## Its daemons standing now (out of their vents or climbing out).
func standing() -> Array:
	return made.filter(func(d): return is_instance_valid(d) and not d.is_queued_for_deletion() and (d.is_alive() or d.climbing()))


func _start(id: String) -> void:
	var wave: Dictionary = _waves[id]
	wave["state"] = "running"
	wave["wait"] = 0.0
	wave_began.emit(id)


func _physics_process(delta: float) -> void:
	for id in _order:
		var wave: Dictionary = _waves[id]
		var w: Dictionary = wave["def"]
		match wave["state"]:
			"waiting":
				var after := str(w.get("after", ""))
				if after != "" and _waves.has(after):
					var before: Dictionary = _waves[after]
					if (before["state"] == "out" or before["state"] == "cleared") and _alive(before) <= int(w.get("left", 0)):
						_start(id)
			"running":
				if stopped:
					continue
				wave["wait"] -= delta
				if wave["wait"] <= 0.0:
					_climb_out(id)
					wave["wait"] = float(w.get("every", MissionDef.WAVE_EVERY_S))
					if int(wave["next"]) >= int(w["count"]):
						wave["state"] = "out"
			"out":
				if _alive(wave) == 0:
					wave["state"] = "cleared"
					wave_cleared.emit(id)


func _alive(wave: Dictionary) -> int:
	var n := 0
	for d in wave["alive"]:
		if is_instance_valid(d) and not d.is_queued_for_deletion() and (d.is_alive() or d.climbing()):
			n += 1
	return n


## The next daemon of wave `id` climbs out of its next vent.
func _climb_out(id: String) -> void:
	var wave: Dictionary = _waves[id]
	var w: Dictionary = wave["def"]
	var i: int = wave["next"]
	wave["next"] = i + 1
	var from: Array = w["from"]
	var vent: RuinsVent = _vents.get(str(from[i % from.size()]))
	if vent == null or targets == null or not is_instance_valid(targets):
		return
	var kind: String = w["kind"]
	var dummy = DummyScene.instantiate()
	dummy.name = "Mission_%s_%02d" % [id, i]
	dummy.tag_text = TAGS[kind]
	dummy.art = ART[kind]
	dummy.respawns = false
	dummy.max_health = float(w.get("health", dummy.max_health))
	dummy.seed_wanted = _seed(id, i, i < int(w.get("elites", 0)))
	dummy.set_meta(&"wave", id)
	targets.add_child(dummy)
	var turn := TAU * float((i * 5 + made.size()) % 8) / 8.0
	var at := vent.global_position + Vector3(cos(turn), 0, sin(turn)) * SPREAD_M * float(int(float(i) / float(from.size())) % 3)
	dummy.global_position = at
	if player != null and is_instance_valid(player):
		var to := player.global_position - at
		dummy.rotation.y = atan2(-to.x, -to.z)
	dummy.spawn_in(CLIMB_S)
	if dummy.brain != null:
		dummy.brain.relentless = true
	dummy.respawned.connect(_on_out)
	wave["alive"].append(dummy)
	made.append(dummy)
	vent.burst()
	var director := DaemonDirector.of(self)
	if director != null:
		director.forget_brains()
	spawned.emit(dummy)


## Whole and out of its vent: it hunts at once.
func _on_out(dummy: Node3D) -> void:
	var director := DaemonDirector.of(dummy)
	if dummy.get("brain") != null and director != null:
		dummy.brain.alert(director)


## The seed of wave `id`'s daemon `i`: fixed in demo, test and capture runs, else rolled; its type's elite when
## `elite`, never one otherwise.
func _seed(id: String, i: int, elite: bool) -> int:
	var seed: int = DaemonArt.seed_of("%s/%s/%d" % [def.id, id, i]) if Dummy.fixed_seeds else (randi() & DaemonArt.SEED_LAST)
	for k in SEED_TRIES:
		if DaemonArt.elite_of(seed) == elite:
			return seed
		seed = (seed * 1103515245 + 12345 + k) & DaemonArt.SEED_LAST
	return seed


## `at` on the floor under it: a ruins point where a player stands has its stand height taken off.
static func _floor(at: Vector3) -> Vector3:
	if not at.is_finite():
		return Vector3.ZERO
	return at - Vector3(0, RuinsLayout.STAND_Y, 0) if absf(at.y - RuinsLayout.STAND_Y) < 0.05 else at
