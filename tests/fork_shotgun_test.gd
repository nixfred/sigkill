extends SceneTree
## Headless fork() shotgun test for SIGKILL (C24). scripts/check.sh runs it, and any FAIL
## exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/fork_shotgun_test.gd
##
## fork() (PRD 5.2, "shotgun whose pellets split in two mid-flight"): the resource and its
## numbers, bad values refused; the fan and the fork alone (the plane, the angles, the seed);
## volleys in an empty test world, frame by frame: 6 pellets, then 12 at exactly the fork
## distance, 24 with root's second fork, every one gone at exactly the range; the same seed the
## same pellets, another seed others; a wall stops every pellet at its face. In the real arena
## with the real player: slot 5 on key 5, the wheel and Q; a point-blank shot whose 6 pellets
## all land at full damage before their fork and never fork; children doing 0.6 of it; the
## point-blank total above the long-range total on the same dummy; root forking twice. Scans
## that the new code runs, calls and reads nothing real (no OS call, no fork(), no /proc) and
## that the shot needs no new message. Then a host and a joiner over ENet on 127.0.0.1: both
## screens draw the same pellets from the host's seed; only the host judges; both agree on the
## health it says; a kill named "fork()" in the feed; root's second fork on both screens. No
## orphan nodes. Deterministic: seeds pinned where a check reads them, times counted in physics
## frames, nothing waits a frame count for the network.

const Session = preload("res://scripts/net/net_session.gd")
const NetTuningScript = preload("res://scripts/net/net_tuning.gd")
const CombatTuningScript = preload("res://scripts/net/combat_tuning.gd")
const WeaponDefScript = preload("res://scripts/weapons/weapon_def.gd")
const ForkVolley = preload("res://scripts/weapons/fork_volley.gd")
const Arsenal = preload("res://scripts/weapons/arsenal_tuning.gd")
const Controls = preload("res://scripts/controls.gd")
const Palette = preload("res://scripts/palette.gd")
const Link = preload("res://scripts/guide/guide_link.gd")
const MainScene = preload("res://scenes/main.tscn")
const TUNING_PATH := "res://resources/fork_shotgun.tres"
const SLOT := 4
const WATCHDOG_MS := 10000
const CLIENT_OFFSET := Vector3(1000.0, 0.0, 0.0)
const OLD_OFFSET := Vector3(2000.0, 0.0, 0.0)
## High above every arena: the empty test world's volleys meet nothing there.
const EMPTY_AT := Vector3(0.0, 300.0, 600.0)
const STAND_Y := 0.95
const LINE_Z := 15.0
const EPS := 0.0001
const SEED := 424242

var _fails := 0
var _checks := 0
var _tmp := ""
var _w: Resource
var _arenas: Array = []
var _branches: Array = []
var _scratch: Array = []


