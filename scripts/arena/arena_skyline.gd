class_name ArenaSkyline
extends Node3D
## The void round the arena (A3), so it never floats in black: a ring of dark megastructures rising
## out of the abyss with lit windows and teal edges, beacons blinking on their tops; a few giant data
## towers far out, beams of light standing up from them into the sky; an orbital ring hanging over the
## arena; and slabs drifting slowly round it, nearer than the towers, so they slide against them as
## the player moves. Original and procedural, from the shared shape kit; placed by a seeded random
## generator, so every run and every machine sees the same skyline. Visual only, nothing collides.
##
## Built once when it enters the tree into a few merged meshes and kept for the next arena, so a reload
## builds nothing; nothing is rebuilt while it is drawn. The ring and the two drifting groups turn
## by their nodes' transforms alone. The fog in the arena's environment fades all of it into the haze.

const Palette = preload("res://scripts/palette.gd")

## Budgets (A3), checked by tests/arena_art_test.gd. Draw calls: a surface each; none throws a shadow.
const BUDGET_TRIANGLES := 8000
const BUDGET_DRAW_CALLS := 12
## Bumped whenever the layout below changes.
const LAYOUT_VERSION := 1
const SEED := 0x51C1
## The tower ring: how many, from how near to how far (metres from the arena's middle), how deep their
## feet are in the abyss, and how high their tops stand over the arena for each metre away: enough to
## rise above the outer walls seen from the floor.
const TOWERS := 72
const TOWER_NEAR_M := 110.0
const TOWER_FAR_M := 430.0
const TOWER_FOOT_Y := -170.0
const TOWER_RISE := Vector2(0.14, 0.42)
## The giant data towers and the ring.
const GIANTS := 4
const RING_RADIUS_M := 180.0
const RING_HEIGHT_M := 150.0
const RING_TILT := Vector3(14.0, 0.0, 6.0)
## How fast the ring and the two drifting groups turn, in degrees a second.
const RING_TURN := 0.6
const DRIFT_TURN := 0.35
const DRIFT_B_TURN := -0.22

enum { TOWER, SLAB, TEAL, MINT, FLOW, BEACON, BUCKETS }
const LIGHTS := {TEAL: "teal", MINT: "mint", FLOW: "flow", BEACON: "beacon"}

static var _kept: Dictionary = {}

var _rng := RandomNumberGenerator.new()
var _ring: Node3D
var _drift: Node3D
var _drift_b: Node3D
var _fresh := false
## How far round the ring and the two drifting groups have turned, in radians, kept under a turn.
var _ring_angle := 0.0
var _drift_angle := 0.0
var _drift_b_angle := 0.0


func _ready() -> void:
	var key := str(LAYOUT_VERSION)
	var built: Dictionary = _kept.get(key, {})
	_fresh = built.is_empty()
	if _fresh:
		built = _build()
		_kept[key] = built
	_show("Towers", built["towers"], self)
	_ring = Node3D.new()
	_ring.name = "Ring"
	_ring.position = Vector3.UP * RING_HEIGHT_M
	_ring.basis = ShapeKit.basis(RING_TILT)
	add_child(_ring)
	_show("Mesh", built["ring"], _ring)
	_drift = Node3D.new()
	_drift.name = "Drift"
	add_child(_drift)
	_show("Mesh", built["drift"], _drift)
	_drift_b = Node3D.new()
	_drift_b.name = "DriftB"
	add_child(_drift_b)
	_show("Mesh", built["drift_b"], _drift_b)


## Turns the ring about its own upright and the drifting groups about the arena's, each set from its
## angle rather than turned by a step, so no error builds up in their bases however long it runs
## (self-review pass 1).
func _process(delta: float) -> void:
	_ring_angle = fposmod(_ring_angle + deg_to_rad(RING_TURN) * delta, TAU)
	_drift_angle = fposmod(_drift_angle + deg_to_rad(DRIFT_TURN) * delta, TAU)
	_drift_b_angle = fposmod(_drift_b_angle + deg_to_rad(DRIFT_B_TURN) * delta, TAU)
	_ring.basis = ShapeKit.basis(RING_TILT) * Basis(Vector3.UP, _ring_angle)
	_drift.basis = Basis(Vector3.UP, _drift_angle)
	_drift_b.basis = Basis(Vector3.UP, _drift_b_angle)


