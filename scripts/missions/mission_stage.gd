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
##
## Mission 3's (M3): its loop (MissionDef's "loop" prop) runs from its trigger: every pass (pass_s apart with every core
## running, quicker as cores go, down to pass_least_s with one left) rewrites its ruins' cache field (scripts/ruins/
## cache_field.gd) and has every core still standing fork one runaway off its hub (forked: within the loop's "each" and
## "standing" and its forks wave's count, so the loop's daemons stay finite whatever it does), while the cache fills (fill_s
## with every core running, slower with fewer; cache_marked at 25, 50 and 75 per cent, cache_full at the top). A core down
## scatters its own children (reaped, as a parent's are) and runs the rest hotter; the last one down breaks the loop
## (loop_broken): every fork still standing reaped, the field frozen with `^C` over its walls. Its "hush" props stop the
## district's rain for a second, and its "prompt" props put a red `>_` on a wall of the field in front of the player, each on
## its trigger after its own wait (and still after the mission is done: they are its last beat).

signal spawned(dummy: Node3D)
signal wave_began(id: String)
signal wave_cleared(id: String)
## A dormant wave woke (M2).
signal woke(id: String)
## Mission 4's (M4): a wave of kind "wall", "node" or "hunter" is the mission's own ICE, each piece placed through the ICE
## director (scripts/ice/ice_director.gd, staged by the runner) at its point as its wave runs, judged by the director as
## its own and counted by the runner as a kill when it breaks; finite: none comes back. Its "pickup" props lay the
## ICEbreakers' pickups (scripts/ice/breaker_director.gd, its spots the mission's) on their triggers; its "vault" prop
## lights the district's records screen (RuinsWorld.light_vault()) on its trigger; its "stutter" prop makes the sector's
## lights stutter once (Blackout.stutter()) `after` seconds past its trigger.
##
## Its parent went down and init reaped `count` of its children still standing (M2).
signal reaped(count: int)
## A scheduled job (M5) ran (`run` of `runs`), ran its fail (its last countdown ended with it still scheduled), or was
## removed from the crontab (its "until" trigger).
signal job_ran(id: String, run: int, runs: int)
signal job_due(id: String, reason: String)
signal job_removed(id: String)
## Mission 6's (M6): a daemon of its waves caught by a SIGHUP burst (scripts/weapons/sighup_burst.gd); a burst reaching
## the shell (`~`'s terminal: it does not even flicker).
signal hung_up(dummy: Node3D)
signal shell_hung_up
## Its loop (M3): a pass made (the field rewritten, its cores forking); a core forked `child`; the cache past a mark (per
## cent) and full; the loop broken (its last core down).
signal passed(turn: int)
signal forked(core: Node3D, child: Node3D)
signal cache_marked(percent: int)
signal cache_full
signal loop_broken

const Dummy = preload("res://scripts/target_dummy.gd")
const DummyScene := preload("res://scenes/target_dummy.tscn")
const ART := {
	"rogue": preload("res://scripts/daemons/rogue_daemon.gd"),
	"zombie": preload("res://scripts/daemons/zombie_process.gd"),
	"swarm": preload("res://scripts/daemons/runaway_swarm.gd"),
	"parent": preload("res://scripts/daemons/parent_process.gd"),
	"core": preload("res://scripts/daemons/loop_core.gd"),
}
const TAGS := {"rogue": "rogue.d", "zombie": "zombie", "swarm": "runaway", "parent": "<parent>", "core": "while true"}
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
## Its runner's clock held (M3: the Esc menu up, the mouse let go): its loop holds with it, no pass, no fork and no cache
## filling, so nothing fails the mission behind its own menu.
var held := false
## Every daemon it made, in order, and how many of them.
var made: Array = []
## Its parent's dummy (M2), once it stands, and how many of its children init reaped when it went down.
var parent: Node3D = null
var reaped_count := -1
## Its loop (M3): running, broken, its passes made, how full the cache is (0 to 1), and every child it forked.
var loop_running := false
var loop_broken_now := false
var passes := 0
var cache := 0.0
var forks_made: Array = []

