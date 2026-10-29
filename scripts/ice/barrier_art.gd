extends IceArt
## White ICE's wall (I1): a barrier sealing a doorway or a corridor of the arena until it is broken.
## Faceted crystal panes held in a crystal lattice: a dark glass backing filling the whole opening,
## a frame of double-terminated crystal bars round it and struts between the panes, each cell's pane a
## cut crystal standing proud of the backing on both faces (each tilted a little its own way, so every
## facet takes the light differently), the ICE's light in the seams beside every strut, a joint of light
## where the struts cross, a lock at its heart (a core of light in a ring on each face, crystal teeth
## pointing at it: its weak point, with the joints), a crystal pylon at each end with bands of light,
## a plinth along the floor and a crown of crystal spikes along its top. Glacier blue.
##
## A hit sprays glacier shards where it struck but never flashes the whole wall (flash()). It cracks as
## it takes damage (set_damage()): each pane's crack starts at a share of the damage of
## its own and spreads across it, the backing and the struts after them; past a share of their own,
## some panes break out and fall from the lattice, so a wall near breaking is open-celled, its backing
## lit by cracks. Its seed rolls the cells (how many across and up), the bars' and struts' thickness,
## how far the panes stand out and how each is tilted, the lock's place and size, the pylons and their
## bands, the crown's spikes, the panes already chipped (battle damage), the joints that flicker, and
## which panes break out and when. Static: it is posed again only when its damage changes or a pane is
## falling, never every frame.
##
## Art space: the opening's middle at the floor is (0, GROUND_Y, 0), its width along X, its height up
## +Y, its two faces toward -Z and +Z. `span` (width, height) and `depth` are set before setup().

## The opening it fills: width and height, metres; how thick the wall is.
var span := Vector2(2.7, 3.5)
var depth := 0.36

var _cols := 3
var _rows := 4
var _frame := 0.16
var _strut := 0.08
var _pane_t := 0.16
var _plinth := 0.12
var _lock := Vector2i(1, 2)
var _lock_r := 0.36

var _backing := -1
var _panes: Array[int] = []
var _pane_xf: Array[Transform3D] = []
var _pane_out := PackedVector3Array()
var _pane_start := PackedFloat32Array()
var _pane_fall := PackedFloat32Array()
var _pane_chip := PackedFloat32Array()
var _pane_fell := PackedFloat32Array()
var _bars: Array[int] = []
var _bar_xf: Array[Transform3D] = []
var _lights: Array[int] = []
var _lights_xf: Array[Transform3D] = []
var _heart := -1
var _rings: Array[int] = []
var _rest_xf: Array[Transform3D] = []
var _rest: Array[int] = []

var _damage := 0.0
var _dirty := true
var _falling := 0

## A pane breaks out of the lattice over this long, sliding this far out of its face.
const FALL_S := 0.35
const FALL_OUT_M := 0.3
## A pane's crack spreads across it over this share of the wall's damage once it has started.
const CRACK_SPAN := 0.45


