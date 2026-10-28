extends SceneTree
## Headless relay test for SIGKILL (C16c). scripts/check.sh runs it, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/relay_test.gd
##
## The relay (relay/relay_server.gd under relay/relay_main.gd) runs as its own process, as it
## would on a server, bound to 127.0.0.1 only, on ports this test hands it; it is never bound
## to any other interface. Against the brief's four acceptance points:
## (1) a real host and a real joiner, each in its own branch of this process, register a room
## code with the relay, resolve it from a sigkill://join/ link and from the typed code, and
## play over it: positions both ways and a shot that lands, every datagram through the relay;
## (2) on a second relay with tight limits, the room cap, room expiry, the resolution rate limit
## and an oversize payload each trip, along with the cookie check, bad packets, a bad code,
## an unknown source, a wrong token and a full room, each also in the relay's own counters;
## (3) with no relay URL (the default) the game sends nothing anywhere: a sniffer on the
## default relay port and one on a port of its own get nothing, while the same sniffer,
## named as the relay, gets the request at once;
## (4) each relay process stops cleanly (exit 0) when told, and a bad setting stops it with
## exit 2. Its output never holds an address. Plus the wire format, the settings parser, the
## run script, and scans of what each part may do. Nothing outside 127.0.0.1 is touched.

const Session = preload("res://scripts/net/net_session.gd")
const NetTuningScript = preload("res://scripts/net/net_tuning.gd")
const CombatTuningScript = preload("res://scripts/net/combat_tuning.gd")
const RoomTuningScript = preload("res://scripts/net/room_tuning.gd")
const RoomCode = preload("res://scripts/net/room_code.gd")
const RelayWire = preload("res://scripts/net/relay_wire.gd")
const UdpRendezvous = preload("res://scripts/net/udp_rendezvous.gd")
const NullRendezvous = preload("res://scripts/net/null_rendezvous.gd")
const RelayServer = preload("res://relay/relay_server.gd")
const Link = preload("res://scripts/guide/guide_link.gd")
const Controls = preload("res://scripts/controls.gd")
const MainScene = preload("res://scenes/main.tscn")
const LOCALHOST := "127.0.0.1"
const WATCHDOG_MS := 10000
const CLIENT_OFFSET := Vector3(1000.0, 0.0, 0.0)
const STAND_Y := 0.95
const LINE_Z := 15.0
const IP_PATTERN := "\\b[0-9]{1,3}(\\.[0-9]{1,3}){3}\\b"
const RELAY_SOURCES := ["res://relay/relay_server.gd", "res://relay/relay_main.gd"]
const NEVER_IN_RELAY := ["OS.execute", "OS.create_process", "OS.kill", "OS.shell_open", "execute_with_pipe", "StreamPeerTCP", "TCPServer", "HTTPRequest", "HTTPClient", "WebSocket", "WebRTC", "ENet", "JSON", "DirAccess", "store_", "FileAccess.open", "bytes_to_var", "str_to_var", "ResourceLoader"]

