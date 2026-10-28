extends SceneTree
## Headless WebSocket relay test for SIGKILL (C16d). scripts/check.sh runs it, and any FAIL
## exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/relay_ws_test.gd
##
## The relay's WebSocket transport (relay/relay_ws.gd) and the game's client for it
## (scripts/net/ws_rendezvous.gd). The scheme picks the transport: udp:// the C16c path, ws://
## and wss:// this one, anything else no relay and no connection; wss:// takes the WebSocket
## path with TLS (the proxy's, which no test here can stand in for). The source: nothing run,
## no file, no address printed, the game's loopback sockets on 127.0.0.1 only. An empty relay
## URL makes no connection of any kind. Then relays run as their own processes, bound to
## 127.0.0.1 only, on one TCP port each: relay A carries a real match (join by room code and by
## link, both players see each other move, a shot judged by the host lands), every datagram
## through the game's loopback tunnel; relay B, with tight limits, trips each one (bad
## messages, the cookie, the rate, the room count, the payload cap, a full room, idle expiry,
## the code's life, the connection cap, the handshake time) and counts it. Neither prints an
## address. Nothing outside this process and its relays is touched.

const Session = preload("res://scripts/net/net_session.gd")
const NetTuningScript = preload("res://scripts/net/net_tuning.gd")
const CombatTuningScript = preload("res://scripts/net/combat_tuning.gd")
const RoomTuningScript = preload("res://scripts/net/room_tuning.gd")
const RoomCode = preload("res://scripts/net/room_code.gd")
const RelayWire = preload("res://scripts/net/relay_wire.gd")
const UdpRendezvous = preload("res://scripts/net/udp_rendezvous.gd")
const WsRendezvous = preload("res://scripts/net/ws_rendezvous.gd")
const NullRendezvous = preload("res://scripts/net/null_rendezvous.gd")
const RelayServer = preload("res://relay/relay_server.gd")
const RelayWs = preload("res://relay/relay_ws.gd")
const Link = preload("res://scripts/guide/guide_link.gd")
const Controls = preload("res://scripts/controls.gd")
const MainScene = preload("res://scenes/main.tscn")
const LOCALHOST := "127.0.0.1"
const WATCHDOG_MS := 10000
const CLIENT_OFFSET := Vector3(1000.0, 0.0, 0.0)
const STAND_Y := 0.95
const LINE_Z := 15.0
const IP_PATTERN := "\\b[0-9]{1,3}(\\.[0-9]{1,3}){3}\\b"
const NEVER := ["OS.execute", "OS.create_process", "OS.kill", "OS.shell_open", "execute_with_pipe", "HTTPRequest", "HTTPClient", "WebRTC", "ENet", "JSON", "DirAccess", "store_", "FileAccess", "bytes_to_var", "str_to_var", "ResourceLoader", "OS.get_environment"]

var _fails := 0
var _checks := 0
var _tmp := ""
var _branches: Array = []
var _relays: Array = []  # {pid, stdio, stderr, stop}


