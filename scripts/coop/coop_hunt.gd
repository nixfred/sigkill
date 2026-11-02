class_name CoopHunt
extends Node3D
## Split-screen co-op (W6, PRD 5.5; the sixth of M5's world features): two players on one machine, each with their own view,
## hunting the arena's daemons together. Reached from the Esc menu ("Split-screen co-op"; "Leave split-screen co-op" ends
## it), or with --coop on a demo or test run. Made by the arena (scripts/main.gd) beside the other world modes; it begins
## when queued, in the regular arena.
##
## The screen (scripts/coop/coop_screen.gd): the game's one window split into two tiles, styled as a tiling desktop's
## windows, each player's view in its own; a player grows or shrinks their tile and flips the split, and the size is a
## trade: a bigger tile sees more, a smaller one aims faster and steadier. No window manager is asked for anything.
##
## The players: player 1 is the game's own, keyboard and mouse as ever; player 2 is made here (a second scenes/player.tscn,
## seat 2) and reads only its own keys: a gamepad, or the numeric keypad (scripts/coop/coop_input.gd). Each one's body is
## drawn for the other (scripts/coop/coop_body.gd). Co-op is weapons only: the abilities stay off (SIGSTOP would slow the
## one clock both share), and the Audit Trail visor is player 1's (I), in player 1's tile.
##
## The run, the arena's PvE hunt for two: WAVES waves of the arena's daemons forking in at the floor's far spots, each
## wave's count the solo count times SCALE, the last with the boss (a core the two of them have pegged, its health for two);
## a break between waves; a shared results card at the end (each player's kills, downs, revives and accuracy, the waves,
## the time); Enter (or the pad's A) runs it again.
##
## Downs and revives: a player's health at 0 is a down, not a death: the job is stopped (`[2]+  Stopped`), the view sinks
## and drains of colour, they cannot move or shoot, and they bleed out over BLEED_S. A partner standing within REVIVE_M of
## them for REVIVE_S brings them back (`fg %2`; the progress falls back while they step away), at REVIVE_HEALTH and briefly
## protected. Bled out, a player is out (derezzed) until the wave ends. Both players down or out at once: wiped, the run
## over. A wave cleared brings back everyone, full.
##
## Demo data only: no real layer of any kind; nothing here reads the player's machine, opens a socket, writes a file, runs
## anything or calls the compositor. Every kill is the game's own, simulated.

const PlayerScene = preload("res://scenes/player.tscn")
const DummyScene = preload("res://scenes/target_dummy.tscn")
const RogueArt = preload("res://scripts/daemons/rogue_daemon.gd")
const ZombieArt = preload("res://scripts/daemons/zombie_process.gd")
const RunawayArt = preload("res://scripts/daemons/runaway_swarm.gd")
const CoreArt = preload("res://scripts/daemons/pegged_core.gd")
const DerezzFx = preload("res://scripts/derezz_fx.gd")
const DerezzTuning = preload("res://scripts/derezz_tuning.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")

const GROUP := &"coop_hunt"
const NODE_NAME := "CoopHunt"
const FLAG := "--coop"
const RELOAD_LABEL := "$ tmux split-window -h"
const PLAYER2 := "Player2"

## The waves for one player (kind: count); the run plays each times SCALE (rounded up). The last brings the boss.
const WAVES := [
	{"rogue": 3, "runaway": 1},
	{"rogue": 2, "zombie": 2, "runaway": 1},
	{"rogue": 3, "zombie": 2, "runaway": 2},
	{"boss": 1, "rogue": 2, "runaway": 1},
]
const SCALE := 1.6
## Health: the arena's daemons as in the other world modes; the boss's for two.
const HEALTH := {"rogue": 50.0, "zombie": 75.0, "runaway": 25.0, "boss": 900.0}
const TAGS := {"rogue": "rogue.d", "zombie": "zombie", "runaway": "runaway", "boss": "pegged core"}
const BOSS_SIZE := 1.7
## How far apart a wave's daemons fork in, the wait before a wave, the break after one, the end's pause.
const FORK_GAP_S := 0.45
const READY_S := 4.0
const BREAK_S := 5.0
const DONE_S := 1.6
## Each player's health, and the revive's numbers.
const MAX_HEALTH := 100.0
const BLEED_S := 25.0
const REVIVE_M := 2.4
const REVIVE_S := 2.6
const REVIVE_DECAY := 0.8
const REVIVE_HEALTH := 40.0
const PROTECT_S := 1.5
## A hit's flash on a tile, seconds.
const HURT_S := 0.35
## Where player 2 starts beside player 1.
const P2_OFFSET := Vector3(2.2, 0.0, 0.6)
## The floor's spots a wave forks in at (the regular arena's own floor, arena space; any a block stands on is skipped).
const SPOTS := [
	Vector3(-16, 0, -4), Vector3(16, 0, -4), Vector3(-16, 0, 14), Vector3(16, 0, 14), Vector3(0, 0, 16),
	Vector3(-4, 0, -14), Vector3(4, 0, -14), Vector3(-15, 0, -16), Vector3(15, 0, -16), Vector3(-10, 0, -3),
	Vector3(10, 0, -3), Vector3(-3, 0, 8), Vector3(16, 0, 5), Vector3(-17, 0, 9), Vector3(3, 0, 16),
]
const BOSS_SPOT := Vector3(0, 0, -3.5)

