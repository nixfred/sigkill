class_name NetBook
extends RefCounted
## The packet tracer's network (W5, PRD 5.5): every machine in the mode, all of them INVENTED. Names made up for the
## game, addresses in a made-up subnet (SUBNET, "leet" on purpose, so it reads as a joke and never as anyone's network),
## put together from numbers here as they are shown. Nothing of the player's network is read: no device list, no
## hostname, no address, no name lookup; nothing in the mode can open a socket or run a program (PRD 6, the brief's
## producer decision: no real layer in W5, since every source for one means running a CLI or talking to a daemon).
##
## A machine is an island over the void: its id (its name, as traceroute prints it), its address's last number, its
## kind (how it looks: scripts/packets/packet_net.gd builds each kind its own island), where its deck stands, how big it
## is, its accent colour, its roster (who lives there) and its hop (its place in the trace; 0 is the player's own).
## A link joins two machines: its protocol (its colour and how its packets stream), how often it drops (its loss), and
## whether a man-in-the-middle sits on it. A stale route stands at a machine's forward port and sends a packet the wrong
## way while it lives.

## The made-up subnet's first three numbers: every address in the mode is these and a machine's own last number.
const SUBNET := [10, 13, 37]
## The player's own machine is the loopback (the one address every machine has for itself; nobody's network).
const LOOPBACK := [127, 0, 0, 1]
## Where the trace goes, its last hop.
const TARGET := "core-sink"

## Protocols: a link's colour and how its packets look and stream (metres a second along it, metres between packets).
const PROTOCOLS := {
	"tcp": {"color": Color(0.36, 0.95, 1.0), "speed": 18.0, "gap": 3.2, "label": "TCP"},
	"udp": {"color": Color(0.62, 0.55, 1.0), "speed": 26.0, "gap": 2.2, "label": "UDP"},
	"quic": {"color": Color(0.35, 1.0, 0.66), "speed": 22.0, "gap": 2.6, "label": "QUIC"},
	"icmp": {"color": Color(0.85, 1.0, 0.45), "speed": 14.0, "gap": 4.4, "label": "ICMP"},
}

## The machines, in hop order. `at` is where the middle of its deck stands (the deck's top), `size` its deck's half
## extents (x, z), `roster` its daemons: [kind, how many]. Kinds of daemon: the arena's three (rogue, zombie, runaway) and
## the packet tracer's own (retransmit, stale, mitm on a link, flood the boss).
const MACHINES := [
	{"id": "localhost", "host": -1, "kind": "laptop", "at": Vector3(0.0, 0.0, 0.0), "size": Vector2(9.0, 7.0), "accent": Color(0.098, 0.827, 0.773), "roster": [], "motto": "where every trace starts"},
	{"id": "gw-lantern", "host": 1, "kind": "router", "at": Vector3(-18.0, 4.0, -81.0), "size": Vector2(10.0, 9.0), "accent": Color(1.0, 0.75, 0.3), "roster": [["rogue", 2], ["retransmit", 1]], "motto": "the gateway out"},
	{"id": "rack-delta", "host": 20, "kind": "rack", "at": Vector3(48.0, 9.0, -138.0), "size": Vector2(13.0, 10.0), "accent": Color(0.45, 0.7, 1.0), "roster": [["zombie", 1], ["rogue", 1], ["runaway", 1]], "motto": "a rack of busy servers"},
	{"id": "edge-board", "host": 31, "kind": "board", "at": Vector3(15.0, 14.0, -219.0), "size": Vector2(11.0, 11.0), "accent": Color(0.4, 1.0, 0.55), "roster": [["retransmit", 2], ["rogue", 1], ["stale", 1]], "motto": "a little board at the edge"},
	{"id": "nas-vault", "host": 42, "kind": "nas", "at": Vector3(-51.0, 8.0, -264.0), "size": Vector2(11.0, 11.0), "accent": Color(0.85, 0.6, 1.0), "roster": [["zombie", 2], ["runaway", 1]], "motto": "where the backups sleep"},
	{"id": "relay-dish", "host": 58, "kind": "dish", "at": Vector3(-9.0, 18.0, -342.0), "size": Vector2(12.0, 11.0), "accent": Color(1.0, 0.55, 0.45), "roster": [["retransmit", 1], ["rogue", 1], ["zombie", 1], ["stale", 1]], "motto": "the long hop over the void"},
	{"id": "core-sink", "host": 66, "kind": "core", "at": Vector3(51.0, 22.0, -420.0), "size": Vector2(17.0, 17.0), "accent": Color(1.0, 0.2, 0.333), "roster": [["flood", 1]], "motto": "the trace's last hop"},
]

