extends "res://scripts/net/rendezvous_client.gd"
## UdpRendezvous (C16c): the game's client for a SIGKILL relay (relay/relay_server.gd,
## docs/RELAY.md), made only when the player has set a relay URL (udp://host[:port]) in the
## settings. With none set the game uses NullRendezvous and this file is never touched.
##
## What it sends, ever: the wire-2 requests of scripts/net/relay_wire.gd, to the relay's
## control port only: register, resolve or close, the room code, the protocol version, the
## host's game port, the cookie the relay handed out, and for close the room's host token.
## No name, path, address or player data. A host name in the URL is looked up without
## blocking the game; the socket opens on the first request, not before, and only to the
## relay's own address: a reply from anywhere else is ignored.
##
## The cookie round trip is handled here: the relay answers a first request with a cookie
## and the same request goes again with it, so the session sees one request and one answer.
## Answers carry what the session needs to go through the relay: {ok, error, address (the
## relay's own, never a player's), port (the room's join port), expires_in_s, host_protocol,
## relay: true, token (host token or join token), host_ports (register only)}.

const Wire = preload("res://scripts/net/relay_wire.gd")

## Longest one request may wait for its answer, cookie round trip included.
var timeout_ms := 4000

var _host := ""
var _port := 0
var _ip := ""
var _lookup := -1
var _lookup_failed := false
var _udp: PacketPeerUDP = null
var _cookie := Wire.zero_token()
var _requests := 0
## The request in flight: {op, code, protocol, port, started, cookie_tries}, or {}.
var _pending := {}
## Host tokens of the codes this client registered, for close().
var _host_tokens := {}


func _init(url: String) -> void:
	var parsed := Wire.parse_url(url)
	_host = parsed.get("host", "")
	_port = parsed.get("port", 0)
	if _host.is_valid_ip_address():
		_ip = _host


func is_live() -> bool:
	return _host != ""


## The relay's address once it is known (a host name is looked up first), or "".
func relay_ip() -> String:
	return _ip


func register(code: String, protocol: int, port: int) -> bool:
	return _start(Wire.Op.REGISTER, code, protocol, port)


func resolve(code: String, protocol: int) -> bool:
	return _start(Wire.Op.RESOLVE, code, protocol, 0)


## Releases a code this client registered: one request with its host token, no answer.
func close(code: String, protocol: int, port: int) -> void:
	var token = _host_tokens.get(code)
	_host_tokens.erase(code)
	if token == null or not _socket():
		return
	_send(Wire.request_bytes(Wire.Op.CLOSE, code, protocol, port, _cookie, token))


func is_busy() -> bool:
	return not _pending.is_empty()


func cancel() -> void:
	_pending = {}


func requests() -> int:
	return _requests


## Closes the socket, if one was ever opened.
func shut() -> void:
	_pending = {}
	if _udp != null:
		_udp.close()
		_udp = null
	if _lookup >= 0:
		IP.erase_resolve_item(_lookup)
		_lookup = -1


func poll() -> Dictionary:
	if _pending.is_empty():
		_drain()
		return {}
	if Time.get_ticks_msec() - _pending["started"] > timeout_ms:
		_pending = {}
		return {"ok": false, "error": "timeout"}
	if _ip == "":
		_poll_lookup()
		if _lookup_failed:
			_pending = {}
			return {"ok": false, "error": "timeout"}
		if _ip == "":
			return {}
	if not _pending.get("sent", false):
		if not _socket():
			_pending = {}
			return {"ok": false, "error": "timeout"}
		_send_pending()
	while _udp.get_available_packet_count() > 0:
		var data := _udp.get_packet()
		if _udp.get_packet_ip() != _ip or _udp.get_packet_port() != _port:
			continue  # only the relay answers
		var reply := Wire.parse_reply(data)
		if reply.is_empty() or reply["code"] != _pending["code"]:
			continue
		match reply["status"]:
			Wire.Status.COOKIE:
				if _pending["cookie_tries"] >= 1:
					_pending = {}
					return {"ok": false, "error": "bad_reply"}
				_pending["cookie_tries"] += 1
				_cookie = reply["token"]
				_send_pending()
			Wire.Status.OK:
				var done := {"ok": true, "error": "", "address": _ip, "port": reply["join_port"], "expires_in_s": reply["left_s"], "host_protocol": reply["host_protocol"], "relay": true, "token": reply["token"]}
				if _pending["op"] == Wire.Op.REGISTER:
					done["host_ports"] = reply["ports"]
					_host_tokens[_pending["code"]] = reply["token"]
				_pending = {}
				return done
			_:
				_pending = {}
				return {"ok": false, "error": Wire.STATUS_WORDS[reply["status"]], "host_protocol": reply["host_protocol"]}
	return {}


func _start(op: int, code: String, protocol: int, port: int) -> bool:
	if not _pending.is_empty() or _host == "":
		return false
	_pending = {"op": op, "code": code, "protocol": protocol, "port": port, "started": Time.get_ticks_msec(), "cookie_tries": 0, "sent": false}
	if _ip == "" and _lookup < 0 and not _lookup_failed:
		_lookup = IP.resolve_hostname_queue_item(_host, IP.TYPE_IPV4)
	return true


func _send_pending() -> void:
	_pending["sent"] = true
	_send(Wire.request_bytes(_pending["op"], _pending["code"], _pending["protocol"], _pending["port"], _cookie, Wire.zero_token()))


func _send(data: PackedByteArray) -> void:
	if _udp.put_packet(data) == OK:
		_requests += 1


func _socket() -> bool:
	if _udp != null:
		return true
	if _ip == "":
		return false
	_udp = PacketPeerUDP.new()
	if _udp.bind(0) != OK:
		_udp = null
		return false
	_udp.set_dest_address(_ip, _port)
	return true


func _poll_lookup() -> void:
	if _lookup < 0:
		return
	match IP.get_resolve_item_status(_lookup):
		IP.RESOLVER_STATUS_DONE:
			var found := IP.get_resolve_item_address(_lookup)
			IP.erase_resolve_item(_lookup)
			_lookup = -1
			if found.is_valid_ip_address():
				_ip = found
			else:
				_lookup_failed = true
		IP.RESOLVER_STATUS_ERROR, IP.RESOLVER_STATUS_NONE:
			IP.erase_resolve_item(_lookup)
			_lookup = -1
			_lookup_failed = true


## Late answers to a request given up on: read and dropped.
func _drain() -> void:
	if _udp == null:
		return
	while _udp.get_available_packet_count() > 0:
		_udp.get_packet()
