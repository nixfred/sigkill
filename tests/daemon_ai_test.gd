extends SceneTree
## Headless test of the daemons fighting back for SIGKILL (C27b). scripts/check.sh runs it as
## step 37, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/daemon_ai_test.gd
##
## In the real arena, with each check's daemons put where it needs them (the others parked under
## the floor, where nothing sees them) and the real player standing idle: each type damages an
## idle player in range; a tell precedes every attack (in the brain's events and on the rogue's
## rig), and the code has one way into a strike, from the end of a tell; nothing lands through a
## wall (no tell without sight, the slash's and the bolt's own checks against the level, each
## proved to land with the wall gone); SIGSTOP freezes their brains, their tells and a bolt in the
## air, and they go on after it; practice never attacks, never moves, and keeps the old dummies;
## the difficulty scales the damage and the waits; the attacker cap holds (and binds); the bolt is
## a real projectile, slow and dodgeable; aggro range, leash and the walk home; the solo life (the
## match's numbers, a death, the 3 s respawn far from the daemons, spawn protection, the round's
## deaths, the banner, the flash and the vignette, the view jolt only with screen shake on);
## rogue.d's fair hit volume; the settings saved; every number in resources/daemon_ai.tres; and
## the fiction rule (the fight code makes no OS, process, file or network call). Then a host and
## a joiner over ENet on 127.0.0.1 (the joiner's arena 1000 m off): the host's daemons hunt the
## joiner, the damage judged in the host's combat and shown on both screens, the joiner's copies
## following the host's (their tells and the bolts drawn there), a joiner's shot landing on the
## host's daemon only through the host, a daemon's kill named on the joiner's banner, and the
## host's practice giving every player its own old dummies again; protocol 10.
## Deterministic: frames counted, only counts and outcomes printed.

const Session = preload("res://scripts/net/net_session.gd")
const CombatTuningScript = preload("res://scripts/net/combat_tuning.gd")
const NetTuningScript = preload("res://scripts/net/net_tuning.gd")
const Link = preload("res://scripts/guide/guide_link.gd")
const MainScene = preload("res://scenes/main.tscn")
const Controls = preload("res://scripts/controls.gd")
const FIGHT_DIR := "res://scripts/fight/"
const WATCHDOG_MS := 12000
const CLIENT_OFFSET := Vector3(1000.0, 0.0, 0.0)
## Open floor south of the low wall, clear of the crates and the platform.
const OPEN := Vector3(0.0, 0.95, 15.0)
## Where a daemon a check does not use waits: under the floor, out of every sight line.
const PARKED := Vector3(0.0, -50.0, 0.0)
## The west cover wall, CoverL1: x from -15 to -9, z from 1.8 to 2.2, 3 m high.
const WALL_X := -12.0
const PAST_WALL_X := -7.0
const NAMES := {"rogue": "DummyA", "zombie": "DummyC", "swarm": "DummyD", "zombie2": "DummyB"}
const NEVER := ["OS.", "execute", "create_process", "kill(", "Thread", "HTTP", "PacketPeer", "StreamPeer", "TCPServer", "UDPServer", "DirAccess", "FileAccess", "shell_open", "move_to_trash", "Expression", "Time.", "ctrl_pressed", "alt_pressed"]
const EPS := 0.001
const FRAME := 1.0 / 60.0

