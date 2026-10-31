class_name RuinsLayout
extends RefCounted
## A ruins district's plan (C36), made from its set (scripts/ruins/ruins_set.gd) and nothing else: pure data, no node,
## so the tests check every set without building one, and the same set and seed always make the same plan. RuinsWorld
## (scripts/ruins/ruins_world.gd) builds it.
##
## The floor is a grid of CELL_M cells, the start at the +z end (the player looks down -z, as in the arena) and the
## exit at the -z end. Every cell is VOID (the abyss round the district), FLOOR, BLOCK (a ruin standing on it: a rack
## cluster, a directory monolith or a fallen tower) or HOLE (the floor gone, the void showing through). Made in order:
##   the outline   corners and notches cut from the rectangle into the void
##   the route     a seeded walk from the start to the exit, kept open, and a plaza in the middle for the fight
##   the ruins     blocks and holes, each kept only if every floor cell can still be walked to from the start
##   the edges     a parapet on every floor side that meets the void or a hole: PARAPET_H tall, over what a jump
##                 reaches, so nothing walks or jumps off the district; the overlooks among them are rails to look
##                 out over the abyss through
##   the points    named places a mission uses: start, exit, plaza, log_<n>, daemon_<n>, breaker_<n>, spawn_<n>,
##                 vista_<n> (a place on an overlook, looking out)
##   the cover     pieces on the floor, never on a point, kept only while every point can be walked to (checked on a
##                 grid of WALK_M squares, everything that collides grown by a player's radius)
##   the scenery   towers in the void round the edge, giants far out, cables between towers (cut ones dangling, never
##                 lower over the floor than CABLE_LOW_M), neon signs on the towers
## and `boxes`, the district's whole collision: the floor, the parapets, the blocks and the cover, every one a box.
##
## Fiction only: the folder names and sign words are the set's demo text.

const REGISTERS := ["tron", "cyberpunk", "matrix", "all"]
enum Cell { VOID, FLOOR, BLOCK, HOLE }
const CELL_M := 4.0
const CELLS_LEAST := Vector2i(6, 8)
const CELLS_MOST := Vector2i(16, 24)
## The floor's top, and how thick a slab is under it.
const FLOOR_Y := 0.0
const SLAB_M := 0.6
## A parapet's height (over the 1.22 m a jump lifts the feet) and thickness; what a block's collision stands to.
const PARAPET_H := 1.3
const PARAPET_T := 0.4
const BLOCK_H := 8.0
const BLOCK_INSET := 0.3
## Where a player's middle stands over the floor (the arena's spawns), and a player's radius, for the walk grid.
const STAND_Y := 0.95
const PLAYER_R := 0.45
## The walk grid's square, metres; what a box under this height does not block (a step).
const WALK_M := 0.5
const STEP_H := 0.3
## Nothing of a cable hangs lower than this over the floor: over the tallest cover plus a jump and a head.
const CABLE_LOW_M := 4.6
## The longest name on a monolith or a sign.
const NAME_LAST := 20
## Never on a sign or a monolith: what would give away the story's author before its mission (STORY.md section 3).
const NEVER_SHOWN := ["6666", "~", "nohup", "tilde", "pid"]
## How many of each point the plan names.
const POINTS := {"log": 4, "daemon": 6, "breaker": 6, "spawn": 5}
## Cover: [kind, collision size (x across its length, y tall, z deep)], picked by the dice.
const COVER := [["toppled", Vector3(3.2, 1.25, 1.0)], ["terminal", Vector3(1.1, 1.35, 0.8)], ["drives", Vector3(1.6, 1.0, 1.2)], ["rubble", Vector3(2.2, 0.95, 1.4)], ["shard", Vector3(1.2, 1.9, 1.0)]]
## How far out the towers and the giants stand, metres from the edge or the middle, and their heights over the floor.
const TOWER_OUT := Vector2(3.0, 14.0)
const TOWER_TALL := Vector2(12.0, 46.0)
const GIANT_OUT := Vector2(70.0, 230.0)
const GIANT_TALL := Vector2(40.0, 230.0)

