extends SceneTree
## Headless LAN and tailnet test for SIGKILL (C13). scripts/check.sh runs it, and any FAIL
## exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/net_test.gd
##
## Everything runs in this one process: each side gets its own branch of the tree with its
## own SceneMultiplayer (SceneTree.set_multiplayer), its own NetSession and its own real
## arena, and the two talk over ENet on 127.0.0.1 only, on ports the system hands out. The
## joiner's branch sits 1000 m away so the two arenas' physics never touch; avatar positions
## are read in their arena's own space. Short timeouts come from a test tuning.

const Session = preload("res://scripts/net/net_session.gd")
const TuningScript = preload("res://scripts/net/net_tuning.gd")
const RemotePlayer = preload("res://scripts/net/remote_player.gd")
const NetHud = preload("res://scripts/net/net_hud.gd")
const Controls = preload("res://scripts/controls.gd")
const MainScene = preload("res://scenes/main.tscn")
const WATCHDOG_MS := 10000
const NET_SOURCES := ["res://scripts/net/net_session.gd", "res://scripts/net/net_hud.gd", "res://scripts/net/remote_player.gd", "res://scripts/net/net_tuning.gd"]
const SOURCE_NEVER := ["OS.execute", "OS.create_process", "OS.kill", "OS.shell_open", "OS.get_environment", "OS.get_user", "OS.get_name", "execute_with_pipe", "StreamPeerTCP", "TCPServer", "HTTPRequest", "HTTPClient", "UDPServer", "WebSocket", "WebRTC", "FileAccess", "DirAccess", "JSON", "var_to_bytes", "bytes_to_var", "with_objects", "server_relay = true", "allow_object_decoding = true", "put_packet", "get_packet"]
const CLIENT_OFFSET := Vector3(1000.0, 0.0, 0.0)
const FRAMES_PER_SEND := 3  # 60 Hz physics, 20 Hz sends

