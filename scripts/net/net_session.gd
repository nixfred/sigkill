extends Node
## The one owner of LAN and tailnet play (C13, PRD 5.1): one player hosts, another joins by
## address, and each sees the other move. Nothing else in the game opens a socket.
##
## One ENet socket, and only when the player asks: host() opens the tuning's UDP port
## (9009), join() connects to the address the player typed (an IP, or a hostname looked
## up on a worker). No discovery, no broadcast, no relay, no server of anyone else's.
## Solo play never touches this: the session sits OFF with Godot's offline peer.
##
## Handshake, before a peer counts as a player: the joiner sends the protocol version and
## its shown name as Godot's authentication data; the host answers with its own version
## and a verdict (ok with a slot and name, version mismatch, or full) and only completes
## authentication for an ok. A refused joiner reads the verdict, shows it and closes; the
## host drops it after a grace anyway. Until the handshake completes no state is sent
## either way. A join that gets no answer ends after connect_timeout_ms with "couldn't
## reach host" (ENet alone would wait far longer for a closed port).
##
## The host owns the session: who is in it, their slots and names (the roster, sent to
## every player on every change). Each player owns its own movement for now: sync_rate_hz
## times a second it sends position, body yaw, view pitch and velocity; a joiner's state
## goes to the host, which applies it to that player's avatar and passes it to the others
## (Godot's own relay is off, so nothing moves between players without the host's code).
## Remote avatars (scripts/net/remote_player.gd) live under a Players node in the arena
## and interpolate between received positions. The session lives beside the arena, so an
## R reload of the arena keeps the connection; the new arena attaches and avatars return.
##
## Over the wire, ever: the protocol version, slots and ids, shown names (a placeholder,
## never the system's user or host name), positions, angles and velocities. Nothing about
## the AI guide, the settings, paths, processes or the machine.

const Tuning = preload("res://scripts/net/net_tuning.gd")
const RemotePlayer = preload("res://scripts/net/remote_player.gd")

const DEFAULT_TUNING_PATH := "res://resources/net.tres"
## Changes whenever what goes over the wire changes. Both sides must match.
const PROTOCOL := 1
const PLACEHOLDER := "player"
const MAGIC_0 := 0x53  # "S"
const MAGIC_1 := 0x4B  # "K"
const HELLO_HEAD := 5
const REPLY_HEAD := 7
const VERSION_LAST := 65535
const SLOT_LAST := 255
## How long a refused joiner gets to read the verdict and close before the host drops it.
const REFUSE_GRACE_MS := 500
## ENet connection slots beyond max_players, so a joiner to a full host can be told so.
const ENET_SLACK := 2
const ENET_TIMEOUT_LIMIT := 32
const WORLD_LAST := 10000.0
const SPEED_LAST := 200.0
const PITCH_LAST := PI * 0.5 + 0.01
const ADDRESS_LAST := 260
const HOSTNAME_LAST := 253
const LABEL_LAST := 63
const PORT_LAST := 65535
const NODE_NAME := "NetSession"
const PLAYERS_NODE := "Players"
const CANT_REACH := "couldn't reach host"
const HOST_FULL := "host full"
const HOST_LEFT := "host left"
const BAD_ADDRESS := "not an address: type an IP or a host name, with an optional :port"
const BAD_REPLY := "the host answered in a way this version does not understand"

enum State { OFF, HOSTING, RESOLVING, CONNECTING, JOINED, FAILED }
enum Verdict { OK, VERSION, FULL }

## Emitted on every change of state, error, roster or address.
signal changed

# Set these before the node enters the tree.
## NetTuning; null for resources/net.tres.
var tuning: Resource = null
## The protocol version this side speaks. A test gives one side another number to prove
## the mismatch is refused. Never changed by the game.
var protocol := PROTOCOL

var state: State = State.OFF
## Why the last join or host attempt ended, for the screen, or "".
var error := ""
## What the player typed to join, shown back on their own screen only.
var address_text := ""
## Everyone in the session, id -> {slot, name}; the host is id 1.
var players := {}
var my_id := 1
## The remote players' avatars in the current arena, id -> RemotePlayer.
var avatars := {}
## State packets sent, and received and applied, this session.
var sent := 0
var received := 0

