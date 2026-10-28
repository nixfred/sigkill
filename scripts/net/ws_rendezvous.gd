extends "res://scripts/net/rendezvous_client.gd"
## WsRendezvous (C16d): the game's client for a SIGKILL relay over WebSocket (relay/relay_ws.gd,
## docs/RELAY.md), made only when the player's relay URL is ws:// or wss://. With no relay URL
## the game uses NullRendezvous and this file is never touched.
##
## One WebSocket link to the relay, opened on the first request, never before: the same
## wire-2 requests and replies as UdpRendezvous (scripts/net/relay_wire.gd), each one message,
## with the cookie round trip handled here. wss:// is TLS with the engine's own certificate
## checks, which the proxy in front of the relay answers; ws:// is plain.
##
## The match itself still runs on the game's own ENet, unchanged: this client is a tunnel for
## its datagrams. Answers point the session at loopback sockets this client holds, bound to
## 127.0.0.1 only. A joiner's ENet connects to the "mouth" (the answer's address and port), and
## a host's ENet probes one loopback socket per joiner slot (the answer's host ports), exactly
## as they would the UDP relay's ports. Every datagram arriving there goes to the relay as a
## data message, the session's probes as the relay's probes; every data message from the relay
## comes out of the matching loopback socket to the game's ENet. A loopback socket takes
## datagrams from one source only: the game's own ENet socket, learned from its first probe.
## pump() moves it all, once a frame; end_tunnel() closes the link and every loopback socket.
##
## What goes to the relay, ever: the requests (as UdpRendezvous sends them), the probes the
## session makes, and the game's ENet datagrams. No name, path or address.

const Wire = preload("res://scripts/net/relay_wire.gd")
const LOOPBACK := "127.0.0.1"
## Messages waiting for the link to open, at most.
const OUTBOX_LAST := 64
## Longest a closing link is kept to send its close.
const CLOSING_MS := 2000
## How long a closing link stays open after its last message: the engine gives up whatever
## arrives with a close, so the relay must read the last message (a host's close request)
## before the close follows it.
const LINGER_MS := 300
## A message is refused while the link's outbound buffer is half full, so the engine's own
## cap on queued messages is never reached (it would print an error).
const QUEUED_LAST := 16384

## Longest one request may wait for its answer, cookie round trip included.
var timeout_ms := 4000

var _url := ""
var _tls := false
var _host := ""
var _ws: WebSocketPeer = null
var _cookie := Wire.zero_token()
var _requests := 0
## The request in flight: {op, code, protocol, port, started, cookie_tries, sent}, or {}.
var _pending := {}
## The answer to it, once it came: poll() hands it over.
var _answer := {}
var _host_tokens := {}
var _outbox: Array = []
## Links on their way out: {ws, close_at, until (ms), closed}. A link closes only once what it
## holds is sent and LINGER_MS have passed: the engine sends a close ahead of queued messages,
## and the far side gives up any message that arrives with one.
var _closing: Array = []
## The tunnel: a joiner's mouth and the source it takes datagrams from; a host's slot sockets
## (index 0 is slot 1) and theirs.
var _mouth: PacketPeerUDP = null
var _mouth_from := ""
var _slots: Array = []
var _slots_from: Array = []
## Datagrams sent and delivered through the tunnel, and dropped (no room for them).
var tunneled_out := 0
var tunneled_in := 0
var tunnel_dropped := 0


func _init(url: String) -> void:
	var parsed := Wire.parse_ws_url(url)
	if parsed.is_empty():
		return
	_host = parsed["host"]
	_tls = parsed["tls"]
	_url = "%s%s:%d/" % [Wire.WSS_SCHEME if _tls else Wire.WS_SCHEME, _host, parsed["port"]]


func is_live() -> bool:
	return _host != ""


## True for a wss:// relay: TLS, which the proxy in front of the relay terminates.
func uses_tls() -> bool:
	return _tls


## The address answers point the session at: this client's own loopback sockets.
func relay_ip() -> String:
	return LOOPBACK


func register(code: String, protocol: int, port: int) -> bool:
	return _start(Wire.Op.REGISTER, code, protocol, port)


func resolve(code: String, protocol: int) -> bool:
	return _start(Wire.Op.RESOLVE, code, protocol, 0)


## Releases a code this client registered: one request with its host token, no answer. Only
## on a link already open: a room with no link left ends with it at the relay anyway.
func close(code: String, protocol: int, port: int) -> void:
	var token = _host_tokens.get(code)
	_host_tokens.erase(code)
	if token == null or _ws == null:
		return
	if _send(Wire.request_bytes(Wire.Op.CLOSE, code, protocol, port, _cookie, token)):
		_requests += 1


