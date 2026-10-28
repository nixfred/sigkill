extends SceneTree
## Headless room code test for SIGKILL (C15). scripts/check.sh runs it, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/room_test.gd
##
## Room codes, invite links and the rendezvous interface. The game's own rendezvous,
## NullRendezvous, is checked to send nothing at all. The live cases use the test-only fake
## in tests/support/fake_rendezvous.gd: a server and clients in this one process on
## 127.0.0.1, with the C13 harness for the game sides (each its own tree branch,
## SceneMultiplayer, NetSession and real arena, ENet on 127.0.0.1 on ports the system hands
## out). Nothing here reaches past 127.0.0.1.

const Session = preload("res://scripts/net/net_session.gd")
const RoomCode = preload("res://scripts/net/room_code.gd")
const NullRendezvous = preload("res://scripts/net/null_rendezvous.gd")
const RoomTuningScript = preload("res://scripts/net/room_tuning.gd")
const NetTuningScript = preload("res://scripts/net/net_tuning.gd")
const NetHud = preload("res://scripts/net/net_hud.gd")
const Fake = preload("res://tests/support/fake_rendezvous.gd")
const Controls = preload("res://scripts/controls.gd")
const MainScene = preload("res://scenes/main.tscn")
const WATCHDOG_MS := 10000
const CLIENT_OFFSET := Vector3(1000.0, 0.0, 0.0)
const ROOM_SOURCES := ["res://scripts/net/room_code.gd", "res://scripts/net/rendezvous_client.gd", "res://scripts/net/null_rendezvous.gd", "res://scripts/net/room_tuning.gd"]
const SOURCE_NEVER := ["PacketPeer", "StreamPeer", "TCPServer", "UDPServer", "HTTPRequest", "HTTPClient", "ENet", "WebSocket", "WebRTC", "IP.", "OS.", "Time.", "randi", "randf", "RandomNumberGenerator", "FileAccess", "DirAccess", "JSON", "hash("]

var _fails := 0
var _checks := 0
var _branches: Array = []
var _server: Fake.Server
var _server_port := 0