func _build() -> void:
	_ice_start()
	ice_color = Palette.GLACIER
	core_color = ice_color
	edge_color = ice_color
	glyph_count = 0
	budget_triangles = 4000
	budget_draw_calls = 16
	ai_kind = "barrier"
	var w := span.x
	var h := span.y
	reach = AABB(Vector3(-w * 0.5 - 0.6, GROUND_Y - 0.3, -depth - 0.8), Vector3(w + 1.2, h + 1.8, depth * 2.0 + 1.6))
	tag_height = h + 0.4
	_frame = lerpf(0.13, 0.2, dice(1, 0))
	_strut = lerpf(0.06, 0.1, dice(2, 0))
	_pane_t = lerpf(0.12, 0.2, dice(3, 0))
	_cols = maxi(2, roundi((w - 2.0 * _frame) / lerpf(0.8, 1.05, dice(4, 0))))
	_rows = maxi(2, roundi((h - _plinth - 2.0 * _frame) / lerpf(0.72, 1.0, dice(5, 0))))
	_lock = Vector2i(_cols / 2 - (pick(6, 0, 0, 1) if _cols % 2 == 0 else 0), _rows / 2 - (pick(7, 0, 0, 1) if _rows % 2 == 0 else 0))
	var inner := Vector2(w - 2.0 * _frame, h - _plinth - 2.0 * _frame)
	var cell := Vector2(inner.x / _cols, inner.y / _rows)
	_lock_r = minf(cell.x, cell.y) * lerpf(0.3, 0.38, dice(8, 0))
	var y0 := GROUND_Y + _plinth + _frame
	var x0 := -inner.x * 0.5
	var back_t := 0.1
	# The backing: one slab of the dark glass filling the opening, a little thinner than the wall.
	_backing = part(Shape.PLATE, Look.ICE)
	_rest.append(_backing)
	_rest_xf.append(Transform3D(Basis(Vector3.RIGHT * inner.x, Vector3.FORWARD * back_t, Vector3.UP * inner.y), Vector3(0.0, y0 + inner.y * 0.5, 0.0)))
	# The panes, both faces of every cell but the lock's.
	var chips := pick(9, 0, 0, 2)
	for c in _cols:
		for r in _rows:
			if Vector2i(c, r) == _lock:
				continue
			var middle := Vector3(x0 + (c + 0.5) * cell.x, y0 + (r + 0.5) * cell.y, 0.0)
			for side in [1.0, -1.0]:
				var k := _panes.size()
				var id := part(Shape.FACET, Look.ICE)
				_panes.append(id)
				var tilt := Basis(Vector3.UP, (dice(20 + k, 1) - 0.5) * 0.24) * Basis(Vector3.RIGHT, (dice(20 + k, 2) - 0.5) * 0.2)
				var face := tilt * plank(Vector3.RIGHT * -side, Vector3.UP)
				var lift := _pane_t * lerpf(0.85, 1.25, dice(20 + k, 3))
				var basis := Basis(face.x * cell.x * 0.94, face.y * lift, face.z * cell.y * 0.94)
				var at: Vector3 = middle + Vector3.BACK * side * (back_t * 0.5 + lift * 0.5 - 0.01)
				_pane_xf.append(Transform3D(basis, at))
				_pane_out.append(Vector3.BACK * side)
				_pane_start.append(dice(20 + k, 4) * 0.45)
				# About two panes in three break out of the lattice, each past its own share of damage.
				_pane_fall.append(0.5 + dice(20 + k, 5) * 0.42 if dice(20 + k, 6) < 0.66 else 2.0)
				_pane_chip.append(lerpf(0.12, 0.3, dice(20 + k, 7)) if dice(9, k) < chips * 0.08 else 0.0)
				_pane_fell.append(-1.0)
	# The frame: four crystal bars round the opening, their points crossing at the corners.
	var bar_d := depth + 0.12
	var left := -w * 0.5 + _frame * 0.5
	var top := GROUND_Y + h - _frame * 0.5
	var bottom := GROUND_Y + _plinth + _frame * 0.5
	for pair in [[Vector3(left, GROUND_Y + _plinth - 0.05, 0.0), Vector3(left, GROUND_Y + h + 0.08, 0.0)], [Vector3(-left, GROUND_Y + _plinth - 0.05, 0.0), Vector3(-left, GROUND_Y + h + 0.08, 0.0)], [Vector3(-w * 0.5 - 0.08, top, 0.0), Vector3(w * 0.5 + 0.08, top, 0.0)], [Vector3(-w * 0.5 - 0.08, bottom, 0.0), Vector3(w * 0.5 + 0.08, bottom, 0.0)]]:
		_bar(pair[0], pair[1], bar_d, _frame)
	# The struts between the cells, through both faces.
	for c in range(1, _cols):
		var x := x0 + c * cell.x
		_bar(Vector3(x, y0 - _frame * 0.4, 0.0), Vector3(x, y0 + inner.y + _frame * 0.4, 0.0), depth + 0.04, _strut)
		_seam(Vector3(x, y0 + inner.y * 0.5, 0.0), Vector3.UP, inner.y, back_t)
	for r in range(1, _rows):
		var y := y0 + r * cell.y
		_bar(Vector3(x0 - _frame * 0.4, y, 0.0), Vector3(-x0 + _frame * 0.4, y, 0.0), depth + 0.04, _strut)
		_seam(Vector3(0.0, y, 0.0), Vector3.RIGHT, inner.x, back_t)
	# The seams just inside the frame, all the way round.
	_seam(Vector3(x0, y0 + inner.y * 0.5, 0.0), Vector3.UP, inner.y, back_t)
	_seam(Vector3(-x0, y0 + inner.y * 0.5, 0.0), Vector3.UP, inner.y, back_t)
	_seam(Vector3(0.0, y0, 0.0), Vector3.RIGHT, inner.x, back_t)
	_seam(Vector3(0.0, y0 + inner.y, 0.0), Vector3.RIGHT, inner.x, back_t)
	# A joint of light where the struts cross, poking through both faces; a few flicker.
	var flickers := pick(10, 0, 0, 2)
	for c in range(1, _cols):
		for r in range(1, _rows):
			var id := weak(part(Shape.GEM, Look.ICE_LIGHT))
			seam(id)
			if flickers > 0 and dice(11, c * 7 + r) < 0.3:
				flicker(id, lerpf(0.25, 0.6, dice(12, c * 7 + r)))
				flickers -= 1
			_light(id, Transform3D(_axes(Vector3.BACK, 0.12, depth + 0.22, 0.12, Vector3.ZERO), Vector3(x0 + c * cell.x, y0 + r * cell.y, 0.0)))
	# The lock: a core of light through the wall in its cell, a ring round it on each face, and
	# crystal teeth from the cell's corners pointing at it.
	var heart_at := Vector3(x0 + (_lock.x + 0.5) * cell.x, y0 + (_lock.y + 0.5) * cell.y, 0.0)
	_heart = weak(part(Shape.GEM, Look.ICE_LIGHT))
	_light(_heart, Transform3D(_axes(Vector3.BACK, _lock_r, depth + 0.3, _lock_r, Vector3.ZERO), heart_at))
	for side in [1.0, -1.0]:
		var ring := weak(part(Shape.RING, Look.ICE_LIGHT))
		_rings.append(ring)
		seam(ring)
		_light(ring, Transform3D(_axes(Vector3.BACK, _lock_r * 2.4, 0.07, _lock_r * 2.4, Vector3.ZERO), heart_at + Vector3.BACK * side * (back_t * 0.5 + 0.06)))
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var tooth := part(Shape.SHARD, Look.ICE)
			var from := heart_at + Vector3(corner.x * cell.x * 0.46, corner.y * cell.y * 0.46, side * back_t * 0.5)
			var to := heart_at + Vector3(corner.x * _lock_r * 1.5, corner.y * _lock_r * 1.5, side * (back_t * 0.5 + 0.08))
			_rest.append(tooth)
			_rest_xf.append(Transform3D(_axes(to - from, 0.1, from.distance_to(to), 0.06, Vector3.BACK), from))
	# The pylons at both ends, with bands of light.
	var pylon_top := GROUND_Y + h + lerpf(0.3, 0.65, dice(13, 0))
	for side in [-1.0, 1.0]:
		var id := part(Shape.PRISM, Look.ICE)
		_rest.append(id)
		_rest_xf.append(Transform3D(_axes(Vector3.UP, depth + 0.16, pylon_top - GROUND_Y + 0.2, 0.26, Vector3.ZERO), Vector3(side * (w * 0.5 + 0.04), GROUND_Y - 0.1, 0.0)))
		var bands := pick(14, int(side + 1.0), 2, 3)
		for b in bands:
			var band := part(Shape.RING, Look.ICE_LIGHT)
			seam(band)
			var y := lerpf(GROUND_Y + 0.5, pylon_top - 0.5, (b + 0.5) / bands + (dice(15, b + int(side + 1.0) * 5) - 0.5) * 0.12)
			_light(band, Transform3D(_axes(Vector3.UP, depth + 0.24, 0.06, 0.34, Vector3.ZERO), Vector3(side * (w * 0.5 + 0.04), y, 0.0)))
	# The plinth along the floor.
	var plinth := part(Shape.PLATE, Look.ICE)
	_rest.append(plinth)
	_rest_xf.append(Transform3D(Basis(Vector3.RIGHT * (w + 0.1), Vector3.UP * _plinth, Vector3.BACK * (depth + 0.22)), Vector3(0.0, GROUND_Y + _plinth * 0.5, 0.0)))
	# The crown: crystal spikes along the top, each its own height and lean.
	var spikes := pick(16, 0, 3, 7)
	for i in spikes:
		var id := part(Shape.SHARD, Look.ICE)
		var x := lerpf(-w * 0.45, w * 0.45, (i + 0.5) / spikes + (dice(17, i) - 0.5) * 0.5 / spikes)
		var tall := lerpf(0.22, 0.85, dice(18, i))
		var lean := Vector3((dice(19, i) - 0.5) * 0.3, 0.0, (dice(19, i + 40) - 0.5) * 0.2)
		var from := Vector3(x, GROUND_Y + h - 0.06, 0.0)
		_rest.append(id)
		_rest_xf.append(Transform3D(_axes(Vector3.UP * tall + lean, lerpf(0.12, 0.2, dice(18, i + 40)), (Vector3.UP * tall + lean).length(), lerpf(0.1, 0.16, dice(18, i + 80)), Vector3.ZERO), from))


