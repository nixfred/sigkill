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
## (scripts/net/combat.gd): a player sends only the intent to fire (shot number, life,
## weapon id, origin, aim); the host validates it (the weapon held, its fire interval, the
## swap time, its magazine), draws a pellet weapon's pellets itself from the aim with its
## own generator (C16: a joiner never chooses where pellets go), raycasts each in its own
## world against walls, dummies and the players' bodies, applies each pellet's damage after
## its falloff, and tells everyone the result. A player also tells the host when it draws a
## weapon and when it starts a reload, so the host keeps the same rules as its inventory;
## both sides start a match with slot 1 drawn and every weapon full (the shot with every pellet's end point, who
## was hit and their health, a death with the weapon, a respawn). The host's own shots go
## through exactly the same path. Joiners never apply damage or decide a kill; they display
## what the host sent, and their own tracers are a guess drawn before the host answers.
## Remote avatars carry a hit volume on the targets layer that nothing walks into. Dummies
## stay each player's own; the host's combat ray stops at one but never damages it. During
## a match an R reload of the arena hands the new player the weapons and ammo the old one
## had, so it never refills a magazine.
##
## Room codes (C15): a host with a live rendezvous (scripts/net/rendezvous_client.gd) draws
## a code from scripts/net/room_code.gd, registers it with its game port and shows it; a
## joiner who types a code or a sigkill://join/ link has it checked here first (a typo never
## reaches the network), then resolved to an address and port, then joined by the C13 path.
## The game's only rendezvous today is NullRendezvous, never live: a code gets "Online rooms
## aren't live yet. Use LAN join (address)." and nothing is sent anywhere.
##
## Over the wire, ever: the protocol version, slots and ids, shown names (a placeholder,
## never the system's user or host name), positions, angles and velocities, shot intents
## and results, health, deaths and respawns by id. Nothing about the AI guide, the
## settings, paths, processes or the machine. Nothing real is signalled, killed or run.

const Tuning = preload("res://scripts/net/net_tuning.gd")
const RemotePlayer = preload("res://scripts/net/remote_player.gd")
const Combat = preload("res://scripts/net/combat.gd")
const RoomCode = preload("res://scripts/net/room_code.gd")
const NullRendezvous = preload("res://scripts/net/null_rendezvous.gd")
const RoomTuningScript = preload("res://scripts/net/room_tuning.gd")
const CombatTuningScript = preload("res://scripts/net/combat_tuning.gd")
const WeaponDefScript = preload("res://scripts/weapons/weapon_def.gd")
const ArsenalScript = preload("res://scripts/weapons/arsenal_tuning.gd")
const CannonFx = preload("res://scripts/cannon_fx.gd")

const DEFAULT_TUNING_PATH := "res://resources/net.tres"
const COMBAT_TUNING_PATH := "res://resources/combat.tres"
const ROOM_TUNING_PATH := "res://resources/room.tres"
const ARSENAL_PATH := "res://resources/arsenal.tres"
## The longest weapon id an intent may carry.
const WEAPON_ID_LAST := 32
## The physics layer the local player's body is on: a joiner's shot must be able to hit it.
const PLAYER_LAYER_MASK := 2
const SPAWNS_NODE := "Arena/Spawns"
const FALLBACK_SPAWN := Vector3(0.0, 0.95, 10.0)
const PLAYER_ID_META := "player_id"
## Changes whenever what goes over the wire changes. Both sides must match.
const PROTOCOL := 3
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
const ROOM_UNKNOWN := "no open room with code %s"
const ROOM_EXPIRED := "room code %s has expired: ask the host for a new one"
const ROOM_UNREACHABLE := "couldn't reach the room service"
const ROOM_BUSY := "the room service is busy: try again in a moment"
const ROOM_BAD_REPLY := "the room service answered in a way this version does not understand"
const ROOM_NO_CODE := "no room code (%s): LAN join by address still works"
const ROOM_ALL_TAKEN := "every code drawn was taken"
## Until relay hosting is decided (docs/RELAY.md), a room code may lead only to this machine,
## the LAN or a tailnet: never to a public address a rendezvous names.
const ROOM_NOT_LOCAL := "that room is outside your LAN or tailnet; online rooms aren't live yet"