var _vents := {}
var _spots := {}
var _queues := {}
var _walls: Array = []
var _waves := {}
var _order: PackedStringArray = []
var _fired := {}
var _threads: ParentThreads = null
var _reaps := ""
var _loop := {}
var _pass_left := 0.0
var _marked := {}
var _full := false
## Its cores' children so far, by core: [core, forked count].
var _core_forks := {}
## Its timed beats (M3): [seconds left, Callable], run even once it is stopped.
var _timed: Array = []
## Its pickups (M4): each prop's spot at the breakers' director (its index), and those due to be laid (their triggers
## fired) and not yet laid.
var _pickup_spot := {}
var _pickups_due: Array = []
## Its scheduled jobs (M5): each its prop, the seconds to its next run (-1 not scheduled), the runs it has made, whether
## it is scheduled now, done, and seconds since it was; its doors only root may pass; the crontab board's live line.
var _jobs := {}
var _doors: Array = []
var _board_label: Label3D = null
## Seconds a done job stays on the crontab.
const JOB_DONE_SHOWN_S := 6.0
## The shell (M6): its prop's wake trigger, its rows of type over the district's screen, what is typing and the rows
## waiting, how far the row typing has got; the SIGHUP bursts seen so far; its one hangup.
const SHELL_CPS := 16.0
const SHELL_ROWS := 6
const SHELL_WRAP := 34
const SHELL_ROW_M := 0.42
const SHELL_HUP_M := 9.0
var _shell_wake := ""
var _shell_labels: Array = []
var _shell_queue: Array = []
var _shell_text := ""
var _shell_typed := 0.0
var _shell_row := 0
var _shell_hup_done := false
var _bursts_seen := {}


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
			"pickup":
				_pickup_spot[p["id"]] = _pickup_spot.size()
			"job":
				_jobs[p["id"]] = {"p": p, "left": -1.0, "run": 0, "live": false, "done": false, "done_s": 0.0}
			"shell":
				_shell_wake = str(p.get("wakes", ""))
				if world != null and is_instance_valid(world) and world.has_shell():
					# `~`'s rows (M6): type over the screen, under its baked prompt, in its colour.
					var screen: Dictionary = world.shell_screen()
					var sout: Vector3 = screen["out"]
					var size: Vector2 = screen["size"]
					for i in SHELL_ROWS:
						var label := Label3D.new()
						label.name = "ShellRow%d" % i
						label.font = Palette.mono_font()
						label.font_size = 64
						label.pixel_size = 0.0042
						label.modulate = Palette.CRIMSON
						label.outline_modulate = Color(0, 0, 0, 0.9)
						label.outline_size = 8
						label.shaded = false
						label.text = ""
						add_child(label)
						label.global_position = (screen["at"] as Vector3) + sout * 0.3 + Vector3(0, 1.1 + size.y - 0.9 - 0.62 - SHELL_ROW_M * float(i), 0)
						label.rotation.y = atan2(sout.x, sout.z)
						_shell_labels.append(label)
			"door":
				var door := RootDoor.new()
				door.name = "Door_" + str(p["id"])
				door.span = p.get("span", MissionDef.DOOR_SPAN)
				add_child(door)
				door.global_position = _floor(place.call(p["at"]))
				door.rotation.y = deg_to_rad(float(p.get("yaw", 0.0)))
				_doors.append(door)
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
	_loop = d.loop_prop()
	if world != null and is_instance_valid(world) and world.has_board() and not _jobs.is_empty():
		# The crontab board's live line (M5): the next job's countdown, over its screen's lines.
		var screen: Dictionary = world.board_screen()
		_board_label = Label3D.new()
		_board_label.name = "BoardLine"
		_board_label.font = Palette.mono_font()
		_board_label.font_size = 64
		_board_label.pixel_size = 0.0055
		_board_label.modulate = Palette.HOSTILE_AMBER
		_board_label.outline_modulate = Color(0, 0, 0, 0.9)
		_board_label.outline_size = 10
		_board_label.shaded = false
		_board_label.text = ""
		add_child(_board_label)
		var out: Vector3 = screen["out"]
		_board_label.global_position = (screen["at"] as Vector3) + out * 0.3 + Vector3(0, 0.75, 0)
		_board_label.rotation.y = atan2(out.x, out.z)


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
			var delay := float(w.get("delay", 0.0))
			if delay > 0.0:
				wave["delay_left"] = delay  # M6: a wave held back past its trigger, by the mission's clock
			else:
				_start(id)
		if w.get("kind") == "black" and str(w.get("withdraws", "")) == trigger:
			for piece in wave["alive"]:
				if is_instance_valid(piece) and piece is BlackIce:
					(piece as BlackIce).withdraw_now()  # M6: the Auditor recalls it
		if not wave["awake"] and str(w.get("wakes", "")) == trigger:
			_wake(id)
		if str(w.get("sealed", "")) == trigger:
			for dummy in wave["alive"]:
				if is_instance_valid(dummy):
					dummy.sealed = false
	if not _loop.is_empty() and str(_loop.get("runs", "")) == trigger:
		_run_loop()
	for p in def.props:
		if ["hush", "prompt", "stutter"].has(p.get("kind")) and str(p.get("on", "")) == trigger:
			_timed.append([float(p.get("after", 0.0)), _beat.bind(p)])
		if p.get("kind") == "pickup" and str(p.get("on", "")) == trigger:
			_pickups_due.append(p)
			_lay_pickups()
		if p.get("kind") == "job":
			var job: Dictionary = _jobs[p["id"]]
			if str(p.get("on", "")) == trigger and not job["live"] and not job["done"]:
				job["live"] = true
				job["left"] = float(p["every"])
			if str(p.get("until", "")) == trigger and not job["done"]:
				job["live"] = false
				job["done"] = true
				job["left"] = -1.0
				job_removed.emit(str(p["id"]))
		if world == null or not is_instance_valid(world):
			continue
		if p.get("kind") == "vault" and str(p.get("lights", "")) == trigger:
			world.light_vault()
		if p.get("kind") == "shop" and str(p.get("dark", "")) == trigger:
			world.shop_dark()
		if p.get("kind") == "shell" and str(p.get("wakes", "")) == trigger:
			world.wake_shell()
		if p.get("kind") != "breach":
			continue
		var after := float(p.get("after", 0.0))
		if str(p.get("opens", "")) == trigger:
			if after > 0.0:
				_timed.append([after, world.open_breach])  # M6: the floor gives way a beat after the word
			else:
				world.open_breach()
		if str(p.get("lights", "")) == trigger:
			if after > 0.0:
				_timed.append([after, world.light_remnant])
			else:
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