static var queued := false
static var stats := {}
static var _flag_taken := false
static var _going := false

signal began
signal ended
signal spawned(dummy: Node3D)
signal event(kind: String, text: String)

var running := false
var player: Node3D = null
var player2: Node3D = null
var director: DaemonDirector = null
var runner: MissionRunner = null
var ice: Node = null
var rounds: Node = null
var guide: Node = null
var visor: Node = null
var hud: Node = null
var screen: CoopScreen = null
## "ready", "wave", "break", "done", "wiped", "results".
var phase := ""
var wave := 0
var enemies: Array = []
var events: Array = []
## Each seat's life (index 1 and 2): {"health", "state" (up, down, out), "bleed", "revive", "protect", "hurt", "slump"}.
var lives: Array = [null, {}, {}]
## Each seat's run: {"kills", "downs", "revives", "outs", "shots0", "hits0"}.
var per: Array = [null, {}, {}]
var _clock := 0.0
var _phase_t := 0.0
var _queue: Array = []
var _queue_t := 0.0
var _parked: Array = []
var _sfx: AudioStreamPlayer = null
var _coop_hud: CoopHud = null
var _bodies: Array = [null, null, null]
var _visor_hud: Control = null
var _visor_hud_parent: Node = null
var _spots: Array = []
var _tick_t := 0.0


static func of(node: Node) -> CoopHunt:
	if node == null or not node.is_inside_tree():
		return null
	var mine := node.get_node_or_null(NODE_NAME) as CoopHunt
	if mine != null:
		return mine
	for m in node.get_tree().get_nodes_in_group(GROUP):
		if not m.is_queued_for_deletion():
			return m as CoopHunt
	return null


static func queue() -> void:
	queued = true
	stats = {}


static func clear() -> void:
	queued = false
	stats = {}


static func take_flag(args: PackedStringArray) -> void:
	if _flag_taken:
		return
	_flag_taken = true
	if args.has(FLAG) and (args.has("--demo") or OS.get_cmdline_args().has("--script")):
		queue()


## As the arena loads: the flag taken once a run; nothing to stage (co-op plays the regular arena).
static func prepare(args: PackedStringArray, online: bool) -> bool:
	take_flag(args)
	_going = false
	return queued and not online and MissionRunner.pending() == ""


static func fresh_stats() -> Dictionary:
	return {"waves": 0, "time": 0.0, "wiped": false, "done": false}


func _ready() -> void:
	name = NODE_NAME
	add_to_group(GROUP)


func _exit_tree() -> void:
	_let_go()


## Begins co-op where the arena stands: the arena's own daemons parked, ICE stood down, the rounds held, player 2 made
## beside player 1, the screen split. False online or in a mission.
func begin() -> bool:
	if running or _online() or (runner != null and is_instance_valid(runner) and runner.running()):
		return false
	if player == null or not is_instance_valid(player):
		return false
	running = true
	queued = true
	_park_arena_daemons()
	if ice != null and is_instance_valid(ice) and "stand_down" in ice:
		ice.stand_down = true
	if rounds != null and is_instance_valid(rounds) and rounds.has_method("hold"):
		rounds.hold(true)
	CoopInput.ensure()
	_make_player2()
	_seat_player1()
	screen = CoopScreen.new()
	add_child(screen)
	screen.build(player, player2)
	screen.moved.connect(_on_moved)
	for seat: int in [1, 2]:
		var body := CoopBody.new()
		body.seat = seat
		body.hue = CoopScreen.COLOR[seat]
		body.hue_hi = CoopScreen.COLOR_HI[seat]
		body.player = _seat(seat)
		_seat(seat).add_child(body)
		_bodies[seat] = body
	_coop_hud = CoopHud.new()
	_coop_hud.mode = self
	add_child(_coop_hud)
	if hud != null and is_instance_valid(hud) and hud.has_method("set_coop"):
		hud.set_coop(true)
	_take_visor_hud()
	if director != null and is_instance_valid(director):
		director.coop = self
	_sfx = AudioStreamPlayer.new()
	_sfx.name = "CoopSound"
	_sfx.bus = SettingsApply.EFFECTS if AudioServer.get_bus_index(SettingsApply.EFFECTS) >= 0 else &"Master"
	_sfx.max_polyphony = 4
	add_child(_sfx)
	_find_spots()
	_start_run()
	began.emit()
	return true