var _t: Tuning
var _enet: ENetMultiplayerPeer
var _arena: Node = null
var _player: Node = null
var _players_node: Node3D = null
var _connect_left_ms := 0.0
var _resolve_item := -1
var _resolve_name := ""
var _join_port := 0
var _seq := 0
var _send_wait_s := 0.0
## Host: joiners that passed the handshake, id -> {slot, name}, until peer_connected.
var _pending := {}
## Host: refused joiners and the grace left before they are dropped, id -> ms.
var _refused := {}
## Joiner: the verdict the host sent, kept until the disconnect it causes is reported.
var _refusal := ""


## The session beside `scene` (its parent's child named NetSession), made if there is none.
## The one just made joins the tree at the end of the frame, so it is ready a frame later.
static func of(scene: Node) -> Node:
	var parent := scene.get_parent()
	if parent == null:
		return null
	var found := parent.get_node_or_null(NODE_NAME)
	if found != null and found.get_script() == load("res://scripts/net/net_session.gd"):
		return found
	var session: Node = load("res://scripts/net/net_session.gd").new()
	session.name = NODE_NAME
	parent.add_child.call_deferred(session)
	return session


static func usable_tuning(candidate: Resource) -> Tuning:
	if candidate is Tuning:
		var issues: PackedStringArray = candidate.problems()
		if issues.is_empty():
			return candidate
		for issue in issues:
			push_warning("net tuning: " + issue + "; using the shipped tuning instead")
	var shipped = load(DEFAULT_TUNING_PATH)
	if shipped is Tuning and shipped.problems().is_empty():
		return shipped
	return Tuning.new()


func _ready() -> void:
	_t = usable_tuning(tuning)
	var m := multiplayer as SceneMultiplayer
	if m == null:
		return
	m.auth_callback = _on_auth
	m.auth_timeout = _t.connect_timeout_ms / 1000.0
	m.server_relay = false
	m.allow_object_decoding = false
	m.peer_authenticating.connect(_on_authenticating)
	m.peer_authentication_failed.connect(_on_auth_failed)
	m.peer_connected.connect(_on_peer_connected)
	m.peer_disconnected.connect(_on_peer_disconnected)
	m.connected_to_server.connect(_on_connected)
	m.connection_failed.connect(_on_connection_failed)
	m.server_disconnected.connect(_on_server_disconnected)


func _exit_tree() -> void:
	_shut_peer()


func tuning_in_use() -> Tuning:
	return _t


## The arena to show other players in and the player whose movement to send. The arena
## calls this when it is ready; avatars for everyone in the session appear in it.
func attach(arena: Node, player: Node) -> void:
	_arena = arena
	_player = player
	avatars.clear()
	_players_node = arena.get_node_or_null(PLAYERS_NODE) as Node3D
	if _players_node == null:
		_players_node = Node3D.new()
		_players_node.name = PLAYERS_NODE
		arena.add_child(_players_node)
	if not arena.tree_exiting.is_connected(_on_arena_exit):
		arena.tree_exiting.connect(_on_arena_exit)
	for id in players:
		if id != my_id:
			_spawn_avatar(id)


func _on_arena_exit() -> void:
	_arena = null
	_player = null
	_players_node = null
	avatars.clear()


## Opens the port and waits for players. `port` 0 lets the system pick one (tests), -1
## means the tuning's. False, with `error` set, if it could not.
func host(port: int = -1) -> bool:
	if state != State.OFF and state != State.FAILED:
		return false
	var p := _t.port if port < 0 else port
	if p != 0 and not _port_free(p):
		_fail("port %d is in use" % p)
		return false
	var enet := ENetMultiplayerPeer.new()
	if _t.bind_address != "*":
		enet.set_bind_ip(_t.bind_address)
	if enet.create_server(p, _t.max_players + ENET_SLACK) != OK:
		_fail("couldn't open port %d" % p)
		return false
	_enet = enet
	multiplayer.multiplayer_peer = _enet
	my_id = 1
	players = {1: {"slot": 1, "name": assigned_name(_t.display_name, 1)}}
	error = ""
	address_text = ""
	state = State.HOSTING
	changed.emit()
	return true


## Connects to what the player typed: "ip", "ip:port", "host", "host:port" or "[v6]:port".
## False, with `error` set, when that is not an address. The outcome comes through
## `changed`: JOINED, or FAILED with the reason.
func join(text: String) -> bool:
	if state != State.OFF and state != State.FAILED:
		return false
	var parsed := parse_address(text, _t.port)
	if parsed.is_empty():
		_fail(BAD_ADDRESS)
		return false
	address_text = text.strip_edges()
	_join_port = parsed["port"]
	_connect_left_ms = _t.connect_timeout_ms
	_refusal = ""
	error = ""
	players = {}
	if parsed["ip"]:
		_connect(parsed["host"])
	else:
		_resolve_name = parsed["host"]
		_resolve_item = IP.resolve_hostname_queue_item(_resolve_name, IP.TYPE_ANY)
		if _resolve_item < 0:
			_fail("couldn't look up %s" % _resolve_name)
			return false
		state = State.RESOLVING
	changed.emit()
	return state != State.FAILED


