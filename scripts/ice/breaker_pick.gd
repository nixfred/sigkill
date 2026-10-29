extends RefCounted
## Which ICEbreaker to load (I2): the guide's pick, between rounds and on T. Built only from the round's
## numbers (numbers()): how many white ICE walls and nodes stand and their health, whether the hunter is
## out, its health and the weapon it has adapted to with how far, this player's breaker counts and the
## round. Nothing else: no path, name, process or file ever goes into it. The player's AI gets these
## numbers through the C9b request builder (guide_request.gd, whitelisted keys only), and
## SIGKILL's own scripted guide (scripted()) gives the same kind of advice from the same numbers when the
## AI is off, refused or silent: a decoy for a hunter that has adapted, exploit for a hunter out, brute
## for walls standing, cloak for nodes standing, else whichever is carried.
##
## Black ICE (I3): its numbers ride along (out or not, its seals standing, how far it is from this player
## in whole metres, whether it flatlined this player this round), and while it is out the scripted guide
## puts it first: the exploit and brute combo when this player holds an exploit and enough brutes for its
## seals, else the decoy, else the cloak, else the run (it is slower than a running intruder).

const Kinds = preload("res://scripts/ice/breakers.gd")

## The guide's numbers' keys (the request whitelist's own), in order.
const KEYS := ["round_number", "ice_walls", "ice_wall_health_pct", "ice_nodes", "ice_node_health_pct", "hunter_out", "hunter_health_pct", "hunter_adapted_weapon", "hunter_adapted_pct", "breakers_brute", "breakers_exploit", "breakers_cloak", "breakers_decoy", "black_ice_out", "black_ice_seals", "black_ice_distance_m", "black_ice_flatlined"]
## No weapon adapted to yet.
const NONE := "none"
## The hunter's adaptation past this share makes the decoy the pick.
const DECOY_AT_PCT := 25
const PICKS := {
	"decoy": "Load decoy: the hunter is out and %d%% adapted to the %s. Throw it, and slip away while it hunts the decoy.",
	"exploit": "Load exploit: the hunter is out. Its heart is a weak seam, and exploit makes those hits land far harder.",
	"brute": "Load brute: %d ICE wall%s up. Up close, one charge breaks a wall.",
	"cloak": "Load cloak: %d ICE node%s up. Cloaked, they never trigger and the hunter loses you.",
}
const ANY := {
	"brute": "Load brute: a charge that cracks ICE and floors daemons in front of you.",
	"exploit": "Load exploit: hits on the marked seams land far harder for a few seconds.",
	"cloak": "Load cloak: a few seconds unseen by ICE and the daemons. Firing ends it.",
	"decoy": "Load decoy: throw it and everything hunting you goes after it instead.",
}
const NOTHING := "No breakers left: find a pickup, the ultraviolet beams."
## While Black ICE is out (I3).
const BLACK := {
	"exploit": "Black ICE: run exploit, then brute it up close while exploit runs; %d seal%s to break, one brute each.",
	"decoy": "Black ICE: throw a decoy and break away. It cannot be shot and it is slower than your run.",
	"cloak": "Black ICE: cloak and slip past it; it cannot see you while the cloak holds.",
	"": "Black ICE: run. It cannot be shot, it is slower than you, and its touch flatlines.",
}