func is_busy() -> bool:
	return not _pending.is_empty()


func cancel() -> void:
	_pending = {}
	_answer = {}


func requests() -> int:
	return _requests


## True while a WebSocket link exists, opening or open (the tests).
func link_open() -> bool:
	return _ws != null


## The loopback sockets this client holds right now (the tests).
func tunnel_sockets() -> Array:
	var out: Array = _slots.duplicate()
	if _mouth != null:
		out.append(_mouth)
	return out


## Everything closed: the request, the link and the tunnel.
func shut() -> void:
	_pending = {}
	_answer = {}
	end_tunnel()


func poll() -> Dictionary:
	_service()
	if _pending.is_empty():
		return {}
	if not _answer.is_empty():
		var done := _answer
		_answer = {}
		_pending = {}
		return done
	if Time.get_ticks_msec() - _pending["started"] > timeout_ms or _ws == null:
		_pending = {}
		return {"ok": false, "error": "timeout"}
	if not _pending["sent"] and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_send_pending()
	return {}


## Once a frame: the link's messages in, the tunnel's datagrams out.
func pump() -> void:
	_service()
	if _mouth != null:
		_drain(_mouth, -1)
	for i in _slots.size():
		_drain(_slots[i], i)
	for going in _closing.duplicate():
		var ws: WebSocketPeer = going["ws"]
		ws.poll()
		var late: bool = Time.get_ticks_msec() >= going["until"]
		var sent: bool = ws.get_current_outbound_buffered_amount() == 0 and Time.get_ticks_msec() >= going["close_at"]
		if not going["closed"] and (sent or late):
			ws.close()
			going["closed"] = true
		if ws.get_ready_state() == WebSocketPeer.STATE_CLOSED or late:
			_closing.erase(going)


## Closes the link (once what it holds is sent, then its close) and every loopback socket.
func end_tunnel() -> void:
	if _ws != null:
		if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			_ws.poll()
			_closing.append({"ws": _ws, "close_at": Time.get_ticks_msec() + LINGER_MS, "until": Time.get_ticks_msec() + CLOSING_MS, "closed": false})
		elif _ws.get_ready_state() == WebSocketPeer.STATE_CONNECTING:
			_ws.close()
		_ws = null
	_outbox.clear()
	if _mouth != null:
		_mouth.close()
		_mouth = null
	_mouth_from = ""
	for udp in _slots:
		udp.close()
	_slots.clear()
	_slots_from.clear()


func _start(op: int, code: String, protocol: int, port: int) -> bool:
	if not _pending.is_empty() or _host == "":
		return false
	if _ws == null and not _open():
		return false
	_pending = {"op": op, "code": code, "protocol": protocol, "port": port, "started": Time.get_ticks_msec(), "cookie_tries": 0, "sent": false}
	_answer = {}
	return true


## The link to the relay, and only to it: the URL the player set.
func _open() -> bool:
	_ws = WebSocketPeer.new()
	_ws.max_queued_packets = QUEUED_LAST
	var opened := _ws.connect_to_url(_url, TLSOptions.client()) if _tls else _ws.connect_to_url(_url)
	if opened != OK:
		_ws = null
		return false
	return true


func _send_pending() -> void:
	_pending["sent"] = true
	if _send(Wire.request_bytes(_pending["op"], _pending["code"], _pending["protocol"], _pending["port"], _cookie, Wire.zero_token())):
		_requests += 1


## One message to the relay: at once on an open link with room for it, held while the link
## opens (a few at most), else dropped. False when it was dropped.
func _send(data: PackedByteArray) -> bool:
	if _ws == null:
		return false
	var state := _ws.get_ready_state()
	if state == WebSocketPeer.STATE_CONNECTING:
		if _outbox.size() >= OUTBOX_LAST:
			return false
		_outbox.append(data)
		return true
	if state != WebSocketPeer.STATE_OPEN or _ws.get_current_outbound_buffered_amount() + data.size() > _ws.outbound_buffer_size / 2:
		return false
	return _ws.put_packet(data) == OK


## The link's state and messages: answers to the request, datagrams for the tunnel.
func _service() -> void:
	if _ws == null:
		return
	_ws.poll()
	var state := _ws.get_ready_state()
	if state == WebSocketPeer.STATE_CLOSED:
		_ws = null
		_outbox.clear()
		return
	if state != WebSocketPeer.STATE_OPEN:
		return
	for data in _outbox:
		_send(data)
	_outbox.clear()
	while _ws != null and _ws.get_available_packet_count() > 0:
		var data := _ws.get_packet()
		if _ws.was_string_packet():
			continue
		var frame := Wire.parse_data(data)
		if not frame.is_empty():
			_deliver(frame["slot"], frame["payload"])
			continue
		_on_reply(Wire.parse_reply(data))


