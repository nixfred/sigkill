extends SceneTree
## Headless test of the relay carrying every protocol since 10 (P2). scripts/check.sh runs it as step 74, and any FAIL
## exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/relay_match_test.gd
##
## The relay (relay/relay_server.gd) runs in this process on 127.0.0.1 only, on a port the system hands out, pumped every
## frame; nothing is deployed and nothing leaves the machine. Two halves:
## - The wire: a room registered at each protocol from 10 to 19, the game's own (scripts/net/net_session.gd PROTOCOL), is
##   resolved by a joiner on the same protocol and refused, with the host's protocol named, to one a protocol off: the
##   relay carries any of them and never mixes two.
## - A full room at protocol 19: a host and three joiners (the relay's room of four, its worst case: the shipped game's
##   matches are two players), each in its own branch of this process, every datagram through the relay, with the daemons fighting back (protocol 10) and ICE on (12 to 14). Every
##   player draws every one of the thirteen weapons in turn, both banks, and fires it (chmod 000, pipe |, /dev/null and
##   SIGHUP among them: 15 to 18), each wearing a look (19). Then: everyone is still in the room and still sees the others
##   move; each joiner has the host's rules, ICE words, breaker words and every player's look, and its daemons stand where
##   the host's do; and the relay dropped nothing (no datagram over its payload cap, none past its packet rate, none
##   malformed), its biggest datagram and a room's packets a second inside its caps, measured on the game's own clock.
## Demo data only; nothing outside 127.0.0.1 is touched.

const Session = preload("res://scripts/net/net_session.gd")
const NetTuningScript = preload("res://scripts/net/net_tuning.gd")
const CombatTuningScript = preload("res://scripts/net/combat_tuning.gd")
const RoomCode = preload("res://scripts/net/room_code.gd")
const UdpRendezvous = preload("res://scripts/net/udp_rendezvous.gd")
const RelayServer = preload("res://relay/relay_server.gd")
const Link = preload("res://scripts/guide/guide_link.gd")
const Controls = preload("res://scripts/controls.gd")
const MainScene = preload("res://scenes/main.tscn")
const LOCALHOST := "127.0.0.1"
const WATCHDOG_MS := 20000
const STAND_Y := 0.95
## The protocols carried: every one since the daemons started fighting back (C27b's 10) to the game's own.
const FIRST_PROTOCOL := 10
## Frames each weapon is fired for, by every player at once.
const FIRE_FRAMES := 45
## A branch's world, this far from the last, so the four arenas never meet.
const SPACING := Vector3(1000.0, 0.0, 0.0)
## The relay's room size by default, filled: the most traffic a room carries. The shipped game's matches are two players;
## four is the relay's worst case.
const ROOM_PLAYERS := 4


## Pumps the relay every frame on the real clock, as relay/relay_main.gd does.
class Pump extends Node:
	var server = null

	func _process(_delta: float) -> void:
		if server != null:
			server.poll(Time.get_ticks_msec() / 1000.0)