## Its daemons standing now (out of their vents or climbing out), and (M4) its pieces of ICE standing.
func standing() -> Array:
	return made.filter(func(d): return is_instance_valid(d) and not d.is_queued_for_deletion() and (d.is_alive() or (d.has_method("climbing") and d.climbing())))


## Its pieces of ICE made so far (M4), broken ones too while they last.
func pieces() -> Array:
	return made.filter(func(d): return is_instance_valid(d) and d is IcePiece)


## Its pickups laid so far (M4), by prop id, and those still due.
func pickups_due() -> int:
	return _pickups_due.size()


## The pickups due laid, those the breakers' director can take now (M4: deciding, the breakers handed over).
func _lay_pickups() -> void:
	if _pickups_due.is_empty():
		return
	var breakers := BreakerDirector.of(self)
	if breakers == null:
		return
	var laid: Array = []
	for p in _pickups_due:
		var spot: int = _pickup_spot.get(p["id"], -1)
		if spot >= 0 and breakers.lay_pickup_at(spot, Breakers.kind_of(str(p["breaker"]))) != null:
			laid.append(p)
	for p in laid:
		_pickups_due.erase(p)


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


## A delayed wave's start (M6), its wait over: only if nothing started it meanwhile.
func _start_if_waiting(id: String) -> void:
	if _waves.has(id) and _waves[id]["state"] == "waiting":
		_start(id)