## A raw WebSocket client of a relay, as a game speaks to it.
class RawWs:
	var ws := WebSocketPeer.new()
	var cookie := PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0])

	func _init(port: int) -> void:
		ws.connect_to_url("ws://127.0.0.1:%d/" % port)

	func shut() -> void:
		ws.close()


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_tmp = OS.get_temp_dir().path_join("sigkill-relay-ws-test-%d" % OS.get_process_id())
	if DirAccess.dir_exists_absolute(_tmp):
		print("FAIL the test's temporary folder already exists; not touching it")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_tmp)
	Controls.ensure()
	GameSettings.current().reset()
	_wire_checks()
	_config_checks()
	_source_checks()
	await _scheme_checks()
	await _empty_url_checks()
	await _down_checks()
	await _match_checks()
	await _limit_checks()
	await _bad_config_checks()
	await _cleanup()
	for name in DirAccess.get_files_at(_tmp):
		DirAccess.remove_absolute(_tmp.path_join(name))
	DirAccess.remove_absolute(_tmp)
	print("RELAY WS: %d checks" % _checks)
	print("RELAY WS RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The scheme, the URL and the data message. ---

func _wire_checks() -> void:
	var picks := PackedStringArray()
	for pair in [["udp://relay.example", "udp"], ["udp://127.0.0.1:9010", "udp"], ["ws://relay.example", "ws"], ["ws://127.0.0.1:8000", "ws"], ["wss://relay.example", "ws"], ["wss://my-vm.exe.xyz", "ws"], ["", ""], ["http://relay.example", ""], ["https://relay.example", ""], ["tcp://relay.example:8000", ""], ["ftp://relay.example", ""], ["WS://relay.example", ""], ["ws://", ""], ["wss://relay.example/path", ""], ["ws://relay.example:0", ""], ["ws://relay.example:70000", ""], ["ws://[::1]:8000", ""], ["ws://relay example", ""], ["wss://" + "a".repeat(60), ""]]:
		if RelayWire.transport_of(pair[0]) != pair[1] or RelayWire.url_ok(pair[0]) != (pair[0] == "" or pair[1] != ""):
			picks.append("%s -> %s" % [pair[0], RelayWire.transport_of(pair[0])])
	_check("the scheme alone picks the transport: udp:// the UDP relay, ws:// and wss:// the WebSocket relay; every other scheme (http, https, tcp, ftp, a capital WS), a path, a bad port or host is no relay at all", picks.is_empty(), ", ".join(picks))
	_check("WebSocket URLs read back with the web's own ports when none is named: wss:// 443 with TLS, ws:// 80 without; udp:// reads exactly as it did", RelayWire.parse_ws_url("wss://relay.example") == {"host": "relay.example", "port": 443, "tls": true} and RelayWire.parse_ws_url("ws://127.0.0.1:8000") == {"host": "127.0.0.1", "port": 8000, "tls": false} and RelayWire.parse_ws_url("udp://relay.example").is_empty() and RelayWire.parse_url("udp://relay.example") == {"host": "relay.example", "port": 9010} and RelayWire.parse_url("ws://relay.example").is_empty())
	var payload := PackedByteArray([1, 2, 3, 250])
	var data := RelayWire.data_bytes(3, payload)
	_check("a data message is \"SD\", wire 2, a slot, then the datagram untouched; anything else is not one", data.size() == RelayWire.DATA_HEAD + 4 and RelayWire.parse_data(data) == {"slot": 3, "payload": payload} and RelayWire.parse_data(data.slice(0, 3)).is_empty() and RelayWire.parse_data(RelayWire.probe_bytes(RelayWire.Probe.JOIN, RelayWire.zero_token())).is_empty() and RelayWire.parse_data(PackedByteArray([0x53, 0x44, 1, 0])).is_empty())


func _config_checks() -> void:
	var plain := RelayServer.config_from({}, PackedStringArray())
	var ws := RelayServer.config_from({"SIGKILL_RELAY_WS_PORT": "8100"}, PackedStringArray(["--ws-port", "8000", "--bind", "*"]))
	_check("the relay's settings: no --ws-port (0) keeps the UDP relay; --ws-port picks the WebSocket transport on that port, a flag over its variable, every interface (*) when asked", plain.get("ws_port") == 0 and ws.get("ws_port") == 8000 and ws.get("bind") == "*" and not ws.has("error"), str(ws))
	var refused := PackedStringArray()
	for args in [["--ws-port", "70000"], ["--ws-port", "-1"], ["--ws-port", "eight"], ["--ws-port"]]:
		if not RelayServer.config_from({}, PackedStringArray(args)).has("error"):
			refused.append(" ".join(args))
	_check("a bad --ws-port is refused with a reason: past 65535, negative, not a number, no value", refused.is_empty(), ", ".join(refused))


func _source_checks() -> void:
	var relay := _code("res://relay/relay_ws.gd")
	var main := _code("res://relay/relay_main.gd")
	var found := PackedStringArray()
	for word in NEVER:
		if relay.contains(word):
			found.append(word)
	_check("the WebSocket relay starts no program, opens no other kind of socket, reads and writes no file, decodes no objects and prints nothing at all", found.is_empty() and not relay.contains("print") and relay.count("TCPServer.new()") == 1 and relay.count("WebSocketPeer.new()") == 1 and relay.count("PacketPeer") == 0, ", ".join(found))
	_check("it is the UDP relay's control path with another transport: it extends relay/relay_server.gd and sends every control answer through the same cookie, rate and room rules", relay.begins_with("extends \"res://relay/relay_server.gd\"") and _body(relay, "_on_message").contains("_on_control(data, link.ip, link.port, now)") and not relay.contains("func _on_control(") and not relay.contains("func _cookie_ok(") and not relay.contains("func _client("))
	var said := PackedStringArray()
	var private := RegEx.create_from_string("\\b(ip|owner|token|code|req|room)\\b")
	for line in main.split("\n"):
		if (line.contains("print(") or line.contains("printerr(")) and private.search(line) != null:
			said.append(line.strip_edges())
	_check("relay_main picks the transport from --ws-port alone and what it prints holds no address, code or token", main.contains("RelayWs.new(config) if config[\"ws_port\"] > 0 else RelayServer.new(config)") and said.is_empty() and _body(relay, "stats_line").contains("counters[name]") and not _body(relay, "stats_line").contains(".ip"), " | ".join(said))
	var client := _code("res://scripts/net/ws_rendezvous.gd")
	var game_found := PackedStringArray()
	for word in NEVER + ["IP.", "TCPServer", "StreamPeerTCP"]:
		if client.contains(word):
			game_found.append(word)
	_check("the game's WebSocket client: one link, to the relay URL the player set, made on its first request; its loopback sockets bound to 127.0.0.1 only; nothing run, read or looked up by itself", game_found.is_empty() and client.count("WebSocketPeer.new()") == 1 and client.count("connect_to_url(") == 2 and client.count("connect_to_url(_url") == 2 and client.count("PacketPeerUDP.new()") == 1 and client.contains("udp.bind(0, LOOPBACK)") and client.count(".bind(") == 1 and client.contains("const LOOPBACK := \"127.0.0.1\"") and _body(client, "_init").find("WebSocketPeer") < 0 and _body(client, "_init").find("PacketPeerUDP") < 0, ", ".join(game_found))
	_check("a loopback socket takes datagrams from 127.0.0.1 only, and only from the first source it saw (the game's own ENet socket)", _body(client, "_drain").contains("if udp.get_packet_ip() != LOOPBACK:") and _body(client, "_drain").contains("elif from != known:"))
	var session := _code("res://scripts/net/net_session.gd")
	_check("the session's relay path is the C16c one: it only picks the client by scheme, pumps it once a frame and closes its tunnel with the peer", _body(session, "rendezvous_for").contains("if RelayWire.transport_of(url) == \"ws\":\n\t\treturn WsRendezvous.new(url)") and _body(session, "_physics_process").contains("_rv.pump()") and _body(session, "_shut_peer").contains("_rv.end_tunnel()") and not session.contains("WebSocket"))


# --- The scheme picks the transport. ---

func _scheme_checks() -> void:
	var tuning := RoomTuningScript.new()
	tuning.relay_url = "ws://127.0.0.1:8000"
	var ws = Session.rendezvous_for(tuning)
	tuning.relay_url = "wss://my-vm.exe.xyz"
	var wss = Session.rendezvous_for(tuning)
	tuning.relay_url = "udp://127.0.0.1:9010"
	var udp = Session.rendezvous_for(tuning)
	var unknown := []
	for url in ["tcp://127.0.0.1:8000", "http://127.0.0.1:8000", "https://my-vm.exe.xyz"]:
		var bad := RoomTuningScript.new()
		bad.relay_url = url
		unknown.append([bad.problems().size(), Session.rendezvous_for(bad).get_script()])
	_check("ws:// and wss:// take the WebSocket client, udp:// the C16c one; making one opens no link and sends nothing", ws.get_script() == WsRendezvous and wss.get_script() == WsRendezvous and udp.get_script() == UdpRendezvous and not ws.link_open() and not wss.link_open() and ws.requests() == 0 and wss.requests() == 0 and ws.tunnel_sockets().is_empty())
	_check("wss:// takes the WebSocket path with TLS, to the web's port 443 (TLS the proxy in front of the relay terminates); ws:// is plain", wss.uses_tls() and wss.get("_url") == "wss://my-vm.exe.xyz:443/" and not ws.uses_tls() and ws.get("_url") == "ws://127.0.0.1:8000/")
	_check("an unknown scheme is refused by the room tuning and gives no relay at all: NullRendezvous, no connection", unknown == [[1, NullRendezvous], [1, NullRendezvous], [1, NullRendezvous]], str(unknown))
	# The settings box: an unknown scheme refused and said why; ws:// taken and saved.
	var settings := GameSettings.current()
	var host := _branch("Box", Vector3.ZERO)
	await _frames(3)
	var menu = host["hud"].pause_menu()
	settings.path = _tmp.path_join("ws-box.cfg")
	menu.open_settings()
	menu._relay.text_submitted.emit("tcp://127.0.0.1:8000")
	var said: String = menu.status_text()
	var refused: bool = settings.value("multiplayer", "relay_url") == ""
	menu._relay.text_submitted.emit("ws://127.0.0.1:8000")
	menu.close()
	var saved: String = settings.value("multiplayer", "relay_url")
	var on_disk := FileAccess.get_file_as_string(settings.path)
	settings.path = ""
	_check("the settings refuse an unknown scheme and say which ones work (udp, ws, wss); a ws:// URL is taken and saved", refused and said.contains("udp://") and said.contains("ws://") and said.contains("wss://") and saved == "ws://127.0.0.1:8000" and on_disk.contains("relay_url=\"ws://127.0.0.1:8000\"") and Session.relay_url_for(RoomTuningScript.new()) == saved, said)
	settings.set_value("multiplayer", "relay_url", "")
	_drop(host)
	await _frames(2)
	# wss:// reaches for its relay over TCP, on the WebSocket path: a listener stands in for
	# the proxy and sees the connection; no TLS server answers it, and the game is let go.
	var proxy := TCPServer.new()
	proxy.listen(0, LOCALHOST)
	var tls_ws = WsRendezvous.new("wss://%s:%d" % [LOCALHOST, proxy.get_local_port()])
	tls_ws.resolve(RoomCode.generate(), Session.PROTOCOL)
	var reached := false
	var t0 := Time.get_ticks_msec()
	var held: StreamPeerTCP = null
	while not reached and Time.get_ticks_msec() - t0 < 3000:
		tls_ws.pump()
		if proxy.is_connection_available():
			held = proxy.take_connection()
			reached = true
		await process_frame
		OS.delay_msec(5)
	_check("a wss:// relay is reached on the WebSocket path: a TCP connection to its host and port, opened on the first request, TLS on top", reached and tls_ws.uses_tls() and tls_ws.link_open())
	tls_ws.shut()
	for i in 5:
		tls_ws.pump()
		await process_frame
	if held != null:
		held.disconnect_from_host()
	proxy.stop()


# --- No relay URL, no connection. ---

func _empty_url_checks() -> void:
	var settings := GameSettings.current()
	var listener := TCPServer.new()
	listener.listen(0, LOCALHOST)
	var host := _branch("Host0", Vector3.ZERO)
	var client := _branch("Client0", CLIENT_OFFSET)
	await _frames(3)
	var hs: Session = host["session"]
	var cs: Session = client["session"]
	hs.host(0)
	await _frames(20)
	cs.join_room(RoomCode.generate())
	await _frames(20)
	var reached := false
	for i in 30:
		if listener.is_connection_available():
			reached = true
		await process_frame
		OS.delay_msec(5)
	_check("acceptance: with no relay URL (the default) nothing connects: no WebSocket client is made, hosting draws no code, a code gets the not-live line, no request is sent and no connection arrives anywhere", settings.value("multiplayer", "relay_url") == "" and hs.rendezvous_in_use().get_script() == NullRendezvous and cs.rendezvous_in_use().get_script() == NullRendezvous and hs.room_code == "" and cs.error == NullRendezvous.NOT_LIVE and hs.rendezvous_in_use().requests() == 0 and cs.rendezvous_in_use().requests() == 0 and not reached)
	listener.stop()
	_drop(host)
	_drop(client)
	await _frames(2)


# --- A relay that is not there. ---

func _down_checks() -> void:
	var settings := GameSettings.current()
	settings.set_value("multiplayer", "relay_url", "ws://%s:%d" % [LOCALHOST, _free_port()])
	var client := _branch("Lone", CLIENT_OFFSET)
	await _frames(3)
	var cs: Session = client["session"]
	cs.join_room(RoomCode.generate())
	var failed := await _until(func(): return cs.state == Session.State.FAILED, 6000)
	_check("a ws:// relay that is not running: the join fails with \"couldn't reach the room service\", no tunnel left open, nothing else to show for it", failed and cs.error == Session.ROOM_UNREACHABLE and not cs.rendezvous_in_use().link_open() and cs.rendezvous_in_use().tunnel_sockets().is_empty(), "%s %s" % [cs.state_word(), cs.error])
	settings.set_value("multiplayer", "relay_url", "")
	_drop(client)
	await _frames(2)


# --- A match through the WebSocket relay. ---

func _match_checks() -> void:
	var port := _free_port()
	var relay := _start_relay("A", true, ["--ws-port", str(port), "--bind", LOCALHOST, "--stats-s", "0"])
	var up := await _relay_up(port)
	_check("relay A is up as its own process through relay/run_relay.sh, on one TCP port of 127.0.0.1", up and OS.is_process_running(relay["pid"]))
	var settings := GameSettings.current()
	settings.set_value("multiplayer", "relay_url", "ws://%s:%d" % [LOCALHOST, port])
	var host := _branch("Host", Vector3.ZERO)
	var client := _branch("Client", CLIENT_OFFSET)
	await _frames(3)
	var hs: Session = host["session"]
	var cs: Session = client["session"]
	hs.host(0)
	var coded := await _until(func(): return hs.room_code != "", 5000)
	var code := hs.room_code
	var ports: PackedInt32Array = hs.get("_relay_host").get("ports", PackedInt32Array())
	var hrv = hs.rendezvous_in_use()
	var loopback := true
	for udp in hrv.tunnel_sockets():
		loopback = loopback and ports.has(udp.get_local_port())
	_check("acceptance: the host registers over ws:// and gets a room code; its tunnel holds one loopback socket per joiner slot, and the session probes those as it would the UDP relay's ports", coded and RoomCode.problem(code) == "" and ports.size() == 3 and hrv.get_script() == WsRendezvous and hrv.tunnel_sockets().size() == 3 and loopback and hs.get("_relay_host").get("ip") == LOCALHOST, "%s %s" % [code, ports])
	cs.join_room(RoomCode.link(code))
	var joined := await _until(func(): return cs.state == Session.State.JOINED and hs.players.size() == 2 and cs.players.size() == 2, 8000)
	var cid: int = cs.my_id
	_check("acceptance: the joiner resolves the sigkill://join/ link over ws:// and joins the host through the relay", joined and cs.address_text == "room " + code and cs.rendezvous_in_use().get_script() == WsRendezvous, "%s %s" % [cs.state_word(), cs.error])
	var crv = cs.rendezvous_in_use()
	var mouth: int = crv.tunnel_sockets()[0].get_local_port() if not crv.tunnel_sockets().is_empty() else -1
	var peer_port := -1
	var enet: ENetMultiplayerPeer = hs.get("_enet")
	if joined and enet != null and enet.get_peer(cid) != null:
		peer_port = enet.get_peer(cid).get_remote_port()
	_check("every datagram goes through the tunnel: the joiner's ENet talks to its own loopback mouth, the host sees the joiner as one of its own loopback slot sockets; neither sees the other", joined and cs.get("_join_port") == mouth and mouth != hs.listen_port() and ports.has(peer_port), "mouth %d, joined to %d, host port %d, joiner seen from %d" % [mouth, cs.get("_join_port"), hs.listen_port(), peer_port])
	await _until(func(): return hs.avatars.has(cid) and cs.avatars.has(1) and not hs.dead.get(1, false) and hs.protect_left.get(1, 0.0) <= 0.0 and hs.protect_left.get(cid, 0.0) <= 0.0, 6000)
	var spot := Vector3(-8.0, STAND_Y, LINE_Z)
	host["player"].respawn_at(host["main"].to_global(spot))
	var seen := await _until(func(): return cs.avatars.has(1) and cs.avatars[1].latest_position().distance_to(spot) < 0.2, 4000)
	var cspot := Vector3(-15.0, STAND_Y, LINE_Z)
	client["player"].respawn_at(client["main"].to_global(cspot))
	var seen_back := await _until(func(): return hs.avatars.has(cid) and hs.avatars[cid].latest_position().distance_to(cspot) < 0.2, 4000)
	_check("acceptance: real game packets round-trip through the WebSocket relay: the joiner sees the host move, the host sees the joiner move", seen and seen_back)
	await _frames(10)
	var health0: float = hs.health.get(1, 0.0)
	_aim(client["player"], client["main"].to_global(spot + Vector3(0.0, 0.05, 0.0)))
	await _settle(client["player"], 0.3)
	client["player"].drive_input(Vector2.ZERO, false, false, true)
	await physics_frame
	var hit := await _until(func(): return hs.health.get(1, 100.0) < health0, 4000)
	_check("acceptance: and a shot judged by the host lands: the joiner's shot reaches the host's authority, seen on both sides", hit and await _until(func(): return cs.health.get(1, 100.0) < health0, 3000), "health %.1f -> %.1f" % [health0, hs.health.get(1, 0.0)])
	_check("the tunnels carried it, both ways on both sides, with nothing dropped", hrv.tunneled_out > 20 and hrv.tunneled_in > 20 and crv.tunneled_out > 20 and crv.tunneled_in > 20 and hrv.tunnel_dropped == 0 and crv.tunnel_dropped == 0, "host %d/%d/%d joiner %d/%d/%d" % [hrv.tunneled_out, hrv.tunneled_in, hrv.tunnel_dropped, crv.tunneled_out, crv.tunneled_in, crv.tunnel_dropped])
	cs.leave()
	var tunnel_gone: bool = not crv.link_open() and crv.tunnel_sockets().is_empty()
	# The joiner's goodbye goes through the tunnel before it closes: the host lets the joiner
	# go at once, long before its 4 s peer timeout would.
	var t_left := Time.get_ticks_msec()
	var let_go := await _until(func(): return hs.players.size() == 1, 4000)
	var after_ms := Time.get_ticks_msec() - t_left
	_check("leaving closes the joiner's link and loopback sockets, after its goodbye went through them: the host lets the joiner go at once (%d ms, the peer timeout is 4 s)" % after_ms, tunnel_gone and let_go and after_ms < 1500)
	cs.join_room(code)
	var rejoined := await _until(func(): return cs.state == Session.State.JOINED and hs.players.size() == 2, 8000)
	_check("the typed code brings the joiner back into the same room over a new link", rejoined and cs.address_text == "room " + code, "%s %s" % [cs.state_word(), cs.error])
	# The host leaves first: its goodbye reaches the joiner through the relay before the relay
	# closes the joiner's link, so the joiner hears "host left" at once, not at its timeout.
	var t_host := Time.get_ticks_msec()
	hs.leave()
	var told := await _until(func(): return cs.state == Session.State.FAILED and cs.error == Session.HOST_LEFT, 4000)
	var told_ms := Time.get_ticks_msec() - t_host
	_check("the host leaving is heard at once: the joiner shows \"host left\" in %d ms (its peer timeout is 4 s), the host's goodbye reaching it before the relay closes its link" % told_ms, told and told_ms < 1500, "%s %s" % [cs.state_word(), cs.error])
	cs.leave()
	await _until_real(func(): return false, 600)
	var raw := RawWs.new(port)
	var opened := await _open(raw)
	var after := await _ask(raw, RelayWire.Op.RESOLVE, code)
	_check("the host leaving releases its code: its close request reaches the relay before its link closes, and the code answers expired", opened and after.get("status", -1) == RelayWire.Status.EXPIRED, str(after.get("status", "none")))
	raw.shut()
	_drop(host)
	_drop(client)
	settings.set_value("multiplayer", "relay_url", "")
	var stopped := await _stop_relay(relay)
	var said: String = stopped["out"]
	_check("relay A stops cleanly when told: exit 0, its last line its counters, the match's datagrams relayed, the close counted", stopped["exit"] == 0 and said.contains("SIGKILL relay: stopped cleanly.") and _counter(said, "relayed_packets") > 50 and _counter(said, "registered") >= 1 and _counter(said, "resolved") >= 2 and _counter(said, "closed") >= 1 and _counter(said, "connections") >= 3, said.right(300).c_escape())
	_check("acceptance: the relay logs no IP address: its output holds none at all", RegEx.create_from_string(IP_PATTERN).search(said) == null and RegEx.create_from_string(IP_PATTERN).search(stopped["err"]) == null)


# --- Every limit trips. ---

func _limit_checks() -> void:
	var port := _free_port()
	var relay := _start_relay("B", false, ["--ws-port", str(port), "--bind", LOCALHOST, "--stats-s", "0", "--rooms", "2", "--rooms-per-ip", "8", "--room-ttl-s", "2", "--expired-s", "3", "--idle-s", "1", "--resolve-per-min", "6", "--register-per-min", "20", "--payload-cap", "300", "--room-players", "2", "--sources", "8"])
	var up := await _relay_up(port)
	_check("relay B is up, with tight limits", up)
	var raw := RawWs.new(port)
	await _open(raw)
	var code_a := RoomCode.generate()
	var code_b := RoomCode.generate()
	var code_c := RoomCode.generate()
	# Bad messages first: none is ever answered.
	var req := RelayWire.request_bytes(RelayWire.Op.REGISTER, code_a, Session.PROTOCOL, 0, raw.cookie, RelayWire.zero_token())
	raw.ws.put_packet(req.slice(0, 40))
	raw.ws.put_packet(req + PackedByteArray([0, 0, 0, 0]))
	raw.ws.put_packet(PackedByteArray([0x58]) + req.slice(1))
	raw.ws.send_text("hello")
	var typo := code_a.substr(0, 5) + ("2" if code_a[5] != "2" else "3")
	raw.ws.put_packet(RelayWire.request_bytes(RelayWire.Op.RESOLVE, typo, Session.PROTOCOL, 0, raw.cookie, RelayWire.zero_token()))
	var silence := await _message(raw, 400)
	_check("bad messages get no answer: too short, too long (oversize), a bad magic, text, a code with a bad checksum", silence.is_empty())
	raw.ws.put_packet(RelayWire.request_bytes(RelayWire.Op.REGISTER, code_a, Session.PROTOCOL, 0, PackedByteArray([1, 2, 3, 4, 5, 6, 7, 8]), RelayWire.zero_token()))
	var cookie_reply := RelayWire.parse_reply(await _message(raw, 1500))
	_check("acceptance (cookie): a request without the cookie the relay gave this link is answered with a cookie, never acted on", cookie_reply.get("status", -1) == RelayWire.Status.COOKIE and cookie_reply.get("token", PackedByteArray()) != PackedByteArray([1, 2, 3, 4, 5, 6, 7, 8]))
	# One host link per room: a link that registers again keeps its room under the new code.
	var host_a := raw
	var a := await _ask(host_a, RelayWire.Op.REGISTER, code_a)
	var a_at := Time.get_ticks_msec()
	var host_b := RawWs.new(port)
	await _open(host_b)
	var b := await _ask(host_b, RelayWire.Op.REGISTER, code_b)
	var host_c := RawWs.new(port)
	await _open(host_c)
	var c := await _ask(host_c, RelayWire.Op.REGISTER, code_c)
	var again := await _ask(host_c, RelayWire.Op.REGISTER, code_a)
	_check("acceptance (room count): two rooms registered on two links, the third answered busy; a live code twice is taken; a room's slots are named 1 to N-1, its join port 0", a.get("status", -1) == RelayWire.Status.OK and b.get("status", -1) == RelayWire.Status.OK and c.get("status", -1) == RelayWire.Status.BUSY and again.get("status", -1) == RelayWire.Status.TAKEN and a.get("ports", PackedInt32Array()) == PackedInt32Array([1]) and a.get("join_port", -1) == 0, "%s %s %s %s" % [a.get("status"), b.get("status"), c.get("status"), again.get("status")])
	var resolves := 0
	var joiner := RawWs.new(port)
	await _open(joiner)
	var found := await _ask(joiner, RelayWire.Op.RESOLVE, code_a)
	resolves += 1
	joiner.ws.put_packet(RelayWire.probe_bytes(RelayWire.Probe.JOIN, found.get("token", PackedByteArray())))
	host_a.ws.put_packet(RelayWire.probe_bytes(RelayWire.Probe.HOST, a.get("token", PackedByteArray())))
	await _until_real(func(): return false, 100)
	var payload := PackedByteArray()
	payload.resize(200)
	payload.fill(0x41)
	joiner.ws.put_packet(RelayWire.data_bytes(0, payload))
	var to_host := RelayWire.parse_data(await _message(host_a, 1500))
	var back := PackedByteArray()
	back.resize(120)
	back.fill(0x42)
	host_a.ws.put_packet(RelayWire.data_bytes(1, back))
	var to_joiner := RelayWire.parse_data(await _message(joiner, 1500))
	_check("the relay forwards both ways by token on the one port: 200 bytes to the host tagged slot 1, 120 back to the joiner", to_host.get("payload", PackedByteArray()) == payload and to_host.get("slot", -1) == 1 and to_joiner.get("payload", PackedByteArray()) == back and to_joiner.get("slot", -1) == 0, "%s / %s" % [to_host.get("slot"), to_joiner.get("slot")])
	var big := PackedByteArray()
	big.resize(301)
	big.fill(0x43)
	joiner.ws.put_packet(RelayWire.data_bytes(0, big))
	var oversize := await _message(host_a, 500)
	var fits := big.slice(0, 300)
	joiner.ws.put_packet(RelayWire.data_bytes(0, fits))
	var at_cap := RelayWire.parse_data(await _message(host_a, 1500))
	_check("acceptance (payload size): a 301-byte datagram (cap 300) is dropped, not forwarded; one of 300 goes through", oversize.is_empty() and at_cap.get("payload", PackedByteArray()) == fits)
	var second := RawWs.new(port)
	await _open(second)
	second.ws.put_packet(RelayWire.probe_bytes(RelayWire.Probe.JOIN, found.get("token", PackedByteArray())))
	second.ws.put_packet(RelayWire.data_bytes(0, payload.slice(0, 60)))
	var stranger := RawWs.new(port)
	await _open(stranger)
	stranger.ws.put_packet(RelayWire.data_bytes(0, payload.slice(0, 50)))
	joiner.ws.put_packet(RelayWire.probe_bytes(RelayWire.Probe.HOST, found.get("token", PackedByteArray())))
	host_a.ws.put_packet(RelayWire.data_bytes(9, payload.slice(0, 40)))
	var leaked := await _message(host_a, 500)
	var leaked_back := await _message(joiner, 200)
	_check("a second joiner in a full room (2 players), a link in no room, a probe of the wrong kind and a datagram for a slot with no joiner are each dropped", leaked.is_empty() and leaked_back.is_empty())
	# The code's life: 2 s after it was registered it answers expired, its host link kept
	# alive meanwhile by its probes (so it is the code's own life that ends it).
	var late := RawWs.new(port)
	await _open(late)
	await _keep_alive(host_a, a.get("token", PackedByteArray()), a_at + 2300)
	var gone := await _ask(late, RelayWire.Op.RESOLVE, code_a)
	resolves += 1
	_check("acceptance (idle expiry): the code's life trips: 2 s after it was registered it answers expired, though its host is still there", gone.get("status", -1) == RelayWire.Status.EXPIRED and host_a.ws.get_ready_state() == WebSocketPeer.STATE_OPEN, str(gone.get("status")))
	# Idle expiry: a link silent for more than the idle time (1 s) is closed by the relay.
	var quiet := RawWs.new(port)
	var quiet_open := await _open(quiet)
	var closed := await _until_real(func():
		quiet.ws.poll()
		return quiet.ws.get_ready_state() == WebSocketPeer.STATE_CLOSED, 3000)
	_check("acceptance (idle expiry): a link that says nothing for the idle time (1 s) is closed by the relay", quiet_open and closed)
	# The idle hosts' links have been closed by now: their rooms are gone, so a third fits.
	var host_d := RawWs.new(port)
	await _open(host_d)
	var later := await _ask(host_d, RelayWire.Op.REGISTER, code_c)
	_check("and the rooms of host links closed for idling are gone: the third room now fits", later.get("status", -1) == RelayWire.Status.OK, str(later.get("status")))
	await _until_real(func(): return Time.get_ticks_msec() >= a_at + 5400, 8000)
	var keep := RawWs.new(port)
	await _open(keep)
	var forgotten := await _ask(keep, RelayWire.Op.RESOLVE, code_a)
	resolves += 1
	_check("an expired code is forgotten after its 3 s of 'expired': unknown", forgotten.get("status", -1) == RelayWire.Status.UNKNOWN, str(forgotten.get("status")))
	var statuses := PackedStringArray()
	var first_busy := -1
	while resolves < 8:
		var r := await _ask(keep, RelayWire.Op.RESOLVE, code_c)
		resolves += 1
		statuses.append(str(r.get("status", -1)))
		if r.get("status", -1) == RelayWire.Status.BUSY and first_busy < 0:
			first_busy = resolves
	_check("acceptance (rate): with 6 resolutions a minute allowed, the 7th from this address is answered busy", first_busy == 7, "busy at %d; %s" % [first_busy, ", ".join(statuses)])
	# The connection cap: 8 links at once (--sources 8); the ninth is turned away.
	var crowd: Array = []
	for i in 9:
		crowd.append(RawWs.new(port))
	var turned_away := await _until_real(func():
		var shut := 0
		for one in crowd:
			one.ws.poll()
			if one.ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
				shut += 1
		return shut >= 1, 3000)
	_check("the connection cap trips: with 8 links allowed at once, a crowd of 9 more has one turned away at once", turned_away)
	for one in crowd:
		one.shut()
	# The handshake time: a TCP connection that never speaks WebSocket is closed within 5 s.
	await _until_real(func(): return false, 1200)
	var mute := StreamPeerTCP.new()
	mute.connect_to_host(LOCALHOST, port)
	var dropped := await _until_real(func():
		mute.poll()
		return mute.get_status() != StreamPeerTCP.STATUS_CONNECTED and mute.get_status() != StreamPeerTCP.STATUS_CONNECTING, 7000)
	_check("a connection that never finishes the WebSocket handshake is closed within 5 s", dropped, str(mute.get_status()))
	mute.disconnect_from_host()
	for one in [host_a, host_b, host_c, host_d, joiner, second, stranger, quiet, late, keep]:
		one.shut()
	var stopped := await _stop_relay(relay)
	var said: String = stopped["out"]
	var tripped := PackedStringArray()
	for name in ["busy", "dropped_oversize", "dropped_rate", "dropped_bad", "dropped_unknown_source", "dropped_full", "expired", "taken", "bad_code", "cookies", "closed_idle", "connections"]:
		if _counter(said, name) < 1:
			tripped.append(name)
	_check("acceptance: the relay's own counters show each limit and drop: busy, oversize, rate, bad, unknown source, full, expired, taken, bad code, cookies, idle closes, connections", tripped.is_empty() and said.contains("stopped cleanly"), "missing: %s; %s" % [", ".join(tripped), said.right(400).c_escape()])
	_check("relay B stops cleanly too (exit 0), and its output holds no address", stopped["exit"] == 0 and RegEx.create_from_string(IP_PATTERN).search(said) == null and RegEx.create_from_string(IP_PATTERN).search(stopped["err"]) == null)


func _bad_config_checks() -> void:
	var relay := _start_relay("bad", false, ["--ws-port", "70000", "--bind", LOCALHOST])
	var t0 := Time.get_ticks_msec()
	while OS.is_process_running(relay["pid"]) and Time.get_ticks_msec() - t0 < 8000:
		await process_frame
	var err: String = relay["stderr"].get_as_text()
	_check("a bad --ws-port stops the relay at once with exit 2 and the reason", not OS.is_process_running(relay["pid"]) and OS.get_process_exit_code(relay["pid"]) == 2 and err.contains("--ws-port"), err.c_escape().right(200))
	_relays.erase(relay)


# --- Helpers. ---

## Waits until the real clock reads `until_ms`, a host probe on `link` every 400 ms keeping it
## from going idle.
func _keep_alive(link: RawWs, token: PackedByteArray, until_ms: int) -> void:
	var next := 0
	while Time.get_ticks_msec() < until_ms:
		if Time.get_ticks_msec() >= next:
			link.ws.put_packet(RelayWire.probe_bytes(RelayWire.Probe.HOST, token))
			next = Time.get_ticks_msec() + 400
		link.ws.poll()
		OS.delay_msec(5)
		await process_frame


## Polls a raw link until it is open (true) or 3 s pass.
func _open(raw: RawWs) -> bool:
	return await _until_real(func():
		raw.ws.poll()
		return raw.ws.get_ready_state() == WebSocketPeer.STATE_OPEN, 3000)


## One request on a raw link, with the cookie round trip when the relay asks for it.
func _ask(raw: RawWs, op: int, code: String, token: PackedByteArray = RelayWire.zero_token()) -> Dictionary:
	for attempt in 2:
		raw.ws.put_packet(RelayWire.request_bytes(op, code, Session.PROTOCOL, 0, raw.cookie, token))
		var reply := RelayWire.parse_reply(await _message(raw, 1500))
		if reply.is_empty() or reply["status"] != RelayWire.Status.COOKIE:
			return reply
		raw.cookie = reply["token"]
	return {"status": RelayWire.Status.COOKIE}


## The next binary message on a raw link within `ms` of real time, or empty.
func _message(raw: RawWs, ms: int) -> PackedByteArray:
	var t0 := Time.get_ticks_msec()
	while true:
		raw.ws.poll()
		if raw.ws.get_available_packet_count() > 0:
			return raw.ws.get_packet()
		if Time.get_ticks_msec() - t0 > ms:
			return PackedByteArray()
		OS.delay_msec(5)
		await process_frame
	return PackedByteArray()


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
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 10000:
		var raw := RawWs.new(port)
		if await _open(raw):
			raw.ws.put_packet(RelayWire.request_bytes(RelayWire.Op.RESOLVE, RoomCode.generate(), Session.PROTOCOL, 0, raw.cookie, RelayWire.zero_token()))
			var answered := not (await _message(raw, 1000)).is_empty()
			raw.shut()
			if answered:
				return true
		await _until_real(func(): return false, 200)
	return false


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


## A TCP port free on 127.0.0.1 right now.
func _free_port() -> int:
	var probe := TCPServer.new()
	probe.listen(0, LOCALHOST)
	var port := probe.get_local_port()
	probe.stop()
	return port


func _net_tuning() -> Resource:
	var t := NetTuningScript.new()
	t.bind_address = LOCALHOST
	t.connect_timeout_ms = 3000
	t.peer_timeout_ms = 4000
	return t


func _combat_tuning() -> Resource:
	var t := CombatTuningScript.new()
	t.respawn_delay_s = 1.0
	t.spawn_protection_s = 0.3
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
	var out := {"branch": branch, "session": session, "main": main, "player": main.get_node("Player"), "hud": hud}
	out["player"].assume_captured = true
	return out


func _drop(side: Dictionary) -> void:
	var node: Node = side.get("branch")
	if is_instance_valid(node):
		for sfx in node.find_children("*", "AudioStreamPlayer", true, false):
			(sfx as AudioStreamPlayer).stop()
		var session = side.get("session")
		if session != null and is_instance_valid(session):
			session.leave()
		node.free()
	_branches.erase(node)
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


## True once `condition` holds, polled every few ms of real time; false after `ms`.
func _until_real(condition: Callable, ms: int) -> bool:
	var t0 := Time.get_ticks_msec()
	while not condition.call():
		if Time.get_ticks_msec() - t0 > ms:
			return false
		OS.delay_msec(5)
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
		at = source.find("\nstatic func %s(" % name)
	if at < 0:
		return ""
	var end := source.find("\nfunc ", at + 1)
	var end_static := source.find("\nstatic func ", at + 1)
	if end_static > 0 and (end < 0 or end_static < end):
		end = end_static
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
