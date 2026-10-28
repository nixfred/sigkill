extends Node3D
## Light-trail mode (C20, PRD 5.2: "your path leaves a solid neon wall, Tron deathmatch"):
## every player's walls in one arena. A player on the ground lays a thin wall segment behind
## them every spacing_m of travel, along the ground from where the last one ended; in the air
## nothing is laid and the next wall starts where they land. Each segment stands lifetime_s
## (fading over its last fade_s) and is then gone; a trail holds cap segments at most, and
## laying past that drops its oldest. All numbers: resources/light_trail.tres
## (scripts/modes/light_trail_tuning.gd). Every position here is in the arena's space.
##
## Who decides: the session (scripts/net/net_session.gd). The host calls advance() for every
## player and touching() for every living one, and a touch is a kill it credits to the wall's
## owner; a joiner's screen only add()s the segments the host sends, and never judges. Both
## age their walls with tick() on the same physics step.
##
## Touching: the player's capsule (RemotePlayer.HIT_RADIUS, feet RemotePlayer.FEET below its
## middle) against a segment's footprint, a line on the ground widened by half the wall's
## thickness, and its height. No physics bodies: walls stop nothing, bullets included; they
## kill on touch. A player's own newest segment never touches them, nor do their own
## segments younger than grace_s, so the wall being laid is never the one that kills.
##
## Drawn as one MultiMesh per player, in that player's colour, over-bright for bloom, each
## segment fading by its own alpha. Cosmetic fiction: nothing real is touched.

const Tuning = preload("res://scripts/modes/light_trail_tuning.gd")
const Palette = preload("res://scripts/palette.gd")
const RemotePlayer = preload("res://scripts/net/remote_player.gd")
## Every node of the walls is in this group: the tests count them.
const GROUP := &"light_trail"
## The node under an arena that holds its walls.
const NODE := "LightTrails"

var tuning: Tuning

## owner id -> {segments: [{a, b, age}] oldest first, anchor (INF: none), color, view,
## lo, hi (the footprint's bounds, x and z)}.
var _owners := {}
var _box: BoxMesh
var _mat: StandardMaterial3D


## The walls of `arena`, made on first use with `with_tuning`.
static func of(arena: Node, with_tuning: Tuning) -> Node3D:
	var found := arena.get_node_or_null(NODE) as Node3D
	if found != null:
		return found
	var trails: Node3D = load("res://scripts/modes/light_trails.gd").new()
	trails.name = NODE
	trails.tuning = with_tuning
	arena.add_child(trails)
	return trails


## The walls of `arena` if it has any, or null.
static func find(arena: Node) -> Node3D:
	if arena == null or not is_instance_valid(arena):
		return null
	return arena.get_node_or_null(NODE) as Node3D


## Takes `arena`'s walls away now, every one of them (the match is over, or the mode off).
static func drop(arena: Node) -> void:
	var found := find(arena)
	if found != null:
		arena.remove_child(found)
		found.queue_free()


## The shortest ground distance from `p` to the segment from `a` to `b`, heights ignored.
static func distance_xz(p: Vector3, a: Vector3, b: Vector3) -> float:
	var p2 := Vector2(p.x, p.z)
	var a2 := Vector2(a.x, a.z)
	var b2 := Vector2(b.x, b.z)
	var ab := b2 - a2
	var span := ab.length_squared()
	var t := 0.0 if span == 0.0 else clampf((p2 - a2).dot(ab) / span, 0.0, 1.0)
	return p2.distance_to(a2 + ab * t)


func _ready() -> void:
	add_to_group(GROUP)
	_box = BoxMesh.new()
	_mat = Palette.trail_material()


## How far a body's middle may come to a wall's middle line before it touches it.
func reach() -> float:
	return RemotePlayer.HIT_RADIUS + tuning.thickness_m * 0.5


## Sets `id`'s wall colour (its match slot's), drawn from then on.
func paint(id: int, color: Color) -> void:
	var o := _owner(id)
	if o["color"] != color:
		o["color"] = color
		_refresh(id)


