class_name NetTuning
extends Resource
## Every number of LAN and tailnet play (C13, scripts/net/net_session.gd): the port a host
## opens, how many players fit, the player's shown name, how long a connect may take, how
## fast positions are sent and how far behind the remote avatars are drawn. The default
## instance is resources/net.tres. Units are milliseconds, hertz and players.

@export_group("Host")
## The UDP port a host opens. 9009 by default ("kill -9", twice): high, unprivileged, and
## the one friends type after the host's address.
@export var port: int = 9009
## The address the host listens on: "*" for every interface (LAN and tailnet alike), or
## one IP address of this machine. Tests bind 127.0.0.1 only.
@export var bind_address: String = "*"
## Players in one session, the host included.
@export var max_players: int = 2

@export_group("Player")
## The name other players see. A placeholder, never read from the system; the host turns
## it into "player <slot>" when it is left as is.
@export var display_name: String = "player"

@export_group("Timing")
## Longest a join may take, address lookup and handshake together, before it is given up
## with "couldn't reach host".
@export var connect_timeout_ms: int = 5000
## How long a connected peer may stay silent before it counts as gone (a crashed game, a
## pulled cable). ENet retries within this time.
@export var peer_timeout_ms: int = 8000
## How many times a second each player sends its position and view: never per frame.
@export var sync_rate_hz: int = 20
## How far behind the newest position a remote avatar is drawn, so it can glide between
## two received positions instead of jumping to each.
@export var interp_delay_ms: int = 100
## Longest a remote avatar keeps moving on its last known velocity when positions stop
## coming, before it holds still.
@export var extrapolate_max_ms: int = 200

const PORT_FIRST := 1024
const PORT_LAST := 65535
const PLAYERS_FIRST := 2
const PLAYERS_LAST := 16
const NAME_LAST := 24
const CONNECT_FIRST_MS := 500
const CONNECT_LAST_MS := 60000
const PEER_FIRST_MS := 1000
const PEER_LAST_MS := 120000
const RATE_FIRST_HZ := 5
const RATE_LAST_HZ := 60
const DELAY_FIRST_MS := 0
const DELAY_LAST_MS := 1000
const EXTRAPOLATE_LAST_MS := 2000


## True for a shown name the game accepts: 1 to 24 printable ASCII characters.
static func name_ok(name: String) -> bool:
	if name.is_empty() or name.length() > NAME_LAST:
		return false
	for i in name.length():
		var code := name.unicode_at(i)
		if code < 0x20 or code > 0x7E:
			return false
	return true


## Everything wrong with these values, or empty when they are safe to use.
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	if port < PORT_FIRST or port > PORT_LAST:
		out.append("port must be between %d and %d" % [PORT_FIRST, PORT_LAST])
	if bind_address != "*" and not bind_address.is_valid_ip_address():
		out.append("bind_address must be * or an IP address")
	if max_players < PLAYERS_FIRST or max_players > PLAYERS_LAST:
		out.append("max_players must be between %d and %d" % [PLAYERS_FIRST, PLAYERS_LAST])
	if not name_ok(display_name):
		out.append("display_name must be 1 to %d printable ASCII characters" % NAME_LAST)
	if connect_timeout_ms < CONNECT_FIRST_MS or connect_timeout_ms > CONNECT_LAST_MS:
		out.append("connect_timeout_ms must be between %d and %d" % [CONNECT_FIRST_MS, CONNECT_LAST_MS])
	if peer_timeout_ms < PEER_FIRST_MS or peer_timeout_ms > PEER_LAST_MS:
		out.append("peer_timeout_ms must be between %d and %d" % [PEER_FIRST_MS, PEER_LAST_MS])
	if sync_rate_hz < RATE_FIRST_HZ or sync_rate_hz > RATE_LAST_HZ:
		out.append("sync_rate_hz must be between %d and %d" % [RATE_FIRST_HZ, RATE_LAST_HZ])
	if interp_delay_ms < DELAY_FIRST_MS or interp_delay_ms > DELAY_LAST_MS:
		out.append("interp_delay_ms must be between %d and %d" % [DELAY_FIRST_MS, DELAY_LAST_MS])
	if extrapolate_max_ms < 0 or extrapolate_max_ms > EXTRAPOLATE_LAST_MS:
		out.append("extrapolate_max_ms must be between 0 and %d" % EXTRAPOLATE_LAST_MS)
	return out
