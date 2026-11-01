class_name ThemeShift
extends Node3D
## Theme-shift levels (W3, PRD 5.5; the third of M5's world features): a run of levels, each in a terminal theme's
## colours and in a world of its own, the theme shifting under the player with a palette tear. Reached from the Esc menu
## ("Theme shift"; "Leave theme shift" ends it), or with --themes on a demo or test run. Made by the arena (scripts/
## main.gd) beside the directors; it begins when queued. The regular arena never shifts: only this mode does.
##
## A level is a theme (scripts/themes/theme_book.gd): its district, made at play, stood in as the arena loads (prepare()),
## and the whole frame graded in its colours (scripts/themes/theme_grade.gd). It plays in two parts:
##   fight   its daemons (the arena's own kinds, a few more each level) and its palette-only daemons (scripts/daemons/
##           conceal_daemon.gd) keyed to this theme, shown and fighting; the ones keyed to the NEXT theme lurk concealed
##           among them, rippling and chirping, out of reach and harmless. It ends when every fighting one is down, or
##           when the theme's time is up (FIGHT_S).
##   shift   `export THEME=<next>` types itself, and the next theme tears in across the screen over SHIFT_S: the sky, the
##           floor, the ruins (their register shifts with it, tearing), the HUD, the daemons, the weapons' light. Halfway,
##           the lurkers print themselves in and wake; any of this theme's still standing conceal and sleep.
##   ambush  the woken lurkers and two more of the arena's kind, in the old district in the new colours. It ends when
##           they are down, or after AMBUSH_S. Then the world follows its theme: the frame tears away (scripts/fx/
##           scene_tear.gd) and the arena reloads into the next theme's own district.
## The last level's shift goes round to the first theme, and its ambush ends the run on a results card (each theme, its
## kills, the concealed caught and the ones that slipped away, its time). Enter plays it again.
##
## Two layers, as the visor's, the hunt's and the folder map's:
##   demo  the default, and the only layer the tests and captures use: the game's six built-in palettes.
##   real  opt-in, behind the same answer as the opener's real data (opener data, real-machine data on, never a demo
##         run): one more level after the six, in the player's own Omarchy theme, its colours read by scripts/themes/
##         theme_reader.gd (the opener's read: `#rrggbb` and the mode, capped; nothing else). Off, nothing is read.
## Nothing here writes, switches or runs anything: the player's real theme and desktop are never touched.

const DummyScene = preload("res://scenes/target_dummy.tscn")
const RogueArt = preload("res://scripts/daemons/rogue_daemon.gd")
const ZombieArt = preload("res://scripts/daemons/zombie_process.gd")
const RunawayArt = preload("res://scripts/daemons/runaway_swarm.gd")
const ConcealArt = preload("res://scripts/daemons/conceal_daemon.gd")
const Palette = preload("res://scripts/palette.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")

const GROUP := &"theme_shift"
const NODE_NAME := "ThemeShift"
## The dev and test flag that begins it as the arena loads (with --demo, or under --script).
const FLAG := "--themes"
const GATE_EVERY_S := 2.0
## How long a theme holds in its fight, how long the ambush may run, how long the shift's line types before the tear.
const FIGHT_S := 75.0
const AMBUSH_S := 60.0
const TYPE_S := 0.45
## When in the tear the lurkers wake (and the old theme's conceal), as a share of it.
const WAKE_AT := 0.5
## A level's roster: the arena's daemons at the first level and how many more every two; its own conceal; the lurkers;
## the ambush's extra; the most at once.
const DAEMONS_FIRST := 3
const OWN_CONCEAL := [1, 1, 1, 2, 2, 2, 2]
const LURKERS := [2, 2, 2, 3, 3, 3, 3]
const AMBUSH_DAEMONS := 2
const MOST_ENEMIES := 10
## A concealed lurker drifts round its home: this far, this fast (radians a second).
const DRIFT_M := 1.6
const DRIFT_TURN := 0.22
const TAGS := {"rogue": "rogue.d", "zombie": "zombie", "runaway": "runaway"}
const CONCEAL_TAG := "conceal"
const EVENTS_KEPT := 5
## The visor's mark round a concealed one (a selection box, as selecting hidden text shows it): its half size, metres.
const MARK_HALF := Vector2(1.05, 1.65)