func _physics_process(delta: float) -> void:
	_step_timed(delta)
	_step_loop(delta)
	_lay_pickups()
	_step_jobs(delta)
	_step_doors()
	_step_shell(delta)
	_watch_bursts()
	for id in _order:
		var wave: Dictionary = _waves[id]
		var w: Dictionary = wave["def"]
		match wave["state"]:
			"waiting":
				if float(wave.get("delay_left", -1.0)) >= 0.0 and not held and not stopped:
					wave["delay_left"] = float(wave["delay_left"]) - delta
					if float(wave["delay_left"]) <= 0.0:
						wave.erase("delay_left")
						_start(id)
					continue
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
		if is_instance_valid(d) and not d.is_queued_for_deletion() and (d.is_alive() or (d.has_method("climbing") and d.climbing())):
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
## `off` (M3): where a loop's child comes off its core (world space), in place of a vent, a spot or a queue; the new daemon,
## or null.
func _climb_out(id: String, off: Vector3 = Vector3.INF) -> Node3D:
	var wave: Dictionary = _waves[id]
	var w: Dictionary = wave["def"]
	var i: int = wave["next"]
	wave["next"] = i + 1
	if MissionDef.ICE_KINDS.has(w["kind"]):
		return _place_ice(id, i, w, wave)
	var from: Array = w.get("from", [])
	var where := str(from[i % from.size()]) if not from.is_empty() else ""
	var vent: RuinsVent = _vents.get(where)
	if (vent == null and not _spots.has(where) and not _queues.has(where) and not off.is_finite()) or targets == null or not is_instance_valid(targets):
		return null
	var kind: String = w["kind"]
	var dummy = DummyScene.instantiate()
	dummy.name = "Mission_%s_%02d" % [id, i]
	dummy.tag_text = str(w.get("tag", "")).replace("{n}", str(i)) if str(w.get("tag", "")) != "" else TAGS[kind]
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
	if off.is_finite():
		at = off
	elif vent != null:
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
	if kind == "core" and not _loop.is_empty() and str(_loop.get("cores", "")) == id:
		_core_forks[dummy] = 0
		dummy.downed.connect(_on_core_down)
	var director := DaemonDirector.of(self)
	if director != null:
		director.forget_brains()
	spawned.emit(dummy)
	return dummy


## A piece of the mission's own ICE (M4): wave `id`'s `i`th, placed through the ICE director (staged by the runner) at
## its point, from the mission's seed; the piece, or null (no director staged, or no point).
func _place_ice(id: String, i: int, w: Dictionary, wave: Dictionary) -> Node3D:
	var ice := IceDirector.of(self)
	var from: Array = w.get("from", [])
	if ice == null or not ice.staged or from.is_empty():
		return null
	var at := _floor(place.call(from[i % from.size()]))
	var kind: String = w["kind"]
	var seed := _seed(id, i, false)
	var piece_name := "Mission_%s_%02d" % [id, i]
	var health := float(w.get("health", 0.0))
	var piece: Node3D = null
	match kind:
		"wall":
			var span: Vector2 = w.get("span", MissionDef.ICE_SPAN)
			piece = ice.stage_wall(piece_name, at, deg_to_rad(float(w.get("yaw", 0.0))), span, seed, health)
		"node":
			var kinds: Array = w.get("nodes", [])
			piece = ice.stage_node(piece_name, str(kinds[i % kinds.size()]) if not kinds.is_empty() else IceNode.JAM, at, seed, health)
		"hunter":
			var face: Vector3 = _floor(place.call(w["face"])) if w.has("face") else (player.global_position if player != null and is_instance_valid(player) else at + Vector3.BACK)
			piece = ice.stage_hunter(piece_name, at, face, seed, health)
		"black":
			piece = ice.stage_black(piece_name, at, seed)  # M6: the machine's last resort, on the mission's word
	if piece == null:
		return null
	piece.set_meta(&"wave", id)
	wave["alive"].append(piece)
	made.append(piece)
	spawned.emit(piece)
	return piece


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