var _fails := 0
var _checks := 0
var _branches: Array = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	Controls.ensure()
	_tuning_checks()
	_source_checks()
	_helper_checks()
	await _solo_checks()
	await _session_checks()
	await _refusal_checks()
	await _failure_checks()
	await _hud_checks()
	await _layout_checks()
	await _cleanup()
	print("NET: %d checks" % _checks)
	print("NET RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


func _tuning(connect_ms: int = 1500) -> Resource:
	var t := TuningScript.new()
	t.bind_address = "127.0.0.1"
	t.connect_timeout_ms = connect_ms
	t.peer_timeout_ms = 2000
	return t


## A side of the game in its own branch: {branch, session, main, player, hud, net_hud}.
## With `arena` false only the session is made (a joiner with nothing to show).
func _branch(name: String, offset: Vector3, tuning: Resource, arena: bool = true, protocol: int = Session.PROTOCOL) -> Dictionary:
	var api := SceneMultiplayer.new()
	var branch := Node3D.new()
	branch.name = name
	branch.position = offset
	root.add_child(branch)
	set_multiplayer(api, branch.get_path())
	var session := Session.new()
	session.name = Session.NODE_NAME
	session.tuning = tuning
	session.protocol = protocol
	branch.add_child(session)
	var out := {"branch": branch, "session": session, "api": api}
	if arena:
		var main = MainScene.instantiate()
		branch.add_child(main)
		out["main"] = main
		out["player"] = main.get_node("Player")
		out["hud"] = main.get_node("Hud")
		out["net_hud"] = main.get_node("Hud").net_hud()
		out["player"].assume_captured = true
		main.get_node("Hud").guide().focus_check = func(): return false
		out["net_hud"].focus_check = func(): return false
	_branches.append(branch)
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


func _joined(host: Dictionary, client: Dictionary) -> bool:
	return await _until(func(): return client["session"].state == Session.State.JOINED and host["session"].players.size() == 2 and client["session"].players.size() == 2)


func _address(host: Dictionary) -> String:
	return "127.0.0.1:%d" % host["session"].listen_port()


func _avatar(side: Dictionary, id: int) -> Node3D:
	return side["session"].avatars.get(id)


func _key(keycode: Key, unicode: int = 0, ctrl: bool = false) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.unicode = unicode
	down.pressed = true
	down.ctrl_pressed = ctrl
	Input.parse_input_event(down)
	await process_frame
	var up := down.duplicate() as InputEventKey
	up.pressed = false
	up.unicode = 0
	Input.parse_input_event(up)
	await process_frame


func _type(text: String) -> void:
	for i in text.length():
		var c := text.unicode_at(i)
		var code: Key
		if c >= 0x30 and c <= 0x39:
			code = (KEY_0 + c - 0x30) as Key
		elif c == 0x2E:
			code = KEY_PERIOD
		elif c == 0x3A:
			code = KEY_COLON
		elif c >= 0x61 and c <= 0x7A:
			code = (c - 0x20) as Key
		else:
			code = KEY_SPACE
		await _key(code, c)


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


func _tuning_checks() -> void:
	var shipped = load("res://resources/net.tres")
	_check("the shipped net tuning is valid: port 9009 on every interface, 2 players, 5 s to connect, 20 sends a second, 100 ms behind", shipped is TuningScript and shipped.problems().is_empty() and shipped.port == 9009 and shipped.bind_address == "*" and shipped.max_players == 2 and shipped.connect_timeout_ms == 5000 and shipped.sync_rate_hz == 20 and shipped.interp_delay_ms == 100 and shipped.display_name == "player", str(shipped.problems()) if shipped is TuningScript else "")
	var bad := TuningScript.new()
	bad.port = 80
	bad.bind_address = "host.example"
	bad.max_players = 1
	bad.display_name = "a name with a tab\tin it"
	bad.sync_rate_hz = 1000
	var issues: PackedStringArray = bad.problems()
	_check("bad tuning is refused and the shipped one used: a privileged port, a name for the bind address, one player, a control character in the name, 1000 sends a second", issues.size() == 5 and Session.usable_tuning(bad) == shipped, ", ".join(issues))


func _source_checks() -> void:
	var all := ""
	for path in NET_SOURCES:
		all += _code(path)
	var found := PackedStringArray()
	for word in SOURCE_NEVER:
		if all.contains(word):
			found.append(word)
	_check("the net module starts no program, reads no file, asks the system nothing, opens no TCP, HTTP, WebSocket or WebRTC socket and never decodes objects", found.is_empty(), ", ".join(found))
	var session := _code("res://scripts/net/net_session.gd")
	_check("its only sockets are the one ENet peer a host or a joiner makes and the port probes that bind and close at once", session.count("ENetMultiplayerPeer.new()") == 2 and session.count("PacketPeerUDP.new()") == 2 and session.count("probe.bind(") == 2 and session.count("probe.close()") == 2 and session.count("create_server(") == 1 and session.count("create_client(") == 1 and all.count("create_server(") == 1 and all.count("create_client(") == 1)
	_check("Godot's relay stays off and objects are never decoded: nothing moves between players without the host's code", session.contains("m.server_relay = false") and session.contains("m.allow_object_decoding = false"))
	_check("three RPCs, all with numbers, names and ids only: the roster from the host, state to the host, state from the host", session.count("@rpc(") == 3 and session.contains('@rpc("authority", "call_remote", "reliable")\nfunc _roster(ids: PackedInt32Array, slots: PackedInt32Array, names: PackedStringArray)') and session.contains('@rpc("any_peer", "call_remote", "unreliable_ordered")\nfunc _state(seq: int, pos: Vector3, yaw: float, pitch: float, vel: Vector3)') and session.contains('@rpc("authority", "call_remote", "unreliable_ordered")\nfunc _remote_state(id: int, seq: int, pos: Vector3, yaw: float, pitch: float, vel: Vector3)'))
	_check("what is sent about a player is its position, body yaw, view pitch and velocity, read from the player node and nothing else", session.contains("var pos: Vector3 = _player.position") and session.contains("var yaw: float = _player.rotation.y") and session.contains("_player.view_pitch()") and session.contains("_player.velocity") and session.count(".rpc_id(") == 4 and session.count(".rpc(") == 0)
	var keys := FileAccess.get_file_as_string("res://scripts/controls.gd")
	var users := PackedStringArray()
	for action in InputMap.get_actions():
		for event in InputMap.action_get_events(action):
			if event is InputEventKey and (event.physical_keycode == KEY_M or event.keycode == KEY_M) and not (event.ctrl_pressed or event.alt_pressed or event.meta_pressed or event.shift_pressed):
				users.append(String(action))
	_check("M is a plain key bound to nothing but the multiplayer panel; H, J and L are its own keys and no action's", keys.contains("_key(\"net_menu\", [KEY_M])") and Array(users) == ["net_menu"] and not keys.contains("[KEY_H]") and not keys.contains("[KEY_J]") and not keys.contains("[KEY_L]"), ", ".join(users))
	var hud := _code("res://scripts/net/net_hud.gd")
	_check("the panel's own keys count only while it is up and never with Ctrl, Alt or Super", hud.contains("if not _open or key.ctrl_pressed or key.alt_pressed or key.meta_pressed or _guide_busy():\n\t\treturn"))


func _helper_checks() -> void:
	var good := {
		"127.0.0.1": ["127.0.0.1", 9009, true], " 127.0.0.1:4433 ": ["127.0.0.1", 4433, true],
		"host.example": ["host.example", 9009, false], "host.example:4433": ["host.example", 4433, false],
		"host": ["host", 9009, false], "my-box-2.lan": ["my-box-2.lan", 9009, false],
		"fd7a:115c:a1e0::1": ["fd7a:115c:a1e0::1", 9009, true], "[fd7a:115c:a1e0::1]:4433": ["fd7a:115c:a1e0::1", 4433, true],
		"[::1]": ["::1", 9009, true],
	}
	var wrong := PackedStringArray()
	for text in good:
		var got := Session.parse_address(text, 9009)
		if got.is_empty() or got["host"] != good[text][0] or got["port"] != good[text][1] or got["ip"] != good[text][2]:
			wrong.append("%s -> %s" % [text, got])
	for text in ["", "   ", "host example", "host:port", "host:0", "host:65536", "host:-1", "host:+5", "[::1", "[::1]x", "-bad.example", "bad-.example", "a..b", "x".repeat(300), "host.example:1:2", "under_score.example", "evil;rm", "http://host.example"]:
		if not Session.parse_address(text, 9009).is_empty():
			wrong.append("accepted '%s'" % text)
	_check("addresses: ip, ip:port, name, name:port, bare v6, [v6]:port parse; spaces, bad ports, bad names and anything else are refused", wrong.is_empty(), "; ".join(wrong))
	var hello := Session.hello_bytes(7, "player")
	var parsed := Session.parse_hello(hello)
	var reply := Session.reply_bytes(7, Session.Verdict.OK, 2, "player 2")
	var rparsed := Session.parse_reply(reply)
	_check("the hello and the reply round-trip: version, name, verdict, slot", hello.size() == 11 and parsed == {"version": 7, "name": "player"} and rparsed == {"version": 7, "verdict": Session.Verdict.OK, "slot": 2, "name": "player 2"} and Session.parse_reply(Session.reply_bytes(7, Session.Verdict.FULL, 0, "")) == {"version": 7, "verdict": Session.Verdict.FULL, "slot": 0, "name": ""})
	var junk := PackedStringArray()
	for data in [PackedByteArray(), PackedByteArray([0x53]), PackedByteArray([0x58, 0x4B, 0, 1, 0]), PackedByteArray([0x53, 0x4B, 0, 1, 3, 0x61]), PackedByteArray([0x53, 0x4B, 0, 1, 0, 0x61]), "SK garbage of some length".to_ascii_buffer()]:
		if not Session.parse_hello(data).is_empty():
			junk.append("hello " + str(data))
		if not Session.parse_reply(data).is_empty():
			junk.append("reply " + str(data))
	var ok_no_slot := Session.reply_bytes(1, Session.Verdict.OK, 0, "player 2")
	var ok_bad_name := Session.reply_bytes(1, Session.Verdict.OK, 2, "")
	var ctrl_name := Session.hello_bytes(1, "x")
	ctrl_name.set(5, 0x07)
	_check("junk, short, wrong-magic and wrong-length packets parse to nothing; an ok reply needs a slot and a shown name; a name with a control byte becomes the placeholder", junk.is_empty() and Session.parse_reply(ok_no_slot).is_empty() and Session.parse_reply(ok_bad_name).is_empty() and Session.parse_hello(ctrl_name) == {"version": 1, "name": "player"}, ", ".join(junk))
	_check("names: a shown name is kept, the placeholder or a name the game cannot show becomes player <slot>", Session.assigned_name("spike", 2) == "spike" and Session.assigned_name("player", 2) == "player 2" and Session.assigned_name("", 1) == "player 1" and Session.assigned_name("x".repeat(40), 3) == "player 3" and Session.assigned_name("aéb", 2) == "player 2")
	_check("sequence numbers: 1 up to 2^31 - 1 count, 0, negatives and 2^63 - 1 do not; a first sample sets the baseline whatever its number, then only newer and at most 10000 ahead", Session.seq_sane(1) and Session.seq_sane(2147483646) and not Session.seq_sane(0) and not Session.seq_sane(-1) and not Session.seq_sane(2147483647) and not Session.seq_sane(9223372036854775807) and RemotePlayer.seq_ok(15000, -1) and RemotePlayer.seq_ok(5, 4) and not RemotePlayer.seq_ok(4, 4) and not RemotePlayer.seq_ok(20000, 4) and not RemotePlayer.seq_ok(9223372036854775807, -1) and not RemotePlayer.seq_ok(9223372036854775807, 5))
	var v := Vector3(1, 2, 3)
	_check("state packets with NaN, infinity, a position beyond the world, a yaw past a full turn, a pitch past straight up or an impossible speed are refused", Session.sane(v, 0.5, -0.5, v) and Session.sane(v, -TAU, PI * 0.5, v) and not Session.sane(Vector3(NAN, 0, 0), 0.0, 0.0, v) and not Session.sane(v, INF, 0.0, v) and not Session.sane(v, 1e300, 0.0, v) and not Session.sane(v, 7.0, 0.0, v) and not Session.sane(v, 0.0, 2.0, v) and not Session.sane(Vector3(20000, 0, 0), 0.0, 0.0, v) and not Session.sane(v, 0.0, 0.0, Vector3(500, 0, 0)))


## Solo play: the arena alone makes an OFF session with the offline peer, no socket, no
## sends, no avatars, and the player moves as before.
func _solo_checks() -> void:
	var api := SceneMultiplayer.new()
	var branch := Node3D.new()
	branch.name = "Solo"
	root.add_child(branch)
	set_multiplayer(api, branch.get_path())
	_branches.append(branch)
	var main = MainScene.instantiate()
	branch.add_child(main)
	var player = main.get_node("Player")
	player.assume_captured = true
	await _frames(3)
	var session = branch.get_node_or_null(Session.NODE_NAME)
	_check("the arena alone makes one OFF session beside itself, on Godot's offline peer, with no socket", session != null and session.state == Session.State.OFF and api.multiplayer_peer is OfflineMultiplayerPeer and session.get("_enet") == null and session.listen_port() == 0)
	var start: Vector3 = player.global_position
	for i in 30:
		player.drive_input(Vector2(0, -1))
		await physics_frame
	var moved: float = Vector2(player.global_position.x - start.x, player.global_position.z - start.z).length()
	_check("solo: the player moves as before, nothing is sent, no avatar exists, the net line says off", moved > 2.0 and session.sent == 0 and session.received == 0 and session.avatars.is_empty() and main.get_node("Players").get_child_count() == 0 and main.get_node("Hud").net_hud().line_text() == NetHud.NET_OFF, "moved %.2f, sent %d" % [moved, session.sent])
	_check("solo: leave() with nothing open does nothing and prints nothing", true if (func(): session.leave(); return session.state == Session.State.OFF).call() else false)
	branch.free()
	_branches.erase(branch)
	await process_frame


## Host and join on 127.0.0.1: the roster, the avatars, the host's scripted movement seen
## by the joiner, both directions, the send rate, the joiner leaving, a second join, the
## arena reloaded under a live session, the host leaving.
func _session_checks() -> void:
	var host := _branch("Host", Vector3.ZERO, _tuning())
	var client := _branch("Client", CLIENT_OFFSET, _tuning())
	await _frames(2)
	var hosted: bool = host["session"].host(0)
	var port: int = host["session"].listen_port()
	_check("host(0) opens a port the system hands out on 127.0.0.1 and lists player 1", hosted and port > 0 and host["session"].state == Session.State.HOSTING and host["session"].players == {1: {"slot": 1, "name": "player 1"}}, "port %d" % port)
	var t0 := Time.get_ticks_msec()
	var started: bool = client["session"].join("127.0.0.1:%d" % port)
	var joined := await _joined(host, client)
	var took := Time.get_ticks_msec() - t0
	var hs: Session = host["session"]
	var cs: Session = client["session"]
	var client_id: int = cs.my_id
	print("NET join: joined %s in %d ms real; host players %s; joiner players %s" % [joined, took, hs.players, cs.players])
	var client_enet = cs.get("_enet")
	_check("the joiner's socket is bound to the tuning's bind address, 127.0.0.1, on a port the system handed out for it", client_enet != null and cs.get("_local_port") > 0 and client_enet.host.get_local_port() == cs.get("_local_port"), "local port %d, bound %d" % [cs.get("_local_port"), client_enet.host.get_local_port() if client_enet != null else -1])
	_check("the joiner connects, passes the handshake and both sides agree on the roster: player 1 (host) and player 2", started and joined and client_id != 1 and hs.players.has(client_id) and hs.players[client_id] == {"slot": 2, "name": "player 2"} and cs.players == hs.players and cs.my_name() == "player 2" and hs.roster_text() == "player 1 (you), player 2" and cs.roster_text() == "player 1, player 2 (you)")
	_check("each side shows the other's avatar, named, under the arena's Players node, hidden until it moves", _avatar(host, client_id) is RemotePlayer and _avatar(client, 1) is RemotePlayer and _avatar(client, 1).player_name == "player 1" and _avatar(host, client_id).player_name == "player 2" and _avatar(client, 1).get_parent() == client["main"].get_node("Players"))
	# The host's player runs forward; the joiner's avatar of it follows, smoothly, behind.
	var hp = host["player"]
	var avatar: RemotePlayer = _avatar(client, 1)
	await _until(func(): return avatar.visible)
	var host_path: Array = []
	var avatar_path: Array = []
	for i in 90:
		hp.drive_input(Vector2(0, -1))
		await physics_frame
		host_path.append(hp.position)
		avatar_path.append(avatar.position)
	var run: float = (host_path[-1] - host_path[0]).length()
	var delay_frames := int(cs.tuning_in_use().interp_delay_ms / 1000.0 * 60.0)
	var worst := 0.0
	var worst_step := 0.0
	for i in range(30, 90):
		worst = maxf(worst, (avatar_path[i] - host_path[i - delay_frames]).length())
		worst_step = maxf(worst_step, (avatar_path[i] - avatar_path[i - 1]).length())
	var step_cap: float = hp.get("_t").walk_speed / 60.0 * 1.6
	print("NET movement: host ran %.2f m in 90 frames; the avatar stayed within %.3f m of where the host was %d frames (%d ms) earlier; largest avatar step %.3f m per frame (host's %.3f)" % [run, worst, delay_frames, cs.tuning_in_use().interp_delay_ms, worst_step, hp.get("_t").walk_speed / 60.0])
	_check("the joiner sees the host move: the avatar tracks the host's path 100 ms behind, within a send interval, with no jumps", run > 5.0 and worst < 0.5 and worst_step < step_cap and (avatar_path[-1] - avatar_path[29]).length() > 3.0, "run %.2f, worst %.3f, step %.3f" % [run, worst, worst_step])
	await _frames(delay_frames + FRAMES_PER_SEND * 3)
	var settled: float = (avatar.position - hp.position).length()
	_check("once the host stops, the avatar settles on the host's position", settled < 0.05, "%.3f m off" % settled)
	hp.rotation.y = 1.0
	hp.get_node("Head").rotation.x = 0.3
	await _frames(delay_frames + FRAMES_PER_SEND * 3)
	_check("body yaw and view pitch are synced too", absf(avatar.rotation.y - 1.0) < 0.01 and absf(avatar.view_pitch() - 0.3) < 0.01, "yaw %.3f pitch %.3f" % [avatar.rotation.y, avatar.view_pitch()])
	var sent_before: int = hs.sent
	await _frames(60)
	var per_second: int = hs.sent - sent_before
	_check("positions go out 20 times a second, not every frame", per_second >= 18 and per_second <= 22, "%d in 60 frames" % per_second)
	# The other way: the joiner's own player moves, the host's avatar of it follows.
	var cp = client["player"]
	var back: RemotePlayer = _avatar(host, client_id)
	var from: Vector3 = cp.position
	for i in 60:
		cp.drive_input(Vector2(0, -1))
		await physics_frame
	await _frames(delay_frames + FRAMES_PER_SEND * 3)
	var client_run: float = (cp.position - from).length()
	var back_off: float = (back.position - cp.position).length()
	_check("the host sees the joiner move too, in the joiner's own arena space", client_run > 3.0 and back.visible and back_off < 0.05 and hs.received > 0, "ran %.2f, avatar %.3f off" % [client_run, back_off])
	# A long delay: the buffer keeps enough samples that the avatar still glides, a second behind.
	back.interp_delay_s = 1.0
	var long_from: Vector3 = cp.position
	var long_host: Array = []
	var long_avatar: Array = []
	var deepest := 0
	for i in 150:
		cp.drive_input(Vector2(0, 1) if i < 90 else Vector2.ZERO)  # back toward the spawn: open floor
		await physics_frame
		long_host.append(cp.position)
		long_avatar.append(back.position)
		deepest = maxi(deepest, back.samples.size())
	var long_worst := 0.0
	var long_step := 0.0
	for i in range(70, 150):
		long_worst = maxf(long_worst, (long_avatar[i] - long_host[i - 60]).length())
		long_step = maxf(long_step, (long_avatar[i] - long_avatar[i - 1]).length())
	print("NET long delay: with a 1000 ms delay the buffer held up to %d samples; the avatar stayed within %.3f m of where the player was 60 frames earlier, largest step %.3f m" % [deepest, long_worst, long_step])
	_check("with a 1000 ms delay the buffer keeps the samples it needs (over 20) and the avatar still glides a second behind, with no jumps", deepest >= 20 and long_worst < 0.5 and long_step < step_cap and (long_host[89] - long_from).length() > 5.0, "deepest %d, worst %.3f, step %.3f" % [deepest, long_worst, long_step])
	back.interp_delay_s = cs.tuning_in_use().interp_delay_ms / 1000.0
	await _frames(delay_frames + FRAMES_PER_SEND * 3)
	# Hostile state packets over the wire, one at a time with the joiner's own stream paused
	# (no player to read): the host accepts none, the avatar takes none and does not move.
	var paused_player = cs.get("_player")
	cs.set("_player", null)
	await _frames(FRAMES_PER_SEND + 1)
	var bad := [["a yaw of 1e300", [cp.position, 1e300, 0.0, Vector3.ZERO]], ["a NaN position", [Vector3(NAN, 0, 0), 0.0, 0.0, Vector3.ZERO]], ["an impossible speed", [cp.position, 0.0, 0.0, Vector3(9999, 0, 0)]], ["a pitch past straight up", [cp.position, 0.0, 2.0, Vector3.ZERO]], ["a position beyond the world", [Vector3(20000, 0, 0), 0.0, 0.0, Vector3.ZERO]]]
	var leaked := PackedStringArray()
	for item in bad:
		var host_got: int = hs.received
		var avatar_got: int = back.received
		var last_seq: int = back.get("_last_seq")
		var at: Vector3 = back.position
		var yaw: float = back.rotation.y
		var args: Array = item[1]
		cs._state.rpc_id(1, last_seq + 1, args[0], args[1], args[2], args[3])
		var moved := false
		for i in delay_frames + FRAMES_PER_SEND:
			await physics_frame
			moved = moved or (back.position - at).length() > 0.0001 or absf(back.rotation.y - yaw) > 0.0001 or not back.transform.basis.is_finite()
		if hs.received != host_got or back.received != avatar_got or back.get("_last_seq") != last_seq or moved:
			leaked.append("%s: host +%d, avatar +%d, last seq %d -> %d, moved %s" % [item[0], hs.received - host_got, back.received - avatar_got, last_seq, back.get("_last_seq"), moved])
	_check("a joiner's packet with a yaw of 1e300, a NaN position, an impossible speed, a pitch past straight up or a position beyond the world, sent alone, is refused on the host: not applied, not counted, the avatar never moves", leaked.is_empty(), "; ".join(leaked))
	cs.set("_player", paused_player)
	var got_before: int = hs.received
	await _frames(delay_frames + FRAMES_PER_SEND * 3)
	var flowing: int = hs.received - got_before
	_check("and the real stream flows again once the joiner has a player to send", flowing >= 3 and (back.position - cp.position).length() < 0.05, "%d packets, %.3f m off" % [flowing, (back.position - cp.position).length()])
	# One sane-looking packet with a giant sequence number must not put the real stream behind it.
	var last: int = back.get("_last_seq")
	cs._state.rpc_id(1, last + 5000000, cp.position + Vector3(0, 0, -3), 0.0, 0.0, Vector3.ZERO)
	cs._state.rpc_id(1, 9223372036854775807, cp.position + Vector3(0, 0, -3), 0.0, 0.0, Vector3.ZERO)
	cs._state.rpc_id(1, 0, cp.position + Vector3(0, 0, -3), 0.0, 0.0, Vector3.ZERO)
	await _frames(delay_frames + FRAMES_PER_SEND)
	var not_jumped: bool = (back.position - cp.position).length() < 0.05
	for i in 30:
		cp.drive_input(Vector2(0, -1))
		await physics_frame
	await _frames(delay_frames + FRAMES_PER_SEND * 3)
	_check("packets with a sequence number far ahead, the largest int or zero are dropped (by the avatar or before it), which goes on following the real ones", not_jumped and back.dropped >= 1 and (back.position - cp.position).length() < 0.05 and back.get("_last_seq") < 2147483647, "%.3f m off after moving on, dropped %d, last seq %d" % [(back.position - cp.position).length(), back.dropped, back.get("_last_seq")])
	# The joiner leaves: the host sees it at once.
	cs.leave()
	var seen := await _until(func(): return hs.players.size() == 1 and hs.avatars.is_empty())
	_check("the joiner leaving is seen by the host: the roster shrinks to player 1, its avatar is gone, the host keeps hosting", seen and cs.state == Session.State.OFF and hs.state == Session.State.HOSTING and not is_instance_valid(back) or (seen and back.is_queued_for_deletion()), "host players %s" % hs.players)
	await _frames(2)
	# A second join after leaving, with both counters high: the joiner's own starts over, the
	# host's is taken as the baseline.
	hs.set("_seq", 30000)
	cs.set("_seq", 30000)
	cs.join(_address(host))
	var again := await _joined(host, client)
	var again_avatar: RemotePlayer = _avatar(client, 1)
	var seen_again := await _until(func(): return again_avatar != null and again_avatar.visible and _avatar(host, cs.my_id) != null and _avatar(host, cs.my_id).visible)
	_check("the same joiner can join again after leaving, as player 2 once more, and both avatars show despite the old counters", again and cs.my_name() == "player 2" and seen_again and cs.get("_seq") < 1000 and again_avatar.get("_last_seq") > 30000, "joiner seq %d, host avatar last %d" % [cs.get("_seq"), again_avatar.get("_last_seq") if again_avatar != null else -1])
	# The joiner's arena is replaced (what R does): the session stays, the avatar comes back,
	# even with the host's counter long past the jump bound.
	hs.set("_seq", 50000)
	var old_main = client["main"]
	old_main.free()
	await _frames(FRAMES_PER_SEND * 2)
	var main2 = MainScene.instantiate()
	client["branch"].add_child(main2)
	client["main"] = main2
	client["player"] = main2.get_node("Player")
	client["player"].assume_captured = true
	await _frames(2)
	var fresh: RemotePlayer = _avatar(client, 1)
	hp.drive_input(Vector2(0, 1))
	await physics_frame
	var shown := await _until(func(): return fresh != null and is_instance_valid(fresh) and fresh.visible)
	_check("the arena replaced under a live session: still joined, the host's avatar is back in the new arena and moves again, with the host's counter already past 50000", cs.state == Session.State.JOINED and fresh is RemotePlayer and fresh.get_parent() == main2.get_node("Players") and shown and fresh.get("_last_seq") > 50000 and main2.get_node("Hud").net_hud().session == cs, "last seq %d" % (fresh.get("_last_seq") if fresh != null else -1))
	# The host leaves: the joiner sees it.
	hs.leave()
	var left := await _until(func(): return cs.state == Session.State.FAILED)
	_check("the host leaving is seen by the joiner: \"host left\", its avatars gone, nothing hosted any more", left and cs.error == Session.HOST_LEFT and cs.avatars.is_empty() and cs.players.is_empty() and hs.state == Session.State.OFF and hs.listen_port() == 0)
	await _frames(2)
	_check("after that the former joiner can host itself", cs.host(0) and cs.state == Session.State.HOSTING and cs.listen_port() > 0)
	cs.leave()
	await _drop(client)
	await _drop(host)


## Refusals: a version mismatch and a full host, each with the reason shown to the joiner.
func _refusal_checks() -> void:
	var host := _branch("Host2", Vector3.ZERO, _tuning())
	await _frames(2)
	host["session"].host(0)
	var hs: Session = host["session"]
	var old := _branch("Old", Vector3.ZERO, _tuning(), false, Session.PROTOCOL + 1)
	await _frames(2)
	old["session"].join(_address(host))
	var refused := await _until(func(): return old["session"].state == Session.State.FAILED)
	await _frames(FRAMES_PER_SEND * 2)
	_check("a joiner on another protocol version is refused with the reason, and the host keeps nothing of it", refused and old["session"].error == "version mismatch: host %d, you %d" % [Session.PROTOCOL, Session.PROTOCOL + 1] and hs.players.size() == 1 and hs.get("_pending").is_empty() and hs.multiplayer.get_peers().is_empty(), old["session"].error)
	var line: String = host["net_hud"].line_text()
	_check("the host's screen says so too: the net line and the panel carry the refusal with both versions", hs.notice == "refused a joiner: version mismatch, host %d, joiner %d" % [Session.PROTOCOL, Session.PROTOCOL + 1] and line.ends_with(hs.notice) and line.begins_with("net: hosting :%d   players 1/2" % hs.listen_port()), line)
	await _drop(old)
	var client := _branch("Client2", CLIENT_OFFSET, _tuning())
	await _frames(2)
	client["session"].join(_address(host))
	await _joined(host, client)
	var third := _branch("Third", Vector3.ZERO, _tuning(), false)
	await _frames(2)
	third["session"].join(_address(host))
	var full := await _until(func(): return third["session"].state == Session.State.FAILED)
	await _frames(FRAMES_PER_SEND * 2)
	_check("a third player to a two-player host is refused with \"host full\"; the two keep playing, and the host's screen says it refused one", full and third["session"].error == Session.HOST_FULL and hs.players.size() == 2 and client["session"].state == Session.State.JOINED and hs.multiplayer.get_peers().size() == 1 and hs.notice == "refused a joiner: host full" and host["net_hud"].line_text().ends_with(hs.notice), third["session"].error)
	await _until(func(): return hs.get("_refused").is_empty() and hs.multiplayer.get_authenticating_peers().is_empty())
	_check("the refused peers are gone from the host after the grace", hs.get("_refused").is_empty() and hs.multiplayer.get_authenticating_peers().is_empty())
	await _drop(third)
	await _drop(client)
	await _drop(host)


## Nothing there, a bad address, a busy port, a cancel: a clear message each time and the
## game runs on.
func _failure_checks() -> void:
	var side := _branch("Alone", Vector3.ZERO, _tuning(1500))
	await _frames(2)
	var s: Session = side["session"]
	var spare := PacketPeerUDP.new()
	spare.bind(0, "127.0.0.1")
	var dead := spare.get_local_port()
	spare.close()
	var frames_before := Engine.get_physics_frames()
	var started := s.join("127.0.0.1:%d" % dead)
	var connecting: bool = s.state == Session.State.CONNECTING
	var gave_up := await _until(func(): return s.state == Session.State.FAILED, 6000)
	var frames := Engine.get_physics_frames() - frames_before
	print("NET closed port: gave up after %d frames (%d ms of game time, tuning %d ms)" % [frames, frames * 1000 / 60, s.tuning_in_use().connect_timeout_ms])
	_check("a join to a closed port gives up on the connect timeout with \"couldn't reach host\", and the game kept running meanwhile", started and connecting and gave_up and s.error == Session.CANT_REACH and absi(frames - 90) <= 3 and s.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "%s after %d frames" % [s.error, frames])
	_check("not an address: refused at once, nothing opened", not s.join("host example") and s.error == Session.BAD_ADDRESS and not s.join("127.0.0.1:99999") and not s.join("") and s.state == Session.State.FAILED and s.get("_enet") == null)
	s.join("127.0.0.1:%d" % dead)
	await _frames(5)
	s.leave()
	_check("Esc while connecting: back to off at once, nothing left open", s.state == Session.State.OFF and s.error == "" and s.get("_enet") == null and s.multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
	var busy := PacketPeerUDP.new()
	busy.bind(0, "127.0.0.1")
	var taken := busy.get_local_port()
	var hosted := s.host(taken)
	busy.close()
	_check("hosting on a port in use says so and opens nothing", not hosted and s.error == "port %d is in use" % taken and s.state == Session.State.FAILED and s.get("_enet") == null)
	var host := _branch("Named", Vector3.ZERO, _tuning())
	await _frames(2)
	host["session"].host(0)
	s.join("localhost:%d" % host["session"].listen_port())
	var resolving: bool = s.state == Session.State.RESOLVING
	var by_name := await _until(func(): return s.state == Session.State.JOINED or s.state == Session.State.FAILED)
	_check("a host name is looked up off the main thread and then joined: localhost reaches the host on 127.0.0.1", resolving and by_name and s.state == Session.State.JOINED, s.error)
	s.leave()
	await _drop(host)
	await _drop(side)


## The panel and its keys, in the real HUD: M, H, J with the address box, L, Esc. One
## arena at a time takes the keys: in this one tree a second HUD would take them first.
func _hud_checks() -> void:
	var tuning := _tuning()
	tuning.port = _free_port()
	var host := _branch("HostHud", Vector3.ZERO, tuning)
	await _frames(2)
	var hh: NetHud = host["net_hud"]
	_check("the net line says off, the panel is down", hh.line_text() == NetHud.NET_OFF and hh.panel_text() == "" and not hh.is_open())
	await _key(KEY_M, 0x6D)
	var opened: bool = hh.is_open()
	await _key(KEY_H, 0x68, true)
	var ctrl_ignored: bool = host["session"].state == Session.State.OFF
	await _key(KEY_H, 0x68)
	await _frames(2)
	var port: int = host["session"].listen_port()
	print("NET HUD host panel:\n", hh.panel_text())
	_check("M opens the panel; Ctrl+H does nothing; H hosts on the tuning's port, and the panel and the net line say so", opened and ctrl_ignored and host["session"].state == Session.State.HOSTING and port == tuning.port and hh.panel_text().begins_with("multiplayer\nHosting on port %d." % port) and hh.panel_text().contains("players 1/2: player 1 (you)") and hh.panel_text().ends_with(NetHud.HOST_KEYS) and hh.line_text() == NetHud.NET_HOSTING % [port, 1, 2], hh.panel_text().c_escape())
	_check("the round summary waits while the panel is up", host["hud"].round_hud().hold_summary)
	await _key(KEY_ESCAPE)
	_check("Esc closes the panel and the summary may show again", not hh.is_open() and not host["hud"].round_hud().hold_summary and host["session"].state == Session.State.HOSTING)
	var client := _branch("ClientHud", CLIENT_OFFSET, _tuning())
	await _frames(2)
	var ch: NetHud = client["net_hud"]
	var guide = client["hud"].guide()
	var cp = client["player"]
	ch.toggle()
	var roast_before: bool = client["hud"].guide().session_link().roast_on()
	await _key(KEY_J, 0x6A)
	var box_open: bool = ch.is_typing() and cp.input_blocked and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and guide.other_box_open
	await _key(KEY_T, 0x74)
	await _key(KEY_O, 0x6F)
	await _key(KEY_B, 0x62)
	var letters: String = ch.get("_edit").text
	var guide_quiet: bool = not guide.is_typing() and not guide.is_asking_consent()
	await _key(KEY_ESCAPE)
	await _key(KEY_J, 0x6A)
	await _type("127.0.0.1:%d" % port)
	var typed: String = ch.get("_edit").text
	await _key(KEY_ENTER)
	var joined := await _joined(host, client)
	await _frames(2)
	print("NET HUD joiner panel:\n", ch.panel_text())
	_check("J opens the address box: the mouse is free, the player takes no input, T, O and B are just letters in it; Enter joins", box_open and letters == "tob" and guide_quiet and client["hud"].guide().session_link().roast_on() == roast_before and typed == "127.0.0.1:%d" % port and joined and not ch.is_typing() and not cp.input_blocked and not guide.other_box_open and ch.is_open(), "box %s letters '%s' quiet %s typed '%s' joined %s" % [box_open, letters, guide_quiet, typed, joined])
	_check("the joiner's panel and both net lines show the session", ch.panel_text().contains("Joined 127.0.0.1:%d.\nplayers 2/2: player 1, player 2 (you)" % port) and ch.panel_text().ends_with(NetHud.JOINED_KEYS) and ch.line_text() == NetHud.NET_JOINED % [2, 2] and hh.line_text() == NetHud.NET_HOSTING % [port, 2, 2], ch.panel_text().c_escape())
	await _key(KEY_L, 0x6C)
	var left := await _until(func(): return host["session"].players.size() == 1)
	await _frames(2)
	_check("L leaves: the joiner is off, the host is alone again", left and client["session"].state == Session.State.OFF and ch.line_text() == NetHud.NET_OFF and hh.line_text() == NetHud.NET_HOSTING % [port, 1, 2], "%s | %s" % [ch.line_text(), hh.line_text()])
	await _key(KEY_J, 0x6A)
	await _key(KEY_ESCAPE)
	var cancelled: bool = not ch.is_typing() and not cp.input_blocked and ch.is_open()
	ch.focus_check = func(): return true
	await _key(KEY_J, 0x6A)
	await _key(KEY_ESCAPE)
	_check("Esc cancels the address box, and with focus the mouse is captured again", cancelled and ch.recaptures() == 1)
	await _key(KEY_ESCAPE)
	_check("Esc closes the panel", not ch.is_open())
	ch.toggle()
	await _key(KEY_J, 0x6A)
	await _type("127.0.0.1:1")
	await _key(KEY_ENTER)
	await _until(func(): return client["session"].state == Session.State.FAILED)
	await _frames(2)
	var shown: String = ch.panel_text()
	_check("a failed join shows its reason in the panel and on the line", shown.contains("\n" + Session.CANT_REACH + "\n") and ch.line_text() == "net: " + Session.CANT_REACH, shown.c_escape())
	await _drop(client)
	await _drop(host)


## A UDP port on 127.0.0.1 the system has just handed out and given back.
func _free_port() -> int:
	var spare := PacketPeerUDP.new()
	spare.bind(0, "127.0.0.1")
	var port := spare.get_local_port()
	spare.close()
	return port


func _layout_checks() -> void:
	var before := root.size
	for size in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = size
		var host := _branch("Layout", Vector3.ZERO, _tuning())
		await _frames(2)
		host["session"].host(0)
		var nh: NetHud = host["net_hud"]
		nh.toggle()
		await _frames(3)
		var screen := Rect2(Vector2.ZERO, Vector2(root.size))
		var panel: Rect2 = nh.get("_panel").get_global_rect()
		var wrong := PackedStringArray()
		var shown := 0
		for label in host["main"].find_children("*", "Label", true, false):
			if not label.is_visible_in_tree() or label.text.is_empty():
				continue
			shown += 1
			var rect: Rect2 = label.get_global_rect()
			if not screen.encloses(rect):
				wrong.append("outside: %s %s" % [label.text.left(20), rect])
			if rect.size.x < screen.size.x and not nh.get("_panel").is_ancestor_of(label) and panel.intersects(rect):
				wrong.append("under the panel: %s %s" % [label.text.left(20), rect])
		_check("at %dx%d the panel while hosting and every HUD label sit inside the screen, and the panel covers no other line" % [size.x, size.y], shown >= 8 and wrong.is_empty(), "%d shown; %s" % [shown, ", ".join(wrong)])
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