## The round's numbers now, from the breaker director `breakers` (its ICE director, its own counts):
## {} when breakers are off.
static func numbers(breakers: Node) -> Dictionary:
	if breakers == null or not is_instance_valid(breakers) or breakers.mode == BreakerDirector.Mode.OFF:
		return {}
	var out := {"round_number": maxi(int(breakers.round_number), 1)}
	var walls := 0
	var wall_health := 0.0
	var nodes := 0
	var node_health := 0.0
	var hunter_out := 0
	var hunter_health := 0
	var weapon := NONE
	var adapted := 0
	var ice: Node = breakers.ice
	if ice != null and is_instance_valid(ice) and ice.mode != IceDirector.Mode.OFF:
		for w in ice.walls:
			if not w.broken:
				walls += 1
				wall_health += w.health() / maxf(w.max_health, 1.0)
		for n in ice.nodes:
			if not n.broken:
				nodes += 1
				node_health += n.health() / maxf(n.max_health, 1.0)
		var h = ice.hunter
		if h != null and is_instance_valid(h) and not h.broken:
			hunter_out = 1
			hunter_health = roundi(100.0 * h.health() / maxf(h.max_health, 1.0))
		if ice.adapt_percent() > 0 and ice.adapt_weapon != "":
			weapon = ice.adapt_weapon
			adapted = ice.adapt_percent()
	out["ice_walls"] = walls
	out["ice_wall_health_pct"] = roundi(100.0 * wall_health / walls) if walls > 0 else 0
	out["ice_nodes"] = nodes
	out["ice_node_health_pct"] = roundi(100.0 * node_health / nodes) if nodes > 0 else 0
	out["hunter_out"] = hunter_out
	out["hunter_health_pct"] = hunter_health
	out["hunter_adapted_weapon"] = weapon
	out["hunter_adapted_pct"] = adapted
	var b: Breakers = breakers.mine
	for k in Kinds.NAMES.size():
		out["breakers_" + Kinds.name_of(k)] = b.count(k)
	var black_out := 0
	var seals := 0
	var gap := 0
	if ice != null and is_instance_valid(ice) and ice.mode != IceDirector.Mode.OFF and ice.black_out():
		black_out = 1
		seals = ice.black.seals_left
		var me: Node3D = breakers.player
		if me != null and is_instance_valid(me):
			gap = mini(roundi(Vector2(me.global_position.x - ice.black.global_position.x, me.global_position.z - ice.black.global_position.z).length()), 1000)
	out["black_ice_out"] = black_out
	out["black_ice_seals"] = seals
	out["black_ice_distance_m"] = gap
	out["black_ice_flatlined"] = 1 if ice != null and is_instance_valid(ice) and ice.flatlined_me() else 0
	return out


## SIGKILL's own pick from `n` (numbers()): [the kind's name, or "" for none carried, and its line].
static func scripted(n: Dictionary) -> Array:
	var has := func(kind: String) -> bool: return int(n.get("breakers_" + kind, 0)) > 0
	var hunter := int(n.get("hunter_out", 0)) > 0
	var adapted := int(n.get("hunter_adapted_pct", 0))
	var walls := int(n.get("ice_walls", 0))
	var nodes := int(n.get("ice_nodes", 0))
	if int(n.get("black_ice_out", 0)) > 0:
		var seals := maxi(int(n.get("black_ice_seals", 1)), 1)
		if has.call("exploit") and int(n.get("breakers_brute", 0)) >= seals:
			return ["exploit", BLACK["exploit"] % [seals, "" if seals == 1 else "s"]]
		for kind in ["decoy", "cloak"]:
			if has.call(kind):
				return [kind, BLACK[kind]]
		return ["", BLACK[""]]
	if hunter and adapted >= DECOY_AT_PCT and has.call("decoy"):
		return ["decoy", PICKS["decoy"] % [adapted, _weapon_word(String(n.get("hunter_adapted_weapon", NONE)))]]
	if hunter and has.call("exploit"):
		return ["exploit", PICKS["exploit"]]
	if walls > 0 and has.call("brute"):
		return ["brute", PICKS["brute"] % [walls, "" if walls == 1 else "s"]]
	if nodes > 0 and has.call("cloak"):
		return ["cloak", PICKS["cloak"] % [nodes, "" if nodes == 1 else "s"]]
	for kind in ["exploit", "cloak", "decoy", "brute"]:
		if has.call(kind):
			return [kind, ANY[kind]]
	return ["", NOTHING]


## The first breaker an answer names ("brute", "exploit", "cloak" or "decoy", whole words, any case),
## or "".
static func kind_in(text: String) -> String:
	var words := RegEx.create_from_string("[A-Za-z]+")
	for m in words.search_all(text):
		var w := m.get_string().to_lower()
		if Kinds.NAMES.has(w):
			return w
	return ""


## A weapon's id as the guide's line says it: its short name from the arsenal ("cannon"), or the id.
static func _weapon_word(id: String) -> String:
	var def = BreakerDirector._weapon(id)
	return def.short_name if def != null else id