func _make_player2() -> void:
	var host := get_parent()
	player2 = PlayerScene.instantiate()
	player2.name = PLAYER2
	player2.seat = 2
	player2.actions = CoopInput.P2.duplicate()
	(player2.get_node("Head/Camera") as Camera3D).current = false  # the window's camera stays player 1's
	host.add_child(player2)
	player2.global_transform = player.global_transform.translated(player.global_basis * P2_OFFSET)
	player2.set_abilities(PackedStringArray(), true)


func _seat_player1() -> void:
	player.stick_look = false  # the pad is player 2's while co-op runs
	player.set_abilities(PackedStringArray(), true)


func _start_run() -> void:
	stats = fresh_stats()
	_clear_enemies()
	_queue.clear()
	events.clear()
	wave = 0
	for seat: int in [1, 2]:
		lives[seat] = {"health": MAX_HEALTH, "state": "up", "bleed": 0.0, "revive": 0.0, "protect": PROTECT_S, "hurt": 0.0, "slump": 0.0}
		var p := _seat(seat)
		per[seat] = {"kills": 0, "downs": 0, "revives": 0, "outs": 0, "shots0": int(p.shots_fired), "hits0": int(p.hits_landed)}
		if p.get("alive") == false:
			p.set_alive(true)
		p.slump = 0.0
	_enter("ready")
	_note("begin", "two jobs on one machine: %d waves" % WAVES.size())


## Ends co-op where it stands (a match starting, the Esc menu's way out): player 2 and the split gone, the arena's own
## daemons back, ICE and the rounds as they were, player 1 as it was. Not queued any more.
func end() -> void:
	if not running:
		return
	running = false
	_let_go()
	_clear_enemies()
	_release_parked()
	if ice != null and is_instance_valid(ice) and "stand_down" in ice:
		ice.stand_down = false
	if rounds != null and is_instance_valid(rounds) and rounds.has_method("hold"):
		rounds.hold(false)
	for node in get_children():
		node.queue_free()
	clear()
	ended.emit()


## Everything the mode changed outside itself, put back: player 1's seat, the visor's HUD, the HUD, the input map, the
## window's 3D view; player 2 and the tiles gone.
func _let_go() -> void:
	_give_visor_hud()
	if screen != null and is_instance_valid(screen):
		screen.tear_down()
	if player != null and is_instance_valid(player):
		player.stick_look = true
		player.view_tan = 1.0
		player.aim_scale = 1.0
		player.steady_scale = 1.0
		player.slump = 0.0
		player.set_abilities(PackedStringArray(), false)
		if player.get("alive") == false:
			player.set_alive(true)
		var body = _bodies[1]
		if body != null and is_instance_valid(body):
			body.queue_free()
	_bodies = [null, null, null]
	if player2 != null and is_instance_valid(player2):
		player2.queue_free()
	player2 = null
	if hud != null and is_instance_valid(hud) and hud.has_method("set_coop"):
		hud.set_coop(false)
	if director != null and is_instance_valid(director) and director.coop == self:
		director.coop = null
	CoopInput.remove()
	if screen != null and is_instance_valid(screen):
		screen.queue_free()
	if _coop_hud != null and is_instance_valid(_coop_hud):
		_coop_hud.queue_free()
	if _sfx != null and is_instance_valid(_sfx):
		_sfx.queue_free()
	screen = null
	_coop_hud = null
	_sfx = null


func _online() -> bool:
	var session = director.session if director != null and is_instance_valid(director) else null
	return session != null and is_instance_valid(session) and session.has_method("is_online") and session.is_online()