## `id` seen at `ground` (the ground under them) when `grounded`, else in the air: lays a
## segment when they have gone spacing_m along the ground since the last one ended. Returns
## the segment laid, [from, to], or [].
func advance(id: int, ground: Vector3, grounded: bool) -> Array:
	var o := _owner(id)
	if not grounded or not ground.is_finite():
		o["anchor"] = Vector3.INF  # airborne: nothing laid, and no wall across the jump
		return []
	var anchor: Vector3 = o["anchor"]
	if not anchor.is_finite():
		o["anchor"] = ground
		return []
	var run := Vector2(ground.x - anchor.x, ground.z - anchor.z).length()
	if run > tuning.segment_last_m:
		o["anchor"] = ground  # a jump in place, not a walk: start again here
		return []
	if run < tuning.spacing_m:
		return []
	add(id, anchor, ground)
	o["anchor"] = ground
	return [anchor, ground]


## A segment of `id`'s wall from `a` to `b`, `age` seconds old: new when laid here or sent
## by the host as it lays it; older when the host catches a new joiner up on the walls.
func add(id: int, a: Vector3, b: Vector3, age: float = 0.0) -> void:
	var o := _owner(id)
	var segments: Array = o["segments"]
	segments.append({"a": a, "b": b, "age": age})
	while segments.size() > tuning.cap:
		segments.pop_front()  # the cap: the oldest goes
	_bounds(o)
	_refresh(id)


## Every wall of `id` gone, and their next starts afresh (a death, a respawn).
func clear(id: int) -> void:
	if not _owners.has(id):
		return
	var o: Dictionary = _owners[id]
	o["segments"] = []
	o["anchor"] = Vector3.INF
	_bounds(o)
	_refresh(id)


## Every owner but those in `ids` gone, view and all (players who left).
func keep_only(ids: Array) -> void:
	for id in _owners.keys():
		if not ids.has(id):
			var view = _owners[id]["view"]
			if view != null and is_instance_valid(view):
				view.queue_free()
			_owners.erase(id)


## Ages every segment by `delta`: those past lifetime_s go, those in their fade fade.
func tick(delta: float) -> void:
	for id in _owners:
		var o: Dictionary = _owners[id]
		var segments: Array = o["segments"]
		var gone := 0
		var fading := false
		for s in segments:
			s["age"] += delta
			if s["age"] >= tuning.lifetime_s:
				gone += 1
			elif s["age"] > tuning.lifetime_s - tuning.fade_s:
				fading = true
		if gone > 0:
			o["segments"] = segments.slice(gone)  # oldest first: the expired lead
			_bounds(o)
			_refresh(id)
		elif fading:
			_refresh(id, true)


## The owner of a wall the body whose middle is at `pos` touches, `who` being that body's
## player, or -1 for none. Its own newest segment and its own younger than grace_s never.
func touching(pos: Vector3, who: int) -> int:
	var r := reach()
	for id in _owners:
		var o: Dictionary = _owners[id]
		var segments: Array = o["segments"]
		if segments.is_empty():
			continue
		var lo: Vector2 = o["lo"]
		var hi: Vector2 = o["hi"]
		if pos.x < lo.x - r or pos.x > hi.x + r or pos.z < lo.y - r or pos.z > hi.y + r:
			continue
		var newest := segments.size() - 1
		for i in segments.size():
			var s: Dictionary = segments[i]
			if id == who and (i == newest or s["age"] < tuning.grace_s):
				continue
			var base := minf(s["a"].y, s["b"].y)
			if pos.y - RemotePlayer.FEET >= base + tuning.height_m or pos.y + RemotePlayer.FEET <= base:
				continue  # over it, or under it
			if distance_xz(pos, s["a"], s["b"]) < r:
				return id
	return -1