func _initialize() -> void:
	GameSettings.current().set_value("gameplay", "practice", true)  # these checks predate C27b: the daemons stay the old never-attack dummies
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	Controls.ensure()
	_server = Fake.Server.new()
	_server.name = "FakeRendezvous"
	root.add_child(_server)
	_server_port = _server.listen()
	if _server_port == 0:
		print("FAIL the fake rendezvous could not listen on 127.0.0.1")
		quit(1)
		return
	_tuning_checks()
	_source_checks()
	_code_checks()
	_link_checks()
	_arg_checks()
	await _null_checks()
	await _live_checks()
	await _error_checks()
	await _expiry_checks()
	await _edge_checks()
	await _launch_checks()
	await _panel_checks()
	await _unchanged_checks()
	await _layout_checks()
	await _cleanup()
	print("ROOM: %d checks" % _checks)
	print("ROOM RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
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


func _room_tuning(timeout_ms: int = 1000) -> Resource:
	var t := RoomTuningScript.new()
	t.request_timeout_ms = timeout_ms
	return t


func _client() -> Fake.Client:
	var c := Fake.Client.new(_server_port)
	c.timeout_ms = 2000
	return c


## A side of the game in its own branch: {branch, session, main, player, hud, net_hud}.
## `rv` is the rendezvous handed in (null: the game's own, NullRendezvous).
func _branch(name: String, offset: Vector3, rv: RefCounted = null, arena: bool = true, protocol: int = Session.PROTOCOL) -> Dictionary:
	var api := SceneMultiplayer.new()
	var branch := Node3D.new()
	branch.name = name
	branch.position = offset
	root.add_child(branch)
	set_multiplayer(api, branch.get_path())
	var session := Session.new()
	session.name = Session.NODE_NAME
	session.tuning = _net_tuning()
	session.room_tuning = _room_tuning()
	session.rendezvous = rv
	session.protocol = protocol
	branch.add_child(session)
	_branches.append(branch)
	var out := {"branch": branch, "session": session, "rv": rv}
	if not arena:
		return out
	var main = MainScene.instantiate()
	branch.add_child(main)
	out["main"] = main
	out["player"] = main.get_node("Player")
	out["hud"] = main.get_node("Hud")
	out["net_hud"] = main.get_node("Hud").net_hud()
	out["player"].assume_captured = true
	main.get_node("Hud").guide().focus_check = func(): return false
	out["net_hud"].focus_check = func(): return false
	return out


func _drop(side: Dictionary) -> void:
	var branch: Node = side["branch"]
	if is_instance_valid(branch):
		for sfx in branch.find_children("*", "AudioStreamPlayer", true, false):
			(sfx as AudioStreamPlayer).stop()
		side["session"].leave()
		branch.free()
	_branches.erase(branch)
	if side.get("rv") is Fake.Client:
		side["rv"].shut()
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


## Lets the fake server read anything still in its socket (a CLOSE from a dropped branch),
## then empties its log.
func _fresh_log() -> void:
	await _frames(3)
	_server.log.clear()


func _key(keycode: Key, unicode: int = 0) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.unicode = unicode
	down.pressed = true
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
		elif c >= 0x41 and c <= 0x5A:
			code = c as Key
		elif c == 0x3A:
			code = KEY_COLON
		elif c == 0x2F:
			code = KEY_SLASH
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


func _body(source: String, name: String) -> String:
	var at := source.find("\nfunc %s(" % name)
	if at < 0:
		at = source.find("\nstatic func %s(" % name)
	if at < 0:
		return ""
	var end := source.find("\nfunc ", at + 1)
	var end2 := source.find("\nstatic func ", at + 1)
	if end2 > 0 and (end < 0 or end2 < end):
		end = end2
	return source.substr(at, (end if end > 0 else source.length()) - at)


func _tuning_checks() -> void:
	var shipped = load("res://resources/room.tres")
	_check("the shipped room tuning: no relay URL, 10-minute codes, 4 s per request, 5 draws", shipped is RoomTuningScript and shipped.problems().is_empty() and shipped.relay_url == "" and shipped.code_ttl_s == 600 and shipped.request_timeout_ms == 4000 and shipped.register_attempts == 5, str(shipped.problems()) if shipped is RoomTuningScript else "")
	var bad := RoomTuningScript.new()
	bad.relay_url = "http://relay.example"
	bad.code_ttl_s = 5
	bad.request_timeout_ms = 100
	bad.register_attempts = 0
	var issues: PackedStringArray = bad.problems()
	_check("bad tuning is refused and the shipped one used: a plain-http URL, 5-second codes, 100 ms requests, no draws", issues.size() == 4 and Session.usable_room_tuning(bad) == shipped, ", ".join(issues))
	# C16c: the relay is a UDP service, so its URL is udp://host[:port] (was https only in C15).
	_check("relay URLs: empty or udp://host[:port] only, no path, spaces or control characters", RoomTuningScript.url_ok("") and RoomTuningScript.url_ok("udp://relay.example") and RoomTuningScript.url_ok("udp://relay.example:9010") and RoomTuningScript.url_ok("udp://127.0.0.1:9010") and not RoomTuningScript.url_ok("https://relay.example/v1") and not RoomTuningScript.url_ok("udp://") and not RoomTuningScript.url_ok("udp://relay .example") and not RoomTuningScript.url_ok("ftp://relay.example") and not RoomTuningScript.url_ok("udp://relay.example/v1") and not RoomTuningScript.url_ok("udp://relay.example:0") and not RoomTuningScript.url_ok("udp://relay.example:" + char(0x07)))


func _source_checks() -> void:
	var all := ""
	for path in ROOM_SOURCES:
		all += _code(path)
	var found := PackedStringArray()
	for word in SOURCE_NEVER:
		if all.contains(word):
			found.append(word)
	_check("room codes, the rendezvous interface, NullRendezvous and RoomTuning open no socket, look nothing up, read no file, ask the system nothing, read no clock and use no ordinary random numbers", found.is_empty(), ", ".join(found))
	var code_src := _code("res://scripts/net/room_code.gd")
	var gen := _body(code_src, "generate")
	_check("a code is drawn from the engine's cryptographic random bytes and nothing else", gen.contains("Crypto.new()") and gen.contains("generate_random_bytes(") and not gen.contains("name") and not gen.contains("address"))
	var session := _code("res://scripts/net/net_session.gd")
	var factory := _body(session, "rendezvous_for")
	# C16c: a relay URL the player sets now gets the real UDP client; empty stays NullRendezvous.
	# C16d: and ws:// or wss:// gets the WebSocket client, picked by the scheme alone.
	_check("rendezvous_for makes NullRendezvous with no relay URL and, by the URL's scheme, a UdpRendezvous or a WsRendezvous only for one, nothing else", factory.contains("if url == \"\":\n\t\treturn NullRendezvous.new()") and factory.contains("if RelayWire.transport_of(url) == \"ws\":\n\t\treturn WsRendezvous.new(url)") and factory.contains("return UdpRendezvous.new(url)") and factory.count("return") == 3 and not session.contains("Fake") and not session.contains("fake_rendezvous"))
	_check("the session's sockets are still exactly C13's: two ENet peers and the two port probes", session.count("ENetMultiplayerPeer.new()") == 2 and session.count("PacketPeerUDP.new()") == 2 and session.count("create_client(") == 1 and session.count("create_server(") == 1)
	var to_rv := PackedStringArray()
	for call in ["_rv.register(", "_rv.resolve(", "_rv.close("]:
		to_rv.append(str(session.count(call)))
	_check("what goes to a rendezvous: register(code, protocol, port) and resolve(code, protocol) in one place each; close(code, protocol, port) wherever a code is released: leaving, a fresh code, and an unanswered, timed-out, failed or zero-time registration, or a relay answer without its ports (C16c)", session.contains("_rv.register(code, protocol, _room_port)") and session.contains("_rv.resolve(code, protocol)") and session.count("_rv.close(room_code, protocol, _room_port)") == 2 and session.count("_rv.close(_room_wanted, protocol, _room_port)") == 5 and Array(to_rv) == ["1", "1", "7"], ", ".join(to_rv))
	var keys := FileAccess.get_file_as_string("res://scripts/controls.gd")
	var users := PackedStringArray()
	for action in InputMap.get_actions():
		for event in InputMap.action_get_events(action):
			if event is InputEventKey and (event.physical_keycode == KEY_K or event.keycode == KEY_K) and not (event.ctrl_pressed or event.alt_pressed or event.meta_pressed):
				users.append(String(action))
	_check("K is the panel's own key, bound to no action, counted only while the panel is up", users.is_empty() and not keys.contains("KEY_K") and _code("res://scripts/net/net_hud.gd").contains("KEY_K:"), ", ".join(users))
	var main := _code("res://scripts/main.gd")
	_check("the arena reads --join from the game's own arguments once and opens the panel to show the result", main.contains("var launch_args: PackedStringArray = OS.get_cmdline_user_args()") and main.contains("session.take_launch_join(launch_args)") and main.contains("_hud.net_hud().open()"))
	var nothing_installed := true
	for word in ["xdg-mime", "update-desktop-database", ".desktop", "x-scheme-handler", "register_protocol"]:
		for path in ["res://scripts/net/room_code.gd", "res://scripts/net/net_session.gd", "res://scripts/main.gd", "res://scripts/net/net_hud.gd", "res://project.godot"]:
			nothing_installed = nothing_installed and not FileAccess.get_file_as_string(path).contains(word)
	_check("no URL handler, .desktop file or xdg-mime entry anywhere: sigkill:// links are read from the arguments only", nothing_installed)


func _code_checks() -> void:
	var codes := {}
	var bad := PackedStringArray()
	var seen := {}
	for i in 2000:
		var c := RoomCode.generate()
		codes[c] = true
		if RoomCode.problem(c) != "" or c.length() != 6:
			bad.append(c)
		for ch in c:
			if "01ILO".contains(ch):
				bad.append(c)
		for j in 5:
			seen[c[j]] = true
	_check("2000 drawn codes: all 6 characters, all valid, none with 0, O, 1, I or L, nearly all different, every one of the 31 symbols used", bad.is_empty() and codes.size() >= 1995 and seen.size() == 31 and RoomCode.ALPHABET.length() == 31, "bad %s, distinct %d, symbols %d" % [bad.slice(0, 3), codes.size(), seen.size()])
	var subs := 0
	var swaps := 0
	var caught := 0
	var sample := codes.keys().slice(0, 60)
	for c in sample:
		for i in 6:
			for x in RoomCode.ALPHABET:
				if x == c[i]:
					continue
				subs += 1
				if RoomCode.problem(c.substr(0, i) + x + c.substr(i + 1)) != "":
					caught += 1
		for i in 5:
			if c[i] == c[i + 1]:
				continue
			swaps += 1
			if RoomCode.problem(c.substr(0, i) + c[i + 1] + c[i] + c.substr(i + 2)) != "":
				caught += 1
	_check("the checksum catches every single mistyped character and every swap of neighbours, before any network call", caught == subs + swaps and subs == 60 * 6 * 30, "%d of %d caught" % [caught, subs + swaps])
	var forms := {" abc-23p ": "ABC23P", "ABC 23P": "ABC23P", "a-b-c-2-3-p": "ABC23P", "abc23p": "ABC23P"}
	var wrong := PackedStringArray()
	for text in forms:
		var p := RoomCode.parse_code(text)
		if p.get("code", "") != forms[text]:
			wrong.append("%s -> %s" % [text, p])
	_check("spaces, dashes and lower case are forgiven", wrong.is_empty(), "; ".join(wrong))
	var errors := {
		"ABC23": RoomCode.NOT_A_CODE % 6, "ABC23PP": RoomCode.NOT_A_CODE % 6, "": RoomCode.NOT_A_CODE % 6,
		"ABC2OP": RoomCode.BAD_CHARACTER, "ABC20P": RoomCode.BAD_CHARACTER, "ABC2IP": RoomCode.BAD_CHARACTER, "ABC2LP": RoomCode.BAD_CHARACTER, "ABC21P": RoomCode.BAD_CHARACTER, "AB_23P": RoomCode.BAD_CHARACTER,
		"ABC23Q": RoomCode.TYPO % "ABC23Q", "BAC23P": RoomCode.TYPO % "BAC23P", "x".repeat(200): RoomCode.NOT_A_CODE % 6,
	}
	for text in errors:
		var p := RoomCode.parse_code(text)
		if p.get("error", "") != errors[text]:
			wrong.append("%s -> %s" % [text.left(12), p])
	_check("refused with the reason: too short or long, a 0, O, 1, I, L or other character, a typo (one wrong, two swapped)", wrong.is_empty(), "; ".join(wrong))
	_check("the README example ABC23P and the other doc examples are valid codes", RoomCode.problem("ABC23P") == "" and RoomCode.problem("K7R2MX") == "" and RoomCode.problem(RoomCode.EXAMPLE) == "")


func _link_checks() -> void:
	var good := {"sigkill://join/ABC23P": "ABC23P", "sigkill://join/abc23p": "ABC23P", " sigkill://join/K7R2MX ": "K7R2MX"}
	var wrong := PackedStringArray()
	for text in good:
		var p := RoomCode.parse_join(text)
		if p.get("code", "") != good[text]:
			wrong.append("%s -> %s" % [text, p])
	var bad := {
		"https://join/ABC23P": RoomCode.NOT_A_LINK, "sigkill://host/ABC23P": RoomCode.NOT_A_LINK, "SIGKILL://join/ABC23P": RoomCode.NOT_A_LINK,
		"sigkill:/join/ABC23P": RoomCode.NOT_A_CODE % 6, "sigkill://user@join/ABC23P": RoomCode.NOT_A_LINK, "sigkill://join/": RoomCode.LINK_TAIL,
		"sigkill://join/ABC23P/": RoomCode.LINK_TAIL, "sigkill://join/ABC23P?x=1": RoomCode.LINK_TAIL, "sigkill://join/ABC23P#top": RoomCode.LINK_TAIL,
		"sigkill://join/ABC-23P": RoomCode.LINK_TAIL, "sigkill://join/AB 23P": RoomCode.LINK_TAIL, "sigkill://join/ABC23Q": RoomCode.TYPO % "ABC23Q",
		"sigkill://join/ABC2OP": RoomCode.BAD_CHARACTER, "sigkill://join/" + "A".repeat(80): RoomCode.NOT_A_LINK,
	}
	for text in bad:
		var p := RoomCode.parse_join(text)
		if p.get("error", "") != bad[text]:
			wrong.append("%s -> %s" % [text.left(30), p])
	_check("links: exactly sigkill://join/<CODE>; another scheme or path, a slash, query or fragment after the code, a dash or space inside, a typo or a wrong character are refused with the reason", wrong.is_empty(), "; ".join(wrong))
	_check("the invite link for a code", RoomCode.link("ABC23P") == "sigkill://join/ABC23P")


func _arg_checks() -> void:
	var cases := [
		[[], {}], [["--demo"], {}], [["--join", "sigkill://join/ABC23P"], {"code": "ABC23P"}], [["--demo", "--join", "abc-23p"], {"code": "ABC23P"}],
		[["--join"], {"error": RoomCode.JOIN_NEEDS}], [["--join", "--demo"], {"error": RoomCode.JOIN_NEEDS}], [["--join=ABC23P"], {"error": RoomCode.JOIN_FORM}],
		[["--join", "ABC23P", "--join", "K7R2MX"], {"error": RoomCode.JOIN_TWICE}], [["--join", "127.0.0.1"], {"error": RoomCode.NOT_A_CODE % 6}],
		[["--join", "http://relay.example/ABC23P"], {"error": RoomCode.NOT_A_LINK}], [["--join", "ABC23Q"], {"error": RoomCode.TYPO % "ABC23Q"}],
	]
	var wrong := PackedStringArray()
	for case in cases:
		var got := RoomCode.parse_args(PackedStringArray(case[0]))
		if got != case[1]:
			wrong.append("%s -> %s" % [case[0], got])
	_check("--join from the game's arguments: a link or a code (forgiving spaces, dashes, case), and anything else refused with the reason: no value, --join=, twice, an address, another link, a typo", wrong.is_empty(), "; ".join(wrong))


## The game's own rendezvous: never live, nothing sent.
func _null_checks() -> void:
	var side := _branch("Null", Vector3.ZERO)
	await _frames(2)
	var s: Session = side["session"]
	var rv = s.rendezvous_in_use()
	_check("with no rendezvous handed in, the session uses NullRendezvous, which is not live", rv.get_script() == NullRendezvous and not rv.is_live() and rv.requests() == 0)
	var with_url := RoomTuningScript.new()
	with_url.relay_url = "https://relay.example/v1"
	var from_url = Session.rendezvous_for(with_url)
	_check("a URL that is not a relay URL (https) gives NullRendezvous: no network client", from_url.get_script() == NullRendezvous and not from_url.is_live())
	s.join_room("ABC23Q")
	var typo: String = s.error
	s.join_room("ABC23P")
	var not_live: String = s.error
	_check("a typo is refused as a typo; a good code gets the not-live line, word for word, and no peer is made", typo == RoomCode.TYPO % "ABC23Q" and not_live == "Online rooms aren't live yet. Use LAN join (address)." and s.state == Session.State.FAILED and s.get("_enet") == null and rv.requests() == 0, not_live)
	s.host(0)
	await _frames(3)
	var panel: NetHud = side["net_hud"]
	panel.open()
	await _frames(2)
	print("ROOM null host panel:\n", panel.panel_text())
	_check("hosting with NullRendezvous: no room code, no room line, the C13 panel as before, still no request", s.state == Session.State.HOSTING and s.room_code == "" and not panel.panel_text().contains("Room code") and not panel.panel_text().contains("room code") and panel.line_text() == NetHud.NET_HOSTING % [s.listen_port(), 1, 2] and rv.requests() == 0)
	s.leave()
	await _drop(side)


## A live (fake) rendezvous on 127.0.0.1: the host registers, a joiner resolves and joins.
func _live_checks() -> void:
	await _fresh_log()
	var host := _branch("Host", Vector3.ZERO, _client())
	var joiner := _branch("Joiner", CLIENT_OFFSET, _client())
	await _frames(2)
	var hs: Session = host["session"]
	var js: Session = joiner["session"]
	hs.host(0)
	var registered := await _until(func(): return hs.room_code != "")
	var code: String = hs.room_code
	var reg: Dictionary = _server.log[0] if not _server.log.is_empty() else {}
	print("ROOM register as the rendezvous saw it: ", reg)
	_check("the host draws a code and registers it: the rendezvous gets the code, the protocol and the game port, and sees the address 127.0.0.1", registered and RoomCode.problem(code) == "" and reg.get("op", 0) == Fake.Op.REGISTER and reg.get("code", "") == code and reg.get("protocol", 0) == Session.PROTOCOL and reg.get("port", 0) == hs.listen_port() and reg.get("from", "") == "127.0.0.1" and reg.get("size", 0) == Fake.REQUEST_SIZE)
	host["net_hud"].open()
	await _frames(2)
	var panel: String = host["net_hud"].panel_text()
	print("ROOM live host panel:\n", panel)
	_check("H shows the room code and its invite link, with the time it has left; the net line shows the code", (panel.contains("Room code %s   invite sigkill://join/%s   (new code in 10:00)" % [code, code]) or panel.contains("Room code %s   invite sigkill://join/%s   (new code in 9:5" % [code, code])) and host["net_hud"].line_text() == NetHud.NET_HOSTING % [hs.listen_port(), 1, 2] + NetHud.NET_ROOM % code)
	js.join_room(" " + code.to_lower().insert(3, "-") + " ")
	var in_lookup: bool = js.state == Session.State.ROOM
	var joined := await _until(func(): return js.state == Session.State.JOINED and hs.players.size() == 2)
	var res: Dictionary = _server.log[1] if _server.log.size() > 1 else {}
	print("ROOM resolve as the rendezvous saw it: ", res, "; joiner state %s, players %s" % [js.state_word(), js.roster_text()])
	_check("a joiner types the code (any case, with a dash): resolved to 127.0.0.1 and the host's port, then joined by the C13 path, roster and all", in_lookup and joined and res.get("op", 0) == Fake.Op.RESOLVE and res.get("code", "") == code and res.get("port", -1) == 0 and js.address_text == "room " + code and js.roster_text() == "Daemon-1, Daemon-2 (you)")
	var fields_ok := true
	for entry in _server.log:
		fields_ok = fields_ok and entry.keys() == ["op", "code", "protocol", "port", "from", "size"] and entry["size"] == Fake.REQUEST_SIZE
	_check("every request carried exactly a code, a protocol version and a port, in 14 fixed bytes: nothing else fits", fields_ok and _server.log.size() == 2, str(_server.log.size()))
	var sent_bytes: Array = joiner["rv"].sent + host["rv"].sent
	var leak := false
	for data in sent_bytes:
		var text: String = data.get_string_from_ascii()
		for word in ["Daemon", "player", "127.0.0.1", "claude", "codex"]:
			leak = leak or text.contains(word)
	_check("no name, address or AI word in any byte sent", not leak)
	# The host leaves: its code is released.
	hs.leave()
	await _until(func(): return not _server.rooms.has(code))
	var after := _client()
	after.resolve(code, Session.PROTOCOL)
	var answer: Array = [{}]
	await _until(func():
		answer[0] = after.poll()
		return not answer[0].is_empty())
	var gone: Dictionary = answer[0]
	after.shut()
	_check("the host leaving releases its code: it no longer resolves", not _server.rooms.has(code) and gone.get("error", "") == "unknown", str(gone))
	await _drop(joiner)
	await _drop(host)


func _error_checks() -> void:
	var side := _branch("Errors", CLIENT_OFFSET, _client(), false)
	await _frames(2)
	var s: Session = side["session"]
	var rv: Fake.Client = side["rv"]
	await _fresh_log()
	var lines := PackedStringArray()
	# A typo never reaches the rendezvous.
	s.join_room("K7R2MZ")
	_check("a typo is refused before any network call", s.error == RoomCode.TYPO % "K7R2MZ" and rv.requests() == 0 and _server.log.is_empty())
	lines.append(s.error)
	# Unknown: a good code nobody holds.
	s.join_room("K7R2MX")
	await _until(func(): return s.state == Session.State.FAILED)
	lines.append(s.error)
	_check("an unknown code: \"no open room with code K7R2MX\"", s.error == Session.ROOM_UNKNOWN % "K7R2MX")
	# Another version.
	var other := _branch("OtherHost", Vector3.ZERO, _client(), true, Session.PROTOCOL + 1)
	await _frames(2)
	other["session"].host(0)
	await _until(func(): return other["session"].room_code != "")
	var other_code: String = other["session"].room_code
	s.join_room(other_code)
	await _until(func(): return s.state == Session.State.FAILED)
	lines.append(s.error)
	_check("a room on another version: the rendezvous says so before any connection", s.error == "version mismatch: host %d, you %d" % [Session.PROTOCOL + 1, Session.PROTOCOL] and s.get("_enet") == null)
	await _drop(other)
	# Busy, then no answer at all.
	_server.busy = true
	s.join_room("K7R2MX")
	await _until(func(): return s.state == Session.State.FAILED)
	lines.append(s.error)
	_server.busy = false
	_check("a busy rendezvous: try again in a moment", s.error == Session.ROOM_BUSY)
	_server.silent = true
	var t0 := Engine.get_physics_frames()
	s.join_room("K7R2MX")
	await _until(func(): return s.state == Session.State.FAILED)
	var frames := Engine.get_physics_frames() - t0
	lines.append(s.error)
	_server.silent = false
	_check("no answer: given up on the request timeout (1 s here) with \"couldn't reach the room service\", nothing left in flight", s.error == Session.ROOM_UNREACHABLE and absi(frames - 60) <= 3 and not rv.is_busy(), "%d frames" % frames)
	# Esc while looking a code up: off at once.
	_server.silent = true
	s.join_room("K7R2MX")
	await _frames(3)
	s.leave()
	_server.silent = false
	_check("cancelling a lookup: off at once, nothing in flight", s.state == Session.State.OFF and not rv.is_busy() and s.error == "")
	print("ROOM errors as shown: ", " | ".join(lines))
	await _drop(side)
	# A taken code: the host draws another.
	await _fresh_log()
	_server.force_taken = 2
	var host := _branch("TakenHost", Vector3.ZERO, _client(), false)
	await _frames(2)
	host["session"].host(0)
	var got := await _until(func(): return host["session"].room_code != "")
	var drawn := PackedStringArray()
	for entry in _server.log:
		drawn.append(entry["code"])
	_check("a code that is taken is redrawn: three registrations, three different codes, the third one kept", got and drawn.size() == 3 and drawn[0] != drawn[1] and drawn[1] != drawn[2] and host["session"].room_code == drawn[2], ", ".join(drawn))
	await _drop(host)
	_server.force_taken = 6
	await _fresh_log()
	var stubborn := _branch("Stubborn", Vector3.ZERO, _client())
	await _frames(2)
	stubborn["session"].host(0)
	stubborn["net_hud"].open()
	await _until(func(): return stubborn["session"].notice != "")
	await _frames(30)
	var stubborn_panel: String = stubborn["net_hud"].panel_text()
	_server.force_taken = 0
	var gave_up: String = stubborn["session"].notice
	var registrations := 0
	for entry in _server.log:
		if entry["op"] == Fake.Op.REGISTER:
			registrations += 1
	_check("after exactly five taken codes the host stops drawing and says so, and asks no more; it keeps hosting, and LAN join still works", stubborn["session"].room_code == "" and gave_up == Session.ROOM_NO_CODE % Session.ROOM_ALL_TAKEN and stubborn["session"].state == Session.State.HOSTING and registrations == 5 and _server.log.size() == 5, "%s; %d registrations" % [gave_up, registrations])
	_check("after giving up, the panel shows why and no longer says a code is coming", stubborn_panel.contains(gave_up) and not stubborn_panel.contains(NetHud.ROOM_WAIT_LINE) and not stubborn["session"].is_getting_room_code(), stubborn_panel.c_escape())
	await _drop(stubborn)


func _expiry_checks() -> void:
	# A code past its time on the rendezvous's clock is refused as expired.
	var host := _branch("ExpiryHost", Vector3.ZERO, _client(), false)
	var s: Session = host["session"]
	await _frames(2)
	s.host(0)
	await _until(func(): return s.room_code != "")
	var old: String = s.room_code
	_server.clock_offset_s += 601.0
	var joiner := _branch("Late", CLIENT_OFFSET, _client(), false)
	await _frames(2)
	joiner["session"].join_room(old)
	await _until(func(): return joiner["session"].state == Session.State.FAILED)
	_check("a code past its 10 minutes is refused as expired", joiner["session"].error == Session.ROOM_EXPIRED % old and joiner["session"].get("_enet") == null, joiner["session"].error)
	await _drop(joiner)
	await _drop(host)
	# The host's own timer: a code given for 2 s is replaced after 2 s, and the old one released.
	_server.ttl_s = 2
	var renew := _branch("RenewHost", Vector3.ZERO, _client(), false)
	var rs: Session = renew["session"]
	await _frames(2)
	rs.host(0)
	await _until(func(): return rs.room_code != "")
	var first: String = rs.room_code
	var left_first: float = rs.room_expires_s
	var renewed := await _until(func(): return rs.room_code != "" and rs.room_code != first, 6000)
	var second: String = rs.room_code
	await _until(func(): return not _server.rooms.has(first))
	_check("a code lives as long as the rendezvous gives (2 s here), then the host releases it and shows a fresh one", left_first <= 2.0 and left_first > 1.5 and renewed and RoomCode.problem(second) == "" and not _server.rooms.has(first) and _server.rooms.has(second), "%s -> %s" % [first, second])
	await _drop(renew)
	_server.ttl_s = 600
	# The game's own cap: a rendezvous offering more than code_ttl_s is held to it.
	var capped := _branch("Capped", Vector3.ZERO, _client(), false)
	capped["session"].room_tuning.code_ttl_s = 30
	await _frames(2)
	capped["session"].host(0)
	await _until(func(): return capped["session"].room_code != "")
	_check("a rendezvous offering 10 minutes is held to the tuning's 30 s", capped["session"].room_expires_s <= 30.0 and capped["session"].room_expires_s > 29.0, str(capped["session"].room_expires_s))
	await _drop(capped)


## Room requests cut short, odd answers, and addresses outside the LAN.
func _edge_checks() -> void:
	# Leaving before the registration is answered: the code is released all the same.
	await _fresh_log()
	var quick := _branch("Quick", Vector3.ZERO, _client(), false)
	await _frames(2)
	quick["session"].host(0)
	quick["session"].leave()
	await _frames(6)
	var drawn: String = _server.log[0]["code"] if not _server.log.is_empty() else ""
	_check("leaving before the registration is answered still releases the code the rendezvous took", drawn != "" and _server.log[0]["op"] == Fake.Op.REGISTER and not _server.rooms.has(drawn) and _server.log.size() == 2 and _server.log[1]["op"] == Fake.Op.CLOSE and _server.log[1]["code"] == drawn, str(_server.log))
	await _drop(quick)
	# A registration whose answer is lost: given up on the timeout, and released.
	await _fresh_log()
	_server.mute = true
	var lost := _branch("Lost", Vector3.ZERO, _client())
	await _frames(2)
	lost["session"].host(0)
	lost["net_hud"].open()
	await _frames(2)
	var waiting_panel: String = lost["net_hud"].panel_text()
	var waiting: bool = lost["session"].is_getting_room_code()
	await _until(func(): return lost["session"].notice != "")
	await _frames(4)
	_server.mute = false
	var lost_panel: String = lost["net_hud"].panel_text()
	_check("while the registration is in flight the panel says a code is coming; once it is given up, it says why instead", waiting and waiting_panel.contains(NetHud.ROOM_WAIT_LINE) and not lost_panel.contains(NetHud.ROOM_WAIT_LINE) and lost_panel.contains(lost["session"].notice) and not lost["session"].is_getting_room_code(), "%s | %s" % [waiting_panel.c_escape(), lost_panel.c_escape()])
	var took: String = _server.log[0]["code"] if not _server.log.is_empty() else ""
	_check("a registration whose answer is lost: the host gives up on the timeout, says so, and releases the code", took != "" and lost["session"].notice == Session.ROOM_NO_CODE % Session.ROOM_UNREACHABLE and lost["session"].room_code == "" and not _server.rooms.has(took), "%s %s" % [lost["session"].notice, _server.log])
	await _drop(lost)
	# A lost reply where the client gives up first (its own timeout, shorter than the session's):
	# released the same way.
	await _fresh_log()
	_server.mute = true
	var quick_client := _client()
	# Real milliseconds: game time runs far ahead of real time here, so the client's own
	# timeout must be tiny to come first.
	quick_client.timeout_ms = 1
	var impatient := _branch("Impatient", Vector3.ZERO, quick_client, false)
	impatient["session"].room_tuning_in_use().request_timeout_ms = 30000  # the session waits far longer than the client
	await _frames(2)
	impatient["session"].host(0)
	await _until(func(): return impatient["session"].notice != "")
	await _frames(4)
	_server.mute = false
	var held: String = _server.log[0]["code"] if not _server.log.is_empty() else ""
	_check("a lost reply the client gives up on first: the notice, and the code released", held != "" and impatient["session"].notice == Session.ROOM_NO_CODE % Session.ROOM_UNREACHABLE and not _server.rooms.has(held) and _server.log.size() == 2 and _server.log[1]["op"] == Fake.Op.CLOSE, "%s %s" % [impatient["session"].notice, _server.log])
	await _drop(impatient)
	# An ok answer that gives the code no time at all: refused and released.
	await _fresh_log()
	_server.left_override = 0
	var zero := _branch("Zero", Vector3.ZERO, _client(), false)
	await _frames(2)
	zero["session"].host(0)
	await _until(func(): return zero["session"].notice != "")
	await _frames(4)
	_server.left_override = -1
	var zero_code: String = _server.log[0]["code"] if not _server.log.is_empty() else ""
	_check("an ok answer with no time left: no code shown, the registration released", zero_code != "" and zero["session"].room_code == "" and zero["session"].notice == Session.ROOM_NO_CODE % Session.ROOM_BAD_REPLY and not _server.rooms.has(zero_code), "%s %s" % [zero["session"].notice, _server.log])
	await _drop(zero)
	# A rendezvous naming an address outside the LAN: refused, no connection made.
	var host := _branch("FarHost", Vector3.ZERO, _client(), false)
	await _frames(2)
	host["session"].host(0)
	await _until(func(): return host["session"].room_code != "")
	_server.address_override = "2001:db8::5"  # the IPv6 documentation range: a public address, no real host
	var joiner := _branch("FarJoiner", CLIENT_OFFSET, _client(), false)
	await _frames(2)
	joiner["session"].join_room(host["session"].room_code)
	await _until(func(): return joiner["session"].state == Session.State.FAILED)
	_server.address_override = ""
	_check("a room the rendezvous places outside the LAN or a tailnet is refused, and nothing connects", joiner["session"].error == Session.ROOM_NOT_LOCAL and joiner["session"].get("_enet") == null, joiner["session"].error)
	await _drop(joiner)
	await _drop(host)
	# Which addresses count as local. The IPv4 cases are built from their four numbers: they are
	# the private ranges themselves (RFC 1918, RFC 6598) and documentation space, not hosts.
	var v4 := func(a: int, b: int, c: int, d: int) -> String: return "%d.%d.%d.%d" % [a, b, c, d]
	var local := [v4.call(127, 0, 0, 1), v4.call(10, 1, 2, 3), v4.call(172, 16, 0, 1), v4.call(172, 31, 255, 254), v4.call(192, 168, 1, 20), v4.call(100, 64, 0, 1), v4.call(100, 127, 1, 1), v4.call(169, 254, 3, 4), "::1", "0:0:0:0:0:0:0:1", "::0:1", "0::1", "fd7a:115c:a1e0::1", "FD00::1", "fe80::1", "fe80:0:0::1", "::ffff:7f00:1", "::ffff:" + v4.call(10, 0, 0, 7)]
	var far := [v4.call(203, 0, 113, 5), v4.call(172, 32, 0, 1), v4.call(100, 128, 0, 1), v4.call(192, 169, 1, 1), v4.call(8, 8, 4, 4), "2001:db8::5", "fe00::1", "::ffff:1", "::2", "1::1", "::ffff:" + v4.call(8, 8, 4, 4), "not an ip", ""]
	var wrong := PackedStringArray()
	for ip in local:
		if not Session.local_address(ip):
			wrong.append("refused " + ip)
	for ip in far:
		if Session.local_address(ip):
			wrong.append("accepted " + ip)
	_check("local means loopback, the private ranges, the tailnet range and link-local, IPv4 and IPv6 in any spelling (expanded, compressed, upper case, IPv4-mapped); everything else is not", wrong.is_empty() and Session.ipv6_groups("0::1") == PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 1]) and Session.ipv6_groups("1::2::3").is_empty() and Session.ipv6_groups("12345::1").is_empty(), ", ".join(wrong))
	# A reply from anywhere but the server is ignored by the fake client.
	var probe := _client()
	var stranger := PacketPeerUDP.new()
	stranger.bind(0, "127.0.0.1")
	probe.resolve("K7R2MX", Session.PROTOCOL)
	var probe_port: int = probe.get("_udp").get_local_port()
	stranger.set_dest_address("127.0.0.1", probe_port)
	stranger.put_packet(Fake.Codec.reply_bytes(Fake.Status.OK, "K7R2MX", Session.PROTOCOL, 4444, 60, "127.0.0.1"))
	var answer: Array = [{}]
	await _until(func():
		answer[0] = probe.poll()
		return not answer[0].is_empty())
	stranger.close()
	probe.shut()
	_check("the test fake trusts answers only from its own server on 127.0.0.1", probe.strays >= 1 and answer[0].get("error", "") == "unknown", "%d strays, %s" % [probe.strays, answer[0]])


