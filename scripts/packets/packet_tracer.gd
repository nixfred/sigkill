class_name PacketTracer
extends Node3D
## The packet tracer arena (W5, PRD 5.5; the fifth of M5's world features): a network of machines as islands floating in
## a dark void (scripts/packets/packet_net.gd), joined by glowing links, and a traceroute run across it. Reached from the
## Esc menu ("Packet tracer"; "Leave packet tracer" ends it), or with --net on a demo or test run. Made by the arena
## (scripts/main.gd) beside the other world modes; it begins when queued, in the network the arena was staged in.
##
## The run, a traceroute from the player's own machine to the last hop (NetBook.TARGET), ending on a results card (every
## hop and its time, the drops dodged and taken, the kills, the time):
##   island  the machine's daemons wake as the player lands (its hop printed in the trace); its forward link has no route
##           until its fighters are down (a stale route and a man-in-the-middle do not hold it)
##   clear   its forward link reconnects (SYN, then up): step onto its port and a packet carries the player across
##   ride    on a packet down the link, fast; looking and fire stay free; Space bursts (once a ride) to outrun a tear
##   the last hop's SYN flood down, the trace is complete: the results card; Enter runs it again
##
## Riding, and dropped connections: a link goes bad on its own schedule (NetLink: it stutters and burns amber, TIMEOUT
## counting down where it will tear, then it tears from there toward both ends). A rider the gap reaches falls into the
## void: survivable, the packet is lost and retransmitted (the player sent again from the port it boarded at, a little
## hurt, never killed by it), a "* * *" in the trace. Dodged by timing: board a steady link, or burst through before the
## tear; a drop threatened on a ride that arrived counts as dodged. A walk off an island's edge is retransmitted the same.
##
## Its own daemons, each its own form (scripts/daemons/): the arena's three on the islands; a retransmit swarm (a train of
## packets; killed once, it is sent again, a smaller dup where it fell); a stale route at a machine's forward port (while
## it stands, a packet boarding there is sent the wrong way, back up the trace); a man-in-the-middle clamped on a link
## (it fires on the player in reach, and a packet meeting it is held, intercepted, until it dies); and at the last hop the
## SYN flood (a pegged core's brain: it rises, tells and fires volleys, and floods retransmits off itself).
##
## Demo layer only, by the producer's decision for W5: every machine, name and address is the game's own invented table
## (scripts/packets/net_book.gd). No real layer: every source for one would mean running a program or talking to a daemon,
## which the game never does. Nothing here reads, opens a socket, resolves a name, sends anything or runs anything; every
## packet is simulated, every drop and kill is the game's own.

const DummyScene = preload("res://scenes/target_dummy.tscn")
const RogueArt = preload("res://scripts/daemons/rogue_daemon.gd")
const ZombieArt = preload("res://scripts/daemons/zombie_process.gd")
const RunawayArt = preload("res://scripts/daemons/runaway_swarm.gd")
const RetransmitArt = preload("res://scripts/daemons/retransmit_swarm.gd")
const MitmArt = preload("res://scripts/daemons/mitm_tap.gd")
const StaleArt = preload("res://scripts/daemons/stale_route.gd")
const FloodArt = preload("res://scripts/daemons/syn_flood.gd")
const Palette = preload("res://scripts/palette.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")

const GROUP := &"packet_tracer"
const NODE_NAME := "PacketTracer"
const FLAG := "--net"
const RELOAD_LABEL := "$ traceroute core-sink"
## A ride: its pace (metres a second), a burst's and how long it lasts; how long the player stands on a port to board, and
## how near its middle.
const RIDE_SPEED := 24.0
const BURST_SPEED := 64.0
const BURST_S := 0.9
const BOARD_S := 0.35
const PORT_REACH := 1.9
## How high the player stands over the packet's middle while it rides.
const RIDE_STAND := 1.15
## How far past where the rider will be a threatened link tears (metres): no rider at its pace slips past.
const THREAT_AHEAD_M := 2.0
## The ridden packet's size: wide enough to stand on.
const RIDER_SLAB := Vector3(1.5, 0.3, 2.2)
## A fall: lost this far under the lowest deck (or after FALL_S), then retransmitted, a little hurt but never killed.
const LOST_BELOW := 16.0
const FALL_S := 2.2
const DROP_HURT := 15.0
## A retransmit swarm sent again: a dup this long after it fell, this much smaller.
const DUP_S := 0.8
const DUP_SIZE := 0.8
## The man in the middle: how far it reaches, how often it fires and its tell; how far before it a packet is held.
const MITM_REACH := 48.0
const MITM_EVERY_S := 2.8
const MITM_TELL_S := 0.7
const MITM_HOLD_M := 3.2
const MITM_LIFT := 0.9
## The SYN flood's floods: how often, how many retransmits each, how many of them standing at most.
const FLOOD_EVERY_S := 11.0
const FLOOD_SENDS := 2
const FLOOD_MOST := 4
const DONE_S := 1.2
## The boss and the stale route drawn bigger than their art's own size: the boss over a deck 34 m wide, the signpost
## standing taller than a player at its port.
const BOSS_SIZE := 1.6
const STALE_SIZE := 1.3
const EVENTS_KEPT := 5
const HEALTH := {"rogue": 50.0, "zombie": 75.0, "runaway": 25.0, "retransmit": 25.0, "mitm": 100.0, "stale": 60.0, "flood": 600.0}
const TAGS := {"rogue": "rogue.d", "zombie": "zombie", "runaway": "runaway", "retransmit": "retransmit", "mitm": "mitm", "stale": "stale route", "flood": "SYN flood"}
## Kinds that do not hold an island's route: the stale route and the man-in-the-middle are the way's own dangers.
const NOT_HOLDING := ["stale", "mitm"]
## The visor's labels over the machines and the daemons (the checks find them here).
const MARK_GROUP := &"packet_route_mark"

