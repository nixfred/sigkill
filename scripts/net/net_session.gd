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
## Combat (C14) runs on the same session with the host as the one authority
## (scripts/net/combat.gd): a player sends only the intent to fire (shot number, origin,
## direction); the host validates it, raycasts in its own world against walls, dummies and
## the players' bodies, applies the one weapon's damage, and tells everyone the result
## (the shot with its end point and the victim's health, a death, a respawn). The host's
## own shots go through exactly the same path. Joiners never apply damage or decide a
## kill; they display what the host sent. Remote avatars carry a hit volume on the targets
## layer that nothing walks into. Dummies stay each player's own; the host's combat ray
## stops at one but never damages it.
##
## Over the wire, ever: the protocol version, slots and ids, shown names (a placeholder,
## never the system's user or host name), positions, angles and velocities, shot intents
## and results, health, deaths and respawns by id. Nothing about the AI guide, the
## settings, paths, processes or the machine. Nothing real is signalled, killed or run.

const Tuning = preload("res://scripts/net/net_tuning.gd")
const RemotePlayer = preload("res://scripts/net/remote_player.gd")
const Combat = preload("res://scripts/net/combat.gd")
const CombatTuningScript = preload("res://scripts/net/combat_tuning.gd")
const WeaponTuningScript = preload("res://scripts/weapon_tuning.gd")
const CannonFx = preload("res://scripts/cannon_fx.gd")

const DEFAULT_TUNING_PATH := "res://resources/net.tres"
const COMBAT_TUNING_PATH := "res://resources/combat.tres"
const WEAPON_PATH := "res://resources/terminal_cannon.tres"
## The physics layer the local player's body is on: a joiner's shot must be able to hit it.
const PLAYER_LAYER_MASK := 2
const SPAWNS_NODE := "Arena/Spawns"
const FALLBACK_SPAWN := Vector3(0.0, 0.95, 10.0)
const PLAYER_ID_META := "player_id"
## Changes whenever what goes over the wire changes. Both sides must match.
const PROTOCOL := 2
const PLACEHOLDER := "player"
const DAEMON := "Daemon-"
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
## Sequence numbers count up from 1 per session and never reach this.
const SEQ_LAST := 2147483647
const PITCH_LAST := PI * 0.5 + 0.01
## A body yaw is an angle Godot already wrapped: never past one full turn either way.
const YAW_LAST := TAU + 0.01
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
## Combat, from the host's confirmed results (on the host too, through the same path).
signal combat_changed
signal shot_confirmed(shooter: int, hit: int, origin: Vector3, end_point: Vector3)
signal player_died(victim: int, killer: int)
signal player_respawned(id: int)

# Set these before the node enters the tree.
## NetTuning; null for resources/net.tres.
var tuning: Resource = null
## The protocol version this side speaks. A test gives one side another number to prove
## the mismatch is refused. Never changed by the game.
var protocol := PROTOCOL
## CombatTuning; null for resources/combat.tres.
var combat_tuning: Resource = null

var state: State = State.OFF
## Why the last join or host attempt ended, for the screen, or "".
var error := ""
## What the player typed to join, shown back on their own screen only.
var address_text := ""
## For a host: the last joiner it refused and why, so the host's screen says so too.
var notice := ""
## Everyone in the session, id -> {slot, name}; the host is id 1.
var players := {}
var my_id := 1
## The remote players' avatars in the current arena, id -> RemotePlayer.
var avatars := {}
## State packets sent, and received and applied, this session.
var sent := 0
var received := 0
## The host's combat authority while hosting; null otherwise.
var combat: Combat = null
## What every side shows, from the host: id -> health, dead, protection left, the last
## killer, respawn countdown (for the dead, counted down locally from the host's number).
var health := {}
var dead := {}
var protect_left := {}
var last_killer := {}
var respawn_left := {}
## Each player's life number: up by one at every respawn, carried in every state packet,
## so a position sent before a respawn and arriving after it is known for what it is.
var lives := {}
## A respawn that arrived for this player while its arena was reloading: the host's chosen
## spawn, in arena space, applied when the next arena attaches. INF when none is waiting.
var _pending_spawn := Vector3.INF
## How soon the host tries a respawn again when its own arena is absent.
const RESPAWN_RETRY_S := 0.05
## After the host's arena attaches, how long a respawn waits for the opponents' positions
## to arrive (a few send intervals), so the spawn is chosen away from them.
const SPAWN_LOOK_S := 0.5
## The host's clock when its arena last attached; respawns wait a little after it.
var _attached_at := -INF
## Shot intents this player sent (or, hosting, fired), numbered from 1 per session.
var fire_seq := 0