## Queued for the next arena (the Esc menu, the flag); kept while it runs, so its reloads stay in it. Its run (theme
## ids), the level it is on, the player's own palette (the real layer's; null on demo), its layer, every level's numbers.
static var queued := false
static var run := PackedStringArray()
static var level := 0
static var yours: OpenerPalette = null
static var layer := "demo"
static var stats: Array = []
## For the tests: the gate and a fake home (kept across reloads, as the mode is); unset in the game. And the clocks,
## shortened by a test.
static var gate: Callable
static var home_root := ""
static var fight_s := FIGHT_S
static var ambush_s := AMBUSH_S
static var _flag_taken := false
static var _going := false
static var _misses := 0
const MISSES_MOST := 2

signal began
signal ended
## An enemy came in (the arena counts it as its own: a kill toward sudo, the top table).
signal spawned(dummy: Node3D)
signal event(kind: String, text: String)
signal shifted(from: String, to: String)

var running := false
## Set by the arena.
var player: Node3D = null
var director: DaemonDirector = null
var runner: MissionRunner = null
var ice: Node = null
var rounds: Node = null
var guide: Node = null
var visor: Node = null
var world: RuinsWorld = null
var grade: ThemeGrade = null
## "fight", "shift", "ambush", "results"; the theme on screen now, and the one a shift tears in.
var phase := ""
var theme := ""
var next_theme := ""
var looks := {}
## Its enemies: {body, kind ("rogue", "zombie", "runaway", "conceal"), key (a conceal's theme), home, phased, mark}.
var enemies: Array = []
var events: Array = []
## The shift's own clock; whether its lurkers woke this shift.
var shift_t := 0.0
var _woke := false
var _parked: Array = []
var _hud: CanvasLayer = null
var _lines: VisorLines = null
var _clock := 0.0
var _phase_t := 0.0
var _gate_wait := 0.0
var _whoosh: AudioStreamPlayer = null


## The mode of the arena `node` is (its own child), else any standing one not on its way out.
static func of(node: Node) -> ThemeShift:
	if node == null or not node.is_inside_tree():
		return null
	var mine := node.get_node_or_null(NODE_NAME) as ThemeShift
	if mine != null:
		return mine
	for m in node.get_tree().get_nodes_in_group(GROUP):
		if not m.is_queued_for_deletion():
			return m as ThemeShift
	return null


## The mode as the next arena loads, from its first level.
static func queue() -> void:
	queued = true
	level = 0
	run = PackedStringArray()
	stats = []


## Out of the mode: the player's palette let go.
static func clear() -> void:
	queued = false
	level = 0
	run = PackedStringArray()
	stats = []
	yours = null
	layer = "demo"


## --themes (with --demo, or under --script): queued once a run.
static func take_flag(args: PackedStringArray) -> void:
	if _flag_taken:
		return
	_flag_taken = true
	if args.has(FLAG) and (args.has("--demo") or OS.get_cmdline_args().has("--script")):
		queue()


## As the arena loads, before it is staged (scripts/main.gd, after the folder map's): the district of the level it is on,
## queued for the stage, when it is queued, alone and with no mission. `real` is the visor's gate for this run.
static func prepare(args: PackedStringArray, online: bool, real: bool) -> void:
	take_flag(args)
	_going = false
	if not queued or online or MissionRunner.pending() != "":
		return
	ensure_run(bool(gate.call()) if gate.is_valid() else real)
	RuinsStage.queue_set(ThemeBook.set_for(run[level]))


## The run for this layer: the six built-in themes, and (real, when the player's theme reads) theirs after them. A layer
## change starts the run again.
static func ensure_run(real: bool) -> void:
	var want := "real" if real else "demo"
	if not run.is_empty() and layer == want:
		return
	layer = want
	yours = null
	if real:
		yours = ThemeReader.read(home_root if home_root != "" else OS.get_environment("HOME"))
	run = ThemeBook.run_ids(yours != null)
	level = clampi(level, 0, run.size() - 1) if not run.is_empty() else 0
	if stats.size() > level:
		stats = stats.slice(0, level)


func _ready() -> void:
	name = NODE_NAME
	add_to_group(GROUP)


func real_allowed() -> bool:
	if gate.is_valid():
		return bool(gate.call())
	var link = guide.session_link() if guide != null and is_instance_valid(guide) and guide.has_method("session_link") else null
	return AuditVisor.real_gate_for(link)


