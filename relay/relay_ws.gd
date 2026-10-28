extends "res://relay/relay_server.gd"
## The SIGKILL relay's WebSocket transport (C16d, docs/RELAY.md), for a machine with no public
## address and no inbound UDP, reached only through an HTTPS proxy on one TCP port: the relay
## speaks plain ws:// on that port, and wss:// is the proxy's TLS in front of it.
## relay/relay_main.gd runs it in place of the UDP relay when --ws-port names a port.
##
## The rules are the UDP relay's own: this extends relay/relay_server.gd and keeps its control
## path whole. The same wire-2 requests and replies (each one WebSocket message), the same
## cookie round trip (on the connection's own address and port), the same registrations and
## resolutions a minute and live rooms per address, rooms in all, players per room, a code's
## life and its time as "expired", payload cap, packets a second per room and idle expiry.
## What changes is the transport. There are no data ports: a connection that registers a code
## is that room's host link, a connection that probes with a room's join token takes one of
## its joiner slots, and rooms are told apart by their tokens. A datagram from a joiner goes to
## its room's host tagged with the joiner's slot; one from the host goes to the slot it names
## (scripts/net/relay_wire.gd, data messages). A host link that registers again (the game draws
## a fresh code when its code runs out) keeps its room and joiners under the new code and
## tokens, and the old code answers "expired".
##
## On top: connections at once (the --sources setting), the WebSocket handshake done within
## HANDSHAKE_S, a connection silent for idle_s closed, a room ended when its host link closes
## (its joiners' links closed with it), a slot freed when its joiner's link closes, a joiner
## link joining one room only, and a message a link's outbound buffer cannot take dropped and
## counted, never queued without end.
##
## Addresses: a connection's address and port live in memory only while it is open (the
## cookie and the per-address limits need them), as the UDP relay keeps them. Behind a proxy
## every connection comes from the proxy, so the per-address limits count all players
## together there. Only aggregate counters are ever printed.

## Longest a connection may take to finish its WebSocket handshake.
const HANDSHAKE_S := 5.0
## Longest a closing connection is kept to send its close.
const CLOSING_S := 2.0
## Messages a link may hold for sending; a message is refused while the buffer is half full,
## so this count is never reached (Godot would print an error) even with the smallest one.
const QUEUED_LAST := 16384
const WS_COUNTERS := ["connections", "closed_idle", "dropped_backlog"]


## One WebSocket connection: its address while it is open, and what it is to a room.
class Link:
	var ws: WebSocketPeer
	var ip := ""
	var port := 0
	var since := 0.0
	var last_seen := 0.0
	var open := false
	## The room this link hosts, or the room it joined and its slot (1 up).
	var hosting = null
	var joined = null
	var slot := 0


class WsRoom extends Room:
	## The host's link, and per joiner slot (index 0 is slot 1) the joiner's link or null.
	var host = null
	var links: Array = []


var _tcp: TCPServer
var _links: Array = []
var _closing: Array = []  # [WebSocketPeer, until]
## The link whose control request is being answered: _reply() goes to it.
var _replying = null


func _init(settings: Dictionary) -> void:
	super(settings)
	for name in WS_COUNTERS:
		counters[name] = 0


## Opens the one TCP port. "" when it is up, else why not.
func start() -> String:
	_tcp = TCPServer.new()
	if _tcp.listen(config["ws_port"], config["bind"]) != OK:
		_tcp = null
		return "could not open TCP port %d" % config["ws_port"]
	return ""


## The port actually open, or 0.
func control_port() -> int:
	return _tcp.get_local_port() if _tcp != null else 0


## Links open or opening right now (the tests).
func links_open() -> int:
	return _links.size()


func stop() -> void:
	for link in _links.duplicate():
		_drop_link(link)
	for pair in _closing:
		pair[0].close()
	_closing.clear()
	_all.clear()
	_rooms.clear()
	_expired.clear()
	_clients.clear()
	if _tcp != null:
		_tcp.stop()
		_tcp = null


func stats_line() -> String:
	var line := super()
	for name in WS_COUNTERS:
		line += ", %s %d" % [name, counters[name]]
	return line + ", links %d" % _links.size()


