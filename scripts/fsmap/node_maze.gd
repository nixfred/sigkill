class_name NodeMaze
extends RefCounted
## The node_modules maze's plan (W2, PRD 5.5: "node_modules is the endless maze"), made from a district's floor (a
## RuinsLayout of FolderRooms.maze_set()) and a seed alone: pure data, so the tests check it without building one, and
## the same level always makes the same maze.
##
## A maze over the floor's cells: a seeded depth-first walk from the start (long corridors, one way between any two
## cells), then a few walls knocked through (BRAID) so it is not one long dead end after another. Every side of a cell
## that is not a way through is a wall: between two cells, or onto the void (the floor's edge is walled too: you do not
## see out). The start is the district's start; the way out is the cell farthest from it along the maze (you cross the
## whole thing to leave); the ways down (`pits`, at most PITS_MOST) are dead ends deep in it, each a node_modules a
## level down. Endless: a way down makes the next level, bigger, on and on; the way out always leaves the maze whole.

const BRAID := 0.07
const PITS_MOST := 3
## A way down stands at least this many steps from the start and the way out.
const PIT_APART := 4
## Wall height and thickness, metres (over a jump, and over the eye: you see the walls, not the room).
const WALL_H := 6.5
const WALL_T := 0.32

var layout: RuinsLayout = null
var seed := 0
var level := 1
var start := Vector2i.ZERO
var exit := Vector2i.ZERO
var pits: Array[Vector2i] = []
## Open sides: "x,y,side" for each way through (both cells' sides marked).
var open := {}
## Every wall: {cell, side, at: Vector3 (its middle on the floor), yaw, length, outer: bool}.
var walls: Array = []
## Steps from the start along the maze, by cell.
var dist := {}
var cells: Array[Vector2i] = []


func _init(from: RuinsLayout, seed_in: int, level_in: int) -> void:
	layout = from
	seed = seed_in
	level = level_in
	if layout == null:
		return
	cells = layout.floor_cells()
	start = layout.start_cell
	_carve()
	_braid()
	dist = distances(start)
	_exit()
	_pits()
	_walls()


func _floor(c: Vector2i) -> bool:
	return layout.cell(c) == RuinsLayout.Cell.FLOOR


func _key(c: Vector2i, side: int) -> String:
	return "%d,%d,%d" % [c.x, c.y, side]


func _open(c: Vector2i, side: int) -> void:
	open[_key(c, side)] = true
	open[_key(c + RuinsLayout.SIDES[side], (side + 2) % 4)] = true


## True when cell `c` opens through its side `side` into the next cell.
func is_open(c: Vector2i, side: int) -> bool:
	return open.has(_key(c, side))


func _carve() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var seen := {start: true}
	var stack: Array[Vector2i] = [start]
	while not stack.is_empty():
		var c: Vector2i = stack.back()
		var ways: Array = []
		for side in 4:
			var n: Vector2i = c + RuinsLayout.SIDES[side]
			if _floor(n) and not seen.has(n):
				ways.append(side)
		if ways.is_empty():
			stack.pop_back()
			continue
		var side: int = ways[rng.randi_range(0, ways.size() - 1)]
		var n: Vector2i = c + RuinsLayout.SIDES[side]
		_open(c, side)
		seen[n] = true
		stack.append(n)


func _braid() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 7 + 3
	for c in cells:
		for side in [1, 2]:
			var n: Vector2i = c + RuinsLayout.SIDES[side]
			if _floor(n) and not is_open(c, side) and rng.randf() < BRAID:
				_open(c, side)


## Steps from `from` to every cell, along the maze.
func distances(from: Vector2i) -> Dictionary:
	var out := {from: 0}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for side in 4:
			if is_open(c, side):
				var n: Vector2i = c + RuinsLayout.SIDES[side]
				if not out.has(n):
					out[n] = int(out[c]) + 1
					queue.append(n)
	return out


## The way along the maze from `a` to `b`, cell by cell (both ends in), or [] when there is none.
func path(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var back := {a: a}
	var queue: Array[Vector2i] = [a]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c == b:
			break
		for side in 4:
			if is_open(c, side):
				var n: Vector2i = c + RuinsLayout.SIDES[side]
				if not back.has(n):
					back[n] = c
					queue.append(n)
	if not back.has(b):
		return []
	var out: Array[Vector2i] = [b]
	var at := b
	while at != a:
		at = back[at]
		out.push_front(at)
	return out


func _exit() -> void:
	var far := -1
	for c in cells:
		var d := int(dist.get(c, -1))
		if d > far or (d == far and c.y < exit.y):
			far = d
			exit = c


func _pits() -> void:
	var from_exit := distances(exit)
	var ends: Array = []
	for c in cells:
		if c == start or c == exit:
			continue
		var ways := 0
		for side in 4:
			if is_open(c, side):
				ways += 1
		if ways == 1 and int(dist.get(c, 0)) >= PIT_APART and int(from_exit.get(c, 0)) >= PIT_APART:
			ends.append(c)
	ends.sort_custom(func(a, b): return [int(dist[a]), a.y, a.x] > [int(dist[b]), b.y, b.x])
	for c in ends:
		if pits.size() >= PITS_MOST:
			break
		var near := false
		for p in pits:
			near = near or absi(p.x - c.x) + absi(p.y - c.y) < PIT_APART
		if not near:
			pits.append(c)


func _walls() -> void:
	var half := RuinsLayout.CELL_M * 0.5
	for c in cells:
		for side in 4:
			var n: Vector2i = c + RuinsLayout.SIDES[side]
			var inner := _floor(n)
			if inner and (side == 0 or side == 3):
				continue  # a side between two cells is drawn once, from the cell to its west or north
			if inner and is_open(c, side):
				continue
			var o := Vector3(RuinsLayout.SIDES[side].x, 0, RuinsLayout.SIDES[side].y)
			var at := layout.center(c) + o * half
			walls.append({"cell": c, "side": side, "at": at, "yaw": 0.0 if side % 2 == 0 else PI * 0.5, "length": RuinsLayout.CELL_M, "outer": not inner})


## The cells every cell can reach (the tests' check that nothing is shut off).
func reachable_from_start() -> int:
	return dist.size()


## As rows of letters, the exit's end first: "#" floor, "S" start, "E" the way out, "v" a way down; for a test's message.
func ascii() -> String:
	var rows := PackedStringArray()
	for z in layout.size.y:
		var row := ""
		for x in layout.size.x:
			var c := Vector2i(x, z)
			row += "S" if c == start else "E" if c == exit else "v" if pits.has(c) else "#" if _floor(c) else "."
		rows.append(row)
	return "\n".join(rows)
