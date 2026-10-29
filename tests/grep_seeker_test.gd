extends SceneTree
## Headless grep seeker test for SIGKILL (C25). scripts/check.sh runs it, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/grep_seeker_test.gd
##
## grep (PRD 5.2, "seeker smart gun that locks onto a marked target"): the resource and its
## numbers, bad values refused; the darts' first directions alone; darts in an empty test world,
## frame by frame: one straight along the aim with no mark, one turning toward a mark never
## faster than its turn rate, the same seed and marks the same darts; a wall stops a dart. In the
## real arena with the real player: slot 6 on key 6, the wheel and Q; a lock that builds only
## inside the cone, in range and in sight, and only after the lock time; 3 marks at most (5 as
## root, whose locks build twice as fast); marks dropping when sight is lost past the grace, when
## the target derezzes and when grep is put away; a shot's darts homing on their marks at the
## weapon's damage (root's 1.5x, no round spent), missing a mark that breaks hard, stopped by a
## wall, flying straight with no mark; the brackets, "match" tags and "grep -c: N"; the "grep"
## callout; six slots that fit at 960x540. Scans that the new code runs, calls and reads nothing
## real, and the wire: protocol 9. Then a host and a joiner over ENet on 127.0.0.1: the joiner
## marks the host and fires; the host believes the claim, runs and judges every dart; the
## joiner's darts only draw; a forged claim (behind the shooter, no such player, itself) and one
## through a wall or out of range are refused and fly no homing dart; a kill named "grep" in the
## feed; the host's own shot; a protocol 8 joiner refused. No orphan nodes. Deterministic: seeds
## pinned where a check reads them, times counted in physics frames, nothing waits a frame count
## for the network.