## The look of theme `id` (made once a run of the mode).
func look_of(id: String) -> ThemeLook:
	if not looks.has(id):
		looks[id] = ThemeLook.of(ThemeBook.palette_of(id, yours).readable())
	return looks[id]


## Begins the level it is on: the arena's own daemons parked, ICE stood down, the rounds held; the frame graded in the
## level's theme, its roster in. False online or in a mission.
func begin() -> bool:
	if running or _online() or (runner != null and is_instance_valid(runner) and runner.running()):
		return false
	ensure_run(real_allowed())
	running = true
	queued = true
	world = _world()
	if world == null or world.ruins == null or world.ruins.id != ThemeBook.set_id(run[level]):
		# Not stood in its district yet (a plain arena, or a layer change): there first, given up past MISSES_MOST loads.
		running = false
		_misses += 1
		if _misses > MISSES_MOST:
			_misses = 0
			clear()
			return false
		_go("$ reset  # " + ThemeBook.slug_of(run[level]))
		return false
	_misses = 0
	_park_arena_daemons()
	if ice != null and is_instance_valid(ice) and "stand_down" in ice:
		ice.stand_down = true
	if rounds != null and is_instance_valid(rounds) and rounds.has_method("hold"):
		rounds.hold(true)
	theme = run[level]
	for id in run:
		look_of(id)  # every look made now: a shift changes numbers, never a material
	grade = ThemeGrade.new()
	add_child(grade)
	grade.show_theme(look_of(theme))
	if level > 0:
		grade.full()  # the run is in its themes already: only its first level eases in
	_hud = ThemeShiftHud.new()
	_hud.mode = self
	add_child(_hud)
	_lines = VisorLines.new()
	add_child(_lines)
	_whoosh = AudioStreamPlayer.new()
	_whoosh.name = "Tear"
	_whoosh.stream = _tear_sound()
	_whoosh.bus = SettingsApply.EFFECTS if AudioServer.get_bus_index(SettingsApply.EFFECTS) >= 0 else &"Master"
	add_child(_whoosh)
	while stats.size() <= level:
		stats.append({"theme": run[stats.size()], "kills": 0, "caught": 0, "slipped": 0, "time": 0.0})
	_spawn_fight()
	_enter("fight")
	_note("theme", "%s  (%s)" % [ThemeBook.name_of(theme), look_of(theme).palette.mode])
	began.emit()
	return true


## Ends the mode where it stands (a match starting, the Esc menu's way out): its enemies gone, the arena's own back, ICE
## and the rounds as they were, the grade gone. Not queued any more.
func end() -> void:
	if not running:
		return
	running = false
	for e in enemies:
		var body = e["body"]
		if is_instance_valid(body) and not body.is_queued_for_deletion():
			body.queue_free()
	enemies.clear()
	_release_parked()
	if ice != null and is_instance_valid(ice) and "stand_down" in ice:
		ice.stand_down = false
	if rounds != null and is_instance_valid(rounds) and rounds.has_method("hold"):
		rounds.hold(false)
	if director != null and is_instance_valid(director):
		director.forget_brains()
	for node in [_hud, grade, _lines]:
		if node != null and is_instance_valid(node):
			node.queue_free()
	_hud = null
	grade = null
	_lines = null
	clear()
	ended.emit()


func _world() -> RuinsWorld:
	var host := get_parent()
	return host.get_node_or_null("Arena/" + RuinsWorld.NODE_NAME) as RuinsWorld if host != null else null


func _online() -> bool:
	var session = director.session if director != null and is_instance_valid(director) else null
	return session != null and is_instance_valid(session) and session.has_method("is_online") and session.is_online()


# --- The roster. ---