func _launch_checks() -> void:
	# --join taken before the session is ready, as on a real first launch (the arena makes the
	# session a frame late): kept, then applied once it is ready.
	var early := Session.new()
	early.name = Session.NODE_NAME
	var api := SceneMultiplayer.new()
	var branch := Node3D.new()
	branch.name = "Early"
	root.add_child(branch)
	set_multiplayer(api, branch.get_path())
	_branches.append(branch)
	early.tuning = _net_tuning()
	early.room_tuning = _room_tuning()
	var took_early := early.take_launch_join(PackedStringArray(["--join", "sigkill://join/ABC23P"]))
	var state_before: int = early.state
	branch.add_child(early)
	await _frames(2)
	_check("a --join that arrives before the session is ready is kept and applied once it is: no error, the not-live line", took_early and state_before == Session.State.OFF and early.state == Session.State.FAILED and early.error == NullRendezvous.NOT_LIVE)
	branch.free()
	_branches.erase(branch)
	await process_frame
	# The real first launch: an arena with --join and no session yet. The arena makes the
	# session (a frame late), hands it the arguments and opens the panel at once.
	var api2 := SceneMultiplayer.new()
	var fresh := Node3D.new()
	fresh.name = "FirstLaunch"
	root.add_child(fresh)
	set_multiplayer(api2, fresh.get_path())
	_branches.append(fresh)
	var main = MainScene.instantiate()
	main.launch_args = PackedStringArray(["--join", "sigkill://join/ABC23P"])
	fresh.add_child(main)
	var panel_at_once: String = main.get_node("Hud").net_hud().panel_text()
	await _frames(3)
	var made = fresh.get_node_or_null(Session.NODE_NAME)
	var panel_after: String = main.get_node("Hud").net_hud().panel_text()
	print("ROOM first launch panel:\n", panel_after)
	_check("first launch with --join and no session yet: the panel is up at once, the session made a frame later applies the join, the not-live line shows, no error", panel_at_once.begins_with("multiplayer") and made != null and made.state == Session.State.FAILED and made.error == NullRendezvous.NOT_LIVE and panel_after.contains("\n" + NullRendezvous.NOT_LIVE + "\n") and made.rendezvous_in_use().requests() == 0, panel_after.c_escape())
	for sfx in fresh.find_children("*", "AudioStreamPlayer", true, false):
		(sfx as AudioStreamPlayer).stop()
	fresh.free()
	_branches.erase(fresh)
	await process_frame
	var host := _branch("LaunchHost", Vector3.ZERO, _client(), false)
	await _frames(2)
	host["session"].host(0)
	await _until(func(): return host["session"].room_code != "")
	var code: String = host["session"].room_code
	var joiner := _branch("LaunchJoiner", CLIENT_OFFSET, _client(), false)
	await _frames(2)
	var js: Session = joiner["session"]
	var took := js.take_launch_join(PackedStringArray(["--join", RoomCode.link(code)]))
	var joined := await _until(func(): return js.state == Session.State.JOINED)
	var again := js.take_launch_join(PackedStringArray(["--join", RoomCode.link(code)]))
	_check("--join sigkill://join/<CODE> joins the room once per run", took and joined and not again and js.address_text == "room " + code)
	await _drop(joiner)
	await _drop(host)
	var plain := _branch("LaunchNull", Vector3.ZERO, null, false)
	await _frames(2)
	var ns: Session = plain["session"]
	var took_null := ns.take_launch_join(PackedStringArray(["--join", "ABC23P"]))
	_check("--join with NullRendezvous: the not-live line, nothing sent", took_null and ns.state == Session.State.FAILED and ns.error == NullRendezvous.NOT_LIVE and ns.rendezvous_in_use().requests() == 0)
	await _drop(plain)
	var bad := _branch("LaunchBad", Vector3.ZERO, null, false)
	await _frames(2)
	var took_bad: bool = bad["session"].take_launch_join(PackedStringArray(["--join"]))
	_check("a bad --join fails with the reason", took_bad and bad["session"].error == RoomCode.JOIN_NEEDS)
	var none := _branch("LaunchNone", Vector3.ZERO, null, false)
	await _frames(2)
	_check("no --join: nothing happens", not none["session"].take_launch_join(PackedStringArray(["--demo"])) and none["session"].state == Session.State.OFF)
	await _drop(none)
	await _drop(bad)