## Closes the socket: a host sends everyone away, a joiner leaves. Back to OFF.
func leave() -> void:
	if state == State.OFF:
		return
	_shut_peer()
	_clear_players()
	state = State.OFF
	error = ""
	address_text = ""
	changed.emit()


func is_online() -> bool:
	return state == State.HOSTING or state == State.JOINED


func is_connecting() -> bool:
	return state == State.RESOLVING or state == State.CONNECTING


## The port a host listens on, or 0.
func listen_port() -> int:
	if state != State.HOSTING or _enet == null:
		return 0
	return _enet.host.get_local_port()


func my_name() -> String:
	return players.get(my_id, {}).get("name", "")


## The roster in slot order, "name" with "(you)" after this player's.
func roster_text() -> String:
	var slots := []
	for id in players:
		slots.append([players[id]["slot"], id])
	slots.sort()
	var parts := PackedStringArray()
	for pair in slots:
		var id: int = pair[1]
		parts.append(players[id]["name"] + (" (you)" if id == my_id else ""))
	return ", ".join(parts)


func state_word() -> String:
	return State.keys()[state].to_lower()


func _physics_process(delta: float) -> void:
	match state:
		State.RESOLVING:
			_tick_resolve(delta)
		State.CONNECTING:
			_connect_left_ms -= delta * 1000.0
			if _connect_left_ms <= 0.0:
				_fail(CANT_REACH)
		State.HOSTING:
			_tick_refused(delta)
			_tick_send(delta)
		State.JOINED:
			_tick_send(delta)


func _tick_resolve(delta: float) -> void:
	_connect_left_ms -= delta * 1000.0
	match IP.get_resolve_item_status(_resolve_item):
		IP.RESOLVER_STATUS_DONE:
			var found := IP.get_resolve_item_addresses(_resolve_item)
			IP.erase_resolve_item(_resolve_item)
			_resolve_item = -1
			var ip := ""
			for candidate in found:
				var text := String(candidate)
				if text.is_valid_ip_address() and (ip == "" or (text.count(":") == 0 and ip.count(":") > 0)):
					ip = text
			if ip == "":
				_fail("couldn't find %s" % _resolve_name)
			else:
				_connect(ip)
		IP.RESOLVER_STATUS_ERROR, IP.RESOLVER_STATUS_NONE:
			IP.erase_resolve_item(_resolve_item)
			_resolve_item = -1
			_fail("couldn't find %s" % _resolve_name)
		_:
			if _connect_left_ms <= 0.0:
				_fail(CANT_REACH)


func _tick_refused(delta: float) -> void:
	if _refused.is_empty():
		return
	var m := multiplayer as SceneMultiplayer
	for id in _refused.keys():
		_refused[id] -= delta * 1000.0
		if _refused[id] <= 0.0:
			_refused.erase(id)
			if m.get_authenticating_peers().has(id):
				m.disconnect_peer(id)


func _tick_send(delta: float) -> void:
	if players.size() < 2:
		_send_wait_s = 0.0
		return
	_send_wait_s -= delta
	if _send_wait_s > 0.0:
		return
	_send_wait_s += 1.0 / _t.sync_rate_hz
	_send_state()


func _connect(ip: String) -> void:
	var enet := ENetMultiplayerPeer.new()
	if enet.create_client(ip, _join_port) != OK:
		_fail(CANT_REACH)
		return
	_enet = enet
	multiplayer.multiplayer_peer = _enet
	my_id = multiplayer.get_unique_id()
	state = State.CONNECTING
	changed.emit()


func _fail(message: String) -> void:
	_shut_peer()
	_clear_players()
	state = State.FAILED
	error = message
	changed.emit()


func _shut_peer() -> void:
	if _resolve_item >= 0:
		IP.erase_resolve_item(_resolve_item)
		_resolve_item = -1
	_pending.clear()
	_refused.clear()
	if _enet != null:
		_enet.close()
		_enet = null
	if is_inside_tree():
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func _clear_players() -> void:
	players = {}
	for id in avatars.keys():
		_drop_avatar(id)
	my_id = 1
	_send_wait_s = 0.0


