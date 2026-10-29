extends SceneTree
## Headless fork bomb test for SIGKILL (C19). scripts/check.sh runs it, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/fork_bomb_test.gd
##
## The fork bomb, slot 4 and G (PRD 5.2, "grenade that splits 1, 2, 4, 8"): its two resources
## and their numbers, bad values refused, the scatter drawn from a seed; a scan that it runs
## nothing and that only the host ever judges a blast; G as a rebindable action, saved to a
## settings file in a temporary folder and loaded back. Then solo in the real arena with the
## real player: two bombs, a throw and a quick throw each spending one, none thrown with none
## left, both back at a round's start and at a new life; one throw makes exactly 1, 2, 4 and
## 8 blasts, 15 in all, and leaves no node behind; the callout; a full chain beside a daemon of
## 100 health in the open kills it and one blast does not; a wall between keeps every blast off;
## the live cap holds under spam. Then a host and a joiner over ENet on 127.0.0.1 in this one
## process: the joiner's throw is run and judged by the host, the joiner's screen draws the same
## scatter from the host's seed and goes off at the host's blasts, the kill feed names "fork
## bomb", the thrower is never hurt by its own bombs, forged throws (a far origin, the wrong aim,
## none left, the wrong types) are dropped and counted, a new life gives the bombs back, the
## host's live cap holds, and every node is freed. Nothing outside this process is touched:
## the fork bomb is fiction, nothing forks or runs.
##
## Every run throws the same chains. The game draws a new scatter seed for each throw; the
## test pins the seed source before each case (_pin()). The outcomes checked do not hang on
## the seed either: a player who must be hurt or killed is reached by the thrown bomb's own
## blast, whose place no seed moves; the case that may kill the joiner runs after the one
## that needs it alive; and the wall is wider than a chain can spread around. Nothing
## waits a frame count for the network: the host must have heard the joiner's newest place
## and look before it judges (_heard()), and each forged throw is waited for until the host
## has counted it.

const Session = preload("res://scripts/net/net_session.gd")
const Combat = preload("res://scripts/net/combat.gd")
const NetTuningScript = preload("res://scripts/net/net_tuning.gd")
const CombatTuningScript = preload("res://scripts/net/combat_tuning.gd")
const ForkBomb = preload("res://scripts/weapons/fork_bomb.gd")
const ForkBombTuningScript = preload("res://scripts/weapons/fork_bomb_tuning.gd")
const WeaponDefScript = preload("res://scripts/weapons/weapon_def.gd")
const Inventory = preload("res://scripts/weapons/inventory.gd")
const WeaponHud = preload("res://scripts/hud/weapon_hud.gd")
const RoundHud = preload("res://scripts/round/round_hud.gd")
const Controls = preload("res://scripts/controls.gd")
const Link = preload("res://scripts/guide/guide_link.gd")
const MainScene = preload("res://scenes/main.tscn")
const TUNING_PATH := "res://resources/fork_bomb.tres"
const WEAPON_PATH := "res://resources/fork_bomb_weapon.tres"
const WATCHDOG_MS := 10000
const CLIENT_OFFSET := Vector3(1000.0, 0.0, 0.0)
const STAND_Y := 0.95
## A clear line across the arena, from x -15 to the east wall at x 20.
const LINE_Z := 15.0
const SLOT := 3
## Where the joiner stands beside the host for the host's own throws: 1.7 m off, out of the
## bomb's path, and 2.3 m from where the thrown bomb itself goes off (2.6 m ahead of the
## host), so that blast alone, whatever the seed, takes 13: it kills the joiner from 10, and
## hurts it from 100 (the rest of the chain may kill it too; that case runs last).
const BESIDE := Vector3(1.0, 0.0, 1.4)
## Each case's scatter seed source, pinned.
const SEEDS := {"drawn": 1901, "quick": 1902, "wall": 1903, "spam": 1904, "joiner": 1905, "own": 1906, "second": 1907, "spent": 1908, "host_spam": 1909}

var _fails := 0
var _checks := 0
var _tmp := ""
var _t: Resource
var _w: Resource
var _arenas: Array = []
var _branches: Array = []


