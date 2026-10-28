extends RefCounted
## The SIGKILL relay (C16c, docs/RELAY.md): the rendezvous for room codes and a relay for the
## game's own datagrams, in one small service with no disk, no accounts, no analytics and no
## log of any address. relay/relay_main.gd runs it under a headless Godot; tests/relay_test.gd
## runs that as a separate process on 127.0.0.1 only.
##
## Control port (UDP, wire format in scripts/net/relay_wire.gd): a host registers a room code
## and gets the room's join port, its host token and one host-facing port per joiner slot; a
## joiner resolves a code and gets the join port and the join token; the host closes its code
## with the host token. A source is believed only after a cookie round trip (its first request
## is answered with a cookie it must send back), and every request is exactly as big as the
## largest reply, so the relay never amplifies.
##
## Data ports (UDP, per room): the joiner's ENet talks to the join port and the host's ENet to
## the host-facing port of that joiner's slot; the relay forwards the datagrams untouched. A
## side is let in only by a probe with its own token, sent from the game's ENet socket. So
## the host sees each joiner as a relay port and the joiner sees the host as the relay:
## neither ever learns the other's address.
##
## Limits: per source address, registrations, resolutions and cookies a minute and live rooms
## at once; rooms in all; players per room; a room code's life; idle paths dropped; a payload
## cap on every datagram and a packet rate per room; every malformed or unexpected datagram
## dropped and counted. Addresses live in memory only: a joiner's for as long as its path
## carries traffic, a host's for its room's, a registering host's for its code's life (the
## per-address room cap), a source's for its one-minute rate window. Only aggregate counters
## ever leave the process.

const Wire = preload("res://scripts/net/relay_wire.gd")
const RoomCode = preload("res://scripts/net/room_code.gd")

const COOKIE_WINDOW_S := 30
const HOUSEKEEPING_S := 0.5
const RATE_WINDOW_S := 60.0
## Settings: [environment variable, flag, default, least, most]. Every one can be given as
## SIGKILL_RELAY_<NAME> or --<name>; a flag wins.
const SETTINGS := {
	"port": ["SIGKILL_RELAY_PORT", "--port", 9010, 1, 65535],
	"max_rooms": ["SIGKILL_RELAY_ROOMS", "--rooms", 64, 1, 4096],
	"max_players": ["SIGKILL_RELAY_ROOM_PLAYERS", "--room-players", 4, 2, 16],
	"rooms_per_ip": ["SIGKILL_RELAY_ROOMS_PER_IP", "--rooms-per-ip", 2, 1, 64],
	"room_ttl_s": ["SIGKILL_RELAY_ROOM_TTL_S", "--room-ttl-s", 600, 1, 86400],
	"expired_s": ["SIGKILL_RELAY_EXPIRED_S", "--expired-s", 120, 1, 86400],
	"idle_s": ["SIGKILL_RELAY_IDLE_S", "--idle-s", 60, 1, 3600],
	"register_per_min": ["SIGKILL_RELAY_REGISTER_PER_MIN", "--register-per-min", 6, 1, 10000],
	"resolve_per_min": ["SIGKILL_RELAY_RESOLVE_PER_MIN", "--resolve-per-min", 30, 1, 10000],
	"hello_per_min": ["SIGKILL_RELAY_HELLO_PER_MIN", "--hello-per-min", 60, 1, 10000],
	"max_clients": ["SIGKILL_RELAY_SOURCES", "--sources", 4096, 1, 1000000],
	"max_payload": ["SIGKILL_RELAY_PAYLOAD_CAP", "--payload-cap", 1400, 100, 65000],
	"room_pps": ["SIGKILL_RELAY_ROOM_PPS", "--room-pps", 400, 10, 100000],
	"tick_hz": ["SIGKILL_RELAY_TICK_HZ", "--tick-hz", 500, 10, 2000],
	"stats_s": ["SIGKILL_RELAY_STATS_S", "--stats-s", 300, 0, 86400],
}
const COUNTERS := ["requests", "registered", "resolved", "closed", "cookies", "rooms_peak", "relayed_packets", "relayed_bytes", "dropped_bad", "dropped_oversize", "dropped_rate", "dropped_unknown_source", "dropped_full", "busy", "taken", "unknown", "expired", "bad_code"]


