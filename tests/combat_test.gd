extends SceneTree
## Headless synced-combat test for SIGKILL (C14). scripts/check.sh runs it, and any FAIL
## exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/combat_test.gd
##
## The same harness as the net test: a host and a joiner in this one process, each in its
## own branch of the tree with its own SceneMultiplayer, its own NetSession and its own real
## arena, over ENet on 127.0.0.1 on ports the system hands out, the joiner's arena 1000 m
## away. Shots are real: the real player's cannon, the host's real raycast. Short respawn
## and protection times come from a test combat tuning.

const Session = preload("res://scripts/net/net_session.gd")
const Combat = preload("res://scripts/net/combat.gd")
const CombatTuningScript = preload("res://scripts/net/combat_tuning.gd")
const NetTuningScript = preload("res://scripts/net/net_tuning.gd")
const RemotePlayer = preload("res://scripts/net/remote_player.gd")
const CombatHud = preload("res://scripts/net/combat_hud.gd")
const DerezzFx = preload("res://scripts/derezz_fx.gd")
const Controls = preload("res://scripts/controls.gd")
const MainScene = preload("res://scenes/main.tscn")
const WATCHDOG_MS := 10000
const CLIENT_OFFSET := Vector3(1000.0, 0.0, 0.0)
const COMBAT_SOURCES := ["res://scripts/net/combat.gd", "res://scripts/net/combat_hud.gd", "res://scripts/net/combat_tuning.gd"]
const SOURCE_NEVER := ["OS.execute", "OS.create_process", "OS.kill", "OS.shell_open", "OS.get_environment", "OS.get_user", "OS.get_name", "execute_with_pipe", "StreamPeerTCP", "TCPServer", "HTTPRequest", "HTTPClient", "UDPServer", "PacketPeerUDP", "ENetMultiplayerPeer", "FileAccess", "DirAccess", "JSON", "var_to_bytes", "bytes_to_var", "RichTextLabel", "bbcode"]
## Frames between two shots from the real cannon: the 0.16 s cooldown at 60 Hz, and one more.
const SHOT_FRAMES := 11

