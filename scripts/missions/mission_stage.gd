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
##
## Mission 2's (M2): a wave may stand at a spot (nothing drawn) or in a queue (a line of places out from a door, each
## daemon facing its head) instead of climbing out of a vent: it is there at once, no climb. A dormant wave's daemons
## stand asleep (DaemonBrain.dormant) until its "wakes" trigger fires, one of them is hurt or the player comes within
## MissionDef.WAKE_M of one; then the whole wave wakes at once and hunts as any (woke, the runner's "woke:<id>"). A
## sealed wave's daemons cannot be hurt until its "sealed" trigger fires. A parent wave's daemon (scripts/daemons/
## parent_process.gd) is the parent of every daemon of the type it reaps: a thread drawn from each to it (scripts/
## missions/parent_threads.gd), and when it goes down every one of them still standing drops at once, reaped
## (TargetDummy.reap(): no kill credited), and no more of that type come (reaped).

signal spawned(dummy: Node3D)
signal wave_began(id: String)
signal wave_cleared(id: String)
## A dormant wave woke (M2).
signal woke(id: String)
## Its parent went down and init reaped `count` of its children still standing (M2).
signal reaped(count: int)

const Dummy = preload("res://scripts/target_dummy.gd")
const DummyScene := preload("res://scenes/target_dummy.tscn")
const ART := {
	"rogue": preload("res://scripts/daemons/rogue_daemon.gd"),
	"zombie": preload("res://scripts/daemons/zombie_process.gd"),
	"swarm": preload("res://scripts/daemons/runaway_swarm.gd"),
	"parent": preload("res://scripts/daemons/parent_process.gd"),
}
const TAGS := {"rogue": "rogue.d", "zombie": "zombie", "swarm": "runaway", "parent": "<parent>"}
## Seconds a daemon takes to climb out of its vent, and to stand up at a spot or in a queue (M2).
const CLIMB_S := 1.1
const STAND_S := 0.4
## How far from its vent's middle a daemon climbs out, metres, so two out of one vent never stand in each other.
const SPREAD_M := 0.5
## A vent's grate, metres square.
const VENT_M := 1.5
## Seeds tried for an elite (or for none) before the first is taken anyway.
const SEED_TRIES := 400
## Seconds a parent's epitaph (its owner field) stays over where it stood (M2).
const EPITAPH_S := 4.2
const Palette = preload("res://scripts/palette.gd")

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
## Its parent's dummy (M2), once it stands, and how many of its children init reaped when it went down.
var parent: Node3D = null
var reaped_count := -1

var _vents := {}
var _spots := {}
var _queues := {}
var _walls: Array = []
var _waves := {}
var _order: PackedStringArray = []
var _fired := {}
var _threads: ParentThreads = null
var _reaps := ""


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
			"spot":
				_spots[p["id"]] = _floor(place.call(p["at"]))
			"queue":
				var yaw := deg_to_rad(float(p.get("yaw", 0.0)))
				var head := _floor(place.call(p["at"]))
				var way := Vector3(-sin(yaw), 0.0, -cos(yaw))
				if p.has("to"):
					var to := _floor(place.call(p["to"])) - head
					to.y = 0.0
					way = to.normalized() if to.length() > 0.1 else way
				_queues[p["id"]] = {"at": head, "way": way, "gap": float(p.get("gap", 1.3))}
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
		_waves[w["id"]] = {"def": w, "state": "waiting", "next": 0, "wait": 0.0, "alive": [], "down": 0, "awake": not w.get("dormant", false)}
	_reaps = str(d.parent_wave().get("reaps", ""))


## Trigger `trigger` fired: the waves it starts, wakes or unseals, the breach it opens, the remnant it lights, the shop it
## puts out (M2).
func fire(trigger: String) -> void:
	if _fired.has(trigger):
		return
	_fired[trigger] = true
	for id in _order:
		var wave: Dictionary = _waves[id]
		var w: Dictionary = wave["def"]
		if wave["state"] == "waiting" and str(w.get("on", "")) == trigger:
			_start(id)
		if not wave["awake"] and str(w.get("wakes", "")) == trigger:
			_wake(id)
		if str(w.get("sealed", "")) == trigger:
			for dummy in wave["alive"]:
				if is_instance_valid(dummy):
					dummy.sealed = false
	for p in def.props:
		if world == null or not is_instance_valid(world):
			continue
		if p.get("kind") == "shop" and str(p.get("dark", "")) == trigger:
			world.shop_dark()
		if p.get("kind") != "breach":
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