var _t: Tuning
var _enet: ENetMultiplayerPeer
var _arena: Node = null
var _player: Node = null
var _players_node: Node3D = null
var _connect_left_ms := 0.0
var _resolve_item := -1
var _resolve_name := ""
var _join_port := 0
## The local port a joiner's socket was bound to on the tuning's bind address, or 0 when
## it was left to the system on every interface.
var _local_port := 0
var _seq := 0
var _send_wait_s := 0.0
## Host: joiners that passed the handshake, id -> {slot, name}, until peer_connected.
var _pending := {}
## Host: refused joiners and the grace left before they are dropped, id -> ms.
var _refused := {}
var _ct: CombatTuningScript
var _weapon: WeaponTuningScript
## The host's clock for the fire rate, in seconds of game time.
var _clock := 0.0
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
	_ct = usable_combat_tuning(combat_tuning)
	var shipped_weapon = load(WEAPON_PATH)
	_weapon = shipped_weapon if shipped_weapon is WeaponTuningScript and shipped_weapon.problems().is_empty() else WeaponTuningScript.new()
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


func combat_tuning_in_use() -> CombatTuningScript:
	return _ct


static func usable_combat_tuning(candidate: Resource) -> CombatTuningScript:
	if candidate is CombatTuningScript:
		var issues: PackedStringArray = candidate.problems()
		if issues.is_empty():
			return candidate
		for issue in issues:
			push_warning("combat tuning: " + issue + "; using the shipped tuning instead")
	var shipped = load(COMBAT_TUNING_PATH)
	if shipped is CombatTuningScript and shipped.problems().is_empty():
		return shipped
	return CombatTuningScript.new()


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
	if player.has_signal("fire_intent") and not player.fire_intent.is_connected(_on_fire_intent):
		player.fire_intent.connect(_on_fire_intent)
	if _pending_spawn.is_finite() and player.has_method("respawn_at"):
		player.respawn_at(arena.to_global(_pending_spawn))  # the host chose this while the arena was away
	_pending_spawn = Vector3.INF
	_attached_at = _clock
	if player.has_method("set_alive"):
		player.set_alive(not dead.get(my_id, false))
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
	_seq = 0
	fire_seq = 0
	_clock = 0.0
	combat = Combat.new(_ct, _weapon.fire_cooldown, _weapon.damage)
	combat.add_player(1)
	_mirror_from_combat()
	error = ""
	notice = ""
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
	_seq = 0
	fire_seq = 0
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
	notice = ""
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
			_clock += delta
			_tick_refused(delta)
			_tick_send(delta)
			for id in combat.tick(delta):
				if _arena == null or not is_instance_valid(_arena) or _player == null or not is_instance_valid(_player):
					combat.defer_respawn(id, RESPAWN_RETRY_S)  # no arena to choose a spawn in yet
				elif _clock - _attached_at < SPAWN_LOOK_S and _opponents_unseen(id):
					combat.defer_respawn(id, RESPAWN_RETRY_S)  # the arena just came back: wait for their positions
				else:
					_do_respawn(id)
			_mirror_from_combat()
			_tick_protection(delta)
		State.JOINED:
			_tick_send(delta)
			_tick_protection(delta)


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
	_local_port = 0
	if _t.bind_address != "*":
		# ENet binds a joiner's socket to the bind address only with a local port named,
		# so one the system has just handed out on that address is taken.
		enet.set_bind_ip(_t.bind_address)
		_local_port = _spare_port()
		if _local_port == 0:
			_fail(CANT_REACH)
			return
	if enet.create_client(ip, _join_port, 0, 0, 0, _local_port) != OK:
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
	combat = null
	health = {}
	dead = {}
	protect_left = {}
	last_killer = {}
	respawn_left = {}
	lives = {}
	_pending_spawn = Vector3.INF
	if _player != null and is_instance_valid(_player) and _player.has_method("set_alive"):
		_player.set_alive(true)
	combat_changed.emit()


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
		if verdict == Verdict.VERSION:
			notice = "refused a joiner: version mismatch, host %d, joiner %s" % [protocol, str(hello["version"]) if not hello.is_empty() else "unknown"]
		else:
			notice = "refused a joiner: host full"
		changed.emit()
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
	combat.add_player(id)
	_mirror_from_combat()
	_spawn_avatar(id)
	_send_roster()
	changed.emit()


