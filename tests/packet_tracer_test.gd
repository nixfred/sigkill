extends SceneTree
## Headless test of the packet tracer arena (W5, PRD 5.5). scripts/check.sh runs it as step 69, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/packet_tracer_test.gd
##
## The network is the game's own invented table only (scripts/packets/net_book.gd); there is no real layer to turn on.
##
## The code: nothing of the mode can open a socket, resolve a name, run a program, write anything or touch a file (no
## file access at all), send or make a key press, or touch the input map. The table: every name its own, every address
## in the made-up subnet (or the loopback), a route from the first machine to the target. The keys: the mode adds no key
## and no action; it reads only the game's own jump (the burst) and Enter (again), so nothing collides; no Ctrl+Alt combo
## anywhere in the game's keys. The mode: off by default; queued, the arena stands in the network (its level gone, the
## islands and links built), the player on its own machine; a port boards a packet, the ride carries the player across
## (movement held, fire free) and the hop is traced; a drop under the rider is survivable (a fall into the void, the packet
## retransmitted, a little hurt, never killed) and dodgeable (a burst outruns the tear; a torn link refuses a boarding);
## an island's route holds until its fighters are down, a retransmit swarm sent again once, a man-in-the-middle holding a
## packet until it dies, a stale route sending a packet the wrong way; the SYN flood at the last hop, the results card,
## Enter's again; a walk off an island retransmitted; the visor's route; every machine name and address shown anywhere in
## the mode the table's own; the Esc menu's entry, one world mode at a time; the arena's keys unchanged.

const MainScene = preload("res://scenes/main.tscn")
const Link = preload("res://scripts/guide/guide_link.gd")
const Controls = preload("res://scripts/controls.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")
const Palette = preload("res://scripts/palette.gd")

const MODE_CODE := ["res://scripts/packets/packet_tracer.gd", "res://scripts/packets/packet_net.gd", "res://scripts/packets/net_link.gd", "res://scripts/packets/net_book.gd", "res://scripts/packets/packet_tracer_hud.gd", "res://scripts/packets/packet_sound.gd", "res://scripts/daemons/retransmit_swarm.gd", "res://scripts/daemons/mitm_tap.gd", "res://scripts/daemons/stale_route.gd", "res://scripts/daemons/syn_flood.gd"]
## Nothing of the network may be touched: no socket of any kind, no lookup, no program run, no file, no key press.
const NEVER := ["OS.execute", "create_process", "execute_with_pipe", "OS.kill", "shell_open", "move_to_trash", "HTTPRequest", "HTTPClient", "PacketPeer", "StreamPeer", "TCPServer", "UDPServer", "WebSocket", "ENetConnection", "ENetMultiplayer", "ENetPacketPeer", "WebRTC", "MultiplayerPeer", "MultiplayerAPI", "DTLS", "TLSOptions", "IP.resolve", "IP.get_", "resolve_hostname", "get_local_addresses", "get_local_interfaces", "IP.clear_cache", "FileAccess", "DirAccess", "store_", "ResourceSaver", "user://", "ConfigFile", "OS.get_environment", "set_environment", "OS.crash", "hyprctl", "omarchy-", "tailscale", "parse_input_event", "Input.action_press", "Input.action_release", "warp_mouse", "InputMap", "InputEventKey", "keycode", "clipboard_set", "print("]
const ADDRESS := "\\b\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\b"
const MOST_FRAMES := 3600
const LONG_ROUND_S := 100000.0