var set: RuinsSet
var size := Vector2i.ZERO
var cells := PackedByteArray()
var start_cell := Vector2i.ZERO
var exit_cell := Vector2i.ZERO
var plaza_cell := Vector2i.ZERO
## The route kept open from the start to the exit.
var route: Array[Vector2i] = []
## [{rect: Rect2i, kind: "racks"|"monolith"|"fallen", seed}]
var blocks: Array = []
## [{rect: Rect2i, seed}]
var holes: Array = []
## [{kind, at: Vector3 (the floor under its middle), yaw (radians), size: Vector3, seed}]
var cover: Array = []
## [{cell: Vector2i, side: 0 north (-z) 1 east 2 south 3 west, hole: bool, overlook: bool, seed}]
var edges: Array = []
## [{at: Vector3 (its foot), tall (over the floor), foot (below it), width, depth, yaw, lean: Vector2 (x, z degrees), seed, inside: bool}]
var towers: Array = []
var giants: Array = []
## [{from: Vector3, to: Vector3, sag (metres at the middle), cut (0: whole, else where along it, 0 to 1), seed}]
var cables: Array = []
## [{tower: index, height (over its foot's floor level), text, slot (0 or 1), upright: bool, seed}]
var signs: Array = []
## Name -> Vector3.
var points := {}
## [{at: Vector3, out: Vector3}] for each vista_<n>: where it stands and the way it looks.
var vistas: Array = []
## [{xform: Transform3D, size: Vector3, kind: "floor"|"parapet"|"block"|"cover"}]
var boxes: Array = []

var _rng := RandomNumberGenerator.new()


func _init(from: RuinsSet) -> void:
	set = from
	if set == null:
		return
	size = set.cells
	_rng.seed = set.seed
	_outline()
	_route()
	_ruins()
	_edges()
	_points()
	_floor_boxes()
	_cover()
	_scenery()


## A set's plan, made once a run and kept (the same every time).
static var _kept := {}
static func of(from: RuinsSet) -> RuinsLayout:
	if from == null:
		return null
	var key := "%s:%d" % [from.id, from.seed]
	if not _kept.has(key):
		_kept[key] = RuinsLayout.new(from)
	return _kept[key]


# --- Cells. ---

func cell(c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= size.x or c.y >= size.y:
		return Cell.VOID
	return cells[c.y * size.x + c.x]


func _put(c: Vector2i, kind: int) -> void:
	cells[c.y * size.x + c.x] = kind


## The middle of cell `c` on the floor, in the district's space.
func center(c: Vector2i) -> Vector3:
	return Vector3((float(c.x) - (size.x - 1) * 0.5) * CELL_M, FLOOR_Y, (float(c.y) - (size.y - 1) * 0.5) * CELL_M)


## The cell a place on the floor is in.
func cell_at(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CELL_M + size.x * 0.5), floori(p.z / CELL_M + size.y * 0.5))


## Half the district's extent on x and z, metres.
func half_extent() -> Vector2:
	return Vector2(size.x, size.y) * CELL_M * 0.5


const SIDES := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


func _outline() -> void:
	cells.resize(size.x * size.y)
	cells.fill(Cell.FLOOR)
	for corner in [Vector2i(0, 0), Vector2i(size.x - 1, 0), Vector2i(0, size.y - 1), Vector2i(size.x - 1, size.y - 1)]:
		var cut := _rng.randi_range(1, 3)
		for x in size.x:
			for z in size.y:
				if absi(x - corner.x) + absi(z - corner.y) < cut:
					_put(Vector2i(x, z), Cell.VOID)
	for z in range(2, size.y - 2):
		for x in [0, size.x - 1]:
			if _rng.randf() < 0.22:
				_put(Vector2i(x, z), Cell.VOID)