var _fails := 0
var _checks := 0
var _tmp := ""
var _arenas: Array = []
var _branches: Array = []
var _t: DaemonAiTuning


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_tmp = OS.get_temp_dir().path_join("sigkill-daemon-ai-test-%d" % OS.get_process_id())
	if DirAccess.dir_exists_absolute(_tmp):
		print("FAIL the test's temporary folder already exists; not touching it")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_tmp)
	Controls.ensure()
	GameSettings.current().reset()
	_t = load("res://resources/daemon_ai.tres")
	_source_checks()
	_settings_checks()
	await _each_type_checks()
	await _tell_and_cap_checks()
	await _wall_checks()
	await _sigstop_checks()
	await _practice_checks()
	await _difficulty_checks()
	await _bolt_checks()
	await _leash_checks()
	await _life_checks()
	await _volume_checks()
	await _match_checks()
	await _cleanup()
	for name in DirAccess.get_files_at(_tmp):
		DirAccess.remove_absolute(_tmp.path_join(name))
	DirAccess.remove_absolute(_tmp)
	print("DAEMON AI: %d checks" % _checks)
	print("DAEMON AI RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The sources, the numbers and the settings. ---

func _source_checks() -> void:
	var code := ""
	for name in DirAccess.get_files_at(FIGHT_DIR):
		if name.ends_with(".gd"):
			code += _code(FIGHT_DIR + name)
	var found := PackedStringArray()
	for word in NEVER:
		if code.contains(word):
			found.append(word)
	_check("acceptance: fiction only: the fight code (brain, director, bolt, solo life, tuning) makes no OS, process, file, folder, thread or network call, reads no wall clock and handles no Ctrl or Alt key", found.is_empty() and code.length() > 20000, ", ".join(found))
	var brain := _code(FIGHT_DIR + "daemon_brain.gd")
	var calls := RegEx.create_from_string("(?<![A-Za-z_])_strike\\(").search_all(brain).size()
	_check("acceptance: one way into an attack: the strike is entered only from the end of a tell (its one call is in _step_tell), and a tell only from a hunt with the prey in sight and a slot (or a burst's next dive, which checks the same)", calls == 2 and _body(brain, "_step_tell").contains("_strike(target, d)") and _body(brain, "_step_hunt").contains("d.take_slot(self, prey)") and _body(brain, "_step_hunt").contains("if sees and cooldown <= 0.0 and _in_range(target, d) and d.prey_attackable(prey)") and _body(brain, "_step_recover").contains("_sees(target, d)"), "%d mentions" % calls)
	var tres := FileAccess.get_file_as_string("res://resources/daemon_ai.tres")
	var missing := PackedStringArray()
	for key in DaemonAiTuning.RANGES.keys() + ["max_attackers", "swarm_burst"]:
		if not tres.contains("\n%s = " % key):
			missing.append(key)
	_check("acceptance: every tunable number is in resources/daemon_ai.tres (each in range), and the brains read their damage, speeds, ranges and waits from it", _t is DaemonAiTuning and _t.problems().is_empty() and missing.is_empty() and brain.contains("t.rogue_damage") and brain.contains("t.swarm_damage") and brain.contains("d.tuning.aggro_range_m") and brain.contains("d.tuning.leash_m") and _code(FIGHT_DIR + "daemon_director.gd").contains("tuning.zombie_bolt_damage") and _code(FIGHT_DIR + "daemon_director.gd").contains("tuning.max_attackers"), ", ".join(missing))
	var bad := DaemonAiTuning.new()
	bad.rogue_damage = -5.0
	bad.max_attackers = 0
	_check("a bad tuning is refused with every reason", bad.problems().size() == 2)
	var shader := FileAccess.get_file_as_string("res://shaders/damage_vignette.gdshader")
	_check("acceptance: the hit vignette never warps the picture: colour only, no screen read, no UV moved", shader.contains("COLOR = vec4(color.rgb") and not shader.contains("SCREEN") and not shader.contains("screen_texture") and not shader.contains("texture(") and not shader.contains("UV ="))


func _settings_checks() -> void:
	var s := GameSettings.new()
	_check("acceptance: the difficulty is normal by default and practice off: the daemons fight back", s.value("gameplay", "difficulty") == "normal" and s.value("gameplay", "practice") == false)
	var refused := not s.set_value("gameplay", "difficulty", "nightmare") and not s.set_value("gameplay", "practice", "yes")
	var path := _tmp.path_join("settings.cfg")
	s.path = path
	var taken := s.set_value("gameplay", "difficulty", "hard") and s.set_value("gameplay", "practice", true) and s.save()
	var back := GameSettings.new()
	back.path = path
	var how := back.load_file()
	_check("acceptance: difficulty and practice are saved like the other settings: easy, normal or hard and on or off read back from the file; anything else is refused", refused and taken and how == "loaded" and back.value("gameplay", "difficulty") == "hard" and back.value("gameplay", "practice") == true, how)
	_check("difficulty's damage and aggression from the tuning: easy 0.6 and 0.75, normal 1 and 1, hard 1.5 and 1.35", _t.damage_scale("easy") == 0.6 and _t.aggression("easy") == 0.75 and _t.damage_scale("normal") == 1.0 and _t.aggression("normal") == 1.0 and _t.damage_scale("hard") == 1.5 and _t.aggression("hard") == 1.35)


# --- Alone. ---

func _each_type_checks() -> void:
	var places := {"rogue": Vector3(0.0, 0.0, 11.5), "zombie": Vector3(0.0, 0.0, 8.0), "swarm": Vector3(3.0, 1.0, 11.0)}
	for type in ["rogue", "zombie", "swarm"]:
		var main := await _lab({NAMES[type]: places[type]}, OPEN)
		var life = main.get_node("SoloLife")
		var brain: DaemonBrain = _dummy(main, NAMES[type]).brain
		var frames := await _wait(func(): return life.health() < 100.0, 720)
		var first := _first(brain, "hit")
		_check("acceptance: %s damages an idle player in range: health %.0f after %d frames, its first hit after a tell and a strike" % [type, life.health(), frames], frames >= 0 and life.health() < 100.0 and first >= 0 and _told_before(brain, first), _events(brain))
		await _drop(main)


func _tell_and_cap_checks() -> void:
	var main := await _lab({"DummyA": Vector3(0.0, 0.0, 12.0), "DummyB": Vector3(-4.0, 0.0, 9.0), "DummyC": Vector3(4.0, 0.0, 9.0), "DummyD": Vector3(2.0, 1.0, 11.5)}, OPEN)
	var director: DaemonDirector = main.get_node("DaemonDirector")
	var rogue: DaemonBrain = _dummy(main, "DummyA").brain
	var rig = rogue.art
	var most := 0
	var most_busy := 0
	var bound := false
	var rear := 0.0
	var reared := []
	var last_state := rogue.state
	for i in 1500:
		await physics_frame
		most = maxi(most, director.attackers(1))
		var busy := 0
		var waiting := false
		for b in director.brains():
			busy += 1 if b.attacking() else 0
			if b.state == DaemonBrain.State.HUNT and b.cooldown <= 0.0 and b.prey == 1 and director.prey_attackable(1) and b._in_range(director.prey_point(1), director) and b._sees(director.prey_point(1), director):
				waiting = true
		most_busy = maxi(most_busy, busy)
		bound = bound or (director.attackers(1) >= _t.max_attackers and waiting)
		if rogue.state == DaemonBrain.State.TELL:
			rear = maxf(rear, rig.rear())
		if last_state == DaemonBrain.State.TELL and rogue.state != DaemonBrain.State.TELL:
			reared.append([rogue.state == DaemonBrain.State.STRIKE, rear])
			rear = 0.0
		last_state = rogue.state
	var untold := PackedStringArray()
	var attacks := 0
	for b in director.brains():
		attacks += b.attacks
		for i in b.events.size():
			if b.events[i][1] == "attack" and not _told_before(b, i):
				untold.append(String(b.dummy.name))
	var low_rear := reared.filter(func(r): return r[0] and r[1] < 0.9).size()
	_check("acceptance: a tell precedes every attack: over 25 s of four daemons on one player, %d attacks, each with its own tell first (at least the tell's length before it), none without" % attacks, attacks >= 8 and untold.is_empty(), ", ".join(untold))
	_check("acceptance: the rogue's tell is its rear-up, readable: it reared at least 0.9 of the way before every strike (%d tells seen)" % reared.size(), reared.size() >= 2 and low_rear == 0 and rogue.attacks >= 1)
	_check("acceptance: the attacker cap holds: never more than %d daemons in a tell or a strike on the player (most %d slots, %d attacking), and it binds: the cap was full while another daemon in sight and in range waited" % [_t.max_attackers, most, most_busy], most <= _t.max_attackers and most_busy <= _t.max_attackers and most == _t.max_attackers and bound)
	var three := [DaemonBrain.new(Node3D.new(), null), DaemonBrain.new(Node3D.new(), null), DaemonBrain.new(Node3D.new(), null)]
	var slots := [director.take_slot(three[0], 7), director.take_slot(three[1], 7), director.take_slot(three[2], 7)]
	for b in three:
		director.release_slot(b)
		b.dummy.free()
	_check("the cap is per player: a third slot on one player is refused while two are held", slots == [true, true, false])
	await _drop(main)


func _wall_checks() -> void:
	# No sight through the wall: no hunt, no tell, no damage.
	var main := await _lab({"DummyA": Vector3(WALL_X, 0.0, 3.2), "DummyC": Vector3(WALL_X + 1.0, 0.0, 6.0)}, Vector3(WALL_X, 0.95, 0.9))
	var life = main.get_node("SoloLife")
	var director: DaemonDirector = main.get_node("DaemonDirector")
	var rogue: DaemonBrain = _dummy(main, "DummyA").brain
	var zombie: DaemonBrain = _dummy(main, "DummyC").brain
	await _frames(360)
	_check("acceptance: no attack through a wall: a rogue 2.3 m off and a zombie 5 m off behind cover never see the player, never tell, never hurt it (6 s)", life.health() == 100.0 and rogue.tells == 0 and zombie.tells == 0 and rogue.state == DaemonBrain.State.HOME, "%s %s" % [_events(rogue), _events(zombie)])
	# The slash's own check: the scythes come down within reach of the player, the wall between.
	_aim_daemon(_dummy(main, "DummyA"), Vector3(WALL_X, 0.0, 0.0))
	rogue.prey = 1
	rogue._slash(director)
	var through: float = life.health()
	_place(_dummy(main, "DummyA"), Vector3(PAST_WALL_X, 0.0, 3.2))
	_aim_daemon(_dummy(main, "DummyA"), Vector3(PAST_WALL_X, 0.0, 0.0))
	main.get_node("Player").global_position = Vector3(PAST_WALL_X, 0.95, 0.9)
	await _frames(1)
	rogue.prey = 1
	rogue._slash(director)
	var clear: float = life.health()
	_check("acceptance: no damage through a wall, melee: the same slash lands nothing with the wall between (%.0f) and lands with it gone (%.0f)" % [through, clear], through == 100.0 and is_equal_approx(clear, 100.0 - _t.rogue_damage))
	# The bolt's own path: stopped by the wall; with it gone it lands.
	_park(_dummy(main, "DummyA"))
	main.get_node("Player").global_position = Vector3(WALL_X, 0.95, 0.9)
	await _frames(1)
	var before: float = life.health()
	zombie.prey = 1
	var bolt := director.throw_bolt(zombie, Vector3(WALL_X, 1.3, 4.0), (Vector3(WALL_X, 0.95, 0.9) - Vector3(WALL_X, 1.3, 4.0)).normalized())
	await _wait(func(): return not bolt.live, 240)
	var blocked := [bolt.ended, life.health()]
	main.get_node("Player").global_position = Vector3(PAST_WALL_X, 0.95, 0.9)
	await _frames(1)
	bolt = director.throw_bolt(zombie, Vector3(PAST_WALL_X, 1.3, 4.0), (Vector3(PAST_WALL_X, 0.95, 0.9) - Vector3(PAST_WALL_X, 1.3, 4.0)).normalized())
	await _wait(func(): return not bolt.live, 240)
	_check("acceptance: no damage through a wall, bolt: the bolt meets the wall and ends there (%s, health %.0f), and with the wall gone the same throw meets the player (%s)" % [blocked[0], blocked[1], bolt.ended], blocked[0] == "level" and blocked[1] == before and bolt.ended == "player" and is_equal_approx(life.health(), before - _t.zombie_bolt_damage))
	await _drop(main)


func _sigstop_checks() -> void:
	var main := await _lab({"DummyA": Vector3(0.0, 0.0, 12.6), "DummyC": Vector3(-6.0, 0.0, 9.0)}, OPEN)
	var player = main.get_node("Player")
	var life = main.get_node("SoloLife")
	var director: DaemonDirector = main.get_node("DaemonDirector")
	var rogue: DaemonBrain = _dummy(main, "DummyA").brain
	var zombie: DaemonBrain = _dummy(main, "DummyC").brain
	var telling := await _wait(func(): return rogue.state == DaemonBrain.State.TELL and rogue.state_t > 0.1, 600)
	player.refill_sigstop()
	player.sigstop.press()
	var on := await _wait(func(): return player.sigstop.is_on(), 10)
	zombie.prey = 1
	var bolt := director.throw_bolt(zombie, Vector3(-6.0, 1.3, 9.0), (OPEN - Vector3(-6.0, 1.3, 9.0)).normalized())
	var held := [rogue.state, rogue.state_t, rogue.clock, rogue.attacks, rogue.dummy.global_position, bolt.global_position, life.health(), zombie.state_t]
	await _frames(60)
	var still: bool = rogue.state == held[0] and rogue.state_t == held[1] and rogue.clock == held[2] and rogue.attacks == held[3] and rogue.dummy.global_position == held[4] and bolt.global_position == held[5] and bolt.live and life.health() == held[6] and zombie.state_t == held[7]
	_check("acceptance: SIGSTOP (F) freezes their AI and attacks: for 60 frames the rogue mid-tell holds its state, its clock and its place, the zombie's clock holds, and a bolt in the air hangs where it was, nothing landing", telling >= 0 and on >= 0 and still, "tell at %d, on at %d; rogue %s %.3f -> %s %.3f, bolt moved %.3f m" % [telling, on, held[0], held[1], rogue.state, rogue.state_t, bolt.global_position.distance_to(held[5])])
	player.sigstop.press()
	var off := await _wait(func(): return not player.sigstop.is_on(), 30)
	var struck := await _wait(func(): return rogue.attacks > held[3], 240)
	var flew := await _wait(func(): return not bolt.live, 240)
	_check("after SIGCONT they go on: the rogue's tell ends in its strike and the bolt flies on", off >= 0 and struck >= 0 and flew >= 0, "%d %d %d" % [off, struck, flew])
	await _drop(main)


func _practice_checks() -> void:
	var places := {"DummyA": Vector3(0.0, 0.0, 12.5), "DummyB": Vector3(-3.0, 0.0, 13.0), "DummyC": Vector3(3.0, 0.0, 13.0), "DummyD": Vector3(1.5, 1.0, 17.0)}
	var main := await _lab(places, OPEN, "normal", true)
	var life = main.get_node("SoloLife")
	var director: DaemonDirector = main.get_node("DaemonDirector")
	var rig = _dummy(main, "DummyA").brain.art
	var reared := 0.0
	for i in 600:
		await physics_frame
		reared = maxf(reared, rig.rear())
	var tells := 0
	var moved := 0.0
	for name in places:
		var brain: DaemonBrain = _dummy(main, name).brain
		tells += brain.tells + brain.attacks
		moved = maxf(moved, _dummy(main, name).global_position.distance_to(places[name]))
	var hud = main.get_node("Hud").combat_hud()
	_check("acceptance: practice mode never attacks: four daemons 2 to 3 m from the player for 10 s, no tell, no strike, no bolt, none of them moved, the player's health untouched and not even shown", director.mode == DaemonDirector.Mode.REST and tells == 0 and director.bolts_live() == 0 and moved < EPS and life.health() == 100.0 and hud.line_text() == "", "tells %d, moved %.3f m, line '%s'" % [tells, moved, hud.line_text()])
	_check("practice keeps the old dummies: rogue.d's threat display still rears up on its own clock, and a shot still derezzes a dummy", reared > 0.5 and _dummy(main, "DummyB").hit(1000.0) and not _dummy(main, "DummyB").is_alive())
	await _drop(main)


func _difficulty_checks() -> void:
	var drops := {}
	var waits := {}
	for level in ["easy", "normal", "hard"]:
		var main := await _lab({"DummyA": Vector3(0.0, 0.0, 12.8)}, OPEN, level)
		var life = main.get_node("SoloLife")
		var brain: DaemonBrain = _dummy(main, "DummyA").brain
		await _wait(func(): return life.health() < 100.0, 600)
		drops[level] = 100.0 - life.health()
		await _wait(func(): return brain.state == DaemonBrain.State.HUNT and brain.attacks >= 1, 120)
		waits[level] = brain.cooldown
		await _drop(main)
	var ok := true
	for level in drops:
		ok = ok and is_equal_approx(drops[level], _t.rogue_damage * _t.damage_scale(level))
		ok = ok and absf(waits[level] - _t.rogue_cooldown_s / _t.aggression(level)) <= 2.0 * FRAME
	_check("acceptance: difficulty multipliers scale damage: the rogue's slash takes %.0f on easy, %.0f on normal, %.0f on hard (its damage times 0.6, 1 and 1.5), and its wait after a strike is shorter the harder (%.2f, %.2f, %.2f s)" % [drops.get("easy", -1.0), drops.get("normal", -1.0), drops.get("hard", -1.0), waits.get("easy", -1.0), waits.get("normal", -1.0), waits.get("hard", -1.0)], ok and drops.size() == 3)


func _bolt_checks() -> void:
	var main := await _lab({"DummyC": PARKED + Vector3(5.0, 0.0, 0.0)}, OPEN)
	var life = main.get_node("SoloLife")
	var director: DaemonDirector = main.get_node("DaemonDirector")
	var zombie: DaemonBrain = _dummy(main, "DummyC").brain
	zombie.prey = 1
	var from := Vector3(0.0, 1.0, 6.0)
	var bolt := director.throw_bolt(zombie, from, (OPEN - from).normalized())
	var at_once: float = life.health()
	var arrived := await _wait(func(): return not bolt.live, 240)
	var taken: float = 100.0 - life.health()
	var far := from.distance_to(OPEN) - _t.zombie_bolt_radius_m - DaemonDirector.BODY_RADIUS_M
	_check("acceptance: the zombie's bolt is a real projectile: nothing lands the frame it is thrown, it meets the player after %d frames (%.1f m at %.0f m/s), then takes its damage" % [arrived, far, _t.zombie_bolt_speed], at_once == 100.0 and absf(arrived * FRAME - far / _t.zombie_bolt_speed) <= 3.0 * FRAME and is_equal_approx(taken, _t.zombie_bolt_damage), "%.1f taken" % taken)
	var player = main.get_node("Player")
	bolt = director.throw_bolt(zombie, from, (OPEN - from).normalized())
	await _frames(20)
	player.global_position = OPEN + Vector3(1.6, 0.0, 0.0)
	await _wait(func(): return not bolt.live, 300)
	_check("acceptance: and dodgeable: a sidestep of 1.6 m while it flies and it passes, landing nothing (%s)" % bolt.ended, bolt.ended != "player" and is_equal_approx(100.0 - life.health(), taken))
	var used := director.bolts().size()
	var thrown := 0
	for i in 20:
		if director.throw_bolt(zombie, from, Vector3.FORWARD) != null:
			thrown += 1
	_check("the bolts come from a fixed pool of %d: a 21st throw at once finds none free, and nothing is made" % used, used == DaemonDirector.BOLTS and thrown == DaemonDirector.BOLTS)
	await _drop(main)


func _leash_checks() -> void:
	var home := Vector3(8.0, 0.0, 16.0)
	var main := await _lab({"DummyA": home}, Vector3(-12.0, 0.95, 16.0))
	var player = main.get_node("Player")
	var brain: DaemonBrain = _dummy(main, "DummyA").brain
	await _frames(120)
	var far_off := brain.state == DaemonBrain.State.HOME and brain.prey == 0
	player.global_position = Vector3(-4.0, 0.95, 16.0)
	var hunted := await _wait(func(): return brain.state == DaemonBrain.State.HUNT, 30)
	player.global_position = Vector3(-17.5, 0.95, 16.0)
	var furthest := 0.0
	var went_home := false
	for i in 900:
		await physics_frame
		furthest = maxf(furthest, Vector2(brain.dummy.global_position.x - home.x, brain.dummy.global_position.z - home.z).length())
		if brain.state == DaemonBrain.State.HOME:
			went_home = true
			break
	_check("acceptance: aggro range: a player 20 m off in plain sight is left alone; at 12 m it is hunted (in %d frames)" % hunted, far_off and hunted >= 0)
	_check("acceptance: the leash: chasing a player who runs off, the rogue goes no more than %.1f m from its spot (leash %.0f m), then walks home and stands there as it did" % [furthest, _t.leash_m], furthest <= _t.leash_m + 0.5 and furthest > 5.0 and went_home and brain.dummy.global_position.distance_to(home) < 0.31, "%.2f m from home" % brain.dummy.global_position.distance_to(home))
	await _drop(main)


func _life_checks() -> void:
	var main := await _lab({"DummyA": Vector3(0.0, 0.0, 12.8)}, OPEN)
	var player = main.get_node("Player")
	var life = main.get_node("SoloLife")
	var hud = main.get_node("Hud").combat_hud()
	var rounds = main.get_node("Hud").round_hud()
	var rogue: Node = _dummy(main, "DummyA")
	_check("acceptance: alone the player has 100 health, from the match's combat numbers, shown on the combat line", life.health() == 100.0 and life.max_health() == CombatTuningScript.new().max_health and hud.line_text() == "health 100", hud.line_text())
	GameSettings.current().set_value("hud", "screen_shake", true)
	await _wait(func(): return life.health() < 100.0, 600)
	await physics_frame
	var shook: float = player.get("_shake")
	var flash: float = hud.flash_left()
	var vignette: float = hud.vignette_strength()
	_check("acceptance: a hit flashes red and presses the vignette in (%.2f), the line shows the health left, and the view jolts with screen shake on" % vignette, flash > 0.0 and vignette > 0.5 and shook > 0.0 and hud.line_text() == "health %d" % roundi(life.health()), "%s, shake %.3f" % [hud.line_text(), shook])
	GameSettings.current().set_value("hud", "screen_shake", false)
	await physics_frame
	life.damage(10.0, rogue, Vector3.FORWARD)
	var calm: float = player.get("_shake")
	GameSettings.current().set_value("hud", "screen_shake", true)
	_check("acceptance: the jolt respects the screen shake setting: off, a hit moves nothing", calm == 0.0)
	life.damage(life.health() - 5.0, rogue, Vector3.FORWARD)
	var deaths_before: int = rounds.stats.deaths
	var died := await _wait(func(): return not life.alive(), 600)
	var down_frame := Engine.get_physics_frames()
	var banner: String = hud.banner_text()
	var banner_ok := banner.contains("DEREZZED by rogue.d") and banner.contains("respawn in")
	var derezz := main.find_children("*", "Node3D", true, false).filter(func(n): return n.get_script() == load("res://scripts/derezz_fx.gd")).size()
	_check("acceptance: on death the player derezzes, as in a match: set down, the derezz played where it stood, the banner naming the daemon (%s), and the round counts the death" % banner.replace("\n", " "), died >= 0 and not player.alive and banner_ok and derezz >= 1 and rounds.stats.deaths == deaths_before + 1 and life.deaths >= 1)
	var back := await _wait(func(): return life.alive(), 400)
	var after := (Engine.get_physics_frames() - down_frame) * FRAME
	var spawn: Vector3 = player.global_position
	var far_spawn := spawn.distance_to(Vector3(15.0, 0.95, -15.0)) < 1.0 or spawn.distance_to(Vector3(-15.0, 0.95, -15.0)) < 1.0
	_check("acceptance: and respawns through the match's flow after its delay (%.2f s, the combat numbers' %.1f s): alive, full health, spawn-protected, at a spawn point far from the daemons (the lair's corners, not the one beside it)" % [after, CombatTuningScript.new().respawn_delay_s], back >= 0 and absf(after - CombatTuningScript.new().respawn_delay_s) <= 2.0 * FRAME and player.alive and life.health() == 100.0 and life.protected() and far_spawn, "at %s" % spawn)
	# The rogue put right beside the fresh spawn: it sees the player but starts nothing while the
	# protection lasts, and tells as soon as it is over.
	_place(rogue, Vector3(spawn.x, 0.0, spawn.z + 2.2))
	var told: int = rogue.brain.tells
	var guarded := true
	var left: float = life.protect_left()
	var broke := ""
	# Each frame the player's life steps before the director (main.gd adds it first), so a tell
	# seen after a frame was started with the protection as that frame left it.
	while life.protected():
		await physics_frame
		if guarded and rogue.brain.tells != told and life.protect_left() > 0.0:
			broke = "a tell with %.2f s of protection left: %s" % [life.protect_left(), _events(rogue.brain)]
			guarded = false
	var then := await _wait(func(): return rogue.brain.tells > told, 120)
	_check("acceptance: spawn protection holds against daemons: a rogue beside the player starts no tell while it lasts (%.2f s), and tells once it is over (%d frames after)" % [left, then], guarded and then >= 0 and left > 1.0, broke)
	var payload: Dictionary = rounds.stats.payload()
	_check("acceptance: round stats count deaths, for the announcer and the roast: the payload's deaths, a whitelisted key", payload.get("deaths", -1) == rounds.stats.deaths and preload("res://scripts/ai/guide_request.gd").build(payload, "", 0).stats.has("deaths") and preload("res://scripts/round/round_announcer.gd").scripted_line({"shots": 9, "deaths": 4}, true).contains("Derezzed 4 times"))
	await _drop(main)


func _volume_checks() -> void:
	var main := await _lab({"DummyA": Vector3(0.0, 0.0, 9.0)}, Vector3(15.0, 0.95, -15.0), "normal", true)
	var rogue: Node3D = _dummy(main, "DummyA")
	await _frames(30)
	var box := rogue.get_node_or_null("BodyBox") as CollisionShape3D
	var art: DaemonArt = rogue.brain.art
	var space := rogue.get_world_3d().direct_space_state
	# A point on its abdomen, 1 m behind the body's centre: past the cylinder, inside what is seen.
	var tail: Vector3 = art.global_transform * (art.body_box() * Vector3(0.0, 0.1, 0.9))
	var from := tail + Vector3(6.0, 0.0, 0.0)
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, tail + Vector3(-0.2, 0.0, 0.0), 4))
	var axis := Vector2(tail.x - rogue.global_position.x, tail.z - rogue.global_position.z).length()
	var turned := box != null and absf(box.global_transform.basis.z.normalized().dot((art.global_transform.basis * art.body_box().basis).z.normalized()) - 1.0) < 0.01
	_check("acceptance: rogue.d's hit volume is fair to what is seen: a shot at its abdomen %.2f m off its middle (past the 0.55 m cylinder) hits it, through the box round its body that turns with it" % axis, box != null and not box.disabled and axis > 0.6 and not hit.is_empty() and hit["collider"] == rogue and turned)
	rogue.hit(1000.0)
	await _frames(2)
	_check("the box is off while it is down, as the cylinder is", box != null and box.disabled and rogue.get_node("Shape").disabled)
	_check("the zombie and the swarm keep the cylinder: what reaches past it is the zombie's ghosts (its past) and the swarm's cloud", _dummy(main, "DummyB").get_node_or_null("BodyBox") == null and _dummy(main, "DummyD").get_node_or_null("BodyBox") == null)
	await _drop(main)