## True once wave `id` is awake (M2): a wave that was never dormant always is.
func wave_awake(id: String) -> bool:
	return _waves.has(id) and _waves[id]["awake"]


## Wave `id`'s daemons, as they were made (M2; freed ones left out).
func wave_daemons(id: String) -> Array:
	return _waves[id]["alive"].filter(func(d): return is_instance_valid(d)) if _waves.has(id) else []


## Its daemons standing now (out of their vents or climbing out).
func standing() -> Array:
	return made.filter(func(d): return is_instance_valid(d) and not d.is_queued_for_deletion() and (d.is_alive() or d.climbing()))


## Its parent's children standing now (M2): every daemon of the type it reaps, its own waves' or not.
func children() -> Array:
	if _reaps == "":
		return []
	return standing().filter(func(d): return d != parent and MissionRunner.kind_of(d) == _reaps)


## Its parent's threads (M2), or null.
func threads() -> ParentThreads:
	return _threads


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
				if stopped or (_reaps != "" and reaped_count >= 0 and w["kind"] == _reaps):
					continue  # stopped, or its parent gone and its kind reaped: no more of them (M2)
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
		if not wave["awake"] and wave["state"] != "waiting" and _stirred(wave):
			_wake(id)


func _alive(wave: Dictionary) -> int:
	var n := 0
	for d in wave["alive"]:
		if is_instance_valid(d) and not d.is_queued_for_deletion() and (d.is_alive() or d.climbing()):
			n += 1
	return n


## True when a dormant wave should wake (M2): one of it hurt, roused by a hit or put down outright (a sleeper railed in
## one shot wakes the rest of its line), or the player near one of it.
func _stirred(wave: Dictionary) -> bool:
	var near: bool = player != null and is_instance_valid(player) and player.get("alive") != false
	for d in wave["alive"]:
		if not is_instance_valid(d) or d.is_queued_for_deletion() or (not d.is_alive() and not d.climbing()):
			return true
		if not d.is_alive():
			continue
		if d.health() < d.max_health or (d.brain != null and not d.brain.dormant):
			return true
		if near and Vector2(d.global_position.x - player.global_position.x, d.global_position.z - player.global_position.z).length() <= MissionDef.WAKE_M:
			return true
	return false


## Wave `id` wakes, all of it at once (M2): each hunts the player, never giving up.
func _wake(id: String) -> void:
	var wave: Dictionary = _waves[id]
	var w: Dictionary = wave["def"]
	if wave["awake"]:
		return
	wave["awake"] = true
	var director := DaemonDirector.of(self)
	var up: bool = wave["alive"].is_empty() or wave["state"] == "running"
	for d in wave["alive"]:
		if is_instance_valid(d):
			d.hide_tag(w.get("tagged", true) == false)
		if is_instance_valid(d) and d.brain != null:
			d.brain.dormant = false
			d.brain.relentless = true
			if d.is_alive() or d.climbing():
				up = true
			if director != null and d.is_alive():
				d.brain.alert(director)
	if up:
		woke.emit(id)  # never for a wave put down in its sleep: nobody is left to have woken


