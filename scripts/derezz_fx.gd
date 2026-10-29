extends MultiMeshInstance3D
## Derezz: a dying daemon shatters into voxels.
##
## One MultiMeshInstance3D per derezz holds every voxel as an instance, so there is no node
## and no physics body per voxel, and DerezzTuning.max_voxels caps the count. The voxel
## mesh and material are shared by every derezz. Motion is scripted on the CPU: an outward
## burst from the body's centre plus a push along the killing shot, random spread, gravity,
## a ground bounce and a tumble, stepped at a fixed rate so it plays the same at any frame
## rate. Each voxel finds the real ground below it with a downward ray, measured again
## every step it moves sideways on the way down, so voxels that fly off a platform fall to
## the floor beneath and voxels that fly over a higher surface land on it. A voxel that
## settles and barely slides stops dead, so a settled derezz casts no more rays. Each voxel shrinks and fades along the fade curve, and the effect frees itself
## once its last voxel is gone. Colours come from palette.gd: a share
## of the voxels glow hostile red, the rest are obsidian. Cosmetic only.
##
## Since A2 each voxel is drawn with glowing Tron edges round a dimmer face and breaks up cell by
## cell as it fades (shaders/derezz_voxel.gdshader), and the death opens with a flash: a column of
## light up through the body and a ring along the ground, gone in FLASH_S, children of the effect so
## they go with it. The motion, the counts, the sizes, the colours and the timing are as they were.

const Palette = preload("res://scripts/palette.gd")
const Derezz = preload("res://scripts/derezz_tuning.gd")

## Every derezz joins this group, so tests can count what is still alive.
const FX_GROUP := &"derezz_fx"
## Most grid points ever considered for one derezz, so a tiny voxel size cannot stall a frame.
const MAX_CANDIDATES := 4096
# Geometry, not tunables.
const HALF := 0.5
const CUBE_ROOT := 1.0 / 3.0
const HEX_APOTHEM_PER_RADIUS := 0.8660254  # cos(30 degrees)
const HEX_SIDE_NORMALS := [Vector2(0.5, 0.8660254), Vector2(1.0, 0.0), Vector2(0.5, -0.8660254)]
# Simulation, not tunables: a fixed step keeps the motion identical at any frame rate.
const SIM_STEP := 1.0 / 60.0
const SIM_EPSILON := 0.000001
const MAX_STEPS_PER_FRAME := 8
## How far below a voxel to look for ground, in metres.
const PROBE_DEPTH := 60.0
## Impacts slower than this settle instead of bouncing, in m/s.
const REST_SPEED := 0.3
## A settled voxel sliding slower than this stops dead, in m/s.
const REST_SLIDE := 0.05
## The death's flash (A2): how long it lasts, in seconds; the column's radius and how much taller
## than the body it stands; how far the ground ring grows, as many times the body's radius.
const FLASH_S := 0.35
const COLUMN_RADIUS := 0.1
const COLUMN_STRETCH := 1.6
const RING_REACH := 3.0
## A voxel this far above a surface's top, in metres, is airborne rather than sliding on it.
const AIRBORNE_MARGIN := 0.001
## Surfaces whose normal points at least this far up count as tops a voxel can land on.
const TOP_NORMAL_Y := 0.7

static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}
static var _column_mesh: CylinderMesh
static var _ring_mesh: TorusMesh
## The flash's material for each colour it has been lit in (A5: a daemon's own), made once each.
static var _flash_materials: Dictionary = {}

var _d: Derezz
var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _axis := PackedVector3Array()
var _spin := PackedFloat32Array()
var _angle := PackedFloat32Array()
var _life := PackedFloat32Array()
var _fade := PackedFloat32Array()
var _color := PackedColorArray()
var _ground := PackedFloat32Array()  # local ground height under each voxel
var _probe_at := PackedVector2Array()  # local XZ where that ground was measured
var _age := 0.0
var _lifetime := 0.0
var _accumulator := 0.0
var _steps := 0
var _probes := 0  # ground rays cast so far, for tests
var _column: MeshInstance3D
## Its light's colour (A5): hostile red, or a daemon's own.
var _glow := Palette.HOSTILE_RED
var _ring: MeshInstance3D
var _radius := 0.0

## Test hook: the instance whose transform and colour, as last handed to the MultiMesh,
## are kept in captured_transform and captured_color. -1 keeps nothing. Under --headless
## the MultiMesh stores nothing to read back, so this is as close to it as a test can see.
var capture_instance := -1
var captured_transform := Transform3D()
var captured_color := Color()