## The fight's roster: the arena's daemons, this theme's own conceal, the next theme's lurkers.
func _spawn_fight() -> void:
	var spots := _spots()
	var k := level
	var count := mini(DAEMONS_FIRST + k / 2, MOST_ENEMIES)
	var kinds := _kinds(count, "%s:%d" % [run[level], level])
	var at := 0
	for i in kinds.size():
		if at < spots.size():
			_spawn_daemon(kinds[i], spots[at], "fight_%d" % i)
			at += 1
	for i in OWN_CONCEAL[mini(k, OWN_CONCEAL.size() - 1)]:
		if at < spots.size() and enemies.size() < MOST_ENEMIES:
			_spawn_conceal(theme, spots[at], true, "own_%d" % i)
			at += 1
	var next := _next_id()
	for i in LURKERS[mini(k, LURKERS.size() - 1)]:
		if at < spots.size() and enemies.size() < MOST_ENEMIES:
			_spawn_conceal(next, spots[at], false, "lurk_%d" % i)
			at += 1


## The ambush's extra: the arena's kind, out of the floor where the fight's started.
func _spawn_ambush() -> void:
	var spots := _spots()
	var kinds := _kinds(AMBUSH_DAEMONS, "%s:%d:ambush" % [run[level], level])
	for i in kinds.size():
		if enemies.size() >= MOST_ENEMIES:
			break
		_spawn_daemon(kinds[i], spots[(i * 5 + 1) % maxi(spots.size(), 1)] if not spots.is_empty() else Vector3.ZERO, "ambush_%d" % i)


func _spots() -> Array:
	var out: Array = []
	if world == null:
		return out
	for p in world.points_of("daemon") + world.points_of("breaker"):
		out.append(p)
	return out


## `count` of the arena's kinds, seeded by `key`: as many rogue.d as the others, a zombie and a runaway among them.
func _kinds(count: int, key: String) -> PackedStringArray:
	var out := PackedStringArray()
	var order := ["rogue", "zombie", "runaway", "rogue", "runaway", "zombie", "rogue"]
	var roll := absi(hash(key)) % order.size()
	for i in count:
		out.append(order[(roll + i) % order.size()])
	return out


func _spawn_daemon(kind: String, at: Vector3, slot: String) -> Node3D:
	var targets := _targets()
	if targets == null:
		return null
	var dummy = DummyScene.instantiate()
	dummy.name = "Theme_%s" % slot
	dummy.tag_text = TAGS[kind]
	dummy.respawns = false
	dummy.art = ZombieArt if kind == "zombie" else (RunawayArt if kind == "runaway" else RogueArt)
	dummy.seed_wanted = _seed_for(slot, false)
	dummy.set_meta(&"theme_shift", slot)
	dummy.set_meta(&"world", true)  # its kills share the world modes' credit cap (W2)
	targets.add_child(dummy)
	dummy.global_position = at
	dummy.spawn_in(1.1)
	_face_player(dummy)
	dummy.downed.connect(_on_downed)
	enemies.append({"body": dummy, "kind": kind, "key": "", "home": at, "phased": false, "mark": null})
	spawned.emit(dummy)
	_forget()
	return dummy


## A palette-only daemon keyed to theme `key`, shown (fighting) or concealed (lurking: out of reach, asleep).
func _spawn_conceal(key: String, at: Vector3, shown: bool, slot: String) -> Node3D:
	var targets := _targets()
	if targets == null:
		return null
	var dummy = DummyScene.instantiate()
	dummy.name = "Theme_%s" % slot
	dummy.tag_text = CONCEAL_TAG
	dummy.respawns = false
	dummy.art = ConcealArt
	dummy.seed_wanted = _seed_for(slot + ":" + key, true)
	dummy.set_meta(&"theme_shift", slot)
	dummy.set_meta(&"conceal", key)
	dummy.set_meta(&"world", true)
	targets.add_child(dummy)
	dummy.global_position = at
	_face_player(dummy)
	var art = dummy.art_node()
	art.key = key
	art.set_shown(shown, true)
	var e := {"body": dummy, "kind": "conceal", "key": key, "home": at, "phased": false, "mark": null}
	enemies.append(e)
	dummy.downed.connect(_on_downed)
	if shown:
		dummy.spawn_in(1.1)
	else:
		_phase(e, true)
	spawned.emit(dummy)
	_forget()
	return dummy


## Its build seed: fixed by its slot and level on demo and test runs (the same run every run), else rolled; a conceal is
## an elite one in twelve (its own rule), the arena's kinds too.
func _seed_for(slot: String, _conceal: bool) -> int:
	if _fixed_seeds():
		return DaemonArt.seed_of("themes:%s:%d:%s" % [run[level], level, slot]) & DaemonArt.SEED_LAST
	return randi() & DaemonArt.SEED_LAST