func _route() -> void:
	start_cell = Vector2i(size.x / 2, size.y - 1)
	exit_cell = Vector2i(clampi(size.x / 2 + _rng.randi_range(-2, 2), 1, size.x - 2), 0)
	for c in [start_cell, exit_cell, start_cell + Vector2i(0, -1), exit_cell + Vector2i(0, 1)]:
		_put(c, Cell.FLOOR)
	var here := start_cell
	route = [here]
	while here != exit_cell:
		var step := Vector2i(0, -1)
		if here.y == exit_cell.y:
			step = Vector2i(signi(exit_cell.x - here.x), 0)
		elif _rng.randf() < 0.35:
			var side := _rng.randi_range(0, 1) * 2 - 1
			if here.x + side >= 1 and here.x + side <= size.x - 2:
				step = Vector2i(side, 0)
		here += step
		_put(here, Cell.FLOOR)
		route.append(here)
	plaza_cell = Vector2i(clampi(size.x / 2 + _rng.randi_range(-1, 1), 1, size.x - 2), clampi(size.y / 2 + _rng.randi_range(-1, 1), 2, size.y - 3))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			_put(plaza_cell + Vector2i(dx, dz), Cell.FLOOR)


func _reserved(c: Vector2i) -> bool:
	if route.has(c):
		return true
	if absi(c.x - plaza_cell.x) <= 1 and absi(c.y - plaza_cell.y) <= 1:
		return true
	for keep in [start_cell, exit_cell]:
		if absi(c.x - keep.x) <= 1 and absi(c.y - keep.y) <= 1:
			return true
	return false


func _ruins() -> void:
	var placed := 0
	for t in set.blocks * 4:
		if placed >= set.blocks:
			break
		var w := _rng.randi_range(1, 2)
		var h := _rng.randi_range(1, 3)
		var rect := Rect2i(_rng.randi_range(0, size.x - w), _rng.randi_range(1, size.y - 1 - h), w, h)
		var kind := "racks"
		var roll := _rng.randf()
		if roll < 0.32:
			kind = "monolith"
		elif roll < 0.5 and w * h >= 2:
			kind = "fallen"
		var block_seed := _rng.randi()
		if _try_mark(rect, Cell.BLOCK):
			blocks.append({"rect": rect, "kind": kind, "seed": block_seed})
			placed += 1
	placed = 0
	for t in set.holes * 12:
		if placed >= set.holes:
			break
		var w := _rng.randi_range(1, 2)
		var h := 1 if w == 2 else _rng.randi_range(1, 2)
		var rect := Rect2i(_rng.randi_range(1, size.x - 1 - w), _rng.randi_range(2, size.y - 2 - h), w, h)
		var hole_seed := _rng.randi()
		if _try_mark(rect, Cell.HOLE):
			holes.append({"rect": rect, "seed": hole_seed})
			placed += 1


## Marks `rect` as `kind` if every cell of it is open floor off the route, and the floor stays one piece; else nothing.
func _try_mark(rect: Rect2i, kind: int) -> bool:
	for x in range(rect.position.x, rect.end.x):
		for z in range(rect.position.y, rect.end.y):
			var c := Vector2i(x, z)
			if cell(c) != Cell.FLOOR or _reserved(c):
				return false
	for x in range(rect.position.x, rect.end.x):
		for z in range(rect.position.y, rect.end.y):
			_put(Vector2i(x, z), kind)
	if _floor_connected():
		return true
	for x in range(rect.position.x, rect.end.x):
		for z in range(rect.position.y, rect.end.y):
			_put(Vector2i(x, z), Cell.FLOOR)
	return false


func _floor_connected() -> bool:
	var seen := {start_cell: true}
	var todo: Array[Vector2i] = [start_cell]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for s in SIDES:
			var n: Vector2i = c + s
			if not seen.has(n) and cell(n) == Cell.FLOOR:
				seen[n] = true
				todo.append(n)
	return seen.size() == floor_cells().size()


## Every floor cell.
func floor_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for z in size.y:
		for x in size.x:
			if cells[z * size.x + x] == Cell.FLOOR:
				out.append(Vector2i(x, z))
	return out


