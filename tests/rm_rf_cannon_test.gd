extends SceneTree
## Headless rm -rf cannon test for SIGKILL (C26). scripts/check.sh runs it, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/rm_rf_cannon_test.gd
##
## The rm -rf cannon (PRD 5.2, "slow, devastating cannon with friendly-fire risk"): the resource
## and its numbers, bad values refused; the blast's falloff alone; scans that the new code
## removes, runs and touches nothing (no OS call, no DirAccess or FileAccess, no move_to_trash,
## no rm) and the wire (protocol 9, nothing new). In an empty test world, frame by frame: the slug
## at its speed, slower than every other projectile, going off at its range, on a wall, on the
## floor and on a body; a ring growing to the blast's radius (root's larger); a slug that only
## draws passing bodies, holding at a wall and going off only on the word. In the real arena with
## the real player: slot 7 on key 7, the wheel and Q; the wind-up holding the shot exactly 36
## frames (18 as root) while its prompt types out; a swap, a death and a respawn cancelling it with
## nothing spent; the pace halved through it and after the shot, no slide; daemons taking the
## blast for their distance, none past the radius or behind cover; root's 1.5 times, free round and
## larger radius; the "rm -rf" callout. Seven slots at 960x540. Then a host and two joiners over
## ENet on 127.0.0.1: one joiner's blast judged by the host on the host (derezzed at its centre),
## the other joiner and the shooter itself; a self-kill "rm -rf: Daemon-2 removed themself"; cover
## stopping the blast; the joiners' slugs only drawing; a protocol 8 joiner refused. No orphan
## nodes. Deterministic: seeds pinned, times counted in physics frames, and only counts and
## outcomes printed for anything a network's timing could move.

const Session = preload("res://scripts/net/net_session.gd")
const NetTuningScript = preload("res://scripts/net/net_tuning.gd")
const CombatTuningScript = preload("res://scripts/net/combat_tuning.gd")
const WeaponDefScript = preload("res://scripts/weapons/weapon_def.gd")
const RmSlug = preload("res://scripts/weapons/rm_slug.gd")
const CombatHud = preload("res://scripts/net/combat_hud.gd")
const Controls = preload("res://scripts/controls.gd")
const Palette = preload("res://scripts/palette.gd")
const Link = preload("res://scripts/guide/guide_link.gd")
const MainScene = preload("res://scenes/main.tscn")
const DummyScene = preload("res://scenes/target_dummy.tscn")
const TUNING_PATH := "res://resources/rm_rf_cannon.tres"
const SLOT := 6
const WATCHDOG_MS := 10000
const CLIENT_OFFSET := Vector3(1000.0, 0.0, 0.0)
const CLIENT_B_OFFSET := Vector3(3000.0, 0.0, 0.0)
const OLD_OFFSET := Vector3(2000.0, 0.0, 0.0)
## High above every arena: the empty test world's slugs meet only what a check puts there.
const EMPTY_AT := Vector3(0.0, 300.0, 600.0)
const STAND_Y := 0.95
const MIDDLE_Y := 0.9
const LINE_Z := 15.0
const EPS := 0.0001
const SEED := 424242
const PROMPT := "rm: remove? [y]"

