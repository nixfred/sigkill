extends MultiMeshInstance3D
## Derezz: a dying daemon shatters into voxels.
##
## One MultiMeshInstance3D per derezz holds every voxel as an instance, so there is no node
## and no physics body per voxel, and DerezzTuning.max_voxels caps the count. The voxel
## mesh and material are shared by every derezz. Motion is scripted on the CPU: an outward
## burst from the body's centre plus a push along the killing shot, random spread, gravity,
## a ground bounce and a tumble. Each voxel shrinks and fades along the fade curve, and the
## effect frees itself once its last voxel is gone. Colours come from palette.gd: a share
## of the voxels glow hostile red, the rest are obsidian. Cosmetic only.

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

static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}

var _d: Derezz
var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _axis := PackedVector3Array()
var _spin := PackedFloat32Array()
var _angle := PackedFloat32Array()
var _life := PackedFloat32Array()
var _fade := PackedFloat32Array()
var _color := PackedColorArray()
var _age := 0.0
var _lifetime := 0.0


## Starts the derezz of a hexagonal prism of `radius` and `height` whose base is at `base`.
## Call it after the node is in the tree. `shot_dir` is the horizontal direction the
## killing shot travelled in, or zero if unknown.
func start(base: Vector3, radius: float, height: float, shot_dir: Vector3, d: Derezz) -> void:
	_d = d
	add_to_group(FX_GROUP)
	global_transform = Transform3D(Basis.IDENTITY, base)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rng := RandomNumberGenerator.new()
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
	var obsidian := Palette.BASE.lerp(Palette.HOSTILE_RED, d.obsidian_glow)
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
		_color.append(Palette.HOSTILE_RED if rng.randf() < d.glow_fraction else obsidian)
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


## Number of voxels in this derezz.
func voxel_count() -> int:
	return _pos.size()


## Seconds from the start until the effect frees itself.
func lifetime() -> float:
	return _lifetime


func _process(delta: float) -> void:
	if _d == null:
		return
	_age += delta
	var fall := Vector3.DOWN * (_d.gravity * delta)
	var rest := _d.voxel_size * HALF
	for i in _pos.size():
		var v := _vel[i] + fall
		var p := _pos[i] + v * delta
		if p.y < rest:
			p.y = rest
			if v.y < 0.0:
				v = Vector3(v.x * _d.ground_friction, -v.y * _d.bounce, v.z * _d.ground_friction)
		_vel[i] = v
		_pos[i] = p
		_angle[i] = wrapf(_angle[i] + _spin[i] * delta, 0.0, TAU)
		_fade[i] = 1.0 - pow(clampf(_age / _life[i], 0.0, 1.0), _d.fade_power)
	_apply()
	if _age >= _lifetime:
		queue_free()


func _apply() -> void:
	for i in _pos.size():
		var s := _fade[i]
		var turn := Basis(_axis[i], _angle[i]).scaled(Vector3(s, s, s))
		multimesh.set_instance_transform(i, Transform3D(turn, _pos[i]))
		var c := _color[i]
		c.a = s
		multimesh.set_instance_color(i, c)


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


static func _voxel_material(energy: float) -> StandardMaterial3D:
	if not _materials.has(energy):
		var mat := Palette.unlit_glow(Palette.FLASH, energy)
		mat.vertex_color_use_as_albedo = true
		_materials[energy] = mat
	return _materials[energy]
