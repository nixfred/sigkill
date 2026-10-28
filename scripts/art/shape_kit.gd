class_name ShapeKit
extends RefCounted
## Low-poly shapes for SIGKILL's procedural art (A1's viewmodels, A2's daemons): boxes, prisms,
## tubes, spikes and a ">" glyph, written into buckets that each become one mesh surface. Built
## once, merged, never rebuilt while drawn: original geometry, no model, texture or font files.
##
## A bucket is a SurfaceTool with a pivot: shapes are given in the art's own space, through the
## kit's pose, and land relative to their bucket's pivot, so a bucket made into a node of its own
## can turn about that pivot. Godot draws clockwise triangles as front faces, so every triangle
## is wound against its outward normal. Shapes with more sides than FACETED_SIDES are shaded
## smooth, the rest faceted.
##
## An edged bucket (A2) also carries, in CUSTOM0, each vertex's barycentric place in its triangle,
## with the triangle's inner edges (a quad's diagonal, a fan's spokes) pushed out of reach, so a
## shader can draw the shapes' true edges as lines and never their triangulation.

## Shapes with more sides than this are shaded smooth; the rest are faceted.
const FACETED_SIDES := 8

## How the art is held: every shape and pivot is placed through it.
var pose := Transform3D.IDENTITY

var _tools: Array[SurfaceTool] = []
var _counts: Array[int] = []
var _pivots: Array[Vector3] = []
var _edged: Array[bool] = []


## A new bucket, its shapes relative to `pivot` (in the art's space, through the pose), carrying
## its true edges when `edged`. Returns its id for the shapes.
func bucket(pivot: Vector3 = Vector3.ZERO, edged: bool = false) -> int:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if edged:
		st.set_custom_format(0, SurfaceTool.CUSTOM_RGB_FLOAT)
	_tools.append(st)
	_counts.append(0)
	_pivots.append(pose * pivot)
	_edged.append(edged)
	return _tools.size() - 1


## Where bucket `id`'s pivot is, through the pose.
func pivot(id: int) -> Vector3:
	return _pivots[id]


## Vertices written into bucket `id` so far.
func count(id: int) -> int:
	return _counts[id]


## Bucket `id` as a surface: appended to `into` when given, else a new mesh. Empty buckets add
## nothing.
func commit(id: int, into: ArrayMesh = null) -> ArrayMesh:
	var out := into if into != null else ArrayMesh.new()
	if _counts[id] > 0:
		_tools[id].commit(out)
	return out


## A box of `size` centred on `center`, turned by `turn` (degrees about X, Y and Z).
func box(into: int, center: Vector3, size: Vector3, turn: Vector3 = Vector3.ZERO) -> void:
	var h := size * 0.5
	var b := basis(turn)
	for axis in 3:
		for side in [-1.0, 1.0]:
			var n := Vector3.ZERO
			n[axis] = side
			var u := Vector3.ZERO
			u[(axis + 1) % 3] = 1.0
			var v := Vector3.ZERO
			v[(axis + 2) % 3] = 1.0
			var corners := []
			for c in [[-1.0, -1.0], [1.0, -1.0], [1.0, 1.0], [-1.0, 1.0]]:
				corners.append(center + b * ((n + u * c[0] + v * c[1]) * h))
			_face(into, corners, b * n)


## A prism of `sides` round the local Z axis, `length` long and centred on `center`: radius at
## the back (+Z) and `end_radius` at the front (-Z), the same when below 0. `phase` turns its
## corners, in degrees. Many sides make a cylinder; a different end radius a cone or a frustum.
func prism(into: int, center: Vector3, radius: float, length: float, sides: int, turn: Vector3 = Vector3.ZERO, end_radius: float = -1.0, phase: float = 0.0) -> void:
	var b := basis(turn)
	var front_r := radius if end_radius < 0.0 else end_radius
	var back := []
	var front := []
	var dirs := []
	for i in sides:
		var a := TAU * i / sides + deg_to_rad(phase)
		var d := Vector3(cos(a), sin(a), 0.0)
		dirs.append(b * d)
		back.append(center + b * (d * radius + Vector3(0.0, 0.0, length * 0.5)))
		front.append(center + b * (d * front_r + Vector3(0.0, 0.0, -length * 0.5)))
	for i in sides:
		var j := (i + 1) % sides
		if sides > FACETED_SIDES:
			_smooth_quad(into, [back[i], back[j], front[j], front[i]], [dirs[i], dirs[j], dirs[j], dirs[i]])
		else:
			_face(into, [back[i], back[j], front[j], front[i]], (dirs[i] + dirs[j]))
	_face(into, back, b * Vector3.BACK)
	_face(into, front, b * Vector3.FORWARD)


## A ring round the local Z axis, `length` deep: a coil, a band or a muzzle's lip. `phase` turns
## its corners, in degrees, to match a prism's.
func tube(into: int, center: Vector3, inner: float, outer: float, length: float, sides: int, turn: Vector3 = Vector3.ZERO, phase: float = 0.0) -> void:
	var b := basis(turn)
	var rings := []  # back outer, front outer, back inner, front inner
	var dirs := []
	for i in sides:
		var a := TAU * i / sides + deg_to_rad(phase)
		var d := Vector3(cos(a), sin(a), 0.0)
		dirs.append(b * d)
		rings.append([
			center + b * (d * outer + Vector3(0.0, 0.0, length * 0.5)),
			center + b * (d * outer + Vector3(0.0, 0.0, -length * 0.5)),
			center + b * (d * inner + Vector3(0.0, 0.0, length * 0.5)),
			center + b * (d * inner + Vector3(0.0, 0.0, -length * 0.5)),
		])
	for i in sides:
		var j := (i + 1) % sides
		var p: Array = rings[i]
		var q: Array = rings[j]
		_face(into, [p[0], q[0], q[1], p[1]], dirs[i] + dirs[j])
		_face(into, [p[2], q[2], q[3], p[3]], -(dirs[i] + dirs[j]))
		_face(into, [p[0], q[0], q[2], p[2]], b * Vector3.BACK)
		_face(into, [p[1], q[1], q[3], p[3]], b * Vector3.FORWARD)