func _on_peer_disconnected(id: int) -> void:
	if state != State.HOSTING or not players.has(id):
		return
	players.erase(id)
	combat.remove_player(id)
	for table in [health, dead, protect_left, last_killer, respawn_left, lives]:
		table.erase(id)
	_drop_avatar(id)
	_send_roster()
	changed.emit()
	combat_changed.emit()


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
	var healths := PackedFloat32Array()
	var deads := PackedByteArray()
	var protects := PackedFloat32Array()
	var life_numbers := PackedInt32Array()
	for id in players:
		ids.append(id)
		slots.append(players[id]["slot"])
		names.append(players[id]["name"])
		healths.append(combat.health_of(id))
		deads.append(0 if combat.alive(id) else 1)
		protects.append(combat.states[id]["protect_left"])
		life_numbers.append(lives.get(id, 0))
	var connected := multiplayer.get_peers()
	for id in players:
		if id != 1 and connected.has(id):
			_roster.rpc_id(id, ids, slots, names, healths, deads, protects, life_numbers)


@rpc("authority", "call_remote", "reliable")
func _roster(ids: PackedInt32Array, slots: PackedInt32Array, names: PackedStringArray, healths: PackedFloat32Array, deads: PackedByteArray, protects: PackedFloat32Array, life_numbers: PackedInt32Array) -> void:
	if state != State.JOINED:
		return
	var n := ids.size()
	if n < 1 or n > _t.max_players or slots.size() != n or names.size() != n or healths.size() != n or deads.size() != n or protects.size() != n or life_numbers.size() != n:
		return
	var next := {}
	for i in n:
		if ids[i] < 1 or slots[i] < 1 or slots[i] > SLOT_LAST or not is_finite(healths[i]) or healths[i] < 0.0 or healths[i] > _ct.max_health or not is_finite(protects[i]) or protects[i] < 0.0 or life_numbers[i] < 0:
			return
		next[ids[i]] = {"slot": slots[i], "name": names[i] if Tuning.name_ok(names[i]) else assigned_name("", slots[i])}
	if not next.has(my_id) or not next.has(1):
		return
	players = next
	for i in n:
		health[ids[i]] = healths[i]
		dead[ids[i]] = deads[i] != 0
		protect_left[ids[i]] = protects[i]
		lives[ids[i]] = life_numbers[i]
	for table in [health, dead, protect_left, last_killer, respawn_left, lives]:
		for id in table.keys():
			if not players.has(id):
				table.erase(id)
	for id in avatars.keys():
		if not players.has(id):
			_drop_avatar(id)
	for id in players:
		if id != my_id:
			_spawn_avatar(id)
			_show_avatar_state(id)
	if _player != null and is_instance_valid(_player) and _player.has_method("set_alive"):
		_player.set_alive(not dead.get(my_id, false))
	changed.emit()
	combat_changed.emit()


func _send_state() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_seq += 1
	var pos: Vector3 = _player.position
	var yaw: float = _player.rotation.y
	var pitch: float = _player.view_pitch() if _player.has_method("view_pitch") else 0.0
	var vel: Vector3 = _player.velocity if "velocity" in _player else Vector3.ZERO
	var life: int = lives.get(my_id, 0)
	var connected := multiplayer.get_peers()
	if state == State.HOSTING:
		for id in players:
			if id != 1 and connected.has(id):
				_remote_state.rpc_id(id, 1, life, _seq, pos, yaw, pitch, vel)
	elif connected.has(1):
		_state.rpc_id(1, _seq, life, pos, yaw, pitch, vel)
	sent += 1