var _fails := 0
var _checks := 0
var _tmp := ""
var _branches: Array = []
var _server = null
var _pump: Pump = null


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	Controls.ensure()
	_tmp = ProjectSettings.globalize_path("user://relay-match-test-%d" % OS.get_process_id())
	if DirAccess.dir_exists_absolute(_tmp):
		print("FAIL the test's own folder already exists; not touching it")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_tmp)
	var config := RelayServer.config_from({}, PackedStringArray(["--bind", LOCALHOST, "--port", str(_free_port()), "--stats-s", "0", "--register-per-min", "100", "--resolve-per-min", "1000", "--rooms-per-ip", "64"]))
	if config.has("error"):
		_check("the in-process relay's settings parse", false, config["error"])
	else:
		_server = RelayServer.new(config)
		var started: String = _server.start()
		_check("the relay is up in this process, bound to 127.0.0.1 only, on a port the system handed out", started == "" and config["bind"] == LOCALHOST, started)
		_pump = Pump.new()
		_pump.server = _server
		root.add_child(_pump)
		await _wire_checks(config)
		await _match_checks(config)
	await _cleanup()
	print("RELAY MATCH: %d checks" % _checks)
	print("RELAY MATCH RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The wire: a room at every protocol from 10 to 19. ---

func _wire_checks(config: Dictionary) -> void:
	var url := "udp://%s:%d" % [LOCALHOST, int(config["port"])]
	var carried := PackedStringArray()
	var mixed := PackedStringArray()
	for protocol in range(FIRST_PROTOCOL, Session.PROTOCOL + 1):
		var host := UdpRendezvous.new(url)
		var code := RoomCode.generate()
		host.register(code, protocol, 9009)
		var made := await _answer(host)
		var same := UdpRendezvous.new(url)
		same.resolve(code, protocol)
		var found := await _answer(same)
		var off := UdpRendezvous.new(url)
		off.resolve(code, protocol + 1 if protocol < Session.PROTOCOL else protocol - 1)
		var refused := await _answer(off)
		if bool(made.get("ok", false)) and bool(found.get("ok", false)) and int(found.get("host_protocol", -1)) == protocol:
			carried.append(str(protocol))
		if bool(refused.get("ok", true)) or int(refused.get("host_protocol", -1)) != protocol:
			mixed.append("%d (%s)" % [protocol, str(refused)])
		host.close(code, protocol, 9009)
		for r in [host, same, off]:
			r.shut()
	_check("acceptance: the relay carries a room of every protocol from %d to %d: each registered and resolved by a joiner on its own protocol (%s)" % [FIRST_PROTOCOL, Session.PROTOCOL, ", ".join(carried)], carried.size() == Session.PROTOCOL - FIRST_PROTOCOL + 1)
	_check("and never mixes two: a joiner one protocol off is refused every time, told the host's protocol", mixed.is_empty(), ", ".join(mixed))


func _answer(r) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var out := {}
	while out.is_empty() and Time.get_ticks_msec() - t0 < 5000:
		out = r.poll()
		await process_frame
	return out


# --- A full room at protocol 19, every datagram through the relay. ---

func _match_checks(config: Dictionary) -> void:
	var settings := GameSettings.current()
	settings.set_value("multiplayer", "relay_url", "udp://%s:%d" % [LOCALHOST, int(config["port"])])
	settings.set_value("gameplay", "practice", false)  # the daemons fight back (protocol 10)
	settings.set_value("gameplay", "difficulty", "normal")
	settings.set_value("gameplay", "ice", true)  # ICE on (protocols 12 to 14)
	var sides: Array = []
	for i in 4:
		sides.append(_branch("Player%d" % (i + 1), SPACING * i))
	await _frames(3)
	var hs: Session = sides[0]["session"]
	hs.host(0)
	var coded := await _until(func(): return hs.room_code != "", 8000)
	var code := hs.room_code
	_check("the host registers a room with the relay at protocol %d" % Session.PROTOCOL, coded and RoomCode.problem(code) == "", code)
	for i in range(1, 4):
		var cs: Session = sides[i]["session"]
		cs.join_room(code)
		await _until(func(): return cs.state == Session.State.JOINED, 8000)
	var full := await _until(func(): return hs.players.size() == 4 and sides.slice(1).all(func(s): return s["session"].state == Session.State.JOINED and s["session"].players.size() == 4), 12000)
	_check("acceptance: a full room through the relay: the host and three joiners, everyone seeing four players", full, "host sees %d; joiners %s" % [hs.players.size(), str(sides.slice(1).map(func(s): return "%s %s" % [s["session"].state_word(), s["session"].error]))])
	var enet: ENetMultiplayerPeer = hs.get("_enet")
	var through := 0
	var ports: PackedInt32Array = hs.get("_relay_host").get("ports", PackedInt32Array())
	for i in range(1, 4):
		var cid: int = sides[i]["session"].my_id
		if enet != null and enet.get_peer(cid) != null and ports.has(enet.get_peer(cid).get_remote_port()):
			through += 1
	_check("every joiner reaches the host only through the relay: the host sees each one as a relay slot port (%d of 3)" % through, through == 3)
	await _until(func(): return sides.slice(1).all(func(s): return s["session"].ice_words > 0), 8000)
	# The run: every player draws each of the thirteen weapons in turn and fires it, all at once.
	var before: Dictionary = _server.counters.duplicate()
	var frames := 0
	var slots: int = sides[0]["player"].inventory.slot_count()
	for slot in slots:
		for s in sides:
			s["player"].select_slot(slot)
		frames += await _hold(sides, 25, false)
		frames += await _hold(sides, FIRE_FRAMES, true)
	frames += await _hold(sides, 60, false)
	var after: Dictionary = _server.counters
	# What every joiner has of the host's word.
	var rules_ok := true
	var ice_ok := true
	var breaker_ok := true
	var looks_ok := true
	var staying := true
	for i in range(1, 4):
		var cs: Session = sides[i]["session"]
		rules_ok = rules_ok and not cs.host_practice and cs.host_ice
		ice_ok = ice_ok and cs.ice_words > 0
		breaker_ok = breaker_ok and cs.breaker_words > 0
		looks_ok = looks_ok and cs.looks.size() == 4
		staying = staying and cs.state == Session.State.JOINED and cs.players.size() == 4
	staying = staying and hs.players.size() == 4
	_check("acceptance: after every weapon from every player, everyone is still in the room (four on every screen)", staying)
	_check("each joiner has the host's rules: the daemons fight back (protocol 10) and ICE is on (12)", rules_ok)
	_check("each joiner keeps taking the host's ICE words (12) and breaker words (13) through the relay", ice_ok and breaker_ok, "ice %s breaker %s" % [str(sides.slice(1).map(func(s): return s["session"].ice_words)), str(sides.slice(1).map(func(s): return s["session"].breaker_words))])
	_check("each joiner knows every player's look as the host accepted it (protocol 19): four looks each", looks_ok, str(sides.slice(1).map(func(s): return s["session"].looks.size())))
	var near := _daemons_follow(sides)
	_check("each joiner's daemons stand where the host's do (the host's daemon word, protocol 10): %s" % near, near.begins_with("ok"), near)
	var missed := await _moves_seen(sides)
	_check("and the room still carries movement both ways after it all: every joiner sees the host move, the host sees every joiner", missed == "", missed)
	var relayed: int = int(after["relayed_packets"]) - int(before["relayed_packets"])
	var game_s := frames / 60.0
	var pps := relayed / maxf(game_s, 0.001)
	var drops := PackedStringArray()
	for name in ["dropped_bad", "dropped_oversize", "dropped_rate", "dropped_full"]:
		if int(after[name]) - int(before[name]) > 0:
			drops.append("%s %d" % [name, int(after[name]) - int(before[name])])
	_check("acceptance: the relay dropped nothing of it: no datagram over its payload cap, none past a room's packet rate, none malformed, none for a full room (%d relayed in %.1f s of game time)" % [relayed, game_s], drops.is_empty() and relayed > 0, ", ".join(drops))
	_check("the biggest datagram it carried, %d bytes, is inside its payload cap of %d" % [int(after["largest_payload"]), int(config["max_payload"])], int(after["largest_payload"]) > 0 and int(after["largest_payload"]) <= int(config["max_payload"]))
	_check("a full room's traffic, %.0f datagrams a second on the game's own clock (%d at the relay's busiest real second), is inside its rate of %d a room" % [pps, int(after["room_pps_peak"]), int(config["room_pps"])], pps <= float(config["room_pps"]) and int(after["room_pps_peak"]) <= int(config["room_pps"]))
	print("RELAY MATCH numbers: %d datagrams in %.1f s of game time, %.0f a second; biggest %d bytes; busiest real second %d; caps %d bytes, %d a second" % [relayed, game_s, pps, int(after["largest_payload"]), int(after["room_pps_peak"]), int(config["max_payload"]), int(config["room_pps"])])
	for i in range(3, -1, -1):
		_drop(sides[i])
	await _frames(3)


## Every player holds still for `n` frames, firing or not, aimed at the floor ahead; the frames waited.
func _hold(sides: Array, n: int, fire: bool) -> int:
	for f in n:
		for s in sides:
			if is_instance_valid(s["player"]):
				s["player"].drive_input(Vector2.ZERO, false, false, fire)
		await physics_frame
	return n


## "ok ..." when each joiner's daemons stand within 1.5 m of the host's (each in its own world, by its branch's offset).
func _daemons_follow(sides: Array) -> String:
	var host_spots := _daemon_spots(sides[0])
	if host_spots.is_empty():
		return "the host has no daemons"
	var worst := 0.0
	for i in range(1, 4):
		var spots := _daemon_spots(sides[i])
		if spots.size() != host_spots.size():
			return "joiner %d has %d daemons, the host %d" % [i, spots.size(), host_spots.size()]
		for k in spots.size():
			worst = maxf(worst, (spots[k] as Vector3).distance_to(host_spots[k]))
	return ("ok, %d daemons, the farthest %.2f m off" if worst < 1.5 else "%d daemons, one %.2f m off") % [host_spots.size(), worst]


func _daemon_spots(side: Dictionary) -> Array:
	var out: Array = []
	var origin: Vector3 = (side["branch"] as Node3D).global_position
	var names: Array = []
	for d in side["main"].find_children("*", "", true, false):
		if d.is_in_group("targets") and d.has_method("is_alive") and d.is_alive() and d is Node3D:
			names.append(d)
	names.sort_custom(func(a, b): return str(a.get_path()) < str(b.get_path()))
	for d in names:
		out.append((d as Node3D).global_position - origin)
	return out


## "" when every joiner sees the host move to a spot and the host sees every joiner move to one; else what was missed.
func _moves_seen(sides: Array) -> String:
	var hs: Session = sides[0]["session"]
	# Everyone alive and out of spawn protection first: the run's daemons and four players' fire can leave someone down.
	var ids := [1]
	for i in range(1, 4):
		ids.append(sides[i]["session"].my_id)
	await _until(func(): return ids.all(func(id): return not hs.dead.get(id, false) and hs.protect_left.get(id, 0.0) <= 0.0), 12000)
	var missed := PackedStringArray()
	var spot := Vector3(-8.0, STAND_Y, 15.0)
	sides[0]["player"].respawn_at(sides[0]["main"].to_global(spot))
	for i in range(1, 4):
		var cs: Session = sides[i]["session"]
		var ok := await _until(func(): return cs.avatars.has(1) and cs.avatars[1].latest_position().distance_to(spot) < 0.3, 6000)
		if not ok:
			missed.append("joiner %d sees the host %.2f m off" % [i, cs.avatars[1].latest_position().distance_to(spot) if cs.avatars.has(1) else -1.0])
	for i in range(1, 4):
		var cs: Session = sides[i]["session"]
		var cspot := Vector3(-15.0, STAND_Y, 15.0 + (i - 2) * 3.0)
		sides[i]["player"].respawn_at(sides[i]["main"].to_global(cspot))
		var ok := await _until(func(): return hs.avatars.has(cs.my_id) and hs.avatars[cs.my_id].latest_position().distance_to(cspot) < 0.3, 6000)
		if not ok:
			missed.append("the host sees joiner %d %.2f m off (alive %s)" % [i, hs.avatars[cs.my_id].latest_position().distance_to(cspot) if hs.avatars.has(cs.my_id) else -1.0, not hs.dead.get(cs.my_id, false)])
	return ", ".join(missed)


# --- Helpers (as tests/relay_test.gd's). ---

func _free_port() -> int:
	var probe := PacketPeerUDP.new()
	probe.bind(0, LOCALHOST)
	var port := probe.get_local_port()
	probe.close()
	return port


func _branch(name: String, offset: Vector3) -> Dictionary:
	var api := SceneMultiplayer.new()
	var branch := Node3D.new()
	branch.name = name
	branch.position = offset
	root.add_child(branch)
	set_multiplayer(api, branch.get_path())
	var session := Session.new()
	session.name = Session.NODE_NAME
	var tuning := NetTuningScript.new()
	tuning.bind_address = LOCALHOST
	tuning.connect_timeout_ms = 8000
	tuning.peer_timeout_ms = 8000
	tuning.max_players = ROOM_PLAYERS  # the relay's room, full: a shipped match is two (resources/net.tres)
	session.tuning = tuning
	session.combat_tuning = load("res://resources/combat.tres")
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
	hud.pause_menu().focus_check = func(): return false
	var out := {"branch": branch, "session": session, "main": main, "player": main.get_node("Player"), "hud": hud}
	out["player"].assume_captured = true
	return out


func _drop(side: Dictionary) -> void:
	var branch: Node = side["branch"]
	if is_instance_valid(branch):
		for sfx in branch.find_children("*", "AudioStreamPlayer", true, false):
			(sfx as AudioStreamPlayer).stop()
		side["session"].leave()
		branch.free()
	_branches.erase(branch)
	var left = Link.take_parked()
	if left != null:
		left.shut_down(null)


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


func _cleanup() -> void:
	for b in _branches.duplicate():
		if is_instance_valid(b):
			b.free()
	_branches.clear()
	if _pump != null and is_instance_valid(_pump):
		_pump.free()
	if _server != null:
		_server.stop()
	var settings := GameSettings.current()
	settings.set_value("multiplayer", "relay_url", "")
	settings.reset()
	_wipe(_tmp)
	_check("the test's own folder is gone, nothing of it left under user://", not DirAccess.dir_exists_absolute(_tmp))


func _wipe(path: String) -> void:
	if not path.begins_with(ProjectSettings.globalize_path("user://relay-match-test-")):
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.include_hidden = true
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := path.path_join(name)
		if dir.current_is_dir() and not dir.is_link(name):
			_wipe(full)
		else:
			DirAccess.remove_absolute(full)
		name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)