var _fails := 0
var _checks := 0
var _tmp := ""
var _branches: Array = []
var _relays: Array = []  # {pid, stdio, stderr, stop}


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_tmp = OS.get_temp_dir().path_join("sigkill-relay-test-%d" % OS.get_process_id())
	if DirAccess.dir_exists_absolute(_tmp):
		print("FAIL the test's temporary folder already exists; not touching it")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_tmp)
	Controls.ensure()
	GameSettings.current().reset()
	_wire_checks()
	_config_checks()
	_stateless_cookie_checks()
	_source_checks()
	await _empty_url_checks()
	await _match_checks()
	await _limit_checks()
	await _bad_config_checks()
	await _cleanup()
	for name in DirAccess.get_files_at(_tmp):
		DirAccess.remove_absolute(_tmp.path_join(name))
	DirAccess.remove_absolute(_tmp)
	print("RELAY: %d checks" % _checks)
	print("RELAY RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The wire, the settings, the code. ---

func _wire_checks() -> void:
	var cookie := PackedByteArray([1, 2, 3, 4, 5, 6, 7, 8])
	var token := PackedByteArray([9, 10, 11, 12, 13, 14, 15, 16])
	var req := RelayWire.request_bytes(RelayWire.Op.REGISTER, "ABC23P", Session.PROTOCOL, 9009, cookie, token)
	var back := RelayWire.parse_request(req)
	_check("a request is exactly 64 bytes and reads back: op, code, protocol, port, cookie, token", req.size() == RelayWire.REQUEST_SIZE and back["op"] == RelayWire.Op.REGISTER and back["code"] == "ABC23P" and back["protocol"] == Session.PROTOCOL and back["port"] == 9009 and back["cookie"] == cookie and back["token"] == token)
	var longest := RelayWire.reply_bytes(RelayWire.Status.OK, "ABC23P", 3, 40000, 600, token, PackedInt32Array(range(40001, 40016)))
	var reply := RelayWire.parse_reply(RelayWire.reply_bytes(RelayWire.Status.OK, "ABC23P", 3, 40000, 600, token, PackedInt32Array([40001, 40002])))
	_check("the longest reply (15 slot ports) is 57 bytes, never more than a request: no amplification", longest.size() == 57 and longest.size() <= RelayWire.REQUEST_SIZE and RelayWire.parse_reply(longest)["ports"].size() == 15)
	_check("a reply reads back and holds no address: status, code, protocol, join port, seconds, token, ports", reply["status"] == RelayWire.Status.OK and reply["code"] == "ABC23P" and reply["host_protocol"] == 3 and reply["join_port"] == 40000 and reply["left_s"] == 600 and reply["token"] == token and reply["ports"] == PackedInt32Array([40001, 40002]) and not reply.has("address"))
	var junk := PackedStringArray()
	var bad_requests := {"short": req.slice(0, 63), "long": req + PackedByteArray([0]), "magic": PackedByteArray([0x58]) + req.slice(1), "wire 1": req.slice(0, 2) + PackedByteArray([1]) + req.slice(3), "op 9": req.slice(0, 3) + PackedByteArray([9]) + req.slice(4), "lower-case code": RelayWire.request_bytes(1, "abc23p", 3, 0, cookie, token)}
	for name in bad_requests:
		if not RelayWire.parse_request(bad_requests[name]).is_empty():
			junk.append(name)
	_check("malformed requests read as nothing: short, long, bad magic, wire 1, unknown op, a code outside the alphabet", junk.is_empty(), ", ".join(junk))
	var probe := RelayWire.probe_bytes(RelayWire.Probe.JOIN, token)
	_check("a probe is 12 bytes, kind and token; anything else is not one", probe.size() == RelayWire.PROBE_SIZE and RelayWire.parse_probe(probe) == {"kind": RelayWire.Probe.JOIN, "token": token} and RelayWire.parse_probe(probe + PackedByteArray([0])).is_empty() and RelayWire.parse_probe(RelayWire.probe_bytes(7, token)).is_empty())
	var urls_ok := PackedStringArray()
	for url in ["udp://relay.example", "udp://relay.example:9010", "udp://127.0.0.1:47000", ""]:
		if not RelayWire.url_ok(url):
			urls_ok.append(url)
	for url in ["https://relay.example", "udp://", "udp://relay.example:0", "udp://relay.example:70000", "udp://relay.example/x", "udp://relay example", "udp://[::1]:9010", "udp://relay.example:90a", "udp://" + "a".repeat(60)]:
		if RelayWire.url_ok(url):
			urls_ok.append("let in " + url)
	_check("relay URLs are udp://<IPv4 or host name>[:port], 64 characters at most; the port defaults to 9010", urls_ok.is_empty() and RelayWire.parse_url("udp://relay.example") == {"host": "relay.example", "port": 9010}, ", ".join(urls_ok))


func _config_checks() -> void:
	var plain := RelayServer.config_from({}, PackedStringArray())
	_check("the relay's defaults: 127.0.0.1 only, port 9010, system-picked data ports, 64 rooms of 4 players, 2 per address, 10-minute codes, 60 s idle, 1400-byte payloads, 3000 cookie replies a minute in all", plain.get("hello_per_min") == 3000 and plain.get("bind") == LOCALHOST and plain.get("port") == 9010 and plain.get("data_first") == 0 and plain.get("max_rooms") == 64 and plain.get("max_players") == 4 and plain.get("rooms_per_ip") == 2 and plain.get("room_ttl_s") == 600 and plain.get("idle_s") == 60 and plain.get("max_payload") == 1400, str(plain))
	var mixed := RelayServer.config_from({"SIGKILL_RELAY_PORT": "9100", "SIGKILL_RELAY_ROOMS": "8", "SIGKILL_RELAY_DATA_PORTS": "40000-40099", "SIGKILL_RELAY_BIND": "*"}, PackedStringArray(["--rooms", "9", "--idle-s", "30"]))
	_check("environment variables set it and flags win over them; parsing never opens a socket", mixed.get("port") == 9100 and mixed.get("max_rooms") == 9 and mixed.get("idle_s") == 30 and mixed.get("data_first") == 40000 and mixed.get("data_last") == 40099 and mixed.get("bind") == "*", str(mixed))
	var refused := PackedStringArray()
	for args in [["--rooms", "0"], ["--port", "70000"], ["--bind", "relay.example"], ["--data-ports", "100-200"], ["--data-ports", "40000-40010"], ["--port", "40005", "--data-ports", "40000-40999"], ["--room-players", "1"], ["--frobnicate", "1"], ["--port"], ["--payload-cap", "99999"]]:
		if not RelayServer.config_from({}, PackedStringArray(args)).has("error"):
			refused.append(" ".join(args))
	_check("bad settings are refused with a reason: no rooms, a port past 65535, a name to bind, a privileged or too-small data range, the control port inside it, one player, an unknown flag, a missing value, a giant payload", refused.is_empty(), ", ".join(refused))


## The relay's own object in this process, on 127.0.0.1, for what a process cannot show:
## that a source not yet believed leaves no state behind, and the cap on cookie replies.
func _stateless_cookie_checks() -> void:
	var config := RelayServer.config_from({}, PackedStringArray(["--port", str(_free_port()), "--bind", LOCALHOST, "--hello-per-min", "5"]))
	if config.has("error"):
		_check("the in-process relay's settings parse", false, config["error"])
		return
	var server := RelayServer.new(config)
	var up := server.start() == ""
	var asker := PacketPeerUDP.new()
	asker.bind(0, LOCALHOST)
	var code := RoomCode.generate()
	var now := 100.0
	var replies := 0
	for i in 8:
		server.call("_on_control", RelayWire.request_bytes(RelayWire.Op.RESOLVE, code, Session.PROTOCOL, 0, RelayWire.zero_token(), RelayWire.zero_token()), LOCALHOST, asker.get_local_port(), now)
	OS.delay_msec(100)
	while asker.get_available_packet_count() > 0:
		asker.get_packet()
		replies += 1
	_check("first requests leave no state: eight from one source track no source at all, and only 5 cookies go out (the cap in all), the rest dropped", up and server.tracked_sources() == 0 and replies == 5 and server.counters["cookies"] == 5 and server.counters["dropped_rate"] == 3, "tracked %d, replies %d" % [server.tracked_sources(), replies])
	var cookie: PackedByteArray = server.call("_cookie", LOCALHOST, asker.get_local_port(), server.call("_window", now))
	server.call("_on_control", RelayWire.request_bytes(RelayWire.Op.RESOLVE, code, Session.PROTOCOL, 0, cookie, RelayWire.zero_token()), LOCALHOST, asker.get_local_port(), now)
	_check("a source is tracked only once it sends its cookie back", server.tracked_sources() == 1 and server.counters["unknown"] == 1)
	server.stop()
	asker.close()


func _source_checks() -> void:
	var relay := ""
	for path in RELAY_SOURCES:
		relay += _code(path)
	var found := PackedStringArray()
	for word in NEVER_IN_RELAY:
		if relay.contains(word):
			found.append(word)
	_check("the relay starts no program, opens no TCP, HTTP or other socket kind, writes no file and loads nothing from data", found.is_empty(), ", ".join(found))
	var said := PackedStringArray()
	var private := RegEx.create_from_string("\\b(ip|owner|token|code|req|room)\\b")
	for line in relay.split("\n"):
		if (line.contains("print(") or line.contains("printerr(")) and private.search(line) != null:
			said.append(line.strip_edges())
	var server := _code("res://relay/relay_server.gd")
	_check("what the relay prints holds no address, code or token: only its own port and settings and the aggregate counters", said.is_empty() and _body(server, "stats_line").contains("counters[name]") and not _body(server, "stats_line").contains("ip"), " | ".join(said))
	_check("the relay reads only one file, and only whether it exists: the stop file", _code("res://relay/relay_main.gd").count("FileAccess.") == 1 and _code("res://relay/relay_main.gd").contains("FileAccess.file_exists(_stop_file)") and not server.contains("FileAccess"))
	var client := _code("res://scripts/net/udp_rendezvous.gd")
	_check("the game's relay client has one socket, to the relay's own address only, opened on its first request", client.count("PacketPeerUDP.new()") == 1 and client.count("set_dest_address(") == 1 and client.contains("_udp.set_dest_address(_ip, _port)") and not client.contains("OS.") and not client.contains("FileAccess") and _body(client, "_init").find("PacketPeerUDP") < 0)
	var session := _code("res://scripts/net/net_session.gd")
	_check("the session itself opens no new socket: relay probes go out on its own ENet socket, nothing else does", session.count("PacketPeerUDP.new()") == 2 and session.count("socket_send(") == 2 and not session.contains("put_packet") and _body(session, "_tick_relay_host").contains("_enet.host.socket_send(") and _body(session, "_tick_join_probe").contains("_enet.host.socket_send("))


# --- Acceptance 3: no relay URL, no outbound connection. ---

func _empty_url_checks() -> void:
	var settings := GameSettings.current()
	var shipped = load("res://resources/room.tres")
	_check("acceptance 3: the shipped game has no relay URL, in the settings or the room tuning, so its rendezvous is NullRendezvous", settings.value("multiplayer", "relay_url") == "" and shipped.relay_url == "" and Session.relay_url_for(shipped) == "" and Session.rendezvous_for(shipped).get_script() == NullRendezvous)
	var default_sniffer := PacketPeerUDP.new()
	var have_default := default_sniffer.bind(RelayWire.DEFAULT_PORT, LOCALHOST) == OK
	var sniffer := PacketPeerUDP.new()
	sniffer.bind(0, LOCALHOST)
	var host := _branch("QuietHost", Vector3.ZERO)
	var client := _branch("QuietClient", CLIENT_OFFSET)
	await _frames(3)
	var hs: Session = host["session"]
	var cs: Session = client["session"]
	hs.host(0)
	await _frames(10)
	var code := RoomCode.generate()
	cs.join_room(code)
	var by_code := cs.error
	cs.join_room(RoomCode.link(code))
	await _frames(30)
	OS.delay_msec(200)
	var heard := sniffer.get_available_packet_count() + (default_sniffer.get_available_packet_count() if have_default else 0)
	_check("acceptance 3: with no relay URL, hosting draws no code and a code or a link gets the not-live line", hs.state == Session.State.HOSTING and hs.room_code == "" and by_code == NullRendezvous.NOT_LIVE and cs.error == NullRendezvous.NOT_LIVE)
	_check("acceptance 3: and nothing goes out: no request counted, nothing reaches the default relay port or any other", heard == 0 and hs.rendezvous_in_use().requests() == 0 and cs.rendezvous_in_use().requests() == 0 and hs.rendezvous_in_use().get_script() == NullRendezvous, "heard %d, default port sniffed: %s" % [heard, have_default])
	# The relay is set the way a player sets it: Settings, Multiplayer, the relay box.
	var menu = client["hud"].pause_menu()
	settings.path = _tmp.path_join("relay-box.cfg")
	menu.open_settings()
	menu._relay.text_submitted.emit("http://not-a-relay.example")
	var refused: bool = settings.value("multiplayer", "relay_url") == "" and menu.status_text().begins_with("A relay is udp://")
	menu._relay.grab_focus()
	menu._relay.text = "udp://%s:%d" % [LOCALHOST, sniffer.get_local_port()]
	menu.close()
	var saved_url: String = settings.value("multiplayer", "relay_url")
	var on_disk := FileAccess.get_file_as_string(settings.path)
	settings.path = ""
	_check("the relay is set on the settings screen: a URL that is not udp:// is refused and says why; one typed and left with the menu closing is taken whole and saved", refused and saved_url == "udp://%s:%d" % [LOCALHOST, sniffer.get_local_port()] and on_disk.contains("relay_url=\"%s\"" % saved_url) and not menu.is_open(), saved_url + " | " + on_disk.c_escape().right(160))
	cs.join_room(code)
	var arrived := await _until(func(): return sniffer.get_available_packet_count() > 0, 3000)
	var first := sniffer.get_packet() if arrived else PackedByteArray()
	_check("the control: named as the relay, the same sniffer gets the resolve at once, one 64-byte wire-2 request and nothing else of the game's", arrived and first.size() == RelayWire.REQUEST_SIZE and RelayWire.parse_request(first).get("op") == RelayWire.Op.RESOLVE and cs.rendezvous_in_use().get_script() == UdpRendezvous)
	cs.leave()
	settings.set_value("multiplayer", "relay_url", "")
	await _frames(2)
	while sniffer.get_available_packet_count() > 0:
		sniffer.get_packet()
	cs.join_room(code)
	await _frames(30)
	OS.delay_msec(200)
	_check("cleared again, the next join is back to NullRendezvous and nothing goes out", cs.error == NullRendezvous.NOT_LIVE and cs.rendezvous_in_use().get_script() == NullRendezvous and sniffer.get_available_packet_count() == 0)
	sniffer.close()
	default_sniffer.close()
	_drop(host)
	_drop(client)
	await _frames(2)


# --- Acceptance 1: a match through the relay. ---

func _match_checks() -> void:
	var port := _free_port()
	var relay := _start_relay("A", true, ["--bind", LOCALHOST, "--port", str(port), "--stats-s", "0"])
	var up := await _relay_up(port)
	_check("relay A is up as its own process through relay/run_relay.sh, bound to 127.0.0.1", up and OS.is_process_running(relay["pid"]))
	var settings := GameSettings.current()
	settings.set_value("multiplayer", "relay_url", "udp://%s:%d" % [LOCALHOST, port])
	var host := _branch("Host", Vector3.ZERO)
	var client := _branch("Client", CLIENT_OFFSET)
	await _frames(3)
	var hs: Session = host["session"]
	var cs: Session = client["session"]
	hs.host(0)
	var coded := await _until(func(): return hs.room_code != "", 5000)
	var code := hs.room_code
	var ports: PackedInt32Array = hs.get("_relay_host").get("ports", PackedInt32Array())
	_check("acceptance 1: the host registers with the relay and gets a room code, and the relay gives it a port per joiner slot", coded and RoomCode.problem(code) == "" and ports.size() == 3 and hs.rendezvous_in_use().get_script() == UdpRendezvous, code)
	cs.join_room(RoomCode.link(code))
	var joined := await _until(func(): return cs.state == Session.State.JOINED and hs.players.size() == 2 and cs.players.size() == 2, 8000)
	var cid: int = cs.my_id
	_check("acceptance 1: the joiner resolves the sigkill://join/ link and joins the host through the relay", joined and cs.address_text == "room " + code, "%s %s" % [cs.state_word(), cs.error])
	var peer_port := -1
	var enet: ENetMultiplayerPeer = hs.get("_enet")
	if joined and enet != null and enet.get_peer(cid) != null:
		peer_port = enet.get_peer(cid).get_remote_port()
	_check("every datagram goes through the relay: the joiner talks to the room's join port, the host sees the joiner as one of the relay's slot ports", joined and cs.get("_join_port") != hs.listen_port() and ports.has(peer_port) and peer_port != cs.get("_local_port"), "join port %d, host port %d, joiner seen from %d" % [cs.get("_join_port"), hs.listen_port(), peer_port])
	await _until(func(): return hs.avatars.has(cid) and cs.avatars.has(1) and not hs.dead.get(1, false) and hs.protect_left.get(1, 0.0) <= 0.0 and hs.protect_left.get(cid, 0.0) <= 0.0, 6000)
	var spot := Vector3(-8.0, STAND_Y, LINE_Z)
	host["player"].respawn_at(host["main"].to_global(spot))
	var seen := await _until(func(): return cs.avatars.has(1) and cs.avatars[1].latest_position().distance_to(spot) < 0.2, 4000)
	var cspot := Vector3(-15.0, STAND_Y, LINE_Z)
	client["player"].respawn_at(client["main"].to_global(cspot))
	var seen_back := await _until(func(): return hs.avatars.has(cid) and hs.avatars[cid].latest_position().distance_to(cspot) < 0.2, 4000)
	_check("acceptance 1: real game packets round-trip through the relay: the joiner sees the host move, the host sees the joiner move", seen and seen_back)
	await _frames(10)
	var health0: float = hs.health.get(1, 0.0)
	_aim(client["player"], client["main"].to_global(spot + Vector3(0.0, 0.05, 0.0)))
	await _settle(client["player"], 0.3)
	client["player"].drive_input(Vector2.ZERO, false, false, true)
	await physics_frame
	var hit := await _until(func(): return hs.health.get(1, 100.0) < health0, 4000)
	_check("acceptance 1: and so does combat: the joiner's shot reaches the host's authority and lands, seen on both sides", hit and await _until(func(): return cs.health.get(1, 100.0) < health0, 3000), "health %.1f -> %.1f" % [health0, hs.health.get(1, 0.0)])
	cs.leave()
	await _frames(5)
	cs.join_room(code)
	var rejoined := await _until(func(): return cs.state == Session.State.JOINED and hs.players.size() == 2, 8000)
	_check("acceptance 1: the typed code works as the link did: the joiner comes back into the same room, on the next free slot", rejoined and cs.address_text == "room " + code, "%s %s" % [cs.state_word(), cs.error])
	# A relay named by host name: looked up without blocking (localhost, so no network).
	var named := UdpRendezvous.new("udp://localhost:%d" % port)
	var named_started := named.resolve(code, Session.PROTOCOL)
	var named_done := {}
	var t0 := Time.get_ticks_msec()
	while named_done.is_empty() and Time.get_ticks_msec() - t0 < 4000:
		named_done = named.poll()
		await process_frame
	named.shut()
	_check("a relay named by host name works the same: localhost is looked up, the code resolves, the answer names the relay's own address", named_started and named_done.get("ok", false) and named_done.get("address", "") == LOCALHOST and named_done.get("relay", false), str(named_done))
	cs.leave()
	hs.leave()
	await _frames(5)
	var raw := Raw.new(port)
	var after := await _ask(raw, RelayWire.Op.RESOLVE, code)
	_check("the host stopping releases its code: the relay answers expired for it", after.get("status", -1) == RelayWire.Status.EXPIRED, str(after.get("status", "none")))
	raw.shut()
	_drop(host)
	_drop(client)
	settings.set_value("multiplayer", "relay_url", "")
	var stopped := await _stop_relay(relay)
	var said: String = stopped["out"]
	_check("acceptance 4: relay A stops cleanly when told: exit 0, its last line its counters, the match's datagrams counted", stopped["exit"] == 0 and said.contains("SIGKILL relay: stopped cleanly.") and _counter(said, "relayed_packets") > 50 and _counter(said, "registered") >= 1 and _counter(said, "resolved") >= 2, said.right(240).c_escape())
	_check("its output holds no address at all", RegEx.create_from_string(IP_PATTERN).search(said) == null and RegEx.create_from_string(IP_PATTERN).search(stopped["err"]) == null)


# --- Acceptance 2: every limit trips. ---

func _limit_checks() -> void:
	var port := _free_port()
	var relay := _start_relay("B", false, ["--bind", LOCALHOST, "--port", str(port), "--stats-s", "0", "--rooms", "2", "--rooms-per-ip", "8", "--room-ttl-s", "2", "--expired-s", "3", "--idle-s", "1", "--resolve-per-min", "6", "--register-per-min", "20", "--payload-cap", "300", "--room-players", "2"])
	var up := await _relay_up(port)
	_check("relay B is up, with tight limits", up)
	var raw := Raw.new(port)
	var code_a := RoomCode.generate()
	var code_b := RoomCode.generate()
	var code_c := RoomCode.generate()
	# Bad packets first: none of them is ever answered.
	var req := RelayWire.request_bytes(RelayWire.Op.REGISTER, code_a, Session.PROTOCOL, 0, raw.cookie, RelayWire.zero_token())
	raw.udp.put_packet(req.slice(0, 40))
	raw.udp.put_packet(req + PackedByteArray([0, 0, 0, 0]))
	raw.udp.put_packet(PackedByteArray([0x58]) + req.slice(1))
	var typo := code_a.substr(0, 5) + ("2" if code_a[5] != "2" else "3")
	raw.udp.put_packet(RelayWire.request_bytes(RelayWire.Op.RESOLVE, typo, Session.PROTOCOL, 0, raw.cookie, RelayWire.zero_token()))
	var silence := await _reply(raw, 400)
	_check("bad packets get no answer: too short, too long (oversize), a bad magic, a code with a bad checksum", silence.is_empty())
	raw.udp.put_packet(RelayWire.request_bytes(RelayWire.Op.REGISTER, code_a, Session.PROTOCOL, 0, PackedByteArray([1, 2, 3, 4, 5, 6, 7, 8]), RelayWire.zero_token()))
	var cookie_reply := await _reply(raw, 1500)
	_check("a request without the cookie the relay gave this source is answered with a cookie, never acted on", cookie_reply.get("status", -1) == RelayWire.Status.COOKIE and cookie_reply.get("token", PackedByteArray()) != PackedByteArray([1, 2, 3, 4, 5, 6, 7, 8]))
	var a := await _ask(raw, RelayWire.Op.REGISTER, code_a)
	var b := await _ask(raw, RelayWire.Op.REGISTER, code_b)
	var c := await _ask(raw, RelayWire.Op.REGISTER, code_c)
	var again := await _ask(raw, RelayWire.Op.REGISTER, code_a)
	_check("acceptance 2: the room cap trips: two rooms registered, the third answered busy; a live code twice is taken", a.get("status", -1) == RelayWire.Status.OK and b.get("status", -1) == RelayWire.Status.OK and c.get("status", -1) == RelayWire.Status.BUSY and again.get("status", -1) == RelayWire.Status.TAKEN, "%s %s %s %s" % [a.get("status"), b.get("status"), c.get("status"), again.get("status")])
	var resolves := 0
	var found := await _ask(raw, RelayWire.Op.RESOLVE, code_a)
	resolves += 1
	var host_side := PacketPeerUDP.new()
	host_side.bind(0, LOCALHOST)
	var joiner := PacketPeerUDP.new()
	joiner.bind(0, LOCALHOST)
	var second := PacketPeerUDP.new()
	second.bind(0, LOCALHOST)
	var stranger := PacketPeerUDP.new()
	stranger.bind(0, LOCALHOST)
	var a_ports: PackedInt32Array = a.get("ports", PackedInt32Array())
	var slot_port: int = a_ports[0] if a_ports.size() > 0 else 0
	var join_port: int = found.get("join_port", 0)
	_send_to(host_side, slot_port, RelayWire.probe_bytes(RelayWire.Probe.HOST, a.get("token", PackedByteArray())))
	_send_to(joiner, join_port, RelayWire.probe_bytes(RelayWire.Probe.JOIN, found.get("token", PackedByteArray())))
	OS.delay_msec(100)
	var payload := PackedByteArray()
	payload.resize(200)
	payload.fill(0x41)
	_send_to(joiner, join_port, payload)
	var to_host := await _datagram(host_side, 1500)
	var back := PackedByteArray()
	back.resize(120)
	back.fill(0x42)
	_send_to(host_side, slot_port, back)
	var to_joiner := await _datagram(joiner, 1500)
	_check("the relay forwards both ways once each side has probed with its own token: 200 bytes to the host, 120 back", to_host == payload and to_joiner == back, "%d and %d bytes" % [to_host.size(), to_joiner.size()])
	var big := PackedByteArray()
	big.resize(301)
	big.fill(0x43)
	_send_to(joiner, join_port, big)
	var oversize := await _datagram(host_side, 500)
	_check("acceptance 2: the payload cap trips: a 301-byte datagram (cap 300) is dropped, not forwarded", oversize.is_empty())
	_send_to(stranger, join_port, payload.slice(0, 50))
	_send_to(second, join_port, RelayWire.probe_bytes(RelayWire.Probe.JOIN, found.get("token", PackedByteArray())))
	OS.delay_msec(50)
	_send_to(second, join_port, payload.slice(0, 60))
	_send_to(joiner, join_port, RelayWire.probe_bytes(RelayWire.Probe.HOST, found.get("token", PackedByteArray())))
	var leaked := await _datagram(host_side, 500)
	_check("a source that never probed, a second joiner in a full room (2 players) and a probe of the wrong kind are each dropped", leaked.is_empty())
	var expired := await _until_real(func(): return true, 2300)
	var gone := await _ask(raw, RelayWire.Op.RESOLVE, code_a)
	resolves += 1
	_check("acceptance 2: room expiry trips: after its 2 s the code answers expired", expired and gone.get("status", -1) == RelayWire.Status.EXPIRED, str(gone.get("status")))
	OS.delay_msec(1300)
	await _frames(2)
	var later := await _ask(raw, RelayWire.Op.REGISTER, code_c)
	_check("and an expired room that has gone idle (1 s) gives its ports back: the third room now fits", later.get("status", -1) == RelayWire.Status.OK, str(later.get("status")))
	OS.delay_msec(2200)
	var forgotten := await _ask(raw, RelayWire.Op.RESOLVE, code_a)
	resolves += 1
	_check("an expired code is forgotten after its 3 s of 'expired': unknown", forgotten.get("status", -1) == RelayWire.Status.UNKNOWN, str(forgotten.get("status")))
	var statuses := PackedStringArray()
	var first_busy := -1
	while resolves < 8:
		var r := await _ask(raw, RelayWire.Op.RESOLVE, code_c)
		resolves += 1
		statuses.append(str(r.get("status", -1)))
		if r.get("status", -1) == RelayWire.Status.BUSY and first_busy < 0:
			first_busy = resolves
	_check("acceptance 2: the rate limit trips: with 6 resolutions a minute allowed, the 7th from this source is answered busy", first_busy == 7, "busy at %d; %s" % [first_busy, ", ".join(statuses)])
	for udp in [host_side, joiner, second, stranger]:
		udp.close()
	raw.shut()
	var stopped := await _stop_relay(relay)
	var said: String = stopped["out"]
	var tripped := PackedStringArray()
	for name in ["busy", "dropped_oversize", "dropped_rate", "dropped_bad", "dropped_unknown_source", "dropped_full", "expired", "taken", "bad_code", "cookies"]:
		if _counter(said, name) < 1:
			tripped.append(name)
	_check("acceptance 2: the relay's own counters show each limit and drop: busy, oversize, rate, bad, unknown source, full, expired, taken, bad code, cookies", tripped.is_empty() and said.contains("stopped cleanly"), "missing: %s; %s" % [", ".join(tripped), said.right(300).c_escape()])
	_check("acceptance 4: relay B stops cleanly too (exit 0), and its output holds no address", stopped["exit"] == 0 and RegEx.create_from_string(IP_PATTERN).search(said) == null)


func _bad_config_checks() -> void:
	var relay := _start_relay("bad", false, ["--rooms", "0", "--bind", LOCALHOST])
	var t0 := Time.get_ticks_msec()
	while OS.is_process_running(relay["pid"]) and Time.get_ticks_msec() - t0 < 8000:
		await process_frame
	var err: String = relay["stderr"].get_as_text()
	_check("a bad setting stops the relay at once with exit 2 and the reason", not OS.is_process_running(relay["pid"]) and OS.get_process_exit_code(relay["pid"]) == 2 and err.contains("--rooms"), err.c_escape().right(200))
	_relays.erase(relay)


# --- Helpers. ---

## A raw client of the relay's control port, as a host or joiner game speaks it.
class Raw:
	var udp := PacketPeerUDP.new()
	var cookie := PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0])
	var relay_port := 0

	func _init(port: int) -> void:
		relay_port = port
		udp.bind(0, "127.0.0.1")
		udp.set_dest_address("127.0.0.1", port)

	func shut() -> void:
		udp.close()