# --- Its loop (M3). ---

## Its loop starts: the field driven by its passes from now, rewritten once at once, the first pass a pass_s away.
func _run_loop() -> void:
	if loop_running or loop_broken_now:
		return
	loop_running = true
	_pass_left = float(_loop["pass_s"])
	var f := _field()
	if f != null:
		f.driven = true
		f.rewrite()


## Its loop's cores standing now.
func cores() -> Array:
	return wave_daemons(str(_loop.get("cores", ""))).filter(func(d): return d.is_alive() or d.climbing()) if not _loop.is_empty() else []


func _field() -> CacheField:
	return world.field() if world != null and is_instance_valid(world) else null


func _step_loop(delta: float) -> void:
	if not loop_running or loop_broken_now or stopped or held:
		return
	var total := int(_wave_def(str(_loop["cores"])).get("count", 1))
	var live := cores().size()
	if live == 0 and _waves[str(_loop["cores"])]["state"] != "waiting" and _waves[str(_loop["cores"])]["state"] != "running":
		return
	# The cache fills while any core runs, faster the more of them.
	cache = minf(cache + delta * float(live) / float(maxi(total, 1)) / float(_loop["fill_s"]), 1.0)
	for mark in MissionDef.CACHE_MARKS:
		if cache * 100.0 >= float(mark) and not _marked.has(mark):
			_marked[mark] = true
			cache_marked.emit(mark)
	if cache >= 1.0 and not _full:
		_full = true
		cache_full.emit()
		return
	var hot := clampf(float(total - live) / float(maxi(total - 1, 1)), 0.0, 1.0)
	for core in cores():
		var art = core.art_node()
		if art != null and "heat" in art:
			art.heat = hot
	_pass_left -= delta
	if _pass_left <= 0.0:
		_pass_left = lerpf(float(_loop["pass_s"]), float(_loop["pass_least_s"]), hot)
		_pass()


## One pass of the loop: the field rewritten, every core standing forking one child (within its limits).
func _pass() -> void:
	passes += 1
	var f := _field()
	if f != null:
		f.rewrite()
	var forks_id := str(_loop["forks"])
	var forks_wave: Dictionary = _waves[forks_id]
	for core in cores():
		if not core.is_alive():
			continue
		if int(forks_wave["next"]) >= int(forks_wave["def"]["count"]):
			break
		if int(_core_forks.get(core, 0)) >= int(_loop["each"]):
			continue
		var standing := forks_made.filter(func(c): return is_instance_valid(c) and c.get_meta(&"core", null) == core and (c.is_alive() or c.climbing())).size()
		if standing >= int(_loop["standing"]):
			continue
		_fork(core)
	passed.emit(passes)


## Core `core` forks one child off its hub: a runaway of the loop's forks wave, hunting at once.
func _fork(core: Node3D) -> void:
	var art = core.art_node()
	var off: Vector3 = core.global_position
	if art != null and art.has_method("hub"):
		off = art.hub()
		off.y = core.global_position.y
	var away := Vector3.ZERO
	if player != null and is_instance_valid(player):
		away = Vector3(player.global_position.x - off.x, 0.0, player.global_position.z - off.z).normalized() * 0.6
	var child := _climb_out(str(_loop["forks"]), off + away)
	if child == null:
		return
	child.set_meta(&"core", core)
	_core_forks[core] = int(_core_forks.get(core, 0)) + 1
	forks_made.append(child)
	var wave: Dictionary = _waves[str(_loop["forks"])]
	wave["state"] = "out"
	if art != null and art.has_method("fork_flash"):
		art.fork_flash()
	forked.emit(core, child)


## A core down: its own children scattered (reaped: no kill credited), and the last one breaks the loop.
func _on_core_down(core: Node3D) -> void:
	for child in forks_made:
		if is_instance_valid(child) and child.get_meta(&"core", null) == core and child.is_alive():
			child.reap()
	if cores().filter(func(d): return d != core).is_empty() and _waves[str(_loop["cores"])]["state"] != "running":
		_break_loop()