# --- A match. ---

func _match_checks() -> void:
	GameSettings.current().set_value("gameplay", "practice", false)
	GameSettings.current().set_value("gameplay", "difficulty", "normal")
	var host := _branch("Host", Vector3.ZERO)
	var client := _branch("Client", CLIENT_OFFSET)
	await _frames(2)
	var joined := await _join(host, client)
	var hs = host["session"]
	var cs = client["session"]
	var cid: int = cs.my_id
	var ruled := await _wait(func(): return cs.host_practice == false and cs.host_difficulty == "normal", 120)
	_check("acceptance: protocol 10, and the host's rule reaches the joiner: its daemons fight, at normal", joined and Session.PROTOCOL == 10 and ruled >= 0)
	# The host's own player far off behind the lair's walls; the joiner on open floor; the host's
	# rogue and one zombie near the joiner, the others parked.
	host["player"].global_position = host["main"].to_global(Vector3(15.0, 0.95, -15.0))
	client["player"].global_position = client["main"].to_global(OPEN)
	for name in ["DummyB", "DummyD"]:
		_park(_dummy(host["main"], name))
	_place(_dummy(host["main"], "DummyA"), host["main"].to_global(Vector3(0.0, 0.0, 12.0)))
	_place(_dummy(host["main"], "DummyC"), host["main"].to_global(Vector3(5.0, 0.0, 8.0)))
	var hd: DaemonDirector = host["main"].get_node("DaemonDirector")
	var cd: DaemonDirector = client["main"].get_node("DaemonDirector")
	var host_rogue: Node3D = _dummy(host["main"], "DummyA")
	var copy: Node3D = _dummy(client["main"], "DummyA")
	var copy_told := false
	var copy_near := INF
	var drawn := 0
	var drawn_judging := false
	var flashed := false
	var hurt := -1
	for i in 900:
		await physics_frame
		if host_rogue.brain.state == DaemonBrain.State.TELL and host_rogue.brain.state_t > 0.2:
			copy_told = copy_told or (copy.brain.state == DaemonBrain.State.TELL and copy.brain.art.act == DaemonArt.Act.TELL)
			copy_near = minf(copy_near, client["main"].to_local(copy.global_position).distance_to(host["main"].to_local(host_rogue.global_position)))
		drawn = maxi(drawn, cd.bolts_live())
		for bolt in cd.bolts():
			drawn_judging = drawn_judging or (bolt.live and bolt.deciding)
		flashed = flashed or client["combat_hud"].flash_left() > 0.0
		if hurt < 0 and hs.combat.health_of(cid) < 100.0:
			hurt = i
		if hurt >= 0 and copy_told and drawn > 0 and i > hurt + 30:
			break
	await _frames(6)
	_check("acceptance: multiplayer: the host runs the daemons: its rogue and zombie hunt the joiner's avatar and the damage is judged in the host's combat (health %.0f), the same on the joiner's screen, with the joiner's own flash" % hs.combat.health_of(cid), hurt >= 0 and cs.health.get(cid, -1.0) == hs.combat.health_of(cid) and flashed and cd.mode == DaemonDirector.Mode.FOLLOW and hd.mode == DaemonDirector.Mode.RUN)
	_check("acceptance: joiners only draw: the joiner's copy of the rogue tells when the host's does, where the host's is (within %.2f m), and the host's bolts are drawn there (%d at once), none of them judging" % [copy_near, drawn], copy_told and copy_near < 0.75 and drawn >= 1 and not drawn_judging)
	# A host's bolt meeting the joiner's avatar lands on the joiner: its hit volume is on the targets
	# layer, met before its middle.
	var zombie_brain: DaemonBrain = _dummy(host["main"], "DummyC").brain
	var avatar_at: Vector3 = hs.avatars[cid].global_position
	hs.combat.states[cid]["health"] = 100.0
	var throw_from := avatar_at + Vector3(6.0, 0.3, 0.0)
	zombie_brain.prey = cid
	var hit_bolt := hd.throw_bolt(zombie_brain, throw_from, (avatar_at - throw_from).normalized())
	await _wait(func(): return not hit_bolt.live, 120)
	await _frames(6)
	_check("acceptance: a host's bolt that meets the joiner's avatar lands on the joiner (%s, player %d), judged in the host's combat and shown on the joiner's screen (%.0f)" % [hit_bolt.ended, hit_bolt.met, cs.health.get(cid, -1.0)], hit_bolt.ended == "player" and hit_bolt.met == cid and hs.combat.health_of(cid) <= 100.0 - _t.zombie_bolt_damage + EPS and cs.health.get(cid, -1.0) == hs.combat.health_of(cid))
	var copy_health: float = copy.health()
	var local: bool = copy.hit(0.4, copy.global_position + Vector3.UP * 0.9, Vector3.FORWARD)
	_check("acceptance: the joiner's copy of a daemon takes nothing from the joiner's own shots: the host judges every shot at it", not local and copy.is_alive() and copy.health() == copy_health)
	_aim(client["player"], copy.global_position + Vector3.UP * 0.9)
	var shot := await _shoot(client["player"], host, client)
	var down := await _wait(func(): return not host_rogue.is_alive(), 60)
	var followed := await _wait(func(): return not copy.is_alive(), 60)
	_check("acceptance: a joiner's shot at the host's daemon lands through the host: the cannon's hit derezzes the host's rogue, and the joiner's copy goes down on the host's word", shot and down >= 0 and followed >= 0, "shot %s down %d followed %d" % [shot, down, followed])
	# A daemon's kill names the daemon on the joiner's banner and in the feed.
	hs.combat.states[cid]["health"] = 1.0
	_place(_dummy(host["main"], "DummyA"), host["main"].to_global(Vector3(0.0, 0.0, 12.0)))
	if not host_rogue.is_alive():
		host_rogue.reset_for_round()
	var killed := await _wait(func(): return cs.dead.get(cid, false), 900)
	await _frames(2)
	var banner: String = client["combat_hud"].banner_text()
	var feed: String = " / ".join(client["combat_hud"].feed_text())
	_check("acceptance: a daemon's kill is the match's death: the joiner derezzed, its banner and the feed name the daemon (%s | %s), no kill credited to anyone" % [banner.replace("\n", " "), feed], killed >= 0 and (banner.contains("by rogue.d") or banner.contains("by <defunct>")) and feed.contains("derezzed by a daemon") and hs.combat.states[1]["kills"] == 0 and hs.combat.states[cid]["kills"] == 0)
	# The host turns practice on: every player's dummies are its own old ones again.
	GameSettings.current().set_value("gameplay", "practice", true)
	var rested := await _wait(func(): return cs.host_practice and cd.mode == DaemonDirector.Mode.REST and hd.mode == DaemonDirector.Mode.REST, 120)
	await _frames(4)
	var own := _dummy(client["main"], "DummyB")
	_check("acceptance: the host's practice: the joiner hears it, every director rests, and a joiner's shot derezzes its own dummy locally again, as since C14", rested >= 0 and own.hit(1000.0) and not own.is_alive())
	GameSettings.current().set_value("gameplay", "practice", false)
	await _drop_side(client)
	await _drop_side(host)


