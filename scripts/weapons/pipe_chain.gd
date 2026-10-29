class_name PipeChain
extends RefCounted
## pipe |'s chain (C30): one process's stdout piped into the next one's stdin. The rules of one chain,
## shared by the shooter's own screen (alone it is the chain; in a match its look) and a match's host
## (which judges every chain), so both reach the same targets from the same world. Static functions over
## targets as dictionaries; nothing is made and nothing is hit here: the caller lands the links.
##
## A chain: the aim's ray meets its first target, the first link, where it struck; from each link the
## stream jumps to the nearest target not yet in the chain whose middle is within jump_m of the link's
## middle, with nothing of the level between the two (walls break a chain: it never arcs through one),
## and on until max_links (root_max_links as root) or no target is left in reach. The first link takes the
## weapon's damage, each after it link_keep of the one before. A daemon or a piece of ICE held frozen by
## chmod 000 conducts: the stream passes through it whole (frozen_keep) and jumps frozen_jump_scale as far
## from it, while its own hit is C29's frozen-hit rule (thawed, doubled, a strong one shattering). A link
## after the first lands on its target's weak seam nearest the stream's way in (A5's weak points: the data
## finds an open port), so an exploit breaker's bonus counts on every link (I2); a player's lands on its
## middle.
##
## What can be a link: a daemon, hunter ICE, a white ICE node, a player. A wall of white ICE ends a chain:
## hit first, it takes the hit and passes nothing on, and nothing ever jumps to it. Black ICE is never part
## of a chain: hit first, it only flashes ("pipe: broken pipe") and nothing goes on; nothing jumps to it.
##
## Cosmetic fiction only: nothing real is piped, run, signalled or read.

const GrepLock = preload("res://scripts/weapons/grep_lock.gd")

enum Kind { DAEMON, ICE, PLAYER, WALL, BLACK }

## How the chain reads on the HUD: its links' names joined by the pipe.
const JOIN := " | "


## `node` as a chain's target: a daemon, a piece of ICE (a wall and Black ICE marked so), or {} for
## anything else (the level, a player: player_target()). {node, middle, kind, frozen, id, name}.
static func target_of(node: Node) -> Dictionary:
	if node == null or not is_instance_valid(node) or not (node is Node3D):
		return {}
	if node is BlackIce:
		return _target(node, (node as IcePiece).aim_point(), Kind.BLACK, false, 0, (node as IcePiece).tag_text)
	if node is IceBarrier:
		return _target(node, (node as IcePiece).aim_point(), Kind.WALL, false, 0, (node as IcePiece).tag_text)
	if node is IcePiece:
		var piece := node as IcePiece
		return _target(node, piece.aim_point(), Kind.ICE, piece.frost != null and piece.frost.frozen(), 0, piece.tag_text)
	if node.is_in_group(GrepLock.TARGET_GROUP) and node.has_method("hit"):
		var frozen: bool = node.has_method("chmod_frozen") and node.chmod_frozen()
		var tag = node.get("tag_text")
		return _target(node, GrepLock.point_of(node), Kind.DAEMON, frozen, 0, tag if tag is String else "daemon")
	return {}


## A player as a chain's target: its body `node` (an avatar, or the host's own player), its id and name.
## A frozen player conducts nothing (C29's fairness: no bonus of any kind for a frozen player).
static func player_target(node: Node3D, id: int, who: String) -> Dictionary:
	return _target(node, node.global_position, Kind.PLAYER, false, id, who)