# --- The handshake. ---

func _on_authenticating(id: int) -> void:
	if state == State.CONNECTING and id == 1:
		(multiplayer as SceneMultiplayer).send_auth(1, hello_bytes(protocol, _t.display_name))


func _on_auth(id: int, data: PackedByteArray) -> void:
	if state == State.HOSTING:
		_host_auth(id, data)
	elif state == State.CONNECTING and id == 1:
		_joiner_auth(data)


func _host_auth(id: int, data: PackedByteArray) -> void:
	var m := multiplayer as SceneMultiplayer
	if not m.get_authenticating_peers().has(id) or _pending.has(id) or _refused.has(id):
		return
	var hello := parse_hello(data)
	var verdict := Verdict.OK
	if hello.is_empty() or hello["version"] != protocol:
		verdict = Verdict.VERSION
	elif players.size() + _pending.size() >= _t.max_players:
		verdict = Verdict.FULL
	if verdict != Verdict.OK:
		m.send_auth(id, reply_bytes(protocol, verdict, 0, ""))
		_refused[id] = REFUSE_GRACE_MS
		return
	var slot := _free_slot()
	var name := assigned_name(hello["name"], slot)
	_pending[id] = {"slot": slot, "name": name}
	m.send_auth(id, reply_bytes(protocol, Verdict.OK, slot, name))
	m.complete_auth(id)


func _joiner_auth(data: PackedByteArray) -> void:
	var reply := parse_reply(data)
	if reply.is_empty():
		_refusal = BAD_REPLY
		_fail(_refusal)
		return
	match reply["verdict"]:
		Verdict.OK:
			players[my_id] = {"slot": reply["slot"], "name": reply["name"]}
			(multiplayer as SceneMultiplayer).complete_auth(1)
		Verdict.VERSION:
			_refusal = "version mismatch: host %d, you %d" % [reply["version"], protocol]
			_fail(_refusal)
		_:
			_refusal = HOST_FULL
			_fail(_refusal)


func _on_auth_failed(id: int) -> void:
	if state == State.HOSTING:
		_pending.erase(id)
		_refused.erase(id)
	elif state == State.CONNECTING and id == 1:
		_fail(_refusal if _refusal != "" else CANT_REACH)


func _on_peer_connected(id: int) -> void:
	if state != State.HOSTING or not _pending.has(id):
		return
	players[id] = _pending[id]
	_pending.erase(id)
	_set_peer_timeout(id)
	_spawn_avatar(id)
	_send_roster()
	changed.emit()


func _on_peer_disconnected(id: int) -> void:
	if state != State.HOSTING or not players.has(id):
		return
	players.erase(id)
	_drop_avatar(id)
	_send_roster()
	changed.emit()


func _on_connected() -> void:
	if state != State.CONNECTING:
		return
	_set_peer_timeout(1)
	state = State.JOINED
	error = ""
	changed.emit()


func _on_connection_failed() -> void:
	if state == State.CONNECTING:
		_fail(_refusal if _refusal != "" else CANT_REACH)


func _on_server_disconnected() -> void:
	if state == State.JOINED:
		_fail(HOST_LEFT)
	elif state == State.CONNECTING:
		_fail(_refusal if _refusal != "" else CANT_REACH)


func _set_peer_timeout(id: int) -> void:
	if _enet == null or not multiplayer.get_peers().has(id):
		return
	_enet.get_peer(id).set_timeout(ENET_TIMEOUT_LIMIT, _t.peer_timeout_ms / 2, _t.peer_timeout_ms)


func _free_slot() -> int:
	var taken := {}
	for id in players:
		taken[players[id]["slot"]] = true
	for id in _pending:
		taken[_pending[id]["slot"]] = true
	var slot := 1
	while taken.has(slot):
		slot += 1
	return slot


# --- The roster and the state, host to joiners and joiners to host. ---

func _send_roster() -> void:
	var ids := PackedInt32Array()
	var slots := PackedInt32Array()
	var names := PackedStringArray()
	for id in players:
		ids.append(id)
		slots.append(players[id]["slot"])
		names.append(players[id]["name"])
	var connected := multiplayer.get_peers()
	for id in players:
		if id != 1 and connected.has(id):
			_roster.rpc_id(id, ids, slots, names)