## A crystal bar from `from` to `to`, `wide` through the wall and `thick` in its plane.
func _bar(from: Vector3, to: Vector3, wide: float, thick: float) -> void:
	var id := part(Shape.PRISM, Look.ICE)
	_bars.append(id)
	_bar_xf.append(Transform3D(_axes(to - from, wide, from.distance_to(to), thick, Vector3.ZERO), from))


## A seam of light centred on `at`, `length` along `along`, a little wider than a strut and through
## the backing on both faces, so it shows as a line of light either side of the strut.
func _seam(at: Vector3, along: Vector3, length: float, back_t: float) -> void:
	var id := seam(part(Shape.PLATE, Look.ICE_LIGHT))
	var across := Vector3.RIGHT if along == Vector3.UP else Vector3.UP
	_light(id, Transform3D(Basis(across * (_strut + 0.035), along.cross(across) * (back_t + 0.04), along * length), at))


func _light(id: int, xf: Transform3D) -> void:
	_lights.append(id)
	_lights_xf.append(xf)


# --- What the wall tells it. ---

## A wall never flashes whole at a hit: lit at once, its many seams would bloom into a white sheet
## under sustained fire. Its feedback is the spray of shards where the shot struck (react()) and its
## cracks deepening (set_damage()).
func flash() -> void:
	pass