func _on_reply(reply: Dictionary) -> void:
	if reply.is_empty() or _pending.is_empty() or not _answer.is_empty() or reply["code"] != _pending["code"]:
		return
	match reply["status"]:
		Wire.Status.COOKIE:
			if _pending["cookie_tries"] >= 1:
				_answer = {"ok": false, "error": "bad_reply"}
				return
			_pending["cookie_tries"] += 1
			_cookie = reply["token"]
			_send_pending()
		Wire.Status.OK:
			var done := {"ok": true, "error": "", "address": LOOPBACK, "expires_in_s": reply["left_s"], "host_protocol": reply["host_protocol"], "relay": true, "token": reply["token"]}
			if _pending["op"] == Wire.Op.REGISTER:
				var ports := _host_side(reply["ports"])
				if ports.is_empty():
					_answer = {"ok": false, "error": "bad_reply"}
					return
				done["port"] = 0
				done["host_ports"] = ports
				_host_tokens[_pending["code"]] = reply["token"]
			else:
				var mouth := _join_side()
				if mouth == 0:
					_answer = {"ok": false, "error": "bad_reply"}
					return
				done["port"] = mouth
			_answer = done
		_:
			_answer = {"ok": false, "error": Wire.STATUS_WORDS[reply["status"]], "host_protocol": reply["host_protocol"]}


## A host's tunnel: one loopback socket per joiner slot the relay named (kept when the room
## gets a fresh code), and their ports for the session's probes. Empty when it cannot be made.
func _host_side(slots: PackedInt32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	if slots.is_empty() or slots.size() > Wire.SLOT_LAST:
		return out
	for i in slots.size():
		if slots[i] != i + 1:
			return out
	if _slots.size() != slots.size():
		for udp in _slots:
			udp.close()
		_slots.clear()
		_slots_from.clear()
		for i in slots.size():
			var udp := _loopback()
			if udp == null:
				for made in _slots:
					made.close()
				_slots.clear()
				_slots_from.clear()
				return out
			_slots.append(udp)
			_slots_from.append("")
	for udp in _slots:
		out.append(udp.get_local_port())
	return out


## A joiner's tunnel: the mouth its ENet connects to. Its port, or 0.
func _join_side() -> int:
	if _mouth == null:
		_mouth = _loopback()
		_mouth_from = ""
	return _mouth.get_local_port() if _mouth != null else 0


static func _loopback() -> PacketPeerUDP:
	var udp := PacketPeerUDP.new()
	return udp if udp.bind(0, LOOPBACK) == OK else null


## What the game's ENet sent to one loopback socket (`slot` -1: the mouth), to the relay: its
## probes as probes, everything else as data for that slot. Only from the first source seen.
func _drain(udp: PacketPeerUDP, slot: int) -> void:
	while udp.get_available_packet_count() > 0:
		var data := udp.get_packet()
		var from := "%s:%d" % [udp.get_packet_ip(), udp.get_packet_port()]
		if udp.get_packet_ip() != LOOPBACK:
			tunnel_dropped += 1
			continue
		var known: String = _mouth_from if slot < 0 else _slots_from[slot]
		if known == "":
			if slot < 0:
				_mouth_from = from
			else:
				_slots_from[slot] = from
			udp.set_dest_address(LOOPBACK, udp.get_packet_port())
		elif from != known:
			tunnel_dropped += 1
			continue
		var out := data if not Wire.parse_probe(data).is_empty() else Wire.data_bytes(slot + 1 if slot >= 0 else 0, data)
		if _send(out):
			tunneled_out += 1
		else:
			tunnel_dropped += 1


## A datagram from the relay, out of the matching loopback socket to the game's ENet.
func _deliver(slot: int, payload: PackedByteArray) -> void:
	var udp: PacketPeerUDP = null
	var known := ""
	if slot == 0 and _mouth != null:
		udp = _mouth
		known = _mouth_from
	elif slot >= 1 and slot <= _slots.size():
		udp = _slots[slot - 1]
		known = _slots_from[slot - 1]
	if udp == null or known == "" or payload.is_empty():
		tunnel_dropped += 1
		return
	if udp.put_packet(payload) == OK:
		tunneled_in += 1
	else:
		tunnel_dropped += 1