enum State { OFF, HOSTING, RESOLVING, CONNECTING, JOINED, FAILED, ROOM }
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
## RoomTuning; null for resources/room.tres.
var room_tuning: Resource = null
## The rendezvous for room codes; null: the one RoomTuning gives, today always NullRendezvous.
## A test hands in its fake.
var rendezvous: RefCounted = null
## While hosting with a live rendezvous: this room's code once registered, else "".
var room_code := ""
## Seconds until room_code is given up and a fresh one registered.
var room_expires_s := 0.0

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
## The killer's name as it was at the death, kept for the banner and the feed even after
## that player has left.
var last_killer_name := {}
## The signal the killing weapon sends, for the feed: "SIGKILL" for the cannon (C16).
var last_kill_word := {}
var respawn_left := {}
## Each player's life number: up by one at every respawn, carried in every state packet,
## so a position sent before a respawn and arriving after it is known for what it is.
var lives := {}
## A respawn that arrived for this player while its arena was reloading: the host's chosen
## spawn, in arena space, applied when the next arena attaches. INF when none is waiting.
var _pending_spawn := Vector3.INF
## The weapon that respawn put in this player's hand, applied with it.
var _pending_weapon := ""
## Joiner: whether the first roster has come (the host holds this player from then on),
## and whether this side's weapons have started fresh since, which needs a player.
var _roster_seen := false
var _weapons_synced := false
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
var _rt: RoomTuningScript
var _rv: RefCounted
## The rendezvous request in flight ("register", "resolve" or ""), the code it is about,
## the codes drawn so far for this room, the port registered, and the time left for it.
var _room_request := ""
var _room_wanted := ""
var _room_attempts := 0
var _room_port := 0
var _room_left_ms := 0.0
var _launch_checked := false
## A --join taken before this node was ready (the arena makes the session a frame late):
## the parsed result, applied in _ready.
var _launch_pending := {}
## The arsenal every player holds (C16): id -> WeaponDef, and the swap time.
var _weapons := {}
var _weapon_list: Array = []
var _swap_s := 0.3
## The host's own generator for pellets: a joiner never picks where its pellets go.
var _pellets_rng := RandomNumberGenerator.new()
## During a match: the weapons and ammo of the player whose arena went away (an R reload),
## handed to the next player that attaches.
var _kept_inventory: RefCounted = null
## Joiner: weapon intents (draws, reloads, shots) sent to the host this session. Host: the
## same, received from each player, id -> count. The host's ammo reply after each one names
## the count it has handled, and a joiner takes only a reply that has caught up with all it
## sent: a late one is stale. One that comes while the arena is away waits for the next.
var _sent_actions := 0
var _actions_from := {}
var _ammo_pending := {}
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
	tuning_in_use()
	combat_tuning_in_use()
	room_tuning_in_use()
	rendezvous_in_use()
	if not _launch_pending.is_empty():
		var pending := _launch_pending
		_launch_pending = {}
		_apply_launch(pending)
	var shipped_arsenal = load(ARSENAL_PATH)
	_weapon_list = ArsenalScript.usable_loadout(shipped_arsenal)
	for def in _weapon_list:
		_weapons[def.id] = def
	_swap_s = ArsenalScript.usable_timing(shipped_arsenal).swap_s
	_pellets_rng.randomize()
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


## The tunings and the rendezvous in use. Made on first use, so a screen that looks at a
## session before it is ready (the arena makes it a frame late) already gets real ones.
func tuning_in_use() -> Tuning:
	if _t == null:
		_t = usable_tuning(tuning)
	return _t


func combat_tuning_in_use() -> CombatTuningScript:
	if _ct == null:
		_ct = usable_combat_tuning(combat_tuning)
	return _ct


func room_tuning_in_use() -> RoomTuningScript:
	if _rt == null:
		_rt = usable_room_tuning(room_tuning)
	return _rt


func rendezvous_in_use() -> RefCounted:
	if _rv == null:
		_rv = rendezvous if rendezvous != null else rendezvous_for(room_tuning_in_use())
	return _rv


## The rendezvous a RoomTuning gives: NullRendezvous for an empty relay_url, and, because no
## network rendezvous client is built yet (docs/RELAY.md: hosting waits on Fred), for any
## other value too. Nothing here ever opens a connection.
static func rendezvous_for(_tuning: Resource) -> RefCounted:
	return NullRendezvous.new()