## One request, with the cookie round trip when the relay asks for it; {} on no answer.
func _ask(raw: Raw, op: int, code: String, token: PackedByteArray = RelayWire.zero_token()) -> Dictionary:
	for attempt in 2:
		raw.udp.put_packet(RelayWire.request_bytes(op, code, Session.PROTOCOL, 0, raw.cookie, token))
		var reply := await _reply(raw, 1500)
		if reply.is_empty() or reply["status"] != RelayWire.Status.COOKIE:
			return reply
		raw.cookie = reply["token"]
	return {"status": RelayWire.Status.COOKIE}


func _reply(raw: Raw, ms: int) -> Dictionary:
	var data := await _datagram(raw.udp, ms)
	return RelayWire.parse_reply(data) if not data.is_empty() else {}


## The next datagram on `udp` within `ms` of real time, or empty.
func _datagram(udp: PacketPeerUDP, ms: int) -> PackedByteArray:
	var t0 := Time.get_ticks_msec()
	while udp.get_available_packet_count() == 0:
		if Time.get_ticks_msec() - t0 > ms:
			return PackedByteArray()
		OS.delay_msec(5)
		await process_frame
	return udp.get_packet()


func _send_to(udp: PacketPeerUDP, port: int, data: PackedByteArray) -> void:
	udp.set_dest_address(LOCALHOST, port)
	udp.put_packet(data)