## The loop broken (its last core down): every fork still standing reaped, no pass again, the field frozen where it
## stands with `^C` over it.
func _break_loop() -> void:
	if loop_broken_now:
		return
	loop_broken_now = true
	loop_running = false
	for child in forks_made:
		if is_instance_valid(child) and child.is_alive():
			child.reap()
	var f := _field()
	if f != null:
		f.freeze()
	loop_broken.emit()


## The scheduled jobs (M5): each live one counts down (held with the mission's clock) and at zero makes its next run: the
## next of its waves started, or, past its last wave, its fail; done once it has nothing left to run.
func _step_jobs(delta: float) -> void:
	for id in _jobs:
		var job: Dictionary = _jobs[id]
		if job["done"]:
			job["done_s"] += delta
			continue
		if not job["live"] or held or stopped:
			continue
		job["left"] -= delta
		if job["left"] > 0.0:
			continue
		var p: Dictionary = job["p"]
		var runs: Array = p.get("waves", [])
		var total := runs.size() + (1 if str(p.get("fails", "")) != "" else 0)
		var n: int = job["run"]
		job["run"] = n + 1
		if n < runs.size():
			var wid := str(runs[n])
			if _waves.has(wid) and _waves[wid]["state"] == "waiting":
				_start(wid)
			job_ran.emit(str(id), n + 1, total)
			if n + 1 < total:
				job["left"] = float(p["every"])
			else:
				job["live"] = false
				job["done"] = true
				job["left"] = -1.0
		else:
			job["live"] = false
			job["done"] = true
			job["left"] = -1.0
			job_due.emit(str(id), str(p["fails"]))
	if _board_label != null:
		var line := ""
		var soonest := INF
		for id in _jobs:
			var job: Dictionary = _jobs[id]
			if job["live"] and job["left"] < soonest:
				soonest = job["left"]
				line = "NEXT  %s  %s" % [str(job["p"]["name"]).to_upper(), _clock(job["left"])]
		_board_label.text = line


## The doors only root may pass (M5): open while the player is root#.
func _step_doors() -> void:
	if _doors.is_empty():
		return
	var root := false
	if player != null and is_instance_valid(player):
		var sudo = player.get("sudo")
		root = sudo != null and sudo.state != null and sudo.is_root()
	for door in _doors:
		if is_instance_valid(door):
			door.set_open(root)


## Its jobs for the HUD's crontab (M5), in their props' order: id, name, every, seconds left, runs made and in all,
## whether it fails at the end, scheduled, done and for how long.
func jobs() -> Array:
	var out: Array = []
	for id in _jobs:
		var job: Dictionary = _jobs[id]
		var p: Dictionary = job["p"]
		var runs: Array = p.get("waves", [])
		var fails := str(p.get("fails", "")) != ""
		out.append({"id": str(id), "name": str(p["name"]), "every": float(p["every"]), "left": float(job["left"]), "run": int(job["run"]), "runs": runs.size() + (1 if fails else 0), "fails": fails, "live": bool(job["live"]), "done": bool(job["done"]), "done_s": float(job["done_s"])})
	return out


## Its doors (M5).
func doors() -> Array:
	return _doors.filter(func(d): return is_instance_valid(d))


static func _clock(seconds: float) -> String:
	var s := maxi(ceili(seconds), 0)
	return "%02d:%02d" % [s / 60, s % 60]


## A hush or a prompt (M3), its wait over: the rain stopped for its seconds, or the red `>_` on a wall in front of the
## player's eyes.
func _beat(p: Dictionary) -> void:
	if world == null or not is_instance_valid(world):
		return
	match p.get("kind"):
		"hush":
			world.hush(float(p.get("seconds", 1.0)))
		"prompt":
			var f := _field()
			var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
			if f != null and cam != null:
				f.prompt(cam.global_position, -cam.global_transform.basis.z)
		"stutter":
			var blackout := Blackout.of(self)
			if blackout != null:
				blackout.stutter()