static func usable_room_tuning(candidate: Resource) -> RoomTuningScript:
	if candidate is RoomTuningScript:
		var issues: PackedStringArray = candidate.problems()
		if issues.is_empty():
			return candidate
		for issue in issues:
			push_warning("room tuning: " + issue + "; using the shipped tuning instead")
	var shipped = load(ROOM_TUNING_PATH)
	if shipped is RoomTuningScript and shipped.problems().is_empty():
		return shipped
	return RoomTuningScript.new()


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
	if player.has_signal("weapon_drawn") and not player.weapon_drawn.is_connected(_on_weapon_drawn):
		player.weapon_drawn.connect(_on_weapon_drawn)
	if player.has_signal("reload_started") and not player.reload_started.is_connected(_on_reload_started):
		player.reload_started.connect(_on_reload_started)
	if is_online() and _kept_inventory != null and player.has_method("adopt_inventory"):
		player.adopt_inventory(_kept_inventory)  # an R reload mid-match keeps the ammo
	_kept_inventory = null
	if _pending_spawn.is_finite() and player.has_method("respawn_at"):
		player.respawn_at(arena.to_global(_pending_spawn))  # the host chose this while the arena was away
		if player.has_method("refill_weapons"):
			player.refill_weapons()  # and refilled every weapon, as a respawn does
		if _pending_weapon != "" and player.has_method("hold_weapon"):
			player.hold_weapon(_pending_weapon)
	_pending_spawn = Vector3.INF
	_pending_weapon = ""
	if not _ammo_pending.is_empty() and _ammo_pending["life"] == lives.get(my_id, 0) and _ammo_pending["handled"] == _sent_actions and player.has_method("take_ammo"):
		_apply_ammo(_ammo_pending)  # a count that came while the arena was away
	_ammo_pending = {}
	_attached_at = _clock
	if player.has_method("set_alive"):
		player.set_alive(not dead.get(my_id, false))
	_sync_weapons()  # a first roster that came while the arena was away
	for id in players:
		if id != my_id:
			_spawn_avatar(id)


func _on_arena_exit() -> void:
	if is_online() and _player != null and is_instance_valid(_player):
		_kept_inventory = _player.get("inventory")
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
	combat = Combat.new(_ct, _weapon_list, _swap_s)
	combat.add_player(1)
	_reset_player_weapons()
	_mirror_from_combat()
	error = ""
	notice = ""
	address_text = ""
	state = State.HOSTING
	if _rv.is_live():
		_room_attempts = 0
		_register_room()
	changed.emit()
	return true


## Joins by a room code or a sigkill://join/ link: checked here first (a typo or a bad link
## is refused at once, with nothing sent), then, with a live rendezvous, resolved to the
## host's address and port and joined by the C13 path. With NullRendezvous: NOT_LIVE.
func join_room(text: String) -> bool:
	if state != State.OFF and state != State.FAILED:
		return false
	var parsed := RoomCode.parse_join(text)
	if parsed.has("error"):
		_fail(parsed["error"])
		return false
	if not _rv.is_live():
		_fail(NullRendezvous.NOT_LIVE)
		return false
	var code: String = parsed["code"]
	if not _rv.resolve(code, protocol):
		_fail(ROOM_UNREACHABLE)
		return false
	_room_request = "resolve"
	_room_wanted = code
	_room_left_ms = _rt.request_timeout_ms
	error = ""
	notice = ""
	players = {}
	address_text = "room " + code
	state = State.ROOM
	changed.emit()
	return true


## The game's own command-line arguments, once per session: a --join with a room code or
## an invite link joins that room; a bad one fails with the reason. True when there was a
## --join at all, good or bad, so the screen can show what came of it.
func take_launch_join(args: PackedStringArray) -> bool:
	if _launch_checked:
		return false
	_launch_checked = true
	var parsed := RoomCode.parse_args(args)
	if parsed.is_empty():
		return false
	if not is_node_ready():
		_launch_pending = parsed  # not in the tree yet: _ready applies it
	else:
		_apply_launch(parsed)
	return true


func _apply_launch(parsed: Dictionary) -> void:
	if parsed.has("error"):
		_fail(parsed["error"])
	else:
		join_room(parsed["code"])


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
	return state == State.RESOLVING or state == State.CONNECTING or state == State.ROOM


## True while a host's room code registration is in flight, and only then.
func is_getting_room_code() -> bool:
	return _room_request == "register"


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
		State.ROOM:
			_tick_room_lookup(delta)
		State.HOSTING:
			_clock += delta
			_tick_room_code(delta)
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


# --- Room codes. ---

## Draws a code and asks the rendezvous to hold it for this room's game port.
func _register_room() -> void:
	var code := RoomCode.generate()
	_room_attempts += 1
	_room_port = listen_port()
	if not _rv.register(code, protocol, _room_port):
		notice = ROOM_NO_CODE % ROOM_UNREACHABLE
		return
	_room_request = "register"
	_room_wanted = code
	_room_left_ms = _rt.request_timeout_ms