var _fails := 0
var _checks := 0
var _tmp := ""
var _w: Resource
var _arenas: Array = []
var _branches: Array = []
var _scratch: Array = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_tmp = OS.get_temp_dir().path_join("sigkill-rm-rf-cannon-test-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(_tmp)
	Controls.ensure()
	_w = load(TUNING_PATH)
	_tuning_checks()
	_source_checks()
	await _empty_world_checks()
	await _arena_checks()
	await _layout_checks()
	await _match_checks()
	await _cleanup()
	for name in DirAccess.get_files_at(_tmp):
		DirAccess.remove_absolute(_tmp.path_join(name))
	DirAccess.remove_absolute(_tmp)
	print("RM -RF CANNON: %d checks" % _checks)
	print("RM -RF CANNON RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The resource, the falloff, the source. ---

func _tuning_checks() -> void:
	var w = _w
	var cannon = load("res://resources/terminal_cannon.tres")
	_check("acceptance: every number is one resource, resources/rm_rf_cannon.tres, a WeaponDef that passes its own checks", w is WeaponDefScript and w.problems().is_empty() and w.is_slug() and w.is_volley(), str(w.problems()) if w is WeaponDefScript else "")
	_check("its wind-up and weight: 0.6 s to confirm (0.3 s as root, root_charge_scale 0.5), half the pace through it and 0.8 s after the shot; the prompt \"rm: remove? [y]\"", w.charge_s == 0.6 and w.charge_for(false) == 0.6 and w.charge_for(true) == 0.3 and w.move_scale == 0.5 and w.move_factor() == 0.5 and w.move_slow_s == 0.8 and w.charge_prompt == PROMPT)
	_check("its slug and blast: 9 m/s out to 45 m; a 6 m blast (9 m as root, root_blast_scale 1.5), 140 at the centre easing to 8 at the edge, the shooter taking 0.5 of it", w.slug_speed == 9.0 and w.fire_range == 45.0 and w.blast_radius_m == 6.0 and w.blast_radius_for(true) == 9.0 and w.damage == 140.0 and w.blast_edge_damage == 8.0 and w.self_damage_share == 0.5)
	_check("acceptance: slow and devastating, never spammy: one round in the magazine, 3 in reserve, a 3.2 s reload on E, a 2.5 s interval; its own ember from the palette; \"rm -rf\" in the feed and the self-kill words \"removed themself\"; fiction only, its line \"rm -rf: no undo.\"", w.magazine_size == 1 and w.reserve_ammo == 3 and w.reload_s == 3.2 and w.fire_cooldown == 2.5 and w.fire_cooldown > cannon.fire_cooldown and w.light_skin == "ember" and w.skin_body() == Palette.EMBER and w.kill_word == "rm -rf" and w.short_name == "rm -rf" and w.self_kill_word == "removed themself" and w.fiction == "rm -rf: no undo.")
	var skins := {}
	var speeds := {}
	for path in ["terminal_cannon", "sigterm", "sigkill_rail", "fork_bomb_weapon", "fork_shotgun", "grep_seeker"]:
		var other = load("res://resources/%s.tres" % path)
		skins[other.skin_body()] = true
		skins[other.skin_beam()] = true
		if other.is_thrown():
			speeds[path] = other.projectile.throw_speed
		elif other.is_fork():
			speeds[path] = other.pellet_speed
		elif other.is_seeker():
			speeds[path] = other.dart_speed
	var slowest: bool = speeds.size() == 3 and speeds.values().all(func(v): return w.slug_speed < v)
	_check("acceptance: the slug is slower than every other projectile: 9 m/s against %s" % [speeds], slowest)
	_check("acceptance: its light colour is its own: neither of ember's colours is the cannon's, SIGTERM's, the rail's, the fork bomb's, fork()'s or grep's, nor hostile red or amber, nor the code rain's green", not skins.has(Palette.EMBER) and not skins.has(Palette.EMBER_HI) and not [Palette.HOSTILE_RED, Palette.HOSTILE_AMBER, Palette.MATRIX_GREEN].has(Palette.EMBER))
	var cases := [
		["charge_s", 0.0, "winds up"], ["root_charge_scale", 0.0, "root_charge_scale"], ["root_charge_scale", 1.5, "root_charge_scale"], ["move_scale", 0.0, "move_scale"],
		["move_slow_s", -1.0, "move_slow_s"], ["slug_speed", 90.0, "slug_speed"], ["slug_speed", NAN, "slug_speed"], ["slug_radius_m", 0.0, "slug_radius_m"],
		["slug_trail_m", 0.0, "slug_trail_m"], ["blast_radius_m", 0.0, "blast_radius_m"], ["blast_radius_m", 30.0, "blast_radius_m"], ["root_blast_scale", 0.5, "root_blast_scale"],
		["blast_edge_damage", 200.0, "blast_edge_damage"], ["self_damage_share", 0.0, "self_damage_share"], ["blast_ring_s", 0.0, "blast_ring_s"], ["blast_wait_s", 0.0, "blast_wait_s"],
		["self_kill_word", "", "self_kill_word"], ["charge_prompt", "", "charge_prompt"], ["pellet_count", 2, "one slug"], ["magazine_size", -1, "from a magazine"], ["falloff_floor", 0.5, "falloff_floor"],
	]
	var missed := PackedStringArray()
	for c in cases:
		var bad = _w.duplicate()
		bad.set(c[0], c[1])
		if c[0] == "magazine_size":
			bad.reserve_ammo = -1
			bad.reload_s = 0.0
		if not ", ".join(bad.problems()).contains(c[2]):
			missed.append("%s=%s: %s" % [c[0], c[1], bad.problems()])
	var odd = cannon.duplicate()
	odd.blast_radius_m = 6.0
	if not ", ".join(odd.problems()).contains("only the rm -rf slug"):
		missed.append("the cannon with a blast: %s" % odd.problems())
	_check("bad values are refused with the reason: no wind-up, root's wind-up none or longer, no weight, a slug too fast or NaN, no look, no blast or one too wide, root's smaller, an edge past the centre, no self-damage, no ring, no wait, no self-kill words, no prompt, more than one slug, no magazine, falloff; and the blast group on any other weapon", missed.is_empty(), " | ".join(missed))
	var max_health: float = CombatTuningScript.new().max_health
	var falloff := [w.blast_damage_at(0.0, false), w.blast_damage_at(3.0, false), w.blast_damage_at(6.0, false), w.blast_damage_at(6.01, false), w.blast_damage_at(9.0, true), w.blast_damage_at(9.01, true)]
	_check("acceptance: the blast falls off from the centre to the edge: 140 at 0 m (more than a full player's %d), 74 at 3 m, 8 at the 6 m edge (a scratch), nothing past it; as root 8 at 9 m and nothing past" % max_health, falloff == [140.0, 74.0, 8.0, 0.0, 8.0, 0.0] and falloff[0] > max_health, str(falloff))


func _source_checks() -> void:
	var slug := _code("res://scripts/weapons/rm_slug.gd")
	var weapon := _code("res://scripts/weapons/weapon_def.gd")
	var player := _code("res://scripts/player.gd")
	var session := _code("res://scripts/net/net_session.gd")
	var parts := slug + _body(weapon, "_slug_problems") + _body(weapon, "blast_damage_at") + _body(weapon, "charge_for") + _body(weapon, "blast_radius_for")
	parts += _body(player, "_fire_slug") + _body(player, "_judge_slug") + _body(player, "move_scale") + _body(session, "_judge_slug_blast") + _body(session, "_on_slug_blasted") + _body(session, "_tell_blast")
	var found := PackedStringArray()
	for word in ["OS.", "execute", "create_process", "DirAccess", "FileAccess", "move_to_trash", "remove_absolute", "/proc", "shell_open", "Thread", "HTTP", "PacketPeer", "StreamPeer", "Expression"]:
		if parts.contains(word):
			found.append(word)
	var bare := RegEx.create_from_string("(?<![\\w.\"])rm\\s*\\(")
	var unquoted := RegEx.create_from_string("\"(?:\\\\.|[^\"\\\\])*\"").sub(parts, "\"\"", true)
	if bare.search(unquoted) != null:
		found.append("a call to rm()")
	if slug.contains("rpc"):
		found.append("rpc in the slug")
	_check("acceptance: fiction only, the hard rule: the new weapon's code runs no rm, no OS call at all (no OS.execute, OS.create_process, OS.move_to_trash), no DirAccess.remove or any DirAccess or FileAccess, no /proc: \"rm -rf\" is only a name and HUD text; and the slug sends nothing itself", found.is_empty() and parts.length() > 4000, ", ".join(found))
	var fire := _body(session, "_handle_fire")
	_check("acceptance: the wire stays protocol 9: no new message and no changed one (20 RPCs, 23 sends: the blast word's one send now in _tell_blast, shared with the fork bomb); the shot is the usual intent, the slug told in the seed message and its blast in the fork bomb's blast word", Session.PROTOCOL == 9 and session.count("@rpc(") == 20 and session.count(".rpc_id(") == 23 and session.count("_blast.rpc_id(") == 1 and _body(session, "_tell_blast").contains("_blast.rpc_id(") and fire.find("combat.accept(") < fire.find("if def.is_slug():") and fire.contains("_spawn_volley(_throws, shooter, weapon, 0, origin, dir, true)") and fire.contains("_tell_seed(_throws, shooter, weapon, 0, origin, dir)") and _body(session, "_blast").contains("slug.apply_blast(_arena.to_global(at))"))
	_check("a client never decides damage: only the host's slug has a judge (_judge_slug_blast, bound only when deciding, which returns at once unless hosting); a joiner's slug only draws and goes off on the host's word", _body(session, "_spawn_volley").contains("var blast := _judge_slug_blast.bind(shooter, weapon, root) if deciding else Callable()") and session.count("_judge_slug_blast.bind(") == 1 and _body(session, "_judge_slug_blast").contains("if state != State.HOSTING or combat == null") and slug.contains("slug.hit_mask = mask if deciding else WORLD_LAYER"))


# --- The slug in an empty world. ---

func _empty_world_checks() -> void:
	var world := Node3D.new()
	world.name = "EmptyWorld"
	root.add_child(world)
	_scratch.append(world)
	var aim := Vector3(1.0, 0.0, 0.0)
	# Its range: nothing in the way.
	var s: Node = RmSlug.spawn(world, _w, EMPTY_AT, aim, false, true, _w.hit_mask)
	var store := _track(s)
	var frames := 0
	var straight := true
	while not store["done"] and frames < 400:
		await physics_frame
		frames += 1
		if not store["done"]:
			var at: Vector3 = s.position_now()
			straight = straight and (at - EMPTY_AT).cross(aim).length() < 0.001
	var steps: Array = store.get("steps", [])
	var even: bool = steps.size() >= 2 and steps.slice(0, steps.size() - 1).all(func(x): return absf(x - 9.0 / 60.0) < 0.00001)
	var rings: Array = world.get_node(RmSlug.FIELD).get_children().filter(func(n): return n.is_in_group(RmSlug.RING_GROUP))
	var ring_ok: bool = rings.size() == 1 and absf((rings[0].mesh as TorusMesh).outer_radius - 6.0) < EPS
	_check("acceptance: one slow slug flying straight, 0.15 m a frame (9 m/s), going off at exactly its 45 m range (%d frames, 5 s), its blast ring growing out to the 6 m radius" % frames, store.get("why", "") == RmSlug.RANGE and absf(store.get("flown", 0.0) - 45.0) < 0.001 and straight and even and frames >= 299 and frames <= 301 and ring_ok, "%s %d %s %s" % [store.get("why", ""), frames, even, ring_ok])
	await _frames(30)
	_check("the ring fades and frees itself within blast_ring_s, the slug with its blast", world.get_node(RmSlug.FIELD).get_child_count() == 0)
	# A wall, the floor, a body.
	var at := EMPTY_AT + Vector3(0.0, 0.0, 300.0)
	var wall := _wall(world, at + Vector3(6.0, 0.0, 0.0))
	var slab := _wall(world, at + Vector3(0.0, -3.0, 40.0), Vector3(20.0, 0.2, 20.0))
	var body := _wall(world, at + Vector3(4.0, 0.0, 80.0), Vector3(0.6, 2.0, 0.6), 4)
	var back := _wall(world, at + Vector3(8.0, 0.0, 80.0))
	await _frames(3)
	var on_wall := await _shot_in(world, at, Vector3(1.0, 0.0, 0.0), false)
	var on_floor := await _shot_in(world, at + Vector3(0.0, 0.0, 40.0), Vector3(1.0, -1.0, 0.0).normalized(), false)
	var on_body := await _shot_in(world, at + Vector3(0.0, 0.0, 80.0), Vector3(1.0, 0.0, 0.0), false)
	var rooted := await _shot_in(world, at, Vector3(1.0, 0.0, 0.0), true)
	var standoff := RmSlug.STANDOFF_M
	_check("acceptance: it goes off on a wall (5 cm off its face, 5.9 m out, so the wall shields what is behind it), on the floor and on a target's body; as root its ring grows to 9 m", on_wall["why"] == RmSlug.WALL and absf(on_wall["at"].x - (at.x + 5.9 - standoff)) < 0.001 and on_floor["why"] == RmSlug.FLOOR and absf(on_floor["at"].y - (at.y - 2.9 + standoff * sqrt(0.5))) < 0.001 and on_body["why"] == RmSlug.BODY and absf(on_wall["ring"] - 6.0) < EPS and absf(rooted["ring"] - 9.0) < EPS, "%s %s %s %.2f" % [on_wall["why"], on_floor["why"], on_body["why"], rooted["ring"]])
	# A slug that only draws: past the body, held at the wall, off only on the word.
	var drawn: Node = RmSlug.spawn(world, _w, at + Vector3(0.0, 0.0, 80.0), Vector3(1.0, 0.0, 0.0), false, false, _w.hit_mask)
	var dstore := _track(drawn)
	await _until(func(): return drawn.why != "" or dstore["done"], 4000)
	var held_at: String = drawn.why if not dstore["done"] else "gone"
	var word_at := at + Vector3(4.3, 0.2, 80.0)
	drawn.apply_blast(word_at)
	await physics_frame
	var lone: Node = RmSlug.spawn(world, _w, at, Vector3(1.0, 0.0, 0.0), false, false, _w.hit_mask)
	var lstore := _track(lone)
	await _until(func(): return lone.why != "", 4000)
	var waited := 0
	while not lstore["done"] and waited < 120:
		await physics_frame
		waited += 1
	_check("a slug on a joiner's screen only draws: it passes the body (no blast there), holds at the wall, goes off only on the host's word at the place the word gives, and with no word it goes away after the 0.5 s wait (%d frames) without a blast" % waited, held_at == RmSlug.WALL and dstore["done"] and dstore.get("why", "") == RmSlug.WORD and dstore.get("at", Vector3.ZERO).distance_to(word_at) < EPS and lstore["done"] and not lstore.get("at", Vector3.ZERO).is_finite() and waited >= 29 and waited <= 31, "%s %s %d" % [held_at, dstore.get("why", ""), waited])
	for n in [wall, slab, body, back]:
		n.queue_free()


## One judging slug from `from` along `dir` in `world`: {why, at, ring}.
func _shot_in(world: Node, from: Vector3, dir: Vector3, root_on: bool) -> Dictionary:
	var s: Node = RmSlug.spawn(world, _w, from, dir, root_on, true, _w.hit_mask)
	var store := _track(s)
	await _until(func(): return store["done"], 6000)
	var radius := 0.0
	for n in world.get_node(RmSlug.FIELD).get_children():
		if n.is_in_group(RmSlug.RING_GROUP) and not n.is_queued_for_deletion():
			radius = (n.mesh as TorusMesh).outer_radius
			n.queue_free()
	return {"why": store.get("why", ""), "at": store.get("at", Vector3.INF), "ring": radius}


# --- The real arena. ---

func _arena_checks() -> void:
	var arena := await _arena()
	var main: Node = arena["main"]
	var p: Node = arena["player"]
	var hud = arena["hud"]
	var wh = hud.weapon_hud()
	var inv = p.get("inventory")
	var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var shipped: Resource = load("res://resources/arsenal.tres")
	_check("acceptance: the arsenal carries it as weapon 7 (after the cannon, SIGTERM, the rail, the fork bomb, fork() and grep); the player holds seven", shipped.loadout.size() == 7 and shipped.loadout[SLOT] == _w and inv.slot_count() == 7 and inv.defs[SLOT].id == "rm_rf_cannon", str(inv.defs.map(func(d): return d.id)))
	var key := InputEventKey.new()
	key.physical_keycode = KEY_7
	key.pressed = true
	Input.parse_input_event(key)
	await physics_frame
	var by_key: int = inv.current
	key.pressed = false
	Input.parse_input_event(key)
	await physics_frame
	p.select_slot(5)
	await physics_frame
	p.cycle_weapon(1)
	var next: int = inv.current
	p.cycle_weapon(1)
	var wrapped: int = inv.current
	p.cycle_weapon(-1)
	var back: int = inv.current
	p.select_slot(1)
	await physics_frame
	p.swap_to_last()
	var last: int = inv.current
	await _settle(p, 0.5)
	_check("acceptance: key 7 draws it; the weapon cycle reaches it after grep and wraps from it to the cannon and back; Q returns to it", by_key == SLOT and next == SLOT and wrapped == 0 and back == SLOT and last == SLOT, "%d %d %d %d %d" % [by_key, next, wrapped, back, last])
	var dummies := _line_up(main)
	var calls := []
	p.rm_blast.connect(func(): calls.append(hud.round_hud().get("last_callout")))
	p.respawn_at(main.to_global(Vector3(-14.0, STAND_Y, LINE_Z)))
	await _settle(p, 0.3)
	_aim(p, main.to_global(Vector3(18.0, 1.6, LINE_Z)))
	# The wind-up: exactly 0.6 s, its prompt typed out meanwhile; letting go stops nothing.
	var wind := await _wind_up(main, p)
	var typed: Array = wind["prompts"]
	var typing: bool = typed.size() >= 30 and range(1, typed.size()).all(func(i): return PROMPT.begins_with(typed[i]) and typed[i].length() >= typed[i - 1].length()) and typed[0] == "r" and typed[-1] == PROMPT
	_check("acceptance: pressing fire winds it up and the shot leaves exactly 36 frames later (0.6 s), fire let go after one frame; meanwhile the strip types out \"rm: remove? [y]\", whole as the shot goes", wind["frames"] == 36 and typing and wind["spent"] == 1, "%d frames, spent %d, %s .. %s" % [wind["frames"], wind["spent"], typed[0] if not typed.is_empty() else "", typed[-1] if not typed.is_empty() else ""])
	await _until(func(): return wind["store"]["done"], 8000)
	# Cancels: a swap, a death, a respawn; nothing spent.
	var cancels := []
	for how in ["swap", "death", "respawn"]:
		await _ready_to_fire(p)
		var shots: int = p.shots_fired
		p.drive_input(Vector2.ZERO, false, false, true)
		await _frames(10)
		var charging: bool = p.is_charging()
		match how:
			"swap":
				p.select_slot(0)
			"death":
				p.set_alive(false)
			"respawn":
				p.respawn_at(main.to_global(Vector3(-14.0, STAND_Y, LINE_Z)))
		await _frames(50)
		cancels.append([how, charging, p.shots_fired == shots, inv.mags[SLOT] == 1, get_nodes_in_group(RmSlug.GROUP).filter(func(n): return main.is_ancestor_of(n)).is_empty()])
		if how == "death":
			p.set_alive(true)
		if how == "swap":
			p.select_slot(SLOT)
		await _settle(p, 0.5)
	_check("acceptance: a swap, a death or a respawn during the wind-up cancels it: no shot, the round still in the magazine", cancels.all(func(c): return c[1] and c[2] and c[3] and c[4]), str(cancels))
	# The weight: half the pace through the wind-up and 0.8 s after, no slide; then the full pace.
	p.respawn_at(main.to_global(Vector3(-16.0, STAND_Y, LINE_Z)))
	_aim(p, main.to_global(Vector3(18.0, 1.6, LINE_Z)))
	p.rotation.y = atan2(-1.0, 0.0)
	await _ready_to_fire(p)
	for i in 30:
		p.drive_input(Vector2(0.0, -1.0))
		await physics_frame
	var full_before: float = p.horizontal_speed()
	var shots_now: int = p.shots_fired
	p.drive_input(Vector2(0.0, -1.0), false, false, true)
	await physics_frame
	p.drive_input(Vector2(0.0, -1.0), false, true)
	await physics_frame
	var slid: bool = p.is_sliding()
	var during := []
	var after := []
	var fired_at := -1
	for i in 120:
		p.drive_input(Vector2(0.0, -1.0))
		await physics_frame
		if fired_at < 0 and p.shots_fired > shots_now:
			fired_at = i
		if fired_at < 0:
			during.append(p.horizontal_speed())
		else:
			after.append(p.horizontal_speed())
	var half: float = 7.0 * 0.5
	var slowed: bool = during.size() >= 30 and during.slice(10).all(func(v): return absf(v - half) < 0.01) and after.size() >= 70 and after.slice(1, 47).all(func(v): return absf(v - half) < 0.01) and absf(after[-1] - 7.0) < 0.01
	_check("acceptance: the move speed factor: running at %.1f m/s, the wind-up holds the player to half its pace (%.2f m/s), and so for 0.8 s after the shot, with no slide started; then the full 7 m/s again" % [full_before, during[-1] if not during.is_empty() else -1.0], absf(full_before - 7.0) < 0.01 and not slid and slowed, "%s / %s" % [during.slice(0, 4).map(func(v): return snappedf(v, 0.01)), after.slice(44, 52).map(func(v): return snappedf(v, 0.01))])
	# Mid-air the weight only eases the carried speed down (0.3 m/s a frame of air control), it
	# never cuts it in one frame (self-review pass 1).
	p.respawn_at(main.to_global(Vector3(-16.0, STAND_Y, LINE_Z)))
	p.rotation.y = atan2(-1.0, 0.0)
	await _ready_to_fire(p)
	for i in 30:
		p.drive_input(Vector2(0.0, -1.0))
		await physics_frame
	p.drive_input(Vector2(0.0, -1.0), true)
	await physics_frame
	p.drive_input(Vector2(0.0, -1.0), false, false, true)
	await physics_frame
	var air := []
	for i in 6:
		p.drive_input(Vector2(0.0, -1.0))
		await physics_frame
		air.append([snappedf(p.horizontal_speed(), 0.01), p.is_on_floor()])
	var eased: bool = air.all(func(a): return not a[1]) and air[0][0] >= 6.4 and range(1, air.size()).all(func(i): return air[i - 1][0] - air[i][0] <= 0.31 and air[i][0] < air[i - 1][0])
	_check("a wind-up started mid-air at 7 m/s eases the speed down a little each frame (%.2f, %.2f, ...), never cutting it to half at once" % [air[0][0], air[1][0]], eased, str(air))
	await _until(func(): return get_nodes_in_group(RmSlug.GROUP).filter(func(n): return main.is_ancestor_of(n)).is_empty(), 8000)
	# The blast on daemons: falloff by distance, none past the radius, none behind cover.
	p.respawn_at(main.to_global(Vector3(-14.0, STAND_Y, LINE_Z)))
	var target := _wall(main, main.to_global(Vector3(0.0, 2.0, LINE_Z)))
	var cover := _wall(main, main.to_global(Vector3(-0.6, 2.0, 13.5)), Vector3(5.0, 4.0, 0.2))
	_put(main, dummies, [[-0.6, 16.0], [-2.1, 18.5], [-4.1, 19.8], [-0.6, 12.0]])
	for d in dummies:
		d.max_health = 1000.0
		d.reset_for_round()
	await _settle(p, 0.3)
	_aim(p, main.to_global(Vector3(-0.1, MIDDLE_Y, LINE_Z)))
	await _ready_to_fire(p)
	var before := dummies.map(func(d): return d.health())
	var shot := await _wind_up(main, p)
	await _until(func(): return shot["store"]["done"], 8000)
	var blast: Vector3 = shot["store"].get("at", Vector3.INF)
	var taken := range(4).map(func(i): return before[i] - dummies[i].health())
	var expected := range(4).map(func(i): return _w.blast_damage_at(blast.distance_to(_middle(dummies[i])), false))
	var near_ok: bool = absf(taken[0] - expected[0]) < 0.001 and absf(taken[1] - expected[1]) < 0.001 and taken[0] > taken[1] and taken[1] > 0.0
	_check("acceptance: the blast's damage falls off with distance: on the wall 14 m out, %.1f to the daemon 1.1 m off, %.1f to the one 4 m off, nothing to the one 6.3 m off (past the radius)" % [taken[0], taken[1]], shot["store"].get("why", "") == RmSlug.WALL and near_ok and taken[2] == 0.0 and expected[2] == 0.0, "%s against %s" % [taken.map(func(x): return snappedf(x, 0.01)), expected.map(func(x): return snappedf(x, 0.01))])
	_check("acceptance: level geometry between the blast and a target blocks it: the daemon 3 m off behind a slab of cover takes nothing (%.1f in the open)" % expected[3], taken[3] == 0.0 and expected[3] > 0.0, str(taken))
	_check("the blast lands with the weapon's hit sound and is the round's \"rm -rf\" callout, at once", shot["store"].get("hit_sound", false) and calls.size() >= 1 and calls.all(func(c): return c == "rm -rf"), str(calls))
	# Root: 1.5 times, no round spent, a 9 m blast, a 0.3 s wind-up.
	var sudo = p.get("sudo")
	sudo.state.charges = 1
	sudo.press()
	var rooted := await _until(func(): return sudo.is_root(), 4000)
	await _settle(p, 0.2)
	_aim(p, main.to_global(Vector3(-0.1, MIDDLE_Y, LINE_Z)))
	await _ready_to_fire(p)
	before = dummies.map(func(d): return d.health())
	var root_shot := await _wind_up(main, p)
	await _until(func(): return root_shot["store"]["done"], 8000)
	blast = root_shot["store"].get("at", Vector3.INF)
	taken = range(4).map(func(i): return before[i] - dummies[i].health())
	expected = range(4).map(func(i): return _w.blast_damage_at(blast.distance_to(_middle(dummies[i])), true) * 1.5)
	var root_ok: bool = absf(taken[0] - expected[0]) < 0.001 and absf(taken[2] - expected[2]) < 0.001 and taken[2] > 0.0 and taken[3] == 0.0
	_check("acceptance: as root (--no-preserve-root): the wind-up is 18 frames (0.3 s), the blast 1.5 times as hard (%.1f to the nearest), it reaches 9 m (the daemon 6.3 m off takes %.1f), cover still stops it, and no round is spent" % [taken[0], taken[2]], rooted and root_shot["frames"] == 18 and root_ok and root_shot["spent"] == 0, "%d frames, spent %d, %s against %s" % [root_shot["frames"], root_shot["spent"], taken.map(func(x): return snappedf(x, 0.01)), expected.map(func(x): return snappedf(x, 0.01))])
	sudo.end_root()
	for n in [target, cover]:
		n.queue_free()
	_drop(arena)
	await _frames(3)
	var orphans_after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_check("alone: no orphan node left behind", orphans_after <= orphans, "%d before, %d after" % [orphans, orphans_after])


## The magazine full, the interval and any reload over, the player at rest.
func _ready_to_fire(p: Node) -> void:
	var inv = p.get("inventory")
	inv.mags[SLOT] = 1
	inv.cooldowns[SLOT] = 0.0
	inv.reload_left = 0.0
	await _settle(p, 0.1)


## Presses fire once and counts the frames until the shot leaves: {frames, prompts (the strip's
## third line each frame of the wind-up), spent (rounds), store (the slug's record)}.
func _wind_up(main: Node, p: Node) -> Dictionary:
	for rng in ["_pellet_rng", "_rng", "_shake_rng"]:
		(p.get(rng) as RandomNumberGenerator).seed = SEED
	(p.get("_sfx")[SLOT][1] as AudioStreamPlayer).stop()
	var inv = p.get("inventory")
	var mag: int = inv.mags[SLOT]
	var shots: int = p.shots_fired
	var wh = main.get_node("Hud").weapon_hud()
	var prompts := []
	p.drive_input(Vector2.ZERO, false, false, true)
	var n := 0
	while p.shots_fired == shots and n < 120:
		await physics_frame
		n += 1
		await process_frame
		if p.shots_fired == shots and p.is_charging():
			prompts.append(wh.state_text())
	var slug: Node = null
	for node in get_nodes_in_group(RmSlug.GROUP):
		if main.is_ancestor_of(node) and not node.is_queued_for_deletion():
			slug = node
	var store := _track(slug, p) if slug != null else {"done": true}
	return {"frames": n, "prompts": prompts, "spent": mag - inv.mags[SLOT], "store": store}


## The arena's four dummies at full health 100, out of the way until placed.
func _line_up(main: Node) -> Array:
	var out := []
	for name in ["DummyA", "DummyB", "DummyC", "DummyD"]:
		out.append(main.get_node("Arena/Targets/" + name))
	_put(main, out, [])
	return out


func _put(main: Node, dummies: Array, places: Array) -> void:
	for i in dummies.size():
		var d: Node3D = dummies[i]
		var at: Vector3 = Vector3(places[i][0], 0.0, places[i][1]) if i < places.size() else Vector3(-17.0 + i * 0.1, 0.0, -18.0 + i * 1.2)
		d.global_position = main.to_global(at)
		d.max_health = 100.0
		if d.is_alive():
			d.reset_for_round()


func _middle(d: Node3D) -> Vector3:
	return d.global_position + Vector3.UP * MIDDLE_Y


# --- Seven slots at 960x540. ---

func _layout_checks() -> void:
	var before := root.size
	for size in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = size
		var host := _branch("Layout", Vector3.ZERO)
		await _frames(2)
		host["session"].host(0)
		var p = host["player"]
		var hud: CombatHud = host["hud"].combat_hud()
		host["session"].players[7] = {"slot": 2, "name": "Daemon-2"}
		for i in 4:
			hud.entries.push_front({"killer": "Daemon-2", "victim": "Daemon-1", "word": "rm -rf", "left": 30.0})
		host["hud"].guide()._notice("word ".repeat(60), Color.WHITE, 5000)
		host["hud"].net_hud().toggle()
		var wrong := PackedStringArray()
		var strips := []
		for slot in [1, SLOT]:
			p.select_slot(slot)
			await _settle(p, 0.5)
			if slot == SLOT:
				p.get("inventory").mags[SLOT] = 1
				p.drive_input(Vector2.ZERO, false, false, true)
				await _frames(30)
			await process_frame
			var screen := Rect2(Vector2.ZERO, Vector2(root.size))
			var guide: Control = host["hud"].guide().get("_panel")
			var panels := [host["hud"].net_hud().get("_panel"), guide]
			var strip: Control = host["hud"].weapon_hud().get("_stack")
			var feed: Control = hud.get("_feed")
			var strip_labels := 0
			for label in host["main"].find_children("*", "Label", true, false):
				if not label.is_visible_in_tree() or label.text.is_empty():
					continue
				var rect: Rect2 = label.get_global_rect()
				if strip.is_ancestor_of(label):
					strip_labels += 1
					if feed.get_global_rect().intersects(rect):
						wrong.append("strip under the feed: %s" % label.text)
				if not screen.encloses(rect):
					wrong.append("outside: %s %s" % [label.text.left(20), rect])
				if rect.size.x >= screen.size.x:
					continue
				for panel in panels:
					if not panel.is_ancestor_of(label) and panel.get_global_rect().intersects(rect):
						wrong.append("under a panel: %s %s" % [label.text.left(20), rect])
			var clear_px: float = strip.get_global_rect().position.x - guide.get_global_rect().end.x if guide.visible else INF
			strips.append([host["hud"].weapon_hud().slots_text(), strip_labels, host["hud"].weapon_hud().state_text(), snappedf(clear_px, 0.1)])
			await _settle(p, 1.2)
		_check("acceptance: at %dx%d the strip fits seven slots clear of the guide panel: with SIGTERM drawn (\"%s\") and with the rm -rf cannon winding up (\"%s\", its prompt \"%s\" on the third line), four rm -rf kills in the feed, the net panel and a long guide notice all inside the screen, nothing covering anything" % [size.x, size.y, strips[0][0], strips[1][0], strips[1][2]], wrong.is_empty() and strips[0][0] == "1 [2 SIGTERM] 3 4(2) 5 6 7" and strips[1][0] == "1 2 3 4(2) 5 6 [7 rm -rf]" and strips[0][1] == 11 and strips[1][1] == 11 and PROMPT.begins_with(strips[1][2]) and strips[1][2].length() >= 7 and strips[0][3] > 0.0 and strips[1][3] > 0.0 and hud.feed_text().size() == 4 and hud.feed_text()[0] == "rm -rf sent by Daemon-2 to Daemon-1", "%s; %s" % [strips, ", ".join(wrong)])
		_drop(host)
		await _frames(2)
	root.size = before


# --- A match: a host and two joiners. ---

func _match_checks() -> void:
	var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var host := _branch("Host", Vector3.ZERO)
	var hs: Session = host["session"]
	hs.host(0)
	await _frames(2)
	var old := _branch("Old", OLD_OFFSET, 8)
	var os: Session = old["session"]
	os.join("127.0.0.1:%d" % hs.listen_port())
	var refused := await _until(func(): return os.state == Session.State.FAILED, 6000)
	_check("acceptance: protocol 9 still: a joiner on protocol 8 is refused with the clear version line", Session.PROTOCOL == 9 and refused and os.error == "version mismatch: host 9, you 8", os.error)
	_drop(old)
	await _frames(2)
	var client := _branch("Client", CLIENT_OFFSET)
	var cs: Session = client["session"]
	cs.join("127.0.0.1:%d" % hs.listen_port())
	await _until(func(): return cs.state == Session.State.JOINED and hs.players.size() == 2, 6000)
	var other := _branch("ClientB", CLIENT_B_OFFSET)
	var bs: Session = other["session"]
	bs.join("127.0.0.1:%d" % hs.listen_port())
	var joined := await _until(func(): return bs.state == Session.State.JOINED and hs.players.size() == 3 and cs.players.size() == 3 and bs.players.size() == 3)
	var cid: int = cs.my_id
	var bid: int = bs.my_id
	await _until(func(): return hs.avatars.has(cid) and hs.avatars.has(bid) and cs.avatars.has(1) and bs.avatars.has(1) and hs.combat.has_player(cid) and hs.combat.has_player(bid) and cs.get("_weapons_synced") and bs.get("_weapons_synced"), 6000)
	await _until(func(): return [1, cid, bid].all(func(id): return hs.protect_left.get(id, 0.0) <= 0.0), 6000)
	var hp: Node = host["player"]
	var cp: Node = client["player"]
	cp.select_slot(SLOT)
	var drawn := await _until(func(): return hs.combat.drawn_by(cid) == "rm_rf_cannon", 4000)
	# One blast on the host (at its centre), the other joiner and the shooter itself.
	_place(host, Vector3(-2.0, STAND_Y, LINE_Z), Vector3(-1.0, 0.0, 0.0))
	_place(client, Vector3(-6.0, STAND_Y, LINE_Z), Vector3(1.0, 0.0, 0.0))
	_place(other, Vector3(-2.0, STAND_Y, LINE_Z + 4.0), Vector3(-1.0, 0.0, 0.0))
	await _settle(cp, 0.6)
	await _until(_heard.bind(hs, cid, client), 4000)
	await _until(_heard.bind(hs, bid, other), 4000)
	_aim(cp, client["main"].to_global(Vector3(-2.0, STAND_Y, LINE_Z)))
	await _settle(cp, 0.3)
	await _until(_heard.bind(hs, cid, client), 4000)
	for id in [1, cid, bid]:
		hs.combat.states[id]["health"] = 100.0
	hs.call("_mirror_from_combat")
	var deaths: int = hs.combat.states[cid]["deaths"]
	var pair := await _match_shot(hs, [cs, bs], cp)
	var hv: Dictionary = pair[0]
	var at: Vector3 = hv.get("at", Vector3.INF)
	var hmid: Vector3 = hp.global_position
	var cmid: Vector3 = host["main"].to_global(hs.avatars[cid].latest_position())
	var bmid: Vector3 = host["main"].to_global(hs.avatars[bid].latest_position())
	var want := {1: _w.blast_damage_at(at.distance_to(hmid), false), cid: _w.blast_damage_at(at.distance_to(cmid), false) * _w.self_damage_share, bid: _w.blast_damage_at(at.distance_to(bmid), false)}
	var got := {1: 100.0 - hs.combat.health_of(1), cid: 100.0 - hs.combat.health_of(cid), bid: 100.0 - hs.combat.health_of(bid)}
	var dead := await _until(func(): return hs.dead.get(1, false) and cs.dead.get(1, false) and bs.dead.get(1, false), 4000)
	var agreed := await _until(func(): return [cs, bs].all(func(s): return absf(s.health.get(cid, -1.0) - hs.combat.health_of(cid)) < EPS and absf(s.health.get(bid, -1.0) - hs.combat.health_of(bid)) < EPS), 4000)
	_check("acceptance: a 127.0.0.1 match, a host and two joiners: the shooter's slug goes off on the host, and the host judges the blast on everyone in it: itself at the centre, derezzed from full health (%.1f), the other joiner 4 m off (%.1f) and the shooter itself 3.6 m off at half (%.1f), each exactly the falloff for its distance; both joiners' screens show the host's numbers" % [want[1], got[bid], got[cid]], joined and drawn and hv.get("authoritative", false) and hv.get("why", "") == RmSlug.BODY and hv.get("landed", 0) == 3 and want[1] >= 100.0 and dead and absf(got[cid] - want[cid]) < 0.001 and absf(got[bid] - want[bid]) < 0.001 and got[cid] > 0.0 and got[bid] > 0.0 and agreed and hs.combat.states[cid]["deaths"] == deaths, "host %s, got %s, want %s" % [_brief(hv), _rounded(got), _rounded(want)])
	var feed_ok := await _until(func(): return [host, client, other].all(func(side): return side["hud"].combat_hud().feed_text().has("rm -rf sent by Daemon-2 to Daemon-1")), 4000)
	_check("acceptance: the kill is the host's to judge, and the feed names it on all three screens: \"rm -rf sent by Daemon-2 to Daemon-1\"", feed_ok, str(host["hud"].combat_hud().feed_text()))
	var cv: Dictionary = pair[1]
	var bv: Dictionary = pair[2]
	var same: bool = cv.get("at_local", Vector3.INF).distance_to(hv.get("at_local", Vector3.ZERO)) < 0.001 and bv.get("at_local", Vector3.INF).distance_to(hv.get("at_local", Vector3.ZERO)) < 0.001
	_check("acceptance: a joiner never decides damage: both joiners' slugs only draw (no judge, nothing landed) and go off on the host's word, at the host's place", not cv.get("authoritative", true) and not bv.get("authoritative", true) and cv.get("why", "") == RmSlug.WORD and bv.get("why", "") == RmSlug.WORD and cv.get("landed", -1) == 0 and bv.get("landed", -1) == 0 and same, "%s / %s / same %s" % [_brief(cv), _brief(bv), same])
	# The self-kill: a slab a step ahead, the shooter low; cover keeps the others out of it.
	await _until(func(): return not hs.dead.get(1, false) and not cs.dead.get(1, false), 8000)
	cp.reload_weapon()
	await _settle(cp, 3.6)
	_place(host, Vector3(-2.0, STAND_Y, LINE_Z), Vector3(-1.0, 0.0, 0.0))
	_place(client, Vector3(-6.0, STAND_Y, LINE_Z), Vector3(1.0, 0.0, 0.0))
	_place(other, Vector3(-2.0, STAND_Y, LINE_Z + 4.0), Vector3(-1.0, 0.0, 0.0))
	var slab := _wall(host["main"], host["main"].to_global(Vector3(-4.5, 2.0, LINE_Z)))
	await _settle(cp, 0.6)
	await _until(_heard.bind(hs, cid, client), 4000)
	await _until(_heard.bind(hs, bid, other), 4000)
	_aim(cp, client["main"].to_global(Vector3(-2.0, STAND_Y, LINE_Z)))
	await _settle(cp, 0.3)
	await _until(_heard.bind(hs, cid, client), 4000)
	for id in [1, bid]:
		hs.combat.states[id]["health"] = 100.0
	hs.combat.states[cid]["health"] = 20.0
	hs.call("_mirror_from_combat")
	var kills: int = hs.combat.states[cid]["kills"]
	var selfie := await _match_shot(hs, [cs, bs], cp)
	var self_dead := await _until(func(): return hs.dead.get(cid, false) and cs.dead.get(cid, false) and bs.dead.get(cid, false), 4000)
	var self_feed := await _until(func(): return [host, client, other].all(func(side): return side["hud"].combat_hud().feed_text().has("rm -rf: Daemon-2 removed themself")), 4000)
	_check("acceptance: friendly fire: point-blank on a slab, the shooter's own blast derezzes it from 20 health, credits it no kill, and every screen's feed reads \"rm -rf: Daemon-2 removed themself\"; the host and the other joiner behind the slab take nothing (cover)", selfie[0].get("why", "") == RmSlug.WALL and self_dead and self_feed and hs.combat.states[cid]["kills"] == kills and hs.combat.health_of(1) == 100.0 and hs.combat.health_of(bid) == 100.0, "%s, kills %d -> %d, %s" % [_brief(selfie[0]), kills, hs.combat.states[cid]["kills"], host["hud"].combat_hud().feed_text()])
	slab.queue_free()
	_drop(host)
	_drop(client)
	_drop(other)
	await _frames(4)
	var orphans_after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_check("acceptance: no orphan nodes are left behind by any of it", orphans_after <= orphans, "%d before, %d after" % [orphans, orphans_after])


## `shooter` fires once in the match (its wind-up first); waits for the host's slug and each
## joiner's drawn one of that shot to be done: [the host's record, then each of `joiners`'].
func _match_shot(hs: Session, joiners: Array, shooter: Node) -> Array:
	(hs.get("_seeds") as RandomNumberGenerator).seed = SEED
	for rng in ["_pellet_rng", "_rng", "_shake_rng"]:
		(shooter.get(rng) as RandomNumberGenerator).seed = SEED
	var before: int = hs.get("_throws")
	var id := before + 1
	var sessions := [hs] + joiners
	var stores := []
	for s in sessions:
		stores.append({})
	shooter.drive_input(Vector2.ZERO, false, false, true)
	# Each side's slug is tracked the frame it appears: a point-blank one goes off within frames.
	var t0 := Time.get_ticks_msec()
	while stores.any(func(s): return s.is_empty()) and Time.get_ticks_msec() - t0 < 6000:
		for i in sessions.size():
			if stores[i].is_empty() and sessions[i].get("_volleys").has(id):
				stores[i] = _track(sessions[i].get("_volleys")[id], null, sessions[i])
		if stores.any(func(s): return s.is_empty()):
			await physics_frame
	if stores.any(func(s): return s.is_empty()):
		return [{}, {}, {}]
	await _until(func(): return stores.all(func(s): return s["done"]), 8000)
	return stores


# --- Helpers. ---

## A record of slug `v` taken the moment it is done (with `player`, whether its hit sound is
## playing then; with `session`, where it went off in that arena's own space).
func _track(v: Node, player: Node = null, session: Node = null) -> Dictionary:
	var store := {"done": false, "authoritative": v.authoritative}
	v.finished.connect(_snap.bind(v, store, player, session))
	return store


func _snap(landed: int, v: Node, store: Dictionary, player: Node, session: Node) -> void:
	store["done"] = true
	if player != null:
		store["hit_sound"] = (player.get("_sfx")[SLOT][1] as AudioStreamPlayer).playing
	store["landed"] = landed
	store["why"] = v.why
	store["at"] = v.at
	store["flown"] = v.flown
	store["steps"] = v.steps.duplicate()
	if session != null and v.at.is_finite():
		var arena: Node3D = session.get("_arena")
		store["at_local"] = arena.to_local(v.at)


## A slug's record without places: what a match check prints.
func _brief(store: Dictionary) -> String:
	return "%s, landed %d, deciding %s" % [store.get("why", ""), store.get("landed", 0), store.get("authoritative", false)]


func _rounded(d: Dictionary) -> String:
	var out := PackedStringArray()
	for k in d:
		out.append("%.1f" % d[k])
	return ", ".join(out)


## A slab on `layer` (the level unless told), `size` (0.2 m thick, 4 m high and wide by default),
## at `at`.
func _wall(parent: Node, at: Vector3, size: Vector3 = Vector3(0.2, 4.0, 4.0), layer: int = 1) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.collision_layer = layer
	wall.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	wall.add_child(shape)
	parent.add_child(wall)
	wall.global_position = at
	return wall


func _place(side: Dictionary, at: Vector3, facing: Vector3) -> void:
	var p: Node = side["player"]
	p.respawn_at(side["main"].to_global(at))
	p.rotation.y = atan2(-facing.x, -facing.z)
	p.get_node("Head").rotation.x = 0.0


func _aim(player: Node, target: Vector3) -> void:
	var cam: Node3D = player.get_node("Head/Camera")
	var to: Vector3 = target - cam.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	player.get_node("Head").rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


func _settle(p: Node, seconds: float) -> void:
	for i in ceili(seconds * 60.0):
		p.drive_input(Vector2.ZERO)
		await physics_frame


func _heard(hs: Session, id: int, side: Dictionary) -> bool:
	var avatar = hs.avatars.get(id)
	var p: Node = side["player"]
	if avatar == null or not is_instance_valid(avatar) or not avatar.visible:
		return false
	var here: Vector3 = side["main"].to_local(p.global_position)
	var look := (Basis(Vector3.UP, p.rotation.y) * Basis(Vector3.RIGHT, p.view_pitch()) * Vector3.FORWARD).normalized()
	return avatar.latest_position().distance_to(here) < 0.05 and avatar.latest_view().angle_to(look) < deg_to_rad(1.0)


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
	t.max_players = 3
	return t


func _combat_tuning() -> Resource:
	var t := CombatTuningScript.new()
	t.respawn_delay_s = 1.0
	t.spawn_protection_s = 0.3
	t.kill_feed_fade_s = 30.0
	return t


func _branch(name: String, offset: Vector3, protocol: int = -1) -> Dictionary:
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
	if protocol >= 0:
		session.protocol = protocol
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
	var rpc := source.find("\n@rpc(", at + 1)
	if rpc > 0 and (end < 0 or rpc < end):
		end = rpc
	return source.substr(at, (end if end > 0 else source.length()) - at)


func _cleanup() -> void:
	for node in _arenas.duplicate() + _branches.duplicate() + _scratch.duplicate():
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