## Starts the derezz of a hexagonal prism of `radius` and `height` whose base is at `base`.
## Call it after the node is in the tree. `shot_dir` is the horizontal direction the
## killing shot travelled in, or zero if unknown.
## A nonzero `rng_seed` makes the derezz repeatable, for tests. `color` is its light: hostile red
## for a player, a daemon's own colour for a daemon (A5).
func start(base: Vector3, radius: float, height: float, shot_dir: Vector3, d: Derezz, rng_seed: int = 0, color: Color = Palette.HOSTILE_RED) -> void:
	_d = d
	add_to_group(FX_GROUP)
	global_transform = Transform3D(Basis.IDENTITY, base)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rng := RandomNumberGenerator.new()
	if rng_seed != 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	var points := _hex_grid(radius, height, d.voxel_size)
	var count := mini(points.size(), d.max_voxels)
	# Partial Fisher-Yates shuffle: the first `count` points become a random sample.
	for i in count:
		var j := rng.randi_range(i, points.size() - 1)
		var swap := points[i]
		points[i] = points[j]
		points[j] = swap
	var centre := Vector3(0.0, height * HALF, 0.0)
	_glow = color
	var obsidian := Palette.BASE.lerp(color, d.obsidian_glow)
	for i in count:
		var p := points[i]
		var radial := Vector3(p.x - centre.x, 0.0, p.z - centre.z).normalized()
		var v := radial * d.burst_speed + Vector3.UP * (d.burst_up * rng.randf()) + shot_dir * d.hit_push
		v += Vector3(rng.randf_range(-d.spread, d.spread), rng.randf_range(-d.spread, d.spread), rng.randf_range(-d.spread, d.spread))
		var axis := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
		if axis.is_zero_approx():
			axis = Vector3.UP
		var life := rng.randf_range(d.lifetime_min, d.lifetime_max)
		_pos.append(p)
		_vel.append(v)
		_axis.append(axis.normalized())
		_spin.append(deg_to_rad(rng.randf_range(d.spin_min_degrees, d.spin_max_degrees)))
		_angle.append(rng.randf_range(0.0, TAU))
		_life.append(life)
		_fade.append(1.0)
		_ground.append(0.0)  # the dummy stood on this ground
		_probe_at.append(Vector2(p.x, p.z))
		_color.append(color if rng.randf() < d.glow_fraction else obsidian)
		_lifetime = maxf(_lifetime, life)
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = _voxel_mesh(d.voxel_size)
	multimesh.instance_count = count
	material_override = _voxel_material(d.glow_energy)
	_apply()
	if count == 0:
		queue_free()
		return
	_start_flash(radius, height)


## Number of voxels in this derezz.
func voxel_count() -> int:
	return _pos.size()


## Seconds from the start until the effect frees itself.
func lifetime() -> float:
	return _lifetime


func _physics_process(delta: float) -> void:
	if _d == null:
		return
	_age += delta
	_accumulator += delta
	var steps := 0
	while _accumulator >= SIM_STEP - SIM_EPSILON and steps < MAX_STEPS_PER_FRAME:
		_simulate(SIM_STEP)
		_accumulator -= SIM_STEP
		steps += 1
	if steps == MAX_STEPS_PER_FRAME:
		_accumulator = 0.0  # never try to catch up a long stall
	for i in _pos.size():
		_fade[i] = 1.0 - pow(clampf(_age / _life[i], 0.0, 1.0), _d.fade_power)
	_apply()
	_step_flash()
	if _age >= _lifetime:
		queue_free()


## The death's flash (A2): a column of light up through the body, as tall as COLUMN_STRETCH of it,
## and a ring on the ground at its foot. Children of this effect, so they go with it.
func _start_flash(radius: float, height: float) -> void:
	_radius = radius
	if _column_mesh == null:
		_column_mesh = CylinderMesh.new()
		_column_mesh.top_radius = 1.0
		_column_mesh.bottom_radius = 1.0
		_column_mesh.height = 1.0
		_column_mesh.radial_segments = 6
		_column_mesh.rings = 1
		_ring_mesh = TorusMesh.new()
		_ring_mesh.inner_radius = 0.9
		_ring_mesh.outer_radius = 1.0
		_ring_mesh.rings = 24
		_ring_mesh.ring_segments = 4
	_column = _flash_node("Column", _column_mesh, Vector3(0.0, height * COLUMN_STRETCH * HALF, 0.0))
	_column.scale = Vector3(COLUMN_RADIUS, height * COLUMN_STRETCH, COLUMN_RADIUS)
	_ring = _flash_node("Ring", _ring_mesh, Vector3(0.0, 0.02, 0.0))
	_ring.scale = Vector3.ONE * radius
	_step_flash()