func _seat(seat: int) -> Node3D:
	return player if seat == 1 else player2


# --- The director's view of the two players (scripts/fight/daemon_director.gd). ---

## Where player `id`'s middle is, or INF while it is not up.
func prey_point(id: int) -> Vector3:
	var p := _seat(id) if id == 1 or id == 2 else null
	if p == null or not is_instance_valid(p) or not p.is_inside_tree() or not up(id):
		return Vector3.INF
	return p.global_position


## True while player `id` stands (not downed, not out).
func up(id: int) -> bool:
	if id != 1 and id != 2 or lives[id].is_empty():
		return false
	return str(lives[id]["state"]) == "up" and phase != "results"


## True while player `id` can be hurt: up and not protected.
func attackable(id: int) -> bool:
	return up(id) and float(lives[id]["protect"]) <= 0.0 and phase != "done" and phase != "wiped"


## `amount` of a daemon's damage on player `id` (by `by`, along `way`); a down when it takes the last of the health. True
## when it took health.
func damage(id: int, amount: float, by: Node, way: Vector3) -> bool:
	if not running or not attackable(id) or amount <= 0.0 or not is_finite(amount):
		return false
	var life: Dictionary = lives[id]
	var taken := minf(amount, float(life["health"]))
	life["health"] = float(life["health"]) - taken
	life["hurt"] = HURT_S
	var p := _seat(id)
	if p != null and is_instance_valid(p) and p.has_method("take_hit"):
		p.take_hit(taken)
	if float(life["health"]) <= 0.0:
		_down(id, String(by.get("tag_text")) if by != null and is_instance_valid(by) else "", way)
	return true


func health(id: int) -> float:
	return float(lives[id].get("health", 0.0)) if (id == 1 or id == 2) and not lives[id].is_empty() else 0.0


func state(id: int) -> String:
	return str(lives[id].get("state", "")) if (id == 1 or id == 2) and not lives[id].is_empty() else ""


# --- Downs and revives. ---

func _down(id: int, what: String, _way: Vector3) -> void:
	var life: Dictionary = lives[id]
	life["state"] = "down"
	life["health"] = 0.0
	life["bleed"] = BLEED_S
	life["revive"] = 0.0
	per[id]["downs"] = int(per[id]["downs"]) + 1
	var p := _seat(id)
	if p != null and is_instance_valid(p):
		p.set_alive(false)
	_note("down", "[%d]+  Stopped   p%d %s%s" % [id, id, CoopScreen.PROMPT[id], ("  (" + what + ")") if what != "" else ""])
	_play("down")
	if _wiped():
		_wipe()


## Player `id` brought back by its partner (`by`).
func revive(id: int, by: int) -> void:
	var life: Dictionary = lives[id]
	if str(life["state"]) != "down":
		return
	life["state"] = "up"
	life["health"] = REVIVE_HEALTH
	life["revive"] = 0.0
	life["protect"] = PROTECT_S
	if by == 1 or by == 2:
		per[by]["revives"] = int(per[by]["revives"]) + 1
	var p := _seat(id)
	if p != null and is_instance_valid(p):
		p.set_alive(true)
		var fx := ParticleFx.of(self)
		if fx != null:
			fx.ping(p.global_position + Vector3.DOWN * 0.85, CoopScreen.COLOR[id], REVIVE_M * 1.6, 0.6)
			fx.blast(p.global_position, CoopScreen.COLOR_HI[id], 1.6)
	_note("revived", "fg %%%d   [%d]  Continued   p%d %s" % [id, id, id, CoopScreen.PROMPT[id]])
	_play("revived")


func _bleed_out(id: int) -> void:
	var life: Dictionary = lives[id]
	life["state"] = "out"
	life["revive"] = 0.0
	per[id]["outs"] = int(per[id]["outs"]) + 1
	var p := _seat(id)
	if p != null and is_instance_valid(p):
		var d = load("res://resources/derezz.tres")
		if not (d is DerezzTuning) or not d.problems().is_empty():
			d = DerezzTuning.new()
		var fx := DerezzFx.new()
		get_parent().add_child(fx)
		fx.start(p.global_position + Vector3.DOWN * 0.9, 0.4, 1.5, Vector3.FORWARD, d)
	var body = _bodies[id]
	if body != null and is_instance_valid(body):
		body.visible = false
	_note("out", "[%d]+  Killed   p%d bled out: back at the wave's end" % [id, id])
	_play("out")
	if _wiped():
		_wipe()