class Slot:
	var host_side: PacketPeerUDP
	var host_ip := ""
	var host_port := 0
	var joiner_ip := ""
	var joiner_port := 0
	var last_seen := 0.0


class Room:
	var code := ""
	var protocol := 0
	## The registering source address, only while the code lives: the per-address room cap.
	var owner := ""
	var code_until := 0.0
	var host_token := PackedByteArray()
	var join_token := PackedByteArray()
	var join: PacketPeerUDP
	var slots: Array = []
	var last_active := 0.0
	var window_start := 0.0
	var window_packets := 0

	func live(now: float) -> bool:
		return code != "" and now < code_until


## The settings in use (SETTINGS' keys, plus bind and data_first/data_last), and what was
## counted. Read only by relay_main.gd and the tests.
var config := {}
var counters := {}

var _control: PacketPeerUDP
var _rooms := {}  # live code -> Room
var _all: Array = []  # every Room that still holds its ports
var _expired := {}  # code -> when it is forgotten
var _clients := {}  # source address -> {"since", "register", "resolve", "hello"}
var _secret := PackedByteArray()
var _crypto := Crypto.new()
var _next_port := 0
var _housekeeping_at := 0.0
## The time of the poll in progress, in seconds: every timer in here runs on it.
var _now := 0.0


## The relay's settings from the environment and the flags (a flag wins), or {"error": why}.
## Not set: SETTINGS' defaults, bind 127.0.0.1 (so a relay started by hand is never open to
## the world: a server sets * itself, every interface), and data ports the system picks.
static func config_from(env: Dictionary, args: PackedStringArray) -> Dictionary:
	var out := {"bind": env.get("SIGKILL_RELAY_BIND", "127.0.0.1"), "data_ports": env.get("SIGKILL_RELAY_DATA_PORTS", "0"), "stop_file": ""}
	for key in SETTINGS:
		var spec: Array = SETTINGS[key]
		out[key] = env.get(spec[0], str(spec[2]))
	var i := 0
	while i < args.size():
		var arg := args[i]
		var value := args[i + 1] if i + 1 < args.size() else ""
		var known := false
		for key in SETTINGS:
			if arg == SETTINGS[key][1]:
				out[key] = value
				known = true
		if arg == "--bind":
			out["bind"] = value
			known = true
		elif arg == "--data-ports":
			out["data_ports"] = value
			known = true
		elif arg == "--stop-file":
			out["stop_file"] = value
			known = true
		if not known:
			return {"error": "unknown option %s" % arg}
		if value == "" or value.begins_with("--"):
			return {"error": "%s needs a value" % arg}
		i += 2
	for key in SETTINGS:
		var spec: Array = SETTINGS[key]
		var text := str(out[key])
		if not text.is_valid_int() or int(text) < spec[3] or int(text) > spec[4]:
			return {"error": "%s (%s) must be a whole number from %d to %d" % [spec[1], spec[0], spec[3], spec[4]]}
		out[key] = int(text)
	var bind := str(out["bind"])
	if bind != "*" and not bind.is_valid_ip_address():
		return {"error": "--bind (SIGKILL_RELAY_BIND) must be an IP address or *"}
	var ports := str(out["data_ports"])
	if ports == "0":
		out["data_first"] = 0
		out["data_last"] = 0
	else:
		var parts := ports.split("-")
		if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int() or int(parts[0]) < 1024 or int(parts[1]) > 65535 or int(parts[0]) > int(parts[1]):
			return {"error": "--data-ports (SIGKILL_RELAY_DATA_PORTS) must be 0 (the system picks) or a range like 40000-40999 above 1023"}
		out["data_first"] = int(parts[0])
		out["data_last"] = int(parts[1])
		var needed: int = out["max_rooms"] * out["max_players"]
		if out["data_last"] - out["data_first"] + 1 < needed:
			return {"error": "--data-ports holds %d ports; rooms x room players needs %d" % [out["data_last"] - out["data_first"] + 1, needed]}
		if out["port"] >= out["data_first"] and out["port"] <= out["data_last"]:
			return {"error": "--port must not be inside --data-ports"}
	return out


func _init(settings: Dictionary) -> void:
	config = settings
	for name in COUNTERS:
		counters[name] = 0
	_secret = _crypto.generate_random_bytes(32)
	_next_port = config.get("data_first", 0)