var _fails := 0
var _checks := 0
var _abs := ""
var _keys_before := {}


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_abs = ProjectSettings.globalize_path("user://packet-test-%d" % OS.get_process_id())
	if DirAccess.dir_exists_absolute(_abs):
		print("FAIL the test's own folder already exists; not touching it")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_abs)
	Controls.ensure()
	_keys_before = _input_map()
	GameSettings.current().reset()
	SettingsApply.apply_audio(GameSettings.current())
	MissionRunner.clear_pending()
	_clear_modes()
	MissionProgress.current().path = _abs.path_join("progress.cfg")
	MissionProgress.current().clear()
	Progress.current().path = _abs.path_join("progress.cfg")
	Progress.current().clear()
	AuditVisor.remembered = false
	_code_checks()
	_table_checks()
	_key_checks()
	await _arena_checks()
	await _run_checks()
	await _foldin_checks()
	await _menu_checks()
	_check("acceptance (no conflicts): the arena's keys are unchanged after the mode: every action and its keys as before", _input_map() == _keys_before)
	await _cleanup()
	print("PACKET TRACER: %d checks" % _checks)
	print("PACKET TRACER RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


func _clear_modes() -> void:
	ProcHunt.clear()
	FolderMap.clear()
	ThemeShift.clear()
	KeybindGunplay.clear()
	PacketTracer.clear()


# --- The code. ---

func _code_checks() -> void:
	var found := PackedStringArray()
	for path in MODE_CODE:
		var code := _code_of(path)
		if code == "":
			found.append(path + ": unreadable")
		for word in NEVER:
			if code.to_lower().contains(word.to_lower()):
				found.append("%s: %s" % [path.get_file(), word])
	_check("acceptance (safety): nothing in the mode can open a socket (no TCP, UDP, HTTP, WebSocket, ENet or WebRTC), resolve a name, run a program, signal anything, touch a file or write anything (no file access at all, nothing under user://), read the environment, send or make a key press or touch the input map, in any of its %d files" % MODE_CODE.size(), found.is_empty(), ", ".join(found))
	var actions := PackedStringArray()
	var re := RegEx.create_from_string("is_action(?:_just)?_pressed\\(\"([a-z_]+)\"")
	for path in MODE_CODE:
		for m in re.search_all(_code_of(path)):
			actions.append(m.get_string(1))
	var known := true
	for a in actions:
		known = known and InputMap.has_action(a)
	_check("acceptance (no conflicts): the mode adds no key: it reads only the game's own actions (%s), the jump's for the burst and Enter's for again" % ", ".join(actions), known and actions.size() >= 2 and actions.has("jump") and actions.has("ui_accept"))


func _code_of(path: String) -> String:
	var out := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var at := line.find("##")
		out.append(line.substr(0, at) if at >= 0 else line)
	return "\n".join(out)


# --- The table (pure). ---

func _table_checks() -> void:
	_check("acceptance: the network is the built-in invented table: %d machines, %d links, every name its own, a route to %s" % [NetBook.MACHINES.size(), NetBook.LINKS.size(), NetBook.TARGET], NetBook.problems().is_empty() and NetBook.MACHINES.size() == 7, ", ".join(NetBook.problems()))
	var subnet := "%d.%d.%d." % NetBook.SUBNET
	var bad := PackedStringArray()
	for m in NetBook.MACHINES:
		var a := NetBook.address(m)
		if not (a.begins_with(subnet) or (int(m["host"]) == -1 and a == "%d.%d.%d.%d" % NetBook.LOOPBACK)):
			bad.append(a)
	_check("acceptance (privacy): every address is the made-up subnet's (%s0/24) or the loopback for the player's own machine; nothing is looked up" % subnet, bad.is_empty() and NetBook.SUBNET == [10, 13, 37], ", ".join(bad))
	var kinds := {}
	for m in NetBook.MACHINES:
		kinds[m["kind"]] = true
	_check("each machine its own island: %d kinds (%s)" % [kinds.size(), ", ".join(PackedStringArray(kinds.keys()))], kinds.size() == NetBook.MACHINES.size())


func _key_checks() -> void:
	var ctrl_alt := PackedStringArray()
	for action in InputMap.get_actions():
		if str(action).begins_with("ui_"):
			continue  # Godot's own text-editing chords, never the game's
		for ev in InputMap.action_get_events(action):
			if ev is InputEventWithModifiers and (ev as InputEventWithModifiers).ctrl_pressed and (ev as InputEventWithModifiers).alt_pressed:
				ctrl_alt.append(str(action))
	_check("acceptance: no Ctrl+Alt combo anywhere in the game's keys (every action of its own, %d)" % InputMap.get_actions().filter(func(a): return not str(a).begins_with("ui_")).size(), ctrl_alt.is_empty(), ", ".join(ctrl_alt))


func _input_map() -> Dictionary:
	var out := {}
	for action in InputMap.get_actions():
		var evs := PackedStringArray()
		for ev in InputMap.action_get_events(action):
			evs.append(ev.as_text())
		out[str(action)] = evs
	return out


# --- The arena. ---

func _arena(queue_mode: bool) -> Node:
	MissionRunner.clear_pending()
	for old in root.get_children():
		if old.scene_file_path == "res://scenes/main.tscn":
			await _drop(old)
	_clear_modes()
	if queue_mode:
		PacketTracer.queue()
	GameSettings.current().set_value("gameplay", "practice", false)
	GameSettings.current().set_value("gameplay", "difficulty", "normal")
	GameSettings.current().set_value("gameplay", "ice", false)
	var link := Link.new()
	link.settings_path = _abs.path_join("privacy.cfg")
	link.demo = true
	Link.park(link)
	var main = MainScene.instantiate()
	root.add_child(main)
	current_scene = main
	await _ready_arena(main)
	return main


func _ready_arena(main: Node) -> void:
	main.get_node("Hud").guide().focus_check = func(): return false
	main.get_node("Hud").pause_menu().focus_check = func(): return false
	main.get_node("Hud").round_hud()._left_s = LONG_ROUND_S
	var player = main.get_node("Player")
	player.assume_captured = true
	player.velocity = Vector3.ZERO
	await _frames(3)


func _after_reload(old_id: int) -> Node:
	await _until(func(): return current_scene != null and current_scene.get_instance_id() != old_id and current_scene.has_node("Hud") and current_scene.is_node_ready())
	var main := current_scene
	await _ready_arena(main)
	await _frames(2)
	return main


func _arena_checks() -> void:
	var plain := await _arena(false)
	var m0 := PacketTracer.of(plain)
	await _frames(10)
	_check("acceptance: off by default: the mode stands in the arena, not running, no network, the arena's own level", m0 != null and not m0.running and PacketNet.of(plain) == null and _blocks(plain) > 0)


func _run_checks() -> void:
	var main := await _arena(true)
	var mode := PacketTracer.of(main)
	await _until(func(): return mode.running)
	await _frames(30)
	var player = main.get_node("Player")
	var life = main.get_node("SoloLife")
	var net := mode.net
	var blocks := _blocks(main)
	_check("acceptance: queued (the Esc menu, or --net), the arena stands in the network: its level gone, %d islands and %d links built, the player on its own machine" % [net.islands.size() if net != null else 0, net.links.size() if net != null else 0], net != null and blocks == 0 and net.islands.size() == NetBook.MACHINES.size() and net.links.size() == NetBook.LINKS.size() and net.island_under(player.global_position) == 0 and mode.at_island == 0)
	var first: NetLink = net.links[0]
	await _until(func(): return first.state == NetLink.State.UP)
	_check("its own machine holds nothing: the route out is up at once (SYN, then up), the next hop named on the panel", mode.phase == "clear" and first.state == NetLink.State.UP and Array(_hud(mode).lines()).any(func(l): return l.begins_with("next: -> gw-lantern")))
	var looks := true
	for e in ["gw-lantern", "rack-delta"]:
		looks = looks and net.islands[net.island_index(e)]["node"].find_children("*", "MeshInstance3D", true, false).size() >= 8
	_check("islands with machines on them (the router's, the rack's: a dozen parts and more each) and every link streaming its packets", looks and net.find_children("Packets", "MultiMeshInstance3D", true, false).size() == 1)
	life.shield(9999.0)
	# Board: step onto the port and stand.
	var port0 := net.port(0, "localhost")
	player.global_position = port0 + Vector3.UP * 0.95
	player.velocity = Vector3.ZERO
	await _frames(int(PacketTracer.BOARD_S * 60.0) + 6)
	_check("acceptance: standing on a port boards a packet: the ride begins, the player carried (riding)", mode.phase == "ride" and player.riding and int(mode.ride["link"]) == 0)
	var u0 := float(mode.ride["u"])
	var shots: int = player.shots_fired
	player.drive_input(Vector2(0.0, -1.0), true, false, true)
	await _frames(2)
	var on_curve: bool = player.global_position.distance_to(first.at(mode.ride_link_u()) + Vector3.UP * PacketTracer.RIDE_STAND) < 0.05
	_check("acceptance: the ride carries the player along the link (%.0f%% along), walking and jumping held, aiming and fire free (a shot fired mid-ride)" % (float(mode.ride["u"]) * 100.0), float(mode.ride["u"]) > u0 and on_curve and player.shots_fired > shots)
	await _until(func(): return mode.phase != "ride")
	var hop1: Dictionary = mode.trace[mode.trace.size() - 1] if not mode.trace.is_empty() else {}
	_check("acceptance: the ride lands on the far island and its hop is traced (%s %.1f ms), its daemons waking (%d)" % [str(hop1.get("id", "")), float(hop1.get("ms", 0.0)), mode.standing_on("gw-lantern")], mode.at_island == 1 and str(hop1.get("id", "")) == "gw-lantern" and float(hop1.get("ms", 0.0)) > 500.0 and not player.riding and mode.standing_on("gw-lantern") == 3 and net.island_under(player.global_position) == 1)
	_check("the panel prints the trace as traceroute does (\"%s\")" % _hud(mode).trace_lines()[1], _hud(mode).trace_lines()[0].begins_with("traceroute to core-sink (%s)" % NetBook.address(NetBook.machine("core-sink"))) and _hud(mode).trace_lines()[1].begins_with(" 1  gw-lantern (%s)" % NetBook.address(NetBook.machine("gw-lantern"))))
	# The route holds until the fighters are down; a retransmit swarm comes back once.
	var out1: NetLink = net.links[1]
	_check("an island's route holds while its daemons stand: no route to host", out1.state == NetLink.State.DOWN and mode.phase == "island" and not out1.boardable())
	await _kill(mode, func(e): return e["island"] == "gw-lantern")
	await _until(func(): return mode.enemies.any(func(e): return e["dup"] and e["body"].is_alive()))
	var dups := mode.enemies.filter(func(e): return e["dup"] and e["island"] == "gw-lantern" and e["body"].is_alive())
	_check("acceptance: a retransmit swarm killed is sent again: a dup where it fell, and the route still held", dups.size() == 1 and out1.state == NetLink.State.DOWN, "dups %d, link %d, phase %s, at %d, pending %d, %s" % [dups.size(), out1.state, mode.phase, mode.at_island, mode._dups.size(), str(mode.enemies.map(func(e): return "%s/%s/%s/%s" % [e["kind"], e["island"], e["dup"], e["body"].state if is_instance_valid(e["body"]) else "gone"]))])
	await _kill(mode, func(e): return e["island"] == "gw-lantern")
	await _frames(int(NetLink.SYN_S * 60.0) + 10)
	_check("the dup down, the route comes up (SYN, then up)", out1.state == NetLink.State.UP and mode.phase == "clear")
	# A drop under the rider: survivable.
	life.combat.states[1]["protect_left"] = 0.0
	var health_before: float = life.health()
	mode.board(1)
	await _frames(20)
	# It goes bad under the rider: the mode tears it where the rider will be as it opens.
	out1.go_flaky(0.92)
	await _frames(4)
	var threat := out1.tear_u < 0.9 and out1.tear_u > mode.ride_link_u()
	var warned: bool = Array(_hud(mode).lines()).any(func(l): return l.begins_with("RIDING")) and out1.state == NetLink.State.FLAKY
	await _until(func(): return mode.phase == "fall")
	_check("acceptance: a link going bad warns first (it stutters, TIMEOUT where it will tear, a little ahead of the rider), then tears under the rider kept at its pace: the player falls into the void", threat and warned and mode.phase == "fall" and not player.riding and int(PacketTracer.stats["taken"]) == 1)
	await _until(func(): return mode.phase != "fall")
	var hurt: float = health_before - life.health()
	_check("acceptance: the drop is survivable: the packet retransmitted, the player back on the island it boarded from, a little hurt (%.0f), alive" % hurt, mode.at_island == 1 and net.island_under(player.global_position) == 1 and life.alive() and player.alive and hurt > 0.0 and hurt <= 15.0)  # pinned here, so a changed constant cannot move its own check
	life.shield(9999.0)
	# A torn link refuses a boarding; a burst outruns a tear.
	await _until(func(): return out1.state == NetLink.State.UP)
	out1.go_flaky(0.5)
	await _frames(int(NetLink.FLAKY_S * 60.0) + 4)
	var refused := not mode.board(1) and mode.ride.is_empty()
	_check("acceptance (dodgeable): a torn link refuses a packet: wait it out (connection refused)", refused and out1.state == NetLink.State.DROPPED)
	await _until(func(): return out1.state == NetLink.State.UP)
	mode.board(1)
	await _frames(12)
	out1.go_flaky(0.5)
	await _frames(20)
	var burst := mode.burst()
	var again_burst := mode.burst()
	await _until(func(): return mode.phase != "ride")
	_check("acceptance (dodgeable): a burst (Space, once a ride) outruns the tear: the packet lands, the drop counted dodged", burst and not again_burst and mode.at_island == 2 and int(PacketTracer.stats["dodged"]) >= 1 and int(PacketTracer.stats["taken"]) == 1)
	var lost: bool = Array(_hud(mode).trace_lines()).any(func(l): return l == " 2  * * *")
	_check("the lost packet is in the trace as traceroute prints a timeout (\" 2  * * *\" before hop 2)", lost)
	# The man in the middle holds a packet.
	var tap := mode.enemies.filter(func(e): return e["kind"] == "mitm")
	_check("a man-in-the-middle clamped on the next link (its own form, violet), the link tapped", tap.size() == 1 and int(tap[0]["link"]) == 2 and (net.links[2] as NetLink).tap_u > 0.0 and tap[0]["body"].art_node().get_script() == preload("res://scripts/daemons/mitm_tap.gd"))
	await _kill(mode, func(e): return e["island"] == "rack-delta")
	await _until(func(): return (net.links[2] as NetLink).state == NetLink.State.UP)
	(net.links[2] as NetLink).loss = 0.0
	mode.board(2)
	await _until(func(): return mode.phase == "ride" and bool(mode.ride["held"]))
	await _frames(30)
	var held_u := mode.ride_link_u()
	_check("acceptance: a packet meeting the man in the middle is held before it, intercepted, while it lives", mode.phase == "ride" and bool(mode.ride["held"]) and held_u < float(tap[0]["u"]) and int(PacketTracer.stats["intercepted"]) == 1)
	var thud = mode.get("_hud")
	_check("fold-in (W5's known issue, folded in with W7): INTERCEPTED is said once, by the ride's own line while the packet is held, never by a banner over it too", thud != null and thud.banner_head() != "INTERCEPTED", str(thud.banner_head()) if thud != null else "no HUD")
	await _kill(mode, func(e): return e["kind"] == "mitm")
	await _until(func(): return mode.phase != "ride")
	_check("the man in the middle down, the ride goes on and lands", mode.at_island == 3)
	# The stale route sends a packet the wrong way.
	await _kill(mode, func(e): return e["island"] == "edge-board" and e["kind"] != "stale")
	var stale := mode.enemies.filter(func(e): return e["kind"] == "stale" and e["body"].is_alive())
	await _dups_up(mode)
	await _kill(mode, func(e): return e["island"] == "edge-board" and e["kind"] != "stale")
	await _until(func(): return (net.links[3] as NetLink).state == NetLink.State.UP)
	(net.links[3] as NetLink).loss = 0.0
	mode.board(3)
	var wrong := int(mode.ride.get("link", -1))
	await _until(func(): return mode.phase != "ride")
	_check("acceptance: a stale route standing at the port sends the packet the wrong way: back to gw-lantern (its own form: a signpost of wrong arrows)", stale.size() == 1 and wrong == NetBook.link_between("edge-board", "gw-lantern") and mode.at_island == 1 and int(PacketTracer.stats["misrouted"]) == 1 and stale[0]["body"].art_node().get_script() == preload("res://scripts/daemons/stale_route.gd"))
	_check("a wrong way is never boarded on its own: only a stale route sends a packet down it", not mode.board(NetBook.link_between("edge-board", "gw-lantern")) and mode.ride.is_empty())
	# Back the long way: up the trace again, hop by hop.
	for li in [1, 2]:
		(net.links[li] as NetLink).loss = 0.0
		await _until(func(): return (net.links[li] as NetLink).state == NetLink.State.UP)
		mode.board(li)
		await _until(func(): return mode.phase != "ride")
	await _kill(mode, func(e): return e["kind"] == "stale" and e["island"] == "edge-board")
	await _frames(2)
	# On to the end: each island's fighters down, its link ridden.
	for i in [3, 4, 5]:
		var f := NetBook.forward_from(net.islands[i]["id"])
		await _kill(mode, func(e): return e["island"] == net.islands[i]["id"] or (e["kind"] == "mitm" and int(e["link"]) == f))
		await _dups_up(mode)
		await _kill(mode, func(e): return e["island"] == net.islands[i]["id"] or (e["kind"] == "mitm" and int(e["link"]) == f))
		await _until(func(): return (net.links[f] as NetLink).state == NetLink.State.UP)
		(net.links[f] as NetLink).loss = 0.0
		mode.board(f)
		await _until(func(): return mode.phase != "ride")
	var boss := mode.enemies.filter(func(e): return e["kind"] == "flood")
	await _frames(240)
	_check("acceptance: the last hop, core-sink: the SYN flood (its own form, a pegged core's brain: risen over the dais, telling and firing)", mode.at_island == 6 and boss.size() == 1 and boss[0]["body"].art_node().get_script() == preload("res://scripts/daemons/syn_flood.gd") and boss[0]["body"].brain.kind == "pegged" and boss[0]["body"].global_position.y > net.top(6).y + 2.0)
	mode._flood_t = PacketTracer.FLOOD_EVERY_S
	await _frames(3)
	var flooded := mode.enemies.filter(func(e): return e["kind"] == "retransmit" and e["island"] == "core-sink").size()
	_check("the flood throws retransmits off itself (%d)" % flooded, flooded >= 1 and flooded <= PacketTracer.FLOOD_MOST)
	# The visor: the route, hop by hop, every daemon's connection.
	var visor = main.find_children("*", "AuditVisor", true, false)[0]
	visor.toggle()
	await _frames(4)
	var marks := mode.get_tree().get_nodes_in_group(PacketTracer.MARK_GROUP).filter(func(l): return l.visible)
	_check("the visor in the mode: the trace drawn hop to hop through walls, each machine's hop, name and address, each daemon's connection", visor.on and marks.size() >= NetBook.MACHINES.size() and marks.any(func(l): return (l.text as String).contains("hop 6  core-sink")))
	_names_check(main, mode, "mid-run, the visor on")
	visor.toggle()
	await _kill(mode, func(e): return e["kind"] == "flood")
	await _until(func(): return mode.phase == "results")
	var rows: PackedStringArray = _hud(mode).result_lines()
	_check("acceptance: the run ends on its results card: the whole trace (%d hops, the lost packet's * * *), hops, drops dodged and taken, kills, time" % NetBook.hops(), mode.phase == "results" and Array(rows).any(func(r): return r == " 2  * * *") and rows.size() >= 10 and Array(rows).any(func(r): return r.begins_with(" 6  core-sink (%s)" % NetBook.address(NetBook.machine("core-sink")))) and Array(rows).any(func(r): return r.begins_with("hops 6 of 6")) and Array(rows).any(func(r): return r.begins_with("drops dodged") and r.contains("packets lost 1")) and Array(rows).any(func(r): return r.begins_with("kills") and r.contains("time ")), " / ".join(rows))
	var ev := InputEventAction.new()
	ev.action = "ui_accept"
	ev.pressed = true
	mode._unhandled_input(ev)
	await _frames(int(NetLink.SYN_S * 60.0) + 10)
	_check("Enter traces it again from its own machine", mode.phase == "clear" and mode.at_island == 0 and int(PacketTracer.stats["hops"]) == 0 and net.island_under(player.global_position) == 0)
	# Killed on a ride: off the packet, and back on the island it left when it respawns.
	await _until(func(): return (net.links[0] as NetLink).state == NetLink.State.UP)
	mode.board(0)
	await _frames(20)
	life.combat.states[1]["protect_left"] = 0.0
	life.damage(100000.0, null, Vector3.ZERO)
	await _frames(3)
	var off_ride: bool = mode.ride.is_empty() and not player.riding and mode.phase != "ride"
	await _until(func(): return life.alive() and player.alive)
	await _frames(5)
	_check("a rider killed mid-ride is off the packet at once, and respawns on the island it left (never carried back onto the link)", off_ride and net.island_under(player.global_position) == 0 and mode.ride.is_empty())
	life.shield(9999.0)
	# A walk off the island's edge: retransmitted the same.
	player.global_position = net.top(0) + Vector3(0.0, -9.0, 30.0)
	player.velocity = Vector3.ZERO
	await _until(func(): return mode.phase == "fall")
	await _until(func(): return mode.phase != "fall")
	_check("a fall off an island into the void is retransmitted too (back on its deck)", net.island_under(player.global_position) == 0 and int(PacketTracer.stats["falls"]) == 1, "under %d, falls %d, at %s, phase %s" % [net.island_under(player.global_position), int(PacketTracer.stats["falls"]), str(player.global_position), mode.phase])
	_names_check(main, mode, "at the end")


## Every name and address any label or panel line of the mode shows: the table's own.
func _names_check(main: Node, mode: PacketTracer, when: String) -> void:
	var re := RegEx.create_from_string(ADDRESS)
	var names := NetBook.names()
	var addresses := NetBook.addresses()
	var texts := PackedStringArray()
	for l in main.find_children("*", "Label3D", true, false):
		if PacketNet.of(main).is_ancestor_of(l) or mode.is_ancestor_of(l):
			texts.append(l.text)
	texts.append_array(_hud(mode).lines())
	texts.append_array(_hud(mode).result_lines())
	for e in mode.events:
		texts.append(str(e["text"]))
	var bad := PackedStringArray()
	var seen_addr := 0
	for t in texts:
		for m in re.search_all(t):
			seen_addr += 1
			if not addresses.has(m.get_string()):
				bad.append(m.get_string())
	var name_re := RegEx.create_from_string("(?:->|to|from|hop \\d+ ) ?([a-z]+-[a-z]+|localhost)")
	var seen_names := 0
	for t in texts:
		for m in name_re.search_all(t):
			seen_names += 1
			if not names.has(m.get_string(1)):
				bad.append(m.get_string(1))
	var isl_ok := true
	for isl in PacketNet.of(main).islands:
		var label: Label3D = isl["label"]
		var head := label.text.split("\n")
		isl_ok = isl_ok and names.has(head[0]) and addresses.has(head[1])
	_check("acceptance (privacy, %s): every machine name and address the mode shows (%d addresses, %d names over %d labels and lines) is the built-in invented table's" % [when, seen_addr, seen_names, texts.size()], bad.is_empty() and isl_ok and seen_addr > 0 and seen_names > 0, ", ".join(bad))


## Every retransmit sent again is up (or none was sent): nothing of a dup still on its way or climbing in.
func _dups_up(mode: PacketTracer) -> void:
	await _until(func(): return mode._dups.is_empty() and not mode.enemies.any(func(e): return is_instance_valid(e["body"]) and e["body"].climbing()))


func _blocks(main: Node) -> int:
	var n := 0
	for node in main.find_children("*", "", true, false):
		if node.get_script() == preload("res://scripts/grey_block.gd"):
			n += 1
	return n


## Every one of its daemons `which` picks, once it has climbed in, shot down.
func _kill(mode: PacketTracer, which: Callable) -> void:
	await _until(func(): return not mode.enemies.any(func(e): return is_instance_valid(e["body"]) and e["body"].climbing() and which.call(e)))
	for e in mode.enemies.duplicate():
		var body = e["body"]
		if is_instance_valid(body) and body.is_alive() and which.call(e):
			body.hit(100000.0, body.threat_point(), Vector3.FORWARD, "test")


func _hud(mode: PacketTracer) -> PacketTracerHud:
	var found := mode.find_children("*", "PacketTracerHud", true, false)
	return found[0] if not found.is_empty() else null


## W6's fold-ins of W5's known issues: a player backing onto a port mid-fight is not carried off; the man in the middle's
## bolts fly in its own violet, not the zombie's amber.
func _foldin_checks() -> void:
	var main := await _arena(true)
	var mode := PacketTracer.of(main)
	await _until(func(): return mode.running)
	var net := mode.net
	var first: NetLink = net.links[0]
	await _until(func(): return first.state == NetLink.State.UP)
	var player = main.get_node("Player")
	main.get_node("SoloLife").shield(9999.0)
	var port0 := net.port(0, "localhost")
	var inward: Vector3 = net.top(0) - port0
	player.global_position = port0 + Vector3.UP * 0.95
	player.velocity = Vector3.ZERO
	player.rotation.y = atan2(-inward.x, -inward.z)  # facing back into the island: backing onto the port
	await _frames(int(PacketTracer.BOARD_S * 60.0) * 3)
	var held: bool = mode.phase != "ride" and not player.riding and not mode.facing_out(0)
	player.rotation.y = atan2(inward.x, inward.z)  # turned to face out along the link
	await _frames(int(PacketTracer.BOARD_S * 60.0) + 6)
	_check("fold-in (W5's known issue): backing onto a port facing the fight does not board it; turned out along the link, it boards", held and mode.phase == "ride" and player.riding)
	mode._let_go()
	mode._enter("clear")
	mode._spawn_mitm(2)
	await _frames(40)
	var tap = null
	for e in mode.enemies:
		if e["kind"] == "mitm" and is_instance_valid(e["body"]):
			tap = e["body"]
	var bolt: GlitchBolt = null
	if tap != null and tap.brain != null:
		bolt = mode.director.throw_bolt(tap.brain, tap.global_position + Vector3.UP, Vector3.FORWARD)
	_check("fold-in (W5's known issue): the man in the middle's bolt flies in its own violet (%s), not the zombie's amber" % (bolt.tint.to_html(false) if bolt != null else "none"), bolt != null and bolt.tint.is_equal_approx(preload("res://scripts/daemons/mitm_tap.gd").TAP_VIOLET) and not bolt.tint.is_equal_approx(Palette.HOSTILE_AMBER))
	if bolt != null:
		bolt.stop()
	# The visor over the SYN flood: the daemons round it folded into its own tag, never a pile of tags over it.
	var at := net.top(2)
	var flood := mode._spawn("flood", at + Vector3.UP * 0.6, "fold_flood", "rack-delta", -1, -1.0)
	mode._spawn("retransmit", at + Vector3(2.0, 1.0, 0.0), "fold_r1", "rack-delta", -1, -1.0)
	mode._spawn("retransmit", at + Vector3(-2.0, 1.0, 1.0), "fold_r2", "rack-delta", -1, -1.0)
	await _until(func(): return not mode.enemies.any(func(e): return is_instance_valid(e["body"]) and e["body"].climbing()))
	mode.visor.toggle()
	await _frames(6)
	var near := 0
	var flood_text := ""
	for m in main.get_tree().get_nodes_in_group(PacketTracer.MARK_GROUP):
		var l := m as Label3D
		if l.visible and l.text.contains("ESTAB") and l.global_position.distance_to(flood.global_position) < PacketTracer.CROWD_M + 3.5:
			near += 1
			if l.text.begins_with("SYN flood"):
				flood_text = l.text
	mode.visor.toggle()
	_check("fold-in (W5's known issue): the visor's tags never crowd over the SYN flood: the daemons round it folded into its own tag (%d tag there: \"%s\")" % [near, flood_text.replace("\n", " / ")], near == 1 and flood_text.contains("+2 SYN_RECV"))


func _menu_checks() -> void:
	var main := await _arena(false)
	var menu = main.get_node("Hud").pause_menu()
	menu.open()
	await _frames(2)
	var b: Button = menu.net_button()
	var plain_ok: bool = b != null and b.text == "Packet tracer" and not b.disabled and b.is_visible_in_tree()
	menu.close()
	FolderMap.queued = true
	ProcHunt.queued = true
	ThemeShift.queued = true
	KeybindGunplay.queued = true
	menu.toggle_packet_tracer()
	var one: bool = PacketTracer.queued and not FolderMap.queued and not ProcHunt.queued and not ThemeShift.queued and not KeybindGunplay.queued
	var old_id := main.get_instance_id()
	main = await _after_reload(old_id)
	var mode := PacketTracer.of(main)
	await _until(func(): return mode != null and mode.running)
	menu = main.get_node("Hud").pause_menu()
	menu.open()
	await _frames(2)
	var leave_ok: bool = menu.net_button().text == "Leave packet tracer"
	menu.close()
	_check("acceptance: the Esc menu reaches it: \"Packet tracer\" in the free arena, \"Leave packet tracer\" while it runs; one world mode at a time (the hunt, the map, the theme shift and keybind gunplay end as it begins)", plain_ok and leave_ok and one and mode.running)
	menu.toggle_keybind_gunplay()
	_check("and it ends as another world mode begins", not PacketTracer.queued and KeybindGunplay.queued)
	old_id = main.get_instance_id()
	main = await _after_reload(old_id)
	KeybindGunplay.clear()
	PacketTracer.clear()


func _cleanup() -> void:
	MissionRunner.clear_pending()
	_clear_modes()
	for node in root.get_children():
		if node.scene_file_path == "res://scenes/main.tscn":
			await _drop(node)
	current_scene = null
	AuditVisor.remembered = false
	GameSettings.current().reset()
	MissionProgress.current().path = ""
	MissionProgress.current().clear()
	Progress.current().path = ""
	Progress.current().clear()
	_wipe(_abs)
	_check("the test's own folder is gone, nothing of it left under user://", not DirAccess.dir_exists_absolute(_abs))


## The test's own folder only, file by file.
func _wipe(path: String) -> void:
	if not path.begins_with(ProjectSettings.globalize_path("user://packet-test-")):
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


func _drop(main: Node) -> void:
	if is_instance_valid(main):
		for sfx in main.find_children("*", "AudioStreamPlayer", true, false):
			(sfx as AudioStreamPlayer).stop()
		for sfx in main.find_children("*", "AudioStreamPlayer3D", true, false):
			(sfx as AudioStreamPlayer3D).stop()
		if current_scene == main:
			current_scene = null
		main.queue_free()
		await _frames(3)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _until(condition: Callable) -> bool:
	var frames := 0
	while frames < MOST_FRAMES and not condition.call():
		await process_frame
		frames += 1
	return condition.call()