static func _fixed_seeds() -> bool:
	return OS.get_cmdline_user_args().has("--demo") or OS.get_cmdline_args().has("--script")


func _face_player(dummy: Node3D) -> void:
	if player != null and is_instance_valid(player):
		var to: Vector3 = player.global_position - dummy.global_position
		dummy.rotation.y = atan2(-to.x, -to.z)


## A conceal out of phase (concealed: no volume, out of the targets, its brain asleep, its tag hidden; nothing reaches it
## and it reaches nothing) or back in (its volume, a target again, awake and hunting).
func _phase(e: Dictionary, out: bool) -> void:
	var body = e["body"]
	if not is_instance_valid(body) or bool(e["phased"]) == out:
		return
	e["phased"] = out
	if out:
		e["layer"] = body.collision_layer if int(body.collision_layer) != 0 else e.get("layer", 1)
		body.collision_layer = 0
		body.remove_from_group("targets")
		body.sealed = true
		body.hide_tag(true)
		if body.brain != null:
			body.brain.dormant = true
	else:
		body.collision_layer = int(e.get("layer", body.collision_layer if int(body.collision_layer) != 0 else 1))
		body.add_to_group("targets")
		body.sealed = false
		body.hide_tag(false)
		if body.brain != null:
			body.brain.take_home()
			body.brain.dormant = false
			if director != null and is_instance_valid(director):
				body.brain.alert(director)
	_forget()


func _forget() -> void:
	if director != null and is_instance_valid(director):
		director.forget_brains()


func _on_downed(dummy: Node3D) -> void:
	if level >= stats.size():
		return
	var s: Dictionary = stats[level]
	if dummy.has_meta(&"conceal"):
		s["caught"] = int(s["caught"]) + 1
		_note("caught", "caught a conceal (%s)" % ThemeBook.name_of(str(dummy.get_meta(&"conceal"))))
	else:
		s["kills"] = int(s["kills"]) + 1


# --- The level's parts. ---

func _enter(next: String) -> void:
	phase = next
	_phase_t = 0.0


func _next_id() -> String:
	return run[(level + 1) % run.size()]


## The fighting ones still standing (or still climbing in): the arena's kinds, every conceal shown and every one printing
## itself in.
func fighting() -> int:
	var n := 0
	for e in enemies:
		var body = e["body"]
		if _standing(body) and (not bool(e["phased"]) or _waking(e)):
			n += 1
	return n


## Concealed ones still lurking (not waking).
func lurking() -> int:
	var n := 0
	for e in enemies:
		var body = e["body"]
		if _standing(body) and bool(e["phased"]) and not _waking(e):
			n += 1
	return n


static func _standing(body) -> bool:
	return is_instance_valid(body) and (body.is_alive() or body.climbing())


static func _waking(e: Dictionary) -> bool:
	var body = e["body"]
	return str(e["kind"]) == "conceal" and is_instance_valid(body) and body.art_node() != null and bool(body.art_node().shown_wanted)


## Seconds the theme holds before it shifts anyway (the fight's), or the ambush has left.
func time_left() -> float:
	if phase == "fight":
		return maxf(fight_s - _phase_t, 0.0)
	if phase == "ambush":
		return maxf(ambush_s - _phase_t, 0.0)
	return 0.0


## The shift: `export THEME=<next>` typed, then the tear; the register with it.
func shift() -> void:
	if phase != "fight":
		return
	next_theme = _next_id()
	_enter("shift")
	shift_t = 0.0
	_woke = false
	_note("shift", "$ export THEME=%s" % ThemeBook.slug_of(next_theme))