## K in the real panel: the room box, a code typed, the join; and with NullRendezvous.
func _panel_checks() -> void:
	var host := _branch("PanelHost", Vector3.ZERO, _client(), false)
	await _frames(2)
	host["session"].host(0)
	await _until(func(): return host["session"].room_code != "")
	var code: String = host["session"].room_code
	var joiner := _branch("PanelJoiner", CLIENT_OFFSET, _client())
	await _frames(2)
	var ch: NetHud = joiner["net_hud"]
	var cp = joiner["player"]
	ch.toggle()
	await _frames(1)
	var keys_line: String = ch.panel_text()
	await _key(KEY_K, 0x6B)
	var box: bool = ch.is_typing() and cp.input_blocked and ch.panel_text().begins_with(NetHud.ROOM_BOX_TITLE)
	await _type(code)
	await _key(KEY_ENTER)
	var joined := await _until(func(): return joiner["session"].state == Session.State.JOINED)
	await _frames(2)
	print("ROOM joiner panel:\n", ch.panel_text())
	_check("the panel lists K; K opens the room-code box with the mouse free and the player still; Enter joins the room", keys_line.contains("[K] room code") and box and joined and not ch.is_typing() and not cp.input_blocked and ch.panel_text().contains("Joined room %s." % code), ch.panel_text().c_escape())
	await _drop(joiner)
	await _drop(host)
	var plain := _branch("PanelNull", Vector3.ZERO)
	await _frames(2)
	var nh: NetHud = plain["net_hud"]
	nh.toggle()
	await _key(KEY_K, 0x6B)
	await _type("ABC23P")
	await _key(KEY_ENTER)
	await _frames(2)
	print("ROOM null panel after a code:\n", nh.panel_text())
	_check("with NullRendezvous, a code typed after K: the panel and the net line say online rooms aren't live yet, LAN join by address is the way", nh.panel_text().contains("\n" + NullRendezvous.NOT_LIVE + "\n") and nh.line_text() == "net: " + NullRendezvous.NOT_LIVE and plain["session"].rendezvous_in_use().requests() == 0)
	await _drop(plain)