const Session = preload("res://scripts/net/net_session.gd")
const NetTuningScript = preload("res://scripts/net/net_tuning.gd")
const CombatTuningScript = preload("res://scripts/net/combat_tuning.gd")
const WeaponDefScript = preload("res://scripts/weapons/weapon_def.gd")
const SeekerVolley = preload("res://scripts/weapons/seeker_volley.gd")
const GrepLock = preload("res://scripts/weapons/grep_lock.gd")
const CombatHud = preload("res://scripts/net/combat_hud.gd")
const Controls = preload("res://scripts/controls.gd")
const Palette = preload("res://scripts/palette.gd")
const Link = preload("res://scripts/guide/guide_link.gd")
const MainScene = preload("res://scenes/main.tscn")
const DummyScene = preload("res://scenes/target_dummy.tscn")
const TUNING_PATH := "res://resources/grep_seeker.tres"
const SLOT := 5
const WATCHDOG_MS := 10000
const CLIENT_OFFSET := Vector3(1000.0, 0.0, 0.0)
const OLD_OFFSET := Vector3(2000.0, 0.0, 0.0)
## High above every arena: the empty test world's darts meet nothing there.
const EMPTY_AT := Vector3(0.0, 300.0, 600.0)
const STAND_Y := 0.95
const MIDDLE_Y := 0.9
const LINE_Z := 15.0
const EPS := 0.0001
const SEED := 424242
## One physics frame's most turn at 60 Hz, in degrees.
const FRAME_S := 1.0 / 60.0

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
	_tmp = OS.get_temp_dir().path_join("sigkill-grep-seeker-test-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(_tmp)
	Controls.ensure()
	_w = load(TUNING_PATH)
	_tuning_checks()
	_geometry_checks()
	_source_checks()
	await _empty_world_checks()
	await _wall_checks()
	await _arena_checks()
	await _layout_checks()
	await _match_checks()
	await _cleanup()
	for name in DirAccess.get_files_at(_tmp):
		DirAccess.remove_absolute(_tmp.path_join(name))
	DirAccess.remove_absolute(_tmp)
	print("GREP SEEKER: %d checks" % _checks)
	print("GREP SEEKER RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The resource, the geometry, the source. ---

func _tuning_checks() -> void:
	var w = _w
	var cannon = load("res://resources/terminal_cannon.tres")
	_check("acceptance: every number is one resource, resources/grep_seeker.tres, a WeaponDef that passes its own checks", w is WeaponDefScript and w.problems().is_empty() and w.is_seeker() and w.is_volley() and not w.is_fork(), str(w.problems()) if w is WeaponDefScript else "")
	_check("its lock: a 6 degree cone, 35 m, 0.5 s to mark, a 0.75 s grace, in sight within 40 degrees; 3 marks (5 as root, whose locks build 2x as fast); the host believes a claim 1.5 m and 4 degrees past them", w.lock_cone_degrees == 6.0 and w.lock_range_m == 35.0 and w.lock_s == 0.5 and w.lock_grace_s == 0.75 and w.sight_cone_degrees == 40.0 and w.max_marks == 3 and w.root_max_marks == 5 and w.root_lock_speed == 2.0 and w.claim_tolerance_m == 1.5 and w.claim_tolerance_degrees == 4.0)
	_check("its darts: 40 m/s, turning at most 220 degrees a second, gone at 45 m, fanned 6 degrees each side; 18 a dart (below the cannon's 25 a hit), a 0.7 s interval, 6 in the magazine and 24 in reserve, a 2 s reload on E; its own cobalt from the palette, \"grep\" in the feed and its fiction line", w.dart_speed == 40.0 and w.dart_turn_degrees == 220.0 and w.fire_range == 45.0 and w.spread_degrees == 6.0 and w.damage == 18.0 and w.damage < cannon.damage and w.fire_cooldown == 0.7 and w.magazine_size == 6 and w.reserve_ammo == 24 and w.reload_s == 2.0 and w.light_skin == "cobalt" and w.skin_body() == Palette.COBALT and w.kill_word == "grep" and w.short_name == "grep" and w.fiction == "grep: lock on, then fire.")
	var skins := {}
	for path in ["terminal_cannon", "sigterm", "sigkill_rail", "fork_bomb_weapon", "fork_shotgun"]:
		var other = load("res://resources/%s.tres" % path)
		skins[other.skin_body()] = true
		skins[other.skin_beam()] = true
	_check("acceptance: its light colour is its own: neither of cobalt's colours is the cannon's, SIGTERM's, the rail's, the fork bomb's or fork()'s, nor hostile red or amber, nor the code rain's green", not skins.has(Palette.COBALT) and not skins.has(Palette.COBALT_HI) and not [Palette.HOSTILE_RED, Palette.HOSTILE_AMBER, Palette.MATRIX_GREEN].has(Palette.COBALT))
	var cases := [
		["lock_cone_degrees", 0.0, "lock_cone_degrees"], ["lock_cone_degrees", 50.0, "lock_cone_degrees"], ["sight_cone_degrees", 3.0, "sight_cone_degrees"], ["lock_range_m", NAN, "lock_range_m"],
		["lock_s", 0.0, "lock_s"], ["lock_grace_s", -1.0, "lock_grace_s"], ["max_marks", 0, "max_marks"], ["root_max_marks", 2, "root_max_marks"], ["root_max_marks", 9, "root_max_marks"],
		["root_lock_speed", 0.5, "root_lock_speed"], ["claim_tolerance_m", 9.0, "claim_tolerance_m"], ["claim_tolerance_degrees", 0.0, "claim_tolerance_degrees"],
		["dart_speed", 1.0, "dart_speed"], ["dart_turn_degrees", 0.0, "dart_turn_degrees"], ["dart_trail_m", 0.0, "dart_trail_m"], ["bracket_open_px", 10.0, "bracket_open_px"],
		["fire_range", 20.0, "fire_range"], ["pellet_count", 3, "pellet_count stays 1"], ["falloff_floor", 0.5, "falloff_floor"], ["magazine_size", -1, "from a magazine"], ["spread_degrees", 0.0, "spread above 0"],
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
	odd.max_marks = 3
	if not ", ".join(odd.problems()).contains("only grep darts"):
		missed.append("the cannon with marks: %s" % odd.problems())
	_check("bad values are refused with the reason: a cone of none or too wide, sight narrower than the lock, no range, no lock time, a negative grace, no marks, root's fewer than user's or past 8, root slower, wide tolerances, slow or unturning darts, no trail, brackets that never close, darts that fall short of the lock range, more than one pellet, falloff, no magazine, no spread; and the seek group on any other weapon", missed.is_empty(), " | ".join(missed))


func _geometry_checks() -> void:
	var w = _w
	var aim := Vector3(1.0, -0.2, 0.3).normalized()
	var one: PackedVector3Array = w.seek_spread(aim, SEED, 1)
	_check("acceptance: a shot with no mark (or one) fires its dart straight along the aim, nothing drawn from the seed", one.size() == 1 and one[0].angle_to(aim) < 0.000001 and w.seek_spread(aim, SEED + 9, 1) == one)
	var fan: PackedVector3Array = w.seek_spread(aim, SEED, 3)
	var axis: Vector3 = WeaponDefScript.fork_axis(aim)
	var flat := true
	var angles := []
	for d in fan:
		flat = flat and absf(d.dot(axis)) < EPS
		angles.append(rad_to_deg(aim.signed_angle_to(d, axis)))
	var sorted := angles.duplicate()
	sorted.sort()
	var inside: bool = angles.all(func(a): return absf(a) <= w.spread_degrees + EPS)
	_check("darts spread over the marks: 3 darts in the plane of the aim and its level right-hand side, within 6 degrees each side, one in each third, from the seed alone (the same seed the same fan, another seed another)", fan.size() == 3 and flat and inside and angles == sorted and w.seek_spread(aim, SEED, 3) == fan and w.seek_spread(aim, SEED + 1, 3) != fan, str(angles.map(func(x): return snappedf(x, 0.01))))
	_check("the overcharge numbers: 3 marks as user and 5 as root; a lock builds at 1x as user and 2x as root", w.marks_for(false) == 3 and w.marks_for(true) == 5 and w.lock_speed(false) == 1.0 and w.lock_speed(true) == 2.0)


func _source_checks() -> void:
	var lock := _code("res://scripts/weapons/grep_lock.gd")
	var darts := _code("res://scripts/weapons/seeker_volley.gd")
	var marks := _code("res://scripts/hud/grep_marks.gd")
	var weapon := _code("res://scripts/weapons/weapon_def.gd")
	var player := _code("res://scripts/player.gd")
	var session := _code("res://scripts/net/net_session.gd")
	var parts := lock + darts + marks + _body(weapon, "seek_spread") + _body(weapon, "_seek_problems") + _body(weapon, "marks_for") + _body(weapon, "lock_speed")
	parts += _body(player, "_fire_grep") + _body(player, "_step_grep") + _body(player, "grep_claims") + _body(session, "_accept_marks") + _body(session, "_mark_point") + _body(session, "_spawn_volley") + _body(session, "_bomb")
	var found := PackedStringArray()
	for word in ["OS.", "execute", "create_process", "/proc", "FileAccess", "DirAccess", "Thread", "HTTP", "PacketPeer", "StreamPeer", "Expression", "RegEx"]:
		if parts.contains(word):
			found.append(word)
	var bare := RegEx.create_from_string("(?<![\\w.\"])grep\\s*\\(")
	var unquoted := RegEx.create_from_string("\"(?:\\\\.|[^\"\\\\])*\"").sub(parts, "\"\"", true)
	if bare.search(unquoted) != null:
		found.append("a call to grep()")
	if (lock + darts + marks).contains("rpc"):
		found.append("rpc in the lock, the darts or the brackets")
	_check("acceptance: fiction only: the new code runs no grep, no OS call at all (no command, no process, no /proc), opens and reads nothing and sends nothing itself", found.is_empty() and parts.length() > 4000, ", ".join(found))
	var fire := _body(session, "_handle_fire")
	var rpc_fire := _body(session, "_fire")
	var bomb := _body(session, "_bomb")
	_check("acceptance: the wire, protocol 9 at C25 (10 since C27b's daemons, 11 since A5's daemon seeds): no new message (20 RPCs and 23 sends as C24 left them; 24 and 27 since C27b's four daemon messages); the shot is the usual intent, which now carries the claimed marks, untyped and type-checked (a packed array of at most 8 ids); the seed message carries the believed marks; a mismatched peer gets the existing version refusal", Session.PROTOCOL == 11 and session.count("@rpc(") == 24 and session.count(".rpc_id(") == 27 and session.contains('@rpc("any_peer", "call_remote", "reliable")\nfunc _fire(seq: Variant, life: Variant, weapon: Variant, origin: Variant, dir: Variant, marks: Variant = PackedInt32Array()) -> void:') and rpc_fire.contains("typeof(marks) != TYPE_PACKED_INT32_ARRAY or marks.size() > WeaponDefScript.MARKS_LAST") and session.contains('@rpc("authority", "call_remote", "reliable")\nfunc _bomb(throw_id: int, thrower: int, weapon: String, seed: int, origin: Vector3, dir: Vector3, marks: PackedInt32Array) -> void:') and bomb.contains("marks.size() > WeaponDefScript.MARKS_LAST"))
	_check("acceptance: the host re-checks every claim after the shot itself is believed (a player other than the shooter, alive, in range, in the sight cone with a small tolerance, nothing of the level between, no more than user's or root's marks), draws the seed with its own generator, runs the darts that judge and tells every joiner the seed and the believed marks", fire.find("combat.accept(") < fire.find("if def.is_seeker():") and fire.contains("var believed := _accept_marks(shooter, origin, dir, def, marks)") and fire.contains("var dart_seed := _seeds.randi()") and fire.contains("_spawn_volley(_throws, shooter, weapon, dart_seed, origin, dir, true, believed)") and fire.contains("_tell_seed(_throws, shooter, weapon, dart_seed, origin, dir, believed)") and _body(session, "_accept_marks").contains("def.marks_for(combat.root(shooter))") and _body(session, "_accept_marks").contains("combat.alive(id)") and _body(session, "_accept_marks").contains("def.lock_range_m + def.claim_tolerance_m") and _body(session, "_accept_marks").contains("def.sight_cone_degrees + def.claim_tolerance_degrees") and _body(session, "_accept_marks").contains("MARK_SIGHT_MASK"))
	_check("a client never decides damage: the joiner's darts take the seed message's marks and never judge a player (at most its own dummies), only the host's volley judges with _judge_pellet, and the player never touches the session", bomb.contains("_spawn_volley(throw_id, thrower, weapon, seed, origin, dir, false, marks)") and _body(session, "_spawn_volley").contains("if deciding:\n\t\tjudge = _judge_pellet.bind(shooter, weapon, origin)") and session.count("_judge_pellet.bind(") == 1 and not (_body(player, "_fire_grep") + _body(player, "fork_hit")).contains("session"))


# --- Darts in an empty world. ---

func _empty_world_checks() -> void:
	var world := Node3D.new()
	world.name = "EmptyWorld"
	root.add_child(world)
	_scratch.append(world)
	var aim := Vector3(1.0, 0.0, 0.0)
	# No mark: one dart, straight along the aim, gone at the range.
	var v: Node = SeekerVolley.spawn(world, _w, EMPTY_AT, aim, SEED, [], true, _w.hit_mask)
	var store := _track(v)
	var straight := true
	var frames := 0
	for i in 90:
		await physics_frame
		if store["done"]:
			break
		frames += 1
		for at in v.positions():
			straight = straight and (at - EMPTY_AT).cross(aim).length() < 0.001 and (at - EMPTY_AT).dot(aim) >= 0.0
	var ends: Array = store.get("ends", [])
	var parts := [store.get("spawned", 0) == 1, straight, store.get("turn_most", -1.0) == 0.0, store.get("directions", {}).get(0, Vector3.ZERO) == aim, ends.size() == 1 and ends[0][3] == SeekerVolley.RANGE and absf(ends[0][2] - 45.0) < 0.001, store.get("expired", 0) == 1, frames >= 66 and frames <= 68]
	_check("acceptance: a shot with no mark flies one dart straight: every frame on the aim's line, never turned, gone at exactly 45 m (%d frames at 40 m/s)" % frames, not parts.has(false), "%s %s, %d frames" % [parts, ends, frames])
	# A mark off to the side: the dart turns toward it at the turn rate, never faster.
	var ghost := Node3D.new()
	world.add_child(ghost)
	ghost.global_position = EMPTY_AT + Vector3(16.0, 0.0, 9.0)
	var mark := func(): return ghost.global_position
	var h: Node = SeekerVolley.spawn(world, _w, EMPTY_AT, aim, SEED, [mark], true, _w.hit_mask)
	var hstore := _track(h)
	var turns := []
	var last := aim
	for i in 30:
		await physics_frame
		if hstore["done"] or h.flights().is_empty():
			break
		var now: Vector3 = h.flights()[0][1]
		turns.append(rad_to_deg(last.angle_to(now)))
		last = now
	var most: float = turns.max()
	var limit: float = _w.dart_turn_degrees * FRAME_S
	await _until(func(): return hstore["done"], 4000)
	_check("acceptance: darts home with the turn-rate limit: toward a mark 29 degrees off the aim the dart turns %.3f degrees a frame at most (the limit %.3f, 220 a second at 60 Hz), at the limit while the mark is still off its nose, and passes within %.2f m of it" % [most, limit, hstore.get("nearest", [INF])[0]], most <= limit + 0.001 and absf(turns[0] - limit) < 0.001 and hstore.get("turn_most", 99.0) <= limit + 0.001 and hstore.get("nearest", [INF])[0] < 0.5, str(turns.slice(0, 8).map(func(x): return snappedf(x, 0.001))))
	# Deterministic: the same seed and the same marks draw the same darts, frame by frame.
	var marks := [mark, func(): return ghost.global_position + Vector3(0.0, 0.0, -18.0), func(): return ghost.global_position + Vector3(4.0, 3.0, -9.0)]
	var a: Node = SeekerVolley.spawn(world, _w, EMPTY_AT, aim, SEED, marks, true, _w.hit_mask)
	var b: Node = SeekerVolley.spawn(world, _w, EMPTY_AT, aim, SEED, marks, false, _w.hit_mask)
	var c: Node = SeekerVolley.spawn(world, _w, EMPTY_AT, aim, SEED + 7, marks, true, _w.hit_mask)
	var same := true
	var differs := false
	frames = 0
	for i in 20:
		await physics_frame
		if not (is_instance_valid(a) and is_instance_valid(b) and is_instance_valid(c)):
			break
		frames += 1
		same = same and a.positions() == b.positions()
		differs = differs or a.positions() != c.positions()
	_check("acceptance: deterministic darts: two volleys with the same origin, aim, seed and marks (one judging, one only drawing) have every dart in the same place on every frame; another seed's are elsewhere; three marks, three darts", same and differs and frames >= 18 and a.spawned == 3, "%d frames" % frames)
	await _frames(80)
	_check("every volley frees itself once its darts are done", get_nodes_in_group(SeekerVolley.GROUP).filter(func(n): return world.is_ancestor_of(n)).is_empty())
	ghost.queue_free()


func _wall_checks() -> void:
	var world := Node3D.new()
	world.name = "WallWorld"
	root.add_child(world)
	_scratch.append(world)
	var at := EMPTY_AT + Vector3(0.0, 0.0, 300.0)
	var wall := _wall(world, at + Vector3(6.0, 0.0, 0.0))
	await _frames(3)
	var target := at + Vector3(12.0, 0.0, 1.0)
	var v: Node = SeekerVolley.spawn(world, _w, at, Vector3(1.0, 0.0, 0.0), SEED, [func(): return target], true, _w.hit_mask)
	var store := _track(v)
	await _until(func(): return store["done"], 4000)
	var ends: Array = store.get("ends", [])
	_check("acceptance: walls stop darts: a dart homing on a mark behind a wall 6 m out ends on the wall's face, flying no further", ends.size() == 1 and ends[0][3] == SeekerVolley.WALL and absf(ends[0][1].x - (at.x + 5.9)) < 0.001 and store.get("stopped", -1) == 1 and store.get("struck", -1) == 0 and store.get("expired", -1) == 0, str(ends))
	wall.queue_free()


# --- The real arena. ---

func _arena_checks() -> void:
	var arena := await _arena()
	var main: Node = arena["main"]
	var p: Node = arena["player"]
	var hud = arena["hud"]
	var inv = p.get("inventory")
	var lock: GrepLock = p.get("grep")
	var marks_hud = hud.grep_marks()
	var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var shipped: Resource = load("res://resources/arsenal.tres")
	_check("acceptance: the arsenal carries it as weapon 6 (after the cannon, SIGTERM, the rail, the fork bomb and fork()); the player holds six (seven since C26's rm -rf, eight since C27's cron, nine since C28's ping)", shipped.loadout.size() == 9 and shipped.loadout[SLOT] == _w and inv.slot_count() == 9 and inv.defs[SLOT].id == "grep_seeker", str(inv.defs.map(func(d): return d.id)))
	# Key 6, the wheel, Q.
	var key := InputEventKey.new()
	key.physical_keycode = KEY_6
	key.pressed = true
	Input.parse_input_event(key)
	await physics_frame
	var by_key: int = inv.current
	key.pressed = false
	Input.parse_input_event(key)
	await physics_frame
	p.select_slot(4)
	await physics_frame
	p.cycle_weapon(1)
	var next: int = inv.current
	p.cycle_weapon(1)
	var wrapped: int = inv.current
	p.cycle_weapon(-1)
	var back: int = inv.current
	p.select_slot(1)
	await physics_frame
	var away: String = marks_hud.count_text()
	p.swap_to_last()
	var last: int = inv.current
	await _settle(p, 0.5)
	_check("acceptance: key 6 draws it; the weapon cycle reaches it after fork() and goes on from it (to the rm -rf cannon, slot 7 since C26) and back; Q returns to it; \"grep -c: 0\" under the crosshair only while it is in hand", by_key == SLOT and next == SLOT and wrapped == 6 and back == SLOT and last == SLOT and away == "" and marks_hud.count_text() == "grep -c: 0", "%d %d %d %d %d '%s' '%s'" % [by_key, next, wrapped, back, last, away, marks_hud.count_text()])
	var dummies := _line_up(main)
	var a: Node3D = dummies[0]
	var calls := []
	p.grep_marked.connect(func(): calls.append(hud.round_hud().get("last_callout")))
	p.respawn_at(main.to_global(Vector3(-14.0, STAND_Y, LINE_Z)))
	_put(main, dummies, [[0.0, LINE_Z]])
	await _settle(p, 0.3)
	# The cone: 10 degrees off it, nothing builds; 4 degrees off, it does.
	_aim_off(p, _middle(a), 10.0)
	var off_cone := await _hold(p, 40, func(): return lock.locking != null or lock.count() > 0)
	_aim_off(p, _middle(a), 4.0)
	var in_cone := await _lock_frames(p, lock, a, 60)
	_check("acceptance: a lock builds only inside the cone: 10 degrees off the dummy nothing builds in 40 frames; 4 degrees off it marks it", not off_cone and in_cone > 0, "%s %d" % [off_cone, in_cone])
	lock.clear()
	# Range: a dummy 36 m off, nothing builds; at 28 m it does.
	p.respawn_at(main.to_global(Vector3(-18.0, STAND_Y, LINE_Z)))
	_put(main, dummies, [[18.0, LINE_Z]])
	await _settle(p, 0.2)
	_aim(p, _middle(a))
	var far := await _hold(p, 40, func(): return lock.locking != null or lock.count() > 0)
	_put(main, dummies, [[10.0, LINE_Z]])
	_aim(p, _middle(a))
	var near := await _lock_frames(p, lock, a, 60)
	_check("acceptance: and only in range: 36 m off (past the 35 m lock range) nothing builds; at 28 m it marks", not far and near > 0, "%s %d" % [far, near])
	lock.clear()
	# Line of sight: a wall between, nothing builds.
	p.respawn_at(main.to_global(Vector3(-14.0, STAND_Y, LINE_Z)))
	_put(main, dummies, [[0.0, LINE_Z]])
	var cover := _wall(main, main.to_global(Vector3(-7.0, 2.0, LINE_Z)))
	await _settle(p, 0.2)
	_aim(p, _middle(a))
	var hidden := await _hold(p, 40, func(): return lock.locking != null or lock.count() > 0)
	cover.queue_free()
	await _frames(2)
	_aim(p, _middle(a))
	# The lock time: built a frame at a time, marked on the frame it reaches 0.5 s, not before.
	var built := []
	var timed := await _lock_frames(p, lock, a, 60, built)
	var steady: bool = built.size() >= 2 and range(1, built.size()).all(func(i): return absf(built[i] - built[i - 1] - FRAME_S) < 0.00001)
	var round_hud = hud.round_hud()
	_check("acceptance: and only in sight: with a wall between nothing builds in 40 frames; and only after the lock time: with the wall gone it builds 1/60 s a frame and marks on frame %d, 0.5 s in (%.4f s built the frame before); every mark is the round's \"grep\" callout, at the usual pace (the first shown, the two within 4 s of it held back)" % [timed, built[-1] if not built.is_empty() else -1.0], not hidden and timed == 30 and steady and absf(built[-1] - (_w.lock_s - FRAME_S)) < 0.00001 and calls == ["grep", "grep", "grep"] and round_hud.callouts_shown == 1 and round_hud.callouts_dropped == 2, "%s %d %s shown %d dropped %d" % [hidden, timed, calls, round_hud.callouts_shown, round_hud.callouts_dropped])
	# The brackets close as a lock builds, and a mark wears a "match" tag.
	lock.clear()
	_aim(p, _middle(a))
	var sizes := []
	_hold_aim(true)
	for i in 29:
		await physics_frame
		await process_frame
		if lock.locking == a and not marks_hud.brackets().is_empty():
			sizes.append(marks_hud.brackets()[-1]["rect"].size.x * 0.5)
	await _frames(3)
	_hold_aim(false)
	await process_frame
	var shown: Array = marks_hud.brackets()
	var closing: bool = sizes.size() >= 20 and range(1, sizes.size()).all(func(i): return sizes[i] < sizes[i - 1]) and sizes[0] <= _w.bracket_open_px and sizes[-1] > _w.bracket_marked_px
	_check("acceptance: the lock brackets tighten as the lock builds (%.1f px to %.1f px over %d frames, from 34 toward 14), and the marked target wears a closed bracket with its \"match\" tag; \"grep -c: 1\"" % [sizes[0] if not sizes.is_empty() else -1.0, sizes[-1] if not sizes.is_empty() else -1.0, sizes.size()], closing and shown.size() == 1 and shown[0]["marked"] and absf(shown[0]["rect"].size.x - _w.bracket_marked_px * 2.0) < 0.001 and marks_hud.count_text() == "grep -c: 1", "%s %s" % [sizes.map(func(x): return snappedf(x, 0.1)), shown])
	lock.clear()
	# Three marks at most: four dummies, the fourth never builds.
	_put(main, dummies, [[0.0, 13.5], [0.0, 14.5], [0.0, 15.5], [0.0, 16.5]])
	await _settle(p, 0.2)
	var made := []
	for i in 3:
		_aim(p, _middle(dummies[i]))
		made.append(await _lock_frames(p, lock, dummies[i], 60))
	_aim(p, _middle(dummies[3]))
	var fourth := await _hold(p, 40, func(): return lock.locking != null or lock.count() > 3)
	await process_frame
	_check("acceptance: the cap on marks holds: three dummies marked in 30 frames each, then with three held the fourth builds nothing in 40 frames; \"grep -c: 3\" and three tagged brackets", made == [30, 30, 30] and not fourth and lock.count() == 3 and marks_hud.count_text() == "grep -c: 3" and marks_hud.brackets().filter(func(b): return b["marked"]).size() == 3, "%s %s %d" % [made, fourth, lock.count()])
	# A shot: one dart per mark, each homing on its own dummy at 18.
	var before := dummies.map(func(d): return d.health())
	var shot := await _fire_tracked(main, p)
	var taken := range(4).map(func(i): return before[i] - dummies[i].health())
	_check("acceptance: a shot fires one dart per mark and spends them: 3 darts, each lands on its own marked dummy at 18 (%s off them, the fourth untouched), the hit sound, no mark left" % [taken], shot.get("spawned", 0) == 3 and shot.get("landed", 0) == 3 and taken == [18.0, 18.0, 18.0, 0.0] and shot.get("hit_sound", false) and lock.count() == 0, str(shot))
	# The marks drop: on a derezz at once, on putting grep away, and on losing sight past the grace.
	_put(main, dummies, [[0.0, LINE_Z]])
	_aim(p, _middle(a))
	await _lock_frames(p, lock, a, 60)
	a.hit(1000.0, _middle(a), Vector3.RIGHT)
	await _frames(2)
	var derezz: int = lock.drops.get(GrepLock.DEREZZ, 0)
	await _until(func(): return a.is_alive(), 8000)
	_put(main, dummies, [[0.0, LINE_Z]])
	await _lock_frames(p, lock, a, 60)
	p.select_slot(0)
	await _frames(2)
	var put_away: int = lock.drops.get(GrepLock.PUT_AWAY, 0)
	var after_swap := lock.count()
	p.select_slot(SLOT)
	await _settle(p, 0.5)
	_aim(p, _middle(a))
	await _lock_frames(p, lock, a, 60)
	var wall := _wall(main, main.to_global(Vector3(-7.0, 2.0, LINE_Z)))
	var still := await _held_for(p, lock, 44)
	var gone := await _held_for(p, lock, 3)
	var sight: int = lock.drops.get(GrepLock.SIGHT, 0)
	wall.queue_free()
	await _frames(2)
	_check("acceptance: marks drop: at once when the dummy derezzes; when grep is put away; and with a wall between, still held 44 frames on (inside the 0.75 s grace), gone just past it", derezz == 1 and put_away >= 1 and after_swap == 0 and still and not gone and sight == 1, "derezz %d put away %d after %d, sight %s %s %d" % [derezz, put_away, after_swap, still, gone, sight])
	# And in range: a marked dummy that moves past the lock range drops past the grace.
	p.respawn_at(main.to_global(Vector3(-18.0, STAND_Y, LINE_Z)))
	_put(main, dummies, [[10.0, LINE_Z]])
	await _settle(p, 0.2)
	_aim(p, _middle(a))
	await _lock_frames(p, lock, a, 60)
	_put(main, dummies, [[18.0, LINE_Z]])
	var kept := await _held_for(p, lock, 44)
	var lost := await _held_for(p, lock, 3)
	_check("and when its target leaves the lock range: held inside the grace, gone past it", kept and not lost and lock.drops.get(GrepLock.SIGHT, 0) == 2)
	# Darts home with their turn limit, and miss a mark that breaks hard.
	p.respawn_at(main.to_global(Vector3(-14.0, STAND_Y, LINE_Z)))
	_put(main, dummies, [[0.0, LINE_Z]])
	await _settle(p, 0.2)
	_aim(p, _middle(a))
	await _lock_frames(p, lock, a, 60)
	_aim_off(p, _middle(a), 20.0)
	await _settle(p, 0.1)
	before = [a.health()]
	var curve := await _fire_tracked(main, p)
	_check("acceptance: a dart homes on its mark: fired 20 degrees off the marked dummy it curves in (%.3f degrees a frame at most, the limit %.3f) and lands at 18" % [curve.get("turn_most", -1.0), _w.dart_turn_degrees * FRAME_S], curve.get("landed", 0) == 1 and before[0] - a.health() == 18.0 and curve.get("turn_most", 99.0) <= _w.dart_turn_degrees * FRAME_S + 0.001 and curve.get("turn_most", 0.0) > 1.0, str(curve))
	_aim(p, _middle(a))
	await _lock_frames(p, lock, a, 60)
	before = [a.health()]
	var dodge := await _fire_tracked(main, p, _break_hard.bind(main, a))
	_check("acceptance: and misses a mark that breaks hard: the dummy jumps 6 m aside when the dart is 3 m short; the dart turns no faster than its limit, never reaches it and flies on to a wall or its range; the dummy untouched", dodge.get("landed", -1) == 0 and a.health() == before[0] and dodge.get("turn_most", 99.0) <= _w.dart_turn_degrees * FRAME_S + 0.001 and dodge.get("nearest", [0.0])[0] > 1.0 and [SeekerVolley.WALL, SeekerVolley.RANGE].has(dodge.get("ends", [[0, 0, 0, ""]])[0][3]), str(dodge))
	# A wall between at the shot: the dart stops on it.
	_put(main, dummies, [[0.0, LINE_Z]])
	_aim(p, _middle(a))
	await _lock_frames(p, lock, a, 60)
	var block := _wall(main, main.to_global(Vector3(-7.0, 2.0, LINE_Z)))
	await _frames(2)
	before = [a.health()]
	var walled := await _fire_tracked(main, p)
	block.queue_free()
	_check("acceptance: walls stop darts: a mark still held inside its grace behind a new wall draws its dart onto the wall, the dummy untouched", walled.get("spawned", 0) == 1 and walled.get("stopped", 0) == 1 and walled.get("landed", -1) == 0 and a.health() == before[0] and walled.get("ends", [[0, 0, 0, ""]])[0][3] == SeekerVolley.WALL, str(walled))
	# No mark: one dart straight along the aim.
	await _frames(2)
	_aim(p, main.to_global(Vector3(0.0, 1.6, LINE_Z + 4.0)))
	await _settle(p, 0.2)
	var aim_now: Vector3 = -(p.get_node("Head/Camera") as Camera3D).global_transform.basis.z
	var plain := await _fire_tracked(main, p)
	_check("acceptance: a shot with no marks flies one dart straight along the aim, never turning", plain.get("spawned", 0) == 1 and plain.get("turn_most", -1.0) == 0.0 and plain.get("directions", {}).get(0, Vector3.ZERO).angle_to(aim_now) < 0.0001, str(plain))
	# Root: 5 marks, locks twice as fast, 1.5x damage, no round spent.
	var extra: Array = []
	for i in 2:
		var d: Node3D = DummyScene.instantiate()
		d.name = "DummyX%d" % i
		main.get_node("Arena/Targets").add_child(d)
		extra.append(d)
	await _frames(2)
	dummies += extra
	_put(main, dummies, [[0.0, 12.5], [0.0, 13.5], [0.0, 14.5], [0.0, 15.5], [0.0, 16.5], [0.0, 17.5]])
	var sudo = p.get("sudo")
	sudo.state.charges = 1
	sudo.press()
	var rooted := await _until(func(): return sudo.is_root(), 4000)
	await _settle(p, 0.2)
	var fast := []
	for i in 5:
		_aim(p, _middle(dummies[i]))
		fast.append(await _lock_frames(p, lock, dummies[i], 60))
	_aim(p, _middle(dummies[5]))
	var sixth := await _hold(p, 40, func(): return lock.locking != null or lock.count() > 5)
	_check("acceptance: as root (sudo's overcharge) locks build twice as fast and five may be held: five dummies marked in 15 frames each, the sixth builds nothing", rooted and fast == [15, 15, 15, 15, 15] and not sixth and lock.count() == 5, "%s %s %d" % [fast, sixth, lock.count()])
	before = dummies.map(func(d): return d.health())
	inv.mags[SLOT] = 6
	var mag_before: int = inv.mags[SLOT]
	var root_shot := await _fire_tracked(main, p)
	taken = range(6).map(func(i): return before[i] - dummies[i].health())
	_check("acceptance: and C22's general overcharge holds: five darts, each 1.5x (27 off each marked dummy, %s), and no round spent (root's free ammo)" % [taken], root_shot.get("spawned", 0) == 5 and root_shot.get("landed", 0) == 5 and taken == [27.0, 27.0, 27.0, 27.0, 27.0, 0.0] and inv.mags[SLOT] == mag_before, str(root_shot))
	for i in 5:
		_aim(p, _middle(dummies[i]))
		await _lock_frames(p, lock, dummies[i], 60)
	sudo.end_root()
	await _frames(2)
	_check("when root ends, the marks past user's three drop (the newest two)", lock.count() == 3 and lock.drops.get(GrepLock.ROOT_OVER, 0) == 2 and lock.marks[0]["target"] == dummies[0] and lock.marks[2]["target"] == dummies[2], "%d" % lock.count())
	lock.clear()
	# A target freed while marked, as an avatar is when its player leaves a match: the mark goes
	# ("gone"), with no script error; a dart whose mark is freed in flight flies straight on.
	_aim(p, _middle(extra[0]))
	var freed_marked := await _lock_frames(p, lock, extra[0], 60)
	extra[0].free()
	await _frames(2)
	await process_frame
	var gone_ok: bool = freed_marked > 0 and lock.count() == 0 and lock.drops.get(GrepLock.GONE, 0) == 1 and marks_hud.count_text() == "grep -c: 0" and marks_hud.brackets().is_empty()
	_aim(p, _middle(extra[1]))
	await _lock_frames(p, lock, extra[1], 60)
	var track := {"freed": false, "dirs": []}
	var freed_shot := await _fire_tracked(main, p, _free_mid_flight.bind(extra[1], track))
	var dirs: Array = track["dirs"]
	var straight_on: bool = dirs.size() >= 2 and dirs.all(func(d): return d.angle_to(dirs[0]) < 0.000001)
	_check("a marked target freed (as an avatar is when its player leaves) drops its mark as \"gone\" with no script error, the brackets and the count with it; a dart whose mark is freed in flight flies straight on from there (%d frames unturned) to a wall or its range" % dirs.size(), gone_ok and track["freed"] and straight_on and freed_shot.get("spawned", 0) == 1 and freed_shot.get("landed", -1) == 0 and [SeekerVolley.WALL, SeekerVolley.RANGE].has(freed_shot.get("ends", [[0, 0, 0, ""]])[0][3]), "%s %s %d %s" % [gone_ok, track["freed"], dirs.size(), freed_shot])
	await _frames(2)
	for d in extra:
		if is_instance_valid(d):
			d.queue_free()
	_drop(arena)
	await _frames(3)
	var orphans_after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_check("alone: no orphan node left behind", orphans_after <= orphans, "%d before, %d after" % [orphans, orphans_after])


## The arena's four dummies at full health 100, out of the way until placed.
func _line_up(main: Node) -> Array:
	var out := []
	for name in ["DummyA", "DummyB", "DummyC", "DummyD"]:
		out.append(main.get_node("Arena/Targets/" + name))
	_put(main, out, [])
	return out


## Places the first dummies of `dummies` at `places` ([x, z] each, arena space), full health
## 100; the rest far out of every line and every lock.
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


## Holds the aim for up to `limit` frames until `target` is marked: the frames it took, or -1.
## `built`, if given, gets the lock's seconds after each frame before the mark.
func _lock_frames(p: Node, lock: GrepLock, target: Node3D, limit: int, built: Array = []) -> int:
	_hold_aim(true)
	var n := 0
	var got := -1
	for i in limit:
		await physics_frame
		n += 1
		if lock.has_mark(target):
			got = n
			break
		if lock.locking == target:
			built.append(lock.built_s)
	_hold_aim(false)
	await physics_frame
	return got


## Holds the aim for `frames` frames: true if `what` came true on any of them.
func _hold(p: Node, frames: int, what: Callable) -> bool:
	_hold_aim(true)
	var seen := false
	for i in frames:
		await physics_frame
		seen = seen or what.call()
	_hold_aim(false)
	await physics_frame
	return seen


## Waits `frames` frames with the aim let go: true if a mark is still held then.
func _held_for(p: Node, lock: GrepLock, frames: int) -> bool:
	for i in frames:
		await physics_frame
	return lock.count() > 0


func _hold_aim(on: bool) -> void:
	if on:
		Input.action_press("aim")
	else:
		Input.action_release("aim")


## A frame callback for a dart in flight at `a`: once it is 3 m short, `a` jumps 6 m aside.
func _break_hard(v: Node, main: Node, a: Node3D) -> void:
	if v.flights().is_empty() or a.get_meta("broke", false):
		return
	if (v.positions()[0] as Vector3).distance_to(_middle(a)) < 3.0:
		a.global_position += main.global_transform.basis * Vector3(0.0, 0.0, 6.0)
		a.set_meta("broke", true)


## A frame callback for a dart in flight at `d`: once it is 6 m short, `d` is freed outright;
## after that, the dart's direction every frame goes into `track`.
func _free_mid_flight(v: Node, d, track: Dictionary) -> void:
	if v.flights().is_empty():
		return
	if not track["freed"]:
		if is_instance_valid(d) and (v.positions()[0] as Vector3).distance_to(_middle(d)) < 6.0:
			d.free()
			track["freed"] = true
		return
	track["dirs"].append(v.flights()[0][1])


## Fires the drawn weapon once and waits for its volley to be done: what it recorded. The
## player's own generators are pinned first, so every run is the same. `each`, if given, is
## called with the volley every frame of its flight.
func _fire_tracked(main: Node, p: Node, each: Callable = Callable()) -> Dictionary:
	for rng in ["_pellet_rng", "_rng", "_shake_rng"]:
		(p.get(rng) as RandomNumberGenerator).seed = SEED
	(p.get("_sfx")[SLOT][1] as AudioStreamPlayer).stop()
	p.get("inventory").mags[SLOT] = maxi(p.get("inventory").mags[SLOT], 3)
	var shots: int = p.shots_fired
	p.drive_input(Vector2.ZERO, false, false, true)
	await _until(func(): return p.shots_fired > shots, 500)
	var v: Node = null
	for node in get_nodes_in_group(SeekerVolley.GROUP):
		if main.is_ancestor_of(node) and not node.is_queued_for_deletion():
			v = node
	if v == null:
		return {}
	var store := _track(v, p)
	var t0 := Time.get_ticks_msec()
	while not store["done"] and Time.get_ticks_msec() - t0 < 4000:
		if each.is_valid() and is_instance_valid(v):
			each.call(v)
		await physics_frame
	for d in main.get_node("Arena/Targets").get_children():
		d.remove_meta("broke")
	await _settle(p, 0.8)
	return store


# --- Six slots at 960x540. ---

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
			hud.entries.push_front({"killer": "Daemon-2", "victim": "Daemon-1", "word": "grep", "left": 2.0})
		host["hud"].guide()._notice("word ".repeat(60), Color.WHITE, 5000)
		host["hud"].net_hud().toggle()
		var wrong := PackedStringArray()
		var strips := []
		for slot in [1, SLOT]:
			p.select_slot(slot)
			await _settle(p, 0.5)
			await _frames(3)
			var screen := Rect2(Vector2.ZERO, Vector2(root.size))
			var panels := [host["hud"].net_hud().get("_panel"), host["hud"].guide().get("_panel")]
			var strip: Control = host["hud"].weapon_hud().get("_stack")
			var feed: Control = hud.get("_feed")
			var count: Label = host["hud"].grep_marks().get("_count")
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
				if label != count and not strip.is_ancestor_of(label) and count.is_visible_in_tree() and count.get_global_rect().intersects(rect):
					wrong.append("under grep's count: %s" % label.text.left(20))
			strips.append([host["hud"].weapon_hud().slots_text(), strip_labels, count.is_visible_in_tree(), count.get_global_rect().position.y > screen.size.y * 0.5])
		_check("acceptance: at %dx%d the strip fits six slots (seven since C26, eight since C27, nine since C28): with SIGTERM drawn (\"%s\") and with grep drawn (\"%s\", its \"grep -c: 0\" under the crosshair), four grep kills in the feed, the net panel and a long guide notice all sit inside the screen and nothing covers anything" % [size.x, size.y, strips[0][0], strips[1][0]], wrong.is_empty() and strips[0][0] == "1 [2 SIGTERM] 3 4(2) 5 6 7 8 9" and strips[1][0] == "1 2 3 4(2) 5 [6 grep] 7 8 9" and strips[0][1] == 13 and strips[1][1] == 13 and not strips[0][2] and strips[1][2] and strips[1][3] and hud.feed_text()[0] == "grep sent by Daemon-2 to Daemon-1", "%s; %s" % [strips, ", ".join(wrong)])
		_drop(host)
		await _frames(2)
	root.size = before


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
	var clock: GrepLock = cp.get("grep")
	cp.select_slot(SLOT)
	var drawn := await _until(func(): return hs.combat.drawn_by(cid) == "grep_seeker", 4000)
	_place(host, Vector3(-6.0, STAND_Y, LINE_Z), Vector3(-1.0, 0.0, 0.0))
	_place(client, Vector3(-14.0, STAND_Y, LINE_Z), Vector3(1.0, 0.0, 0.0))
	await _settle(cp, 0.6)
	await _until(_heard.bind(hs, cid, client), 4000)
	await _until(_seen_by.bind(cs, host), 4000)
	# The joiner marks the host's avatar and fires.
	var host_avatar: Node3D = cs.avatars[1]
	_aim(cp, host_avatar.global_position)
	var marked := await _lock_frames(cp, clock, host_avatar, 60)
	var claims := clock.claims()
	hs.combat.states[1]["health"] = 100.0
	hs.call("_mirror_from_combat")
	var refused_before: int = hs.marks_refused
	var pair := await _match_shot(hs, cs, cp)
	var hv: Dictionary = pair[0]
	var cv: Dictionary = pair[1]
	var taken: float = 100.0 - hs.combat.health_of(1)
	var agreed := await _until(func(): return absf(cs.health.get(1, -1.0) - hs.combat.health_of(1)) < EPS, 4000)
	_check("acceptance: a 127.0.0.1 match: the joiner marks the host (its claim, [1]) and fires; the host believes the claim, runs the dart and judges it (18 off the host), the joiner's dart only draws and lands nothing, and the joiner's screen shows the host's health", joined and drawn and marked > 0 and claims == PackedInt32Array([1]) and hs.marks_refused == refused_before and hv.get("authoritative", false) and not cv.get("authoritative", true) and hv.get("spawned", 0) == 1 and hv.get("landed", 0) == 1 and absf(taken - 18.0) < EPS and cv.get("landed", -1) == 0 and agreed, "marked %d claims %s, host %s, joiner %s, taken %.1f" % [marked, claims, _brief(hv), _brief(cv), taken])
	_check("acceptance: the same darts on both screens: the joiner draws the host's dart from its seed and the believed mark, its first direction the same", not hv.get("directions", {}).is_empty() and hv.get("directions", {}) == cv.get("directions", {}) and cv.get("spawned", 0) == 1)
	# A forged claim: behind the shooter, no such player, itself.
	_place(client, Vector3(-14.0, STAND_Y, LINE_Z), Vector3(-1.0, 0.0, 0.0))
	await _settle(cp, 1.0)
	await _until(_heard.bind(hs, cid, client), 4000)
	hs.combat.states[1]["health"] = 100.0
	hs.call("_mirror_from_combat")
	refused_before = hs.marks_refused
	var forged := await _forged_shot(hs, cs, cp, client, PackedInt32Array([1, 999, cid]))
	_check("acceptance: the host rejects a forged mark claim: the host behind the shooter, a player who does not exist and the shooter itself are all refused (3 counted); the shot still flies, one dart straight along the aim on both screens, and the host takes nothing", forged[0].get("spawned", 0) == 1 and forged[1].get("spawned", 0) == 1 and hs.marks_refused == refused_before + 3 and forged[0].get("turn_most", -1.0) == 0.0 and hs.combat.health_of(1) == 100.0, "%s %s refused %d" % [_brief(forged[0]), _brief(forged[1]), hs.marks_refused - refused_before])
	# Through a wall, and out of range, the host's check refuses a claim too.
	_place(client, Vector3(-14.0, STAND_Y, LINE_Z), Vector3(1.0, 0.0, 0.0))
	var cover := _wall(host["main"], host["main"].to_global(Vector3(-10.0, 2.0, LINE_Z)))
	await _settle(cp, 0.6)
	await _until(_heard.bind(hs, cid, client), 4000)
	refused_before = hs.marks_refused
	var walled := await _forged_shot(hs, cs, cp, client, PackedInt32Array([1]))
	cover.queue_free()
	await _frames(2)
	var def: WeaponDefScript = _w
	_place(client, Vector3(-19.0, STAND_Y, LINE_Z), Vector3(1.0, 0.0, 0.0))
	_place(host, Vector3(19.0, STAND_Y, LINE_Z), Vector3(-1.0, 0.0, 0.0))
	await _settle(cp, 0.6)
	await _until(_heard.bind(hs, cid, client), 4000)
	var eye: Vector3 = client["main"].to_local((cp.get_node("Head/Camera") as Node3D).global_position)
	var to_host: Vector3 = (Vector3(19.0, STAND_Y, LINE_Z) - eye).normalized()
	var too_far: PackedInt32Array = hs.call("_accept_marks", cid, eye, to_host, def, PackedInt32Array([1]))
	_place(host, Vector3(10.0, STAND_Y, LINE_Z), Vector3(-1.0, 0.0, 0.0))
	await _frames(3)
	var near: PackedInt32Array = hs.call("_accept_marks", cid, eye, (Vector3(10.0, STAND_Y, LINE_Z) - eye).normalized(), def, PackedInt32Array([1, 1]))
	_check("acceptance: a claim through a wall is refused (the shot's one dart flies straight on to the wall), as is one 38 m off (past 35 m and its 1.5 m tolerance); at 29 m the same claim is believed, once (named twice, the second is refused)", hs.marks_refused == refused_before + 1 + 1 + 1 and walled[0].get("turn_most", -1.0) == 0.0 and too_far.is_empty() and near == PackedInt32Array([1]), "walled %s far %s near %s" % [_brief(walled[0]), too_far, near])
	# A believed mark whose player has left by the time the seed comes: the joiner still draws
	# the shot's darts, that one straight, so its darts stay as many as the host's.
	var gone_id := 77777
	var c_origin: Vector3 = client["main"].to_local((cp.get_node("Head/Camera") as Node3D).global_position)
	cs.call("_bomb", 99999, cid, "grep_seeker", SEED, c_origin, Vector3(1.0, 0.0, 0.0), PackedInt32Array([gone_id, 1]))
	var left_vol = cs.get("_volleys").get(99999)
	var drew: bool = left_vol != null
	var left_store := _track(left_vol) if drew else {"done": false}
	await _until(func(): return left_store["done"], 4000)
	_check("a joiner told of a believed mark whose player has since left still draws the shot: both darts, the departed one's straight, so the fan matches the host's", drew and left_store.get("spawned", 0) == 2 and left_store.get("nearest", [0.0])[0] == INF and left_store.get("landed", -1) == 0 and not left_store.get("authoritative", true), _brief(left_store))
	# A kill by grep, named in the feed on both screens.
	_place(host, Vector3(-6.0, STAND_Y, LINE_Z), Vector3(-1.0, 0.0, 0.0))
	_place(client, Vector3(-14.0, STAND_Y, LINE_Z), Vector3(1.0, 0.0, 0.0))
	await _settle(cp, 1.0)
	await _until(_heard.bind(hs, cid, client), 4000)
	await _until(_seen_by.bind(cs, host), 4000)
	_aim(cp, cs.avatars[1].global_position)
	await _lock_frames(cp, clock, cs.avatars[1], 60)
	hs.combat.states[1]["health"] = 1.0
	hs.call("_mirror_from_combat")
	cp.get("inventory").mags[SLOT] = 6
	await _match_shot(hs, cs, cp)
	var dead := await _until(func(): return hs.dead.get(1, false) and cs.dead.get(1, false), 4000)
	var feed_ok := await _until(func(): return host["hud"].combat_hud().feed_text().has("grep sent by Daemon-2 to Daemon-1") and client["hud"].combat_hud().feed_text().has("grep sent by Daemon-2 to Daemon-1"), 4000)
	_check("acceptance: a grep kill is the host's, and the feed names it on both screens: \"grep sent by Daemon-2 to Daemon-1\"", dead and feed_ok, str(host["hud"].combat_hud().feed_text()))
	# The host's own shot: the same path; the joiner draws it and never decides.
	await _until(func(): return not hs.dead.get(1, false) and not cs.dead.get(1, false), 8000)
	cp.select_slot(0)
	hp.select_slot(SLOT)
	await _settle(hp, 0.6)
	_place(host, Vector3(-6.0, STAND_Y, LINE_Z), Vector3(-1.0, 0.0, 0.0))
	_place(client, Vector3(-14.0, STAND_Y, LINE_Z), Vector3(1.0, 0.0, 0.0))
	await _settle(hp, 0.6)
	await _until(_heard.bind(hs, cid, client), 4000)
	var client_avatar: Node3D = hs.avatars[cid]
	_aim(hp, client_avatar.global_position)
	var hlock: GrepLock = hp.get("grep")
	var host_marked := await _lock_frames(hp, hlock, client_avatar, 60)
	hs.combat.states[cid]["health"] = 100.0
	hs.call("_mirror_from_combat")
	var own := await _match_shot(hs, cs, hp)
	var own_taken: float = 100.0 - hs.combat.health_of(cid)
	var mirrored := await _until(func(): return absf(cs.health.get(cid, -1.0) - hs.combat.health_of(cid)) < EPS, 4000)
	_check("acceptance: the host's own grep shot takes the same path: it marks the joiner, its dart judges (%.1f off the joiner); the joiner's drawn dart meets its own body and decides nothing, and its screen shows the health the host says" % own_taken, host_marked > 0 and own[0].get("authoritative", false) and own[0].get("landed", 0) == 1 and absf(own_taken - 18.0) < EPS and not own[1].get("authoritative", true) and own[1].get("landed", -1) == 0 and own[1].get("struck", 0) == 1 and own[0].get("directions", {}) == own[1].get("directions", {}) and mirrored, "%s %s" % [_brief(own[0]), _brief(own[1])])
	# A peer still on protocol 8 is refused.
	var old := _branch("Old", OLD_OFFSET, 8)
	var os: Session = old["session"]
	os.join("127.0.0.1:%d" % hs.listen_port())
	var refused := await _until(func(): return os.state == Session.State.FAILED, 6000)
	_check("acceptance: protocol 9 at C25 (10 since C27b, 11 since A5): a joiner still on protocol 8 is refused with the clear version line", Session.PROTOCOL == 11 and refused and os.error == "version mismatch: host 11, you 8", os.error)
	_drop(old)
	_drop(host)
	_drop(client)
	await _frames(4)
	var orphans_after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_check("acceptance: no orphan nodes are left behind by any of it", orphans_after <= orphans, "%d before, %d after" % [orphans, orphans_after])


## `shooter` fires once in the match; waits for the host's volley and the joiner's drawn one of
## that shot to be done: [the host's record, the joiner's]. The host's seed generator and the
## shooter's own are pinned first, so every run draws the same darts.
func _match_shot(hs: Session, cs: Session, shooter: Node) -> Array:
	(hs.get("_seeds") as RandomNumberGenerator).seed = SEED
	for rng in ["_pellet_rng", "_rng", "_shake_rng"]:
		(shooter.get(rng) as RandomNumberGenerator).seed = SEED
	var before: int = hs.get("_throws")
	shooter.drive_input(Vector2.ZERO, false, false, true)
	await physics_frame
	return await _volleys_of(hs, cs, before + 1)


## A grep shot of the joiner sent straight to the host with `claims` instead of its marks: a
## forged intent, as a cheating client would send it, the shot itself otherwise sound.
func _forged_shot(hs: Session, cs: Session, cp: Node, client: Dictionary, claims: PackedInt32Array) -> Array:
	(hs.get("_seeds") as RandomNumberGenerator).seed = SEED
	var before: int = hs.get("_throws")
	var cam := cp.get_node("Head/Camera") as Node3D
	var origin: Vector3 = client["main"].to_local(cam.global_position)
	var dir: Vector3 = (client["main"].global_transform.basis.inverse() * -cam.global_transform.basis.z).normalized()
	cs.fire_seq = maxi(cs.fire_seq, hs.combat.states[cs.my_id]["last_seq"]) + 1
	cs.set("_sent_actions", cs.get("_sent_actions") + 1)
	cs._fire.rpc_id(1, cs.fire_seq, cs.lives.get(cs.my_id, 0), "grep_seeker", origin, dir, claims)
	var out := await _volleys_of(hs, cs, before + 1)
	await _settle(cp, 0.8)
	return out


func _volleys_of(hs: Session, cs: Session, shot_id: int) -> Array:
	var made := await _until(func(): return hs.get("_volleys").has(shot_id) and cs.get("_volleys").has(shot_id), 4000)
	if not made:
		return [{}, {}]
	var hstore := _track(hs.get("_volleys")[shot_id])
	var cstore := _track(cs.get("_volleys")[shot_id])
	await _until(func(): return hstore["done"] and cstore["done"], 4000)
	return [hstore, cstore]


# --- Helpers. ---

## A record of `v` taken the moment it is done (with `player`, whether grep's hit sound is
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
	store["spawned"] = v.spawned
	store["stopped"] = v.stopped
	store["struck"] = v.struck
	store["expired"] = v.expired
	store["ends"] = v.ends.duplicate(true)
	store["directions"] = v.directions.duplicate()
	store["turn_most"] = v.turn_most
	store["nearest"] = v.nearest.duplicate()


## A volley's record without places: what a match check prints. A dart homing on an avatar
## flies by where that avatar is drawn, which moves with the packets' real arrival times, so
## only its counts and how each dart ended are the same on every run.
func _brief(store: Dictionary) -> String:
	return "%d darts, landed %d, struck %d, stopped %d, expired %d, deciding %s, ends %s" % [store.get("spawned", 0), store.get("landed", 0), store.get("struck", 0), store.get("stopped", 0), store.get("expired", 0), store.get("authoritative", false), store.get("ends", []).map(func(e): return e[3])]


## A slab of the level (layer 1), 0.2 m thick, 4 m high and wide, square to x, at `at`.
func _wall(parent: Node, at: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2, 4.0, 4.0)
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


## Aims `degrees` to the left of `target`, level with it.
func _aim_off(player: Node, target: Vector3, degrees: float) -> void:
	_aim(player, target)
	player.rotation.y += deg_to_rad(degrees)


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


## True once the joiner's avatar of the host stands where the host is.
func _seen_by(cs: Session, host: Dictionary) -> bool:
	var avatar = cs.avatars.get(1)
	if avatar == null or not is_instance_valid(avatar) or not avatar.visible:
		return false
	var here: Vector3 = host["main"].to_local(host["player"].global_position)
	return avatar.position.distance_to(here) < 0.05


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
	Input.action_release("aim")
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