## A joiner's own movement, to the host. Untyped on purpose: a packet of the wrong types
## is dropped here, never an engine error.
@rpc("any_peer", "call_remote", "unreliable_ordered")
func _state(seq: Variant, life: Variant, pos: Variant, yaw: Variant, pitch: Variant, vel: Variant) -> void:
	if state != State.HOSTING:
		return
	if typeof(seq) != TYPE_INT or typeof(life) != TYPE_INT or typeof(pos) != TYPE_VECTOR3 or typeof(yaw) != TYPE_FLOAT or typeof(pitch) != TYPE_FLOAT or typeof(vel) != TYPE_VECTOR3:
		return
	var from := multiplayer.get_remote_sender_id()
	if from == 1 or not players.has(from) or not seq_sane(seq) or not sane(pos, yaw, pitch, vel):
		return
	# A dead player goes nowhere, and a position from a past life is a packet that was in
	# flight when the respawn happened.
	if combat != null and (not combat.alive(from) or life != lives.get(from, 0)):
		return
	received += 1
	_apply_remote(from, seq, pos, yaw, pitch, vel)
	var connected := multiplayer.get_peers()
	for id in players:
		if id != 1 and id != from and connected.has(id):
			_remote_state.rpc_id(id, from, life, seq, pos, yaw, pitch, vel)


## A player's movement, from the host.
@rpc("authority", "call_remote", "unreliable_ordered")
func _remote_state(id: int, life: int, seq: int, pos: Vector3, yaw: float, pitch: float, vel: Vector3) -> void:
	if state != State.JOINED or id == my_id or not players.has(id) or not seq_sane(seq) or not sane(pos, yaw, pitch, vel):
		return
	if dead.get(id, false) or life != lives.get(id, 0):
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
	avatar.player_id = id
	avatar.player_name = players[id]["name"]
	avatar.interp_delay_s = _t.interp_delay_ms / 1000.0
	avatar.extrapolate_max_s = _t.extrapolate_max_ms / 1000.0
	_players_node.add_child(avatar)
	avatars[id] = avatar
	_show_avatar_state(id)


## The avatar's health, death and protection as this side knows them.
func _show_avatar_state(id: int) -> void:
	var avatar = avatars.get(id)
	if avatar == null or not is_instance_valid(avatar):
		return
	avatar.health = health.get(id, _ct.max_health)
	avatar.protected = protect_left.get(id, 0.0) > 0.0
	if dead.get(id, false) and not avatar.dead:
		avatar.hide_dead()


# --- Combat: intents in, the host's results out. ---

## This player's cannon fired (scripts/player.gd): the intent goes to the host, which, when
## this is the host, is the same validation every other shot gets.
func _on_fire_intent(origin: Vector3, direction: Vector3) -> void:
	if not is_online() or _arena == null or not is_instance_valid(_arena):
		return
	fire_seq += 1
	var local_origin: Vector3 = _arena.to_local(origin)
	var local_dir: Vector3 = (_arena.global_transform.basis.inverse() * direction).normalized()
	if state == State.HOSTING:
		_handle_fire(1, fire_seq, local_origin, local_dir)
	elif multiplayer.get_peers().has(1):
		_fire.rpc_id(1, fire_seq, local_origin, local_dir)


## A joiner's intent to fire, to the host. Untyped on purpose: a packet of the wrong types
## is dropped and counted here, never an engine error.
@rpc("any_peer", "call_remote", "reliable")
func _fire(seq: Variant, origin: Variant, dir: Variant) -> void:
	if state != State.HOSTING or combat == null:
		return
	if typeof(seq) != TYPE_INT or typeof(origin) != TYPE_VECTOR3 or typeof(dir) != TYPE_VECTOR3:
		combat.validate(0, 0, Vector3.ZERO, Vector3.ZERO, Vector3.INF, _clock)  # counted: no such shot
		return
	_handle_fire(multiplayer.get_remote_sender_id(), seq, origin, dir)