func _wiped() -> bool:
	return not up(1) and not up(2) and phase != "results" and phase != "wiped"


func _wipe() -> void:
	stats["wiped"] = true
	_queue.clear()
	_enter("wiped")
	_note("wiped", "both jobs stopped: wiped on wave %d" % wave)
	_play("wiped")


## Everyone back up, full (a wave cleared, a run begun).
func _all_back() -> void:
	for seat: int in [1, 2]:
		var life: Dictionary = lives[seat]
		var was := str(life["state"])
		life["state"] = "up"
		life["health"] = MAX_HEALTH
		life["bleed"] = 0.0
		life["revive"] = 0.0
		life["protect"] = PROTECT_S
		var p := _seat(seat)
		if p != null and is_instance_valid(p) and p.get("alive") == false:
			p.set_alive(true)
		var body = _bodies[seat]
		if body != null and is_instance_valid(body):
			body.visible = true
		if was != "up":
			_note("revived", "[%d]  Continued   p%d back for the next wave" % [seat, seat])


# --- The waves. ---

## The kinds wave `n` (1-based) forks in, for two: each solo count times SCALE, rounded up; the boss alone as it is.
static func wave_list(n: int) -> Array:
	var out: Array = []
	var spec: Dictionary = WAVES[n - 1]
	for kind in ["boss", "zombie", "rogue", "runaway"]:
		if not spec.has(kind):
			continue
		var count := int(spec[kind]) if kind == "boss" else int(ceil(float(spec[kind]) * SCALE - 0.0001))
		for i in count:
			out.append(kind)
	return out


func _start_wave(n: int) -> void:
	wave = n
	_queue = wave_list(n)
	_queue_t = 0.0
	_enter("wave")
	var boss := _queue.has("boss")
	_note("wave", ("wave %d/%d: the boss and %d daemons fork in" % [n, WAVES.size(), _queue.size() - 1]) if boss else ("wave %d/%d: %d daemons fork in" % [n, WAVES.size(), _queue.size()]))
	_play("boss" if boss else "wave")


func _find_spots() -> void:
	_spots.clear()
	var arena := get_parent().get_node_or_null("Arena") as Node3D
	var space := get_world_3d().direct_space_state
	for s in SPOTS:
		var at: Vector3 = arena.to_global(s) if arena != null else s
		var q := PhysicsPointQueryParameters3D.new()
		q.position = at + Vector3.UP * 1.0
		q.collision_mask = 1
		if space.intersect_point(q, 1).is_empty():
			_spots.append(at)


## The spot for the next daemon: the free spots farthest from both players, taken in turn.
func _spot_for(i: int) -> Vector3:
	if _spots.is_empty():
		return Vector3(0, 0, -10)
	var ranked := _spots.duplicate()
	var near := func(s: Vector3) -> float:
		var best := INF
		for seat: int in [1, 2]:
			var p := _seat(seat)
			if p != null and is_instance_valid(p):
				best = minf(best, s.distance_to(p.global_position))
		return best
	ranked.sort_custom(func(a, b): return near.call(a) > near.call(b))
	var far: int = maxi(ranked.size() / 2, 1)
	return ranked[i % far]


func _fork(kind: String, i: int) -> Node3D:
	var targets := _targets()
	if targets == null:
		return null
	var slot := "w%d_%s_%d" % [wave, kind, i]
	var dummy = DummyScene.instantiate()
	dummy.name = "Coop_%s" % slot
	dummy.tag_text = TAGS[kind]
	dummy.respawns = false
	match kind:
		"zombie":
			dummy.art = ZombieArt
		"runaway":
			dummy.art = RunawayArt
		"boss":
			dummy.art = CoreArt
		_:
			dummy.art = RogueArt
	dummy.max_health = float(HEALTH[kind])
	dummy.seed_wanted = _seed_for(slot)
	dummy.set_meta(&"coop", slot)
	dummy.set_meta(&"world", true)  # its kills share the world modes' credit cap (W2)
	targets.add_child(dummy)
	var at: Vector3
	if kind == "boss":
		var arena := get_parent().get_node_or_null("Arena") as Node3D
		at = arena.to_global(BOSS_SPOT) if arena != null else BOSS_SPOT
	else:
		at = _spot_for(i) + Vector3(randf_range(-0.6, 0.6), 0.0, randf_range(-0.6, 0.6)) * (0.0 if _fixed() else 1.0)
	dummy.global_position = at
	var to: Vector3 = player.global_position - at if player != null and is_instance_valid(player) else Vector3.FORWARD
	dummy.rotation.y = atan2(-to.x, -to.z)
	if kind == "boss":
		dummy.resize_art(BOSS_SIZE)
		dummy.spawn_in(1.6)
	else:
		dummy.spawn_in(1.0)
	if dummy.brain != null:
		dummy.brain.dormant = false
		dummy.brain.relentless = kind != "boss"
	dummy.downed.connect(_on_downed)
	enemies.append({"body": dummy, "kind": kind, "wave": wave})
	spawned.emit(dummy)
	_forget()
	return dummy