# --- Helpers. ---

## A fresh arena with the daemons in `keep` (name -> world place) and every other parked under the
## floor, the player at `player_at`, at `difficulty`, practice `practice`.
func _lab(keep: Dictionary, player_at: Vector3, difficulty: String = "normal", practice: bool = false) -> Node:
	GameSettings.current().set_value("gameplay", "practice", practice)
	GameSettings.current().set_value("gameplay", "difficulty", difficulty)
	var link := Link.new()
	link.settings_path = _tmp.path_join("arena-privacy.cfg")
	link.demo = true
	Link.park(link)
	var main = MainScene.instantiate()
	root.add_child(main)
	_arenas.append(main)
	main.get_node("Hud").guide().focus_check = func(): return false
	var player = main.get_node("Player")
	player.assume_captured = true
	player.global_position = player_at
	player.velocity = Vector3.ZERO
	for dummy in main.get_node("Arena/Targets").get_children():
		if keep.has(String(dummy.name)):
			_place(dummy, keep[String(dummy.name)])
		else:
			_park(dummy)
	await _frames(2)
	return main


func _drop(main: Node) -> void:
	if is_instance_valid(main):
		for sfx in main.find_children("*", "AudioStreamPlayer", true, false):
			(sfx as AudioStreamPlayer).stop()
		main.free()
	_arenas.erase(main)
	var left = Link.take_parked()
	if left != null:
		left.shut_down(null)
	Engine.time_scale = 1.0
	await process_frame