static var queued := false
## The run's numbers, kept across a reload (the HUD and the results card read them).
static var stats := {}
static var _flag_taken := false
static var _going := false
static var _misses := 0
const MISSES_MOST := 2

signal began
signal ended
signal spawned(dummy: Node3D)
signal event(kind: String, text: String)
signal hopped(hop: int, id: String)
signal dropped(link: int, ridden: bool)

var running := false
var player: Node3D = null
var director: DaemonDirector = null
var runner: MissionRunner = null
var ice: Node = null
var rounds: Node = null
var guide: Node = null
var visor: Node = null
var net: PacketNet = null
## "island" (its daemons standing), "clear" (its route up), "ride", "fall", "done" (the last hop down), "results".
var phase := ""
## The island the player is on, or last stood on (an index into the network's islands).
var at_island := 0
var reached := {}
## The trace so far: {hop, id, addr, ms, lost} each.
var trace: Array = []
## Its enemies: {body, kind, island (an id, "" on a link), link (-1 on an island), u, dup}.
var enemies: Array = []
var events: Array = []
## The ride now: {link, from, to, dir, u, burst, bursts, held, warned, start}; empty when not riding.
var ride := {}
var _clock := 0.0
var _phase_t := 0.0
var _board_t := 0.0
var _board_link := -1
var _port_block := -1
var _fall_t := 0.0
var _fall_from := -1
var _hop_lost := 0
var _hop_start := 0.0
var _dups: Array = []
var _flood_t := 0.0
var _flood_glow := 0.0
var _refused_t := 0.0
var _hud: CanvasLayer = null
var _lines: VisorLines = null
var _marks := {}
var _sfx: AudioStreamPlayer = null
var _parked: Array = []
## The packet the player rides: a slab of light under its feet, in its link's colour.
var _rider: MeshInstance3D = null


static func of(node: Node) -> PacketTracer:
	if node == null or not node.is_inside_tree():
		return null
	var mine := node.get_node_or_null(NODE_NAME) as PacketTracer
	if mine != null:
		return mine
	for m in node.get_tree().get_nodes_in_group(GROUP):
		if not m.is_queued_for_deletion():
			return m as PacketTracer
	return null


static func queue() -> void:
	queued = true
	stats = {}


static func clear() -> void:
	queued = false
	stats = {}


static func take_flag(args: PackedStringArray) -> void:
	if _flag_taken:
		return
	_flag_taken = true
	if args.has(FLAG) and (args.has("--demo") or OS.get_cmdline_args().has("--script")):
		queue()


## As the arena loads, before it is staged (scripts/main.gd): true when the arena should stand in the network (queued,
## alone, no mission). No reader to prepare: the network is the game's own.
static func prepare(args: PackedStringArray, online: bool) -> bool:
	take_flag(args)
	_going = false
	return queued and not online and MissionRunner.pending() == ""


static func fresh_stats() -> Dictionary:
	return {"hops": 0, "rides": 0, "dodged": 0, "taken": 0, "falls": 0, "kills": 0, "bursts": 0, "misrouted": 0, "intercepted": 0, "time": 0.0}


func _ready() -> void:
	name = NODE_NAME
	add_to_group(GROUP)


func _exit_tree() -> void:
	_let_go()


## Begins the run where the arena stands in the network: the arena's own daemons parked, ICE stood down, the rounds held,
## the player on its own machine. False online, in a mission, or not in the network (it reloads into it first).
func begin() -> bool:
	if running or _online() or (runner != null and is_instance_valid(runner) and runner.running()):
		return false
	running = true
	queued = true
	net = PacketNet.of(self)
	if net == null:
		running = false
		_misses += 1
		if _misses > MISSES_MOST:
			_misses = 0
			clear()
			return false
		_go(RELOAD_LABEL)
		return false
	_misses = 0
	_park_arena_daemons()
	if ice != null and is_instance_valid(ice) and "stand_down" in ice:
		ice.stand_down = true
	if rounds != null and is_instance_valid(rounds) and rounds.has_method("hold"):
		rounds.hold(true)
	_hud = PacketTracerHud.new()
	_hud.mode = self
	add_child(_hud)
	_lines = VisorLines.new()
	_lines.through_walls = true
	add_child(_lines)
	_sfx = AudioStreamPlayer.new()
	_sfx.name = "Packets"
	_sfx.bus = SettingsApply.EFFECTS if AudioServer.get_bus_index(SettingsApply.EFFECTS) >= 0 else &"Master"
	_sfx.max_polyphony = 4
	add_child(_sfx)
	_start_run()
	began.emit()
	return true


func _start_run() -> void:
	stats = fresh_stats()
	reached = {}
	trace = []
	ride = {}
	_dups.clear()
	_clear_enemies()
	for link in net.links:
		(link as NetLink).state = NetLink.State.DOWN
		link.state_t = 0.0
		link.tear_open = 0.0
		link.tap_u = -1.0
		link.stale = false
		link.drops = 0
		if not link.forward:
			link.open_route(_clock)  # the wrong ways are always up: a stale route sends packets down them
	at_island = 0
	_arrive(0, true)
	_note("begin", "traceroute to %s (%s), %d hops, 60 byte packets" % [NetBook.TARGET, NetBook.address(NetBook.machine(NetBook.TARGET)), NetBook.hops()])