## The one authority path: validate, raycast in the host's world, apply, tell everyone.
func _handle_fire(shooter: int, seq: int, origin: Vector3, dir: Vector3) -> void:
	if state != State.HOSTING or combat == null:
		return
	if not players.has(shooter):
		combat.validate(0, seq, origin, dir, Vector3.INF, _clock)  # counted: no such player
		return
	var eye := _eye_of(shooter)
	if not eye.is_finite():
		combat.validate(0, seq, origin, dir, eye, _clock)  # counted: nothing of it is known yet
		return
	if combat.validate(shooter, seq, origin, dir, eye, _clock) != "":
		return
	# Within the tolerance is not enough: a claimed origin the host's view of the eye
	# cannot see (behind cover it stands against) is a shot through that cover.
	if shooter != 1 and _obstructed(shooter, eye, origin):
		combat.drop_after(Combat.DROP_ORIGIN)
		return
	combat.accept(shooter, seq, _clock)
	var ray := _raycast(shooter, origin, dir)
	var hit: int = ray["hit"]
	var victim_health := -1.0
	var killed := false
	if hit != 0:
		var outcome := combat.damage_player(hit, shooter)
		if outcome.is_empty():
			hit = 0  # dead or protected: the shot landed on nothing that counts
		else:
			victim_health = outcome["health"]
			killed = outcome["killed"]
	# The death is told after the shot, so the mirror learns of it then: the avatar must
	# play its derezz, not be hidden first by the health update.
	_broadcast_shot(shooter, origin, ray["end"], hit, victim_health)
	if killed:
		_broadcast_death(hit, shooter, dir)
	_mirror_from_combat()


## Where the host believes `id`'s eye is, in arena space: its own camera for itself, the
## newest received position (or the spawn it was just put at) plus the eye height for a
## joiner; INF when nothing is known of it yet.
func _eye_of(id: int) -> Vector3:
	if _player == null or not is_instance_valid(_player) or _arena == null:
		return Vector3.INF
	if id == 1:
		return _arena.to_local(_player.eye_position()) if _player.has_method("eye_position") else Vector3.INF
	var avatar = avatars.get(id)
	if avatar == null or not is_instance_valid(avatar) or not avatar.visible:
		return Vector3.INF
	var eye_height: float = _player.eye_height() if _player.has_method("eye_height") else 0.7
	return avatar.latest_position() + Vector3(0.0, eye_height, 0.0)


## True when something solid lies between the host's view of the shooter's eye and the
## origin it claims: cover, a dummy or another player's body. The shooter's own avatar,
## which the eye sits inside, does not count.
func _obstructed(shooter: int, eye: Vector3, origin: Vector3) -> bool:
	var from: Vector3 = _arena.to_global(eye)
	var to: Vector3 = _arena.to_global(origin)
	if from.distance_to(to) < 0.001:
		return false
	var query := PhysicsRayQueryParameters3D.create(from, to, _weapon.hit_mask | PLAYER_LAYER_MASK)
	var exclude: Array[RID] = []
	var own = avatars.get(shooter)
	if own != null and is_instance_valid(own):
		exclude.append(own.hit_rid())
	if not combat.alive(1):
		exclude.append(_player.get_rid())  # the host's corpse is no cover, as in the shot itself
	query.exclude = exclude
	return not _player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## The host's own raycast for a believed shot: walls, dummies, the players' bodies, never
## the shooter's own. {end, hit}: the end point in arena space and the player hit, or 0.
func _raycast(shooter: int, origin: Vector3, dir: Vector3) -> Dictionary:
	var from: Vector3 = _arena.to_global(origin)
	var along: Vector3 = (_arena.global_transform.basis * dir).normalized()
	var far := from + along * _weapon.fire_range
	var query := PhysicsRayQueryParameters3D.create(from, far, _weapon.hit_mask | PLAYER_LAYER_MASK)
	# Players can stand inside each other, at a shared spawn for one: a shot that starts
	# inside an opponent still hits it. The shooter's own body is excluded below.
	query.hit_from_inside = true
	var exclude: Array[RID] = []
	if shooter == 1 or not combat.alive(1):
		exclude.append(_player.get_rid())  # the shooter's own body, or the host's corpse
	if shooter != 1:
		var own = avatars.get(shooter)
		if own != null and is_instance_valid(own):
			exclude.append(own.hit_rid())
	query.exclude = exclude
	var result: Dictionary = _player.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return {"end": _arena.to_local(far), "hit": 0}
	var collider = result["collider"]
	var hit := 0
	if collider == _player and shooter != 1 and combat.has_player(1):
		hit = 1
	elif is_instance_valid(collider) and collider.has_meta(PLAYER_ID_META):
		var id: int = collider.get_meta(PLAYER_ID_META, 0)
		if id != shooter and combat.has_player(id):
			hit = id
	return {"end": _arena.to_local(result["position"]), "hit": hit}