func _edges() -> void:
	for c in floor_cells():
		for side in 4:
			var n := cell(c + SIDES[side])
			if n == Cell.VOID or n == Cell.HOLE:
				edges.append({"cell": c, "side": side, "hole": n == Cell.HOLE, "overlook": n == Cell.VOID and _rng.randf() < 0.45, "seed": _rng.randi()})
	for e in edges:
		var at := center(e["cell"]) + Vector3(SIDES[e["side"]].x, 0.0, SIDES[e["side"]].y) * (CELL_M * 0.5 + PARAPET_T * 0.5)
		var along_x: bool = e["side"] % 2 == 0
		var box := Vector3(CELL_M + PARAPET_T, PARAPET_H, PARAPET_T) if along_x else Vector3(PARAPET_T, PARAPET_H, CELL_M + PARAPET_T)
		boxes.append({"xform": Transform3D(Basis.IDENTITY, at + Vector3(0, PARAPET_H * 0.5, 0)), "size": box, "kind": "parapet"})
	for b in blocks:
		var r: Rect2i = b["rect"]
		var tall := BLOCK_H if b["kind"] != "fallen" else 4.2
		var lo := center(r.position) - Vector3(CELL_M, 0, CELL_M) * 0.5
		var hi := center(r.end - Vector2i.ONE) + Vector3(CELL_M, 0, CELL_M) * 0.5
		var sz := Vector3(hi.x - lo.x - BLOCK_INSET * 2.0, tall, hi.z - lo.z - BLOCK_INSET * 2.0)
		boxes.append({"xform": Transform3D(Basis.IDENTITY, (lo + hi) * 0.5 + Vector3(0, tall * 0.5, 0)), "size": sz, "kind": "block"})


func _floor_boxes() -> void:
	for z in size.y:
		var x := 0
		while x < size.x:
			if cell(Vector2i(x, z)) != Cell.FLOOR and cell(Vector2i(x, z)) != Cell.BLOCK:
				x += 1
				continue
			var run := 0
			while x + run < size.x and (cell(Vector2i(x + run, z)) == Cell.FLOOR or cell(Vector2i(x + run, z)) == Cell.BLOCK):
				run += 1
			var mid := (center(Vector2i(x, z)) + center(Vector2i(x + run - 1, z))) * 0.5
			boxes.append({"xform": Transform3D(Basis.IDENTITY, mid - Vector3(0, SLAB_M * 0.5, 0)), "size": Vector3(run * CELL_M, SLAB_M, CELL_M), "kind": "floor"})
			x += run


# --- Points. ---

func _points() -> void:
	points["start"] = center(start_cell) + Vector3(0, STAND_Y, 0)
	points["exit"] = center(exit_cell) + Vector3(0, STAND_Y, 0)
	points["plaza"] = center(plaza_cell) + Vector3(0, STAND_Y, 0)
	var open := floor_cells()
	var taken: Array[Vector2i] = [start_cell, exit_cell, plaza_cell]
	# Logs: tucked against a ruin or an edge, away from each other.
	var nooks: Array[Vector2i] = []
	for c in open:
		if taken.has(c):
			continue
		for s in SIDES:
			var n := cell(c + s)
			if n == Cell.BLOCK or n == Cell.VOID:
				nooks.append(c)
				break
	var logs := _spread(nooks, POINTS["log"], [start_cell], taken)
	for i in logs.size():
		var c: Vector2i = logs[i]
		var lean := Vector3.ZERO
		for s in SIDES:
			var n := cell(c + s)
			if n == Cell.BLOCK or n == Cell.VOID:
				lean = Vector3(s.x, 0, s.y)
				break
		points["log_%d" % i] = center(c) + lean * 0.8 + Vector3(0, STAND_Y, 0)
	# Daemons: out from the start, spread over the floor.
	var far: Array[Vector2i] = []
	for c in open:
		if absi(c.x - start_cell.x) + absi(c.y - start_cell.y) >= 4 and not taken.has(c):
			far.append(c)
	var daemons := _spread(far, POINTS["daemon"], [start_cell], taken)
	for i in daemons.size():
		points["daemon_%d" % i] = center(daemons[i])
	var breakers := _spread(open.filter(func(c): return not taken.has(c)), POINTS["breaker"], [start_cell] + daemons, taken)
	for i in breakers.size():
		points["breaker_%d" % i] = center(breakers[i])
	points["spawn_0"] = points["start"]
	var spawns := _spread(open.filter(func(c): return not taken.has(c)), POINTS["spawn"] - 1, [start_cell] + daemons, taken)
	for i in spawns.size():
		points["spawn_%d" % (i + 1)] = center(spawns[i]) + Vector3(0, STAND_Y, 0)
	var looks := edges.filter(func(e): return e["overlook"] and not taken.has(e["cell"]))
	for i in mini(looks.size(), 4):
		var e: Dictionary = looks[(i * 7 + 3) % looks.size()]
		var out := Vector3(SIDES[e["side"]].x, 0, SIDES[e["side"]].y)
		var at: Vector3 = center(e["cell"]) + out * (CELL_M * 0.5 - 0.9) + Vector3(0, STAND_Y, 0)
		points["vista_%d" % i] = at
		vistas.append({"at": at, "out": out})