## A spike from `from` to `to`: two cones of `sides` meeting at a ring of `radius`, `waist` of
## the way along (0.5 makes a bipyramid, a gem; a small waist a dart or a shard). `phase` turns
## the ring, in degrees. Few sides make it faceted: obsidian shards, drones, cores.
func spike(into: int, from: Vector3, to: Vector3, radius: float, sides: int, waist: float = 0.5, phase: float = 0.0) -> void:
	var along := to - from
	if along.is_zero_approx():
		return
	var axis := along.normalized()
	var side := axis.cross(Vector3.UP if absf(axis.y) < 0.98 else Vector3.RIGHT).normalized()
	var other := axis.cross(side)
	var middle := from + along * waist
	var ring := []
	for i in sides:
		var a := TAU * i / sides + deg_to_rad(phase)
		ring.append(middle + (side * cos(a) + other * sin(a)) * radius)
	for i in sides:
		var j := (i + 1) % sides
		var mid: Vector3 = (ring[i] + ring[j]) * 0.5 - middle
		_face(into, [ring[i], ring[j], to], mid + axis * radius)
		_face(into, [ring[j], ring[i], from], mid - axis * radius)


## A ">" of two bars, `size` tall, on a side face: flat against the plane x = at.x, its tip toward
## -Z with `toward` -1 or +Z with +1, `thick` out from the face. Seen from the eye, on the left
## face of a held weapon, +Z reads as ">" and -Z as "<".
func chevron(into: int, at: Vector3, size: float, toward: float = -1.0, thick: float = 0.002) -> void:
	var bar := Vector3(thick, size * 0.16, size * 0.62)
	box(into, at + Vector3(0.0, size * 0.21, -toward * size * 0.12), bar, Vector3(36.0 * toward, 0.0, 0.0))
	box(into, at + Vector3(0.0, -size * 0.21, -toward * size * 0.12), bar, Vector3(-36.0 * toward, 0.0, 0.0))


## A turn given in degrees about X, Y and Z, as a basis.
static func basis(turn: Vector3) -> Basis:
	return Basis.from_euler(Vector3(deg_to_rad(turn.x), deg_to_rad(turn.y), deg_to_rad(turn.z)))


## A flat polygon facing `outward`, as a fan from its first corner: the fan's spokes are inner
## edges, its rim the polygon's own.
func _face(into: int, corners: Array, outward: Vector3) -> void:
	var n := _normal(corners, outward)
	var last := corners.size() - 1
	for i in range(1, last):
		# Opposite corner 0 is the rim edge (i, i+1); opposite i the spoke to i+1; opposite i+1 the
		# spoke to i. A spoke is the polygon's own edge only at the fan's two ends.
		_tri(into, [corners[0], corners[i], corners[i + 1]], [n, n, n], n, Vector3(0.0, 0.0 if i + 1 == last else 1.0, 0.0 if i == 1 else 1.0))


func _smooth_quad(into: int, corners: Array, normals: Array) -> void:
	var outward: Vector3 = normals[0] + normals[2]
	_tri(into, [corners[0], corners[1], corners[2]], [normals[0], normals[1], normals[2]], outward, Vector3(0.0, 1.0, 0.0))
	_tri(into, [corners[0], corners[2], corners[3]], [normals[0], normals[2], normals[3]], outward, Vector3(0.0, 0.0, 1.0))


## One triangle wound against `outward`. `inner` marks which of its edges are inner ones (the edge
## opposite corner k when inner[k] is 1), for an edged bucket.
func _tri(into: int, v: Array, n: Array, outward: Vector3, inner: Vector3 = Vector3.ZERO) -> void:
	var a: Vector3 = v[0]
	var b: Vector3 = v[1]
	var c: Vector3 = v[2]
	var order := [0, 1, 2]
	if (b - a).cross(c - a).dot(outward) > 0.0:
		order = [0, 2, 1]
	var st := _tools[into]
	var edged := _edged[into]
	for k in order:
		st.set_normal((pose.basis * (n[k] as Vector3)).normalized())
		if edged:
			var place := inner
			place[k] += 1.0
			st.set_custom(0, Color(place.x, place.y, place.z))
		st.add_vertex(pose * (v[k] as Vector3) - _pivots[into])
	_counts[into] += 3


## A polygon's own normal (Newell's), turned to face `outward`.
static func _normal(corners: Array, outward: Vector3) -> Vector3:
	var n := Vector3.ZERO
	for i in corners.size():
		var p: Vector3 = corners[i]
		var q: Vector3 = corners[(i + 1) % corners.size()]
		n += Vector3((p.y - q.y) * (p.z + q.z), (p.z - q.z) * (p.x + q.x), (p.x - q.x) * (p.y + q.y))
	if n.is_zero_approx():
		return outward.normalized()
	n = n.normalized()
	return n if n.dot(outward) >= 0.0 else -n