## Opens the control port. "" when it is up, else why not.
func start() -> String:
	_control = PacketPeerUDP.new()
	if _control.bind(config["port"], config["bind"]) != OK:
		_control = null
		return "could not open UDP port %d" % config["port"]
	return ""


## The control port actually open, or 0.
func control_port() -> int:
	return _control.get_local_port() if _control != null else 0


## Rooms holding ports right now.
func rooms_open() -> int:
	return _all.size()


## Closes every socket and forgets every address and code.
func stop() -> void:
	for room in _all:
		_free_room(room)
	_all.clear()
	_rooms.clear()
	_expired.clear()
	_clients.clear()
	if _control != null:
		_control.close()
		_control = null


## One line of aggregate counters: never an address, a code or a token.
func stats_line() -> String:
	var parts := PackedStringArray(["rooms %d" % _all.size()])
	for name in COUNTERS:
		parts.append("%s %d" % [name, counters[name]])
	return ", ".join(parts)


## Everything that arrived since the last call, then the timers. `now` is in seconds.
func poll(now: float) -> void:
	if _control == null:
		return
	_now = now
	while _control.get_available_packet_count() > 0:
		var data := _control.get_packet()
		_on_control(data, _control.get_packet_ip(), _control.get_packet_port(), now)
	for room in _all:
		_drain_room(room, now)
	if now >= _housekeeping_at:
		_housekeeping_at = now + HOUSEKEEPING_S
		_housekeeping(now)


# --- Control. ---

func _on_control(data: PackedByteArray, ip: String, port: int, now: float) -> void:
	counters["requests"] += 1
	if data.size() != Wire.REQUEST_SIZE:
		counters["dropped_oversize" if data.size() > Wire.REQUEST_SIZE else "dropped_bad"] += 1
		return
	var req := Wire.parse_request(data)
	if req.is_empty():
		counters["dropped_bad"] += 1
		return
	if RoomCode.problem(req["code"]) != "":
		counters["bad_code"] += 1  # the game checks every code before it sends one
		return
	var client = _client(ip, now)
	if client == null:
		_reply(ip, port, Wire.Status.BUSY, req["code"])
		return
	if req["op"] == Wire.Op.CLOSE:
		_close(req)  # the host token is the proof; no reply, so nothing to reflect
		return
	if not _cookie_ok(req["cookie"], ip, port, now):
		if not _spend(client, "hello", config["hello_per_min"]):
			counters["dropped_rate"] += 1
			return
		counters["cookies"] += 1
		_reply(ip, port, Wire.Status.COOKIE, req["code"], 0, 0, 0, _cookie(ip, port, _window(now)))
		return
	match req["op"]:
		Wire.Op.REGISTER:
			if not _spend(client, "register", config["register_per_min"]):
				counters["dropped_rate"] += 1
				_reply(ip, port, Wire.Status.BUSY, req["code"])
				return
			_register(req, ip, port, now)
		Wire.Op.RESOLVE:
			if not _spend(client, "resolve", config["resolve_per_min"]):
				counters["dropped_rate"] += 1
				_reply(ip, port, Wire.Status.BUSY, req["code"])
				return
			_resolve(req, ip, port, now)


func _register(req: Dictionary, ip: String, port: int, now: float) -> void:
	var code: String = req["code"]
	if _rooms.has(code) and _rooms[code].live(now):
		counters["taken"] += 1
		_reply(ip, port, Wire.Status.TAKEN, code)
		return
	var owned := 0
	for room in _rooms.values():
		if room.owner == ip and room.live(now):
			owned += 1
	if _all.size() >= config["max_rooms"] or owned >= config["rooms_per_ip"]:
		counters["busy"] += 1
		_reply(ip, port, Wire.Status.BUSY, code)
		return
	var room := Room.new()
	room.join = _data_socket()
	for i in config["max_players"] - 1:
		var slot := Slot.new()
		slot.host_side = _data_socket()
		room.slots.append(slot)
	var short := room.join == null
	for slot in room.slots:
		short = short or slot.host_side == null
	if short:
		_free_room(room)
		counters["busy"] += 1
		_reply(ip, port, Wire.Status.BUSY, code)
		return
	room.code = code
	room.protocol = req["protocol"]
	room.owner = ip
	room.code_until = now + config["room_ttl_s"]
	room.host_token = _crypto.generate_random_bytes(Wire.TOKEN_SIZE)
	room.join_token = _crypto.generate_random_bytes(Wire.TOKEN_SIZE)
	room.last_active = now
	_rooms[code] = room
	_expired.erase(code)
	_all.append(room)
	counters["registered"] += 1
	counters["rooms_peak"] = maxi(counters["rooms_peak"], _all.size())
	var ports := PackedInt32Array()
	for slot in room.slots:
		ports.append(slot.host_side.get_local_port())
	_reply(ip, port, Wire.Status.OK, code, room.protocol, room.join.get_local_port(), config["room_ttl_s"], room.host_token, ports)