func poll(now: float) -> void:
	if _tcp == null:
		return
	_now = now
	while _tcp.is_connection_available():
		_accept(_tcp.take_connection(), now)
	for link in _links.duplicate():
		if _links.has(link):
			_poll_link(link, now)
	for pair in _closing.duplicate():
		pair[0].poll()
		if pair[0].get_ready_state() == WebSocketPeer.STATE_CLOSED or now >= pair[1]:
			_closing.erase(pair)
	if now >= _housekeeping_at:
		_housekeeping_at = now + HOUSEKEEPING_S
		_housekeeping(now)


func _accept(tcp: StreamPeerTCP, now: float) -> void:
	if _links.size() >= config["max_clients"]:
		counters["busy"] += 1
		tcp.disconnect_from_host()
		return
	var link := Link.new()
	link.ws = WebSocketPeer.new()
	link.ws.max_queued_packets = QUEUED_LAST
	link.ip = tcp.get_connected_host()
	link.port = tcp.get_connected_port()
	link.since = now
	link.last_seen = now
	if link.ws.accept_stream(tcp) != OK:
		counters["dropped_bad"] += 1
		return
	_links.append(link)
	counters["connections"] += 1


## A link's messages first, its state after: what a closing link sent before its close (a
## host's close request, say) still counts.
func _poll_link(link: Link, now: float) -> void:
	link.ws.poll()
	var state := link.ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		link.open = true
	while _links.has(link) and link.ws.get_available_packet_count() > 0:
		var data := link.ws.get_packet()
		link.last_seen = now
		if link.ws.was_string_packet():
			counters["dropped_bad"] += 1
			continue
		_on_message(link, data, now)
	if _links.has(link) and (state == WebSocketPeer.STATE_CLOSED or state == WebSocketPeer.STATE_CLOSING):
		_drop_link(link)


## One message from a link: a control request, a probe or a datagram; anything else dropped.
func _on_message(link: Link, data: PackedByteArray, now: float) -> void:
	if data.size() >= 2 and data[0] == Wire.MAGIC_CONTROL[0] and data[1] == Wire.MAGIC_CONTROL[1]:
		_replying = link
		_on_control(data, link.ip, link.port, now)
		_replying = null
		return
	var probe := Wire.parse_probe(data)
	if not probe.is_empty():
		_on_probe(link, probe, now)
		return
	var frame := Wire.parse_data(data)
	if frame.is_empty():
		counters["dropped_bad"] += 1
		return
	_on_data(link, frame, now)


## A host probe keeps its room's link fresh; a join probe with a room's join token takes a
## free slot of that room for this link (one room per link, never the host's own).
func _on_probe(link: Link, probe: Dictionary, now: float) -> void:
	if probe["kind"] == Wire.Probe.HOST:
		if link.hosting == null or probe["token"] != link.hosting.host_token:
			counters["dropped_bad"] += 1
			return
		link.hosting.last_active = now
		return
	var room = _room_of(probe["token"])
	if room == null or link.hosting != null or (link.joined != null and link.joined != room):
		counters["dropped_bad"] += 1
		return
	if link.joined == room:
		room.last_active = now
		return
	var free: int = room.links.find(null)
	if free < 0:
		counters["dropped_full"] += 1
		return
	room.links[free] = link
	link.joined = room
	link.slot = free + 1
	room.last_active = now


## A datagram: from a joiner to its host, tagged with the joiner's slot; from the host to the
## joiner on the slot it names. A link in no room, or a slot with no joiner, is dropped.
func _on_data(link: Link, frame: Dictionary, now: float) -> void:
	var payload: PackedByteArray = frame["payload"]
	var room = link.hosting if link.hosting != null else link.joined
	if room == null:
		counters["dropped_unknown_source"] += 1
		return
	var to = null
	var slot := 0
	if link.hosting != null:
		var named: int = frame["slot"]
		to = room.links[named - 1] if named >= 1 and named <= room.links.size() else null
	else:
		to = room.host
		slot = link.slot
	if to == null:
		counters["dropped_unknown_source"] += 1
		return
	if not _payload_ok(payload, room, now):
		return
	room.last_active = now
	if not _send(to, Wire.data_bytes(slot, payload)):
		counters["dropped_backlog"] += 1
		return
	counters["relayed_packets"] += 1
	counters["relayed_bytes"] += payload.size()


## The room whose join token is `token`, or null.
func _room_of(token: PackedByteArray):
	for room in _all:
		if room.join_token == token:
			return room
	return null