func _dummy(main: Node, name: String) -> Node3D:
	return main.get_node("Arena/Targets/" + name)


## A daemon put at `at` (world space), facing as the scene had it, at home there.
func _place(dummy: Node3D, at: Vector3) -> void:
	dummy.global_position = at
	dummy.global_rotation = Vector3.ZERO
	dummy.brain.take_home()
	dummy.brain.moved = false
	dummy.brain.state = DaemonBrain.State.HOME
	dummy.brain.prey = 0


func _park(dummy: Node3D) -> void:
	_place(dummy, PARKED + Vector3(dummy.get_index() * 3.0, 0.0, 0.0))


func _aim_daemon(dummy: Node3D, at: Vector3) -> void:
	var way := at - dummy.global_position
	dummy.global_rotation = Vector3(0.0, atan2(-way.x, -way.z), 0.0)


## Index of `brain`'s first event `word`, or -1.
func _first(brain: DaemonBrain, word: String) -> int:
	for i in brain.events.size():
		if brain.events[i][1] == word:
			return i
	return -1


## True when the event at `index` (an attack, or what followed it) comes after a tell of its own:
## the latest tell, attack or abort before it is a tell at least the tell's length earlier.
func _told_before(brain: DaemonBrain, index: int) -> bool:
	var at := index
	while at >= 0 and brain.events[at][1] != "attack":
		at -= 1
	if at < 0:
		return false
	for i in range(at - 1, -1, -1):
		var word: String = brain.events[i][1]
		if word == "tell":
			return brain.events[at][0] - brain.events[i][0] >= brain._tell_s(DaemonDirector.of(brain.dummy)) - 1.5 * FRAME
		if word == "attack" or word == "abort":
			return false
	return false