@rpc("authority", "call_remote", "reliable")
func _roster(ids: PackedInt32Array, slots: PackedInt32Array, names: PackedStringArray) -> void:
	if state != State.JOINED:
		return
	var n := ids.size()
	if n < 1 or n > _t.max_players or slots.size() != n or names.size() != n:
		return
	var next := {}
	for i in n:
		if ids[i] < 1 or slots[i] < 1 or slots[i] > SLOT_LAST:
			return
		next[ids[i]] = {"slot": slots[i], "name": names[i] if Tuning.name_ok(names[i]) else "%s %d" % [PLACEHOLDER, slots[i]]}
	if not next.has(my_id) or not next.has(1):
		return
	players = next
	for id in avatars.keys():
		if not players.has(id):
			_drop_avatar(id)
	for id in players:
		if id != my_id:
			_spawn_avatar(id)
	changed.emit()


func _send_state() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_seq += 1
	var pos: Vector3 = _player.position
	var yaw: float = _player.rotation.y
	var pitch: float = _player.view_pitch() if _player.has_method("view_pitch") else 0.0
	var vel: Vector3 = _player.velocity if "velocity" in _player else Vector3.ZERO
	var connected := multiplayer.get_peers()
	if state == State.HOSTING:
		for id in players:
			if id != 1 and connected.has(id):
				_remote_state.rpc_id(id, 1, _seq, pos, yaw, pitch, vel)
	elif connected.has(1):
		_state.rpc_id(1, _seq, pos, yaw, pitch, vel)
	sent += 1


## A joiner's own movement, to the host.
@rpc("any_peer", "call_remote", "unreliable_ordered")
func _state(seq: int, pos: Vector3, yaw: float, pitch: float, vel: Vector3) -> void:
	if state != State.HOSTING:
		return
	var from := multiplayer.get_remote_sender_id()
	if from == 1 or not players.has(from) or not sane(pos, yaw, pitch, vel):
		return
	received += 1
	_apply_remote(from, seq, pos, yaw, pitch, vel)
	var connected := multiplayer.get_peers()
	for id in players:
		if id != 1 and id != from and connected.has(id):
			_remote_state.rpc_id(id, from, seq, pos, yaw, pitch, vel)


## A player's movement, from the host.
@rpc("authority", "call_remote", "unreliable_ordered")
func _remote_state(id: int, seq: int, pos: Vector3, yaw: float, pitch: float, vel: Vector3) -> void:
	if state != State.JOINED or id == my_id or not players.has(id) or not sane(pos, yaw, pitch, vel):
		return
	received += 1
	_apply_remote(id, seq, pos, yaw, pitch, vel)


func _apply_remote(id: int, seq: int, pos: Vector3, yaw: float, pitch: float, vel: Vector3) -> void:
	var avatar = avatars.get(id)
	if avatar != null and is_instance_valid(avatar):
		avatar.push_sample(seq, pos, yaw, pitch, vel)


func _spawn_avatar(id: int) -> void:
	if _players_node == null or not is_instance_valid(_players_node) or avatars.has(id) or not players.has(id):
		return
	var avatar := RemotePlayer.new()
	avatar.name = "Player%d" % id
	avatar.player_name = players[id]["name"]
	avatar.interp_delay_s = _t.interp_delay_ms / 1000.0
	avatar.extrapolate_max_s = _t.extrapolate_max_ms / 1000.0
	_players_node.add_child(avatar)
	avatars[id] = avatar


func _drop_avatar(id: int) -> void:
	var avatar = avatars.get(id)
	avatars.erase(id)
	if avatar != null and is_instance_valid(avatar):
		avatar.queue_free()


# --- Pure helpers, checked on their own by the test. ---

## True when every number of a state packet is one a player could have.
static func sane(pos: Vector3, yaw: float, pitch: float, vel: Vector3) -> bool:
	if not pos.is_finite() or not vel.is_finite() or not is_finite(yaw) or not is_finite(pitch):
		return false
	if absf(pos.x) > WORLD_LAST or absf(pos.y) > WORLD_LAST or absf(pos.z) > WORLD_LAST:
		return false
	return absf(pitch) <= PITCH_LAST and vel.length() <= SPEED_LAST


## The name a player is shown under: the one it asked for when it is one the game can
## show and not the placeholder, else "player <slot>".
static func assigned_name(requested: String, slot: int) -> String:
	if Tuning.name_ok(requested) and requested != PLACEHOLDER:
		return requested
	return "%s %d" % [PLACEHOLDER, slot]