func _fixed() -> bool:
	return OS.get_cmdline_user_args().has("--demo") or OS.get_cmdline_args().has("--script")


func _seed_for(slot: String) -> int:
	if _fixed():
		return DaemonArt.seed_of("coop:%s" % slot) & DaemonArt.SEED_LAST
	return randi() & DaemonArt.SEED_LAST


func _on_downed(dummy: Node3D) -> void:
	var by = dummy.get("struck_by")
	var seat := 0
	if by != null and is_instance_valid(by):
		seat = 2 if by == player2 else (1 if by == player else 0)
	if seat > 0:
		per[seat]["kills"] = int(per[seat]["kills"]) + 1
	for e in enemies:
		if e["body"] == dummy and e["kind"] == "boss":
			_note("boss", "the pegged core is down%s" % ((" (p%d)" % seat) if seat > 0 else ""))


## Who downed `dummy` (1, 2, or 0 for nobody): for the arena's kill credit (scripts/main.gd).
func killer_seat(dummy: Node) -> int:
	var by = dummy.get("struck_by") if dummy != null else null
	if by == null or not is_instance_valid(by):
		return 0
	return 2 if by == player2 else (1 if by == player else 0)


func standing() -> int:
	var n := 0
	for e in enemies:
		if _alive(e["body"]):
			n += 1
	return n


func boss() -> Node3D:
	for e in enemies:
		if e["kind"] == "boss" and is_instance_valid(e["body"]):
			return e["body"]
	return null


static func _alive(body) -> bool:
	return body != null and is_instance_valid(body) and (body.is_alive() or body.climbing())


# --- Every frame. ---

func _physics_process(delta: float) -> void:
	if not running:
		return
	if _online():
		end()  # a match started mid-run: the match's rules, the arena's own back
		return
	_clock += delta
	_phase_t += delta
	if phase != "results":
		stats["time"] = float(stats.get("time", 0.0)) + delta
	_step_lives(delta)
	_step_tiles()
	match phase:
		"ready":
			if _phase_t >= READY_S:
				_start_wave(wave + 1)
		"wave":
			_queue_t -= delta
			if not _queue.is_empty() and _queue_t <= 0.0:
				var kind: String = _queue.pop_front()
				_fork(kind, enemies.size())
				_queue_t = FORK_GAP_S
			_step_boss()
			if _queue.is_empty() and standing() == 0:
				_wave_cleared()
		"break":
			if _phase_t >= BREAK_S:
				_start_wave(wave + 1)
		"done", "wiped":
			if _phase_t >= DONE_S:
				_enter("results")
				_note("results", "results")
				_play("results")


func _wave_cleared() -> void:
	stats["waves"] = wave
	_all_back()
	_prune()
	if wave >= WAVES.size():
		stats["done"] = true
		_enter("done")
		_note("done", "every wave cleared: the core cooled")
		_play("clear")
	else:
		_enter("break")
		_note("clear", "wave %d cleared: everyone back, full" % wave)
		_play("clear")


func _prune() -> void:
	var keep: Array = []
	for e in enemies:
		if _alive(e["body"]):
			keep.append(e)
		elif is_instance_valid(e["body"]) and not e["body"].is_queued_for_deletion():
			e["body"].queue_free()
	enemies = keep
	_forget()


## The boss's heat: hotter as it is hurt.
func _step_boss() -> void:
	var b := boss()
	if b == null or not b.is_alive():
		return
	var art = b.art_node() if b.has_method("art_node") else null
	if art != null:
		var left := clampf(b.health() / float(HEALTH["boss"]), 0.0, 1.0)
		art.set("heat", lerpf(1.0, 0.55, left))