func _events(brain: DaemonBrain) -> String:
	return ", ".join(brain.events.slice(-8).map(func(e): return "%.2f %s" % [e[0], e[1]]))


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


## Frames until `condition` holds, or -1 after `most`.
func _wait(condition: Callable, most: int) -> int:
	for i in most:
		if condition.call():
			return i
		await physics_frame
	return most if condition.call() else -1


func _net_tuning() -> Resource:
	var t := NetTuningScript.new()
	t.bind_address = "127.0.0.1"
	t.connect_timeout_ms = 1500
	t.peer_timeout_ms = 2000
	return t


## A side of the game in its own branch: {branch, session, main, player, hud, combat_hud}.
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
	branch.add_child(session)
	_branches.append(branch)
	var main = MainScene.instantiate()
	branch.add_child(main)
	var out := {"branch": branch, "session": session, "main": main, "player": main.get_node("Player"), "hud": main.get_node("Hud"), "combat_hud": main.get_node("Hud").combat_hud()}
	out["player"].assume_captured = true
	main.get_node("Hud").guide().focus_check = func(): return false
	return out


func _drop_side(side: Dictionary) -> void:
	var branch: Node = side["branch"]
	if is_instance_valid(branch):
		for sfx in branch.find_children("*", "AudioStreamPlayer", true, false):
			(sfx as AudioStreamPlayer).stop()
		side["session"].leave()
		branch.free()
	_branches.erase(branch)
	await process_frame