## Puts one message on a link if its outbound buffer has room (less than half full after it);
## false, nothing sent, when it has not.
func _send(link: Link, data: PackedByteArray) -> bool:
	if link.ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return false
	if link.ws.get_current_outbound_buffered_amount() + data.size() > link.ws.outbound_buffer_size / 2:
		return false
	return link.ws.put_packet(data) == OK


# --- The control path's transport: what the UDP relay does with ports. ---

func _reply(_ip: String, _port: int, status: int, code: String, protocol: int = 0, join_port: int = 0, left_s: int = 0, token: PackedByteArray = PackedByteArray(), ports: PackedInt32Array = PackedInt32Array()) -> void:
	if _replying != null and not _send(_replying, Wire.reply_bytes(status, code, protocol, join_port, left_s, token, ports)):
		counters["dropped_backlog"] += 1


## A code for the link's own room: a new room with one slot per joiner, or, for a link that
## already hosts one, the same room under the new code and fresh tokens. Join port 0, and the
## slots named 1 to N-1 where the UDP relay names ports.
func _register(req: Dictionary, ip: String, port: int, now: float) -> void:
	var link = _replying
	var code: String = req["code"]
	if _rooms.has(code) and _rooms[code].live(now):
		counters["taken"] += 1
		_reply(ip, port, Wire.Status.TAKEN, code)
		return
	if link == null or link.joined != null:
		counters["busy"] += 1
		_reply(ip, port, Wire.Status.BUSY, code)
		return
	var room = link.hosting
	if room != null:
		if room.code != "":
			_end_code(room)
	else:
		var owned := 0
		for other in _rooms.values():
			if other.owner == ip and other.live(now):
				owned += 1
		if _all.size() >= config["max_rooms"] or owned >= config["rooms_per_ip"]:
			counters["busy"] += 1
			_reply(ip, port, Wire.Status.BUSY, code)
			return
		room = WsRoom.new()
		room.host = link
		room.links.resize(config["max_players"] - 1)
		link.hosting = room
		_all.append(room)
	room.code = code
	room.protocol = req["protocol"]
	room.owner = ip
	room.code_until = now + config["room_ttl_s"]
	room.host_token = _crypto.generate_random_bytes(Wire.TOKEN_SIZE)
	room.join_token = _crypto.generate_random_bytes(Wire.TOKEN_SIZE)
	room.last_active = now
	_rooms[code] = room
	_expired.erase(code)
	counters["registered"] += 1
	counters["rooms_peak"] = maxi(counters["rooms_peak"], _all.size())
	var slots := PackedInt32Array()
	for i in room.links.size():
		slots.append(i + 1)
	_reply(ip, port, Wire.Status.OK, code, room.protocol, 0, config["room_ttl_s"], room.host_token, slots)


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
	_reply(ip, port, Wire.Status.OK, code, room.protocol, 0, int(ceil(room.code_until - now)), room.join_token)


func _free_room(room: Room) -> void:
	if room is WsRoom:
		room.host = null
		room.links.clear()


# --- Time. ---

func _housekeeping(now: float) -> void:
	for code in _rooms.keys():
		if now >= _rooms[code].code_until:
			_end_code(_rooms[code])
	for link in _links.duplicate():
		var waited: bool = not link.open and now - link.since >= HANDSHAKE_S
		if waited or (link.open and now - link.last_seen >= config["idle_s"]):
			counters["closed_idle"] += 1
			_drop_link(link)
	for code in _expired.keys():
		if now >= _expired[code]:
			_expired.erase(code)
	for ip in _clients.keys():
		if now - _clients[ip]["since"] >= RATE_WINDOW_S:
			_clients.erase(ip)


## Closes a link and forgets its address. A host link takes its room with it: the code
## answers "expired" and every joiner's link closes too. A joiner's slot comes free.
func _drop_link(link: Link) -> void:
	_links.erase(link)
	if link.ws.get_ready_state() == WebSocketPeer.STATE_OPEN or link.ws.get_ready_state() == WebSocketPeer.STATE_CONNECTING:
		link.ws.close()
		_closing.append([link.ws, _now + CLOSING_S])
	var room = link.hosting
	if room != null:
		link.hosting = null
		if room.code != "":
			_end_code(room)
		for other in room.links:
			if other != null:
				other.joined = null
				_drop_link(other)
		_free_room(room)
		_all.erase(room)
	if link.joined != null:
		var at: int = link.joined.links.find(link)
		if at >= 0:
			link.joined.links[at] = null
		link.joined = null
	link.ip = ""
	link.port = 0