func _step_lives(delta: float) -> void:
	for seat: int in [1, 2]:
		var life: Dictionary = lives[seat]
		if life.is_empty():
			continue
		life["protect"] = maxf(float(life["protect"]) - delta, 0.0)
		life["hurt"] = maxf(float(life["hurt"]) - delta, 0.0)
		var p := _seat(seat)
		var st := str(life["state"])
		if st == "down" and phase != "results":
			life["bleed"] = float(life["bleed"]) - delta
			var partner: int = 3 - seat
			var q := _seat(partner)
			var near := up(partner) and p != null and q != null and is_instance_valid(p) and is_instance_valid(q) and _flat(p.global_position).distance_to(_flat(q.global_position)) <= REVIVE_M
			if near:
				life["revive"] = minf(float(life["revive"]) + delta / REVIVE_S, 1.0)
				_tick_t -= delta
				if _tick_t <= 0.0:
					_tick_t = 0.32
					_play("tick")
			else:
				life["revive"] = maxf(float(life["revive"]) - delta * REVIVE_DECAY, 0.0)
			if float(life["revive"]) >= 1.0:
				revive(seat, partner)
			elif float(life["bleed"]) <= 0.0:
				_bleed_out(seat)
		var goal := 0.0 if str(life["state"]) == "up" else 1.0
		life["slump"] = move_toward(float(life["slump"]), goal, delta * (2.2 if goal > 0.0 else 3.0))
		if p != null and is_instance_valid(p):
			p.slump = float(life["slump"])
			if p == player2 and player != null and is_instance_valid(player):
				player2.input_blocked = player.input_blocked  # the Esc menu, a text box: both players wait
		var body = _bodies[seat]
		if body != null and is_instance_valid(body):
			body.slump = float(life["slump"])
			body.revive = float(life["revive"])


static func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


## The tiles' moments from the lives, and the tile keys.
func _step_tiles() -> void:
	if screen == null:
		return
	for seat: int in [1, 2]:
		var life: Dictionary = lives[seat]
		screen.down[seat] = float(life.get("slump", 0.0))
		screen.hurt[seat] = float(life.get("hurt", 0.0)) / HURT_S
		var st := str(life.get("state", ""))
		screen.status[seat] = "Stopped" if st == "down" else ("Killed" if st == "out" else ("wave %d/%d" % [wave, WAVES.size()] if wave > 0 else "ready"))
		if not _can_press(seat):
			continue
		var keys: Dictionary = CoopInput.TILE[seat]
		if Input.is_action_just_pressed(keys["grow"]):
			screen.grow(seat)
		elif Input.is_action_just_pressed(keys["shrink"]):
			screen.shrink(seat)
		if Input.is_action_just_pressed(keys["flip"]):
			screen.flip(seat)


func _can_press(seat: int) -> bool:
	var p := _seat(seat)
	return p != null and is_instance_valid(p) and p.get("input_blocked") != true and CoopInput.made()


func _on_moved(seat: int, what: String) -> void:
	var share := screen.share_of(seat)
	var tr := CoopScreen.trade_for(share)
	_note("tile", "p%d %s: %d%%  aim x%.2f  spread x%.2f" % [seat, what, int(round(share * 100.0)), tr["aim"], tr["steady"]])
	_play("flip" if what == "flip" else what)


## Plays the run again (the results card's Enter): everyone back at the start, full.
func again() -> void:
	if phase != "results":
		return
	var spawn := get_parent().get_node_or_null("Arena/Spawns/S1") as Node3D
	if spawn != null:
		player.respawn_at(spawn.global_position)
		player2.respawn_at(spawn.global_position + player.global_basis * P2_OFFSET)
	_all_back()
	_start_run()
	_note("again", "again")


func _unhandled_input(ev: InputEvent) -> void:
	if running and phase == "results" and ev.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		again()


func _enter(next: String) -> void:
	phase = next
	_phase_t = 0.0


func _play(id: String) -> void:
	if _sfx == null or not _sfx.is_inside_tree():
		return
	_sfx.stream = CoopSound.of(id)
	_sfx.play()


func _note(kind: String, text: String) -> void:
	events.append({"t": _clock, "kind": kind, "text": text})
	while events.size() > 6:
		events.pop_front()
	event.emit(kind, text)


## Each player's accuracy this run: hits over shots (0 with no shot).
func accuracy(seat: int) -> float:
	var p := _seat(seat)
	if p == null or not is_instance_valid(p) or per[seat].is_empty():
		return 0.0
	var shots := int(p.shots_fired) - int(per[seat]["shots0"])
	var hits := int(p.hits_landed) - int(per[seat]["hits0"])
	return float(hits) / float(shots) if shots > 0 else 0.0