## {host, port, ip} from what the player typed, or {} when it is not an address. Accepts
## "ip", "ip:port", "name", "name:port", "[v6]" and "[v6]:port"; a bare IPv6 address with
## its colons is taken whole. `default_port` fills in a missing port.
static func parse_address(text: String, default_port: int) -> Dictionary:
	var s := text.strip_edges()
	if s.is_empty() or s.length() > ADDRESS_LAST:
		return {}
	var host := s
	var port_text := ""
	if s.begins_with("["):
		var close := s.find("]")
		if close < 0:
			return {}
		host = s.substr(1, close - 1)
		var rest := s.substr(close + 1)
		if rest != "":
			if not rest.begins_with(":"):
				return {}
			port_text = rest.substr(1)
	elif s.count(":") == 1:
		var parts := s.split(":")
		host = parts[0]
		port_text = parts[1]
	var port := default_port
	if port_text != "":
		if port_text.length() > 5:
			return {}
		for i in port_text.length():
			var code := port_text.unicode_at(i)
			if code < 0x30 or code > 0x39:
				return {}
		port = int(port_text)
	if port < 1 or port > PORT_LAST:
		return {}
	if host.is_valid_ip_address():
		return {"host": host, "port": port, "ip": true}
	if not hostname_ok(host):
		return {}
	return {"host": host, "port": port, "ip": false}


## True for a host name made of letters, digits and hyphens in dot-separated labels.
static func hostname_ok(name: String) -> bool:
	if name.is_empty() or name.length() > HOSTNAME_LAST:
		return false
	for label in name.split("."):
		if label.is_empty() or label.length() > LABEL_LAST or label.begins_with("-") or label.ends_with("-"):
			return false
		for i in label.length():
			var code := label.unicode_at(i)
			var ok := (code >= 0x30 and code <= 0x39) or (code >= 0x41 and code <= 0x5A) or (code >= 0x61 and code <= 0x7A) or code == 0x2D
			if not ok:
				return false
	return true


## The joiner's hello: "SK", the protocol version, the name's length and the name.
static func hello_bytes(version: int, name: String) -> PackedByteArray:
	var shown := name if Tuning.name_ok(name) else PLACEHOLDER
	var out := PackedByteArray([MAGIC_0, MAGIC_1, 0, 0, 0])
	out.encode_u16(2, clampi(version, 0, VERSION_LAST))
	out.encode_u8(4, shown.length())
	out.append_array(shown.to_ascii_buffer())
	return out


## {version, name} from a hello, or {} when it is not one. A name the game cannot show
## becomes the placeholder.
static func parse_hello(data: PackedByteArray) -> Dictionary:
	if data.size() < HELLO_HEAD or data[0] != MAGIC_0 or data[1] != MAGIC_1:
		return {}
	var n := data.decode_u8(4)
	if data.size() != HELLO_HEAD + n:
		return {}
	var name := data.slice(HELLO_HEAD).get_string_from_ascii()
	return {"version": data.decode_u16(2), "name": name if Tuning.name_ok(name) else PLACEHOLDER}


## The host's reply: "SK", its version, the verdict, the slot and the assigned name.
static func reply_bytes(version: int, verdict: int, slot: int, name: String) -> PackedByteArray:
	var out := PackedByteArray([MAGIC_0, MAGIC_1, 0, 0, 0, 0, 0])
	out.encode_u16(2, clampi(version, 0, VERSION_LAST))
	out.encode_u8(4, clampi(verdict, 0, Verdict.size() - 1))
	out.encode_u8(5, clampi(slot, 0, SLOT_LAST))
	out.encode_u8(6, name.length())
	out.append_array(name.to_ascii_buffer())
	return out


## {version, verdict, slot, name} from a reply, or {} when it is not one, or an ok reply
## has no slot or no name the game can show.
static func parse_reply(data: PackedByteArray) -> Dictionary:
	if data.size() < REPLY_HEAD or data[0] != MAGIC_0 or data[1] != MAGIC_1:
		return {}
	var n := data.decode_u8(6)
	if data.size() != REPLY_HEAD + n:
		return {}
	var verdict := data.decode_u8(4)
	if verdict >= Verdict.size():
		return {}
	var slot := data.decode_u8(5)
	var name := data.slice(REPLY_HEAD).get_string_from_ascii()
	if verdict == Verdict.OK and (slot < 1 or not Tuning.name_ok(name)):
		return {}
	return {"version": data.decode_u16(2), "verdict": verdict, "slot": slot, "name": name}


func _port_free(port: int) -> bool:
	var probe := PacketPeerUDP.new()
	var ok := probe.bind(port, _t.bind_address) == OK
	probe.close()
	return ok