func _tick_room_code(delta: float) -> void:
	if _room_request == "register":
		var done: Dictionary = _rv.poll()
		if done.is_empty():
			_room_left_ms -= delta * 1000.0
			if _room_left_ms <= 0.0:
				_rv.cancel()
				_rv.close(_room_wanted, protocol, _room_port)  # it may have been taken in all the same
				_room_request = ""
				notice = ROOM_NO_CODE % ROOM_UNREACHABLE
				changed.emit()
			return
		_room_request = ""
		if done.get("ok", false):
			var given = done.get("expires_in_s", 0)
			if not (given is int) or given <= 0:
				_rv.close(_room_wanted, protocol, _room_port)  # held for no time: release it
				notice = ROOM_NO_CODE % ROOM_BAD_REPLY
				changed.emit()
				return
			room_code = _room_wanted
			room_expires_s = float(mini(given, _rt.code_ttl_s))
			notice = ""
		elif done.get("error", "") == "taken" and _room_attempts < _rt.register_attempts:
			_register_room()  # someone holds that one: draw another
		else:
			if done.get("error", "") != "taken":
				# A timeout or an odd answer: the rendezvous may hold the code all the same.
				_rv.close(_room_wanted, protocol, _room_port)
			notice = ROOM_NO_CODE % _room_error_text(done)
		changed.emit()
	elif room_code != "":
		room_expires_s -= delta
		if room_expires_s <= 0.0:
			# One live code per room: the old one is released, then a fresh one drawn.
			_rv.close(room_code, protocol, _room_port)
			room_code = ""
			_room_attempts = 0
			_register_room()
			changed.emit()


func _tick_room_lookup(delta: float) -> void:
	var done: Dictionary = _rv.poll()
	if done.is_empty():
		_room_left_ms -= delta * 1000.0
		if _room_left_ms <= 0.0:
			_rv.cancel()
			_room_request = ""
			_fail(ROOM_UNREACHABLE)
		return
	_room_request = ""
	var code := _room_wanted
	if not done.get("ok", false):
		_fail(_room_error_text(done))
		return
	var address = done.get("address", "")
	var port = done.get("port", 0)
	if not (address is String) or not address.is_valid_ip_address() or not (port is int) or port < 1 or port > PORT_LAST:
		_fail(ROOM_BAD_REPLY)
		return
	if not local_address(address):
		_fail(ROOM_NOT_LOCAL)
		return
	state = State.OFF  # from here it is the C13 join, to the address the rendezvous gave
	if join(("[%s]:%d" if address.contains(":") else "%s:%d") % [address, port]):
		address_text = "room " + code


## What went wrong with a rendezvous request, for the screen.
func _room_error_text(done: Dictionary) -> String:
	match done.get("error", ""):
		"unknown":
			return ROOM_UNKNOWN % _room_wanted
		"expired":
			return ROOM_EXPIRED % _room_wanted
		"version":
			return "version mismatch: host %d, you %d" % [int(done.get("host_protocol", 0)), protocol]
		"busy":
			return ROOM_BUSY
		"taken":
			return ROOM_ALL_TAKEN
		"not_live":
			return NullRendezvous.NOT_LIVE
		"bad_reply":
			return ROOM_BAD_REPLY
	return ROOM_UNREACHABLE


## Stops any rendezvous request and releases this room's code, and a code whose
## registration was still unanswered (it may have been taken all the same).
func _end_room() -> void:
	if _rv == null:
		return
	if _room_request != "":
		_rv.cancel()
		if _room_request == "register":
			_rv.close(_room_wanted, protocol, _room_port)
	if room_code != "" and _rv.is_live():
		_rv.close(room_code, protocol, _room_port)
	_room_request = ""
	room_code = ""
	room_expires_s = 0.0
	_room_attempts = 0


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
	_end_room()
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
	last_killer_name = {}
	last_kill_word = {}
	respawn_left = {}
	lives = {}
	_pending_spawn = Vector3.INF
	_pending_weapon = ""
	_roster_seen = false
	_weapons_synced = false
	_kept_inventory = null
	_sent_actions = 0
	_actions_from = {}
	_ammo_pending = {}
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
	_actions_from[id] = 0
	_mirror_from_combat()
	_spawn_avatar(id)
	_send_roster()
	changed.emit()


func _on_peer_disconnected(id: int) -> void:
	if state != State.HOSTING or not players.has(id):
		return
	players.erase(id)
	combat.remove_player(id)
	_actions_from.erase(id)
	for table in [health, dead, protect_left, last_killer, last_killer_name, last_kill_word, respawn_left, lives]:
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
	for table in [health, dead, protect_left, last_killer, last_killer_name, last_kill_word, respawn_left, lives]:
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
	_roster_seen = true
	_sync_weapons()
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

## Joiner, once: after the first roster (the host holds this player by then) and with a
## player here, weapons start fresh with slot 1 being drawn, and that draw goes to the host,
## so any draw sent before it held the player is undone and both sides wait the same swap.
## With the arena away it waits for the next one.
func _sync_weapons() -> void:
	if state != State.JOINED or not _roster_seen or _weapons_synced:
		return
	if _player == null or not is_instance_valid(_player) or not _player.has_method("reset_inventory"):
		return
	_weapons_synced = true
	_player.reset_inventory(true)
	_on_weapon_drawn(_player.weapon_tuning().id)


## A match starts with slot 1 drawn and every weapon full on this side, as the host counts.
func _reset_player_weapons() -> void:
	if _player != null and is_instance_valid(_player) and _player.has_method("reset_inventory"):
		_player.reset_inventory()