## Solo and the C13 address join, untouched.
func _unchanged_checks() -> void:
	var solo := _branch("Solo", Vector3.ZERO)
	await _frames(3)
	var start: Vector3 = solo["player"].global_position
	for i in 30:
		solo["player"].drive_input(Vector2(0, -1))
		await physics_frame
	var moved: float = Vector2(solo["player"].global_position.x - start.x, solo["player"].global_position.z - start.z).length()
	_check("solo: off, no rendezvous request, the player moves as before", solo["session"].state == Session.State.OFF and solo["session"].rendezvous_in_use().requests() == 0 and moved > 2.0 and solo["net_hud"].line_text() == NetHud.NET_OFF)
	await _drop(solo)
	var host := _branch("AddrHost", Vector3.ZERO)
	var joiner := _branch("AddrJoiner", CLIENT_OFFSET)
	await _frames(2)
	host["session"].host(0)
	await _frames(2)
	joiner["session"].join("127.0.0.1:%d" % host["session"].listen_port())
	var joined := await _until(func(): return joiner["session"].state == Session.State.JOINED and host["session"].players.size() == 2)
	_check("join by address works as in C13, with NullRendezvous on both sides and no request", joined and joiner["session"].address_text == "127.0.0.1:%d" % host["session"].listen_port() and host["session"].room_code == "" and host["session"].rendezvous_in_use().requests() == 0)
	await _drop(joiner)
	await _drop(host)