## `count` cells of `from`, each as far as can be from those `away` and those already picked (farthest-point
## sampling, its first pick seeded), added to `taken`.
func _spread(from: Array, count: int, away: Array, taken: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var pool: Array = from.duplicate()
	var keep: Array = away.duplicate()
	for k in count:
		if pool.is_empty():
			break
		var best := -1
		var best_d := -1.0
		var jitter := _rng.randf() * 0.9
		for i in pool.size():
			var c: Vector2i = pool[i]
			var d := INF
			for o in keep + out:
				var other: Vector2i = o
				d = minf(d, Vector2(c - other).length())
			d += jitter * fposmod(float(c.x * 7 + c.y * 13), 1.7)
			if d > best_d:
				best_d = d
				best = i
		var pick: Vector2i = pool[best]
		pool.remove_at(best)
		out.append(pick)
		taken.append(pick)
	return out


## Every point's name, sorted.
func point_names() -> PackedStringArray:
	var out := PackedStringArray(points.keys())
	out.sort()
	return out


# --- Cover. ---

func _cover() -> void:
	var open := floor_cells().filter(func(c): return c != start_cell and c != exit_cell)
	for t in set.cover * 3:
		if cover.size() >= set.cover or open.is_empty():
			break
		var c: Vector2i = open[_rng.randi_range(0, open.size() - 1)]
		var pick: Array = COVER[_rng.randi_range(0, COVER.size() - 1)]
		var side: Vector2i = SIDES[_rng.randi_range(0, 3)]
		var yaw := (0.0 if side.x == 0 else PI * 0.5) + _rng.randf_range(-0.25, 0.25)
		var sz: Vector3 = pick[1] * Vector3(_rng.randf_range(0.85, 1.15), _rng.randf_range(0.9, 1.1), _rng.randf_range(0.9, 1.1))
		# Along the cell's side, its long way along it, and wholly inside its cell.
		var at := center(c) + Vector3(side.y, 0, side.x) * _rng.randf_range(-0.4, 0.4) + Vector3(side.x, 0, side.y) * _rng.randf_range(0.7, 1.15)
		var reach := absf(sz.x * 0.5 * cos(yaw)) + absf(sz.z * 0.5 * sin(yaw))
		var reach_z := absf(sz.x * 0.5 * sin(yaw)) + absf(sz.z * 0.5 * cos(yaw))
		var local := at - center(c)
		if absf(local.x) + reach > CELL_M * 0.5 - 0.1 or absf(local.z) + reach_z > CELL_M * 0.5 - 0.1:
			continue
		var clear := true
		for name in points:
			var p: Vector3 = points[name]
			if Vector2(p.x - at.x, p.z - at.z).length() < reach + 1.4:
				clear = false
				break
		if not clear:
			continue
		cover.append({"kind": pick[0], "at": at, "yaw": yaw, "size": sz, "seed": _rng.randi()})
	# Kept only while every point can be walked to: the last placed go first.
	while not cover.is_empty() and not unreachable().is_empty():
		cover.pop_back()
	for p in cover:
		boxes.append({"xform": Transform3D(Basis(Vector3.UP, p["yaw"]), p["at"] + Vector3(0, p["size"].y * 0.5, 0)), "size": p["size"], "kind": "cover"})


## The points a player at the start cannot walk to (on the walk grid, round everything that collides); empty when
## every one can be.
func unreachable() -> PackedStringArray:
	var ext := half_extent()
	var n := Vector2i(ceili(ext.x * 2.0 / WALK_M), ceili(ext.y * 2.0 / WALK_M))
	var open := PackedByteArray()
	open.resize(n.x * n.y)
	for j in n.y:
		for i in n.x:
			var w := Vector3(-ext.x + (i + 0.5) * WALK_M, 0, -ext.y + (j + 0.5) * WALK_M)
			open[j * n.x + i] = 1 if cell(cell_at(w)) == Cell.FLOOR else 0
	var solid: Array = boxes.filter(func(b): return b["kind"] != "floor" and b["size"].y > STEP_H)
	for p in cover:
		solid.append({"xform": Transform3D(Basis(Vector3.UP, p["yaw"]), p["at"]), "size": p["size"]})
	# Each box drawn onto the squares under it, grown by a player's radius.
	for b in solid:
		var xf: Transform3D = b["xform"]
		var h: Vector3 = b["size"] * 0.5
		var reach_x := absf(xf.basis.x.x) * h.x + absf(xf.basis.z.x) * h.z + PLAYER_R
		var reach_z := absf(xf.basis.x.z) * h.x + absf(xf.basis.z.z) * h.z + PLAYER_R
		var inv := xf.affine_inverse()
		for j in range(maxi(floori((xf.origin.z - reach_z + ext.y) / WALK_M), 0), mini(ceili((xf.origin.z + reach_z + ext.y) / WALK_M), n.y)):
			for i in range(maxi(floori((xf.origin.x - reach_x + ext.x) / WALK_M), 0), mini(ceili((xf.origin.x + reach_x + ext.x) / WALK_M), n.x)):
				var local := inv * Vector3(-ext.x + (i + 0.5) * WALK_M, xf.origin.y, -ext.y + (j + 0.5) * WALK_M)
				if absf(local.x) < h.x + PLAYER_R and absf(local.z) < h.z + PLAYER_R:
					open[j * n.x + i] = 0
	var at_of := func(p: Vector3) -> Vector2i: return Vector2i(clampi(floori((p.x + ext.x) / WALK_M), 0, n.x - 1), clampi(floori((p.z + ext.y) / WALK_M), 0, n.y - 1))
	var from: Vector2i = at_of.call(points["start"])
	var seen := PackedByteArray()
	seen.resize(n.x * n.y)
	var todo: Array[Vector2i] = []
	if open[from.y * n.x + from.x] == 1:
		seen[from.y * n.x + from.x] = 1
		todo.append(from)
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for s in SIDES:
			var m: Vector2i = c + s
			if m.x < 0 or m.y < 0 or m.x >= n.x or m.y >= n.y:
				continue
			var k := m.y * n.x + m.x
			if open[k] == 1 and seen[k] == 0:
				seen[k] = 1
				todo.append(m)
	var out := PackedStringArray()
	for name in points:
		var g: Vector2i = at_of.call(points[name])
		if seen[g.y * n.x + g.x] == 0:
			out.append(name)
	return out


# --- Scenery. ---

func _scenery() -> void:
	var outer := edges.filter(func(e): return not e["hole"])
	var tries := 0
	while towers.size() < set.towers and tries < set.towers * 8 and not outer.is_empty():
		tries += 1
		var e: Dictionary = outer[_rng.randi_range(0, outer.size() - 1)]
		var out := Vector3(SIDES[e["side"]].x, 0, SIDES[e["side"]].y)
		var across := Vector3(-out.z, 0, out.x)
		var at: Vector3 = center(e["cell"]) + out * (CELL_M * 0.5 + _rng.randf_range(TOWER_OUT.x, TOWER_OUT.y)) + across * _rng.randf_range(-1.8, 1.8)
		var width := _rng.randf_range(2.4, 5.0)
		var depth := _rng.randf_range(1.6, 3.2)
		if not _over_void(at, maxf(width, depth) * 0.75 + 1.0):
			continue
		var crowded := false
		for t in towers:
			if Vector2(t["at"].x - at.x, t["at"].z - at.z).length() < 3.6:
				crowded = true
				break
		if crowded:
			continue
		towers.append({"at": at, "tall": _rng.randf_range(TOWER_TALL.x, TOWER_TALL.y), "foot": _rng.randf_range(18.0, 70.0), "width": width, "depth": depth, "yaw": atan2(out.x, out.z) + _rng.randf_range(-0.35, 0.35), "lean": Vector2(_rng.randf_range(-7.0, 7.0), _rng.randf_range(-7.0, 7.0)), "seed": _rng.randi(), "inside": false})
	for b in blocks:
		if b["kind"] != "racks":
			continue
		var r: Rect2i = b["rect"]
		var lo := center(r.position) - Vector3(CELL_M, 0, CELL_M) * 0.5 + Vector3(BLOCK_INSET + 0.4, 0, BLOCK_INSET + 0.4)
		var hi := center(r.end - Vector2i.ONE) + Vector3(CELL_M, 0, CELL_M) * 0.5 - Vector3(BLOCK_INSET + 0.4, 0, BLOCK_INSET + 0.4)
		var count := clampi(r.size.x * r.size.y + _rng.randi_range(0, 1), 1, 4)
		for k in count:
			var width := _rng.randf_range(1.8, 2.6)
			var depth := _rng.randf_range(1.2, 1.6)
			var at := Vector3(_rng.randf_range(lo.x + width * 0.5, maxf(lo.x + width * 0.5, hi.x - width * 0.5)), 0, _rng.randf_range(lo.z + depth * 0.5, maxf(lo.z + depth * 0.5, hi.z - depth * 0.5)))
			towers.append({"at": at, "tall": _rng.randf_range(7.0, 26.0), "foot": 0.0, "width": width, "depth": depth, "yaw": float(_rng.randi_range(0, 3)) * PI * 0.5 + _rng.randf_range(-0.12, 0.12), "lean": Vector2(_rng.randf_range(-3.0, 3.0), _rng.randf_range(-3.0, 3.0)), "seed": _rng.randi(), "inside": true})
	for i in set.giants:
		var a := TAU * (float(i) + _rng.randf_range(0.1, 0.9)) / float(maxi(set.giants, 1))
		var d := _rng.randf_range(GIANT_OUT.x, GIANT_OUT.y)
		giants.append({"at": Vector3(sin(a) * d, 0, cos(a) * d), "tall": _rng.randf_range(GIANT_TALL.x, GIANT_TALL.y) * clampf(d / 140.0, 0.6, 1.4), "foot": 260.0, "width": _rng.randf_range(9.0, 26.0), "depth": _rng.randf_range(7.0, 16.0), "yaw": _rng.randf_range(0.0, TAU), "lean": Vector2(_rng.randf_range(-5.0, 5.0), _rng.randf_range(-5.0, 5.0)), "seed": _rng.randi(), "inside": false, "broken": _rng.randf() < 0.35})
	_cables()
	_signs()


## True when nothing within `radius` of `at` (on x and z) is floor, a block or a hole.
func _over_void(at: Vector3, radius: float) -> bool:
	for dx in [-radius, 0.0, radius]:
		for dz in [-radius, 0.0, radius]:
			if cell(cell_at(at + Vector3(dx, 0, dz))) != Cell.VOID:
				return false
	return true


func _cables() -> void:
	var tries := 0
	while cables.size() < set.cables and tries < set.cables * 12 and towers.size() >= 2:
		tries += 1
		var a: Dictionary = towers[_rng.randi_range(0, towers.size() - 1)]
		var b: Dictionary = towers[_rng.randi_range(0, towers.size() - 1)]
		if a == b:
			continue
		var span := Vector2(a["at"].x - b["at"].x, a["at"].z - b["at"].z).length()
		if span < 10.0 or span > 60.0:
			continue
		var from: Vector3 = _on_tower(a, _rng.randf_range(0.45, 0.95))
		var to: Vector3 = _on_tower(b, _rng.randf_range(0.45, 0.95))
		var cut := 0.0 if _rng.randf() < 0.55 else _rng.randf_range(0.25, 0.75)
		var cable := {"from": from, "to": to, "sag": span * _rng.randf_range(0.06, 0.16), "cut": cut, "seed": _rng.randi()}
		if cable_low(cable) < CABLE_LOW_M:
			continue
		cables.append(cable)


## A place on tower `t`'s upright, `share` of the way up what stands over the floor.
func _on_tower(t: Dictionary, share: float) -> Vector3:
	return tower_xform(t) * Vector3(0, t["tall"] * share, 0)


## Tower (or giant) `t`'s own space: its origin where its upright meets the floor's level, turned by its yaw and
## leaning by its lean about that point, so it stands where it was placed at the floor and leans above and below it.
static func tower_xform(t: Dictionary) -> Transform3D:
	var lean: Vector2 = t["lean"]
	var b := Basis.from_euler(Vector3(deg_to_rad(lean.y), 0.0, deg_to_rad(lean.x))) * Basis(Vector3.UP, t["yaw"])
	return Transform3D(b, t["at"])


## A cable's points, `steps` along it: its catenary (a parabola is close enough), and for a cut one each half hanging
## from its tower down to where it was cut, then dangling straight down a third of its span. [[Vector3...], ...]
static func cable_points(c: Dictionary, steps: int = 16) -> Array:
	var from: Vector3 = c["from"]
	var to: Vector3 = c["to"]
	var sag: float = c["sag"]
	var cut: float = c["cut"]
	var along := func(t: float) -> Vector3: return from.lerp(to, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0)
	if cut <= 0.0:
		var whole: Array = []
		for i in steps + 1:
			whole.append(along.call(float(i) / steps))
		return [whole]
	var drop := from.distance_to(to) * 0.3
	var halves: Array = []
	for half in [[0.0, cut], [1.0, cut]]:
		var line: Array = []
		var n := maxi(steps / 2, 4)
		for i in n + 1:
			# Slack once cut: each half hangs lower than the whole did, its end the lowest.
			var t: float = lerpf(half[0], half[1], float(i) / n)
			var p: Vector3 = along.call(t)
			p.y -= drop * 0.5 * pow(float(i) / n, 2.0)
			line.append(p)
		var tip: Vector3 = line[line.size() - 1]
		line.append(tip - Vector3(0, drop * 0.5, 0))
		halves.append(line)
	return halves


## The lowest a cable hangs over the floor (a block or a hole counts as floor), INF when it never crosses it.
func cable_low(c: Dictionary) -> float:
	var low := INF
	for line in cable_points(c, 24):
		for i in line.size():
			var p: Vector3 = line[i]
			if cell(cell_at(p)) != Cell.VOID:
				low = minf(low, p.y - FLOOR_Y)
			if i > 0:
				var mid: Vector3 = (p + (line[i - 1] as Vector3)) * 0.5
				if cell(cell_at(mid)) != Cell.VOID:
					low = minf(low, mid.y - FLOOR_Y)
	return low


func _signs() -> void:
	var ring := []
	for i in towers.size():
		if towers[i]["tall"] > (16.0 if not towers[i]["inside"] else 10.0):
			ring.append(i)
	for k in mini(set.signs, ring.size()):
		var i: int = ring[(k * 5 + _rng.randi_range(0, 2)) % ring.size()]
		var t: Dictionary = towers[i]
		var words := set.words
		var text: String = words[_rng.randi_range(0, words.size() - 1)]
		signs.append({"tower": i, "height": _rng.randf_range(0.35, 0.8) * t["tall"], "text": text, "slot": k % 2, "upright": _rng.randf() < 0.55, "seed": _rng.randi()})


## A monolith's name: one of the set's folder names, by its seed.
func folder_name(seed: int) -> String:
	return set.folders[posmod(seed, set.folders.size())]


## True when every letter of `text` is in the sign font and it is short enough to stand on a monolith.
static func legible(text: String) -> bool:
	return text != "" and text.length() <= NAME_LAST and load("res://scripts/arena/arena_font.gd").covers(text.to_upper())


## The plan as rows of letters, north (the exit) first: for a look while tuning, and a test's message.
## "." void, "#" floor, "B" block, "o" hole, "S" start, "E" exit, "P" plaza, "c" cover, digits daemons.
func ascii() -> String:
	var rows := PackedStringArray()
	for z in size.y:
		var row := ""
		for x in size.x:
			var c := Vector2i(x, z)
			var ch: String = [".", "#", "B", "o"][cell(c)]
			if c == start_cell:
				ch = "S"
			elif c == exit_cell:
				ch = "E"
			elif c == plaza_cell:
				ch = "P"
			else:
				for p in cover:
					if cell_at(p["at"]) == c:
						ch = "c"
				for i in POINTS["daemon"]:
					var at = points.get("daemon_%d" % i)
					if at != null and cell_at(at) == c:
						ch = str(i)
			row += ch
		rows.append(row)
	return "\n".join(rows)
