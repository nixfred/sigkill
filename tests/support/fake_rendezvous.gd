extends RefCounted
## A fake rendezvous for the room tests (C15), test-only: a server node and a client, both
## in this one process on 127.0.0.1, speaking the wire format docs/RELAY.md describes. The
## game never uses this file; its only rendezvous is NullRendezvous.
##
## Request, 14 bytes, fixed: "SR", wire version 1, op (1 register, 2 resolve, 3 close),
## the 6-character code in ASCII, the protocol version (u16), the game port (u16, 0 when
## resolving). Nothing else fits in it.
## Reply: "SR", 1, status (0 ok, 1 unknown, 2 expired, 3 version, 4 taken, 5 busy), the code,
## the host's protocol (u16), the port (u16), seconds left (u32), then the address as the
## rendezvous saw it (u8 length, ASCII).

const RendezvousClient = preload("res://scripts/net/rendezvous_client.gd")

const MAGIC := [0x53, 0x52]
const WIRE := 1
const REQUEST_SIZE := 14
const REPLY_HEAD := 19
enum Op { REGISTER = 1, RESOLVE = 2, CLOSE = 3 }
enum Status { OK, UNKNOWN, EXPIRED, VERSION, TAKEN, BUSY }
const STATUS_WORDS := ["", "unknown", "expired", "version", "taken", "busy"]
const LOCALHOST := "127.0.0.1"


## The wire format, shared by the server and the client.
class Codec:
	static func request_bytes(op: int, code: String, protocol: int, port: int) -> PackedByteArray:
		var out := PackedByteArray([MAGIC[0], MAGIC[1], WIRE, op])
		out.append_array(code.to_ascii_buffer())
		out.resize(REQUEST_SIZE)
		out.encode_u16(10, protocol)
		out.encode_u16(12, port)
		return out


	static func parse_request(data: PackedByteArray) -> Dictionary:
		if data.size() != REQUEST_SIZE or data[0] != MAGIC[0] or data[1] != MAGIC[1] or data[2] != WIRE:
			return {}
		var op := data[3]
		if op < Op.REGISTER or op > Op.CLOSE:
			return {}
		return {"op": op, "code": data.slice(4, 10).get_string_from_ascii(), "protocol": data.decode_u16(10), "port": data.decode_u16(12)}


	static func reply_bytes(status: int, code: String, host_protocol: int, port: int, left_s: int, address: String) -> PackedByteArray:
		var out := PackedByteArray([MAGIC[0], MAGIC[1], WIRE, status])
		out.append_array(code.to_ascii_buffer())
		out.resize(REPLY_HEAD)
		out.encode_u16(10, host_protocol)
		out.encode_u16(12, port)
		out.encode_u32(14, left_s)
		out.encode_u8(18, address.length())
		out.append_array(address.to_ascii_buffer())
		return out


	static func parse_reply(data: PackedByteArray) -> Dictionary:
		if data.size() < REPLY_HEAD or data[0] != MAGIC[0] or data[1] != MAGIC[1] or data[2] != WIRE:
			return {}
		var n := data.decode_u8(18)
		if data.size() != REPLY_HEAD + n or data[3] >= STATUS_WORDS.size():
			return {}
		return {"status": data[3], "code": data.slice(4, 10).get_string_from_ascii(), "host_protocol": data.decode_u16(10), "port": data.decode_u16(12), "left_s": data.decode_u32(14), "address": data.slice(REPLY_HEAD).get_string_from_ascii()}