func _initialize() -> void:
	GameSettings.current().set_value("gameplay", "practice", true)  # these checks predate C27b: the daemons stay the old never-attack dummies
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_tmp = OS.get_temp_dir().path_join("sigkill-fork-shotgun-test-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(_tmp)
	Controls.ensure()
	_w = load(TUNING_PATH)
	_tuning_checks()
	_geometry_checks()
	_source_checks()
	await _empty_world_checks()
	await _wall_checks()
	await _arena_checks()
	await _match_checks()
	await _cleanup()
	for name in DirAccess.get_files_at(_tmp):
		DirAccess.remove_absolute(_tmp.path_join(name))
	DirAccess.remove_absolute(_tmp)
	print("FORK SHOTGUN: %d checks" % _checks)
	print("FORK SHOTGUN RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The resource, the geometry, the source. ---

func _tuning_checks() -> void:
	var w = _w
	var sigterm = load("res://resources/sigterm.tres")
	_check("acceptance: every number is one resource, resources/fork_shotgun.tres, a WeaponDef that passes its own checks", w is WeaponDefScript and w.problems().is_empty() and w.is_fork(), str(w.problems()) if w is WeaponDefScript else "")
	_check("its numbers: 6 pellets in a 5 degree fan each side, 12 damage, 90 m/s, a fork every 4 m 10 degrees apart, children 0.6, one fork (two as root), gone at 30 m", w.pellet_count == 6 and w.spread_degrees == 5.0 and w.damage == 12.0 and w.pellet_speed == 90.0 and w.fork_distance_m == 4.0 and w.fork_angle_degrees == 10.0 and w.child_damage_share == 0.6 and w.fork_generations == 1 and w.root_fork_generations == 2 and w.fire_range == 30.0)
	_check("a shotgun like the others, slower than SIGTERM: a 1.2 s pump (SIGTERM's 0.9), 4 shells and 16 in reserve, a 2.6 s reload on E (SIGTERM's 2.2); its own yellow from the palette, \"fork()\" in the feed and its fiction line", w.fire_cooldown == 1.2 and w.fire_cooldown > sigterm.fire_cooldown and w.magazine_size == 4 and w.reserve_ammo == 16 and w.reload_s == 2.6 and w.reload_s > sigterm.reload_s and w.light_skin == "yellow" and w.skin_body() == Palette.CROSSHAIR_YELLOW and w.kill_word == "fork()" and w.fiction == "fork(): split in two." and w.short_name == "fork()")
	var cases := [
		["pellet_speed", 5.0, "pellet_speed"], ["pellet_speed", NAN, "pellet_speed"], ["fork_distance_m", 0.0, "fork_distance_m"], ["fork_distance_m", 20.0, "fork_distance_m"],
		["fork_angle_degrees", 0.0, "fork_angle_degrees"], ["fork_angle_degrees", 90.0, "fork_angle_degrees"], ["child_damage_share", 0.0, "child_damage_share"], ["child_damage_share", 1.5, "child_damage_share"],
		["fork_generations", 0, "fork_generations"], ["root_fork_generations", 4, "root_fork_generations"], ["pellet_count", 20, "at most 64 pellets"], ["falloff_floor", 0.5, "falloff_floor"],
		["magazine_size", -1, "from a magazine"], ["pellet_trail_m", 0.0, "pellet_trail_m"], ["fork_flash_s", 9.0, "fork_flash_s"], ["spread_degrees", 0.0, "spread above 0"],
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
	var odd = sigterm.duplicate()
	odd.pellet_speed = 90.0
	if not ", ".join(odd.problems()).contains("only fork() pellets"):
		missed.append("SIGTERM with a pellet speed: %s" % odd.problems())
	_check("bad values are refused with the reason: too slow or NaN, no fork or a fork past the range, no angle or too wide, children worth nothing or more than the parent, no fork or a third root fork, more than 64 pellets a shot, falloff, no magazine, no trail, a long flash, no spread; and the fork group on any other weapon", missed.is_empty(), " | ".join(missed))


func _geometry_checks() -> void:
	var w = _w
	var aim := Vector3(1.0, -0.2, 0.3).normalized()
	var fan: PackedVector3Array = w.fork_spread(aim, SEED)
	var axis: Vector3 = WeaponDefScript.fork_axis(aim)
	var flat := true
	var inside := true
	var angles := []
	for d in fan:
		flat = flat and absf(d.dot(axis)) < EPS
		var a := rad_to_deg(aim.signed_angle_to(d, axis))
		angles.append(a)
		inside = inside and absf(a) <= w.spread_degrees + EPS
	var sorted := angles.duplicate()
	sorted.sort()
	_check("the fan alone: 6 directions in one plane through the aim (a level one turned about the axis square to the aim and its right-hand side), within 5 degrees each side, one in each sixth of the fan", fan.size() == 6 and flat and inside and angles == sorted, str(angles.map(func(x): return snappedf(x, 0.01))))
	var again: PackedVector3Array = w.fork_spread(aim, SEED)
	var other: PackedVector3Array = w.fork_spread(aim, SEED + 1)
	_check("the fan comes from the aim and the seed alone: the same seed gives the same fan, another seed another", again == fan and other != fan)
	var pair: PackedVector3Array = w.fork_pair(fan[2], aim)
	var apart := rad_to_deg(pair[0].angle_to(pair[1]))
	var even := absf(rad_to_deg(fan[2].angle_to(pair[0])) - rad_to_deg(fan[2].angle_to(pair[1]))) < 0.001
	_check("a fork alone: two children 10 degrees apart, one each side of the parent, both in the plane of the fan", absf(apart - 10.0) < 0.001 and even and absf(pair[0].dot(axis)) < EPS and absf(pair[1].dot(axis)) < EPS, "%.4f" % apart)
	_check("acceptance: a child does the parent's damage times 0.6 (12 then 7.2, and 4.32 for root's second fork); 6 pellets make 12, then 24", w.fork_damage(0) == 12.0 and absf(w.fork_damage(1) - 7.2) < EPS and absf(w.fork_damage(2) - 4.32) < EPS and w.pellets_after(1) == 12 and w.pellets_after(2) == 24)


func _source_checks() -> void:
	var mine := _code("res://scripts/weapons/fork_volley.gd")
	var weapon := _code("res://scripts/weapons/weapon_def.gd")
	var player := _code("res://scripts/player.gd")
	var session := _code("res://scripts/net/net_session.gd")
	var parts := mine + _body(weapon, "fork_spread") + _body(weapon, "fork_pair") + _body(weapon, "fork_axis") + _body(weapon, "_fork_problems") + _body(weapon, "fork_damage")
	parts += _body(player, "_fire_fork") + _body(player, "fork_hit") + _body(player, "take_volley") + _body(session, "_spawn_volley") + _body(session, "_judge_pellet") + _body(session, "_pellets_past") + _body(session, "_tell_seed")
	var found := PackedStringArray()
	for word in ["OS.", "execute", "create_process", "/proc", "FileAccess", "DirAccess", "Thread", "HTTP", "PacketPeer", "StreamPeer"]:
		if parts.contains(word):
			found.append(word)
	var bare := RegEx.create_from_string("(?<![\\w.])fork\\s*\\(")
	var unquoted := RegEx.create_from_string("\"(?:\\\\.|[^\"\\\\])*\"").sub(parts, "\"\"", true)
	if bare.search(unquoted) != null:
		found.append("a call to fork()")
	if mine.contains("rpc"):
		found.append("rpc in the volley")
	_check("acceptance: fiction only: the new code calls no fork(), no OS call at all (no command, no process, no /proc), opens nothing and sends nothing itself", found.is_empty() and parts.length() > 2000, ", ".join(found))
	var fire := _body(session, "_handle_fire")
	var bomb := _body(session, "_bomb")
	_check("acceptance: no new message, protocol 8 (9 since C25's grep marks, which reuse the seed message, 10 since C27b's daemons, 20 RPCs then and 23 since): the shot is the usual intent; the host checks it as any shot, draws the seed with its own generator, runs the volley that judges and tells every joiner the seed in the fork bomb's seed message; damage goes out as the usual shot and death messages", Session.PROTOCOL == 10 and session.count("@rpc(") == 23 and fire.find("combat.accept(") < fire.find("if def.is_fork():") and fire.contains("var shot_seed := _seeds.randi()") and fire.contains("_spawn_volley(_throws, shooter, weapon, shot_seed, origin, dir, true)") and fire.contains("_tell_seed(_throws, shooter, weapon, shot_seed, origin, dir)") and bomb.contains("_spawn_volley(throw_id, thrower, weapon, seed, origin, dir, false)") and _body(session, "_judge_pellet").contains("if state != State.HOSTING or combat == null") and _body(session, "_judge_pellet").contains("_broadcast_shot(") and _body(session, "_judge_pellet").contains("_broadcast_death("))
	_check("a client never decides damage: a joiner's volley never judges a player (at most its own dummies, as every weapon's local shot does), and only the host's volley calls _judge_pellet", _body(session, "_spawn_volley").contains("if deciding:\n\t\tjudge = _judge_pellet.bind(shooter, weapon, origin)") and _body(session, "_spawn_volley").contains("judge = _player.fork_hit.bind(def)") and session.count("_judge_pellet.bind(") == 1 and not _body(player, "fork_hit").contains("session"))


# --- Volleys in an empty world. ---

func _empty_world_checks() -> void:
	var world := Node3D.new()
	world.name = "EmptyWorld"
	root.add_child(world)
	_scratch.append(world)
	var aim := Vector3(1.0, 0.0, 0.0)
	# One fork: 6 pellets, 12 at 4 m, every one gone at 30 m.
	var v: Node = ForkVolley.spawn(world, _w, EMPTY_AT, aim, SEED, 1, true, _w.hit_mask)
	var store := _track(v)
	var live := [v.live_count()]
	var first: Array = v.spawned.duplicate()
	var furthest := 0.0
	var look := []
	for i in 40:
		await physics_frame
		if store["done"]:
			break
		live.append(v.live_count())
		for f in v.flights():
			furthest = maxf(furthest, f[2])
		if look.is_empty() and v.forked_count == 6:
			look = [v.live_count(), v.find_children("*", "MeshInstance3D", false, false).size()]
	var stages := []
	for n in live:
		if stages.is_empty() or stages[-1] != n:
			stages.append(n)
	var ends: Array = store.get("ends", [])
	var fork_points := ends.filter(func(e): return e[4] == ForkVolley.FORKED)
	var at_four := fork_points.all(func(e): return absf((e[2] - EMPTY_AT).length() - 4.0) < 0.001 and absf(e[3] - 4.0) < 0.001)
	var at_range := ends.filter(func(e): return e[4] == ForkVolley.RANGE)
	var full := at_range.all(func(e): return absf(e[3] - 30.0) < 0.001 and (e[2] - EMPTY_AT).length() <= 30.0 + 0.001)
	_check("acceptance: a shot spawns its 6 pellets, and each forks into exactly two at the fork distance: 6, then 12 (6 forks, every one exactly 4 m out)", first == [6, 0] and stages.slice(0, 2) == [6, 12] and store.get("spawned", []) == [6, 12] and store.get("forked", -1) == 6 and fork_points.size() == 6 and at_four, "stages %s, spawned %s, first %s, forked %s, %d fork points, at 4 m %s: %s" % [stages, store.get("spawned", []), first, store.get("forked", -1), fork_points.size(), at_four, fork_points.map(func(e): return [snappedf((e[2] - EMPTY_AT).length(), 0.0001), snappedf(e[3], 0.0001)])])
	_check("acceptance: past the range they vanish: all 12 children gone at exactly 30 m flown (none further from the muzzle), nothing left flying, the volley freed", stages == [6, 12] and at_range.size() == 12 and full and furthest <= 30.0 + 0.001 and store.get("expired", -1) == 12 and store["done"], "stages %s, furthest %.4f, %d at range" % [stages, furthest, at_range.size()])
	_check("the look: every live pellet a glowing head and a thin trail, and each fork a small flash: on the frame of the fork, 12 pellets make 24 meshes and the 6 flashes 6 more", look == [12, 30], str(look))
	# Root's second fork: 24.
	var r: Node = ForkVolley.spawn(world, _w, EMPTY_AT, aim, SEED, 2, true, _w.hit_mask)
	var rstore := _track(r)
	var rlive := [r.live_count()]
	for i in 40:
		await physics_frame
		if rstore["done"]:
			break
		rlive.append(r.live_count())
	var rstages := []
	for n in rlive:
		if rstages.is_empty() or rstages[-1] != n:
			rstages.append(n)
	var second: Array = rstore.get("ends", []).filter(func(e): return e[4] == ForkVolley.FORKED and e[0] == 1)
	_check("acceptance: with sudo's overcharge the children fork once more: 6, then 12 at 4 m, then 24 at 8 m (18 forks), all 24 gone at 30 m", rstages.slice(0, 3) == [6, 12, 24] and rstore.get("spawned", []) == [6, 12, 24] and rstore.get("forked", -1) == 18 and second.size() == 12 and second.all(func(e): return absf(e[3] - 8.0) < 0.001) and rstore.get("expired", -1) == 24, "stages %s" % [rstages])
	# Deterministic: the same seed draws the same pellets, frame by frame.
	var a: Node = ForkVolley.spawn(world, _w, EMPTY_AT, aim, SEED, 1, true, _w.hit_mask)
	var b: Node = ForkVolley.spawn(world, _w, EMPTY_AT, aim, SEED, 1, false, _w.hit_mask)
	var c: Node = ForkVolley.spawn(world, _w, EMPTY_AT, aim, SEED + 7, 1, true, _w.hit_mask)
	var same := true
	var differs := false
	var frames := 0
	for i in 12:
		await physics_frame
		if not (is_instance_valid(a) and is_instance_valid(b) and is_instance_valid(c)):
			break
		frames += 1
		same = same and a.positions() == b.positions()
		differs = differs or a.positions() != c.positions()
	_check("acceptance: deterministic forks: two volleys with the same origin, aim and seed (one judging, one only drawing) have every pellet in the same place on every frame; another seed's are elsewhere", same and differs and frames >= 10, "%d frames" % frames)
	await _frames(30)
	_check("every volley frees itself once its pellets and flashes are done", world.get_node_or_null(ForkVolley.FIELD) == null or world.get_node(ForkVolley.FIELD).get_child_count() == 0)


func _wall_checks() -> void:
	var world := Node3D.new()
	world.name = "WallWorld"
	root.add_child(world)
	_scratch.append(world)
	var at := EMPTY_AT + Vector3(0.0, 0.0, 300.0)
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2, 20.0, 20.0)
	shape.shape = box
	wall.add_child(shape)
	world.add_child(wall)
	wall.global_position = at + Vector3(6.0, 0.0, 0.0)
	await _frames(3)
	var v: Node = ForkVolley.spawn(world, _w, at, Vector3(1.0, 0.0, 0.0), SEED, 1, true, _w.hit_mask)
	var store := _track(v)
	await _until(func(): return store["done"], 4000)
	var ends: Array = store.get("ends", [])
	var walls := ends.filter(func(e): return e[4] == ForkVolley.WALL)
	var on_face := walls.all(func(e): return absf(e[2].x - (at.x + 5.9)) < 0.001)
	_check("acceptance: pellets stop at a wall: the 6 fork at 4 m and all 12 children end on the face of a wall 6 m out, none beyond it, none flying on to the range", walls.size() == 12 and on_face and store.get("expired", -1) == 0 and store.get("stopped", -1) == 12 and store.get("struck", -1) == 0, "%d at the wall, on its face %s" % [walls.size(), on_face])
	wall.queue_free()


# --- The real arena. ---

func _arena_checks() -> void:
	var arena := await _arena()
	var main: Node = arena["main"]
	var p: Node = arena["player"]
	var hud = arena["hud"]
	var inv = p.get("inventory")
	var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var shipped: Resource = load("res://resources/arsenal.tres")
	_check("acceptance: the arsenal carries it as weapon 5 (after the cannon, SIGTERM, the rail and the fork bomb); the player holds five (six since C25's grep, seven since C26's rm -rf, eight since C27's cron)", shipped.loadout.size() == 8 and shipped.loadout[SLOT] == _w and inv.slot_count() == 8 and inv.defs[SLOT].id == "fork_shotgun", str(inv.defs.map(func(d): return d.id)))
	# Key 5, the wheel, Q.
	var key := InputEventKey.new()
	key.physical_keycode = KEY_5
	key.pressed = true
	Input.parse_input_event(key)
	await physics_frame
	var by_key: int = inv.current
	key.pressed = false
	Input.parse_input_event(key)
	await physics_frame
	p.select_slot(3)
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
	_check("acceptance: key 5 draws it; the weapon cycle reaches it after the fork bomb and goes on from it (to grep, slot 6 since C25) and back; Q returns to it", by_key == SLOT and next == SLOT and wrapped == 5 and back == SLOT and last == SLOT, "%d %d %d %d %d" % [by_key, next, wrapped, back, last])
	await _settle(p, 0.5)
	var dummy: Node = main.get_node("Arena/Targets/DummyA")
	var calls := []
	p.fork_split.connect(func(): calls.append(hud.round_hud().get("last_callout")))
	# Point-blank: every pellet lands before its fork, at full damage.
	p.respawn_at(main.to_global(Vector3(-12.0, STAND_Y, LINE_Z)))
	var pb := await _shot_at(main, p, dummy, -9.5)
	_check("acceptance: a pellet that hits before its fork distance does full damage and never forks: point-blank all 6 land on the dummy at 12 each (72 off it), no fork, nothing judged as a child; the weapon's hit sound as the shot lands", pb["hit_sound"] and pb["landed"] == 6 and pb["forked"] == 0 and absf(pb["taken"] - 72.0) < EPS and pb["landed_by_gen"] == [6, 0] and pb["spawned"] == [6, 0], str(pb))
	# Past the fork: every landed pellet a child, at 0.6 of the parent.
	var mid := await _shot_at(main, p, dummy, -6.0)
	_check("acceptance: past the fork, children land at the parent's damage times 0.6: %d children, %.1f off the dummy (7.2 each), no parent" % [mid["landed"], mid["taken"]], mid["landed"] > 0 and mid["landed_by_gen"][0] == 0 and absf(mid["taken"] - mid["landed"] * 7.2) < 0.001 and mid["forked"] == 6, str(mid))
	var far := await _shot_at(main, p, dummy, 2.0)
	_check("acceptance: point-blank total damage exceeds long-range total on the same dummy: %.1f at 2.5 m against %.1f at 14 m, the cloud wider and weaker" % [pb["taken"], far["taken"]], pb["taken"] > far["taken"] and far["landed_by_gen"][0] == 0, str(far))
	# Root: the second fork through the real weapon.
	var sudo = p.get("sudo")
	sudo.state.charges = 1
	sudo.press()
	var rooted := await _until(func(): return sudo.is_root(), 4000)
	await _settle(p, 1.3)
	var up: Vector3 = main.to_global(Vector3(-12.0, 40.0, LINE_Z))
	_aim(p, up)
	var mag_before: int = inv.mags[SLOT]
	var sky := await _fire_tracked(main, p)
	_check("acceptance: with sudo overcharge on, a real shot's children fork once more: 6, 12, 24 into the open sky, every one gone at the range, no shell spent (root's free ammo, C22), and no hit sound for a shot that landed nothing", not sky.get("hit_sound", true) and rooted and sky.get("spawned", []) == [6, 12, 24] and sky.get("expired", -1) == 24 and inv.mags[SLOT] == mag_before, str(sky))
	await _until(func(): return not sudo.is_root(), 12000)
	var plain := await _fire_tracked(main, p)
	_check("after root it is one fork again: 6, then 12", plain.get("spawned", []) == [6, 12], str(plain))
	_check("a shot's first fork is the round's \"fork()\" callout (shown at the usual callout pace): each of the 4 shots that forked raised it once, the point-blank one never", calls.size() == 4 and calls.has("fork()"), str(calls))
	_drop(arena)
	await _frames(3)
	var orphans_after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_check("alone: no orphan node left behind", orphans_after <= orphans, "%d before, %d after" % [orphans, orphans_after])


## One fork() shot of the real player at `dummy`, put at `x` on the test line with full health
## 100: {taken, landed, landed_by_gen, forked, spawned}.
func _shot_at(main: Node, p: Node, dummy: Node, x: float) -> Dictionary:
	await _until(func(): return dummy.is_alive(), 8000)
	dummy.global_position = main.to_global(Vector3(x, 0.0, LINE_Z))
	dummy.max_health = 100.0
	dummy.reset_for_round()
	_aim(p, main.to_global(Vector3(x, 0.9, LINE_Z)))
	await _settle(p, 1.3)
	p.get("inventory").mags[SLOT] = 4
	var before: float = dummy.health()
	var store := await _fire_tracked(main, p)
	return {"taken": before - dummy.health(), "landed": store.get("landed", -1), "landed_by_gen": store.get("landed_by_gen", []), "forked": store.get("forked", -1), "spawned": store.get("spawned", []), "hit_sound": store.get("hit_sound", false)}


## Fires the drawn weapon once and waits for its volley to be done: what it recorded. The
## player's own generators are pinned first (the fan's seed, the recoil), so every run is the
## same.
func _fire_tracked(main: Node, p: Node) -> Dictionary:
	for rng in ["_pellet_rng", "_rng", "_shake_rng"]:
		(p.get(rng) as RandomNumberGenerator).seed = SEED  # the fan, and the recoil it leaves
	# The last shot's hit sound may still count as playing: stopped, so a sound at this volley's
	# end is this shot's own.
	(p.get("_sfx")[SLOT][1] as AudioStreamPlayer).stop()
	p.drive_input(Vector2.ZERO, false, false, true)
	await physics_frame
	var v: Node = null
	for node in get_nodes_in_group(ForkVolley.GROUP):
		if main.is_ancestor_of(node) and not node.is_queued_for_deletion():
			v = node
	if v == null:
		return {}
	var store := _track(v, p)
	await _until(func(): return store["done"], 4000)
	await _settle(p, 1.3)
	return store


# --- A match. ---

func _match_checks() -> void:
	var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var host := _branch("Host", Vector3.ZERO)
	var hs: Session = host["session"]
	hs.host(0)
	await _frames(2)
	var client := _branch("Client", CLIENT_OFFSET)
	var cs: Session = client["session"]
	cs.join("127.0.0.1:%d" % hs.listen_port())
	var joined := await _until(func(): return cs.state == Session.State.JOINED and hs.players.size() == 2 and cs.players.size() == 2)
	var cid: int = cs.my_id
	await _until(func(): return hs.avatars.has(cid) and cs.avatars.has(1) and hs.combat.has_player(cid) and cs.get("_weapons_synced"), 6000)
	await _until(func(): return hs.protect_left.get(1, 0.0) <= 0.0 and hs.protect_left.get(cid, 0.0) <= 0.0, 6000)
	var hp: Node = host["player"]
	var cp: Node = client["player"]
	cp.select_slot(SLOT)
	var drawn := await _until(func(): return hs.combat.drawn_by(cid) == "fork_shotgun", 4000)
	_place(host, Vector3(-6.0, STAND_Y, LINE_Z), Vector3(-1.0, 0.0, 0.0))
	_place(client, Vector3(-12.0, STAND_Y, LINE_Z), Vector3(1.0, 0.0, 0.0))
	await _frames(10)
	_aim(cp, client["main"].to_global(Vector3(-6.0, 0.9, LINE_Z)))
	await _settle(cp, 0.6)
	await _until(_heard.bind(hs, cid, client), 4000)
	hs.combat.states[1]["health"] = 100.0
	hs.call("_mirror_from_combat")
	var pair := await _match_shot(hs, cs, cp)
	var hv: Dictionary = pair[0]
	var cv: Dictionary = pair[1]
	var taken: float = 100.0 - hs.combat.health_of(1)
	var expected := 0.0
	var by_gen: Array = hv.get("landed_by_gen", [])
	for g in by_gen.size():
		expected += by_gen[g] * _w.fork_damage(g)
	var agreed := await _until(func(): return absf(cs.health.get(1, -1.0) - hs.combat.health_of(1)) < EPS, 4000)
	_check("acceptance: a joiner's shot over 127.0.0.1: the host runs it and judges (its volley decides, the joiner's only draws and lands nothing), the host loses %.1f, every pellet its generation's damage, and the joiner's screen shows the host's health" % taken, joined and drawn and hv.get("authoritative", false) and not cv.get("authoritative", true) and taken > 0.0 and absf(taken - expected) < 0.001 and cv.get("landed", -1) == 0 and agreed, "host %s, joiner %s" % [hv, cv])
	_check("acceptance: deterministic on both screens: the joiner draws the same pellets from the host's seed, every direction the same, and both fork the same (6, then 12)", not hv.get("directions", {}).is_empty() and hv.get("directions", {}) == cv.get("directions", {}) and hv.get("spawned", []) == [6, 12] and cv.get("spawned", []) == [6, 12], "%d and %d directions" % [hv.get("directions", {}).size(), cv.get("directions", {}).size()])
	# A kill by fork(), named in the feed on both screens.
	await _settle(cp, 1.3)
	cp.get("inventory").mags[SLOT] = 4
	await _until(_heard.bind(hs, cid, client), 4000)
	hs.combat.states[1]["health"] = 1.0
	hs.call("_mirror_from_combat")
	await _match_shot(hs, cs, cp)
	var dead := await _until(func(): return hs.dead.get(1, false) and cs.dead.get(1, false), 4000)
	var feed_ok := await _until(func(): return host["hud"].combat_hud().feed_text().has("fork() sent by Daemon-2 to Daemon-1") and client["hud"].combat_hud().feed_text().has("fork() sent by Daemon-2 to Daemon-1"), 4000)
	_check("acceptance: a fork() kill is the host's, and the feed names it on both screens: \"fork() sent by Daemon-2 to Daemon-1\"", dead and feed_ok, str(host["hud"].combat_hud().feed_text()))
	# Root's second fork, on the host's word, on both screens.
	await _until(func(): return not hs.dead.get(1, false) and not cs.dead.get(1, false), 8000)
	hs.combat.states[cid]["sudo"].charges = 1
	hs.combat.set("_sudo_changed", {cid: true})
	var csudo = cp.get("sudo")
	await _until(func(): return csudo.charges() == 1, 4000)
	csudo.press()
	var rooted := await _until(func(): return hs.combat.root(cid) and cs.root_left.get(cid, 0.0) > 0.0, 4000)
	_aim(cp, client["main"].to_global(Vector3(-12.0, 40.0, LINE_Z)))
	await _settle(cp, 1.3)
	cp.get("inventory").mags[SLOT] = 4
	var sky := await _match_shot(hs, cs, cp)
	_check("acceptance: while the host says the joiner is root, its shot forks twice on both screens: 6, 12, 24", rooted and sky[0].get("spawned", []) == [6, 12, 24] and sky[1].get("spawned", []) == [6, 12, 24], "%s %s" % [sky[0].get("spawned", []), sky[1].get("spawned", [])])
	await _until(func(): return not hs.combat.root(cid), 12000)
	# The host's own shot: the same path, the joiner drawing it.
	hp.select_slot(SLOT)
	await _settle(hp, 0.6)
	_place(host, Vector3(-6.0, STAND_Y, LINE_Z), Vector3(-1.0, 0.0, 0.0))
	_place(client, Vector3(-12.0, STAND_Y, LINE_Z), Vector3(1.0, 0.0, 0.0))
	await _frames(10)
	await _until(_heard.bind(hs, cid, client), 4000)
	_aim(hp, host["main"].to_global(Vector3(-12.0, 0.9, LINE_Z)))
	await _settle(hp, 1.3)
	hs.combat.states[cid]["health"] = 100.0
	hs.call("_mirror_from_combat")
	var own := await _match_shot(hs, cs, hp)
	var own_taken: float = 100.0 - hs.combat.health_of(cid)
	var mirrored := await _until(func(): return absf(cs.health.get(cid, -1.0) - hs.combat.health_of(cid)) < EPS, 4000)
	_check("the host's own fork() shot takes the same path: its volley judges, the joiner draws the same pellets and shows the health the host says (%.1f off)" % own_taken, own[0].get("authoritative", false) and own[0].get("directions", {}) == own[1].get("directions", {}) and own_taken > 0.0 and mirrored)
	_drop(host)
	_drop(client)
	await _frames(4)
	var orphans_after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_check("acceptance: no orphan nodes are left behind by any of it", orphans_after <= orphans, "%d before, %d after" % [orphans, orphans_after])


## `shooter` fires once in the match; waits for the host's volley and the joiner's drawn one of
## that shot to be done: [the host's record, the joiner's]. The host's seed generator is
## pinned first, so every run draws the same fan.
func _match_shot(hs: Session, cs: Session, shooter: Node) -> Array:
	(hs.get("_seeds") as RandomNumberGenerator).seed = SEED
	var before: int = hs.get("_throws")
	shooter.drive_input(Vector2.ZERO, false, false, true)
	await physics_frame
	var made := await _until(func(): return hs.get("_throws") > before and hs.get("_volleys").has(before + 1) and cs.get("_volleys").has(before + 1), 4000)
	if not made:
		return [{}, {}]
	var hstore := _track(hs.get("_volleys")[before + 1])
	var cstore := _track(cs.get("_volleys")[before + 1])
	await _until(func(): return hstore["done"] and cstore["done"], 4000)
	return [hstore, cstore]


# --- Helpers. ---

## A record of `v` taken the moment it is done (with `player`, whether its fork() hit sound is
## playing then).
func _track(v: Node, player: Node = null) -> Dictionary:
	var store := {"done": false, "authoritative": v.authoritative}
	v.finished.connect(_snap.bind(v, store, player))
	return store


func _snap(landed: int, v: Node, store: Dictionary, player: Node) -> void:
	store["done"] = true
	if player != null:
		store["hit_sound"] = (player.get("_sfx")[SLOT][1] as AudioStreamPlayer).playing
	store["landed"] = landed
	store["spawned"] = v.spawned.duplicate()
	store["landed_by_gen"] = v.landed_by_gen.duplicate()
	store["forked"] = v.forked_count
	store["stopped"] = v.stopped
	store["struck"] = v.struck
	store["expired"] = v.expired
	store["ends"] = v.ends.duplicate(true)
	store["directions"] = v.directions.duplicate()


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


func _heard(hs: Session, cid: int, client: Dictionary) -> bool:
	var avatar = hs.avatars.get(cid)
	var cp: Node = client["player"]
	if avatar == null or not is_instance_valid(avatar) or not avatar.visible:
		return false
	var here: Vector3 = client["main"].to_local(cp.global_position)
	var look := (Basis(Vector3.UP, cp.rotation.y) * Basis(Vector3.RIGHT, cp.view_pitch()) * Vector3.FORWARD).normalized()
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
