extends SceneTree
## Headless root vs user and sudo overcharge test for SIGKILL (C22). scripts/check.sh runs it,
## and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/root_sudo_test.gd
##
## Root vs user (PRD 5.3) and sudo overcharge (PRD 5.2): the resource and its numbers, bad
## values refused; the rules on their own; Z as a rebindable action, saved to a settings file
## in a temporary folder and loaded back, Ctrl+Alt refused; scans that nothing real is run or
## read, that only the host applies the harder hits, and that no other ability's or weapon's
## numbers moved. Then solo in the real arena with the real player: a life starts as user; Z
## with no charge does nothing; the third dummy down earns exactly one charge and a fourth no
## second; Z then shows the password line and root# for the tuned time and back to user$;
## while root a real dummy takes 1.5 times the cannon's hit, SIGTERM and the fork bomb spend
## nothing (an empty magazine still fires), the ult meter fills no faster, and the weapons
## glow red; after it, all as before; a death drops the charge and ends root, a respawn ends
## root. Then a host and joiners over ENet on 127.0.0.1: a joiner on the protocol before (6 at
## C22, 7 since C23's top table) is refused with
## the version line; the joiner's forged ask with no charge is refused and counted; three real
## kills of the host credit the joiner a charge on both screens; its Z starts root on the
## host's word, both screens show it, and the host's judging makes its shot 1.5 times harder;
## a death ends it and drops the charge; leaving the match ends it. No orphan nodes.
## Deterministic: no random numbers drawn for what is checked, every time counted in physics
## frames, nothing waits a frame count for the network.

const Session = preload("res://scripts/net/net_session.gd")
const Combat = preload("res://scripts/net/combat.gd")
const NetTuningScript = preload("res://scripts/net/net_tuning.gd")
const CombatTuningScript = preload("res://scripts/net/combat_tuning.gd")
const Sudo = preload("res://scripts/abilities/sudo_overcharge.gd")
const SudoState = preload("res://scripts/abilities/sudo_state.gd")
const SudoTuningScript = preload("res://scripts/abilities/sudo_overcharge_tuning.gd")
const SudoBadge = preload("res://scripts/hud/sudo_badge.gd")
const Controls = preload("res://scripts/controls.gd")
const Palette = preload("res://scripts/palette.gd")
const Link = preload("res://scripts/guide/guide_link.gd")
const MainScene = preload("res://scenes/main.tscn")
const TUNING_PATH := "res://resources/sudo_overcharge.tres"
const WATCHDOG_MS := 10000
const CLIENT_OFFSET := Vector3(1000.0, 0.0, 0.0)
const OLD_OFFSET := Vector3(2000.0, 0.0, 0.0)
const STAND_Y := 0.95
const LINE_Z := 15.0
const EPS := 0.0001

var _fails := 0
var _checks := 0
var _tmp := ""
var _t: Resource
var _arenas: Array = []
var _branches: Array = []


