class_name RoomTuning
extends Resource
## Every number of room codes (C15, scripts/net/net_session.gd): which rendezvous to use,
## how long a code lives, how long a request may take and how often a taken code is
## redrawn. The default instance is resources/room.tres. Units are seconds, milliseconds
## and attempts.

@export_group("Rendezvous")
## The SIGKILL relay for room codes, udp://<host>[:<port>] (C16c, docs/RELAY.md), or ws:// or
## wss://<host>[:<port>] for its WebSocket transport (C16d). Empty, the default, means
## NullRendezvous: no online rooms and no network call. The player's own relay URL, in the
## settings' Multiplayer section, comes first when one is set.
@export var relay_url: String = ""

@export_group("Codes")
## Longest a room code lives. A host shows its code for at most this long, then registers
## a fresh one; the rendezvous may give less, never more.
@export var code_ttl_s: int = 600
## Longest one rendezvous request may take before it is given up.
@export var request_timeout_ms: int = 4000
## Codes drawn, in all, when the rendezvous answers that a code is taken.
@export var register_attempts: int = 5

const RelayWire = preload("res://scripts/net/relay_wire.gd")
const URL_LAST := RelayWire.URL_LAST
const TTL_FIRST_S := 30
const TTL_LAST_S := 86400
const TIMEOUT_FIRST_MS := 500
const TIMEOUT_LAST_MS := 30000
const ATTEMPTS_LAST := 20


## True for an empty relay_url, or udp://, ws:// or wss://<IPv4 address or host name>[:<port>].
static func url_ok(url: String) -> bool:
	return RelayWire.url_ok(url)


## Everything wrong with these values, or empty when they are safe to use.
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	if not url_ok(relay_url):
		out.append("relay_url must be empty or udp://, ws:// or wss://<host>[:<port>], at most %d characters" % URL_LAST)
	if code_ttl_s < TTL_FIRST_S or code_ttl_s > TTL_LAST_S:
		out.append("code_ttl_s must be between %d and %d" % [TTL_FIRST_S, TTL_LAST_S])
	if request_timeout_ms < TIMEOUT_FIRST_MS or request_timeout_ms > TIMEOUT_LAST_MS:
		out.append("request_timeout_ms must be between %d and %d" % [TIMEOUT_FIRST_MS, TIMEOUT_LAST_MS])
	if register_attempts < 1 or register_attempts > ATTEMPTS_LAST:
		out.append("register_attempts must be between 1 and %d" % ATTEMPTS_LAST)
	return out