## Ends the mode where it stands (a match starting, the Esc menu's way out): its enemies gone, the arena's own back, ICE
## and the rounds as they were. Not queued any more.
func end() -> void:
	if not running:
		return
	running = false
	_let_go()
	_clear_enemies()
	_release_parked()
	if ice != null and is_instance_valid(ice) and "stand_down" in ice:
		ice.stand_down = false
	if rounds != null and is_instance_valid(rounds) and rounds.has_method("hold"):
		rounds.hold(false)
	_forget()
	for node in get_children():
		node.queue_free()
	_hud = null
	_lines = null
	clear()
	ended.emit()


func _let_go() -> void:
	if _rider != null and is_instance_valid(_rider):
		_rider.visible = false
	if player != null and is_instance_valid(player):
		if "riding" in player:
			player.riding = false
		if "ride_kick" in player:
			player.ride_kick = 0.0
	ride = {}


func _online() -> bool:
	var session = director.session if director != null and is_instance_valid(director) else null
	return session != null and is_instance_valid(session) and session.has_method("is_online") and session.is_online()


# --- Hops. ---

## The player has landed on island `i`: the first time, its hop is traced and its daemons wake; its spawns are the
## player's from now on.
func _arrive(i: int, first_run: bool = false) -> void:
	at_island = i
	var isl: Dictionary = net.islands[i]
	var id: String = isl["id"]
	_move_spawns(i)
	if reached.has(id):
		_enter("island" if standing_on(id) > 0 else "clear")
		return
	reached[id] = true
	var m := NetBook.machine(id)
	if i > 0:
		var ms := (_clock - _hop_start) * 1000.0
		for n in _hop_lost:
			trace.append({"hop": i, "id": "", "addr": "", "ms": 0.0, "lost": true})
		trace.append({"hop": i, "id": id, "addr": NetBook.address(m), "ms": ms, "lost": false})
		stats["hops"] = int(stats["hops"]) + 1
		_note("hop", "%2d  %s (%s)  %.1f ms" % [i, id, NetBook.address(m), ms])
		hopped.emit(i, id)
		_play("hop")
	elif first_run:
		trace.append({"hop": 0, "id": id, "addr": NetBook.address(m), "ms": 0.0, "lost": false})
	_hop_lost = 0
	_spawn_island(i)
	var f := NetBook.forward_from(id)
	if f >= 0 and bool(NetBook.LINKS[f][4]):
		_spawn_mitm(f)
	if standing_on(id) == 0 and id != NetBook.TARGET:
		_clear_island(i)
	else:
		_enter("island")


func _clear_island(i: int) -> void:
	var id: String = net.islands[i]["id"]
	var f := NetBook.forward_from(id)
	if f >= 0:
		(net.links[f] as NetLink).open_route(_clock)
		_note("route", "route up: %s -> %s" % [id, NetBook.LINKS[f][1]])
		_play("syn")
	_enter("clear")


## Its daemons on island `id` that hold its route: standing or climbing in, a dup on its way counted too.
func standing_on(id: String) -> int:
	var n := 0
	for e in enemies:
		if e["island"] != id or NOT_HOLDING.has(e["kind"]):
			continue
		var body = e["body"]
		if is_instance_valid(body) and (body.is_alive() or body.climbing()):
			n += 1
	for d in _dups:
		if d["island"] == id:
			n += 1
	return n


## Every one of its daemons standing anywhere (the HUD).
func standing() -> int:
	var n := 0
	for e in enemies:
		var body = e["body"]
		if is_instance_valid(body) and (body.is_alive() or body.climbing()):
			n += 1
	return n + _dups.size()


func _move_spawns(i: int) -> void:
	var spots := net.spots(i)
	if player != null and is_instance_valid(player) and player.has_method("set_spawn") and not spots.is_empty():
		var top := net.top(i)
		player.set_spawn(Transform3D(Basis.IDENTITY, top + Vector3.UP * 0.95))
	var host := get_parent()
	var markers = host.get_node_or_null("Arena/Spawns") if host != null else null
	if markers != null and not spots.is_empty():
		for k in markers.get_child_count():
			var m := markers.get_child(k) as Node3D
			if m != null:
				m.global_position = spots[k % spots.size()] + Vector3.UP * 0.95


# --- Riding. ---

## The port of the island under the player it stands on now (a link index), or -1.
func port_under() -> int:
	if player == null or not is_instance_valid(player) or net == null:
		return -1
	var p: Vector3 = player.global_position
	var isl: Dictionary = net.islands[at_island]
	for li in isl["gates"]:
		var at: Vector3 = isl["ports"][li]
		if Vector2(p.x - at.x, p.z - at.z).length() <= PORT_REACH and absf(p.y - at.y) < 2.5:
			return li
	return -1


func _step_ports(delta: float) -> void:
	var li := port_under()
	if _port_block >= 0 and li != _port_block:
		_port_block = -1  # stepped off the port it arrived at: it boards again
	if li < 0 or li == _port_block:
		_board_t = 0.0
		_board_link = -1
		return
	var link: NetLink = net.links[li]
	if not link.boardable():
		_board_t = 0.0
		_refused_t -= delta
		if _refused_t <= 0.0:
			_refused_t = 2.0
			_note("refused", "connect to %s: %s" % [link.other(net.islands[at_island]["id"]), "connection refused (RST)" if link.state == NetLink.State.DROPPED else ("no route to host" if link.state == NetLink.State.DOWN else "reconnecting")])
			_play("refused")
		return
	if _board_link != li:
		_board_link = li
		_board_t = 0.0
	_board_t += delta
	if _board_t >= BOARD_S:
		board(li)