func shots(seat: int) -> int:
	var p := _seat(seat)
	if p == null or not is_instance_valid(p) or per[seat].is_empty():
		return 0
	return int(p.shots_fired) - int(per[seat]["shots0"])


## The results card's lines (for the HUD and the checks).
func result_lines() -> PackedStringArray:
	var out := PackedStringArray()
	out.append("WIPED ON WAVE %d/%d" % [wave, WAVES.size()] if bool(stats.get("wiped", false)) else "ALL %d WAVES CLEARED" % WAVES.size())
	for seat: int in [1, 2]:
		var r: Dictionary = per[seat]
		out.append("p%d %s   kills %d   downs %d   revives %d   accuracy %d%% (%d shots)" % [seat, CoopScreen.PROMPT[seat], int(r.get("kills", 0)), int(r.get("downs", 0)), int(r.get("revives", 0)), int(round(accuracy(seat) * 100.0)), shots(seat)])
	var t := float(stats.get("time", 0.0))
	out.append("waves %d/%d   time %d:%02d" % [int(stats.get("waves", 0)), WAVES.size(), int(t) / 60, int(t) % 60])
	return out


# --- The visor's HUD in player 1's tile (C43's own, drawn inside the tile so it reads that tile's camera). ---

func _take_visor_hud() -> void:
	if hud == null or not is_instance_valid(hud) or not hud.has_method("visor_hud") or screen == null:
		return
	var v = hud.visor_hud()
	if v == null or not is_instance_valid(v):
		return
	_visor_hud = v
	_visor_hud_parent = v.get_parent()
	v.reparent(screen.port(1), false)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _give_visor_hud() -> void:
	if _visor_hud != null and is_instance_valid(_visor_hud) and _visor_hud_parent != null and is_instance_valid(_visor_hud_parent):
		_visor_hud.reparent(_visor_hud_parent, false)
		_visor_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var at := _visor_hud_parent.get_child_count() - 1
		for i in _visor_hud_parent.get_child_count():
			if _visor_hud_parent.get_child(i).name == "MissionHud":
				at = i
				break
		_visor_hud_parent.move_child(_visor_hud, at)
	_visor_hud = null
	_visor_hud_parent = null


func _process(_delta: float) -> void:
	if not running or screen == null:
		return
	# The visor's lines only in player 1's tile.
	if visor != null and is_instance_valid(visor):
		for child in visor.get_children():
			CoopScreen.set_layers(child, CoopScreen.VISOR)


# --- The arena's own daemons. ---

func _targets() -> Node3D:
	var host := get_parent()
	var t = host.get_node_or_null("Arena/Targets") if host != null else null
	return t as Node3D if t != null else (host as Node3D)


func _clear_enemies() -> void:
	for e in enemies:
		var body = e["body"]
		if is_instance_valid(body) and not body.is_queued_for_deletion():
			body.queue_free()
	enemies.clear()
	_forget()


func _forget() -> void:
	if director != null and is_instance_valid(director):
		director.forget_brains()


func _park_arena_daemons() -> void:
	var host := get_parent()
	for dummy in get_tree().get_nodes_in_group("targets"):
		if host != null and host.is_ancestor_of(dummy) and not dummy.has_meta(&"coop"):
			dummy.remove_from_group("targets")
			_parked.append([dummy, dummy.get_parent(), dummy.collision_layer])
			dummy.process_mode = Node.PROCESS_MODE_DISABLED
			dummy.visible = false
			dummy.collision_layer = 0
			dummy.reparent(self)
	_forget()
	for driver in get_tree().get_nodes_in_group(&"code_rain_driver"):
		if driver.has_method("invalidate"):
			driver.invalidate()


func _release_parked() -> void:
	for entry in _parked:
		var dummy: Node3D = entry[0]
		if not is_instance_valid(dummy) or not is_instance_valid(entry[1]):
			continue
		dummy.reparent(entry[1])
		dummy.collision_layer = entry[2]
		dummy.visible = true
		dummy.process_mode = Node.PROCESS_MODE_INHERIT
		dummy.add_to_group("targets")
	_parked.clear()


func leave() -> void:
	if _going:
		return
	_going = true
	clear()
	SceneTear.reload_scene(get_tree(), "$ exit")


static func going() -> bool:
	return _going