## This player drew a weapon or started a reload: the host hears of it as of every shot.
## A joiner sends nothing about its weapons until their fresh start (_sync_weapons): what it
## did before the host held it is undone there on both sides.
func _on_weapon_drawn(weapon: String) -> void:
	if state == State.HOSTING:
		_handle_draw(1, lives.get(my_id, 0), weapon)
	elif state == State.JOINED and _weapons_synced and multiplayer.get_peers().has(1):
		_sent_actions += 1
		_draw.rpc_id(1, lives.get(my_id, 0), weapon)


func _on_reload_started(weapon: String) -> void:
	if state == State.HOSTING:
		_handle_reload(1, lives.get(my_id, 0), weapon)
	elif state == State.JOINED and _weapons_synced and multiplayer.get_peers().has(1):
		_sent_actions += 1
		_reload.rpc_id(1, lives.get(my_id, 0), weapon)


## A joiner drew a weapon, to the host. Untyped like _fire: wrong types are counted, never
## an engine error.
@rpc("any_peer", "call_remote", "reliable")
func _draw(life: Variant, weapon: Variant) -> void:
	if state != State.HOSTING or combat == null:
		return
	if typeof(life) != TYPE_INT or typeof(weapon) != TYPE_STRING:
		combat.draw(0, 0, "", 0, _clock)  # counted: no such draw
	else:
		_handle_draw(multiplayer.get_remote_sender_id(), life, weapon.left(WEAPON_ID_LAST + 1))
	_ack_actions(multiplayer.get_remote_sender_id())


## A joiner started a reload, to the host.
@rpc("any_peer", "call_remote", "reliable")
func _reload(life: Variant, weapon: Variant) -> void:
	if state != State.HOSTING or combat == null:
		return
	if typeof(life) != TYPE_INT or typeof(weapon) != TYPE_STRING:
		combat.reload(0, 0, "", 0, _clock)  # counted: no such reload
	else:
		_handle_reload(multiplayer.get_remote_sender_id(), life, weapon.left(WEAPON_ID_LAST + 1))
	_ack_actions(multiplayer.get_remote_sender_id())


func _handle_draw(id: int, life: int, weapon: String) -> void:
	if state == State.HOSTING and combat != null:
		combat.draw(id if players.has(id) else 0, life, weapon, lives.get(id, 0), _clock)


func _handle_reload(id: int, life: int, weapon: String) -> void:
	if state == State.HOSTING and combat != null:
		combat.reload(id if players.has(id) else 0, life, weapon, lives.get(id, 0), _clock)


## One more weapon intent handled from `id`: the host's count of its magazines goes back to
## it with the number handled so far. The host's own player needs none: nothing lies between
## it and the host's count.
func _ack_actions(id: int) -> void:
	if id == 1 or not players.has(id):
		return
	_actions_from[id] = _actions_from.get(id, 0) + 1
	_send_ammo(id)


## The host's count of `id`'s magazine and reserve for every weapon that has one, to that
## player alone, with the intents handled from it so far.
func _send_ammo(id: int) -> void:
	if not multiplayer.get_peers().has(id):
		return
	combat.settle(id, _clock)  # a reload whose time is up counts as done
	var ids := PackedStringArray()
	var mags := PackedInt32Array()
	var reserves := PackedInt32Array()
	for def in _weapon_list:
		if def.has_magazine():
			var ammo: Array = combat.ammo_of(id, def.id)
			ids.append(def.id)
			mags.append(ammo[0])
			reserves.append(ammo[1])
	_ammo.rpc_id(id, lives.get(id, 0), _actions_from.get(id, 0), ids, mags, reserves)


## The host's count of this player's magazines once it has handled `handled` of this side's
## intents: taken when that is all this side has sent in this life, else stale and dropped.
@rpc("authority", "call_remote", "reliable")
func _ammo(life: int, handled: int, ids: PackedStringArray, mags: PackedInt32Array, reserves: PackedInt32Array) -> void:
	if state != State.JOINED or life != lives.get(my_id, 0) or handled != _sent_actions:
		return
	if ids.size() != mags.size() or ids.size() != reserves.size() or ids.size() > _weapon_list.size():
		return
	for i in ids.size():
		var def = _weapons.get(ids[i])
		if def == null or not def.has_magazine() or mags[i] < 0 or mags[i] > def.magazine_size or (reserves[i] != WeaponDefScript.INFINITE and (reserves[i] < 0 or reserves[i] > def.reserve_ammo)):
			return
	var count := {"life": life, "handled": handled, "ids": ids, "mags": mags, "reserves": reserves}
	if _player != null and is_instance_valid(_player) and _player.has_method("take_ammo"):
		_apply_ammo(count)
	else:
		_ammo_pending = count  # the arena is away: the next player takes it