## Boards link `li` at the island the player stands on: a packet carries the player across (or, with a stale route
## standing here, down the wrong way). True when it boarded.
func board(li: int) -> bool:
	if not ride.is_empty() or net == null or li < 0 or li >= net.links.size():
		return false
	var from_id: String = net.islands[at_island]["id"]
	var link: NetLink = net.links[li]
	if link.from_id != from_id and link.to_id != from_id:
		return false
	if not link.forward or not link.boardable():
		return false  # a wrong way is ridden only when a stale route sends a packet down it
		return false
	var stale := _stale_on(from_id)
	if stale != null and link.forward and link.from_id == from_id and NetBook.STALE_TO.has(from_id):
		var wrong := NetBook.link_between(from_id, NetBook.STALE_TO[from_id])
		if wrong >= 0 and (net.links[wrong] as NetLink).boardable():
			var art = stale.art_node()
			if art != null:
				art.misroute = 1.0
			stats["misrouted"] = int(stats["misrouted"]) + 1
			_note("stale", "stale route: sent the wrong way, to %s" % NetBook.STALE_TO[from_id])
			_play("stale")
			li = wrong
			link = net.links[li]
	var to_id := link.other(from_id)
	ride = {"link": li, "from": from_id, "to": to_id, "dir": 1.0 if link.from_id == from_id else -1.0, "u": 0.0, "burst": 0.0, "bursts": 0, "held": false, "warned": link.unstable(), "start": _clock}
	_hop_start = _clock
	_board_t = 0.0
	_board_link = -1
	if player != null and is_instance_valid(player):
		if "riding" in player:
			player.riding = true
		player.velocity = Vector3.ZERO
		var to := link.at(1.0 if ride["dir"] > 0.0 else 0.0) - player.global_position
		player.rotation.y = atan2(-to.x, -to.z)
	stats["rides"] = int(stats["rides"]) + 1
	_enter("ride")
	_note("ride", "%s -> %s  %s" % [from_id, to_id, NetBook.PROTOCOLS[link.proto]["label"]])
	_play("board")
	return true


## A link going bad under the rider (or boarded while it warns) tears where the rider will be as it opens, a little
## ahead: the rider who keeps its pace meets the gap; a burst outruns it. A rider who will be off it by then is safe as it
## is.
func _threaten(link: NetLink) -> void:
	var left := maxf(NetLink.FLAKY_S - link.state_t, 0.0)
	var at := float(ride["u"]) + (RIDE_SPEED * left + THREAT_AHEAD_M) / link.length_m
	if at >= 0.97:
		return
	link.tear_u = clampf(at if float(ride["dir"]) > 0.0 else 1.0 - at, 0.03, 0.97)


## Space while riding: the packet bursts ahead (once a ride), to outrun a tear.
func burst() -> bool:
	if ride.is_empty() or int(ride["bursts"]) > 0 or bool(ride["held"]):
		return false
	ride["burst"] = BURST_S
	ride["bursts"] = 1
	stats["bursts"] = int(stats["bursts"]) + 1
	_note("burst", "burst")
	_play("burst")
	return true


## Where along its link (0 to 1, by the link's own direction) the ride is now.
func ride_link_u() -> float:
	if ride.is_empty():
		return -1.0
	return float(ride["u"]) if float(ride["dir"]) > 0.0 else 1.0 - float(ride["u"])


func _step_ride(delta: float) -> void:
	var link: NetLink = net.links[int(ride["link"])]
	if link.state == NetLink.State.FLAKY and int(ride.get("seen", -1)) != NetLink.State.FLAKY:
		_threaten(link)  # it went bad under the rider: its tear where the rider will be as it opens
	ride["seen"] = link.state
	if link.unstable():
		ride["warned"] = true
	var lu := ride_link_u()
	if link.gone_at(lu):
		_fall(link)
		return
	# A man in the middle on it: the packet held before it while it lives.
	var held := false
	var hold_at := INF
	for e in enemies:
		if int(e["link"]) != int(ride["link"]) or not _alive(e["body"]):
			continue
		var tu: float = float(e["u"]) if float(ride["dir"]) > 0.0 else 1.0 - float(e["u"])
		var stop := tu - MITM_HOLD_M / link.length_m
		if float(ride["u"]) <= stop + 0.0001:
			hold_at = minf(hold_at, stop)
	var speed := BURST_SPEED if float(ride["burst"]) > 0.0 else RIDE_SPEED
	ride["burst"] = maxf(float(ride["burst"]) - delta, 0.0)
	var next := float(ride["u"]) + speed * delta / link.length_m
	if next >= hold_at:
		next = maxf(hold_at, float(ride["u"]))
		held = true
		if not bool(ride["held"]):
			stats["intercepted"] = int(stats["intercepted"]) + 1
			_note("intercepted", "intercepted: a man in the middle on %s -> %s" % [ride["from"], ride["to"]])
			_play("intercepted")
	ride["held"] = held
	ride["u"] = minf(next, 1.0)
	_place_rider(link)
	if player != null and is_instance_valid(player) and "ride_kick" in player:
		player.ride_kick = 0.0 if held else (22.0 if float(ride["burst"]) > 0.0 else 12.0)
	if float(ride["u"]) >= 1.0:
		_land()


