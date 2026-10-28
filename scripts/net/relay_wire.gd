extends RefCounted
## The SIGKILL relay's wire format, version 2 (C16c, docs/RELAY.md), shared by the game's
## client (scripts/net/udp_rendezvous.gd) and the relay itself (relay/relay_server.gd), so
## both always speak the same bytes. Version 1 is the C15 test fake's and stays as it was.
##
## Control, over UDP to the relay's control port.
## Request, exactly REQUEST_SIZE bytes: "SR", wire 2, op (1 register, 2 resolve, 3 close),
## the room code (6 ASCII bytes), the protocol version (u16), the game port (u16; the relay
## learns the real path from the host's probes), the cookie (8 bytes, zero until the relay
## hands one out), the host token (8 bytes, close only), then zeros. A request is never
## shorter than the longest reply, so the relay never sends more bytes than it received.
## Reply, at most REPLY_LAST bytes: "SR", 2, status, the code (echoed, so a late reply is
## never taken for another), the host's protocol (u16), the room's join port (u16), seconds
## left (u32), a token (8 bytes: the cookie, the host token or the join token), and the
## host-facing ports (u8 count, then u16 each). No reply ever holds an address: a joiner
## connects to the relay itself, and neither player learns the other's address.
##
## Data, to a room's own ports on the relay: the game's ENet datagrams, forwarded untouched,
## and a PROBE_SIZE probe, "SP", 2, kind (1 host, 2 join), then the room's token for that
## side, sent from the game's own ENet socket so the relay learns the path it forwards on
## (and the player's NAT opens it).
##
## The relay URL a player sets is udp://<host>[:<port>]: an IPv4 address or a host name, and
## the control port (DEFAULT_PORT when left out). Empty means no relay and no network call.

const WIRE := 2
const REQUEST_SIZE := 64
## Bytes before the host-facing ports in a reply; the longest reply is 27 + 2 * 15 = 57.
const REPLY_HEAD := 27
const REPLY_LAST := 64
const PROBE_SIZE := 12
const TOKEN_SIZE := 8
const CODE_SIZE := 6
## The longest list of host-facing ports a reply can carry: one per joiner slot.
const PORTS_LAST := 15
const DEFAULT_PORT := 9010
const SCHEME := "udp://"
## A relay URL's longest length: it is kept in the settings file, whose strings stop at 64.
const URL_LAST := 64
const HOSTNAME_LAST := 50
const LABEL_LAST := 63
const MAGIC_CONTROL := [0x53, 0x52]  # "SR"
const MAGIC_PROBE := [0x53, 0x50]  # "SP"

enum Op { REGISTER = 1, RESOLVE = 2, CLOSE = 3 }
enum Status { OK, UNKNOWN, EXPIRED, VERSION, TAKEN, BUSY, COOKIE }
enum Probe { HOST = 1, JOIN = 2 }
const STATUS_WORDS := ["", "unknown", "expired", "version", "taken", "busy", "cookie"]


static func zero_token() -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(TOKEN_SIZE)
	out.fill(0)
	return out


