extends SceneTree
## Headless cron mines test for SIGKILL (C27). scripts/check.sh runs it, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/cron_mines_test.gd
##
## cron mines (PRD 5.2, "timed mines"): the resource and its numbers, bad values refused; scans
## that the new code touches nothing real (no OS call, no DirAccess or FileAccess, no crontab or
## systemctl called, the HUD's words aside) and the wire (protocol 9, nothing new). In an empty
## test world, frame by frame: a mine's arm delay and every run on exactly its frame, exactly its
## runs (one more as root), then gone; the ring closing and the brighten before each run; the
## schedule text counting down; a mine that only draws running on the word alone. In the real arena
## with the real player: slot 8 on key 8, the wheel and Q; a mine on the floor and on a wall in
## reach, at the feet out of it; the crontab's limit (the oldest removed, the strip's note and
## count); daemons taking each run's falloff, none behind cover; root's extra run, 1.5 times and
## free mine; the "cron" callout; a new round clearing them. Eight slots at 960x540. Then a host and
## two joiners over ENet on 127.0.0.1: a joiner arriving mid-job sees the mine; the host judges every
## run on the host (one run survived, all three not) and the other joiner, never on the owner;
## the owner's death leaves its mine running and the kill its own; another player's shot removes a
## mine ("crontab -r" in the feed); the owner leaving takes its jobs; the joiners' mines only draw;
## a protocol 8 joiner refused. No orphan nodes. Deterministic: times counted in physics frames,
## only counts and outcomes printed for anything a network's timing could move.