func _place_rider(link: NetLink) -> void:
	if player == null or not is_instance_valid(player):
		return
	var at := link.at(ride_link_u())
	player.global_position = at + Vector3.UP * RIDE_STAND
	player.velocity = Vector3.ZERO
	if _rider == null:
		_rider = MeshInstance3D.new()
		_rider.name = "RiddenPacket"
		var box := BoxMesh.new()
		box.size = Vector3.ONE
		_rider.mesh = box
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://shaders/net_packet.gdshader")
		_rider.material_override = mat
		_rider.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_rider.top_level = true
		add_child(_rider)
	var mat2 := _rider.material_override as ShaderMaterial
	mat2.set_shader_parameter("single", NetBook.color_of(link.proto).lerp(Color.WHITE, 0.2))
	mat2.set_shader_parameter("boost", 1.6 if float(ride["burst"]) > 0.0 else 1.0)
	_rider.visible = true
	_rider.global_transform = Transform3D(Basis.looking_at(link.way(ride_link_u()) * float(ride["dir"]), Vector3.UP) * Basis.from_scale(RIDER_SLAB), at + Vector3.UP * 0.32)


## The far port reached: the player stepped off onto it, and on into the island.
func _land() -> void:
	var li := int(ride["link"])
	var to_id: String = ride["to"]
	var warned := bool(ride["warned"])
	var link: NetLink = net.links[li]
	var at := net.port(li, to_id)
	var i := net.island_index(to_id)
	var inward := (net.top(i) - at)
	inward.y = 0.0
	inward = inward.normalized() if inward.length_squared() > 0.001 else Vector3.FORWARD
	_let_go()
	if player != null and is_instance_valid(player):
		player.global_position = at + inward * 2.6 + Vector3.UP * 0.95
		player.velocity = inward * 5.0
	_port_block = li
	if warned:
		stats["dodged"] = int(stats["dodged"]) + 1
		_note("dodged", "drop dodged on %s -> %s" % [link.other(to_id), to_id])
	_play("land")
	_arrive(i)


## The link tore under the rider: the packet is lost; the player falls into the void until it is retransmitted.
func _fall(link: NetLink) -> void:
	var way := link.way(ride_link_u()) * float(ride["dir"])
	var speed := BURST_SPEED if float(ride["burst"]) > 0.0 else RIDE_SPEED
	_fall_from = net.island_index(str(ride["from"]))
	_let_go()
	stats["taken"] = int(stats["taken"]) + 1
	_hop_lost += 1
	if player != null and is_instance_valid(player):
		player.velocity = way * speed * 0.35 + Vector3.UP * 2.0
	_fall_t = 0.0
	_enter("fall")
	_note("lost", "* * *  packet lost: %s -> %s dropped" % [link.from_id, link.to_id])
	dropped.emit(link.index, true)
	_play("lost")


## Sent again: the player at the port it boarded from (or the island it fell off), a little hurt, never killed by it.
func _retransmit() -> void:
	var i := _fall_from if _fall_from >= 0 else at_island
	var to: Vector3 = net.top(i)
	var back_port := -1
	for li in net.islands[i]["ports"]:
		if (net.links[li] as NetLink).forward and (net.links[li] as NetLink).from_id == net.islands[i]["id"]:
			back_port = li
	if back_port >= 0:
		var p := net.port(back_port, net.islands[i]["id"])
		var inward := net.top(i) - p
		inward.y = 0.0
		to = p + inward.normalized() * 3.0
	if player != null and is_instance_valid(player):
		if player.has_method("respawn_at"):
			player.respawn_at(to + Vector3.UP * 0.95)
		else:
			player.global_position = to + Vector3.UP * 0.95
	var life = get_parent().get_node_or_null("SoloLife") if get_parent() != null else null
	if life != null and life.has_method("damage") and life.has_method("health"):
		var hurt := minf(DROP_HURT, float(life.health()) - 1.0)
		if hurt > 0.0:
			life.damage(hurt, null, Vector3.ZERO)
	_fall_from = -1
	at_island = i
	_note("retransmit", "retransmitted from %s" % net.islands[i]["id"])
	_play("retransmit")
	_enter("island" if standing_on(net.islands[i]["id"]) > 0 else "clear")


# --- Its daemons. ---

func _spawn_island(i: int) -> void:
	var id: String = net.islands[i]["id"]
	var roster: Array = NetBook.machine(id)["roster"]
	var spots := net.spots(i)
	var near := spots.duplicate()
	var land: Vector3 = player.global_position if player != null and is_instance_valid(player) else net.top(i)
	# Farthest from where the player lands first, so the fight comes to them across the deck.
	var arr := Array(near)
	arr.sort_custom(func(a, b): return (a as Vector3).distance_to(land) > (b as Vector3).distance_to(land))
	var at := 0
	for r in roster:
		var kind := str(r[0])
		for n in int(r[1]):
			var where: Vector3
			if kind == "stale":
				where = _stale_spot(i)
			elif kind == "flood":
				where = net.top(i) + Vector3.UP * 0.6
			else:
				if arr.is_empty():
					continue
				where = arr[at % arr.size()]
				at += 1
			_spawn(kind, where, "%s_%s_%d" % [id, kind, n], id, -1, -1.0)


## A stale route's spot: beside its machine's forward port, a few metres in, so it stands in the way.
func _stale_spot(i: int) -> Vector3:
	var id: String = net.islands[i]["id"]
	var f := NetBook.forward_from(id)
	var p := net.port(f, id) if f >= 0 else net.top(i)
	var inward := net.top(i) - p
	inward.y = 0.0
	inward = inward.normalized()
	return p + inward * 3.6 + Vector3(inward.z, 0.0, -inward.x) * 2.6


func _spawn_mitm(li: int) -> void:
	var link: NetLink = net.links[li]
	var u := 0.55
	link.tap_u = u
	var body := _spawn("mitm", link.at(u) + Vector3.DOWN * MITM_LIFT, "mitm_%d" % li, "", li, u)
	if body != null:
		body.global_basis = Basis.looking_at(link.way(u), Vector3.UP)