## The full skyline, or with `full` off the plain one (A4, the low preset): the tower ring alone,
## without the orbital ring and the two drifting groups of slabs. Nothing is made or freed: the
## parts are only hidden, and keep turning so they are where they belong when shown again.
func set_full(full: bool) -> void:
	for mover in [_ring, _drift, _drift_b]:
		(mover as Node3D).visible = full


func is_full() -> bool:
	return _ring.visible


## Every mesh node of the skyline, for the checks.
func mesh_nodes() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for node in find_children("*", "MeshInstance3D", true, false):
		out.append(node as MeshInstance3D)
	return out


## The turning parts, for the checks: the ring, then the two drifting groups.
func movers() -> Array[Node3D]:
	return [_ring, _drift, _drift_b]


## True when this skyline built its meshes, false when it took kept ones.
func built_fresh() -> bool:
	return _fresh


## Triangles in the whole skyline: its budget.
func triangles() -> int:
	var total := 0
	for node in mesh_nodes():
		var m := node.mesh as ArrayMesh
		for s in m.get_surface_count():
			total += m.surface_get_array_len(s) / 3
	return total


## Draw calls for the whole skyline: a surface each.
func draw_calls() -> int:
	var total := 0
	for node in mesh_nodes():
		total += node.mesh.get_surface_count()
	return total