## The fake service: one UDP socket on 127.0.0.1, a table of rooms, a log of every request
## exactly as decoded, and knobs for the failure cases.
class Server:
	extends Node
	var ttl_s := 600
	## Seconds added to the clock, so a test can make codes expire.
	var clock_offset_s := 0.0
	## Answers every request with "busy", or answers nothing at all.
	var busy := false
	var silent := false
	## The next this many registrations are answered "taken".
	var force_taken := 0
	## Requests are carried out but never answered (a lost reply).
	var mute := false
	## A non-negative value replaces the seconds left in every ok reply.
	var left_override := -1
	## Replaces the address in every ok resolve reply, when set.
	var address_override := ""
	var rooms := {}
	## Every request: {op, code, protocol, port, from, size}.
	var log: Array = []
	var _udp := PacketPeerUDP.new()

	func listen() -> int:
		if _udp.bind(0, LOCALHOST) != OK:
			return 0
		return _udp.get_local_port()

	func now_s() -> float:
		return Time.get_ticks_msec() / 1000.0 + clock_offset_s

	func _process(_delta: float) -> void:
		while _udp.get_available_packet_count() > 0:
			var data := _udp.get_packet()
			var from_ip := _udp.get_packet_ip()
			var from_port := _udp.get_packet_port()
			var req := Codec.parse_request(data)
			if req.is_empty():
				continue
			log.append({"op": req["op"], "code": req["code"], "protocol": req["protocol"], "port": req["port"], "from": from_ip, "size": data.size()})
			if silent:
				continue
			var reply := _answer(req, from_ip, from_port)
			if reply.is_empty() or mute:
				continue
			_udp.set_dest_address(from_ip, from_port)
			_udp.put_packet(reply)

	func _answer(req: Dictionary, from_ip: String, from_port: int) -> PackedByteArray:
		var code: String = req["code"]
		if busy:
			return Codec.reply_bytes(Status.BUSY, code, 0, 0, 0, "")
		var room = rooms.get(code)
		var live: bool = room != null and room["until"] > now_s()
		match req["op"]:
			Op.REGISTER:
				if force_taken > 0:
					force_taken -= 1
					return Codec.reply_bytes(Status.TAKEN, code, 0, 0, 0, "")
				if live:
					return Codec.reply_bytes(Status.TAKEN, code, 0, 0, 0, "")
				rooms[code] = {"address": from_ip, "port": req["port"], "protocol": req["protocol"], "until": now_s() + ttl_s, "owner": "%s:%d" % [from_ip, from_port]}
				return Codec.reply_bytes(Status.OK, code, req["protocol"], req["port"], left_override if left_override >= 0 else ttl_s, from_ip)
			Op.RESOLVE:
				if room == null:
					return Codec.reply_bytes(Status.UNKNOWN, code, 0, 0, 0, "")
				if not live:
					return Codec.reply_bytes(Status.EXPIRED, code, 0, 0, 0, "")
				if room["protocol"] != req["protocol"]:
					return Codec.reply_bytes(Status.VERSION, code, room["protocol"], 0, 0, "")
				return Codec.reply_bytes(Status.OK, code, room["protocol"], room["port"], int(room["until"] - now_s()), address_override if address_override != "" else room["address"])
			Op.CLOSE:
				if room != null and room["owner"] == "%s:%d" % [from_ip, from_port]:
					rooms.erase(code)
		return PackedByteArray()

	func _exit_tree() -> void:
		_udp.close()


## The fake client: the session's RendezvousClient in the tests.
class Client:
	extends "res://scripts/net/rendezvous_client.gd"
	var timeout_ms := 4000
	var sent: Array = []
	## Replies that came from anywhere but the server, ignored.
	var strays := 0
	var _udp := PacketPeerUDP.new()
	var _server_port := 0
	var _pending := ""
	var _code := ""
	var _started := 0
	var _requests := 0

	func _init(server_port: int) -> void:
		_server_port = server_port
		_udp.bind(0, LOCALHOST)
		_udp.set_dest_address(LOCALHOST, server_port)

	func is_live() -> bool:
		return true

	func register(code: String, protocol: int, port: int) -> bool:
		return _send(Op.REGISTER, code, protocol, port, "register")

	func resolve(code: String, protocol: int) -> bool:
		return _send(Op.RESOLVE, code, protocol, 0, "resolve")

	func close(code: String, protocol: int, port: int) -> void:
		var data := Codec.request_bytes(Op.CLOSE, code, protocol, port)
		_udp.put_packet(data)
		sent.append(data)
		_requests += 1

	func is_busy() -> bool:
		return _pending != ""

	func cancel() -> void:
		_pending = ""

	func requests() -> int:
		return _requests

	func poll() -> Dictionary:
		if _pending == "":
			return {}
		while _udp.get_available_packet_count() > 0:
			var data := _udp.get_packet()
			if _udp.get_packet_ip() != LOCALHOST or _udp.get_packet_port() != _server_port:
				strays += 1  # only the server answers
				continue
			var reply := Codec.parse_reply(data)
			if reply.is_empty():
				_pending = ""
				return {"ok": false, "error": "bad_reply"}
			if reply["code"] != _code:
				continue
			_pending = ""
			var status: int = reply["status"]
			if status != Status.OK:
				return {"ok": false, "error": STATUS_WORDS[status], "host_protocol": reply["host_protocol"]}
			return {"ok": true, "error": "", "address": reply["address"], "port": reply["port"], "expires_in_s": reply["left_s"], "host_protocol": reply["host_protocol"]}
		if Time.get_ticks_msec() - _started > timeout_ms:
			_pending = ""
			return {"ok": false, "error": "timeout"}
		return {}

	func _send(op: int, code: String, protocol: int, port: int, kind: String) -> bool:
		if _pending != "":
			return false
		var data := Codec.request_bytes(op, code, protocol, port)
		if _udp.put_packet(data) != OK:
			return false
		sent.append(data)
		_requests += 1
		_pending = kind
		_code = code
		_started = Time.get_ticks_msec()
		return true

	func shut() -> void:
		_udp.close()