func _step_timed(delta: float) -> void:
	if _timed.is_empty():
		return
	var due: Array = []
	for t in _timed:
		t[0] -= delta
		if t[0] <= 0.0:
			due.append(t)
	for t in due:
		_timed.erase(t)
		(t[1] as Callable).call()


func _wave_def(id: String) -> Dictionary:
	return _waves[id]["def"] if _waves.has(id) else {}


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
func _floor(at: Vector3) -> Vector3:
	if not at.is_finite():
		return Vector3.ZERO
	if world != null and is_instance_valid(world):
		# Its band's floor (M6: terraces): a point standing on it, or at a player's height over it, put on it.
		var fy := world.floor_y_at(at)
		if absf(at.y - fy) < 0.05 or absf(at.y - (fy + RuinsLayout.STAND_Y)) < 0.05:
			return Vector3(at.x, fy, at.z)
		return at
	return at - Vector3(0, RuinsLayout.STAND_Y, 0) if absf(at.y - RuinsLayout.STAND_Y) < 0.05 else at


# --- The shell and the hangups (M6). ---

## `~`'s line `text` typed on the shell's screen, row by row, after whatever is typing.
func type_line(text: String) -> void:
	if _shell_labels.is_empty():
		return
	var words := text.split(" ", false)
	var row := ""
	for word in words:
		if row != "" and row.length() + 1 + word.length() > SHELL_WRAP:
			_shell_queue.append(row)
			row = word
		else:
			row = word if row == "" else row + " " + word
	if row != "":
		_shell_queue.append(row)


## True while a row is typing or waiting to.
func shell_typing() -> bool:
	return _shell_text != "" or not _shell_queue.is_empty()


## Every row typed on the shell so far, the one typing included, a "\n" between two.
func shell_text() -> String:
	var rows := PackedStringArray()
	for label in _shell_labels:
		if (label as Label3D).text != "":
			rows.append((label as Label3D).text.trim_suffix("_"))
	return "\n".join(rows)


func _step_shell(delta: float) -> void:
	if _shell_labels.is_empty():
		return
	if _shell_text == "":
		if _shell_queue.is_empty():
			return
		_shell_text = _shell_queue.pop_front()
		_shell_typed = 0.0
		if _shell_row >= SHELL_ROWS:
			# The screen full: every row up one, the last cleared (a terminal scrolling).
			for i in SHELL_ROWS - 1:
				(_shell_labels[i] as Label3D).text = (_shell_labels[i + 1] as Label3D).text
			_shell_row = SHELL_ROWS - 1
	_shell_typed += SHELL_CPS * delta
	var n := mini(int(_shell_typed), _shell_text.length())
	var label: Label3D = _shell_labels[_shell_row]
	label.text = _shell_text.substr(0, n) + ("_" if n < _shell_text.length() else "")
	if n >= _shell_text.length():
		_shell_text = ""
		_shell_row += 1


## Every SIGHUP burst in the arena watched once (M6): what it catches, and where it goes off.
func _watch_bursts() -> void:
	if not is_inside_tree():
		return
	for burst in get_tree().get_nodes_in_group(&"sighup"):
		var key := burst.get_instance_id()
		if _bursts_seen.has(key):
			continue
		_bursts_seen[key] = true
		if burst.has_signal("caught"):
			burst.caught.connect(_on_hup)
		if burst.has_signal("went_off"):
			burst.went_off.connect(_on_burst)


func _on_hup(what: Node, _at: Vector3) -> void:
	if what is Node3D and what.has_meta(&"wave") and made.has(what):
		hung_up.emit(what)


func _on_burst(at: Vector3) -> void:
	if _shell_hup_done or world == null or not is_instance_valid(world) or not world.has_shell():
		return
	var screen: Dictionary = world.shell_screen()
	var middle: Vector3 = (screen["at"] as Vector3) + Vector3(0, 2.2, 0)
	if at.distance_to(middle) <= SHELL_HUP_M:
		_shell_hup_done = true
		shell_hung_up.emit()