func _apply_ammo(count: Dictionary) -> void:
	for i in count["ids"].size():
		_player.take_ammo(count["ids"][i], count["mags"][i], count["reserves"][i])


## This player fired (scripts/player.gd): the intent goes to the host, which, when this is
## the host, is the same validation every other shot gets. Only the aim goes: the host
## draws a pellet weapon's pellets itself.
func _on_fire_intent(origin: Vector3, direction: Vector3, weapon: String) -> void:
	if not is_online() or _arena == null or not is_instance_valid(_arena):
		return
	if state == State.JOINED and not _weapons_synced:
		return  # the host does not count this player's weapons yet: the fresh start comes first
	fire_seq += 1
	var local_origin: Vector3 = _arena.to_local(origin)
	var local_dir: Vector3 = (_arena.global_transform.basis.inverse() * direction).normalized()
	var life: int = lives.get(my_id, 0)
	if state == State.HOSTING:
		_handle_fire(1, fire_seq, life, weapon, local_origin, local_dir)
	elif multiplayer.get_peers().has(1):
		_sent_actions += 1
		_fire.rpc_id(1, fire_seq, life, weapon, local_origin, local_dir)


## A joiner's intent to fire, to the host. Untyped on purpose: a packet of the wrong types
## is dropped and counted here, never an engine error.
@rpc("any_peer", "call_remote", "reliable")
func _fire(seq: Variant, life: Variant, weapon: Variant, origin: Variant, dir: Variant) -> void:
	if state != State.HOSTING or combat == null:
		return
	if typeof(seq) != TYPE_INT or typeof(life) != TYPE_INT or typeof(weapon) != TYPE_STRING or typeof(origin) != TYPE_VECTOR3 or typeof(dir) != TYPE_VECTOR3:
		combat.validate(0, 0, 0, "", Vector3.ZERO, Vector3.ZERO, Vector3.INF, 0, _clock)  # counted: no such shot
	else:
		_handle_fire(multiplayer.get_remote_sender_id(), seq, life, weapon.left(WEAPON_ID_LAST + 1), origin, dir)
	_ack_actions(multiplayer.get_remote_sender_id())


## The one authority path: validate, draw the pellets, raycast each in the host's world,
## apply, tell everyone.
func _handle_fire(shooter: int, seq: int, life: int, weapon: String, origin: Vector3, dir: Vector3) -> void:
	if state != State.HOSTING or combat == null:
		return
	if not players.has(shooter):
		combat.validate(0, seq, life, weapon, origin, dir, Vector3.INF, 0, _clock)  # counted: no such player
		return
	var eye := _eye_of(shooter)
	if not eye.is_finite():
		combat.validate(0, seq, life, weapon, origin, dir, eye, 0, _clock)  # counted: nothing of it is known yet
		return
	if combat.validate(shooter, seq, life, weapon, origin, dir, eye, lives.get(shooter, 0), _clock) != "":
		return
	var def: WeaponDefScript = combat.weapons[weapon]
	# Within the tolerance is not enough: a claimed origin the host's view of the eye
	# cannot see (behind cover it stands against) is a shot through that cover.
	if shooter != 1 and _obstructed(shooter, eye, origin, def.hit_mask):
		combat.drop_after(Combat.DROP_ORIGIN)
		return
	combat.accept(shooter, seq, weapon, _clock)
	# Every pellet's damage after its falloff, added up per player it struck.
	var ends := PackedVector3Array()
	var struck := {}
	for pellet in def.pellet_directions(dir, _pellets_rng):
		var ray := _raycast(shooter, origin, pellet, def)
		ends.append(ray["end"])
		if ray["hit"] != 0:
			struck[ray["hit"]] = struck.get(ray["hit"], 0.0) + def.damage_at(ray["distance"])
	var hits := PackedInt32Array()
	var healths := PackedFloat32Array()
	var killed := PackedInt32Array()
	for victim in struck:
		var outcome := combat.damage_player(victim, shooter, struck[victim])
		if outcome.is_empty():
			continue  # dead or protected: the pellets landed on nothing that counts
		hits.append(victim)
		healths.append(outcome["health"])
		if outcome["killed"]:
			killed.append(victim)
	# The death is told after the shot, so the mirror learns of it then: the avatar must
	# play its derezz, not be hidden first by the health update.
	_broadcast_shot(shooter, weapon, origin, ends, hits, healths)
	for victim in killed:
		_broadcast_death(victim, shooter, dir, weapon)
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
func _obstructed(shooter: int, eye: Vector3, origin: Vector3, mask: int) -> bool:
	var from: Vector3 = _arena.to_global(eye)
	var to: Vector3 = _arena.to_global(origin)
	if from.distance_to(to) < 0.001:
		return false
	var query := PhysicsRayQueryParameters3D.create(from, to, mask | PLAYER_LAYER_MASK)
	query.exclude = _not_in_the_way(shooter)
	return not _player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## What no shot and no cover probe may stop at: the shooter's own body, and every corpse