func _join(host: Dictionary, client: Dictionary) -> bool:
	host["session"].host(0)
	await _frames(2)
	client["session"].join("127.0.0.1:%d" % host["session"].listen_port())
	var t0 := Time.get_ticks_msec()
	while not (client["session"].state == Session.State.JOINED and host["session"].players.size() == 2 and client["session"].players.size() == 2 and client["session"].get("_weapons_synced") == true):
		if Time.get_ticks_msec() - t0 > WATCHDOG_MS:
			return false
		await physics_frame
	await _frames(10)
	return true


func _aim(player: Node, target: Vector3) -> void:
	var cam: Node3D = player.get_node("Head/Camera")
	var to: Vector3 = target - cam.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	player.get_node("Head").rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


## Fires once and waits for the host's word on it to reach the joiner.
func _shoot(player: Node, host: Dictionary, client: Dictionary) -> bool:
	var before: int = host["session"].combat.states.values().reduce(func(acc, s): return acc + s["last_seq"], 0)
	var seen: Array = [0]
	var hook := func(_s: int, _h: int, _o: Vector3, _e: Vector3) -> void:
		seen[0] += 1
	client["session"].shot_confirmed.connect(hook)
	player.drive_input(Vector2.ZERO, false, false, true)
	await physics_frame
	var t0 := Time.get_ticks_msec()
	while seen[0] < 1 and Time.get_ticks_msec() - t0 < 3000:
		await physics_frame
	client["session"].shot_confirmed.disconnect(hook)
	await _frames(1)
	return seen[0] >= 1 and host["session"].combat.states.values().reduce(func(acc, s): return acc + s["last_seq"], 0) > before


func _cleanup() -> void:
	Engine.time_scale = 1.0
	for node in _arenas.duplicate():
		await _drop(node)
	for branch in _branches.duplicate():
		if is_instance_valid(branch):
			branch.free()
	GameSettings.current().reset()
	Controls.apply_binds({})
	await process_frame
	OS.delay_msec(300)
	await process_frame


## A script's code without its comments or the text of its strings.
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
		out.append(line.left(cut))
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