## Starts a relay process: through relay/run_relay.sh, or Godot directly. Never bound
## anywhere but 127.0.0.1 here.
func _start_relay(name: String, script: bool, flags: Array) -> Dictionary:
	var stop := _tmp.path_join("stop-%s" % name)
	var project := ProjectSettings.globalize_path("res://")
	var args := PackedStringArray(flags)
	if name != "bad":
		args.append_array(["--stop-file", stop])
	var out := {}
	if script:
		OS.set_environment("SIGKILL_GODOT", OS.get_executable_path())
		OS.set_environment("SIGKILL_RELAY_LOG", _tmp.path_join("relay-%s.log" % name))
		out = OS.execute_with_pipe("bash", PackedStringArray([project.path_join("relay/run_relay.sh")]) + args, false)
	else:
		out = OS.execute_with_pipe(OS.get_executable_path(), PackedStringArray(["--headless", "--log-file", _tmp.path_join("relay-%s.log" % name), "--path", project, "--script", "res://relay/relay_main.gd", "--"]) + args, false)
	var relay := {"pid": out.get("pid", -1), "stdio": out.get("stdio"), "stderr": out.get("stderr"), "stop": stop}
	_relays.append(relay)
	return relay


## True once the relay answers on `port` (with a cookie, to a first request).
func _relay_up(port: int) -> bool:
	var raw := Raw.new(port)
	var answered := false
	for i in 40:
		raw.udp.put_packet(RelayWire.request_bytes(RelayWire.Op.RESOLVE, RoomCode.generate(), Session.PROTOCOL, 0, raw.cookie, RelayWire.zero_token()))
		if not (await _reply(raw, 250)).is_empty():
			answered = true
			break
	raw.shut()
	return answered