func _show(node_name: String, mesh: ArrayMesh, parent: Node3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


# --- The build. ---

func _build() -> Dictionary:
	_rng.seed = SEED
	var towers := _new_kit()
	for i in TOWERS:
		_tower(towers, i)
	for i in GIANTS:
		_giant(towers, i)
	var ring := _new_kit()
	_orbital_ring(ring)
	var drift := _new_kit()
	var drift_b := _new_kit()
	for i in 7:
		_slab(drift, i)
	for i in 5:
		_shard(drift_b, i)
	return {"towers": _merge(towers), "ring": _merge(ring), "drift": _merge(drift), "drift_b": _merge(drift_b)}


static func _new_kit() -> ShapeKit:
	var kit := ShapeKit.new()
	for id in BUCKETS:
		kit.bucket(Vector3.ZERO, id == TOWER or id == SLAB)
	return kit


static func _merge(kit: ShapeKit) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for id in BUCKETS:
		if kit.count(id) > 0:
			kit.commit(id, mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, _material(id))
	return mesh


static func _material(id: int) -> Material:
	match id:
		TOWER:
			return Palette.arena_tower_material()
		SLAB:
			return Palette.arena_tower_material(false)
		_:
			return Palette.arena_light_material(LIGHTS[id])


## A point `r` metres out from the arena's middle, `angle` round, at height `y`.
static func _round(angle: float, r: float, y: float) -> Vector3:
	return Vector3(sin(angle) * r, y, cos(angle) * r)


## Tower `i` of the ring: one to three tiers, each set back from the one below, sometimes a spire,
## a beacon on top, and on some a lit strip up two corners of its first tier.
func _tower(kit: ShapeKit, i: int) -> void:
	var angle := TAU * i / TOWERS + _rng.randf_range(-0.03, 0.03)
	var r := lerpf(TOWER_NEAR_M, TOWER_FAR_M, pow(_rng.randf(), 0.75))
	var top := 1.6 + r * _rng.randf_range(TOWER_RISE.x, TOWER_RISE.y)
	var foot := _round(angle, r, TOWER_FOOT_Y)
	var size := Vector2(_rng.randf_range(9.0, 26.0), _rng.randf_range(9.0, 26.0))
	var base_size := size
	var turn := Vector3(0.0, _rng.randf_range(0.0, 90.0), 0.0)
	var tiers := _rng.randi_range(1, 3)
	var y := TOWER_FOOT_Y
	var first_top := top
	for t in tiers:
		var end := top if t == tiers - 1 else lerpf(y, top, _rng.randf_range(0.55, 0.8))
		kit.frustum(TOWER, Vector3(foot.x, y, foot.z), size, size * 0.97, end - y, turn)
		if t == 0:
			first_top = end
		y = end
		size *= _rng.randf_range(0.6, 0.8)
	if _rng.randf() < 0.3:
		var spire := _rng.randf_range(12.0, 40.0)
		kit.spike(TOWER, Vector3(foot.x, y - 1.0, foot.z), Vector3(foot.x, y + spire, foot.z), minf(size.x, size.y) * 0.35, 4, 0.05, turn.y + 45.0)
		y += spire
	kit.box(BEACON, Vector3(foot.x, y + 0.6, foot.z), Vector3.ONE * clampf(r * 0.008, 0.8, 2.5))
	if _rng.randf() < 0.35:
		var b := ShapeKit.basis(turn)
		var low := TOWER_FOOT_Y * 0.3
		for side in [-1.0, 1.0]:
			var corner := b * Vector3(side * base_size.x * 0.5, 0.0, base_size.y * 0.5)
			kit.box(TEAL, Vector3(foot.x + corner.x, (low + first_top) * 0.5, foot.z + corner.z), Vector3(0.6, first_top - low, 0.6), turn)


## Giant data tower `i`, far out: a broad battered shaft, a crown, and a beam of light standing up
## from it into the sky.
func _giant(kit: ShapeKit, i: int) -> void:
	var angle := TAU * (i + 0.5) / GIANTS + _rng.randf_range(-0.2, 0.2)
	var r := _rng.randf_range(520.0, 640.0)
	var top := _rng.randf_range(260.0, 380.0)
	var foot := _round(angle, r, TOWER_FOOT_Y * 1.5)
	var w := _rng.randf_range(32.0, 46.0)
	var turn := Vector3(0.0, _rng.randf_range(0.0, 90.0), 0.0)
	kit.frustum(TOWER, foot, Vector2(w, w), Vector2(w * 0.7, w * 0.7), top - foot.y, turn)
	kit.frustum(TOWER, Vector3(foot.x, top, foot.z), Vector2(w * 0.8, w * 0.8), Vector2(w * 0.3, w * 0.3), 18.0, turn)
	kit.prism(MINT, Vector3(foot.x, top + 618.0, foot.z), 1.2, 1200.0, 6, Vector3(90.0, 0.0, 0.0))
	for k in 6:
		kit.box(FLOW, Vector3(foot.x, top - 30.0 - k * 34.0, foot.z), Vector3(w * 0.76, 1.2, w * 0.76), turn)


## The orbital ring over the arena, in its own tilted frame: a band of dark segments with a line of
## mint lights round its inside, and four larger nodes on it.
func _orbital_ring(kit: ShapeKit) -> void:
	var sides := 72
	kit.tube(SLAB, Vector3.ZERO, RING_RADIUS_M - 3.0, RING_RADIUS_M + 3.0, 4.0, sides, Vector3(90.0, 0.0, 0.0))
	for i in sides:
		var a := TAU * (i + 0.5) / sides
		var at := Vector3(cos(a), 0.0, sin(a)) * (RING_RADIUS_M - 3.2)
		kit.box(MINT if i % 2 == 0 else TEAL, at, Vector3(2.0, 0.5, 2.0), Vector3(0.0, -rad_to_deg(a), 0.0))
	for i in 4:
		var a := TAU * i / 4.0 + 0.3
		var at := Vector3(cos(a), 0.0, sin(a)) * RING_RADIUS_M
		kit.box(SLAB, at, Vector3(14.0, 9.0, 14.0), Vector3(0.0, -rad_to_deg(a), 0.0))
		kit.box(BEACON, at + Vector3.UP * 5.3, Vector3.ONE * 1.6)


## Drifting slab `i`: a tall thin monolith leaning a little, nearer than the towers.
func _slab(kit: ShapeKit, i: int) -> void:
	var angle := TAU * i / 7.0 + _rng.randf_range(-0.25, 0.25)
	var at := _round(angle, _rng.randf_range(130.0, 240.0), _rng.randf_range(25.0, 80.0))
	var turn := Vector3(_rng.randf_range(-12.0, 12.0), _rng.randf_range(0.0, 180.0), _rng.randf_range(-12.0, 12.0))
	kit.box(SLAB, at, Vector3(_rng.randf_range(6.0, 10.0), _rng.randf_range(28.0, 46.0), _rng.randf_range(1.5, 3.0)), turn)


## Drifting shard `i`: an octahedron turned at random, its edges lit.
func _shard(kit: ShapeKit, i: int) -> void:
	var angle := TAU * (i + 0.3) / 5.0 + _rng.randf_range(-0.3, 0.3)
	var at := _round(angle, _rng.randf_range(110.0, 200.0), _rng.randf_range(40.0, 95.0))
	var tilt := Vector3(_rng.randf_range(-0.4, 0.4), 1.0, _rng.randf_range(-0.4, 0.4)).normalized()
	var length := _rng.randf_range(18.0, 34.0)
	kit.spike(SLAB, at - tilt * length * 0.5, at + tilt * length * 0.5, length * 0.3, 4, 0.5, _rng.randf_range(0.0, 90.0))