func _resolve(req: Dictionary, ip: String, port: int, now: float) -> void:
	var code: String = req["code"]
	var room = _rooms.get(code)
	if room == null or not room.live(now):
		var word := "expired" if _expired.has(code) or room != null else "unknown"
		counters[word] += 1
		_reply(ip, port, Wire.Status.EXPIRED if word == "expired" else Wire.Status.UNKNOWN, code)
		return
	if room.protocol != req["protocol"]:
		_reply(ip, port, Wire.Status.VERSION, code, room.protocol)
		return
	counters["resolved"] += 1
	_reply(ip, port, Wire.Status.OK, code, room.protocol, room.join.get_local_port(), int(ceil(room.code_until - now)), room.join_token)


## The code is released at once (it answers "expired" for a while); the room keeps its ports
## for any match already running through it, until that goes idle.
func _close(req: Dictionary) -> void:
	var room = _rooms.get(req["code"])
	if room == null or room.host_token != req["token"]:
		counters["dropped_bad"] += 1
		return
	counters["closed"] += 1
	_end_code(room)


func _end_code(room: Room) -> void:
	_rooms.erase(room.code)
	_expired[room.code] = _now + config["expired_s"]
	room.code = ""
	room.owner = ""


func _reply(ip: String, port: int, status: int, code: String, protocol: int = 0, join_port: int = 0, left_s: int = 0, token: PackedByteArray = PackedByteArray(), ports: PackedInt32Array = PackedInt32Array()) -> void:
	_control.set_dest_address(ip, port)
	_control.put_packet(Wire.reply_bytes(status, code, protocol, join_port, left_s, token, ports))


## The rate record of a source, or null when the table is full of other live sources.
func _client(ip: String, now: float):
	var rec = _clients.get(ip)
	if rec != null and now - rec["since"] >= RATE_WINDOW_S:
		_clients.erase(ip)
		rec = null
	if rec == null:
		if _clients.size() >= config["max_clients"]:
			counters["busy"] += 1
			return null
		rec = {"since": now, "register": 0, "resolve": 0, "hello": 0}
		_clients[ip] = rec
	return rec


func _spend(rec: Dictionary, what: String, per_min: int) -> bool:
	if rec[what] >= per_min:
		return false
	rec[what] += 1
	return true


func _window(now: float) -> int:
	return int(floor(now / COOKIE_WINDOW_S))


func _cookie(ip: String, port: int, window: int) -> PackedByteArray:
	return _crypto.hmac_digest(HashingContext.HASH_SHA256, _secret, ("%s|%d|%d" % [ip, port, window]).to_utf8_buffer()).slice(0, Wire.TOKEN_SIZE)


## True when `cookie` is the one this source was given in this window or the last.
func _cookie_ok(cookie: PackedByteArray, ip: String, port: int, now: float) -> bool:
	var window := _window(now)
	return cookie == _cookie(ip, port, window) or cookie == _cookie(ip, port, window - 1)


# --- Data. ---