## Tells a relay to stop (its stop file) and waits for it: {exit, out, err}.
func _stop_relay(relay: Dictionary) -> Dictionary:
	var f := FileAccess.open(relay["stop"], FileAccess.WRITE)
	f.close()
	var t0 := Time.get_ticks_msec()
	while OS.is_process_running(relay["pid"]) and Time.get_ticks_msec() - t0 < 8000:
		await process_frame
	var running := OS.is_process_running(relay["pid"])
	var result := {"exit": -1 if running else OS.get_process_exit_code(relay["pid"]), "out": relay["stdio"].get_as_text() if not running else "", "err": relay["stderr"].get_as_text() if not running else ""}
	_relays.erase(relay)
	return result


## The number after `name` in a relay's counter line, or -1.
func _counter(text: String, name: String) -> int:
	var at := text.rfind(name + " ")
	if at < 0:
		return -1
	var digits := ""
	for ch in text.substr(at + name.length() + 1, 12):
		if ch < "0" or ch > "9":
			break
		digits += ch
	return int(digits) if digits != "" else -1


func _free_port() -> int:
	var probe := PacketPeerUDP.new()
	probe.bind(0, LOCALHOST)
	var port := probe.get_local_port()
	probe.close()
	return port


func _net_tuning() -> Resource:
	var t := NetTuningScript.new()
	t.bind_address = LOCALHOST
	t.connect_timeout_ms = 8000
	t.peer_timeout_ms = 8000
	return t