func _initialize() -> void:
	GameSettings.current().set_value("gameplay", "practice", true)  # these checks predate C27b: the daemons stay the old never-attack dummies
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_tmp = OS.get_temp_dir().path_join("sigkill-fork-bomb-test-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(_tmp)
	Controls.ensure()
	_t = load(TUNING_PATH)
	_w = load(WEAPON_PATH)
	_tuning_checks()
	_scatter_checks()
	_source_checks()
	_rebind_checks()
	await _solo_checks()
	await _match_checks()
	await _cleanup()
	for name in DirAccess.get_files_at(_tmp):
		DirAccess.remove_absolute(_tmp.path_join(name))
	DirAccess.remove_absolute(_tmp)
	print("FORK BOMB: %d checks" % _checks)
	print("FORK BOMB RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The resources. ---

func _tuning_checks() -> void:
	var t = _t
	_check("the chain's numbers are one resource, resources/fork_bomb.tres, a ForkBombTuning that passes its own checks", t is ForkBombTuningScript and t.problems().is_empty(), str(t.problems()) if t is ForkBombTuningScript else "")
	_check("its numbers: 4 generations (1, 2, 4, 8: 15 blasts), a 1.2 s fuse and 0.5 s for each child, a 4 m blast of 22 at the centre easing to 30% at the edge, 16 live bomblets a player at most", t.generations == 4 and t.blasts() == 15 and t.fuse_s == 1.2 and t.child_fuse_s == 0.5 and t.radius_m == 4.0 and t.damage == 22.0 and t.falloff_floor == 0.3 and t.live_cap == 16 and t.scatter_speed == 3.5 and t.throw_speed == 13.0)
	_check("one blast's damage: 22 at the centre, 6.6 at the edge, none past it; never 100", is_equal_approx(t.damage_at(0.0), 22.0) and is_equal_approx(t.damage_at(4.0), 6.6) and t.damage_at(4.01) == 0.0 and t.damage_at(-1.0) == 0.0 and t.damage < 100.0)
	var w = _w
	var shipped = load("res://resources/arsenal.tres")
	_check("the weapon is a WeaponDef in slot 4 of the arsenal: \"fork bomb\", thrown, 2 bombs and none in reserve, a 0.6 s throw interval, its own fork light skin, the kill feed's \"fork bomb\", the chain's resource as its projectile (five slots since C24's fork() shotgun, six since C25's grep, seven since C26's rm -rf, eight since C27's cron, nine since C28's ping, ten since C29's chmod 000, eleven since C30's pipe |, twelve since C31's /dev/null, thirteen since C32's SIGHUP)", w is WeaponDefScript and w.problems().is_empty() and w.id == "fork_bomb" and w.short_name == "fork bomb" and w.is_thrown() and w.magazine_size == 2 and w.reserve_ammo == 0 and w.fire_cooldown == 0.6 and w.light_skin == "fork" and w.kill_word == "fork bomb" and w.projectile == t and shipped.loadout.size() == 13 and shipped.loadout[SLOT] == w, str(w.problems()) if w is WeaponDefScript else "")
	var cases := [
		["generations", 5, "generations"], ["generations", 0, "generations"], ["fuse_s", 0.0, "fuse_s"], ["child_fuse_s", 20.0, "child_fuse_s"],
		["radius_m", 0.0, "radius_m"], ["damage", -1.0, "damage"], ["live_cap", 0, "live_cap"], ["ring_shrink", 2.0, "ring_shrink"],
		["scatter_spread_degrees", 120.0, "scatter_spread_degrees"], ["bounce", 1.5, "bounce"], ["gravity", NAN, "gravity"],
	]
	var missed := PackedStringArray()
	for c in cases:
		var bad = _t.duplicate()
		bad.set(c[0], c[1])
		if not ", ".join(bad.problems()).contains(c[2]):
			missed.append("%s=%s: %s" % [c[0], c[1], bad.problems()])
	var no_tuning = _w.duplicate()
	no_tuning.projectile = null
	var stray = load("res://resources/sigterm.tres").duplicate()
	stray.projectile = _t
	var five = _t.duplicate()
	five.generations = 4
	_check("bad values are refused with the reason: 5 generations (past 15 blasts) or none, fuses, radius, damage, the live cap, the ring, the spread, the bounce, NaN; a thrown weapon with no tuning, and a tuning on a weapon that is not thrown", missed.is_empty() and ", ".join(no_tuning.problems()).contains("needs a ForkBombTuning") and ", ".join(stray.problems()).contains("only a thrown weapon") and five.blasts() == 15, " | ".join(missed))


func _scatter_checks() -> void:
	var a := ForkBomb.scatter(_t, 4242, 1, 1)
	var b := ForkBomb.scatter(_t, 4242, 1, 1)
	var other := ForkBomb.scatter(_t, 4243, 1, 1)
	var sibling := ForkBomb.scatter(_t, 4242, 1, 0)
	var flat_a := Vector3(a[0].x, 0.0, a[0].z)
	var flat_b := Vector3(a[1].x, 0.0, a[1].z)
	_check("the scatter comes from the seed: the same seed and blast give the same two children's velocities, another seed or blast others", a == b and a != other and a != sibling and a.size() == 2)
	_check("the two children fly out from the blast in roughly opposite directions at the scatter speed, and up", is_equal_approx(flat_a.length(), _t.scatter_speed) and flat_a.angle_to(flat_b) > deg_to_rad(180.0 - 2.0 * _t.scatter_spread_degrees - 0.5) and a[0].y > 0.0 and a[1].y > 0.0, "%s %s" % [a[0], a[1]])


func _source_checks() -> void:
	var chain := _code("res://scripts/weapons/fork_bomb.gd")
	var real := PackedStringArray()
	for word in ["OS.", "FileAccess", "DirAccess", "create_process", "execute", "get_process_id", "Thread"]:
		if chain.contains(word):
			real.append(word)
	_check("the fork bomb is fiction: its chain runs, forks, reads and signals nothing real", real.is_empty(), ", ".join(real))
	_check("fifteen blasts at most per throw, whatever the tuning says; the last generation only goes off", chain.contains("if blasts >= Tuning.BLASTS_LAST:") and _body(chain, "_blast").contains("gen + 1 < Tuning.GENERATIONS_LAST") and ForkBombTuningScript.BLASTS_LAST == 15)
	var session := _code("res://scripts/net/net_session.gd")
	_check("the wire: protocol 5 then (6 since C20's light trails, 7 since C22's sudo, 8 since C23's top table, 9 since C25's grep marks, 10 since C27b's daemons, 11 since A5's daemon seeds, 12 since I1's ICE, 13 since I2's ICEbreakers, 14 since I3's Black ICE, 15 since C29's chmod 000, 16 since C30's pipe |, 17 since C31's /dev/null, 18 since C32's SIGHUP); the throw is an untyped, type-checked any-peer request; the seed and each blast are authority RPCs from the host", Session.PROTOCOL == 18 and session.contains('@rpc("any_peer", "call_remote", "reliable")\nfunc _throw(life: Variant, weapon: Variant, origin: Variant, dir: Variant) -> void:') and _body(session, "_throw").contains("typeof(life) != TYPE_INT or typeof(weapon) != TYPE_STRING or typeof(origin) != TYPE_VECTOR3 or typeof(dir) != TYPE_VECTOR3") and session.contains('@rpc("authority", "call_remote", "reliable")\nfunc _bomb(') and session.contains('@rpc("authority", "call_remote", "reliable")\nfunc _blast('))
	_check("only the host ever judges a blast: its chains decide and are judged by _judge_blast, which only runs hosting; a joiner's chain draws, with no judge", _body(session, "_handle_throw").contains("_spawn_chain(_throws, id, weapon, seed, origin, dir, true)") and _body(session, "_bomb").contains("_spawn_chain(throw_id, thrower, weapon, seed, origin, dir, false)") and _body(session, "_spawn_chain").contains("var judge := _judge_blast.bind(thrower, weapon) if deciding else Callable()") and _body(session, "_judge_blast").contains("if state != State.HOSTING or combat == null") and _body(session, "_judge_blast").contains("if id == thrower or not combat.alive(id):"))
	var combat := _code("res://scripts/net/combat.gd")
	_check("the host believes a throw only with a bomb left, the interval kept, under the live cap, from near the eye and along the aim; a shot intent naming the fork bomb is refused", _body(combat, "throw").contains("if a[\"mag\"] <= 0 and not root_now:\n\t\treturn _drop(DROP_EMPTY)") and _body(combat, "throw").contains("return _drop(DROP_LIVE)") and _body(combat, "throw").contains("return _drop(DROP_ORIGIN)") and _body(combat, "throw").contains("return _drop(DROP_AIM)") and _body(combat, "validate").contains("weapons[weapon].is_thrown()"))


func _rebind_checks() -> void:
	var events := InputMap.action_get_events("throw_bomb")
	_check("G is the fork bomb's quick throw: a rebindable action shown as \"Fork bomb\" in the settings' list, G by default, clashing with nothing", Controls.rebindable("throw_bomb") and Controls.default_bind("throw_bomb") == "key:%d" % KEY_G and _shown("throw_bomb") == "Fork bomb" and not Controls.conflicts({}).has("throw_bomb") and events.size() == 1 and (events[0] as InputEventKey).physical_keycode == KEY_G)
	var path := _tmp.path_join("rebind-settings.cfg")
	var s := GameSettings.new()
	s.path = path
	var h := InputEventKey.new()
	h.physical_keycode = KEY_H
	var took := s.set_bind("throw_bomb", h)
	var saved := s.save()
	var back := GameSettings.new()
	back.path = path
	var how := back.load_file()
	Controls.apply_binds(back.binds())
	var moved := InputMap.action_get_events("throw_bomb")
	_check("acceptance: the G rebind saves and loads: the fork bomb moved to H is written to the settings file, read back from it, and the input map takes it", took == "" and saved and how == "loaded" and back.bind("throw_bomb") == "key:%d" % KEY_H and moved.size() == 1 and (moved[0] as InputEventKey).physical_keycode == KEY_H and FileAccess.get_file_as_string(path).contains("throw_bomb"), "%s %s %s" % [took, how, back.bind("throw_bomb")])
	var chord := InputEventKey.new()
	chord.physical_keycode = KEY_G
	chord.ctrl_pressed = true
	chord.alt_pressed = true
	var refused := back.set_bind("throw_bomb", chord)
	back.reset_binds()
	back.save()
	var again := GameSettings.new()
	again.path = path
	again.load_file()
	Controls.apply_binds(again.binds())
	var reset := InputMap.action_get_events("throw_bomb")
	_check("Ctrl+Alt+G is refused, and resetting the keys puts the fork bomb back on G, saved and loaded the same way", refused == Controls.CTRL_ALT_REFUSED and again.bind("throw_bomb") == "key:%d" % KEY_G and reset.size() == 1 and (reset[0] as InputEventKey).physical_keycode == KEY_G)


# --- Solo. ---

func _solo_checks() -> void:
	var arena := await _arena()
	var main: Node = arena["main"]
	var p: Node = arena["player"]
	var hud = arena["hud"]
	var wh: WeaponHud = hud.weapon_hud()
	var round: RoundHud = hud.round_hud()
	var inv = p.inventory
	var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var dummies: Array = []
	for name in ["DummyA", "DummyB", "DummyC"]:
		dummies.append(main.get_node("Arena/Targets/" + name))
	for i in 3:
		_place(main, dummies[i], 30.0 + 3.0 * i, LINE_Z + 6.0)  # out of the throw's way
	p.respawn_at(main.to_global(Vector3(-15.0, STAND_Y, LINE_Z)))
	_aim(p, main.to_global(Vector3(0.0, STAND_Y + 0.6, LINE_Z)))
	await _settle(p, 0.3)
	_check("solo: the fork bomb is slot 4 with its 2 bombs, and the strip shows them while the cannon is drawn (fork() in slot 5 and one space between slots since C24, grep in slot 6 since C25, rm -rf in slot 7 since C26, cron in slot 8 since C27, ping in slot 9 since C28)", inv.slot_count() == 13 and inv.thrown_slot() == SLOT and inv.mags[SLOT] == 2 and wh.slots_text() == "[1 cannon] 2 3 4(2) 5 6 7 8 9", wh.slots_text())
	# A throw, drawn: fire.
	p.select_slot(SLOT)
	await _settle(p, 0.4)
	var drawn_line := wh.ammo_text()
	var gens := []
	var callouts := []
	p.fork_bomb_burst.connect(func(): callouts.append(round.callout_text()))
	_pin(p.get("_bomb_rng"), SEEDS["drawn"])
	await _fire(p)
	var thrown_one: bool = inv.mags[SLOT] == 1 and _chains(main).size() == 1
	var chain = _chains(main)[0] if thrown_one else null
	if chain != null:
		chain.blasted.connect(func(g, _i, _at): gens.append(g))
	var counts := await _until_done(main, 400)
	var by := [gens.count(0), gens.count(1), gens.count(2), gens.count(3)]
	_check("acceptance: drawn, fire throws one (2 left becomes 1, \"fork bomb  2 left\" drawn), and that one throw makes exactly 1, 2, 4 and 8 blasts, 15 in all, never more", thrown_one and drawn_line == "fork bomb  2 left" and by == [1, 2, 4, 8] and gens.size() == 15, "%s %s %s" % [drawn_line, by, counts])
	_check("the first blast of the throw is called out \":(){ :|:& };:\" by game logic", callouts.size() == 1 and callouts[0] == RoundHud.FORK_BOMB_LINE and round.last_callout == ":(){ :|:& };:")
	var left := get_nodes_in_group(ForkBomb.GROUP).size()
	_check("acceptance: when the chain is done every bomblet and ring node is freed: none left in the fork bomb's group, the field empty", left == 0 and main.get_node(ForkBomb.FIELD).get_child_count() == 0, "%d left" % left)
	# The quick throw: G with the cannon drawn.
	p.select_slot(0)
	await _settle(p, 0.4)
	_pin(p.get("_bomb_rng"), SEEDS["quick"])
	var quick: bool = p.quick_throw()
	await physics_frame
	var after_quick: int = inv.mags[SLOT]
	var strip_empty := wh.slots_text()
	await _until_done(main, 400)
	await _settle(p, 0.7)
	var none_left: bool = p.quick_throw()
	p.select_slot(SLOT)
	await _settle(p, 1.8)  # past the draw's fiction line
	await _fire(p)
	await _settle(p, 0.1)
	_check("acceptance: G throws one without drawing it (the cannon stays in hand, 0 left, the strip shows \"4(0)\"); with none left neither G nor fire throws anything", quick and after_quick == 0 and inv.current == SLOT and strip_empty == "[1 cannon] 2 3 4(0) 5 6 7 8 9" and not none_left and _chains(main).is_empty() and wh.state_text() == "out of ammo", "%s %d %s %s" % [quick, after_quick, strip_empty, wh.state_text()])
	round.call("_next_round")
	var at_round: int = inv.mags[SLOT]
	inv.mags[SLOT] = 0
	p.set_alive(false)
	p.set_alive(true)
	_check("acceptance: the bombs come back to 2 at a round's start and at a new life", at_round == 2 and inv.mags[SLOT] == 2, "%d %d" % [at_round, inv.mags[SLOT]])
	# Damage: a full chain beside a daemon of 100 health in the open kills it; one blast not.
	var target: Node = dummies[0]
	target.max_health = 100.0
	_place(main, target, -2.0, LINE_Z)
	target.reset_for_round()
	await _frames(3)
	var judge := Callable(p, "_judge_blast").bind(inv.defs[SLOT])
	var one := _t.duplicate()
	one.generations = 1
	var single = ForkBomb.spawn(main, one, target.global_position + Vector3(1.5, 0.6, 0.0), Vector3.ZERO, 7, "test", true, "fork", [], judge)
	await _until_done(main, 200)
	var after_one: float = target.health()
	target.reset_for_round()
	await _frames(3)
	ForkBomb.spawn(main, _t, target.global_position + Vector3(1.5, 0.6, 0.0), Vector3.ZERO, 7, "test", true, "fork", [], judge)
	await _until_done(main, 400)
	_check("acceptance: one blast beside a daemon of 100 health does not kill it (%.1f left); a full chain from the same spot in the open does" % after_one, after_one > 0.0 and after_one < 100.0 and not target.is_alive(), "health after one %.1f, alive after the chain %s" % [after_one, target.is_alive()])
	# A wall between blast and target: the whole chain on its far side does nothing.
	var guard: Node = dummies[1]
	guard.max_health = 100.0
	_place(main, guard, -2.0, LINE_Z - 5.0)
	guard.reset_for_round()
	var wall := _wall(main, Vector3(-3.5, 3.0, LINE_Z - 5.0), Vector3(0.4, 6.0, 14.0))
	await _frames(3)
	ForkBomb.spawn(main, _t, main.to_global(Vector3(-4.6, 0.6, LINE_Z - 5.0)), Vector3.ZERO, 11, "test", true, "fork", [], judge)
	await _until_done(main, 400)
	_check("acceptance: a wall between the blasts and a daemon blocks every one of them: a full chain 2.6 m away on the wall's far side leaves it at full health", guard.is_alive() and guard.health() == 100.0, "%.1f" % guard.health())
	wall.free()
	# A throw against a wall: the bomb leaves on this side of it, and nothing goes off beyond.
	# The wall runs 7 m each side of the throw (into the arena's own wall), wider than any
	# chain spreads: three child generations of 0.5 s at 3.5 m/s are 5.5 m at most, so no
	# blast gets past it but through it.
	p.respawn_at(main.to_global(Vector3(-15.0, STAND_Y, LINE_Z)))
	_aim(p, main.to_global(Vector3(20.0, STAND_Y + 0.65, LINE_Z)))
	await _settle(p, 0.3)
	var eye_x: float = main.to_local(p.eye_position()).x
	var face := _wall(main, Vector3(eye_x + 0.3, 1.5, LINE_Z), Vector3(0.1, 3.0, 14.0))
	await _frames(2)
	inv.mags[SLOT] = 2
	inv.cooldowns[SLOT] = 0.0
	var blasts_at := []
	_pin(p.get("_bomb_rng"), SEEDS["wall"])
	var close: bool = p.quick_throw()
	var against = _chains(main)[0] if not _chains(main).is_empty() else null
	var start_x: float = main.to_local(against.get("_bombs")[0]["pos"]).x if against != null else INF
	if against != null:
		against.blasted.connect(func(_g, _i, at): blasts_at.append(main.to_local(at)))
	await _until_done(main, 400)
	var beyond := blasts_at.filter(func(at): return at.x > eye_x + 0.25)
	_check("a throw against a wall 0.3 m off leaves on this side of it (from %.2f m ahead), and none of its blasts is beyond it" % (start_x - eye_x), close and start_x < eye_x + 0.25 and beyond.is_empty(), "start %.2f, wall at %.2f, %d beyond" % [start_x, eye_x + 0.25, beyond.size()])
	face.free()
	# The live cap under spam: bombs and the interval forced, a throw every frame.
	inv.mags[SLOT] = 40
	var peak := 0
	var most_blasts := 0
	var chains_seen := {}
	_pin(p.get("_bomb_rng"), SEEDS["spam"])
	for i in 120:
		inv.cooldowns[SLOT] = 0.0
		if i < 40:
			p.quick_throw()
		await physics_frame
		peak = maxi(peak, ForkBomb.live_of(main, "solo"))
		for c in _chains(main):
			chains_seen[c.get_instance_id()] = c
			most_blasts = maxi(most_blasts, c.blasts)
	await _until_done(main, 600)
	var refused := 0
	_check("acceptance: the live cap holds under spam: a throw every frame, 40 of them, never more than %d live bomblets at once (peak %d), no chain past 15 blasts, and every node freed after" % [_t.live_cap, peak], peak <= _t.live_cap and peak >= 8 and most_blasts <= 15 and chains_seen.size() >= 10 and get_nodes_in_group(ForkBomb.GROUP).is_empty(), "peak %d, chains %d, most blasts %d" % [peak, chains_seen.size(), most_blasts])
	await _frames(5)
	var orphans_after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_check("no orphan node is left behind by any of it", orphans_after <= orphans, "%d before, %d after" % [orphans, orphans_after])
	_drop(arena)
	await _frames(2)


## Waits until no chain is left in `main` (or `frames` physics frames), then a little for the
## rings: true when they all ended.
func _until_done(main: Node, frames: int) -> bool:
	for i in frames:
		if _chains(main).is_empty():
			break
		await physics_frame
	await _frames(int(_t.ring_s * 60.0) + 4)
	return _chains(main).is_empty()


func _chains(scope: Node) -> Array:
	var field := scope.get_node_or_null(ForkBomb.FIELD)
	if field == null:
		return []
	return field.get_children().filter(func(n): return n.has_method("live_count") and not n.is_queued_for_deletion())


func _wall(main: Node, at: Vector3, size: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var box := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	box.shape = shape
	wall.add_child(box)
	main.add_child(wall)
	wall.global_position = main.to_global(at)
	return wall


# --- A match. ---

func _match_checks() -> void:
	var host := _branch("Host", Vector3.ZERO)
	var client := _branch("Client", CLIENT_OFFSET)
	var joined := await _join(host, client)
	var hs: Session = host["session"]
	var cs: Session = client["session"]
	var hp: Node = host["player"]
	var cp: Node = client["player"]
	var cid: int = cs.my_id
	await _until(func(): return hs.avatars.has(cid) and cs.avatars.has(1) and hs.combat.has_player(cid) and cs.get("_weapons_synced"), 6000)
	await _until(func(): return hs.protect_left.get(1, 0.0) <= 0.0 and hs.protect_left.get(cid, 0.0) <= 0.0, 6000)
	_check("a host and a joiner over ENet on 127.0.0.1, protocol 18 (5 at C19, 10 at C27b, 11 at A5, 12 at I1, 13 at I2, 14 at I3, 15 at C29, 16 at C30, 17 at C31), both with the fork bomb's 2 bombs, the host counting the joiner's", joined and Session.PROTOCOL == 18 and hs.combat.ammo_of(cid, "fork_bomb") == [2, 0] and cp.inventory.mags[SLOT] == 2)
	# The joiner throws at the host, 3 m off on the clear line; the host is low, so it dies.
	var spot := Vector3(-8.0, STAND_Y, LINE_Z)
	var cspot := Vector3(-11.0, STAND_Y, LINE_Z)
	hp.respawn_at(host["main"].to_global(spot))
	cp.respawn_at(client["main"].to_global(cspot))
	await _frames(10)
	_aim(cp, client["main"].to_global(spot + Vector3(0.0, -0.3, 0.0)))
	await _settle(cp, 0.3)
	var heard := await _until(_heard.bind(hs, cid, client), 4000)
	hs.combat.states[1]["health"] = 40.0
	hs.call("_mirror_from_combat")
	var throws_before: int = hs.get("_throws")
	var host_scatter := {}
	var client_scatter := {}
	var host_blasts := []
	var client_blasts := []
	var callouts := []
	cp.fork_bomb_burst.connect(func(): callouts.append(true))
	_pin(hs.get("_seeds"), SEEDS["joiner"])
	var deaths := []
	var host_hud = host["hud"].combat_hud()
	var client_hud = client["hud"].combat_hud()
	hs.player_died.connect(func(victim, killer): deaths.append(["host", victim, killer, host_hud.feed_text().duplicate()]))
	cs.player_died.connect(func(victim, killer): deaths.append(["joiner", victim, killer, client_hud.feed_text().duplicate()]))
	var quick: bool = cp.quick_throw()
	var both := await _until(func(): return _held(hs, throws_before + 1) != null and _held(cs, throws_before + 1) != null, 2000)
	var host_chain = _held(hs, throws_before + 1)
	var client_chain = _held(cs, throws_before + 1)
	if both:
		host_chain.blasted.connect(func(g, i, at): host_blasts.append([g, i, host["main"].to_local(at)]); host_scatter.merge(host_chain.scatters, true))
		client_chain.blasted.connect(func(g, i, at): client_blasts.append([g, i, client["main"].to_local(at)]); client_scatter.merge(client_chain.scatters, true))
	_check("acceptance: the joiner's throw is a request the host checks and runs: its chain on the host decides, the joiner's only draws, and the host counts the joiner's bomb spent", heard and quick and both and host_chain.authoritative and not client_chain.authoritative and hs.combat.ammo_of(cid, "fork_bomb") == [1, 0] and client_chain.judge.is_null(), "%s %s %s %s" % [heard, quick, both, hs.combat.ammo_of(cid, "fork_bomb")])
	await _until(func(): return host_blasts.size() == 15 and client_blasts.size() == 15, 6000)
	await _frames(10)
	var same_places := host_blasts.size() == 15 and client_blasts.size() == 15
	for i in mini(host_blasts.size(), client_blasts.size()):
		same_places = same_places and host_blasts[i][0] == client_blasts[i][0] and host_blasts[i][1] == client_blasts[i][1] and host_blasts[i][2].distance_to(client_blasts[i][2]) < 0.001
	var same_scatter := host_scatter.size() == 7 and client_scatter.size() == 7
	for key in host_scatter:
		same_scatter = same_scatter and client_scatter.has(key) and client_scatter[key] == host_scatter[key]
	_check("acceptance: the joiner's screen draws the host's chain: the same 15 blasts in the same order at the host's places, and every one of the 7 forks scattered exactly as the host scattered it, from the seed", same_places and same_scatter, "blasts %d/%d, forks %d/%d" % [host_blasts.size(), client_blasts.size(), host_scatter.size(), client_scatter.size()])
	await _frames(4)
	var host_death: Array = deaths.filter(func(d): return d[0] == "host" and d[1] == 1)
	var client_death: Array = deaths.filter(func(d): return d[0] == "joiner" and d[1] == 1)
	var feed_host: Array = host_death[0][3] if not host_death.is_empty() else []
	var feed_client: Array = client_death[0][3] if not client_death.is_empty() else []
	_check("acceptance: the host judged the blasts: the host, at 40 health, died to them, killed by the joiner, and the kill feed names the fork bomb on both sides", host_death.size() == 1 and client_death.size() == 1 and host_death[0][2] == cid and not feed_host.is_empty() and feed_host[0] == "fork bomb sent by Daemon-2 to Daemon-1" and not feed_client.is_empty() and feed_client[0] == "fork bomb sent by Daemon-2 to Daemon-1", "%s | %s | %s" % [deaths.map(func(d): return d.slice(0, 3)), feed_host, feed_client])
	_check("the first blast of the joiner's own throw is called out on the joiner's screen, once", callouts.size() == 1 and client["hud"].round_hud().last_callout == RoundHud.FORK_BOMB_LINE)
	# A new life gives the bombs back: the joiner, low and beside the host, dies to the host's
	# bomb, its own first bomb still spent. First, so no other blast can have given it a new life.
	await _until(func(): return not hs.dead.get(1, false) and hs.protect_left.get(1, 0.0) <= 0.0 and hs.protect_left.get(cid, 0.0) <= 0.0, 8000)
	hp.respawn_at(host["main"].to_global(spot))
	cp.respawn_at(client["main"].to_global(spot + BESIDE))
	await _frames(12)
	_aim(hp, host["main"].to_global(spot + Vector3(1.0, -0.9, 0.0)))
	await _settle(hp, 0.3)
	var placed := await _until(_heard.bind(hs, cid, client), 4000)
	hs.combat.states[cid]["health"] = 10.0
	_pin(hs.get("_seeds"), SEEDS["second"])
	hp.quick_throw()
	var down := await _until(func(): return hs.dead.get(cid, false) and cs.dead.get(cid, false), 6000)
	var spent := [hs.combat.ammo_of(cid, "fork_bomb"), cp.inventory.mags[SLOT]]
	var back := await _until(func(): return not hs.dead.get(cid, false) and not cs.dead.get(cid, false), 6000)
	await _frames(4)
	_check("acceptance: a new life gives the bombs back: the joiner killed with 1 bomb left is back with 2, in the host's count and its own", placed and down and back and spent[0] == [1, 0] and hs.combat.ammo_of(cid, "fork_bomb") == [2, 0] and cp.inventory.mags[SLOT] == 2, "%s -> %s %d" % [spent, hs.combat.ammo_of(cid, "fork_bomb"), cp.inventory.mags[SLOT]])
	# No self-damage: the host throws at its own feet with the joiner beside it.
	await _until(func(): return _held(hs, hs.get("_throws")) == null and hs.protect_left.get(cid, 0.0) <= 0.0, 6000)
	cp.respawn_at(client["main"].to_global(spot + BESIDE))
	await _frames(12)
	await _settle(hp, 0.7)
	var beside := await _until(_heard.bind(hs, cid, client), 4000)
	var host_health: float = hs.combat.health_of(1)
	var joiner_health: float = hs.combat.health_of(cid)
	var mine_before: int = hs.get("_throws")
	_pin(hs.get("_seeds"), SEEDS["own"])
	hp.quick_throw()
	await _until(func(): return _held(hs, mine_before + 1) != null, 1000)
	await _until(func(): return _held(hs, mine_before + 1) == null, 6000)
	await _frames(10)
	_check("acceptance: the thrower takes no damage from its own bombs: the host's chain at its feet leaves it at %d health, while the joiner beside it is hurt (%d -> %d)" % [hs.combat.health_of(1), joiner_health, hs.combat.health_of(cid)], beside and host_health == 100.0 and hs.combat.health_of(1) == 100.0 and hs.combat.health_of(cid) < joiner_health)
	# Forged throws.
	await _until(func(): return not hs.dead.get(cid, false) and not cs.dead.get(cid, false) and hs.protect_left.get(cid, 0.0) <= 0.0, 6000)
	cp.respawn_at(client["main"].to_global(cspot))
	_aim(cp, client["main"].to_global(Vector3(20.0, STAND_Y, LINE_Z)))
	await _settle(cp, 0.5)
	var aimed := await _until(_heard.bind(hs, cid, client), 4000)
	var eye: Vector3 = client["main"].to_local(cp.eye_position())
	var east := Vector3(1.0, 0.0, 0.0)
	var life: int = cs.lives.get(cid, 0)
	var drops: Dictionary = hs.combat.drops.duplicate()
	var counted: int = hs.combat.dropped
	var throws_now: int = hs.get("_throws")
	await _forge(hs, cs, [life, "fork_bomb", eye + Vector3(0.0, 0.0, 9.0), east])
	await _forge(hs, cs, [life, "fork_bomb", eye, Vector3(-1.0, 0.0, 0.0)])
	await _forge(hs, cs, ["one", "fork_bomb", eye, east])
	await _forge(hs, cs, [life, "sigterm", eye, east])
	var dropped_now: Dictionary = hs.combat.drops
	_check("acceptance: forged throws are dropped by the host and counted: a far origin (\"origin\"), the wrong aim (\"aim\"), the wrong types and a weapon that is not thrown; no chain is run for any", aimed and dropped_now.get(Combat.DROP_ORIGIN, 0) == drops.get(Combat.DROP_ORIGIN, 0) + 1 and dropped_now.get(Combat.DROP_AIM, 0) == drops.get(Combat.DROP_AIM, 0) + 1 and dropped_now.get(Combat.DROP_WEAPON, 0) == drops.get(Combat.DROP_WEAPON, 0) + 1 and hs.combat.dropped == counted + 4 and hs.get("_throws") == throws_now and hs.combat.ammo_of(cid, "fork_bomb") == [2, 0], "drops %s" % dropped_now)
	_pin(hs.get("_seeds"), SEEDS["spent"])
	cp.quick_throw()
	await _settle(cp, 0.7)
	cp.quick_throw()
	await _until(func(): return hs.combat.ammo_of(cid, "fork_bomb") == [0, 0], 2000)
	await _settle(cp, 0.7)
	var empty_before: int = hs.combat.drops.get(Combat.DROP_EMPTY, 0)
	var throws_spent: int = hs.get("_throws")
	await _forge(hs, cs, [life, "fork_bomb", client["main"].to_local(cp.eye_position()), east])
	_check("acceptance: with no bombs left in the host's count, a forged throw is dropped and counted (\"empty\"), and no chain is run", hs.combat.drops.get(Combat.DROP_EMPTY, 0) == empty_before + 1 and hs.get("_throws") == throws_spent, "drops %s" % hs.combat.drops)
	# The host's live cap: its own bombs and interval forced, a throw every frame.
	await _until(func(): return _held(hs, throws_spent) == null and _held(hs, throws_spent - 1) == null and not hs.dead.get(1, false), 6000)
	hp.respawn_at(host["main"].to_global(Vector3(5.0, STAND_Y, LINE_Z)))
	_aim(hp, host["main"].to_global(Vector3(20.0, STAND_Y, LINE_Z)))
	await _settle(hp, 0.3)
	var peak := 0
	var cap_drops: int = hs.combat.drops.get(Combat.DROP_LIVE, 0)
	_pin(hs.get("_seeds"), SEEDS["host_spam"])
	for i in 90:
		hs.combat.states[1]["ammo"]["fork_bomb"]["mag"] = 9
		hs.combat.states[1]["ammo"]["fork_bomb"]["last_fire"] = -INF
		hp.inventory.mags[SLOT] = 9
		hp.inventory.cooldowns[SLOT] = 0.0
		if i < 40:
			hp.quick_throw()
		await physics_frame
		peak = maxi(peak, ForkBomb.live_of(host["main"], "p1"))
	_check("acceptance: the host's live cap holds under spam: a throw every frame, never more than %d of the host's bomblets live at once (peak %d), and a throw at the cap is dropped and counted (\"live_cap\")" % [_t.live_cap, peak], peak <= _t.live_cap and peak >= 8 and hs.combat.drops.get(Combat.DROP_LIVE, 0) > cap_drops, "peak %d, live_cap drops %d" % [peak, hs.combat.drops.get(Combat.DROP_LIVE, 0) - cap_drops])
	await _until(func(): return _chains(host["main"]).is_empty() and _chains(client["main"]).is_empty(), 8000)
	await _frames(int(_t.ring_s * 60.0) + 6)
	var host_left: int = host["main"].find_children("*", "", true, false).filter(func(n): return n.is_in_group(ForkBomb.GROUP)).size()
	var client_left: int = client["main"].find_children("*", "", true, false).filter(func(n): return n.is_in_group(ForkBomb.GROUP)).size()
	_check("acceptance: every bomblet and ring node is freed after the chains, on the host and on the joiner", host_left == 0 and client_left == 0 and hs.get("_chains").is_empty() and cs.get("_chains").is_empty(), "host %d, joiner %d" % [host_left, client_left])
	_drop(host)
	_drop(client)


## The chain throw `id` runs or draws on session `s`, or null.
func _held(s: Session, id: int):
	var held = s.get("_chains").get(id)
	return held["chain"] if held != null and is_instance_valid(held["chain"]) else null


## A throw straight onto the wire from the joiner, as the joiner's game counts what it sends;
## back once the host has dropped it or run it, never on a frame count.
func _forge(hs: Session, cs: Session, args: Array) -> void:
	var dropped: int = hs.combat.dropped
	var throws: int = hs.get("_throws")
	cs.set("_sent_actions", cs.get("_sent_actions") + 1)
	cs.rpc_id(1, "_throw", args[0], args[1], args[2], args[3])
	await _until(func(): return hs.combat.dropped != dropped or hs.get("_throws") != throws, 4000)
	await _frames(2)


## True once the host has heard the joiner's newest place and look as its game sends them:
## the host judges a throw's origin and aim, and how far a blast reaches, by what it last
## heard of the joiner.
func _heard(hs: Session, cid: int, client: Dictionary) -> bool:
	var avatar = hs.avatars.get(cid)
	var cp: Node = client["player"]
	if avatar == null or not is_instance_valid(avatar) or not avatar.visible:
		return false
	var here: Vector3 = client["main"].to_local(cp.global_position)
	var look := (Basis(Vector3.UP, cp.rotation.y) * Basis(Vector3.RIGHT, cp.view_pitch()) * Vector3.FORWARD).normalized()
	return avatar.latest_position().distance_to(here) < 0.05 and avatar.latest_view().angle_to(look) < deg_to_rad(1.0)


## A scatter seed source pinned: every throw it draws for from here on is the same each run.
func _pin(rng: RandomNumberGenerator, seed: int) -> void:
	rng.seed = seed


# --- Helpers. ---

func _shown(action: String) -> String:
	for pair in Controls.REBINDABLE:
		if pair[0] == action:
			return pair[1]
	return ""


func _place(main: Node, dummy: Node, x: float, z: float) -> void:
	dummy.global_position = main.to_global(Vector3(x, 0.0, z))


func _arena() -> Dictionary:
	var link := Link.new()
	link.settings_path = _tmp.path_join("arena-privacy.cfg")
	link.demo = true
	Link.park(link)
	var main = MainScene.instantiate()
	root.add_child(main)
	_arenas.append(main)
	var hud = main.get_node("Hud")
	hud.guide().focus_check = func(): return false
	var player = main.get_node("Player")
	player.assume_captured = true
	await _frames(3)
	return {"main": main, "player": player, "hud": hud}


func _drop(side: Dictionary) -> void:
	var node: Node = side.get("branch", side.get("main"))
	if is_instance_valid(node):
		for sfx in node.find_children("*", "AudioStreamPlayer", true, false):
			(sfx as AudioStreamPlayer).stop()
		var session = side.get("session")
		if session != null and is_instance_valid(session):
			session.leave()
		node.free()
	_arenas.erase(node)
	_branches.erase(node)
	var left = Link.take_parked()
	if left != null:
		left.shut_down(null)


func _net_tuning() -> Resource:
	var t := NetTuningScript.new()
	t.bind_address = "127.0.0.1"
	t.connect_timeout_ms = 1500
	t.peer_timeout_ms = 4000
	return t


func _combat_tuning() -> Resource:
	var t := CombatTuningScript.new()
	t.respawn_delay_s = 1.0
	t.spawn_protection_s = 0.3
	t.kill_feed_fade_s = 30.0
	return t


func _branch(name: String, offset: Vector3) -> Dictionary:
	var api := SceneMultiplayer.new()
	var branch := Node3D.new()
	branch.name = name
	branch.position = offset
	root.add_child(branch)
	set_multiplayer(api, branch.get_path())
	var session := Session.new()
	session.name = Session.NODE_NAME
	session.tuning = _net_tuning()
	session.combat_tuning = _combat_tuning()
	branch.add_child(session)
	_branches.append(branch)
	var link := Link.new()
	link.settings_path = _tmp.path_join("%s-privacy.cfg" % name)
	link.demo = true
	Link.park(link)
	var main = MainScene.instantiate()
	branch.add_child(main)
	var hud = main.get_node("Hud")
	hud.guide().focus_check = func(): return false
	var out := {"branch": branch, "session": session, "main": main, "player": main.get_node("Player"), "hud": hud}
	out["player"].assume_captured = true
	return out


func _join(host: Dictionary, client: Dictionary) -> bool:
	host["session"].host(0)
	await _frames(2)
	client["session"].join("127.0.0.1:%d" % host["session"].listen_port())
	return await _until(func(): return client["session"].state == Session.State.JOINED and host["session"].players.size() == 2 and client["session"].players.size() == 2)


func _settle(p: Node, seconds: float) -> void:
	for i in ceili(seconds * 60.0):
		p.drive_input(Vector2.ZERO)
		await physics_frame


func _fire(p: Node) -> void:
	p.drive_input(Vector2.ZERO, false, false, true)
	await physics_frame


func _aim(player: Node, target: Vector3) -> void:
	var cam: Node3D = player.get_node("Head/Camera")
	var to: Vector3 = target - cam.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	player.get_node("Head").rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


func _until(condition: Callable, ms: int = WATCHDOG_MS) -> bool:
	var t0 := Time.get_ticks_msec()
	while not condition.call():
		if Time.get_ticks_msec() - t0 > ms:
			return false
		await physics_frame
	return true


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _code(path: String) -> String:
	var out := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var quote := ""
		var cut := line.length()
		var i := 0
		while i < line.length():
			var ch := line[i]
			if quote != "":
				if ch == "\\":
					i += 1
				elif ch == quote:
					quote = ""
			elif ch == "\"" or ch == "'":
				quote = ch
			elif ch == "#":
				cut = i
				break
			i += 1
		out.append(line.substr(0, cut).rstrip(" \t"))
	return "\n".join(out)


func _body(source: String, name: String) -> String:
	var at := source.find("\nfunc %s(" % name)
	if at < 0:
		at = source.find("\nstatic func %s(" % name)
	if at < 0:
		return ""
	var end := source.find("\nfunc ", at + 1)
	var end_static := source.find("\nstatic func ", at + 1)
	if end_static > 0 and (end < 0 or end_static < end):
		end = end_static
	return source.substr(at, (end if end > 0 else source.length()) - at)


func _cleanup() -> void:
	for node in _arenas.duplicate() + _branches.duplicate():
		if is_instance_valid(node):
			var session = node.get_node_or_null(Session.NODE_NAME)
			if session != null:
				session.leave()
			node.free()
	var left = Link.take_parked()
	if left != null:
		left.shut_down(null)
	Controls.apply_binds({})
	await process_frame
	OS.delay_msec(300)
	await process_frame