func _layout_checks() -> void:
	var before := root.size
	for size in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = size
		var host := _branch("Layout", Vector3.ZERO, _client())
		await _frames(2)
		host["session"].host(0)
		await _until(func(): return host["session"].room_code != "")
		host["net_hud"].open()
		await _frames(3)
		var screen := Rect2(Vector2.ZERO, Vector2(root.size))
		var panel_node: PanelContainer = host["net_hud"].get("_panel")
		var panel: Rect2 = panel_node.get_global_rect()
		var wrong := PackedStringArray()
		var shown := 0
		for label in host["main"].find_children("*", "Label", true, false):
			if not label.is_visible_in_tree() or label.text.is_empty():
				continue
			shown += 1
			var rect: Rect2 = label.get_global_rect()
			if not screen.encloses(rect):
				wrong.append("outside: %s %s" % [label.text.left(20), rect])
			if rect.size.x < screen.size.x and not panel_node.is_ancestor_of(label) and panel.intersects(rect):
				wrong.append("under the panel: %s %s" % [label.text.left(20), rect])
		_check("at %dx%d the hosting panel with its room code and invite link, and every label, sit inside the screen, covering nothing" % [size.x, size.y], shown >= 8 and wrong.is_empty() and host["net_hud"].panel_text().contains("Room code"), "%d shown; %s" % [shown, ", ".join(wrong)])
		await _drop(host)
	root.size = before


func _cleanup() -> void:
	for branch in _branches.duplicate():
		if is_instance_valid(branch):
			var session = branch.get_node_or_null(Session.NODE_NAME)
			if session != null:
				session.leave()
			branch.free()
	if is_instance_valid(_server):
		_server.free()
	await process_frame
	OS.delay_msec(300)
	await process_frame