func _combat_tuning() -> Resource:
	var t := CombatTuningScript.new()
	t.respawn_delay_s = 1.0
	t.spawn_protection_s = 0.3
	t.kill_feed_fade_s = 30.0
	return t


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
	session.combat_tuning = _combat_tuning()
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


func _aim(player: Node, target: Vector3) -> void:
	var cam: Node3D = player.get_node("Head/Camera")
	var to: Vector3 = target - cam.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	player.get_node("Head").rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


func _settle(p: Node, seconds: float) -> void:
	for i in ceili(seconds * 60.0):
		p.drive_input(Vector2.ZERO)
		await physics_frame


func _until(condition: Callable, ms: int = WATCHDOG_MS) -> bool:
	var t0 := Time.get_ticks_msec()
	while not condition.call():
		if Time.get_ticks_msec() - t0 > ms:
			return false
		await physics_frame
	return true


## Waits `ms` of real time (frames keep coming), then true.
func _until_real(_condition: Callable, ms: int) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		OS.delay_msec(10)
		await process_frame
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
		return ""
	var end := source.find("\nfunc ", at + 1)
	return source.substr(at, (end if end > 0 else source.length()) - at)


func _cleanup() -> void:
	for branch in _branches.duplicate():
		if is_instance_valid(branch):
			var session = branch.get_node_or_null(Session.NODE_NAME)
			if session != null:
				session.leave()
			branch.free()
	for relay in _relays.duplicate():
		if OS.is_process_running(relay["pid"]):
			_check("no relay process is left running at the end", false, "pid still running; stopped with the stop file")
			await _stop_relay(relay)
	var left = Link.take_parked()
	if left != null:
		left.shut_down(null)
	GameSettings.current().reset()
	await process_frame
	OS.delay_msec(300)
	await process_frame