## The links: [from, to, protocol, loss (drops a minute while it is up), mitm (a man-in-the-middle sits on it), forward
## (part of the route; false: a link a stale route sends a packet down the wrong way)].
const LINKS := [
	["localhost", "gw-lantern", "tcp", 0.0, false, true],
	["gw-lantern", "rack-delta", "udp", 5.0, false, true],
	["rack-delta", "edge-board", "tcp", 6.0, true, true],
	["edge-board", "nas-vault", "quic", 6.5, false, true],
	["nas-vault", "relay-dish", "udp", 7.5, true, true],
	["relay-dish", "core-sink", "tcp", 8.0, true, true],
	["edge-board", "gw-lantern", "icmp", 0.0, false, false],
	["relay-dish", "nas-vault", "icmp", 0.0, false, false],
]

## Where a stale route sends a packet that boards its machine's forward port: the wrong way, back up the trace.
const STALE_TO := {"edge-board": "gw-lantern", "relay-dish": "nas-vault"}


## A machine's address as shown: the loopback for the player's own, else the made-up subnet and its own last number.
static func address(m: Dictionary) -> String:
	var host := int(m.get("host", -1))
	if host < 0:
		return "%d.%d.%d.%d" % LOOPBACK
	return "%d.%d.%d.%d" % [SUBNET[0], SUBNET[1], SUBNET[2], host]


static func index_of(id: String) -> int:
	for i in MACHINES.size():
		if MACHINES[i]["id"] == id:
			return i
	return -1


static func machine(id: String) -> Dictionary:
	var i := index_of(id)
	return MACHINES[i] if i >= 0 else {}


## Every machine's name, and every address, the mode may show.
static func names() -> PackedStringArray:
	var out := PackedStringArray()
	for m in MACHINES:
		out.append(m["id"])
	return out


static func addresses() -> PackedStringArray:
	var out := PackedStringArray()
	for m in MACHINES:
		out.append(address(m))
	return out


## The forward link out of machine `id` (toward the target), or -1 at the target.
static func forward_from(id: String) -> int:
	for i in LINKS.size():
		if LINKS[i][0] == id and bool(LINKS[i][5]):
			return i
	return -1


## The link joining `a` and `b` (either way), or -1.
static func link_between(a: String, b: String) -> int:
	for i in LINKS.size():
		if (LINKS[i][0] == a and LINKS[i][1] == b) or (LINKS[i][0] == b and LINKS[i][1] == a):
			return i
	return -1


## The protocol's colour.
static func color_of(proto: String) -> Color:
	return PROTOCOLS.get(proto, PROTOCOLS["tcp"])["color"]


## The hops from the player's own machine to the target, in order (every machine but the first).
static func hops() -> int:
	return MACHINES.size() - 1


## Problems with the table, for the checks: every name unique and none blank, every address in the made-up subnet or
## the loopback, every link between two machines of the table, a forward route from the first to the target.
static func problems() -> PackedStringArray:
	var out := PackedStringArray()
	var seen := {}
	for m in MACHINES:
		var id := str(m["id"])
		if id == "" or seen.has(id):
			out.append("name %s blank or twice" % id)
		seen[id] = true
		var host := int(m["host"])
		if host != -1 and (host < 1 or host > 254):
			out.append("%s's host number out of range" % id)
	for l in LINKS:
		if index_of(l[0]) < 0 or index_of(l[1]) < 0:
			out.append("a link to nowhere: %s %s" % [l[0], l[1]])
		if not PROTOCOLS.has(l[2]):
			out.append("unknown protocol " + str(l[2]))
	var at := str(MACHINES[0]["id"])
	var steps := 0
	while at != TARGET and steps <= MACHINES.size():
		var f := forward_from(at)
		if f < 0:
			out.append("no forward link out of " + at)
			break
		at = LINKS[f][1]
		steps += 1
	if at != TARGET:
		out.append("the route never reaches " + TARGET)
	for from in STALE_TO:
		if link_between(from, STALE_TO[from]) < 0:
			out.append("a stale route with no link: " + from)
	return out