var _fails := 0
var _checks := 0
var _branches: Array = []
var _spawns: Array = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	Controls.ensure()
	_tuning_checks()
	_source_checks()
	_rule_checks()
	await _solo_checks()
	await _match_checks()
	await _forgery_checks()
	await _late_join_checks()
	await _leave_checks()
	await _layout_checks()
	await _cleanup()
	print("COMBAT: %d checks" % _checks)
	print("COMBAT RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


func _net_tuning() -> Resource:
	var t := NetTuningScript.new()
	t.bind_address = "127.0.0.1"
	t.connect_timeout_ms = 1500
	t.peer_timeout_ms = 2000
	return t


func _combat_tuning() -> Resource:
	var t := CombatTuningScript.new()
	t.respawn_delay_s = 1.0
	t.spawn_protection_s = 0.5
	t.kill_feed_fade_s = 2.0
	return t


## A side of the game in its own branch: {branch, session, main, player, hud, combat_hud}.
## With `arena` false only the session is made (a joiner with nothing to show).
func _branch(name: String, offset: Vector3, arena: bool = true, max_players: int = 2, display_name: String = "player") -> Dictionary:
	var api := SceneMultiplayer.new()
	var branch := Node3D.new()
	branch.name = name
	branch.position = offset
	root.add_child(branch)
	set_multiplayer(api, branch.get_path())
	var session := Session.new()
	session.name = Session.NODE_NAME
	var net := _net_tuning()
	net.max_players = max_players
	net.display_name = display_name
	session.tuning = net
	session.combat_tuning = _combat_tuning()
	branch.add_child(session)
	_branches.append(branch)
	if not arena:
		return {"branch": branch, "session": session}
	var main = MainScene.instantiate()
	branch.add_child(main)
	var out := {"branch": branch, "session": session, "main": main, "player": main.get_node("Player"), "hud": main.get_node("Hud"), "combat_hud": main.get_node("Hud").combat_hud()}
	out["player"].assume_captured = true
	out["player"].get("_rng").seed = 7
	main.get_node("Hud").guide().focus_check = func(): return false
	return out


func _drop(side: Dictionary) -> void:
	var branch: Node = side["branch"]
	if is_instance_valid(branch):
		for sfx in branch.find_children("*", "AudioStreamPlayer", true, false):
			(sfx as AudioStreamPlayer).stop()
		side["session"].leave()
		branch.free()
	_branches.erase(branch)
	await process_frame


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


func _join(host: Dictionary, client: Dictionary) -> bool:
	host["session"].host(0)
	await _frames(2)
	client["session"].join("127.0.0.1:%d" % host["session"].listen_port())
	return await _until(func(): return client["session"].state == Session.State.JOINED and host["session"].players.size() == 2 and client["session"].players.size() == 2)


func _avatar(side: Dictionary, id: int) -> RemotePlayer:
	return side["session"].avatars.get(id)


## Points `player`'s body and head at a world-space point.
func _aim(player: Node, target: Vector3) -> void:
	var cam: Node3D = player.get_node("Head/Camera")
	var to: Vector3 = target - cam.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	player.get_node("Head").rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


func _fire(player: Node) -> void:
	player.drive_input(Vector2.ZERO, false, false, true)
	await physics_frame


## Fires once and waits for the host's word on it to reach both sides.
func _shoot(player: Node, host: Dictionary, client: Dictionary) -> bool:
	var before: int = host["session"].combat.states.values().reduce(func(acc, s): return acc + s["last_seq"], 0)
	var seen: Array = [0]
	var hook := func(_s: int, _h: int, _o: Vector3, _e: Vector3) -> void:
		seen[0] += 1
	client["session"].shot_confirmed.connect(hook)
	await _fire(player)
	var ok := await _until(func(): return seen[0] >= 1, 3000)
	client["session"].shot_confirmed.disconnect(hook)
	await _frames(1)
	return ok and host["session"].combat.states.values().reduce(func(acc, s): return acc + s["last_seq"], 0) > before


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
		return ""
	var end := source.find("\nfunc ", at + 1)
	return source.substr(at, (end if end > 0 else source.length()) - at)


func _derezz_count(side: Dictionary) -> int:
	var n := 0
	for node in side["main"].find_children("*", "MultiMeshInstance3D", true, false):
		if node.get_script() == DerezzFx:
			n += 1
	return n


func _tuning_checks() -> void:
	var shipped = load("res://resources/combat.tres")
	_check("the shipped combat tuning is valid: 100 health, a 3 s respawn, 2 s of protection, 25% rate tolerance, 1.5 m origin tolerance, 4 kills shown for 6 s", shipped is CombatTuningScript and shipped.problems().is_empty() and shipped.max_health == 100.0 and shipped.respawn_delay_s == 3.0 and shipped.spawn_protection_s == 2.0 and shipped.fire_rate_tolerance == 0.25 and shipped.origin_tolerance_m == 1.5 and shipped.kill_feed_length == 4 and shipped.kill_feed_fade_s == 6.0, str(shipped.problems()) if shipped is CombatTuningScript else "")
	var weapon = load("res://resources/terminal_cannon.tres")
	_check("the one weapon's damage is 25 of 100 health: four hits derezz a player, and a dummy's single point of health still goes in one", weapon.damage == 25.0 and weapon.fire_cooldown == 0.16)
	var bad := CombatTuningScript.new()
	bad.max_health = 0.0
	bad.respawn_delay_s = NAN
	bad.fire_rate_tolerance = 2.0
	bad.origin_tolerance_m = 0.0
	bad.kill_feed_length = 0
	var issues: PackedStringArray = bad.problems()
	_check("bad tuning is refused and the shipped one used: no health, a NaN respawn, a 200% tolerance, no origin room, an empty feed", issues.size() == 5 and Session.usable_combat_tuning(bad) == shipped, ", ".join(issues))


func _source_checks() -> void:
	var all := ""
	for path in COMBAT_SOURCES:
		all += _code(path)
	var found := PackedStringArray()
	for word in SOURCE_NEVER:
		if all.contains(word):
			found.append(word)
	_check("the combat module starts no program, reads no file, asks the system nothing, opens no socket of its own and parses no rich text", found.is_empty(), ", ".join(found))
	var session := _code("res://scripts/net/net_session.gd")
	var handle := _body(session, "_handle_fire")
	_check("damage is applied in one place, the host's _handle_fire, after validate() and the host's own raycast; joiners never call it", session.count("damage_player(") == 1 and handle.contains("combat.validate(shooter, seq, origin, dir, eye, _clock) != \"\"") and handle.contains("_raycast(shooter, origin, dir)") and handle.contains("combat.damage_player(hit, shooter)") and handle.begins_with("\nfunc _handle_fire") and handle.contains("if state != State.HOSTING or combat == null"))
	_check("the host's own shot takes the same path as a joiner's: _on_fire_intent hands it to _handle_fire, a joiner's intent arrives through the any_peer _fire RPC into _handle_fire", _body(session, "_on_fire_intent").contains("_handle_fire(1, fire_seq, local_origin, local_dir)") and _body(session, "_fire").contains("_handle_fire(multiplayer.get_remote_sender_id(), seq, origin, dir)") and session.count("_handle_fire(") == 3)
	_check("results go out only from the host: _shot, _death and _respawn are authority RPCs; _fire, untyped and type-checked, is the only any_peer one besides _state", session.contains('@rpc("any_peer", "call_remote", "reliable")\nfunc _fire(seq: Variant, origin: Variant, dir: Variant)') and _body(session, "_fire").contains("typeof(seq) != TYPE_INT or typeof(origin) != TYPE_VECTOR3 or typeof(dir) != TYPE_VECTOR3") and session.contains('@rpc("authority", "call_remote", "reliable")\nfunc _shot(') and session.contains('@rpc("authority", "call_remote", "reliable")\nfunc _death(') and session.contains('@rpc("authority", "call_remote", "reliable")\nfunc _respawn(') and session.count('"any_peer"') == 2)
	var hud := _code("res://scripts/net/combat_hud.gd")
	_check("the HUD shows only confirmed results: the hit marker and the flash come from shot_confirmed, the feed from player_died, never from the local cannon", hud.contains("s.shot_confirmed.connect(_on_shot)") and hud.contains("s.player_died.connect(_on_death)") and not hud.contains("shot_fired") and hud.count("confirm_hit()") == 1)
	var names := _code("res://scripts/net/net_session.gd")
	_check("default names are Daemon-<slot>, never from the system", names.contains('const DAEMON := "Daemon-"') and Session.assigned_name("player", 2) == "Daemon-2" and Session.assigned_name("", 1) == "Daemon-1" and not all.contains("OS."))


func _rule_checks() -> void:
	var c := Combat.new(_combat_tuning(), 0.16, 25.0)
	c.add_player(1)
	c.add_player(7)
	var eye := Vector3(0, 1.65, 10)
	var dir := Vector3(0, 0, -1)
	var words := PackedStringArray()
	words.append(c.validate(7, 1, eye, dir, eye, 1.0))
	words.append(c.validate(7, 2, eye, dir, eye, 1.05))
	words.append(c.validate(7, 1, eye, dir, eye, 1.5))
	words.append(c.validate(7, 2, eye + Vector3(0, 0, 3), dir, eye, 1.5))
	words.append(c.validate(7, 2, eye, Vector3(NAN, 0, 0), eye, 1.5))
	words.append(c.validate(7, 2, eye, Vector3(0, 0, -50), eye, 1.5))
	words.append(c.validate(7, 2, Vector3(INF, 0, 0), dir, eye, 1.5))
	words.append(c.validate(9, 1, eye, dir, eye, 1.5))
	words.append(c.validate(7, 2, eye, dir, Vector3.INF, 1.5))
	words.append(c.validate(7, 2, eye + Vector3(1.0, 0, 0), dir, eye, 1.5))
	words.append(c.validate(7, 3, eye, dir, eye, 1.61))
	words.append(c.validate(7, 3, eye, dir, eye, 1.63))
	words.append(c.validate(7, 50000, eye, dir, eye, 2.0))
	words.append(c.validate(7, 2147483647, eye, dir, eye, 2.0))
	_check("validate: a first shot passes; 0.05 s later is too fast; a number already believed is refused, a refused one is not burnt; an origin 3 m off, a NaN or 50-long direction, an infinite origin, an unknown shooter and an unseen eye are refused; 1 m off within the 1.5 m tolerance passes; 0.11 s later is too fast and 0.13 s later passes; a number 50000 ahead or at the cap is refused", words == PackedStringArray(["", "rate", "seq", "origin", "shape", "shape", "shape", "no_player", "origin", "", "rate", "", "seq", "seq"]), ", ".join(words))
	_check("drops are counted in all and by reason", c.dropped == 11 and c.drops.get("rate", 0) == 2 and c.drops.get("seq", 0) == 3 and c.drops.get("shape", 0) == 3 and c.drops.get("origin", 0) == 2 and c.drops.get("no_player", 0) == 1, str(c.drops))
	var hits := []
	for i in 4:
		hits.append(c.damage_player(1, 7))
	_check("damage: 100 to 75, 50, 25, 0 and dead on the fourth hit, the killer credited", hits[0] == {"health": 75.0, "killed": false} and hits[2] == {"health": 25.0, "killed": false} and hits[3] == {"health": 0.0, "killed": true} and not c.alive(1) and c.states[7]["kills"] == 1 and c.states[1]["deaths"] == 1 and c.states[1]["respawn_left"] == 1.0)
	_check("a dead player takes no more damage and cannot fire", c.damage_player(1, 7).is_empty() and c.validate(1, 1, eye, dir, eye, 5.0) == "dead")
	var due := []
	for i in 65:
		due.append_array(c.tick(1.0 / 60.0))
	c.respawn(1)
	var shielded: bool = c.alive(1) and c.health_of(1) == 100.0 and c.protected(1) and c.damage_player(1, 7).is_empty()
	for i in 31:
		c.tick(1.0 / 60.0)
	_check("the respawn comes due after the delay; respawning restores full health, alive and protected, and protection blocks damage until it runs out", due == [1] and shielded and not c.protected(1) and c.damage_player(1, 7) == {"health": 75.0, "killed": false}, "due %s shielded %s protected after %s" % [due, shielded, c.protected(1)])
	var spawns := [Vector3(0, 0, 10), Vector3(-15, 0, 15), Vector3(15, 0, -15)]
	_check("the spawn farthest from the nearest threat wins; no threats give the first; no spawns give INF", Combat.farthest_spawn(spawns, [Vector3(0, 0, 10)]) == Vector3(15, 0, -15) and Combat.farthest_spawn(spawns, [Vector3(15, 0, -15), Vector3(0, 0, 10)]) == Vector3(-15, 0, 15) and Combat.farthest_spawn(spawns, []) == Vector3(0, 0, 10) and Combat.farthest_spawn([], [Vector3.ZERO]) == Vector3.INF)
	_check("rules: a unit direction within 1%, an origin within the tolerance, a shot at 75% of the cooldown", Combat.dir_ok(Vector3(0, 0, -1.009)) and not Combat.dir_ok(Vector3(0, 0, -1.02)) and Combat.origin_ok(Vector3(1, 0, 0), Vector3.ZERO, 1.0) and not Combat.origin_ok(Vector3(1.01, 0, 0), Vector3.ZERO, 1.0) and Combat.rate_ok(0.12, 0.0, 0.16, 0.25) and not Combat.rate_ok(0.119, 0.0, 0.16, 0.25))


## Solo: no session online, the combat HUD shows nothing and the cannon works as before.
func _solo_checks() -> void:
	var side := _branch("Solo", Vector3.ZERO)
	await _frames(3)
	var hud: CombatHud = side["combat_hud"]
	var dummy = side["main"].get_node("Arena/Targets/DummyA")
	await _fire(side["player"])
	await _frames(2)
	_check("solo: the combat line, feed, flash and banner stay hidden, and the cannon still derezzes a dummy in one shot", hud.line_text() == "" and hud.feed_text().is_empty() and hud.flash_left() == 0.0 and hud.banner_text() == "" and side["player"].shots_fired == 1 and side["player"].hits_landed == 1 and not dummy.is_hittable() and side["session"].fire_seq == 0)
	var p = side["player"]
	for i in 20:
		p.drive_input(Vector2(0, -1))
		await physics_frame
	var running: float = p.horizontal_speed()
	p.set_alive(false)
	var stopped: float = p.horizontal_speed()
	var at: Vector3 = p.position
	for i in 10:
		p.drive_input(Vector2(0, -1), true, true, true)
		await physics_frame
	var drift: float = Vector2(p.position.x - at.x, p.position.z - at.z).length()
	p.set_alive(true)
	_check("a derezzed body stops where it is: momentum gone at once, and no input moves, jumps, slides or fires it until it is alive again", running > 3.0 and stopped == 0.0 and drift < 0.01 and p.shots_fired == 1 and not p.is_sliding(), "running %.2f stopped %.2f drift %.3f" % [running, stopped, drift])
	await _drop(side)


## The match: shots, health, death, the feed, respawn, protection, the host's own shot.
func _match_checks() -> void:
	var host := _branch("Host", Vector3.ZERO)
	var client := _branch("Client", CLIENT_OFFSET)
	await _frames(2)
	var joined := await _join(host, client)
	var hs: Session = host["session"]
	var cs: Session = client["session"]
	var hp = host["player"]
	var cp = client["player"]
	var hhud: CombatHud = host["combat_hud"]
	var chud: CombatHud = client["combat_hud"]
	var cid: int = cs.my_id
	_check("joined: both sides show full health for both players, alive, with the combat line up", joined and hs.health[1] == 100.0 and hs.health[cid] == 100.0 and cs.health[1] == 100.0 and cs.health[cid] == 100.0 and not cs.dead[1] and hhud.line_text() == "health 100" and chud.line_text() == "health 100")
	# The host walks forward 3.5 m; the joiner, at the spawn behind it, aims at its avatar.
	for i in 30:
		hp.drive_input(Vector2(0, -1))
		await physics_frame
	await _until(func(): return _avatar(client, 1).visible and (_avatar(client, 1).position - hp.position).length() < 0.1)
	await _frames(8)
	var target: RemotePlayer = _avatar(client, 1)
	_aim(cp, target.global_position + Vector3(0, 0.3, 0))
	var first := await _shoot(cp, host, client)
	print("COMBAT first hit: host health %.0f on the host, %.0f on the joiner; host drops %s" % [hs.health[1], cs.health[1], hs.combat.drops])
	_check("a joiner's shot damages the host's player: health drops by the weapon's damage on both sides, the joiner's hit marker shows, the host's screen flashes", first and hs.health[1] == 75.0 and cs.health[1] == 75.0 and hs.combat.states[1]["health"] == 75.0 and client["hud"].hit_marker_alpha() > 0.5 and hhud.flash_left() > 0.0 and host["hud"].hit_marker_alpha() == 0.0 and hs.combat.dropped == 0, "host %.0f joiner %.0f marker %.2f flash %.2f" % [hs.health[1], cs.health[1], client["hud"].hit_marker_alpha(), hhud.flash_left()])
	_check("the avatar's tag carries the health", target.get("_tag").text == "Daemon-1  75")
	for i in 3:
		await _frames(SHOT_FRAMES)
		await _shoot(cp, host, client)
	await _until(func(): return cs.dead.get(1, false) and hs.dead.get(1, false))
	await _frames(2)
	print("COMBAT death: host dead %s/%s, derezz effects in the joiner's arena %d, feed host %s joiner %s" % [hs.dead[1], cs.dead[1], _derezz_count(client), hhud.feed_text(), chud.feed_text()])
	_check("four hits derezz the host: dead on both sides at 0 health, its player takes no input, its avatar on the joiner is hidden and the derezz effect plays there", hs.dead[1] and cs.dead[1] and hs.health[1] == 0.0 and cs.health[1] == 0.0 and not hp.alive and not hp.get("_viewmodel").visible and target.dead and not target.get("_body").visible and _derezz_count(client) == 1)
	_check("the kill feed on both sides names the players in SIGKILL's words", hhud.feed_text() == PackedStringArray(["SIGKILL sent by Daemon-2 to Daemon-1"]) and chud.feed_text() == PackedStringArray(["SIGKILL sent by Daemon-2 to Daemon-1"]) and hhud.line_text().begins_with("DEREZZED by Daemon-2   respawn in") and hhud.banner_text().begins_with("[ DEREZZED by Daemon-2 ]"))
	# A shot through the host's corpse goes on past it: here into the room, to the dummy.
	var ends: Array = []
	var end_hook := func(_s: int, _h: int, _o: Vector3, e: Vector3) -> void:
		ends.append(e)
	cs.shot_confirmed.connect(end_hook)
	await _frames(SHOT_FRAMES)
	_aim(cp, Vector3(1000.0, 1.65, -15.0))
	await _shoot(cp, host, client)
	cs.shot_confirmed.disconnect(end_hook)
	_check("the dead host's body stops no shot: a ray through the corpse ends far beyond it", not ends.is_empty() and ends[-1].z < 0.0 and (ends[-1] - cp.position).length() > 15.0, "end %s" % (ends[-1] if not ends.is_empty() else Vector3.INF))
	# The dead host cannot fire.
	var seq_before: int = hs.combat.states[1]["last_seq"]
	var shots_before: int = hp.shots_fired
	await _fire(hp)
	await _frames(2)
	_check("the dead host's cannon stays silent: no shot fired, no intent handled", hp.shots_fired == shots_before and hs.combat.states[1]["last_seq"] == seq_before and hs.combat.dropped == 0)
	# Respawn after the delay, away from the joiner, protected.
	var respawned := await _until(func(): return not hs.dead.get(1, true) and not cs.dead.get(1, true), 3000)
	await _frames(2)
	var at: Vector3 = hp.position
	var far: float = Vector2(at.x - cp.position.x, at.z - cp.position.z).length()
	print("COMBAT respawn: host at %s, %.1f m from the joiner; protection %.2f s on the host, %.2f on the joiner" % [at, far, hs.protect_left.get(1, 0.0), cs.protect_left.get(1, 0.0)])
	_check("after the delay the host respawns at a spawn point far from the joiner, alive with full health on both sides, protected, the avatar back", respawned and hp.alive and far > 25.0 and ((at - Vector3(15, 0.95, -15)).length() < 0.6 or (at - Vector3(-15, 0.95, -15)).length() < 0.6) and hs.health[1] == 100.0 and cs.health[1] == 100.0 and hs.protect_left[1] > 0.0 and cs.protect_left[1] > 0.0 and target.visible and not target.dead and target.protected and hhud.line_text().begins_with("health 100   spawn protection") and hhud.banner_text() == "", "at %s far %.1f alive %s" % [at, far, hp.alive])
	# A shot during protection does nothing; one after it damages.
	await _until(func(): return target.visible and (target.position - hp.position).length() < 0.6)
	_aim(cp, target.global_position + Vector3(0, 0.3, 0))
	var shielded := await _shoot(cp, host, client)
	_check("during spawn protection a believed shot does no damage and confirms no hit", shielded and hs.health[1] == 100.0 and cs.health[1] == 100.0 and hs.combat.dropped == 0, "health %.0f" % hs.health[1])
	await _until(func(): return hs.protect_left.get(1, 0.0) == 0.0 and cs.protect_left.get(1, 0.0) == 0.0)
	await _frames(SHOT_FRAMES)
	var after := await _shoot(cp, host, client)
	_check("once protection expires the same shot damages again, and the protection cue is gone on both sides", after and hs.health[1] == 75.0 and cs.health[1] == 75.0 and not target.protected and hhud.line_text() == "health 75")
	# The host's own shot goes through the same path.
	hp.respawn_at(Vector3(0, 0.95, 4))
	hp.rotation.y = PI
	await _frames(3)
	var mine: RemotePlayer = _avatar(host, cid)
	await _until(func(): return mine.visible)
	_aim(hp, mine.global_position + Vector3(0, 0.3, 0))
	var host_hit: Array = [0]
	var hook := func(s: int, h: int, _o: Vector3, _e: Vector3) -> void:
		if s == 1 and h == cid:
			host_hit[0] += 1
	cs.shot_confirmed.connect(hook)
	await _fire(hp)
	var landed := await _until(func(): return host_hit[0] >= 1, 3000)
	cs.shot_confirmed.disconnect(hook)
	await _frames(1)
	print("COMBAT host shot: joiner health %.0f on the host, %.0f on the joiner; host validated %d shots of its own" % [hs.health[cid], cs.health[cid], hs.combat.states[1]["last_seq"]])
	_check("the host's own shot is validated and raycast like any other: the joiner's health drops on both sides, the host's hit marker shows, the joiner's screen flashes", landed and hs.health[cid] == 75.0 and cs.health[cid] == 75.0 and hs.combat.states[1]["last_seq"] >= 1 and host["hud"].hit_marker_alpha() > 0.5 and chud.flash_left() > 0.0)
	await _drop(client)
	await _drop(host)


## Forged and too-fast intents from a joiner: dropped, counted, nothing applied.
func _forgery_checks() -> void:
	var host := _branch("Host2", Vector3.ZERO)
	var client := _branch("Client2", CLIENT_OFFSET)
	await _frames(2)
	await _join(host, client)
	var hs: Session = host["session"]
	var cs: Session = client["session"]
	var cp = client["player"]
	var cid: int = cs.my_id
	for i in 20:
		cp.drive_input(Vector2(0, -1))
		await physics_frame
	await _until(func(): return _avatar(host, cid).visible and (_avatar(host, cid).latest_position() - cp.position).length() < 0.1)
	await _frames(8)
	var eye: Vector3 = _avatar(host, cid).latest_position() + Vector3(0, cp.eye_height(), 0)
	var up := Vector3.UP
	# One believed shot straight up first, so the joiner has a number to be ahead of.
	cs._fire.rpc_id(1, 1, eye, up)
	await _until(func(): return hs.combat.states[cid]["last_seq"] == 1, 2000)
	await _frames(10)
	var bad := [
		["an origin 3 m off", 2, eye + Vector3(3, 0, 0), up, "origin"],
		["a NaN direction", 3, eye, Vector3(NAN, 0, 0), "shape"],
		["a direction 50 long", 4, eye, Vector3(0, 50, 0), "shape"],
		["an infinite origin", 5, Vector3(INF, 0, 0), up, "shape"],
		["a shot number far ahead", 100000, eye, up, "seq"],
		["a number already believed", 1, eye, up, "seq"],
	]
	var wrong := PackedStringArray()
	for item in bad:
		var dropped_before: int = hs.combat.dropped
		var health_before: Dictionary = hs.health.duplicate()
		cs._fire.rpc_id(1, item[1], item[2], item[3])
		var counted := await _until(func(): return hs.combat.dropped > dropped_before, 2000)
		if not counted or hs.combat.dropped != dropped_before + 1 or hs.combat.drops.get(item[4], 0) < 1 or hs.health != health_before:
			wrong.append("%s: dropped %d -> %d (%s), health %s" % [item[0], dropped_before, hs.combat.dropped, hs.combat.drops, hs.health])
	print("COMBAT forgeries dropped by reason: ", hs.combat.drops)
	_check("forged intents (an origin 3 m off, a NaN or 50-long direction, an infinite origin, a number far ahead, a number already believed) are each dropped and counted by reason, with no damage and no answer", wrong.is_empty() and hs.combat.drops == {"origin": 1, "shape": 3, "seq": 2}, "; ".join(wrong) + " " + str(hs.combat.drops))
	# Too fast: two believable intents in one frame; the second is refused.
	await _frames(10)
	var dropped_before: int = hs.combat.dropped
	var seq_before: int = hs.combat.states[cid]["last_seq"]
	cs._fire.rpc_id(1, 10, eye, up)
	cs._fire.rpc_id(1, 11, eye, up)
	await _until(func(): return hs.combat.states[cid]["last_seq"] >= 10, 2000)
	await _frames(2)
	_check("two intents inside the cooldown: the first is believed, the second dropped as too fast", hs.combat.states[cid]["last_seq"] == 10 and hs.combat.dropped == dropped_before + 1 and hs.combat.drops.get("rate", 0) == 1 and seq_before == 1, "last seq %d drops %s" % [hs.combat.states[cid]["last_seq"], hs.combat.drops])
	# From the wrong peer: an intent not from a player (no sender) is dropped.
	dropped_before = hs.combat.dropped
	hs._fire(12, eye, up)
	_check("an intent from no player is dropped", hs.combat.dropped == dropped_before + 1 and hs.combat.drops.get("no_player", 0) >= 1)
	# A dead shooter: the host derezzes the joiner, then the joiner's intents are refused.
	var hp = host["player"]
	hp.respawn_at(Vector3(0, 0.95, 4))
	hp.rotation.y = PI
	await _frames(3)
	var mine: RemotePlayer = _avatar(host, cid)
	for i in 4:
		_aim(hp, mine.global_position + Vector3(0, 0.3, 0))
		await _fire(hp)
		await _frames(SHOT_FRAMES)
	var died := await _until(func(): return cs.dead.get(cid, false) and hs.dead.get(cid, false), 3000)
	await _frames(2)
	dropped_before = hs.combat.dropped
	cs._fire.rpc_id(1, 20, eye, up)
	await _until(func(): return hs.combat.dropped > dropped_before, 2000)
	var shots_before: int = cp.shots_fired
	await _fire(cp)
	await _frames(2)
	_check("the host derezzes the joiner through the same path, with the derezz effect on the host's own screen; a dead joiner's intent is dropped as dead, its own cannon stays silent and its screen says who got it", died and _derezz_count(host) == 1 and mine.dead and not cp.alive and hs.combat.dropped == dropped_before + 1 and hs.combat.drops.get("dead", 0) == 1 and cp.shots_fired == shots_before and client["combat_hud"].line_text().begins_with("DEREZZED by Daemon-1") and client["combat_hud"].feed_text() == PackedStringArray(["SIGKILL sent by Daemon-1 to Daemon-2"]), "alive %s derezz %d drops %s line '%s'" % [cp.alive, _derezz_count(host), hs.combat.drops, client["combat_hud"].line_text()])
	# Wrong types from a joiner: dropped and counted, never an engine error.
	dropped_before = hs.combat.dropped
	cs._fire.rpc_id(1, "junk", Vector3.ZERO, up)
	cs._fire.rpc_id(1, 30, "junk", up)
	cs._fire.rpc_id(1, 30, eye, 7)
	cs._state.rpc_id(1, "junk", 0, eye, 0.0, 0.0, Vector3.ZERO)
	await _until(func(): return hs.combat.dropped >= dropped_before + 3, 2000)
	_check("intents and positions of the wrong types are dropped as malformed, three counted, with nothing applied", hs.combat.dropped == dropped_before + 3 and hs.combat.drops.get("no_player", 0) >= 4, str(hs.combat.drops))
	var corpse: Vector3 = mine.latest_position()
	var old_life: int = cs.lives.get(cid, 0)
	var back := await _until(func(): return not cs.dead.get(cid, true) and cp.alive, 3000)
	await _frames(2)
	_check("the joiner respawns too, far from the host, alive on its own screen, in a new life on both sides", back and cp.alive and cs.health[cid] == 100.0 and Vector2(cp.position.x - hp.position.x, cp.position.z - hp.position.z).length() > 15.0 and cs.lives[cid] == old_life + 1 and hs.lives[cid] == old_life + 1)
	# A position from the past life, still in flight at the respawn, cannot drag the avatar back.
	await _until(func(): return mine.visible and (mine.latest_position() - cp.position).length() < 0.1)
	var stale_seq: int = mine.get("_last_seq") + 1
	cs._state.rpc_id(1, stale_seq, old_life, corpse, 0.0, 0.0, Vector3.ZERO)
	await _frames(4)
	_check("a position from the past life is ignored: the respawned avatar stays at the spawn", (mine.latest_position() - cp.position).length() < 0.1 and (mine.latest_position() - corpse).length() > 10.0, "avatar %s corpse %s" % [mine.latest_position(), corpse])
	await _until(func(): return client["combat_hud"].feed_text().is_empty(), 4000)
	_check("the kill feed entry fades out after its time", client["combat_hud"].feed_text().is_empty() and client["combat_hud"].entries.is_empty())
	await _drop(client)
	await _drop(host)


## A third session joining mid-match sees protection and lives; a joiner asking to be
## Daemon-1 is Daemon-3; a newcomer with no position yet cannot be shot.
func _late_join_checks() -> void:
	var host := _branch("Host4", Vector3.ZERO, true, 3)
	var client := _branch("Client4", CLIENT_OFFSET, true, 3)
	await _frames(2)
	await _join(host, client)
	var hs: Session = host["session"]
	var cs: Session = client["session"]
	var cp = client["player"]
	var hp = host["player"]
	# A newcomer whose position nobody has yet: its avatar's hit volume is off.
	var late := _branch("Late", Vector3.ZERO, false, 3, "Daemon-1")
	await _frames(2)
	late["session"].join("127.0.0.1:%d" % hs.listen_port())
	await _until(func(): return late["session"].state == Session.State.JOINED and hs.players.size() == 3)
	await _frames(2)
	var lid: int = late["session"].my_id
	var phantom: RemotePlayer = _avatar(host, lid)
	var shape_off: bool = phantom != null and not phantom.visible and phantom.get("_hit_shape").disabled
	hp.respawn_at(Vector3(0, 1.65, 4))
	_aim(hp, Vector3(0, 0.5, 0))
	await _fire(hp)
	await _frames(SHOT_FRAMES)
	_check("a newcomer with no position yet is named by its slot (Daemon-3, though it asked to be Daemon-1) and cannot be shot at the origin where its hidden avatar waits", hs.players[lid]["name"] == "Daemon-3" and late["session"].my_name() == "Daemon-3" and shape_off and hs.health[lid] == 100.0, "name %s shape off %s health %.0f" % [hs.players.get(lid, {}).get("name", "?"), shape_off, hs.health.get(lid, -1.0)])
	await _drop(late)
	# The host dies and respawns protected; a session joining then sees the protection and the life.
	for i in 20:
		cp.drive_input(Vector2(0, 1))
		await physics_frame
	hp.respawn_at(Vector3(0, 0.95, 6))
	await _frames(3)
	var target: RemotePlayer = _avatar(client, 1)
	await _until(func(): return target.visible and (target.position - hp.position).length() < 0.3)
	for i in 4:
		_aim(cp, target.global_position + Vector3(0, 0.3, 0))
		await _fire(cp)
		await _frames(SHOT_FRAMES)
	await _until(func(): return hs.dead.get(1, false), 3000)
	await _until(func(): return not hs.dead.get(1, true), 3000)
	var late2 := _branch("Late2", Vector3.ZERO, false, 3)
	await _frames(1)
	late2["session"].join("127.0.0.1:%d" % hs.listen_port())
	await _until(func(): return late2["session"].state == Session.State.JOINED and late2["session"].players.size() == 3)
	await _frames(1)
	var ls: Session = late2["session"]
	print("COMBAT late join: host protection %.2f s on the host, %.2f on the newcomer; host life %d/%d" % [hs.protect_left.get(1, 0.0), ls.protect_left.get(1, 0.0), hs.lives.get(1, -1), ls.lives.get(1, -1)])
	_check("a session joining while the host is freshly respawned sees the protection left and the host's life number", ls.protect_left.get(1, 0.0) > 0.0 and absf(ls.protect_left[1] - hs.protect_left[1]) < 0.1 and ls.lives.get(1, -1) == 1 and hs.lives[1] == 1 and ls.health[1] == 100.0 and not ls.dead[1])
	await _drop(late2)
	await _drop(client)
	await _drop(host)


## A joiner that leaves while dead: the host forgets it cleanly; back alive on a rejoin.
func _leave_checks() -> void:
	var host := _branch("Host3", Vector3.ZERO)
	var client := _branch("Client3", CLIENT_OFFSET)
	await _frames(2)
	await _join(host, client)
	var hs: Session = host["session"]
	var cs: Session = client["session"]
	var cid: int = cs.my_id
	var cp = client["player"]
	var hp = host["player"]
	for i in 20:
		cp.drive_input(Vector2(0, -1))
		await physics_frame
	hp.respawn_at(Vector3(0, 0.95, 4))
	hp.rotation.y = PI
	await _frames(3)
	var mine: RemotePlayer = _avatar(host, cid)
	await _until(func(): return mine.visible)
	for i in 4:
		_aim(hp, mine.global_position + Vector3(0, 0.3, 0))
		await _fire(hp)
		await _frames(SHOT_FRAMES)
	await _until(func(): return cs.dead.get(cid, false), 3000)
	cs.leave()
	await _until(func(): return hs.players.size() == 1)
	await _frames(90)
	_check("a joiner leaving while dead is forgotten by the host, whose respawn timer fires on nobody; the joiner is alive again on its own", hs.players.size() == 1 and not hs.combat.has_player(cid) and hs.dead.size() == 1 and hs.health.size() == 1 and cp.alive and cs.dead.is_empty() and cs.health.is_empty())
	cs.join("127.0.0.1:%d" % hs.listen_port())
	await _until(func(): return cs.state == Session.State.JOINED and hs.players.size() == 2)
	await _frames(2)
	_check("rejoined: full health and alive on both sides", cs.health[cs.my_id] == 100.0 and hs.health[cs.my_id] == 100.0 and not cs.dead[cs.my_id] and cp.alive)
	# The host leaving while the joiner is dead: the joiner comes back to life on its own.
	for i in 4:
		_aim(hp, _avatar(host, cs.my_id).global_position + Vector3(0, 0.3, 0))
		await _fire(hp)
		await _frames(SHOT_FRAMES)
	await _until(func(): return cs.dead.get(cs.my_id, false), 3000)
	hs.leave()
	await _until(func(): return cs.state == Session.State.FAILED)
	_check("the host leaving while the joiner is dead: \"host left\", the joiner alive and off", cs.error == Session.HOST_LEFT and cp.alive and cs.dead.is_empty())
	await _drop(client)
	await _drop(host)


func _layout_checks() -> void:
	var before := root.size
	for size in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = size
		var host := _branch("Layout", Vector3.ZERO)
		await _frames(2)
		host["session"].host(0)
		var hud: CombatHud = host["combat_hud"]
		host["session"].players[7] = {"slot": 2, "name": "Daemon-2"}
		for i in 4:
			hud.entries.push_front({"killer": 7 if i % 2 == 0 else 1, "victim": 1 if i % 2 == 0 else 7, "left": 2.0})
		host["hud"].guide()._notice("word ".repeat(60), Color.WHITE, 5000)
		host["hud"].net_hud().toggle()
		await _frames(3)
		var screen := Rect2(Vector2.ZERO, Vector2(root.size))
		var panels := [host["hud"].net_hud().get("_panel"), host["hud"].guide().get("_panel")]
		var wrong := PackedStringArray()
		var shown := 0
		for label in host["main"].find_children("*", "Label", true, false):
			if not label.is_visible_in_tree() or label.text.is_empty():
				continue
			shown += 1
			var rect: Rect2 = label.get_global_rect()
			if not screen.encloses(rect):
				wrong.append("outside: %s %s" % [label.text.left(20), rect])
			if rect.size.x >= screen.size.x:
				continue
			for panel in panels:
				if not panel.is_ancestor_of(label) and panel.get_global_rect().intersects(rect):
					wrong.append("under a panel: %s %s" % [label.text.left(20), rect])
		_check("at %dx%d four kills in the feed, the combat line, the net panel and a long guide notice all sit inside the screen and nothing is covered" % [size.x, size.y], shown >= 14 and wrong.is_empty() and hud.feed_text().size() == 4, "%d shown; %s" % [shown, ", ".join(wrong)])
		await _drop(host)
	root.size = before


func _cleanup() -> void:
	for branch in _branches.duplicate():
		if is_instance_valid(branch):
			var session = branch.get_node_or_null(Session.NODE_NAME)
			if session != null:
				session.leave()
			branch.free()
	await process_frame
	OS.delay_msec(300)
	await process_frame