## The next daemon of wave `id` climbs out of its next vent, or stands at its next spot or place in its queue (M2).
func _climb_out(id: String) -> void:
	var wave: Dictionary = _waves[id]
	var w: Dictionary = wave["def"]
	var i: int = wave["next"]
	wave["next"] = i + 1
	var from: Array = w["from"]
	var where := str(from[i % from.size()])
	var vent: RuinsVent = _vents.get(where)
	if (vent == null and not _spots.has(where) and not _queues.has(where)) or targets == null or not is_instance_valid(targets):
		return
	var kind: String = w["kind"]
	var dummy = DummyScene.instantiate()
	dummy.name = "Mission_%s_%02d" % [id, i]
	dummy.tag_text = str(w.get("tag", "")) if str(w.get("tag", "")) != "" else TAGS[kind]
	dummy.art = ART[kind]
	dummy.respawns = false
	dummy.max_health = float(w.get("health", dummy.max_health))
	dummy.seed_wanted = _seed(id, i, i < int(w.get("elites", 0)))
	dummy.set_meta(&"wave", id)
	dummy.sealed = str(w.get("sealed", "")) != "" and not _fired.has(str(w.get("sealed", "")))
	dummy.hit_cap = float(w.get("hit_cap", 0.0))
	dummy.tag_hidden = not wave["awake"] or w.get("tagged", true) == false  # a sleeper unlabelled until it wakes; a crowd never
	targets.add_child(dummy)
	var at: Vector3
	var face := Vector3.INF
	if vent != null:
		var turn := TAU * float((i * 5 + made.size()) % 8) / 8.0
		at = vent.global_position + Vector3(cos(turn), 0, sin(turn)) * SPREAD_M * float(int(float(i) / float(from.size())) % 3)
	elif _spots.has(where):
		at = _spots[where]
	else:
		# Its place in the line (M2): one gap further out per daemon already standing in it, facing its head.
		var q: Dictionary = _queues[where]
		var place_in := int(float(i) / float(from.size()))
		var sway := Vector3(q["way"].z, 0.0, -q["way"].x) * (0.18 if place_in % 2 == 0 else -0.14)
		at = q["at"] + q["way"] * q["gap"] * place_in + sway
		face = q["at"] - q["way"] * 4.0
	dummy.global_position = at
	if not face.is_finite() and player != null and is_instance_valid(player):
		face = player.global_position
	if face.is_finite():
		var to: Vector3 = face - at
		dummy.rotation.y = atan2(-to.x, -to.z)
	dummy.spawn_in(CLIMB_S if vent != null else STAND_S)
	if dummy.brain != null:
		dummy.brain.relentless = wave["awake"]
		dummy.brain.dormant = not wave["awake"]
	dummy.respawned.connect(_on_out)
	wave["alive"].append(dummy)
	made.append(dummy)
	if vent != null:
		vent.burst()
	if kind == "parent":
		_take_parent(dummy)
	var director := DaemonDirector.of(self)
	if director != null:
		director.forget_brains()
	spawned.emit(dummy)


## Whole and out of its vent: it hunts at once, unless its wave sleeps (M2) or it is a parent.
func _on_out(dummy: Node3D) -> void:
	if reaped_count >= 0 and dummy != parent and MissionRunner.kind_of(dummy) == _reaps:
		dummy.reap()  # still climbing out as its parent went down (M2): reaped as it stands
		return
	var wave: Dictionary = _waves.get(str(dummy.get_meta(&"wave", "")), {})
	if not wave.is_empty() and not wave["awake"]:
		return
	var director := DaemonDirector.of(dummy)
	if dummy.get("brain") != null and director != null:
		dummy.brain.alert(director)


## Its parent stands (M2): its threads drawn to every child, and its death reaps them.
func _take_parent(dummy: Node3D) -> void:
	parent = dummy
	dummy.downed.connect(_on_parent_down)
	_threads = ParentThreads.new()
	_threads.parent = dummy
	_threads.children = children
	add_child(_threads)


## The parent down (M2): every child still standing drops at once, reaped (no kill credited), and no more come.
func _on_parent_down(dummy: Node3D) -> void:
	var count := 0
	for d in children():
		if d.is_alive() and d.reap():
			count += 1
	reaped_count = count
	var epitaph := str(def.parent_wave().get("epitaph", ""))
	if epitaph != "":
		_epitaph(dummy, epitaph)
	reaped.emit(count)


## The parent's owner field over where it stood (M2), in its own amber, rising and fading over EPITAPH_S.
func _epitaph(dummy: Node3D, text: String) -> void:
	var art = dummy.art_node()
	var label := Label3D.new()
	label.name = "Epitaph"
	label.text = text
	label.font = Palette.mono_font()
	label.font_size = 96
	label.pixel_size = 0.008
	label.outline_size = 18
	label.modulate = Palette.HOSTILE_AMBER
	label.outline_modulate = Palette.VOID
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)
	var from: Vector3 = art.anchor() if art != null and art.has_method("anchor") else dummy.global_position + Vector3.UP * 4.0
	label.global_position = from
	var fade := label.create_tween()
	fade.tween_property(label, "global_position", from + Vector3.UP * 1.2, EPITAPH_S)
	fade.parallel().tween_property(label, "modulate:a", 0.0, EPITAPH_S).set_delay(EPITAPH_S * 0.55)
	fade.tween_callback(label.queue_free)


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