## (the host's body while the host is dead, every dead avatar's hit volume: a volume is
## switched off a frame after the death, and a second shot in the same poll must not find
## it in between).
func _not_in_the_way(shooter: int) -> Array[RID]:
	var out: Array[RID] = []
	if shooter == 1 or not combat.alive(1):
		out.append(_player.get_rid())
	for id in avatars:
		var avatar = avatars[id]
		if avatar != null and is_instance_valid(avatar) and (id == shooter or not combat.alive(id)):
			out.append(avatar.hit_rid())
	return out


## The host's own raycast for one pellet of a believed shot of weapon `def`: walls,
## dummies, the players' bodies, never the shooter's own. {end, hit, distance}: the end
## point in arena space, the player hit or 0, and how far the pellet flew.
func _raycast(shooter: int, origin: Vector3, dir: Vector3, def: WeaponDefScript) -> Dictionary:
	var from: Vector3 = _arena.to_global(origin)
	var along: Vector3 = (_arena.global_transform.basis * dir).normalized()
	var far := from + along * def.fire_range
	var query := PhysicsRayQueryParameters3D.create(from, far, def.hit_mask | PLAYER_LAYER_MASK)
	# Players can stand inside each other, at a shared spawn for one: a shot that starts
	# inside an opponent still hits it. The shooter's own body and every corpse are excluded.
	query.hit_from_inside = true
	query.exclude = _not_in_the_way(shooter)
	var result: Dictionary = _player.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return {"end": _arena.to_local(far), "hit": 0, "distance": def.fire_range}
	var collider = result["collider"]
	var hit := 0
	if collider == _player and shooter != 1 and combat.has_player(1):
		hit = 1
	elif is_instance_valid(collider) and collider.has_meta(PLAYER_ID_META):
		var id: int = collider.get_meta(PLAYER_ID_META, 0)
		if id != shooter and combat.has_player(id):
			hit = id
	var flown: float = from.distance_to(result["position"])
	return {"end": _arena.to_local(result["position"]), "hit": hit, "distance": flown}


func _broadcast_shot(shooter: int, weapon: String, origin: Vector3, ends: PackedVector3Array, hits: PackedInt32Array, healths: PackedFloat32Array) -> void:
	_apply_shot(shooter, weapon, origin, ends, hits, healths)
	var connected := multiplayer.get_peers()
	for id in players:
		if id != 1 and connected.has(id):
			_shot.rpc_id(id, shooter, weapon, origin, ends, hits, healths)


## A shot the host believed: who fired which weapon, where each pellet went, whom it hit
## and their health now.
@rpc("authority", "call_remote", "reliable")
func _shot(shooter: int, weapon: String, origin: Vector3, ends: PackedVector3Array, hits: PackedInt32Array, healths: PackedFloat32Array) -> void:
	if state != State.JOINED or not players.has(shooter) or not _weapons.has(weapon) or not origin.is_finite():
		return
	if ends.is_empty() or ends.size() > _weapons[weapon].pellet_count or hits.size() != healths.size() or hits.size() > players.size():
		return
	for end in ends:
		if not end.is_finite():
			return
	for i in hits.size():
		if not players.has(hits[i]) or not is_finite(healths[i]) or healths[i] < 0.0 or healths[i] > _ct.max_health:
			return
	_apply_shot(shooter, weapon, origin, ends, hits, healths)


func _apply_shot(shooter: int, weapon: String, origin: Vector3, ends: PackedVector3Array, hits: PackedInt32Array, healths: PackedFloat32Array) -> void:
	for i in hits.size():
		health[hits[i]] = healths[i]
		_show_avatar_state(hits[i])
	if shooter != my_id and _arena != null and is_instance_valid(_arena):
		for end in ends:
			CannonFx.spawn_beam(_arena, _arena.to_global(origin), _arena.to_global(end), _weapons[weapon])
	if hits.is_empty():
		shot_confirmed.emit(shooter, 0, origin, ends[0])
	for hit in hits:
		shot_confirmed.emit(shooter, hit, origin, ends[0])
	combat_changed.emit()


func _broadcast_death(victim: int, killer: int, dir: Vector3, weapon: String) -> void:
	_apply_death(victim, killer, dir, weapon)
	var connected := multiplayer.get_peers()
	for id in players:
		if id != 1 and connected.has(id):
			_death.rpc_id(id, victim, killer, dir, weapon)


## A player went down, from the host, and to which weapon.
@rpc("authority", "call_remote", "reliable")
func _death(victim: int, killer: int, dir: Vector3, weapon: String) -> void:
	if state != State.JOINED or not players.has(victim) or not players.has(killer) or not dir.is_finite() or not _weapons.has(weapon):
		return
	_apply_death(victim, killer, dir, weapon)