func _spawn(kind: String, at: Vector3, slot: String, island: String, link: int, u: float, dup: bool = false) -> Node3D:
	var targets := _targets()
	if targets == null:
		return null
	var dummy = DummyScene.instantiate()
	dummy.name = "Net_%s" % slot
	dummy.tag_text = TAGS[kind] + (" dup" if dup else "")
	dummy.respawns = false
	match kind:
		"zombie":
			dummy.art = ZombieArt
		"runaway":
			dummy.art = RunawayArt
		"retransmit":
			dummy.art = RetransmitArt
		"mitm":
			dummy.art = MitmArt
		"stale":
			dummy.art = StaleArt
		"flood":
			dummy.art = FloodArt
		_:
			dummy.art = RogueArt
	dummy.max_health = float(HEALTH[kind])
	dummy.seed_wanted = _seed_for(slot)
	dummy.set_meta(&"net", slot)
	dummy.set_meta(&"world", true)  # its kills share the world modes' credit cap (W2)
	targets.add_child(dummy)
	dummy.global_position = at
	match kind:
		"mitm":
			dummy.resize_volume(0.85, 1.5)
			dummy.climb_depth_m = 0.0
			dummy.spawn_in(0.6)
		"stale":
			dummy.resize_volume(0.8, 4.4)
			dummy.resize_art(STALE_SIZE)
			dummy.spawn_in(1.0)
		"flood":
			dummy.resize_art(BOSS_SIZE)
			dummy.spawn_in(1.6)
		_:
			if dup:
				dummy.resize_art(DUP_SIZE)
			dummy.spawn_in(0.5 if dup else 1.0)
	if player != null and is_instance_valid(player) and kind != "mitm":
		var to: Vector3 = player.global_position - dummy.global_position
		dummy.rotation.y = atan2(-to.x, -to.z)
	if dummy.brain != null:
		dummy.brain.dormant = false
		dummy.brain.relentless = kind == "rogue" or kind == "zombie"  # walkers keep their feet on a deck: never off its edge
	dummy.downed.connect(_on_downed)
	enemies.append({"body": dummy, "kind": kind, "island": island, "link": link, "u": u, "dup": dup})
	spawned.emit(dummy)
	_forget()
	return dummy


func _seed_for(slot: String) -> int:
	if OS.get_cmdline_user_args().has("--demo") or OS.get_cmdline_args().has("--script"):
		return DaemonArt.seed_of("net:%s" % slot) & DaemonArt.SEED_LAST
	return randi() & DaemonArt.SEED_LAST


func _on_downed(dummy: Node3D) -> void:
	stats["kills"] = int(stats["kills"]) + 1
	for e in enemies:
		if e["body"] != dummy:
			continue
		match str(e["kind"]):
			"retransmit":
				if not bool(e["dup"]):
					_dups.append({"at": dummy.global_position, "t": DUP_S, "island": e["island"], "slot": str(dummy.get_meta(&"net", "r"))})
					_note("retransmit", "retransmit: sent again")
			"mitm":
				var link: NetLink = net.links[int(e["link"])]
				link.tap_u = -1.0
				_note("mitm", "the man in the middle is down: %s -> %s clean" % [link.from_id, link.to_id])
			"stale":
				_note("stale", "stale route flushed at %s" % e["island"])
			"flood":
				_note("done", "SYN flood down: %s reached" % NetBook.TARGET)
		break


## The SYN flood standing (or climbing in) at the last hop.
func _boss_standing() -> bool:
	for e in enemies:
		if e["kind"] == "flood" and is_instance_valid(e["body"]) and (e["body"].is_alive() or e["body"].climbing()):
			return true
	return false


func _stale_on(id: String) -> Node3D:
	for e in enemies:
		if e["kind"] == "stale" and e["island"] == id and _alive(e["body"]):
			return e["body"]
	return null


static func _alive(body) -> bool:
	return body != null and is_instance_valid(body) and body.has_method("is_alive") and body.is_alive()


func _step_daemons(delta: float) -> void:
	for d in _dups.duplicate():
		d["t"] = float(d["t"]) - delta
		if float(d["t"]) <= 0.0:
			_dups.erase(d)
			_spawn("retransmit", d["at"], "%s_dup" % d["slot"], d["island"], -1, -1.0, true)
	var eye: Vector3 = player.global_position + Vector3.UP * 0.6 if player != null and is_instance_valid(player) else Vector3.INF
	for e in enemies:
		var body = e["body"]
		if not _alive(body):
			continue
		var art = body.art_node()
		match str(e["kind"]):
			"mitm":
				_step_mitm(e, art, eye, delta)
			"stale":
				if art != null:
					var to: String = NetBook.STALE_TO.get(str(e["island"]), "")
					var wrong: Vector3 = (net.top(net.island_index(to)) - body.global_position) if to != "" else Vector3.BACK
					art.wrong = body.global_basis.inverse() * wrong
					art.misroute = maxf(float(art.misroute) - delta * 0.6, 0.0)
			"flood":
				_step_flood(e, art, delta)


func _step_mitm(e: Dictionary, art, eye: Vector3, delta: float) -> void:
	var body: Node3D = e["body"]
	var t := float(e.get("t", 0.0))
	var free: bool = body.brain == null or body.brain.flown_frame == Engine.get_physics_frames()
	var reach_ok := eye.is_finite() and body.global_position.distance_to(eye) <= MITM_REACH and free and _sees(body.global_position, eye)
	if not reach_ok:
		e["t"] = 0.0
		if art != null:
			art.tell = maxf(float(art.tell) - delta * 3.0, 0.0)
			art.snap = maxf(float(art.snap) - delta * 4.0, 0.0)
		return
	t += delta
	if art != null:
		art.tell = clampf((t - (MITM_EVERY_S - MITM_TELL_S)) / MITM_TELL_S, 0.0, 1.0)
		art.snap = maxf(float(art.snap) - delta * 4.0, 0.0)
	if t >= MITM_EVERY_S:
		t = 0.0
		if art != null:
			art.tell = 0.0
			art.snap = 1.0
		if director != null and is_instance_valid(director) and body.brain != null:
			body.brain.prey = 1
			var from: Vector3 = body.global_position + (eye - body.global_position).normalized() * 1.4
			director.throw_bolt(body.brain, from, (eye - from).normalized())
	e["t"] = t