func _drain_room(room: Room, now: float) -> void:
	while room.join.get_available_packet_count() > 0:
		var data := room.join.get_packet()
		var ip := room.join.get_packet_ip()
		var port := room.join.get_packet_port()
		if not _payload_ok(data, room, now):
			continue
		var probe := Wire.parse_probe(data)
		var slot = _joiner_slot(room, ip, port)
		if not probe.is_empty():
			if probe["kind"] != Wire.Probe.JOIN or probe["token"] != room.join_token:
				counters["dropped_bad"] += 1
				continue
			if slot == null:
				slot = _free_slot(room)
				if slot == null:
					counters["dropped_full"] += 1
					continue
				slot.joiner_ip = ip
				slot.joiner_port = port
			slot.last_seen = now
			room.last_active = now
			continue
		if slot == null:
			counters["dropped_unknown_source"] += 1
			continue
		if slot.host_ip == "":
			counters["dropped_unknown_source"] += 1  # the host has not opened this slot's path yet
			continue
		slot.last_seen = now
		room.last_active = now
		slot.host_side.set_dest_address(slot.host_ip, slot.host_port)
		slot.host_side.put_packet(data)
		counters["relayed_packets"] += 1
		counters["relayed_bytes"] += data.size()
	for slot in room.slots:
		while slot.host_side.get_available_packet_count() > 0:
			var data: PackedByteArray = slot.host_side.get_packet()
			var ip: String = slot.host_side.get_packet_ip()
			var port: int = slot.host_side.get_packet_port()
			if not _payload_ok(data, room, now):
				continue
			var probe := Wire.parse_probe(data)
			if not probe.is_empty():
				if probe["kind"] != Wire.Probe.HOST or probe["token"] != room.host_token:
					counters["dropped_bad"] += 1
					continue
				slot.host_ip = ip
				slot.host_port = port
				room.last_active = now
				continue
			if ip != slot.host_ip or port != slot.host_port or slot.joiner_ip == "":
				counters["dropped_unknown_source"] += 1
				continue
			slot.last_seen = now
			room.last_active = now
			room.join.set_dest_address(slot.joiner_ip, slot.joiner_port)
			room.join.put_packet(data)
			counters["relayed_packets"] += 1
			counters["relayed_bytes"] += data.size()


## False, counted, for a datagram over the payload cap or past the room's packet rate.
func _payload_ok(data: PackedByteArray, room: Room, now: float) -> bool:
	if data.size() > config["max_payload"] or data.is_empty():
		counters["dropped_oversize" if not data.is_empty() else "dropped_bad"] += 1
		return false
	if now - room.window_start >= 1.0:
		room.window_start = now
		room.window_packets = 0
	room.window_packets += 1
	if room.window_packets > config["room_pps"]:
		counters["dropped_rate"] += 1
		return false
	return true


func _joiner_slot(room: Room, ip: String, port: int):
	for slot in room.slots:
		if slot.joiner_ip == ip and slot.joiner_port == port:
			return slot
	return null


func _free_slot(room: Room):
	for slot in room.slots:
		if slot.joiner_ip == "":
			return slot
	return null


# --- Time. ---

func _housekeeping(now: float) -> void:
	for code in _rooms.keys():
		var room: Room = _rooms[code]
		if now >= room.code_until:
			_end_code(room)
	for room in _all.duplicate():
		for slot in room.slots:
			if slot.joiner_ip != "" and now - slot.last_seen >= config["idle_s"]:
				slot.joiner_ip = ""  # an idle path: its address is forgotten
				slot.joiner_port = 0
		if room.code == "" and now - room.last_active >= config["idle_s"]:
			_free_room(room)
			_all.erase(room)
	for code in _expired.keys():
		if now >= _expired[code]:
			_expired.erase(code)
	for ip in _clients.keys():
		if now - _clients[ip]["since"] >= RATE_WINDOW_S:
			_clients.erase(ip)


func _free_room(room: Room) -> void:
	if room.join != null:
		room.join.close()
	for slot in room.slots:
		if slot.host_side != null:
			slot.host_side.close()
		slot.host_ip = ""
		slot.joiner_ip = ""
	room.slots.clear()


## A data socket on the relay's bind address: a port from the data range, or one the system
## picks. Null when none is free.
func _data_socket() -> PacketPeerUDP:
	var first: int = config.get("data_first", 0)
	var last: int = config.get("data_last", 0)
	if first == 0:
		var any := PacketPeerUDP.new()
		return any if any.bind(0, config["bind"]) == OK else null
	for i in last - first + 1:
		var port := first + (_next_port - first + i) % (last - first + 1)
		var udp := PacketPeerUDP.new()
		if udp.bind(port, config["bind"]) == OK:
			_next_port = port + 1
			return udp
	return null