## The wall's damage now, 0 whole to 1 broken: its cracks and falling panes follow.
func set_damage(amount: float) -> void:
	amount = clampf(amount, 0.0, 1.0)
	if amount == _damage:
		return
	_damage = amount
	_dirty = true


func damage() -> float:
	return _damage


## How many panes have broken out of the lattice.
func panes_out() -> int:
	var n := 0
	for at in _pane_fell:
		n += 1 if at >= 0.0 else 0
	return n


func pane_count() -> int:
	return _panes.size()


## The deepest crack on any pane now, 0 to 1.
func deepest_crack() -> float:
	var most := 0.0
	for id in _panes:
		most = maxf(most, part_custom(id).a)
	return most


func _pose(_t: float, _delta: float) -> void:
	if not _dirty and _falling == 0:
		return
	_dirty = false
	_falling = 0
	var f := _damage
	for i in _panes.size():
		var id := _panes[i]
		crack(id, maxf(_pane_chip[i], clampf((f - _pane_start[i]) / CRACK_SPAN, 0.0, 1.0)))
		if f >= _pane_fall[i] and _pane_fell[i] < 0.0:
			_pane_fell[i] = clock()
		if _pane_fell[i] < 0.0:
			put(id, _pane_xf[i])
			continue
		var u := clampf(since(_pane_fell[i]) / FALL_S, 0.0, 1.0)
		if u < 1.0:
			_falling += 1
		present(id, 1.0 - u)
		if u >= 1.0:
			conceal(id)
			continue
		var xf := _pane_xf[i]
		put(id, Transform3D(xf.basis.rotated(Vector3.RIGHT, u * 0.6), xf.origin + _pane_out[i] * FALL_OUT_M * u + Vector3.DOWN * 0.6 * u * u))
	for i in _bars.size():
		crack(_bars[i], clampf((f - 0.3) * 1.3, 0.0, 1.0))
		put(_bars[i], _bar_xf[i])
	for i in _rest.size():
		if _rest[i] == _backing:
			crack(_backing, clampf(f * 1.1, 0.0, 1.0))
		put(_rest[i], _rest_xf[i])
	for i in _lights.size():
		put(_lights[i], _lights_xf[i])
	# The lock burns brighter the nearer the wall is to breaking.
	brighten(_heart, 1.0 + 1.6 * f)