## The flash's material in `color`, made the first time it is asked for (A5).
static func _flash_of(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _flash_materials.has(key):
		var mat := Palette.unlit_glow(color, Palette.DEREZZ_FLASH_ENERGY)
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_flash_materials[key] = mat
	return _flash_materials[key]


func _flash_node(node_name: String, mesh: Mesh, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = _flash_of(_glow)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = at
	add_child(node)
	return node


## The flash at this age: the column thinning, the ring spreading, both fading out by FLASH_S.
func _step_flash() -> void:
	if _column == null:
		return
	var t := clampf(_age / FLASH_S, 0.0, 1.0)
	_column.visible = t < 1.0
	_ring.visible = t < 1.0
	_column.scale.x = COLUMN_RADIUS * (1.0 - t) + 0.0001
	_column.scale.z = _column.scale.x
	_column.transparency = t
	_ring.scale = Vector3.ONE * _radius * (1.0 + (RING_REACH - 1.0) * t)
	_ring.transparency = t


## Whether the death's flash still shows (A2).
func flashing() -> bool:
	return _column != null and _column.visible


func _simulate(step: float) -> void:
	_steps += 1
	var space := get_world_3d().direct_space_state
	var fall := Vector3.DOWN * (_d.gravity * step)
	var rest := _d.voxel_size * HALF
	for i in _pos.size():
		var v := _vel[i] + fall
		var p := _pos[i] + v * step
		var xz := Vector2(p.x, p.z)
		var floor_y := _ground[i] + rest
		# Measure the ground again every step a descending voxel has moved sideways at all:
		# only a descending voxel can land, and one that only moves up and down keeps its
		# ground. Measuring before it can sink means the ray, which starts above the higher of
		# the old and new height, never starts inside the surface the voxel is about to hit.
		if v.y < 0.0 and xz != _probe_at[i]:
			var was := _ground[i]
			_ground[i] = _ground_below(space, Vector3(p.x, maxf(_pos[i].y, p.y), p.z))
			_probe_at[i] = xz
			# An airborne voxel that passed a higher surface's edge this step while dipping
			# below its top may have crossed that top before it passed the edge: sweep the
			# step to find out. A voxel sliding off an edge was on the top, not above it, so
			# it drops without a sweep: that costs no ray, and it never depends on whether
			# its height rounds a hair above the top, where a sweep would catch it on the edge.
			if _ground[i] < was and p.y < was + rest and _pos[i].y > was + rest + AIRBORNE_MARGIN:
				var top := _top_crossed(space, _pos[i] + Vector3.DOWN * rest, p + Vector3.DOWN * rest)
				if not top.is_empty():
					var at: Vector3 = (top["position"] as Vector3) - global_position
					p.x = at.x
					p.z = at.z
					_ground[i] = at.y
					_probe_at[i] = Vector2(at.x, at.z)
			floor_y = _ground[i] + rest
		if p.y < floor_y:
			p.y = floor_y
			if v.y < 0.0:
				var impact := -v.y
				v.y = impact * _d.bounce if impact > REST_SPEED else 0.0
				v.x *= _d.ground_friction
				v.z *= _d.ground_friction
				if v.y == 0.0 and Vector2(v.x, v.z).length() < REST_SLIDE:
					v.x = 0.0  # settled and barely sliding: stop dead
					v.z = 0.0
		_vel[i] = v
		_pos[i] = p
		_angle[i] = wrapf(_angle[i] + _spin[i] * step, 0.0, TAU)


## Local height of the first world surface below the local point `p`, or -INF if none.
func _ground_below(space: PhysicsDirectSpaceState3D, p: Vector3) -> float:
	var from := global_position + Vector3(p.x, p.y + _d.voxel_size, p.z)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * PROBE_DEPTH, _d.ground_mask)
	_probes += 1
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return -INF
	return (hit["position"] as Vector3).y - global_position.y


## The first upward-facing world surface crossed going from local point `from` to `to`,
## as a ray hit, or an empty dictionary if there is none. Sides are ignored.
func _top_crossed(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	_probes += 1
	var query := PhysicsRayQueryParameters3D.create(global_position + from, global_position + to, _d.ground_mask)
	var hit := space.intersect_ray(query)
	if hit.is_empty() or (hit["normal"] as Vector3).y < TOP_NORMAL_Y:
		return {}
	return hit


func _apply() -> void:
	for i in _pos.size():
		var s := _fade[i]
		var xf := Transform3D(Basis(_axis[i], _angle[i]).scaled(Vector3(s, s, s)), _pos[i])
		var c := _color[i]
		c.a = s
		multimesh.set_instance_transform(i, xf)
		multimesh.set_instance_color(i, c)
		if i == capture_instance:
			captured_transform = xf
			captured_color = c


## Voxel centres filling a hexagonal prism (vertices at 0, 60, 120 degrees from +Z, the way
## CylinderMesh builds it) from y = 0 to `height`, in the effect's local space.
static func _hex_grid(radius: float, height: float, size: float) -> PackedVector3Array:
	var apothem := radius * HEX_APOTHEM_PER_RADIUS
	var box_volume := (radius + radius) * (radius + radius) * height
	var step := maxf(size, pow(box_volume / MAX_CANDIDATES, CUBE_ROOT))
	var out := PackedVector3Array()
	var x := -radius + step * HALF
	while x < radius:
		var z := -radius + step * HALF
		while z < radius:
			var xz := Vector2(x, z)
			var inside := true
			for n in HEX_SIDE_NORMALS:
				if absf(xz.dot(n)) > apothem:
					inside = false
					break
			if inside:
				var y := step * HALF
				while y < height:
					out.append(Vector3(x, y, z))
					y += step
			z += step
		x += step
	return out


static func _voxel_mesh(size: float) -> BoxMesh:
	if not _meshes.has(size):
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE * size
		_meshes[size] = mesh
	return _meshes[size]


static func _voxel_material(energy: float) -> ShaderMaterial:
	if not _materials.has(energy):
		_materials[energy] = Palette.derezz_voxel_material(energy)
	return _materials[energy]