func _apply_death(victim: int, killer: int, dir: Vector3, weapon: String) -> void:
	dead[victim] = true
	health[victim] = 0.0
	last_killer[victim] = killer
	last_killer_name[victim] = players.get(killer, {}).get("name", assigned_name("", 0))
	last_kill_word[victim] = _weapons[weapon].kill_word if _weapons.has(weapon) else ""
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
	var held := combat.drawn_by(id)
	_apply_respawn(id, life, pos, _ct.spawn_protection_s, combat.health_of(id), held)
	var connected := multiplayer.get_peers()
	for peer in players:
		if peer != 1 and connected.has(peer):
			_respawn.rpc_id(peer, id, life, pos, _ct.spawn_protection_s, combat.health_of(id), held)


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
func _respawn(id: int, life: int, pos: Vector3, protect_s: float, new_health: float, held: String) -> void:
	if state != State.JOINED or not players.has(id) or life < 0 or not pos.is_finite() or not is_finite(protect_s) or protect_s < 0.0 or not is_finite(new_health) or new_health <= 0.0 or new_health > _ct.max_health or not _weapons.has(held):
		return
	_apply_respawn(id, life, pos, protect_s, new_health, held)


## A respawn, with `held`, the weapon in the player's hand as the host counts it: this
## player takes it, so a draw that crossed its death leaves no difference behind.
func _apply_respawn(id: int, life: int, pos: Vector3, protect_s: float, new_health: float, held: String) -> void:
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
			if _player.has_method("hold_weapon"):
				_player.hold_weapon(held)
		else:
			_pending_spawn = pos  # the arena is reloading: the next one puts the player there
			_pending_weapon = held
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

## True for an address on this machine, a private LAN or a tailnet: IPv4 loopback, 10/8,
## 172.16/12, 192.168/16, the 100.64/10 shared range tailnets use, link-local 169.254/16;
## IPv6 loopback, unique-local fc00::/7 and link-local fe80::/10. A rendezvous may only send
## a joiner to one of these until relay hosting is decided.
static func local_address(ip: String) -> bool:
	if not ip.is_valid_ip_address():
		return false
	if ip.contains(":"):
		var g := ipv6_groups(ip)
		if g.size() != 8:
			return false
		if g == PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 1]):
			return true
		if g[0] == 0 and g[1] == 0 and g[2] == 0 and g[3] == 0 and g[4] == 0 and g[5] == 0xFFFF:
			return local_address("%d.%d.%d.%d" % [g[6] >> 8, g[6] & 0xFF, g[7] >> 8, g[7] & 0xFF])  # IPv4-mapped
		return (g[0] & 0xFE00) == 0xFC00 or (g[0] & 0xFFC0) == 0xFE80
	var o := ip.split(".")
	var a := int(o[0])
	var b := int(o[1])
	return a == 127 or a == 10 or (a == 172 and b >= 16 and b <= 31) or (a == 192 and b == 168) or (a == 100 and b >= 64 and b <= 127) or (a == 169 and b == 254)


## An IPv6 address as its eight 16-bit groups, "::" expanded and a trailing IPv4 part folded
## in; empty when it is not one.
static func ipv6_groups(ip: String) -> PackedInt32Array:
	var text := ip.to_lower()
	var tail4 := PackedStringArray()
	var last := text.rfind(":")
	if last >= 0 and text.substr(last + 1).contains("."):
		tail4 = text.substr(last + 1).split(".")
		if tail4.size() != 4:
			return PackedInt32Array()
		text = text.substr(0, last + 1) + "0:0"
	var halves := text.split("::")
	if halves.size() > 2:
		return PackedInt32Array()
	var head := halves[0].split(":", false)
	var tail := halves[1].split(":", false) if halves.size() == 2 else PackedStringArray()
	var gap := 8 - head.size() - tail.size()
	if (halves.size() == 1 and gap != 0) or (halves.size() == 2 and gap < 1):
		return PackedInt32Array()
	var out := PackedInt32Array()
	for part in head:
		out.append(_hex_group(part))
	for i in gap if halves.size() == 2 else 0:
		out.append(0)
	for part in tail:
		out.append(_hex_group(part))
	if out.has(-1):
		return PackedInt32Array()
	if not tail4.is_empty():
		for octet in tail4:
			if not octet.is_valid_int() or int(octet) < 0 or int(octet) > 255:
				return PackedInt32Array()
		out[6] = (int(tail4[0]) << 8) | int(tail4[1])
		out[7] = (int(tail4[2]) << 8) | int(tail4[3])
	return out


static func _hex_group(part: String) -> int:
	if part.is_empty() or part.length() > 4 or not part.is_valid_hex_number():
		return -1
	return part.hex_to_int()


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