## The chain from `first` (a target, struck at `first_point`; {} for none) through `pool` (every target
## that could be a link, any order), where `sight` (from, to: world points) is true when nothing of the
## level lies between: its links in order, each its target with the point it lands on and its damage.
## `damage` is the first link's, `root` C22's root (one more link). `report`, when given, is told how it
## ended: "walled" true when it stopped short of its most with a target in reach that a wall hid.
static func build(first: Dictionary, first_point: Vector3, pool: Array, sight: Callable, tuning: PipeTuning, damage: float, root: bool, report: Dictionary = {}) -> Array:
	var links: Array = []
	if first.is_empty():
		return links
	var link := first.duplicate()
	link["point"] = first_point
	link["damage"] = damage
	links.append(link)
	if first["kind"] == Kind.WALL or first["kind"] == Kind.BLACK:
		return links  # a wall ends it; Black ICE never passes anything on
	var cap := tuning.links_for(root)
	var used := {first["node"]: true}
	var at: Dictionary = first
	var share := 1.0
	while links.size() < cap:
		share *= tuning.frozen_keep if at["frozen"] else tuning.link_keep
		var reach: float = tuning.jump_m * (tuning.frozen_jump_scale if at["frozen"] else 1.0)
		var next: Dictionary = {}
		var nearest := INF
		var walled := false
		for t in pool:
			if t.is_empty() or used.has(t["node"]) or t["kind"] == Kind.WALL or t["kind"] == Kind.BLACK:
				continue
			var d: float = (at["middle"] as Vector3).distance_to(t["middle"])
			if d > reach or d >= nearest:
				continue
			if not sight.call(at["middle"], t["middle"]):
				walled = true  # a wall between: the stream never arcs through it
				continue
			next = t
			nearest = d
		if next.is_empty():
			report["walled"] = walled
			break
		var joined := next.duplicate()
		joined["point"] = landing(next, at["middle"])
		joined["damage"] = damage * share
		links.append(joined)
		used[next["node"]] = true
		at = next
	return links


## Where the stream jumping in from `from` lands on `target`: the weak seam of its art nearest `from`
## (a daemon's or a piece of ICE's), else its middle (a player, a body with no seam shown).
static func landing(target: Dictionary, from: Vector3) -> Vector3:
	var node = target.get("node")
	if node == null or not is_instance_valid(node):
		return target.get("middle", Vector3.ZERO)
	var art = null
	if node.has_method("art_node"):
		art = node.art_node()
	elif node is IcePiece:
		art = (node as IcePiece).art
	if not (art is DaemonArt) or not (art as Node3D).is_inside_tree():
		return target["middle"]
	var xf: Transform3D = (art as Node3D).global_transform
	var best: Vector3 = target["middle"]
	var nearest := INF
	for p in (art as DaemonArt).weak_points():
		var at: Vector3 = xf * p
		var d := at.distance_to(from)
		if d < nearest:
			nearest = d
			best = at
	return best


## Every daemon and piece of ICE of `arena` that could be a link now: the living daemons, the standing
## hunter and nodes (a wall or Black ICE is never jumped to, so neither is listed).
static func pool_in(arena: Node) -> Array:
	var out: Array = []
	if arena == null or not is_instance_valid(arena) or not arena.is_inside_tree():
		return out
	for body in arena.get_tree().get_nodes_in_group(GrepLock.TARGET_GROUP):
		if body is Node3D and arena.is_ancestor_of(body) and GrepLock.alive(body):
			out.append(target_of(body))
	var ice := IceDirector.of(arena)
	if ice != null:
		for piece in ice.pieces():
			if (piece is HunterIce or piece is IceNode) and arena.is_ancestor_of(piece) and GrepLock.alive(piece):
				out.append(target_of(piece))
	return out


## The chain written out as a pipeline: "rogue.d | zombie | runaway".
static func line_of(links: Array) -> String:
	var names := PackedStringArray()
	for link in links:
		names.append(String(link.get("name", "?")))
	return JOIN.join(names)


## Every link's point, in order (world space).
static func points_of(links: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for link in links:
		out.append(link["point"])
	return out


static func _target(node: Node3D, middle: Vector3, kind: Kind, frozen: bool, id: int, who: String) -> Dictionary:
	return {"node": node, "middle": middle, "kind": kind, "frozen": frozen, "id": id, "name": who}