func _broadcast_shot(shooter: int, origin: Vector3, end_point: Vector3, hit: int, victim_health: float) -> void:
	_apply_shot(shooter, origin, end_point, hit, victim_health)
	var connected := multiplayer.get_peers()
	for id in players:
		if id != 1 and connected.has(id):
			_shot.rpc_id(id, shooter, origin, end_point, hit, victim_health)


## A shot the host believed: who fired, where it went, whom it hit and their health now.
@rpc("authority", "call_remote", "reliable")
func _shot(shooter: int, origin: Vector3, end_point: Vector3, hit: int, victim_health: float) -> void:
	if state != State.JOINED or not players.has(shooter) or not origin.is_finite() or not end_point.is_finite():
		return
	if hit != 0 and (not players.has(hit) or not is_finite(victim_health) or victim_health < 0.0 or victim_health > _ct.max_health):
		return
	_apply_shot(shooter, origin, end_point, hit, victim_health)


func _apply_shot(shooter: int, origin: Vector3, end_point: Vector3, hit: int, victim_health: float) -> void:
	if hit != 0 and victim_health >= 0.0:
		health[hit] = victim_health
		_show_avatar_state(hit)
	if shooter != my_id and _arena != null and is_instance_valid(_arena):
		CannonFx.spawn_beam(_arena, _arena.to_global(origin), _arena.to_global(end_point), _weapon)
	shot_confirmed.emit(shooter, hit, origin, end_point)
	combat_changed.emit()


func _broadcast_death(victim: int, killer: int, dir: Vector3) -> void:
	_apply_death(victim, killer, dir)
	var connected := multiplayer.get_peers()
	for id in players:
		if id != 1 and connected.has(id):
			_death.rpc_id(id, victim, killer, dir)


## A player went down, from the host.
@rpc("authority", "call_remote", "reliable")
func _death(victim: int, killer: int, dir: Vector3) -> void:
	if state != State.JOINED or not players.has(victim) or not players.has(killer) or not dir.is_finite():
		return
	_apply_death(victim, killer, dir)


func _apply_death(victim: int, killer: int, dir: Vector3) -> void:
	dead[victim] = true
	health[victim] = 0.0
	last_killer[victim] = killer
	respawn_left[victim] = _ct.respawn_delay_s
	if victim == my_id:
		if _player != null and is_instance_valid(_player) and _player.has_method("set_alive"):
			_player.set_alive(false)
	else:
		var avatar = avatars.get(victim)
		if avatar != null and is_instance_valid(avatar):
			avatar.die(dir)
	player_died.emit(victim, killer)
	combat_changed.emit()


func _do_respawn(id: int) -> void:
	var pos := _pick_spawn(id)
	combat.respawn(id)
	_mirror_from_combat()
	var life: int = lives.get(id, 0) + 1
	_apply_respawn(id, life, pos, _ct.spawn_protection_s, combat.health_of(id))
	var connected := multiplayer.get_peers()
	for peer in players:
		if peer != 1 and connected.has(peer):
			_respawn.rpc_id(peer, id, life, pos, _ct.spawn_protection_s, combat.health_of(id))


## True while some living opponent of `id` has sent no position since this arena attached.
func _opponents_unseen(id: int) -> bool:
	for other in players:
		if other == id or other == 1 or not combat.alive(other):
			continue
		var avatar = avatars.get(other)
		if avatar == null or not is_instance_valid(avatar) or not avatar.visible:
			return true
	return false