const Session = preload("res://scripts/net/net_session.gd")
const NetTuningScript = preload("res://scripts/net/net_tuning.gd")
const CombatTuningScript = preload("res://scripts/net/combat_tuning.gd")
const WeaponDefScript = preload("res://scripts/weapons/weapon_def.gd")
const CronMine = preload("res://scripts/weapons/cron_mine.gd")
const CombatHud = preload("res://scripts/net/combat_hud.gd")
const Controls = preload("res://scripts/controls.gd")
const Palette = preload("res://scripts/palette.gd")
const Link = preload("res://scripts/guide/guide_link.gd")
const MainScene = preload("res://scenes/main.tscn")
const TUNING_PATH := "res://resources/cron_mines.tres"
const SLOT := 7
const WATCHDOG_MS := 10000
const CLIENT_OFFSET := Vector3(1000.0, 0.0, 0.0)
const CLIENT_B_OFFSET := Vector3(3000.0, 0.0, 0.0)
const OLD_OFFSET := Vector3(2000.0, 0.0, 0.0)
## High above every arena: the empty test world's mines meet nothing there.
const EMPTY_AT := Vector3(0.0, 300.0, 600.0)
const STAND_Y := 0.95
const MIDDLE_Y := 0.9
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
	_tmp = OS.get_temp_dir().path_join("sigkill-cron-mines-test-%d" % OS.get_process_id())
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
	print("CRON MINES: %d checks" % _checks)
	print("CRON MINES RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The resource and the source. ---

func _tuning_checks() -> void:
	var w = _w
	var rm = load("res://resources/rm_rf_cannon.tres")
	_check("acceptance: every number is one resource, resources/cron_mines.tres, a WeaponDef that passes its own checks", w is WeaponDefScript and w.problems().is_empty() and w.is_mine() and w.is_volley(), str(w.problems()) if w is WeaponDefScript else "")
	_check("its job: placed up to 4 m off, armed after 1 s, a run every 2 s, 3 runs (4 as root), 3 jobs to a crontab, a 0.35 m target for shots, a 0.6 s fade, a 0.3 s brighten before each run, the full crontab noted 1.6 s", w.place_range_m == 4.0 and w.arm_s == 1.0 and w.run_interval_s == 2.0 and w.runs == 3 and w.runs_for(true) == 4 and w.crontab_limit == 3 and w.mine_hit_radius_m == 0.35 and w.fade_s == 0.6 and w.telegraph_s == 0.3 and w.crontab_note_s == 1.6)
	var max_health: float = CombatTuningScript.new().max_health
	var at_middle: float = w.blast_damage_at(MIDDLE_Y - CronMine.STUD_LIFT_M, false)
	_check("acceptance: each run a moderate blast, not rm -rf's: 55 at the centre easing to 6 at 3 m (rm -rf's 140 and 6 m); standing over it %.1f a run, one run short of a full player's %d, three past it; root's overcharge is the extra run alone (radius share 1), and the owner takes nothing (self share 0)" % [at_middle, max_health], w.damage == 55.0 and w.blast_edge_damage == 6.0 and w.blast_radius_m == 3.0 and w.damage < rm.damage and w.blast_radius_m < rm.blast_radius_m and at_middle < max_health and at_middle * w.runs >= max_health and w.blast_radius_for(true) == 3.0 and w.self_damage_share == 0.0)
	_check("acceptance: three mines in the magazine, 6 in reserve, a 2.4 s reload on E, a 0.5 s placement interval; its own rose from the palette; \"cron\" in the feed, \"crontab -r\" for a removal", w.magazine_size == 3 and w.reserve_ammo == 6 and w.reload_s == 2.4 and w.fire_cooldown == 0.5 and w.light_skin == "rose" and w.skin_body() == Palette.ROSE and w.kill_word == "cron" and w.short_name == "cron" and w.remove_word == "crontab -r")
	var skins := {}
	for path in ["terminal_cannon", "sigterm", "sigkill_rail", "fork_bomb_weapon", "fork_shotgun", "grep_seeker", "rm_rf_cannon"]:
		var other = load("res://resources/%s.tres" % path)
		skins[other.skin_body()] = true
		skins[other.skin_beam()] = true
	_check("acceptance: its light colour is its own: neither of rose's colours is any of the seven other weapons', nor hostile red or amber, nor the code rain's green", not skins.has(Palette.ROSE) and not skins.has(Palette.ROSE_HI) and not [Palette.HOSTILE_RED, Palette.HOSTILE_AMBER, Palette.MATRIX_GREEN].has(Palette.ROSE))
	var cases := [
		["place_range_m", 0.0, "place_range_m"], ["place_range_m", 30.0, "place_range_m"], ["arm_s", -1.0, "arm_s"], ["run_interval_s", 0.0, "run_interval_s"],
		["runs", 0, "runs must"], ["runs", 11, "runs must"], ["root_extra_runs", -1, "root_extra_runs"], ["crontab_limit", 0, "crontab_limit"], ["crontab_limit", 9, "crontab_limit"],
		["mine_hit_radius_m", 0.0, "mine_hit_radius_m"], ["fade_s", 0.0, "fade_s"], ["mine_radius_m", 0.0, "mine_radius_m"], ["telegraph_s", 3.0, "telegraph_s"], ["crontab_note_s", 0.0, "crontab_note_s"],
		["blast_radius_m", 0.0, "blast_radius_m"], ["root_blast_scale", 1.5, "root_blast_scale"], ["blast_edge_damage", 90.0, "blast_edge_damage"], ["self_damage_share", 0.5, "only the rm -rf slug"],
		["remove_word", "", "remove_word"], ["pellet_count", 2, "one mine"], ["magazine_size", -1, "from a magazine"],
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
	var odd = load("res://resources/terminal_cannon.tres").duplicate()
	odd.runs = 3
	if not ", ".join(odd.problems()).contains("only cron mines"):
		missed.append("the cannon with runs: %s" % odd.problems())
	_check("bad values are refused with the reason: a placement of nothing or too far, a negative arm, no interval, no runs or too many, negative root runs, a crontab of none or too many, no target, no fade, no stud, a brighten longer than the wait, no note, no blast, a root blast share, an edge past the centre, self-damage, no removal words, more than one mine, no magazine; and the mine group on any other weapon", missed.is_empty(), " | ".join(missed))


func _source_checks() -> void:
	var mine := _code("res://scripts/weapons/cron_mine.gd")
	var weapon := _code("res://scripts/weapons/weapon_def.gd")
	var player := _code("res://scripts/player.gd")
	var session := _code("res://scripts/net/net_session.gd")
	var parts := mine + _body(weapon, "_mine_problems") + _body(weapon, "runs_for")
	for name in ["_fire_mine", "take_mine", "clear_jobs", "_judge_mine", "crontab_count", "note_crontab_full"]:
		parts += _body(player, name)
	for name in ["_mine_place", "_spawn_mine", "_mine_word", "_mine_removed", "_remove_mine", "_crontab_trim", "_drop_jobs", "_send_mines", "_shoot_mines", "_shot_mine", "_blast_mines"]:
		parts += _body(session, name)
	var found := PackedStringArray()
	for word in ["OS.", "execute", "create_process", "DirAccess", "FileAccess", "move_to_trash", "/proc", "shell_open", "Thread", "HTTP", "PacketPeer", "StreamPeer", "Expression", "Time.set"]:
		if parts.contains(word):
			found.append(word)
	# HUD strings may say "crontab"; a call may not. Strings are blanked before looking for calls.
	var unquoted := RegEx.create_from_string("\"(?:\\\\.|[^\"\\\\])*\"").sub(parts, "\"\"", true)
	var calls := RegEx.create_from_string("(?<![\\w.\"])(crontab|systemctl|cron|at)\\s*\\(")
	for m in calls.search_all(unquoted):
		found.append("a call to %s()" % m.get_string(1))
	if mine.contains("rpc"):
		found.append("rpc in the mine")
	var strings_say: bool = parts.contains("\"crontab") or _code("res://scripts/hud/weapon_hud.gd").contains("\"crontab")
	_check("acceptance: fiction only, the hard rule: the new weapon's code calls no crontab, systemctl or at, and no OS call at all (no OS.execute, OS.create_process, OS.move_to_trash), no DirAccess or FileAccess, no /proc, nothing that sets a clock; \"crontab\" appears only as HUD text, which the scan tells apart from a call", found.is_empty() and parts.length() > 6000 and strings_say, ", ".join(found))
	var fire := _body(session, "_handle_fire")
	_check("acceptance: the wire stayed protocol 9 at C27 (10 since C27b's daemons, 11 since A5's daemon seeds, 12 since I1's ICE, 13 since I2's ICEbreakers, 14 since I3's Black ICE, 15 since C29's chmod 000, 16 since C30's pipe |, 17 since C31's /dev/null, 18 since C32's SIGHUP): no new message and no changed one (20 RPCs, 23 sends then, 24 and 27 since C27b's four daemon messages, 26 and 29 since I1's two ICE messages, 28 and 31 since I2's two ICEbreaker messages, 28 and 32 since C29's freeze meter sent back to its player; I3's Black ICE rides ICE's word: the seed message's one send in _tell_seed, now able to reach one joiner, the blast word's in _tell_blast); a placement is the usual intent, a mine told in the seed message, each run and removal in the blast word", Session.PROTOCOL == 18 and session.count("@rpc(") == 28 and session.count(".rpc_id(") == 32 and session.count("_bomb.rpc_id(") == 1 and session.count("_blast.rpc_id(") == 1 and fire.find("combat.accept(") < fire.find("if def.is_mine():") and fire.contains("_spawn_mine(_throws, shooter, weapon, place[\"at\"], place[\"normal\"], left, true, false)") and fire.contains("_tell_seed(_throws, shooter, weapon, left, place[\"at\"], place[\"normal\"])") and _body(session, "_blast").contains("_mine_word(throw_id, gen, index, at)") and _body(session, "_bomb").contains("_spawn_mine(throw_id, thrower, weapon, origin, dir, left, false, seed < 0)"))
	_check("a client never decides damage or schedules: only the host's mine keeps the schedule and judges (its judge the rm -rf blast's, bound only when deciding); removals are the host's alone; a joiner's mine runs and ends on the host's word", _body(session, "_spawn_mine").contains("var judge := _judge_slug_blast.bind(owner, weapon, false) if deciding else Callable()") and _body(session, "_mine_word").contains("mine.apply_run(gen, _arena.to_global(at))") and _body(session, "_remove_mine").contains("_tell_blast(") and _body(session, "_judge_pellet").find("if state != State.HOSTING or combat == null") < _body(session, "_judge_pellet").find("_shot_mine(collider, shooter)") and mine.contains("if authoritative:\n\t\tif age >= next_at - TIME_EPS:"))


# --- A mine in an empty world. ---

func _empty_world_checks() -> void:
	var world := Node3D.new()
	world.name = "EmptyWorld"
	root.add_child(world)
	_scratch.append(world)
	var judged := []
	var judge := func(at: Vector3) -> int:
		judged.append(at)
		return 0
	await physics_frame
	var m: Node = CronMine.spawn(world, _w, EMPTY_AT, Vector3.UP, 1, 0, _w.runs_for(false), true, false, judge)
	var texts := [m.schedule_text()]
	var shares := []
	var bright := []
	var clock := [0]
	var gone_after := -1
	var ran_at := []
	# A run happens in the physics step under way: the frame after the last one counted.
	m.ran.connect(func(_left, _at): ran_at.append(clock[0] + 1))
	while clock[0] < 600:
		await physics_frame
		clock[0] += 1
		var frames: int = clock[0]
		if not is_instance_valid(m) or m.is_queued_for_deletion():
			gone_after = frames
			break
		if texts[-1] != m.schedule_text():
			texts.append(m.schedule_text())
		if m.running():
			shares.append(m.countdown())
			bright.append(m.brightened())
	_check("acceptance: armed after exactly 60 frames (1 s), it runs on exactly frames 60, 180 and 300 (every 120, 2 s), three runs and no more, then fades out and is gone 36 frames (0.6 s) after its last", ran_at == [60, 180, 300] and judged.size() == 3 and gone_after >= 336 and gone_after <= 337, "%s, gone after %d" % [ran_at, gone_after])
	_check("it shows its schedule cron-style over the stud and counts its runs down: \"*/2s x3\", \"*/2s x2\", \"*/2s x1\", \"*/2s x0\"", texts == ["*/2s x3", "*/2s x2", "*/2s x1", "*/2s x0"], str(texts))
	var closing: bool = shares.size() > 200 and shares[0] > 0.98 and range(1, 59).all(func(i): return shares[i] < shares[i - 1]) and shares[61] > 0.98 and range(62, 179).all(func(i): return shares[i] < shares[i - 1])
	var brightens: bool = bright.slice(0, 41).all(func(b): return not b) and bright.slice(42, 59).all(func(b): return b) and not bright[60] and bright.slice(162, 179).all(func(b): return b)
	_check("acceptance: before each run it telegraphs: a ring closing from the blast's radius toward nothing over the wait, and the stud brightened for the last 0.3 s (18 frames) of it", closing and brightens, "%s %s" % [closing, brightens])
	var r: Node = CronMine.spawn(world, _w, EMPTY_AT, Vector3.UP, 2, 0, _w.runs_for(true), true, false, Callable())
	var rstore := _track(r)
	await _until(func(): return rstore["done"], 8000)
	_check("acceptance: one placed as root runs once more: four runs, on frames 60, 180, 300 and 420", rstore.get("ages", []).map(func(a): return roundi(a * 60.0)) == [60, 180, 300, 420] and rstore.get("why", "") == CronMine.DONE, str(rstore.get("ages", [])))
	# A mine that only draws: no run of its own, the word's runs alone, a removal ends it.
	var d: Node = CronMine.spawn(world, _w, EMPTY_AT, Vector3.UP, 3, 0, 3, false)
	var dstore := _track(d)
	await _frames(200)
	var none_own: bool = d.run_ages.is_empty()
	d.apply_run(2, EMPTY_AT)
	await physics_frame
	var after_word: Array = [d.run_ages.size(), d.runs_left, d.schedule_text()]
	d.remove(CronMine.SHOT)
	await _until(func(): return dstore["done"], 4000)
	var rings := world.get_node(CronMine.FIELD).get_children().filter(func(n): return n.is_in_group(CronMine.RING_GROUP))
	_check("a mine on a joiner's screen only draws: no run of its own past its schedule, a run on the host's word (runs left 2, \"*/2s x2\"), ended by a removal's word", none_own and after_word == [1, 2, "*/2s x2"] and dstore.get("why", "") == CronMine.SHOT and rings.size() <= 1, str(after_word))
	# One a joiner heard of mid-job, its last run to come: its clock is a guess, so it waits a
	# whole interval past it for the word, and only then gives up (self-review pass 1).
	var late: Node = CronMine.spawn(world, _w, EMPTY_AT, Vector3.UP, 4, 0, 1, false, true)
	var lstore := _track(late)
	await _frames(200)
	var still: bool = is_instance_valid(late) and late.running()
	await _until(func(): return lstore["done"], 6000)
	_check("a joiner's mine heard of mid-job waits for its last run's word a whole interval past its guess (still running 200 frames in, 3.3 s), and only then gives up without a blast", still and lstore.get("why", "") == CronMine.DONE and lstore.get("ages", [1]).is_empty(), "%s %s" % [still, lstore.get("why", "")])
	await _frames(30)


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
	_check("acceptance: the arsenal carries it as weapon 8 (after the cannon, SIGTERM, the rail, the fork bomb, fork(), grep and rm -rf); the player holds eight (nine since C28's ping, ten since C29's chmod 000, eleven since C30's pipe |, twelve since C31's /dev/null, thirteen since C32's SIGHUP)", shipped.loadout.size() == 13 and shipped.loadout[SLOT] == _w and inv.slot_count() == 13 and inv.defs[SLOT].id == "cron_mines", str(inv.defs.map(func(d): return d.id)))
	var key := InputEventKey.new()
	key.physical_keycode = KEY_8
	key.pressed = true
	Input.parse_input_event(key)
	await physics_frame
	var by_key: int = inv.current
	key.pressed = false
	Input.parse_input_event(key)
	await physics_frame
	p.select_slot(6)
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
	await _settle(p, 1.8)  # past the fiction line drawing shows for a moment
	await process_frame
	_check("acceptance: key 8 draws it; the weapon cycle reaches it after rm -rf and goes on from it (to the cannon until C28, to ping, slot 9, since) and back; Q returns to it; the strip's third line is the crontab, \"crontab 0/3\"", by_key == SLOT and next == SLOT and wrapped == SLOT + 1 and back == SLOT and last == SLOT and wh.state_text() == "crontab 0/3", "%d %d %d %d %d '%s'" % [by_key, next, wrapped, back, last, wh.state_text()])
	var dummies := _line_up(main)
	var calls := []
	p.cron_ran.connect(func(): calls.append(hud.round_hud().get("last_callout")))
	# Placement: on the floor and on a wall in reach, at the feet with nothing in reach.
	p.respawn_at(main.to_global(Vector3(-14.0, STAND_Y, LINE_Z)))
	var wall := _wall(main, main.to_global(Vector3(-11.0, 2.0, LINE_Z)))
	await _settle(p, 0.3)
	_aim(p, main.to_global(Vector3(-12.0, 0.0, LINE_Z)))
	var on_floor := await _place(main, p)
	_aim(p, main.to_global(Vector3(-11.1, 1.6, LINE_Z)))
	var on_wall := await _place(main, p)
	_aim(p, main.to_global(Vector3(-14.0, 40.0, LINE_Z - 6.0)))
	var at_feet := await _place(main, p)
	var feet: Vector3 = main.to_local(p.global_position)
	var floor_ok: bool = on_floor != null and on_floor.normal.is_equal_approx(Vector3.UP) and absf(main.to_local(on_floor.global_position).y - CronMine.STUD_LIFT_M) < 0.001 and absf(main.to_local(on_floor.global_position).x + 12.0) < 0.05
	var wall_ok: bool = on_wall != null and on_wall.normal.is_equal_approx(Vector3(-1.0, 0.0, 0.0)) and absf(main.to_local(on_wall.global_position).x - (-11.1 - CronMine.STUD_LIFT_M)) < 0.001
	var feet_ok: bool = at_feet != null and at_feet.normal.is_equal_approx(Vector3.UP) and Vector2(main.to_local(at_feet.global_position).x - feet.x, main.to_local(at_feet.global_position).z - feet.z).length() < 0.01 and absf(main.to_local(at_feet.global_position).y - CronMine.STUD_LIFT_M) < 0.001
	inv.mags[SLOT] = 3  # three placed, the magazine empty: its "empty" line comes first, as every weapon's
	await physics_frame
	await process_frame
	var three: String = wh.state_text()
	_check("acceptance: a mine sticks where it is aimed: on the floor 2 m ahead (lying flat on it), on a wall 3 m ahead (on its face), and with nothing within 4 m, on the floor at the player's feet; the strip counts \"crontab 3/3\"", floor_ok and wall_ok and feet_ok and three == "crontab 3/3", "%s %s %s '%s'" % [floor_ok, wall_ok, feet_ok, three])
	# The crontab's limit: a fourth removes the oldest, and the strip notes it.
	_aim(p, main.to_global(Vector3(-12.0, 0.0, LINE_Z + 1.0)))
	var fourth := await _place(main, p)
	await process_frame
	var noted: String = wh.state_text()
	var floor_why: String = on_floor.why if is_instance_valid(on_floor) else "gone"
	var live := get_nodes_in_group(CronMine.GROUP).filter(func(n): return main.is_ancestor_of(n) and n.running())
	var floor_live: bool = live.has(on_floor)
	await _settle(p, 1.7)
	await process_frame
	_check("acceptance: the crontab's limit: a fourth mine removes the oldest (the floor's, \"crontab\" its reason), three still running; the strip notes \"crontab full: oldest out\" for 1.6 s, then \"crontab 3/3\" again", fourth != null and floor_why == CronMine.CRONTAB and live.size() == 3 and not floor_live and noted == "crontab full: oldest out" and wh.state_text() == "crontab 3/3", "%s %d '%s' '%s'" % [floor_why, live.size(), noted, wh.state_text()])
	wall.queue_free()
	p.clear_jobs()
	await _frames(40)
	# The blast on daemons: each run its falloff, none past the radius, none behind cover.
	var cover := _wall(main, main.to_global(Vector3(-11.0, 2.0, 14.0)), Vector3(5.0, 4.0, 0.2))
	_put(main, dummies, [[-11.0, 15.5], [-11.0, 17.0], [-11.0, 18.5], [-11.0, 13.0]])
	for dm in dummies:
		dm.max_health = 1000.0
		dm.reset_for_round()
	p.respawn_at(main.to_global(Vector3(-14.0, STAND_Y, LINE_Z)))
	await _settle(p, 0.2)
	_aim(p, main.to_global(Vector3(-11.0, 0.0, LINE_Z)))
	var before := dummies.map(func(dm): return dm.health())
	var placed := await _place(main, p)
	var store := _track(placed)
	await _until(func(): return store["done"], 10000)
	var taken := range(4).map(func(i): return before[i] - dummies[i].health())
	var expected := range(4).map(func(i): return _w.blast_damage_at(placed_at(store).distance_to(_middle(dummies[i])), false) * 3.0)
	_check("acceptance: each run is a blast with falloff, three runs in all: the daemon 0.5 m off takes %.1f, the one 2 m off %.1f, the one 3.5 m off nothing (past 3 m), and the one 2 m off behind cover nothing (%.1f in the open)" % [taken[0], taken[1], expected[3]], store.get("why", "") == CronMine.DONE and store.get("ages", []).size() == 3 and absf(taken[0] - expected[0]) < 0.01 and absf(taken[1] - expected[1]) < 0.01 and taken[0] > taken[1] and taken[2] == 0.0 and expected[2] == 0.0 and taken[3] == 0.0 and expected[3] > 0.0, "%s against %s" % [taken.map(func(x): return snappedf(x, 0.01)), expected.map(func(x): return snappedf(x, 0.01))])
	_check("the first run of a mine is the round's \"cron\" callout", calls.size() >= 1 and calls.all(func(c): return c == "cron"), str(calls))
	# Root: one run more, 1.5 times, no mine spent.
	var sudo = p.get("sudo")
	sudo.state.charges = 1
	sudo.press()
	var rooted := await _until(func(): return sudo.is_root(), 4000)
	inv.mags[SLOT] = 3
	before = dummies.map(func(dm): return dm.health())
	var rmine := await _place(main, p)
	var spent: int = 3 - inv.mags[SLOT]
	var rstore := _track(rmine)
	await _until(func(): return rstore["done"], 12000)
	taken = range(4).map(func(i): return before[i] - dummies[i].health())
	expected = range(4).map(func(i): return _w.blast_damage_at(placed_at(rstore).distance_to(_middle(dummies[i])), false) * 1.5 * 4.0)
	_check("acceptance: as root (root crontab): the mine runs four times, each 1.5 times as hard (%.1f to the nearest over four), and placing it spends nothing" % taken[0], rooted and rstore.get("ages", []).size() == 4 and absf(taken[0] - expected[0]) < 0.01 and spent == 0, "%d runs, spent %d, %s against %s" % [rstore.get("ages", []).size(), spent, taken.map(func(x): return snappedf(x, 0.01)), expected.map(func(x): return snappedf(x, 0.01))])
	sudo.end_root()
	cover.queue_free()
	# A new round, alone, ends every job.
	inv.mags[SLOT] = 3
	for x in [-12.0, -12.5]:
		_aim(p, main.to_global(Vector3(x, 0.0, LINE_Z)))
		await _place(main, p)
	var running_before := get_nodes_in_group(CronMine.GROUP).filter(func(n): return main.is_ancestor_of(n) and n.running()).size()
	hud.round_hud().call("_start_round", 2)
	await physics_frame
	var running_after := get_nodes_in_group(CronMine.GROUP).filter(func(n): return main.is_ancestor_of(n) and n.running()).size()
	_check("acceptance: a new round clears the player's mines (alone): 2 running, then none", running_before == 2 and running_after == 0 and p.crontab_count() == 0, "%d then %d" % [running_before, running_after])
	await _frames(60)
	_drop(arena)
	await _frames(3)
	var orphans_after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_check("alone: no orphan node left behind", orphans_after <= orphans, "%d before, %d after" % [orphans, orphans_after])


## Places one mine with the drawn weapon (its interval over first): the new mine, or null.
func _place(main: Node, p: Node) -> Node:
	var inv = p.get("inventory")
	inv.cooldowns[SLOT] = 0.0
	inv.reload_left = 0.0
	if inv.mags[SLOT] <= 0 and not inv.free_ammo:
		inv.mags[SLOT] = 3
	var known := get_nodes_in_group(CronMine.GROUP)
	p.drive_input(Vector2.ZERO, false, false, true)
	var found := []
	await _until(func():
		for n in get_nodes_in_group(CronMine.GROUP):
			if main.is_ancestor_of(n) and not known.has(n) and not found.has(n):
				found.append(n)
		return not found.is_empty(), 1000)
	await physics_frame
	return found[0] if not found.is_empty() else null


func placed_at(store: Dictionary) -> Vector3:
	return store.get("at", Vector3.INF)


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


# --- Eight slots at 960x540. ---

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
			hud.entries.push_front({"killer": "Daemon-2", "victim": "Daemon-1", "word": "cron", "left": 30.0})
		host["hud"].guide()._notice("word ".repeat(60), Color.WHITE, 5000)
		host["hud"].net_hud().toggle()
		var wrong := PackedStringArray()
		var strips := []
		for slot in [1, SLOT]:
			p.select_slot(slot)
			await _settle(p, 0.5 if slot == 1 else 1.8)
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
		_check("acceptance: at %dx%d the strip fits eight slots clear of the guide panel (its slot line a point smaller, 11 px; nine slots and 10 px since C28): with SIGTERM drawn (\"%s\") and with cron drawn (\"%s\", \"%s\" on the third line), four cron kills in the feed, the net panel and a long guide notice all inside the screen, nothing covering anything" % [size.x, size.y, strips[0][0], strips[1][0], strips[1][2]], wrong.is_empty() and strips[0][0] == "1 [2 SIGTERM] 3 4(2) 5 6 7 8 9" and strips[1][0] == "1 2 3 4(2) 5 6 7 [8 cron] 9" and strips[0][1] == 14 and strips[1][1] == 14 and strips[1][2] == "crontab 0/3" and strips[0][3] > 0.0 and strips[1][3] > 0.0 and hud.feed_text().size() == 4 and hud.feed_text()[0] == "cron sent by Daemon-2 to Daemon-1", "%s; %s" % [strips, ", ".join(wrong)])
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
	_check("acceptance: protocol 9 still at C27 (10 since C27b, 11 since A5, 12 since I1, 13 since I2, 14 since I3, 15 since C29, 16 since C30, 17 since C31, 18 since C32): a joiner on protocol 8 is refused with the clear version line", Session.PROTOCOL == 18 and refused and os.error == "version mismatch: host 18, you 8", os.error)
	_drop(old)
	await _frames(2)
	var client := _branch("Client", CLIENT_OFFSET)
	var cs: Session = client["session"]
	cs.join("127.0.0.1:%d" % hs.listen_port())
	await _until(func(): return cs.state == Session.State.JOINED and hs.players.size() == 2, 6000)
	var cid: int = cs.my_id
	await _until(func(): return hs.avatars.has(cid) and cs.avatars.has(1) and hs.combat.has_player(cid) and cs.get("_weapons_synced"), 6000)
	await _until(func(): return hs.protect_left.get(1, 0.0) <= 0.0 and hs.protect_left.get(cid, 0.0) <= 0.0, 6000)
	var hp: Node = host["player"]
	var cp: Node = client["player"]
	cp.select_slot(SLOT)
	var drawn := await _until(func(): return hs.combat.drawn_by(cid) == "cron_mines", 4000)
	# A joiner arriving mid-job sees the mine already placed.
	_put_player(client, Vector3(-14.0, STAND_Y, LINE_Z - 6.0), Vector3(1.0, 0.0, 0.0))
	await _settle(cp, 0.6)
	await _until(_heard.bind(hs, cid, client), 4000)
	_aim(cp, client["main"].to_global(Vector3(-12.0, 0.0, LINE_Z - 6.0)))
	await _settle(cp, 0.2)
	await _until(_heard.bind(hs, cid, client), 4000)
	var early := await _host_place(hs, cp)
	var other := _branch("ClientB", CLIENT_B_OFFSET)
	var bs: Session = other["session"]
	bs.join("127.0.0.1:%d" % hs.listen_port())
	var joined := await _until(func(): return bs.state == Session.State.JOINED and hs.players.size() == 3 and bs.players.size() == 3 and cs.players.size() == 3)
	var bid: int = bs.my_id
	var caught := await _until(func(): return bs.get("_mines").has(early), 4000)
	var bmine = bs.get("_mines").get(early)
	var hmine = hs.get("_mines").get(early)
	var caught_ok: bool = caught and is_instance_valid(bmine) and is_instance_valid(hmine) and not bmine.authoritative and bmine.runs_left == hmine.runs_left and bmine.runs_left >= 1
	_check("acceptance: a joiner arriving mid-match sees a mine already placed: the host sends it every running mine, armed, with its runs left (%d), and its screen draws it" % (bmine.runs_left if is_instance_valid(bmine) else -1), joined and caught_ok)
	await _until(func(): return not hs.get("_mines").has(early), 8000)
	await _until(func(): return hs.avatars.has(bid) and cs.avatars.has(bid) and hs.combat.has_player(bid) and bs.get("_weapons_synced"), 6000)
	await _until(func(): return hs.protect_left.get(bid, 0.0) <= 0.0, 6000)
	# One mine under the host: the host and the other joiner hurt each run, the owner never.
	_put_player(host, Vector3(-2.0, STAND_Y, LINE_Z), Vector3(-1.0, 0.0, 0.0))
	_put_player(client, Vector3(-4.0, STAND_Y, LINE_Z), Vector3(1.0, 0.0, 0.0))
	_put_player(other, Vector3(-2.0, STAND_Y, LINE_Z + 2.5), Vector3(-1.0, 0.0, 0.0))
	await _settle(cp, 0.6)
	await _until(_heard.bind(hs, cid, client), 4000)
	await _until(_heard.bind(hs, bid, other), 4000)
	_aim(cp, client["main"].to_global(Vector3(-2.0, 0.0, LINE_Z)))
	await _settle(cp, 0.2)
	await _until(_heard.bind(hs, cid, client), 4000)
	for id in [1, cid, bid]:
		hs.combat.states[id]["health"] = 100.0
	hs.call("_mirror_from_combat")
	var deaths: int = hs.combat.states[cid]["deaths"]
	var kills: int = hs.combat.states[cid]["kills"]
	var id1 := await _host_place(hs, cp)
	var hmine1 = hs.get("_mines").get(id1)
	await _until(func(): return cs.get("_mines").has(id1), 4000)
	var cmine = cs.get("_mines").get(id1)
	var c_words := []
	var c_decides: bool = is_instance_valid(cmine) and cmine.authoritative
	if is_instance_valid(cmine):
		cmine.ran.connect(func(left, _at): c_words.append(left))
	var at: Vector3 = hmine1.global_position if is_instance_valid(hmine1) else Vector3.INF
	var hmid: Vector3 = hp.global_position
	var cmid: Vector3 = host["main"].to_global(hs.avatars[cid].latest_position())
	var bmid: Vector3 = host["main"].to_global(hs.avatars[bid].latest_position())
	var per := {1: _w.blast_damage_at(at.distance_to(hmid), false), bid: _w.blast_damage_at(at.distance_to(bmid), false), cid: _w.blast_damage_at(at.distance_to(cmid), false)}
	var first_run := await _until(func(): return is_instance_valid(hmine1) and hmine1.run_ages.size() >= 1, 6000)
	await physics_frame
	var after_one := {1: hs.combat.health_of(1), bid: hs.combat.health_of(bid), cid: hs.combat.health_of(cid)}
	var one_ok: bool = first_run and absf(after_one[1] - (100.0 - per[1])) < 0.001 and absf(after_one[bid] - (100.0 - per[bid])) < 0.001 and after_one[cid] == 100.0 and per[cid] > 0.0
	_check("acceptance: a 127.0.0.1 match, a host and two joiners: the host runs a joiner's mine and judges its first run on everyone in reach: the host over it %.1f (one run survived), the other joiner %.1f, each its falloff; the owner, %.1f m off and inside the radius, takes nothing from its own mine" % [per[1], per[bid], at.distance_to(cmid)], joined and drawn and one_ok, "after one %s, per run %s" % [_rounded(after_one), _rounded(per)])
	# The owner dies; its mine runs on, and the kill is still its own.
	hs.combat.damage_player(cid, 1, 1000.0)
	hs.combat.defer_respawn(cid, 8.0)  # held dead through every run still to come
	hs.call("_broadcast_death", cid, 1, Vector3.UP, "terminal_cannon")
	hs.call("_mirror_from_combat")
	var host_dead := await _until(func(): return hs.dead.get(1, false) and cs.dead.get(1, false) and bs.dead.get(1, false), 8000)
	var owner_still_dead: bool = not hs.combat.alive(cid)
	var credited: bool = owner_still_dead and hs.combat.states[cid]["kills"] == kills + 1 and hs.combat.states[cid]["deaths"] == deaths + 1
	var feed_ok := await _until(func(): return [host, client, other].all(func(side): return side["hud"].combat_hud().feed_text().has("cron sent by Daemon-2 to Daemon-1")), 4000)
	_check("acceptance: mines keep running after the owner dies: the owner derezzed after the first run and held dead, the mine's later runs take the host from %.1f to its death while the owner is still down, the kill credited to the owner, and every screen's feed reads \"cron sent by Daemon-2 to Daemon-1\"" % after_one[1], host_dead and credited and feed_ok, "kills %d -> %d" % [kills, hs.combat.states[cid]["kills"]])
	await _until(func(): return not hs.get("_mines").has(id1), 6000)
	_check("acceptance: a joiner never schedules or damages: the owner's own copy of the mine only drew and judged nothing, running on the host's three words alone (runs left 2, 1, 0)", not c_decides and c_words == [2, 1, 0], str(c_words))
	# Another player's shot removes a mine: the host judges it.
	await _until(func(): return not hs.dead.get(1, false) and not hs.dead.get(cid, false), 20000)
	cp.select_slot(SLOT)
	_put_player(client, Vector3(-6.0, STAND_Y, LINE_Z), Vector3(1.0, 0.0, 0.0))
	_put_player(other, Vector3(-6.0, STAND_Y, LINE_Z + 6.0), Vector3(0.0, 0.0, -1.0))
	_put_player(host, Vector3(4.0, STAND_Y, LINE_Z), Vector3(-1.0, 0.0, 0.0))
	await _settle(cp, 0.8)
	await _until(_heard.bind(hs, cid, client), 4000)
	await _until(_heard.bind(hs, bid, other), 4000)
	_aim(cp, client["main"].to_global(Vector3(-4.0, 0.0, LINE_Z)))
	await _settle(cp, 0.2)
	await _until(_heard.bind(hs, cid, client), 4000)
	var id2 := await _host_place(hs, cp)
	var hmine2 = hs.get("_mines").get(id2)
	var target: Vector3 = other["main"].to_global(host["main"].to_local(hmine2.global_position)) if is_instance_valid(hmine2) else Vector3.ZERO
	var bp: Node = other["player"]
	bp.select_slot(0)
	await _settle(bp, 0.6)
	_aim(bp, target)
	await _settle(bp, 0.3)
	await _until(_heard.bind(hs, bid, other), 4000)
	bp.drive_input(Vector2.ZERO, false, false, true)
	var shot := await _until(func(): return not is_instance_valid(hmine2) or hmine2.why == CronMine.SHOT, 4000)
	var removed_ok: bool = shot and (not is_instance_valid(hmine2) or hmine2.why == CronMine.SHOT)
	var cfeed := await _until(func(): return [host, client, other].all(func(side): return side["hud"].combat_hud().feed_text().has("crontab -r: Daemon-3 removed Daemon-2's job")), 4000)
	var cgone := await _until(func(): return not cs.get("_mines").has(id2), 4000)
	_check("acceptance: counterplay: the other joiner shoots the mine with the cannon, the host judges the shot and removes it, the owner's screen drops it, and every feed reads \"crontab -r: Daemon-3 removed Daemon-2's job\"", removed_ok and cfeed and cgone, "%s %s %s" % [removed_ok, cfeed, cgone])
	# The owner leaving takes its jobs with it.
	await _settle(cp, 0.6)
	cp.get("inventory").mags[SLOT] = 3
	var id3 := await _host_place(hs, cp)
	var seen_b := await _until(func(): return bs.get("_mines").has(id3), 4000)
	var hmine3 = hs.get("_mines").get(id3)
	var bmine3 = bs.get("_mines").get(id3)
	cs.leave()
	await _until(func(): return not hs.players.has(cid), 4000)
	await physics_frame
	# Read at once, before its job could end on its own: the reason is the owner's leaving.
	var host_why: String = hmine3.why if is_instance_valid(hmine3) else "freed"
	var b_why := [""]
	await _until(func():
		b_why[0] = bmine3.why if is_instance_valid(bmine3) else "freed"
		return b_why[0] != "", 4000)
	_check("acceptance: mines are removed when their owner leaves: the joiner's mine (seen by the other joiner) ends on the host the moment it drops the player, and on the other joiner's screen on the host's word, \"gone\" its reason on both", seen_b and host_why == CronMine.GONE and b_why[0] == CronMine.GONE, "%s %s" % [host_why, b_why[0]])
	_drop(host)
	_drop(client)
	_drop(other)
	await _frames(4)
	var orphans_after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_check("acceptance: no orphan nodes are left behind by any of it", orphans_after <= orphans, "%d before, %d after" % [orphans, orphans_after])


## `placer` places one mine in the match: the id the host gave it (0 if none came).
func _host_place(hs: Session, placer: Node) -> int:
	var before: int = hs.get("_throws")
	var inv = placer.get("inventory")
	if inv.mags[SLOT] <= 0:
		inv.mags[SLOT] = 3
	placer.drive_input(Vector2.ZERO, false, false, true)
	var made := await _until(func(): return hs.get("_mines").has(before + 1), 4000)
	return before + 1 if made else 0


# --- Helpers. ---

## A record of mine `m` taken the moment it is gone.
func _track(m: Node) -> Dictionary:
	var store := {"done": false, "at": m.global_position}
	m.finished.connect(_snap.bind(m, store))
	return store


func _snap(why: String, m: Node, store: Dictionary) -> void:
	store["done"] = true
	store["why"] = why
	store["ages"] = m.run_ages.duplicate()


func _rounded(d: Dictionary) -> String:
	var out := PackedStringArray()
	for k in d:
		out.append("%.1f" % d[k])
	return ", ".join(out)


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


func _put_player(side: Dictionary, at: Vector3, facing: Vector3) -> void:
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