func _step_shift(delta: float) -> void:
	shift_t += delta
	if shift_t < TYPE_S:
		return
	if grade != null and not grade.tearing() and grade.look != look_of(next_theme):
		grade.shift_to(look_of(next_theme), float(level) * 1.37 + 0.5)
		if world != null:
			world.set_register(str(ThemeBook.WORLDS.get(next_theme, ThemeBook.WORLDS[ThemeBook.YOURS])["register"]), ThemeGrade.SHIFT_S, true)
		if _whoosh != null and _whoosh.is_inside_tree():
			_whoosh.play()
	if not _woke and grade != null and grade.tear >= WAKE_AT:
		_woke = true
		for e in enemies:
			if str(e["kind"]) != "conceal":
				continue
			var body = e["body"]
			if not is_instance_valid(body) or not body.is_alive():
				continue
			var art = body.art_node()
			if str(e["key"]) == next_theme:
				art.set_shown(true)
			elif bool(art.shown_wanted):
				art.set_shown(false)
				_phase(e, true)  # this theme's own conceal hides with it, at once out of reach
	if grade != null and not grade.tearing() and grade.look == look_of(next_theme):
		var from := theme
		theme = next_theme
		next_theme = ""
		shifted.emit(from, theme)
		_note("theme", "%s  (%s)" % [ThemeBook.name_of(theme), look_of(theme).palette.mode])
		_spawn_ambush()
		_enter("ambush")


## The level done: its slipped counted, then the next theme's own world (a reload behind the tear), or the results.
func _level_done() -> void:
	var s: Dictionary = stats[level]
	s["slipped"] = lurking() + _concealed_standing()
	_enter("out")
	if level >= run.size() - 1:
		_enter("results")
		_note("done", "theme shift complete")
		return
	level += 1
	_go("$ reset  # " + ThemeBook.slug_of(run[level]))


func _concealed_standing() -> int:
	var n := 0
	for e in enemies:
		var body = e["body"]
		if str(e["kind"]) == "conceal" and _standing(body) and not bool(e["phased"]):
			n += 1
	return n


## Plays the run again from its first level (the results card's Enter).
func again() -> void:
	if phase != "results":
		return
	level = 0
	stats = []
	_go("$ reset  # " + ThemeBook.slug_of(run[0]))


func _go(label: String) -> void:
	if _going:
		return
	_going = true
	_note("go", label)
	SceneTear.reload_scene(get_tree(), label)


## Out of the mode, back to the plain arena.
func leave() -> void:
	if _going:
		return
	_going = true
	clear()
	SceneTear.reload_scene(get_tree(), "$ exit")


func _physics_process(delta: float) -> void:
	if not running:
		return
	if _online():
		end()  # a match started mid-run: the match's rules, the arena's own daemons back
		return
	_clock += delta
	_phase_t += delta
	_gate_wait -= delta
	if _gate_wait <= 0.0:
		_gate_wait = GATE_EVERY_S
		if (layer == "real") != real_allowed() and not _going:
			ensure_run(real_allowed())  # the answer changed: the run starts again in the other layer
			level = 0
			stats = []
			_go("$ reset  # " + ThemeBook.slug_of(run[0]))
			return
	if level < stats.size() and phase != "results":
		stats[level]["time"] = float(stats[level]["time"]) + delta
	_step_lurkers(delta)
	match phase:
		"fight":
			if fighting() == 0 or _phase_t >= fight_s:
				shift()
		"shift":
			_step_shift(delta)
		"ambush":
			if fighting() == 0 or _phase_t >= ambush_s:
				_level_done()


## Lurkers drift round their homes (their ripple moves); a shown conceal comes back into reach once it has printed in.
func _step_lurkers(delta: float) -> void:
	for e in enemies:
		if str(e["kind"]) != "conceal":
			continue
		var body = e["body"]
		if not is_instance_valid(body) or not body.is_alive():
			continue
		var art = body.art_node()
		if bool(e["phased"]):
			if art != null and art.shown_wanted and art.reveal >= 1.0:
				_phase(e, false)
				continue
			var a := _clock * DRIFT_TURN + float(hash(str(e["home"]))) * 0.001
			var home: Vector3 = e["home"]
			body.global_position = body.global_position.lerp(home + Vector3(cos(a), 0.0, sin(a)) * DRIFT_M, minf(delta * 1.5, 1.0))
			if body.brain != null:
				body.brain.dormant = true


func _process(delta: float) -> void:
	if not running:
		return
	if grade != null:
		grade.step(delta)
	_draw_visor()


func _unhandled_input(ev: InputEvent) -> void:
	if running and phase == "results" and ev.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		again()


# --- The visor. ---

## Under the visor (I) a concealed one is marked as selected hidden text shows: a box round it and its theme over it,
## seen through walls. The shown ones are the visor's own (lineage and tags, as every daemon's).
func visor_on() -> bool:
	return visor != null and is_instance_valid(visor) and bool(visor.get("on"))