## The arena's spawn point farthest from the nearest living opponent, in arena space.
func _pick_spawn(id: int) -> Vector3:
	var spawns := []
	if _arena != null and is_instance_valid(_arena):
		var node := _arena.get_node_or_null(SPAWNS_NODE)
		if node != null:
			for marker in node.get_children():
				if marker is Node3D:
					spawns.append(_arena.to_local(marker.global_position))
	if spawns.is_empty():
		spawns.append(FALLBACK_SPAWN)
	var threats := []
	for other in players:
		if other == id or not combat.alive(other):
			continue
		if other == 1:
			if _player != null and is_instance_valid(_player):
				threats.append(_player.position)
		else:
			# A player just put at a spawn, with no new position yet, stands there all the same.
			var avatar = avatars.get(other)
			if avatar != null and is_instance_valid(avatar) and avatar.visible:
				threats.append(avatar.latest_position())
	return Combat.farthest_spawn(spawns, threats)


## A player is back, from the host: its new life number, where, how long safe, with what
## health.
@rpc("authority", "call_remote", "reliable")
func _respawn(id: int, life: int, pos: Vector3, protect_s: float, new_health: float) -> void:
	if state != State.JOINED or not players.has(id) or life < 0 or not pos.is_finite() or not is_finite(protect_s) or protect_s < 0.0 or not is_finite(new_health) or new_health <= 0.0 or new_health > _ct.max_health:
		return
	_apply_respawn(id, life, pos, protect_s, new_health)


func _apply_respawn(id: int, life: int, pos: Vector3, protect_s: float, new_health: float) -> void:
	dead[id] = false
	health[id] = new_health
	protect_left[id] = protect_s
	lives[id] = life
	respawn_left.erase(id)
	if id == my_id:
		if _player != null and is_instance_valid(_player) and _arena != null and is_instance_valid(_arena):
			if _player.has_method("respawn_at"):
				_player.respawn_at(_arena.to_global(pos))
			if _player.has_method("set_alive"):
				_player.set_alive(true)
		else:
			_pending_spawn = pos  # the arena is reloading: the next one puts the player there
	else:
		var avatar = avatars.get(id)
		if avatar != null and is_instance_valid(avatar):
			avatar.revive(pos)
	_show_avatar_state(id)
	player_respawned.emit(id)
	combat_changed.emit()


func _tick_protection(delta: float) -> void:
	var any := false
	for id in protect_left.keys():
		if protect_left[id] > 0.0:
			protect_left[id] = maxf(protect_left[id] - delta, 0.0)
			any = true
			if protect_left[id] == 0.0:
				_show_avatar_state(id)
	for id in respawn_left.keys():
		respawn_left[id] = maxf(respawn_left[id] - delta, 0.0)
		any = true
	if any:
		combat_changed.emit()


## The host's own screen shows the authority's numbers.
func _mirror_from_combat() -> void:
	if combat == null:
		return
	for id in combat.states:
		health[id] = combat.health_of(id)
		dead[id] = not combat.alive(id)


func _drop_avatar(id: int) -> void:
	var avatar = avatars.get(id)
	avatars.erase(id)
	if avatar != null and is_instance_valid(avatar):
		avatar.queue_free()


# --- Pure helpers, checked on their own by the test. ---

## True for a sequence number a sender could have counted to.
static func seq_sane(seq: int) -> bool:
	return seq >= 1 and seq < SEQ_LAST


## True when every number of a state packet is one a player could have.
static func sane(pos: Vector3, yaw: float, pitch: float, vel: Vector3) -> bool:
	if not pos.is_finite() or not vel.is_finite() or not is_finite(yaw) or not is_finite(pitch):
		return false
	if absf(pos.x) > WORLD_LAST or absf(pos.y) > WORLD_LAST or absf(pos.z) > WORLD_LAST:
		return false
	return absf(yaw) <= YAW_LAST and absf(pitch) <= PITCH_LAST and vel.length() <= SPEED_LAST


## The name a player is shown under: "Daemon-<slot>", always. A requested name is read
## and checked but never used for the name, so no joiner can call itself Daemon-1 or
## borrow another player's name; the slot alone tells players apart. Never anything from
## the system.
static func assigned_name(_requested: String, slot: int) -> String:
	return "%s%d" % [DAEMON, slot]


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


## A port on the bind address the system has just handed out and given back, or 0.
func _spare_port() -> int:
	var probe := PacketPeerUDP.new()
	var port := probe.get_local_port() if probe.bind(0, _t.bind_address) == OK else 0
	probe.close()
	return port