func _initialize() -> void:
	GameSettings.current().set_value("gameplay", "practice", true)  # these checks predate C27b: the daemons stay the old never-attack dummies
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_tmp = OS.get_temp_dir().path_join("sigkill-root-sudo-test-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(_tmp)
	Controls.ensure()
	_t = load(TUNING_PATH)
	_tuning_checks()
	_rule_checks()
	_rebind_checks()
	_source_checks()
	await _solo_checks()
	await _match_checks()
	await _cleanup()
	for name in DirAccess.get_files_at(_tmp):
		DirAccess.remove_absolute(_tmp.path_join(name))
	DirAccess.remove_absolute(_tmp)
	print("ROOT SUDO: %d checks" % _checks)
	print("ROOT SUDO RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The resource, the rules, the action, the source. ---

func _tuning_checks() -> void:
	var t = _t
	_check("every number is one resource, resources/sudo_overcharge.tres, a SudoOverchargeTuning that passes its own checks", t is SudoTuningScript and t.problems().is_empty(), str(t.problems()) if t is SudoTuningScript else "")
	_check("its numbers: 3 kills in one life earn a sudo charge, 1 held at most, 8 s of root at 1.5 times the damage, the password line for 1.2 s, the weapon's glow doubled", t.kills_needed == 3 and t.max_charges == 1 and t.root_s == 8.0 and t.damage_scale == 1.5 and t.password_s == 1.2 and t.glow_scale == 2.0)
	var cases := [
		["kills_needed", 0, "kills_needed"], ["max_charges", 0, "max_charges"], ["max_charges", 9, "max_charges"], ["root_s", 0.5, "root_s"],
		["damage_scale", 0.5, "damage_scale"], ["damage_scale", NAN, "damage_scale"], ["password_s", 9.0, "password_s"], ["glow_scale", 0.5, "glow_scale"],
	]
	var missed := PackedStringArray()
	for c in cases:
		var bad = _t.duplicate()
		bad.set(c[0], c[1])
		if not ", ".join(bad.problems()).contains(c[2]):
			missed.append("%s=%s: %s" % [c[0], c[1], bad.problems()])
	_check("bad values are refused with the reason: no kills, no or too many charges, too short a root, a scale under 1 or NaN, a password line past root, a dimmer glow", missed.is_empty(), " | ".join(missed))


func _rule_checks() -> void:
	var s := SudoState.new(_t)
	var fresh := s.streak == 0 and s.charges == 0 and not s.is_root() and s.damage_scale() == 1.0
	var first := s.kill()
	var second := s.kill()
	var third := s.kill()
	var after_third := s.charges
	var more := [s.kill(), s.kill(), s.kill(), s.kill()]
	_check("acceptance: the rules alone: a life starts as user; the 3rd kill in one life earns exactly one charge, and four more kills do not stack a second", fresh and not first and not second and third and after_third == 1 and more == [false, false, false, false] and s.charges == 1 and s.streak == 0)
	s.die()
	var dropped := s.charges == 0 and s.streak == 0 and not s.is_root()
	s.kill()
	s.kill()
	s.die()
	var reset := not s.kill() and s.streak == 1
	_check("acceptance: a death drops the charge and resets the streak: two kills, a death, and the next kill counts as the first", dropped and reset)
	var none := SudoState.new(_t)
	var refused := not none.activate() and not none.is_root()
	none.charges = 1
	var started := none.activate()
	var during := [none.is_root(), none.charges, none.damage_scale(), none.root_left]
	var mid := none.tick(7.9)
	var still := none.is_root()
	var ended := none.tick(0.1)
	_check("acceptance: with no charge a start does nothing; with one, root for 8 s at 1.5 times (the charge spent), still root at 7.9 s, user at 8.0 s and the scale back to 1", refused and started and during == [true, 0, 1.5, 8.0] and not mid and still and ended and not none.is_root() and none.damage_scale() == 1.0, str(during))
	var r := SudoState.new(_t)
	r.charges = 1
	r.activate()
	var kills_in_root := [r.kill(), r.kill(), r.kill()]
	var ended_by_respawn := r.end_root()
	_check("kills while root count toward the next charge (the third earns it), and a respawn ends root but keeps the charges", kills_in_root == [false, false, true] and ended_by_respawn and not r.is_root() and r.charges == 1)


func _rebind_checks() -> void:
	var events := InputMap.action_get_events("sudo_overcharge")
	_check("Z is sudo: a rebindable action shown as \"sudo\" in the settings' list, Z by default, clashing with nothing", Controls.rebindable("sudo_overcharge") and Controls.default_bind("sudo_overcharge") == "key:%d" % KEY_Z and _shown("sudo_overcharge") == "sudo" and not Controls.conflicts({}).has("sudo_overcharge") and events.size() == 1 and (events[0] as InputEventKey).physical_keycode == KEY_Z)
	var path := _tmp.path_join("rebind-settings.cfg")
	var s := GameSettings.new()
	s.path = path
	var u := InputEventKey.new()
	u.physical_keycode = KEY_U
	var took := s.set_bind("sudo_overcharge", u)
	var saved := s.save()
	var back := GameSettings.new()
	back.path = path
	var how := back.load_file()
	Controls.apply_binds(back.binds())
	var moved := InputMap.action_get_events("sudo_overcharge")
	var chord := InputEventKey.new()
	chord.physical_keycode = KEY_Z
	chord.ctrl_pressed = true
	chord.alt_pressed = true
	var refused := back.set_bind("sudo_overcharge", chord)
	back.reset_binds()
	Controls.apply_binds(back.binds())
	var reset := InputMap.action_get_events("sudo_overcharge")
	_check("acceptance: rebindable: moved to U it is saved, read back and taken by the input map, clashing with nothing; Ctrl+Alt+Z is refused; reset, it is Z again", took == "" and saved and how == "loaded" and moved.size() == 1 and (moved[0] as InputEventKey).physical_keycode == KEY_U and not Controls.conflicts(back.binds()).has("sudo_overcharge") and refused == Controls.CTRL_ALT_REFUSED and reset.size() == 1 and (reset[0] as InputEventKey).physical_keycode == KEY_Z, "%s %s %s" % [took, how, refused])


func _source_checks() -> void:
	var mine := _code("res://scripts/abilities/sudo_overcharge.gd") + _code("res://scripts/abilities/sudo_state.gd") + _code("res://scripts/abilities/sudo_overcharge_tuning.gd") + _code("res://scripts/hud/sudo_badge.gd")
	var found := PackedStringArray()
	for word in ["OS.", "FileAccess", "DirAccess", "Thread", "HTTP", "PacketPeer", "StreamPeer", "Engine.time_scale", "rpc"]:
		if mine.contains(word):
			found.append(word)
	_check("fiction only: the sudo code runs, calls, reads and opens nothing real (no OS call at all: no command, no environment, no user name), and sends nothing itself; \"user\" is a fixed word", found.is_empty() and FileAccess.get_file_as_string("res://scripts/hud/sudo_badge.gd").contains('const PASSWORD := "[sudo] password for user: ********"'), ", ".join(found))
	var session := _code("res://scripts/net/net_session.gd")
	_check("the wire: protocol 7 (8 since C23's top table, 9 since C25's grep marks, 10 since C27b's daemons, 11 since A5's daemon seeds); the ask an untyped, type-checked any-peer RPC; each player's sudo state an authority RPC from the host; 19 RPCs in all (20 since C23, 24 since C27b)", Session.PROTOCOL == 11 and session.count("@rpc(") == 24 and session.contains('@rpc("any_peer", "call_remote", "reliable")\nfunc _sudo(life: Variant) -> void:') and _body(session, "_sudo").contains("typeof(life) != TYPE_INT") and session.contains('@rpc("authority", "call_remote", "reliable")\nfunc _sudo_state(id: int, life: int, charges: int, left: float) -> void:'))
	var fire := _body(session, "_handle_fire")
	var blast := _body(session, "_judge_blast")
	_check("acceptance: only the host applies root's harder hits: in _handle_fire and _judge_blast (and _judge_pellet for fork()'s pellets since C24, _judge_slug_blast for the rm -rf blast since C26, and since C27b on the host's daemons: a joiner's pellet in _judge_pellet and every blast in _blast_daemons, which runs only hosting a match whose daemons fight), after their hosting checks; a joiner's shot and death messages only take the host's numbers", _body(session, "_blast_daemons").find("if not daemons_fight()") >= 0 and _body(session, "_blast_daemons").find("if not daemons_fight()") < _body(session, "_blast_daemons").find("combat.damage_scale(shooter)") and _body(session, "daemons_fight").contains("state == State.HOSTING") and fire.find("if state != State.HOSTING or combat == null") < fire.find("combat.damage_scale(shooter)") and blast.find("if state != State.HOSTING or combat == null") < blast.find("combat.damage_scale(thrower)") and _body(session, "_judge_pellet").find("if state != State.HOSTING or combat == null") < _body(session, "_judge_pellet").find("combat.damage_scale(shooter)") and _body(session, "_judge_slug_blast").find("if state != State.HOSTING or combat == null") < _body(session, "_judge_slug_blast").find("combat.damage_scale(shooter)") and session.count("combat.damage_scale(") == 7 and not _body(session, "_apply_shot").contains("damage_scale") and not _body(session, "_shot").contains("scale"))
	var stop = load("res://resources/sigstop.tres")
	var vision = load("res://resources/code_rain_vision.tres")
	var cannon = load("res://resources/terminal_cannon.tres")
	var sigterm = load("res://resources/sigterm.tres")
	var bomb = load("res://resources/fork_bomb.tres")
	_check("acceptance: no other ability's or weapon's numbers moved: SIGSTOP 4 s, 20 s, 25%; code-rain vision 3 s, 12 s, 1 s, 25%, 40 m; the cannon 25 a hit, SIGTERM 14 a pellet, the fork bomb 22 a blast", stop.meter_s == 4.0 and stop.refill_s == 20.0 and stop.start_share == 0.25 and vision.meter_s == 3.0 and vision.refill_s == 12.0 and vision.rest_s == 1.0 and vision.start_share == 0.25 and vision.range_m == 40.0 and cannon.damage == 25.0 and sigterm.damage == 14.0 and bomb.damage == 22.0)


# --- Solo. ---

func _solo_checks() -> void:
	var arena := await _arena()
	var main: Node = arena["main"]
	var p: Node = arena["player"]
	var hud = arena["hud"]
	var badge: SudoBadge = hud.sudo_badge()
	var sudo = p.get("sudo")
	var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var grants := [0]
	var ends := [0]
	sudo.granted.connect(func(): grants[0] += 1)
	sudo.ended.connect(func(): ends[0] += 1)
	var dummies: Array = []
	for name in ["DummyA", "DummyB", "DummyC", "DummyD"]:
		dummies.append(main.get_node("Arena/Targets/" + name))
	p.respawn_at(main.to_global(Vector3(-12.0, STAND_Y, LINE_Z)))
	_face(p, Vector3(1.0, 0.0, 0.0))
	await _frames(5)
	_check("acceptance: a life starts as user: the node lives under the player beside SIGSTOP and code-rain vision, no streak, no charge, and the badge reads \"user$\" in mint", sudo is Sudo and p.get_node_or_null("Sigstop") != null and p.get_node_or_null("CodeRainVision") != null and sudo.charges() == 0 and not sudo.is_root() and badge.prompt_text() == "user$" and badge.detail_text() == "" and badge.prompt_color() == Palette.MINT)
	sudo.press()
	await _frames(3)
	_check("acceptance: Z with no charge does nothing: still user", not sudo.is_root() and badge.prompt_text() == "user$")
	# Three daemons down earn a charge; a fourth no second.
	for i in 2:
		_kill_dummy(dummies[i])
	await _frames(2)
	var after_two: int = sudo.charges()
	_kill_dummy(dummies[2])
	await _frames(2)
	var after_three: int = sudo.charges()
	var ready_line := badge.detail_text()
	_kill_dummy(dummies[3])
	await _frames(2)
	_check("acceptance: the third daemon down in one life earns exactly one charge (none after two), the badge says \"sudo ready: Z\", and a fourth earns no second", after_two == 0 and after_three == 1 and ready_line == "sudo ready: Z" and sudo.charges() == 1 and grants[0] == 1, "%d %d %s" % [after_two, after_three, ready_line])
	# Root.
	sudo.press()
	await physics_frame
	var password := badge.prompt_text()
	var red := badge.prompt_color()
	await _frames(int(_t.password_s * 60.0) + 1)
	var prompt := badge.prompt_text()
	var left_line := badge.detail_text()
	_check("acceptance: Z with the charge spends it on root: the cosmetic \"[sudo] password for user: ********\" first, in root's red, then \"root#\" with its seconds left", sudo.is_root() and sudo.charges() == 0 and password == "[sudo] password for user: ********" and red == Palette.HOSTILE_RED and prompt == "root#" and left_line == "7s", "%s | %s %s" % [password, prompt, left_line])
	_check("the weapons wear root's red: every viewmodel glows in it", p.shows_root() and _viewmodel_color(p, 0) == Palette.HOSTILE_RED)
	# 1.5 times the cannon's hit on a real dummy, and the meter's share at user's strength.
	var target: Node = dummies[0]
	await _until(func(): return target.is_alive(), 8000)
	_place(main, target, -4.0, LINE_Z)
	target.max_health = 100.0  # a partial hit, so the meter's share is the hit's own
	target.reset_for_round()
	_aim(p, main.to_global(Vector3(-4.0, 0.9, LINE_Z)))
	await _frames(3)
	var inv = p.get("inventory")
	var meter_before: float = inv.meter
	var health_before: float = target.health()
	await _fire(p)
	var root_hit: float = health_before - target.health()
	var root_meter: float = inv.meter - meter_before
	var cannon_hit: float = p.weapon_tuning().damage_at(p.eye_position().distance_to(main.to_global(Vector3(-4.0, 0.9, LINE_Z))))
	# SIGTERM: drawn, fired, and fired again from an empty magazine: nothing spent.
	p.select_slot(1)
	await _settle(p, 0.5)
	var mag_before: int = inv.mags[1]
	await _fire(p)
	await _settle(p, 1.0)
	var mag_after: int = inv.mags[1]
	inv.mags[1] = 0
	var shots: int = p.shots_fired
	await _fire(p)
	var empty_fired: bool = p.shots_fired == shots + 1 and inv.mags[1] == 0
	p.select_slot(0)
	await _settle(p, 0.5)
	var bombs_before: int = inv.mags[3]
	inv.cooldowns[3] = 0.0
	var thrown: bool = p.quick_throw()
	var bombs_after: int = inv.mags[3]
	_check("acceptance: while root, damage is 1.5 times: the cannon takes %.1f off a dummy where its hit is %.1f" % [root_hit, cannon_hit], absf(root_hit - cannon_hit * 1.5) < EPS, "%.3f vs %.3f" % [root_hit, cannon_hit * 1.5])
	_check("acceptance: while root, ammo does not drop: SIGTERM fires and keeps its %d shells, fires from an empty magazine, and a fork bomb throws without spending one" % mag_before, mag_before == mag_after and empty_fired and thrown and bombs_before == bombs_after, "%d -> %d, empty %s, bombs %d -> %d" % [mag_before, mag_after, empty_fired, bombs_before, bombs_after])
	# Back to user at the tuned time.
	var frames_left := ceili(sudo.root_left() * 60.0 - 0.001)
	var ended_at := -1
	for i in frames_left + 5:
		await physics_frame
		if ended_at < 0 and not sudo.is_root():
			ended_at = i + 1
	_check("acceptance: root lasts the tuned 8 s and then it is user again: it ends on the frame due (%d), the badge \"user$\" in mint, the weapons back in their own colours" % frames_left, absi(ended_at - frames_left) <= 1 and badge.prompt_text() == "user$" and badge.prompt_color() == Palette.MINT and not p.shows_root() and _viewmodel_color(p, 0) == p.get("inventory").defs[0].skin_body() and ends[0] == 1, "ended at %d" % ended_at)
	# After it: user's hits and ammo again, and the meter's share the same as root's.
	await _until(func(): return target.is_alive(), 8000)
	target.reset_for_round()
	_aim(p, main.to_global(Vector3(-4.0, 0.9, LINE_Z)))
	await _settle(p, 0.6)
	meter_before = inv.meter
	health_before = target.health()
	await _fire(p)
	var user_hit: float = health_before - target.health()
	var user_meter: float = inv.meter - meter_before
	p.select_slot(1)
	await _settle(p, 0.5)
	inv.mags[1] = 3
	await _fire(p)
	var spent: bool = inv.mags[1] == 2
	p.select_slot(0)
	await _settle(p, 0.5)
	_check("after root, both are normal: the cannon's hit is its own %.1f, SIGTERM spends a shell again" % user_hit, absf(user_hit - cannon_hit) < EPS and spent, "%.3f, spent %s" % [user_hit, spent])
	_check("acceptance: root fills the ult meter no faster: its 1.5-times hit added exactly the share a user's hit adds (%.4f and %.4f)" % [root_meter, user_meter], user_meter > 0.0 and absf(root_meter - user_meter) < EPS)
	# A death and a respawn.
	sudo.state.charges = 1
	sudo.press()
	await _frames(3)
	var root_then: bool = sudo.is_root()
	p.set_alive(false)
	var dead_user: bool = not sudo.is_root() and sudo.charges() == 0
	p.set_alive(true)
	await physics_frame
	sudo.state.charges = 1
	sudo.state.streak = 2
	p.set_alive(false)
	var dropped: bool = sudo.charges() == 0 and sudo.state.streak == 0
	p.set_alive(true)
	await physics_frame
	_check("acceptance: a death ends root and drops the unused charge and the streak: back as user", root_then and dead_user and dropped and badge.prompt_text() == "user$")
	sudo.state.charges = 1
	sudo.press()
	await _frames(3)
	var root_again: bool = sudo.is_root()
	p.respawn_at(main.to_global(Vector3(-12.0, STAND_Y, LINE_Z)))
	_check("acceptance: a respawn ends root too", root_again and not sudo.is_root())
	_drop(arena)
	await _frames(3)
	var orphans_after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_check("solo: no orphan node left behind", orphans_after <= orphans, "%d before, %d after" % [orphans, orphans_after])


# --- A match. ---

func _match_checks() -> void:
	var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var host := _branch("Host", Vector3.ZERO)
	host["session"].host(0)
	await _frames(2)
	# A joiner of the last protocol is refused with the clear version line.
	var old := _branch("Old", OLD_OFFSET, 7)
	var os: Session = old["session"]
	os.join("127.0.0.1:%d" % host["session"].listen_port())
	var refused := await _until(func(): return os.state == Session.State.FAILED, 6000)
	_check("acceptance: protocol 7 (8 since C23, 9 since C25, 10 since C27b, 11 since A5): a joiner still on the protocol before is refused with the clear version line", Session.PROTOCOL == 11 and refused and os.error == "version mismatch: host 11, you 7", os.error)
	_drop(old)
	await _frames(2)
	var client := _branch("Client", CLIENT_OFFSET)
	var hs: Session = host["session"]
	var cs: Session = client["session"]
	cs.join("127.0.0.1:%d" % hs.listen_port())
	var joined := await _until(func(): return cs.state == Session.State.JOINED and hs.players.size() == 2 and cs.players.size() == 2)
	var hp: Node = host["player"]
	var cp: Node = client["player"]
	var cid: int = cs.my_id
	await _until(func(): return hs.avatars.has(cid) and cs.avatars.has(1) and hs.combat.has_player(cid) and cs.get("_weapons_synced"), 6000)
	await _until(func(): return hs.protect_left.get(1, 0.0) <= 0.0 and hs.protect_left.get(cid, 0.0) <= 0.0, 6000)
	var csudo = cp.get("sudo")
	var hbadge: SudoBadge = host["hud"].sudo_badge()
	var cbadge: SudoBadge = client["hud"].sudo_badge()
	# No charge: Z sends nothing; a forged ask is refused and counted.
	var drops_before: int = hs.combat.drops.get(Combat.DROP_SUDO, 0)
	csudo.press()
	await _frames(5)
	var pressed_nothing: bool = hs.combat.drops.get(Combat.DROP_SUDO, 0) == drops_before and not hs.combat.root(cid)
	cs.rpc_id(1, "_sudo", cs.lives.get(cid, 0))
	var counted := await _until(func(): return hs.combat.drops.get(Combat.DROP_SUDO, 0) == drops_before + 1, 4000)
	await _frames(5)
	_check("acceptance: a joiner cannot start root without the host's grant: its Z with no charge sends nothing, and its forged ask is refused and counted (\"sudo\"); root on neither screen", joined and pressed_nothing and counted and not hs.combat.root(cid) and not csudo.is_root() and cbadge.prompt_text() == "user$")
	# Three real kills of the host by the joiner's cannon earn the joiner a charge.
	var kills := 0
	for k in 3:
		if await _joiner_kills_host(host, client, cid):
			kills += 1
	var granted := await _until(func(): return csudo.charges() == 1, 4000)
	_check("acceptance: in a match the host grants it: three kills of the host by the joiner's real cannon credit the joiner one charge in the host's count and on its own screen (\"sudo ready: Z\")", kills == 3 and granted and hs.combat.sudo_charges(cid) == 1 and hs.combat.states[cid]["kills"] == 3 and cbadge.detail_text() == "sudo ready: Z", "%d kills, host %d, joiner %d" % [kills, hs.combat.sudo_charges(cid), csudo.charges()])
	# The joiner's Z: root on the host's word, seen on both screens.
	await _until(func(): return not hs.dead.get(1, false) and hs.protect_left.get(1, 0.0) <= 0.0, 8000)
	csudo.press()
	var both := await _until(func(): return hs.combat.root(cid) and csudo.is_root() and hs.avatars[cid].root and cs.root_left.get(cid, 0.0) > 0.0, 4000)
	await _frames(int(_t.password_s * 60.0) + 2)
	_check("acceptance: its Z starts root on the host's word, and both screens see it: the host counts it root, the joiner's badge reads \"root#\", and on the host's screen its avatar glows red with \"root#\" on its tag", both and cbadge.prompt_text() == "root#" and hs.avatars[cid].root and String(hs.avatars[cid].get_node("Tag").text).contains("root#") and hbadge.prompt_text() == "user$")
	# The host judges it: the joiner's shot 1.5 times harder on the host.
	_place(host, Vector3(-8.0, STAND_Y, LINE_Z), Vector3(-1.0, 0.0, 0.0))
	_place(client, Vector3(-12.0, STAND_Y, LINE_Z), Vector3(1.0, 0.0, 0.0))
	await _frames(10)
	_aim(cp, client["main"].to_global(Vector3(-8.0, 0.9, LINE_Z)))
	await _settle(cp, 0.3)
	await _until(_heard.bind(hs, cid, client), 4000)
	hs.combat.states[1]["health"] = 100.0
	hs.call("_mirror_from_combat")
	var shots_before: Array = hs.combat.ammo_of(cid, "terminal_cannon")
	await _fire(cp)
	var hit := await _until(func(): return hs.combat.health_of(1) < 100.0, 4000)
	var taken: float = 100.0 - hs.combat.health_of(1)
	var cannon: Resource = load("res://resources/terminal_cannon.tres")
	_check("acceptance: the host judges it: the root joiner's cannon shot takes %.1f off the host (1.5 times its %.0f), and the joiner's screen shows the host's number; the joiner's own game never applies the scale in a match" % [taken, cannon.damage], hit and absf(taken - cannon.damage * 1.5) < EPS and cp.call("_damage_scale") == 1.0 and await _until(func(): return absf(cs.health.get(1, 100.0) - hs.combat.health_of(1)) < EPS, 4000) and hs.combat.ammo_of(cid, "terminal_cannon") == shots_before, "%.3f" % taken)
	# A death ends it.
	var died := await _host_kills_joiner(host, client, cid)
	var ended := await _until(func(): return not hs.combat.root(cid) and not csudo.is_root() and not hs.avatars[cid].root, 4000)
	_check("acceptance: a death ends root on both screens and drops the charge: the joiner back as user", died and ended and hs.combat.sudo_charges(cid) == 0 and csudo.charges() == 0)
	# Leaving the match ends it.
	await _until(func(): return not hs.dead.get(cid, false) and not cs.dead.get(cid, false), 6000)
	hs.combat.states[cid]["sudo"].charges = 1  # a grant in the host's own count, told at its next tick
	hs.combat.set("_sudo_changed", {cid: true})
	await _until(func(): return csudo.charges() == 1, 4000)
	csudo.press()
	var again := await _until(func(): return csudo.is_root(), 4000)
	cs.leave()
	await physics_frame
	_check("acceptance: leaving the match ends it: root on the host's word, then off the moment the joiner leaves, a fresh user", again and not csudo.is_root() and csudo.charges() == 0 and cbadge.prompt_text() == "user$")
	_drop(host)
	_drop(client)
	await _frames(4)
	var orphans_after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_check("acceptance: no orphan nodes are left behind by any of it", orphans_after <= orphans, "%d before, %d after" % [orphans, orphans_after])


## The joiner's real cannon kills the host, its health set to 1 first. True when the host died.
func _joiner_kills_host(host: Dictionary, client: Dictionary, cid: int) -> bool:
	var hs: Session = host["session"]
	var cp: Node = client["player"]
	await _until(func(): return not hs.dead.get(1, false) and hs.protect_left.get(1, 0.0) <= 0.0 and not hs.dead.get(cid, false), 8000)
	_place(host, Vector3(-8.0, STAND_Y, LINE_Z), Vector3(-1.0, 0.0, 0.0))
	_place(client, Vector3(-12.0, STAND_Y, LINE_Z), Vector3(1.0, 0.0, 0.0))
	await _frames(10)
	_aim(cp, client["main"].to_global(Vector3(-8.0, 0.9, LINE_Z)))
	await _settle(cp, 0.3)
	await _until(_heard.bind(hs, cid, client), 4000)
	hs.combat.states[1]["health"] = 1.0
	hs.call("_mirror_from_combat")
	await _fire(cp)
	return await _until(func(): return hs.dead.get(1, false), 4000)


## The host's real cannon kills the joiner, its health set to 1 first. True when it died on
## both screens.
func _host_kills_joiner(host: Dictionary, client: Dictionary, cid: int) -> bool:
	var hs: Session = host["session"]
	var cs: Session = client["session"]
	var hp: Node = host["player"]
	_aim(hp, host["main"].to_global(Vector3(-12.0, 0.9, LINE_Z)))
	await _settle(hp, 0.5)
	hs.combat.states[cid]["health"] = 1.0
	hs.call("_mirror_from_combat")
	await _fire(hp)
	return await _until(func(): return hs.dead.get(cid, false) and cs.dead.get(cid, false), 4000)


# --- Helpers. ---

func _kill_dummy(dummy: Node) -> void:
	dummy.hit(100000.0, dummy.global_position + Vector3.UP, Vector3.FORWARD)


func _viewmodel_color(p: Node, slot: int) -> Color:
	var models: Array = p.get("_viewmodels")
	var glow := models[slot].material_override as StandardMaterial3D
	return glow.emission if glow != null else Color.BLACK


func _shown(action: String) -> String:
	for pair in Controls.REBINDABLE:
		if pair[0] == action:
			return pair[1]
	return ""


func _place_dummy(main: Node, dummy: Node, x: float, z: float) -> void:
	dummy.global_position = main.to_global(Vector3(x, 0.0, z))


func _place(side_or_main, at_or_dummy, facing_or_x, z: float = INF) -> void:
	if side_or_main is Dictionary:
		var p: Node = side_or_main["player"]
		p.respawn_at(side_or_main["main"].to_global(at_or_dummy))
		_face(p, facing_or_x)
	else:
		_place_dummy(side_or_main, at_or_dummy, facing_or_x, z)


func _face(p: Node, facing: Vector3) -> void:
	p.rotation.y = atan2(-facing.x, -facing.z)
	p.get_node("Head").rotation.x = 0.0


func _aim(player: Node, target: Vector3) -> void:
	var cam: Node3D = player.get_node("Head/Camera")
	var to: Vector3 = target - cam.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	player.get_node("Head").rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


func _fire(p: Node) -> void:
	p.drive_input(Vector2.ZERO, false, false, true)
	await physics_frame


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
