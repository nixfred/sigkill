extends DaemonArt
## A live process swarm's nest (W1, PRD 5.5): the process whose children are its swarm (a browser and its tabs) or whose
## threads are (a busy process), given a body. Not a walker: a nest hanging in the air, a ball of armoured hex cells
## round a core, each cell with a vermilion light that is lit while one of its drones is out (lit), its armoured core
## halves turning round a band of light with its heart in the gap (its weak point), blade antennae over it. Its drones
## (scripts/daemons/tab_drone.gd) fly round it as a flock (scripts/procs/swarm_flock.gd).
##
## It breathes; its cells turn in two bands against each other. Before its swarm dives (the flock's tell) it pulls its
## cells in tight and burns every light white; as the dive goes out its cells spring out again. A drone forked out of it
## (fork_flash()) pops one cell out and flares it. Hurt, its cells loosen and its heart shows more.
##
## No two alike (A5's rule): its seed sets how many cells and how far out, the antennae, its tilt, a scorched cell or two
## and a flickering light. Never an elite. Faceless. Visual only: its dummy keeps a box round the nest as its hit volume.

const CELLS_LOW := 14
const CELLS_HIGH := 22
const SHELL_R := 1.0
const CELL := Vector3(0.36, 0.1, 0.36)
const CELL_LIGHT := 0.11
const CORE_W := 0.62
const CORE_H := 0.16
const HEART_M := 0.3
const ANTENNA_L := 0.7
const TURN := 0.35
const BREATH_HZ := 0.45
const BOX := Vector3(2.4, 2.4, 2.4)
const FORK_FLASH_S := 0.6

## Set by the hunt: how many of its cells are lit (its drones out now).
var lit := 0

var _cells := PackedInt32Array()
var _lights := PackedInt32Array()
var _dirs := PackedVector3Array()
var _bands := PackedInt32Array()
var _antennae := PackedInt32Array()
var _core_top: int
var _core_bottom: int
var _band_ring: int
var _heart: int
var _shell := SHELL_R
var _tilt := Basis.IDENTITY
var _turned := 0.0
var _fork_at := -1.0
var _fork_cell := 0


func _build() -> void:
	ai_kind = "nest"
	core_color = Palette.VERMILION
	edge_color = Palette.VERMILION
	glyph_count = 8
	glyph_radius = 1.7
	glyph_low = -1.0
	glyph_high = 1.2
	glyph_size = 0.15
	glyph_turns = 0.08
	reach = AABB(Vector3(-2.0, -2.0, -2.0), Vector3(4.0, 4.4, 4.0))
	tag_height = 1.9
	budget_triangles = 6000
	budget_draw_calls = 9
	size_low = 0.95
	size_high = 1.1
	elite_size = 1.1
	var count := pick(60, 0, CELLS_LOW, CELLS_HIGH)
	_shell = SHELL_R * lerpf(0.9, 1.12, dice(61, 0))
	_tilt = Basis(Vector3(dice(62, 0) - 0.5, 0.0, dice(62, 1) - 0.5).normalized() if dice(62, 2) > 0.05 else Vector3.RIGHT, lerpf(0.1, 0.35, dice(63, 0)))
	_turned = TAU * dice(64, 0)
	_core_top = part(Shape.HEX, Look.ARMOR)
	_core_bottom = part(Shape.HEX, Look.ARMOR)
	_band_ring = seam(part(Shape.RING, Look.CORE))
	_heart = weak(part(Shape.GEM, Look.CORE))
	# The cells on a sphere, evenly spread (a golden spiral), the poles left open for the core's axis.
	for i in count:
		var y := lerpf(0.82, -0.82, (float(i) + 0.5) / float(count))
		var r := sqrt(1.0 - y * y)
		var a := float(i) * 2.399963
		_dirs.append(Vector3(cos(a) * r, y, sin(a) * r))
		_bands.append(0 if y >= 0.0 else 1)
		_cells.append(part(Shape.HEX, Look.ARMOR))
		_lights.append(part(Shape.GEM, Look.CORE))
	for i in pick(65, 0, 3, 5):
		_antennae.append(part(Shape.BLADE, Look.ARMOR))
	for i in pick(66, 0, 1, 2):
		scorch(_cells[pick(67, i, 0, count - 1)], lerpf(0.5, 1.0, dice(68, i)))
	flicker(_lights[pick(69, 0, 0, count - 1)], lerpf(0.3, 0.6, dice(70, 0)))