## Which way a body at `pos` is thrown by the wall of `id` it touched: away from it,
## along the ground. Straight back along z when that cannot be told.
func push_of(pos: Vector3, id: int) -> Vector3:
	var best := INF
	var away := Vector3.BACK
	for s in _owners.get(id, {}).get("segments", []):
		var d := distance_xz(pos, s["a"], s["b"])
		if d < best:
			best = d
			var ab := Vector2(s["b"].x - s["a"].x, s["b"].z - s["a"].z)
			var to := Vector2(pos.x - s["a"].x, pos.z - s["a"].z)
			var t := 0.0 if ab.length_squared() == 0.0 else clampf(to.dot(ab) / ab.length_squared(), 0.0, 1.0)
			var off := to - ab * t
			if off.length_squared() > 0.000001:
				away = Vector3(off.x, 0.0, off.y).normalized()
	return away


## `id`'s segments, oldest first, each [from, to, age].
func walls_of(id: int) -> Array:
	var out := []
	for s in _owners.get(id, {}).get("segments", []):
		out.append([s["a"], s["b"], s["age"]])
	return out


## Every player with walls here.
func owners() -> Array:
	return _owners.keys()


## `id`'s segments, oldest first, each [from, to].
func segments_of(id: int) -> Array:
	var out := []
	for s in _owners.get(id, {}).get("segments", []):
		out.append([s["a"], s["b"]])
	return out


func count_of(id: int) -> int:
	return _owners.get(id, {}).get("segments", []).size()


## Every segment of every owner.
func total() -> int:
	var n := 0
	for id in _owners:
		n += _owners[id]["segments"].size()
	return n


## Where `id`'s next segment will start, INF when none (airborne, or not seen yet).
func anchor_of(id: int) -> Vector3:
	return _owners.get(id, {}).get("anchor", Vector3.INF)


func _owner(id: int) -> Dictionary:
	if not _owners.has(id):
		_owners[id] = {"segments": [], "anchor": Vector3.INF, "color": Palette.trail_color(1), "view": null, "lo": Vector2.ZERO, "hi": Vector2.ZERO}
	return _owners[id]


func _bounds(o: Dictionary) -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for s in o["segments"]:
		for p in [s["a"], s["b"]]:
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
	o["lo"] = lo
	o["hi"] = hi


## Draws `id`'s segments: one box each, along the ground from its start to its end. With
## `fading_only`, only the colours of the oldest, those in their fade, change.
func _refresh(id: int, fading_only: bool = false) -> void:
	var o: Dictionary = _owners[id]
	var view = o["view"]
	if view == null or not is_instance_valid(view):
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _box
		mm.instance_count = tuning.cap
		mm.visible_instance_count = 0
		view = MultiMeshInstance3D.new()
		view.name = "Trail%d" % id
		view.multimesh = mm
		view.material_override = _mat
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		view.add_to_group(GROUP)
		add_child(view)
		o["view"] = view
	var multimesh: MultiMesh = view.multimesh
	var segments: Array = o["segments"]
	var color: Color = o["color"]
	var bright := Color(color.r * tuning.energy, color.g * tuning.energy, color.b * tuning.energy)
	multimesh.visible_instance_count = segments.size()
	for i in segments.size():
		var s: Dictionary = segments[i]
		if fading_only:
			if s["age"] <= tuning.lifetime_s - tuning.fade_s:
				break  # oldest first: none after this one fades yet
			multimesh.set_instance_color(i, Color(bright, clampf((tuning.lifetime_s - s["age"]) / tuning.fade_s, 0.0, 1.0)))
			continue
		var a: Vector3 = s["a"]
		var b: Vector3 = s["b"]
		var run := Vector2(b.x - a.x, b.z - a.z)
		var base := minf(a.y, b.y)
		var turn := Basis(Vector3.UP, atan2(-run.y, run.x))
		var size := Basis.from_scale(Vector3(maxf(run.length(), 0.01), tuning.height_m, tuning.thickness_m))
		var middle := Vector3((a.x + b.x) * 0.5, base + tuning.height_m * 0.5, (a.z + b.z) * 0.5)
		multimesh.set_instance_transform(i, Transform3D(turn * size, middle))
		var left: float = tuning.lifetime_s - s["age"]
		var alpha := 1.0 if tuning.fade_s <= 0.0 else clampf(left / tuning.fade_s, 0.0, 1.0)
		multimesh.set_instance_color(i, Color(bright, alpha))