func _draw_visor() -> void:
	if _lines == null:
		return
	var on := visor_on()
	var lines: Array = []
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	for e in enemies:
		if str(e["kind"]) != "conceal":
			continue
		var body = e["body"]
		var alive: bool = is_instance_valid(body) and body.is_alive()
		var hidden: bool = alive and bool(e["phased"])
		var mark = e.get("mark")
		if on and hidden and cam != null:
			var mid: Vector3 = body.threat_point() + Vector3(0.0, 0.5, 0.0)
			var right: Vector3 = cam.global_transform.basis.x
			var up: Vector3 = cam.global_transform.basis.y
			lines.append_array(_box(mid, right, up))
			if mark == null or not is_instance_valid(mark):
				mark = _mark_label()
				e["mark"] = mark
			mark.text = "\\e[8m concealed\nshows in %s" % ThemeBook.name_of(str(e["key"]))
			mark.visible = true
			mark.global_position = mid + up * (MARK_HALF.y + 0.35)
		elif mark != null and is_instance_valid(mark):
			mark.visible = false
	_lines.draw(lines, [])


## A selection box's corners (eight short strokes) round `mid`, facing the camera.
func _box(mid: Vector3, right: Vector3, up: Vector3) -> Array:
	var out: Array = []
	var w := MARK_HALF.x
	var h := MARK_HALF.y
	var arm := 0.45
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var corner: Vector3 = mid + right * w * sx + up * h * sy
			out.append(_line(corner, corner - right * arm * sx, 0.9))
			out.append(_line(corner, corner - up * arm * sy, 0.9))
	return out


func _line(a: Vector3, b: Vector3, heat: float) -> Dictionary:
	return {"a": a, "b": b, "heat": heat, "width": 0.06, "grown": 1.0, "phase": 0.0, "burn": 0.0, "bright": 1.2, "depth": 0.0, "lift": 0.0}


func _mark_label() -> Label3D:
	var l := Label3D.new()
	l.name = "ConcealMark"
	l.font = Palette.mono_font()
	l.font_size = 44
	l.pixel_size = 0.008
	l.outline_size = 10
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.modulate = Palette.HOSTILE_AMBER.lerp(Color.WHITE, 0.2) * 1.4
	l.shaded = false
	l.no_depth_test = true
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	return l


# --- The arena's own daemons. ---

func _targets() -> Node3D:
	var host := get_parent()
	var t = host.get_node_or_null("Arena/Targets") if host != null else null
	return t as Node3D if t != null else (host as Node3D)


func _park_arena_daemons() -> void:
	var host := get_parent()
	for dummy in get_tree().get_nodes_in_group("targets"):
		if host != null and host.is_ancestor_of(dummy) and not dummy.has_meta(&"theme_shift"):
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


# --- The tear's sound. ---

## A tape-stop sweep with a crackle of glitch over it, made once: the theme tearing.
static var _tear_wav: AudioStreamWAV = null


static func _tear_sound() -> AudioStreamWAV:
	if _tear_wav != null:
		return _tear_wav
	var rate := 22050
	var seconds := ThemeGrade.SHIFT_S + 0.3
	var count := int(seconds * rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4096
	var phase_a := 0.0
	var phase_b := 0.0
	var hold := 0.0
	for i in count:
		var u := float(i) / count
		var f := lerpf(1400.0, 90.0, pow(u, 0.6))
		phase_a = fmod(phase_a + TAU * f / rate, TAU)
		phase_b = fmod(phase_b + TAU * f * 1.5 / rate, TAU)
		if i % 160 == 0:
			hold = rng.randf_range(-1.0, 1.0) if rng.randf() < 0.4 else 0.0
		var swell := sin(PI * minf(u * 1.25, 1.0))
		var v := (sin(phase_a) * 0.45 + signf(sin(phase_b)) * 0.12 + hold * 0.18) * swell * 0.6
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	_tear_wav = stream
	return stream


# --- For the HUD and the checks. ---

func _note(kind: String, text: String) -> void:
	events.append({"t": _clock, "kind": kind, "text": text})
	while events.size() > EVENTS_KEPT:
		events.pop_front()
	event.emit(kind, text)


func clock() -> float:
	return _clock


func phase_time() -> float:
	return _phase_t


static func going() -> bool:
	return _going