func _pose(t: float, delta: float) -> void:
	var hurt := _hurt()
	var tell := drive_amount() if act == Act.TELL else 0.0
	var burst := drive_amount() if act == Act.STRIKE else 0.0
	var breath := 0.5 + 0.5 * sin(TAU * BREATH_HZ * t + _seed * TAU)
	_turned = fmod(_turned + TURN * (1.0 + 1.5 * tell) * delta, TAU)
	var middle := recoil() + Vector3(0.0, 0.12 * sin(0.9 * t + _seed * 5.0), 0.0)
	var frame := _tilt * Basis(Vector3.UP, _turned)
	var fork := clampf(1.0 - since(_fork_at) / FORK_FLASH_S, 0.0, 1.0) if _fork_at >= 0.0 else 0.0
	# The core: two armoured hex halves round a band of light, the heart in the gap.
	var gap := 0.08 + 0.1 * hurt + 0.06 * breath
	lay(_core_top, middle + frame * Vector3(0.0, gap, 0.0), frame * Basis.from_scale(Vector3(CORE_W, CORE_H, CORE_W)))
	lay(_core_bottom, middle - frame * Vector3(0.0, gap, 0.0), frame * Basis(Vector3.RIGHT, PI) * Basis.from_scale(Vector3(CORE_W, CORE_H, CORE_W)))
	orient(_band_ring, middle, frame * Vector3.UP, 0.05, CORE_W * 1.25)
	brighten(_band_ring, 1.4 + 0.6 * breath + 2.0 * tell + 1.0 * hurt)
	orient(_heart, middle, frame * Vector3.UP, HEART_M * (1.0 + 0.3 * tell), HEART_M * 0.9)
	brighten(_heart, 2.2 + 1.0 * breath + 3.0 * tell + 2.0 * hurt)
	# The cells: two bands turning against each other; in tight for the tell, out in the burst; a forked cell popping.
	var shell := _shell * (1.0 + 0.04 * breath - 0.2 * tell + 0.25 * burst + 0.12 * hurt)
	for i in _cells.size():
		var spin := Basis(Vector3.UP, _turned * (1.4 if _bands[i] == 0 else -1.4))
		var dir: Vector3 = frame * (spin * _dirs[i])
		var out := shell + (0.45 * sin(PI * fork) if i == _fork_cell else 0.0)
		var at := middle + dir * out
		var side := dir.cross(Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).normalized()
		lay(_cells[i], at, DaemonArt.plank(side, side.cross(dir)) * Basis.from_scale(CELL))  # its face (Y) outward
		var on := i < lit
		orient(_lights[i], at + dir * CELL.y * 0.8, dir, CELL_LIGHT * (1.3 if on else 0.8), CELL_LIGHT)
		brighten(_lights[i], (2.4 if on else 0.35) + 2.5 * tell + (3.0 * fork if i == _fork_cell else 0.0))
	# The antennae: blades over the top, leaning out, trembling in the tell.
	for k in _antennae.size():
		var a := TAU * float(k) / float(_antennae.size()) + 0.4
		var root := middle + frame * Vector3(cos(a) * 0.25, CORE_H + gap, sin(a) * 0.25)
		var lean := 0.35 + 0.15 * sin(t * 1.3 + k) + 0.25 * tell * sin(t * 30.0 + k)
		var tip := root + frame * Vector3(cos(a) * sin(lean), cos(lean), sin(a) * sin(lean)) * ANTENNA_L * (1.0 - 0.2 * float(k % 2))
		bone(_antennae[k], root, tip, 0.07, 0.02, frame * Vector3(-sin(a), 0.0, cos(a)))


## How hurt it is, 0 whole to 1 at death's door.
func _hurt() -> float:
	if _target == null or not _target.has_method("health") or not ("max_health" in _target):
		return 0.0
	return clampf(1.0 - float(_target.health()) / maxf(float(_target.max_health), 0.001), 0.0, 1.0)


## A drone forked out of it: one cell pops out and flares.
func fork_flash() -> void:
	_fork_at = clock()
	_fork_cell = (_fork_cell + 7) % maxi(_cells.size(), 1)


## Where a forked drone comes out (world space): the cell that popped.
func hub() -> Vector3:
	var local: Vector3 = _xf[_cells[_fork_cell]].origin if _cells.size() > _fork_cell else Vector3.ZERO
	return global_transform * local if is_inside_tree() else transform * local


## Where its lineage line meets it (world space): its heart.
func anchor() -> Vector3:
	return global_transform * Vector3.ZERO if is_inside_tree() else transform.origin


func body_box() -> Transform3D:
	return Transform3D.IDENTITY


func body_box_size() -> Vector3:
	return BOX