static func request_bytes(op: int, code: String, protocol: int, port: int, cookie: PackedByteArray, token: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray([MAGIC_CONTROL[0], MAGIC_CONTROL[1], WIRE, op])
	out.append_array(_fixed(code.to_ascii_buffer(), CODE_SIZE))
	out.resize(REQUEST_SIZE)
	out.encode_u16(10, clampi(protocol, 0, 65535))
	out.encode_u16(12, clampi(port, 0, 65535))
	for i in TOKEN_SIZE:
		out[14 + i] = cookie[i] if i < cookie.size() else 0
		out[22 + i] = token[i] if i < token.size() else 0
	return out


## {op, code, protocol, port, cookie, token} from a request, or {} when it is not one: the
## wrong size, magic, wire version or op, or a code that is not six plain characters.
static func parse_request(data: PackedByteArray) -> Dictionary:
	if data.size() != REQUEST_SIZE or data[0] != MAGIC_CONTROL[0] or data[1] != MAGIC_CONTROL[1] or data[2] != WIRE:
		return {}
	var op := data[3]
	if op < Op.REGISTER or op > Op.CLOSE:
		return {}
	var code := _code_text(data.slice(4, 4 + CODE_SIZE))
	if code == "":
		return {}
	return {"op": op, "code": code, "protocol": data.decode_u16(10), "port": data.decode_u16(12), "cookie": data.slice(14, 22), "token": data.slice(22, 30)}


static func reply_bytes(status: int, code: String, host_protocol: int, join_port: int, left_s: int, token: PackedByteArray, ports: PackedInt32Array) -> PackedByteArray:
	var out := PackedByteArray([MAGIC_CONTROL[0], MAGIC_CONTROL[1], WIRE, status])
	out.append_array(_fixed(code.to_ascii_buffer(), CODE_SIZE))
	out.resize(REPLY_HEAD)
	out.encode_u16(10, clampi(host_protocol, 0, 65535))
	out.encode_u16(12, clampi(join_port, 0, 65535))
	out.encode_u32(14, maxi(left_s, 0))
	for i in TOKEN_SIZE:
		out[18 + i] = token[i] if i < token.size() else 0
	var count := mini(ports.size(), PORTS_LAST)
	out[26] = count
	out.resize(REPLY_HEAD + count * 2)
	for i in count:
		out.encode_u16(27 + i * 2, clampi(ports[i], 0, 65535))
	return out


## {status, code, host_protocol, join_port, left_s, token, ports} from a reply, or {}.
static func parse_reply(data: PackedByteArray) -> Dictionary:
	if data.size() < REPLY_HEAD or data.size() > REPLY_LAST or data[0] != MAGIC_CONTROL[0] or data[1] != MAGIC_CONTROL[1] or data[2] != WIRE:
		return {}
	var status := data[3]
	if status > Status.COOKIE:
		return {}
	var code := _code_text(data.slice(4, 4 + CODE_SIZE))
	var count := data[26]
	if code == "" or count > PORTS_LAST or data.size() != REPLY_HEAD + count * 2:
		return {}
	var ports := PackedInt32Array()
	for i in count:
		ports.append(data.decode_u16(27 + i * 2))
	return {"status": status, "code": code, "host_protocol": data.decode_u16(10), "join_port": data.decode_u16(12), "left_s": data.decode_u32(14), "token": data.slice(18, 26), "ports": ports}


static func probe_bytes(kind: int, token: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray([MAGIC_PROBE[0], MAGIC_PROBE[1], WIRE, kind])
	out.append_array(_fixed(token, TOKEN_SIZE))
	return out


## {kind, token} from a probe, or {} when the datagram is not one.
static func parse_probe(data: PackedByteArray) -> Dictionary:
	if data.size() != PROBE_SIZE or data[0] != MAGIC_PROBE[0] or data[1] != MAGIC_PROBE[1] or data[2] != WIRE:
		return {}
	if data[3] != Probe.HOST and data[3] != Probe.JOIN:
		return {}
	return {"kind": data[3], "token": data.slice(4, PROBE_SIZE)}


## True for an empty relay URL (no relay), or udp://<IPv4 or host name>[:<port>].
static func url_ok(url: String) -> bool:
	return url.is_empty() or not parse_url(url).is_empty()


## {host, port} from a relay URL, or {} when it is empty or not udp://<host>[:<port>].
static func parse_url(url: String) -> Dictionary:
	if url.length() > URL_LAST or not url.begins_with(SCHEME):
		return {}
	var rest := url.substr(SCHEME.length())
	var host := rest
	var port := DEFAULT_PORT
	if rest.count(":") == 1:
		host = rest.get_slice(":", 0)
		var digits := rest.get_slice(":", 1)
		if digits.is_empty() or digits.length() > 5 or not digits.is_valid_int() or digits.begins_with("+") or digits.begins_with("-"):
			return {}
		port = int(digits)
	elif rest.count(":") > 1:
		return {}
	if port < 1 or port > 65535 or host.is_empty():
		return {}
	if host.is_valid_ip_address():
		return {"host": host, "port": port} if not host.contains(":") else {}
	if host.length() > HOSTNAME_LAST:
		return {}
	for label in host.split("."):
		if label.is_empty() or label.length() > LABEL_LAST or label.begins_with("-") or label.ends_with("-"):
			return {}
		for i in label.length():
			var c := label.unicode_at(i)
			var ok := (c >= 0x30 and c <= 0x39) or (c >= 0x41 and c <= 0x5A) or (c >= 0x61 and c <= 0x7A) or c == 0x2D
			if not ok:
				return {}
	return {"host": host, "port": port}


static func _fixed(bytes: PackedByteArray, size: int) -> PackedByteArray:
	var out := bytes.slice(0, size)
	out.resize(size)
	return out


## The code as text when it is exactly six of the code alphabet's characters, else "".
static func _code_text(bytes: PackedByteArray) -> String:
	for b in bytes:
		var digit := b >= 0x32 and b <= 0x39
		var letter := b >= 0x41 and b <= 0x5A
		if not (digit or letter):
			return ""
	return bytes.get_string_from_ascii()