func _step_flood(e: Dictionary, art, delta: float) -> void:
	_flood_t += delta
	_flood_glow = maxf(_flood_glow - delta / 1.5, 0.0)
	if _flood_t >= FLOOD_EVERY_S:
		_flood_t = 0.0
		var sent := 0
		var here := 0
		for x in enemies:
			if x["kind"] == "retransmit" and x["island"] == NetBook.TARGET and _alive(x["body"]):
				here += 1
		var spots := net.spots(net.island_index(NetBook.TARGET))
		for n in FLOOD_SENDS:
			if here + sent >= FLOOD_MOST or spots.is_empty():
				break
			var k := int(_clock * 7.0 + n * 5) % spots.size()
			_spawn("retransmit", spots[k] + Vector3.UP * 1.2, "flood_%d_%d" % [int(_clock), n], NetBook.TARGET, -1, -1.0)
			sent += 1
		if sent > 0:
			_flood_glow = 1.0
			_note("flood", "SYN flood: %d more retransmitting" % sent)
			_play("flood")
	if art != null:
		art.flood = _flood_glow


func _sees(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _clear_enemies() -> void:
	var fx := ParticleFx.of(self)
	for e in enemies:
		var body = e["body"]
		if is_instance_valid(body) and not body.is_queued_for_deletion():
			if fx != null and body.is_alive():
				fx.impact(body.threat_point(), Vector3.UP, false, Palette.MINT)
			body.queue_free()
	enemies.clear()
	_dups.clear()
	if net != null:
		for link in net.links:
			link.tap_u = -1.0
	_forget()


func _forget() -> void:
	if director != null and is_instance_valid(director):
		director.forget_brains()


# --- The run's clock. ---

func _physics_process(delta: float) -> void:
	if not running:
		return
	if _online():
		end()  # a match started mid-run: the match's rules, the arena's own back
		return
	_clock += delta
	_phase_t += delta
	if phase != "results":
		stats["time"] = float(stats.get("time", 0.0)) + delta
	for link in net.links:
		var was: int = link.state
		(link as NetLink).step(delta, _clock)
		if was != NetLink.State.DROPPED and link.state == NetLink.State.DROPPED and (ride.is_empty() or int(ride["link"]) != link.index):
			dropped.emit(link.index, false)
	_step_daemons(delta)
	match phase:
		"island":
			_step_ports(delta)
			var here: String = net.islands[at_island]["id"]
			if here == NetBook.TARGET:
				if not _boss_standing():
					_finish()  # the SYN flood down: the trace is complete, whatever it threw off still standing reaped
			elif standing_on(here) == 0:
				_clear_island(at_island)
			_check_fallen()
		"clear":
			_step_ports(delta)
			_check_fallen()
		"ride":
			if Input.is_action_just_pressed("jump") and _can_act():
				burst()
			_step_ride(delta)
		"fall":
			_fall_t += delta
			if player == null or not is_instance_valid(player) or player.global_position.y < net.lowest() - LOST_BELOW or _fall_t >= FALL_S:
				_retransmit()
		"done":
			if _phase_t >= DONE_S:
				_enter("results")
				_note("results", "trace complete")


## Walked off a deck into the void: retransmitted the same as a drop (no drop counted).
func _check_fallen() -> void:
	if player == null or not is_instance_valid(player) or net == null:
		return
	var p: Vector3 = player.global_position
	if p.y < net.top(at_island).y - 6.0 and net.island_under(p) < 0:
		stats["falls"] = int(stats["falls"]) + 1
		_fall_from = at_island
		_fall_t = 0.0
		_enter("fall")
		_note("lost", "fell off %s into the void" % net.islands[at_island]["id"])
		_play("lost")


func _finish() -> void:
	for e in enemies:
		var body = e["body"]
		if _alive(body) and body.has_method("reap"):
			body.reap()
	_dups.clear()
	_let_go()
	_enter("done")
	_play("done")


func _can_act() -> bool:
	return player != null and is_instance_valid(player) and player.get("alive") != false and player.get("input_blocked") != true


func _enter(next: String) -> void:
	phase = next
	_phase_t = 0.0


## Plays the run again from the player's own machine (the results card's Enter).
func again() -> void:
	if phase != "results":
		return
	if player != null and is_instance_valid(player) and player.has_method("respawn_at"):
		player.respawn_at(net.start_point())
		player.rotation.y = net.start_yaw()
	_start_run()
	_note("again", "again")


func _unhandled_input(ev: InputEvent) -> void:
	if running and phase == "results" and ev.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		again()


func _go(label: String) -> void:
	if _going:
		return
	_going = true
	SceneTear.reload_scene(get_tree(), label)


func leave() -> void:
	if _going:
		return
	_going = true
	clear()
	SceneTear.reload_scene(get_tree(), "$ exit")


static func going() -> bool:
	return _going


func _process(_delta: float) -> void:
	if not running:
		return
	_draw_visor()


# --- The visor: the route, hop by hop, and every daemon's connection to its machine. ---

func visor_on() -> bool:
	return visor != null and is_instance_valid(visor) and bool(visor.get("on"))


func _draw_visor() -> void:
	if _lines == null or net == null:
		return
	var on := visor_on()
	var lines: Array = []
	var live := {}
	if on:
		# The trace: from the player's own machine hop by hop, along each forward link's curve.
		var at := str(NetBook.MACHINES[0]["id"])
		var hop := 0
		while at != NetBook.TARGET and hop <= NetBook.MACHINES.size():
			var f := NetBook.forward_from(at)
			if f < 0:
				break
			var link: NetLink = net.links[f]
			var done := reached.has(link.to_id)
			for s in 8:
				var a := link.at(float(s) / 8.0) + Vector3.UP * 0.4
				var b := link.at(float(s + 1) / 8.0) + Vector3.UP * 0.4
				lines.append(_line(a, b, 1.0 if done else 0.45, 0.12))
			at = link.to_id
			hop += 1
		for i in net.islands.size():
			var key := "isl%d" % i
			live[key] = true
			var mark := _mark(key)
			var id: String = net.islands[i]["id"]
			var m := NetBook.machine(id)
			var ms := ""
			for row in trace:
				if row["id"] == id and int(row["hop"]) > 0:
					ms = "  %.0f ms" % float(row["ms"])
			mark.visible = true
			mark.text = "hop %d  %s\n%s%s  %s" % [i, id, NetBook.address(m), ms, "reached" if reached.has(id) else "unreached"]
			var half: Vector2 = net.islands[i]["half"]
			mark.global_position = net.top(i) + Vector3(-half.x + 0.8, 3.2, -half.y + 0.8)
		for e in enemies:
			var body = e["body"]
			if not _alive(body):
				continue
			var key := "e%d" % body.get_instance_id()
			live[key] = true
			var home: Vector3
			if int(e["link"]) >= 0:
				home = net.links[int(e["link"])].at(float(e["u"])) + Vector3.UP * 0.4
			else:
				home = net.top(net.island_index(str(e["island"]))) + Vector3.UP * 4.0
			var p: Vector3 = body.threat_point()
			lines.append(_line(p, home, 0.8, 0.06))
			var mk := _mark(key)
			mk.visible = true
			var port: int = 1024 + (int(body.get_instance_id()) % 60000)
			mk.text = "%s  ESTAB\n:%d -> %s" % [str(body.tag_text), port, str(e["island"]) if str(e["island"]) != "" else "on the link"]
			mk.global_position = p + Vector3.UP * 1.6
	for key in _marks.keys():
		if not live.has(key):
			var m = _marks[key]
			if is_instance_valid(m):
				m.visible = false
	_lines.draw(lines, [])


func _line(a: Vector3, b: Vector3, bright: float, width: float) -> Dictionary:
	return {"a": a, "b": b, "heat": 0.6, "width": width, "grown": 1.0, "phase": 0.0, "burn": 0.0, "bright": 1.2 * bright, "depth": 0.0, "lift": 0.0}


func _mark(key: String) -> Label3D:
	var l: Label3D = _marks.get(key)
	if l != null and is_instance_valid(l):
		return l
	l = Label3D.new()
	l.name = "RouteMark"
	l.add_to_group(MARK_GROUP)
	l.font = Palette.mono_font()
	l.font_size = 40
	l.pixel_size = 0.01 if key.begins_with("isl") else 0.0075
	l.outline_size = 10
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.modulate = Color(0.75, 0.95, 1.0) * 1.3
	l.shaded = false
	l.no_depth_test = true
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	_marks[key] = l
	return l


# --- The arena's own daemons. ---

func _targets() -> Node3D:
	var host := get_parent()
	var t = host.get_node_or_null("Arena/Targets") if host != null else null
	return t as Node3D if t != null else (host as Node3D)


func _park_arena_daemons() -> void:
	var host := get_parent()
	for dummy in get_tree().get_nodes_in_group("targets"):
		if host != null and host.is_ancestor_of(dummy) and not dummy.has_meta(&"net"):
			dummy.remove_from_group("targets")
			_parked.append([dummy, dummy.get_parent(), dummy.collision_layer])
			dummy.process_mode = Node.PROCESS_MODE_DISABLED
			dummy.visible = false
			dummy.collision_layer = 0
			dummy.reparent(self)
	_forget()
	for driver in get_tree().get_nodes_in_group(&"code_rain_driver"):
		if driver.has_method("invalidate"):
			driver.invalidate()


func _release_parked() -> void:
	for entry in _parked:
		var dummy: Node3D = entry[0]
		if not is_instance_valid(dummy) or not is_instance_valid(entry[1]):
			continue
		dummy.reparent(entry[1])
		dummy.collision_layer = entry[2]
		dummy.visible = true
		dummy.process_mode = Node.PROCESS_MODE_INHERIT
		dummy.add_to_group("targets")
	_parked.clear()


# --- For the HUD and the checks. ---

func _play(id: String) -> void:
	if _sfx == null or not _sfx.is_inside_tree():
		return
	_sfx.stream = PacketSound.of(id)
	_sfx.play()


func _note(kind: String, text: String) -> void:
	events.append({"t": _clock, "kind": kind, "text": text})
	while events.size() > EVENTS_KEPT:
		events.pop_front()
	event.emit(kind, text)


func clock() -> float:
	return _clock


func phase_time() -> float:
	return _phase_t


## The forward link out of the island the player is on (the HUD's "next"), or null at the last hop.
func next_link() -> NetLink:
	if net == null:
		return null
	var f := NetBook.forward_from(net.islands[at_island]["id"])
	return net.links[f] if f >= 0 else null
