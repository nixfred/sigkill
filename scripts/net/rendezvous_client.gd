extends RefCounted
## RendezvousClient (C15): the interface the session talks to for room codes. A rendezvous
## holds, for a few minutes, which address and game port a room code points to: the host
## registers its code, a joiner resolves one, and the C13 join path does the rest.
## docs/RELAY.md is the design of the service behind it; none is deployed.
##
## What may go to a rendezvous, ever: the room code, the protocol version and, from a host,
## its game port. The address is the one the rendezvous itself sees the request come from.
## Never a user or host name, a path, anything about the AI guide, or player data.
##
## Polled, one request at a time: register() and resolve() start one and return false when
## they cannot; poll() returns {} until it is answered, then once
## {ok, error, address, port, expires_in_s, host_protocol}. close() releases a code and
## expects no answer. Error words: "not_live", "unknown", "expired", "version", "taken",
## "busy", "timeout", "bad_reply".
##
## Two implementations: NullRendezvous (scripts/net/null_rendezvous.gd), the game's only
## one until hosting is decided, which never touches the network; and a fake for the tests
## (tests/support/fake_rendezvous.gd) on 127.0.0.1.


## True when room codes work: a rendezvous can be reached.
func is_live() -> bool:
	return false


func register(_code: String, _protocol: int, _port: int) -> bool:
	return false


func resolve(_code: String, _protocol: int) -> bool:
	return false


func close(_code: String, _protocol: int, _port: int) -> void:
	pass


func poll() -> Dictionary:
	return {}


func is_busy() -> bool:
	return false


func cancel() -> void:
	pass


## Requests this client has sent over the network, ever.
func requests() -> int:
	return 0
