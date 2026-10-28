class_name ParticleFx
extends Node3D
## The game's GPU particles (A4): sparks off what a shot strikes, derezz bits off a daemon it hits,
## debris from a blast, sparks shed behind a projectile in flight, and each weapon family's muzzle
## burst. Cosmetic only: no collision, no ray, nothing outside the game.
##
## Everything is made once. The arena (scripts/main.gd) makes this node, which holds a fixed pool of
## one-shot emitters for each kind of effect; an effect takes the next emitter of its kind round the
## pool, moves it, and restarts it, so a busy fight reuses the same few emitters and the oldest burst
## is cut short rather than more being made: the pools are the caps. A projectile's trail borrows a
## follower from its pool for as long as it flies (none free: no trail), and gives it back when the
## projectile is gone. A weapon's muzzle burst is made with its model (scripts/viewmodels/viewmodel.gd)
## under its Muzzle, so it rides the model and its fixed projection (A4), and fires with the C6 flash
## (scripts/cannon_fx.gd). Every kind shares one process material and one mesh, and every colour one
## draw material, made on first use and kept; nothing is made per shot or per frame.
##
## The settings' particle level (scripts/settings/game_settings.gd) sets the share of each effect's
## particles shown, and low has no trails. Particles step at the game's pace, so SIGSTOP slows them.

const Palette = preload("res://scripts/palette.gd")

## Every particle pool node joins this group, so effects can find it from anywhere in its tree.
const GROUP := &"particle_fx"
## The muzzle burst's node name under a model's Muzzle.
const MUZZLE_NAME := "MuzzleBurst"

enum Kind { SPARK, DEREZZ, BLAST, TRAIL, HEAVY_TRAIL }
## Each pool: [emitters, particles each, lifetime in seconds, how far its particles may fly, metres].
const POOLS := {
	Kind.SPARK: [12, 24, 0.45, 4.0],
	Kind.DEREZZ: [8, 24, 0.7, 4.0],
	Kind.BLAST: [4, 64, 0.9, 8.0],
	Kind.TRAIL: [12, 40, 0.4, 40.0],
	Kind.HEAVY_TRAIL: [2, 64, 0.6, 40.0],
}
## The particle level: [the share of each effect's particles shown, trails on].
const LEVELS := {"low": [0.25, false], "medium": [0.5, true], "high": [1.0, true]}

## The muzzle bursts, one look per weapon family: the terminal cannon's pulse, the rail's ring, the
## shotguns' wide scatter, grep's tight seeker ring, the lobbed launchers' (fork bomb, cron) chunky
## embers and rm -rf's heavy blast of them.
enum Family { PULSE, RAIL, SCATTER, SEEKER, LAUNCHER, HEAVY }
## Particles a muzzle burst has room for; each family shows its own share of them.
const MUZZLE_PARTICLES := 24
## Each family: [particles, lifetime s, emission ring radius m (0: a point), spread degrees, speed
## m/s from and to, radial speed m/s, damping, gravity m/s², chunky cubes instead of streaks, size].
const MUZZLE := {
	Family.PULSE: [12, 0.1, 0.0, 26.0, 3.0, 6.0, 0.0, 28.0, 0.0, false, 1.0],
	Family.RAIL: [24, 0.18, 0.05, 6.0, 0.5, 1.5, 2.0, 6.0, 0.0, false, 0.8],
	Family.SCATTER: [20, 0.12, 0.0, 42.0, 3.0, 7.0, 0.0, 20.0, 0.0, false, 1.0],
	Family.SEEKER: [14, 0.14, 0.035, 10.0, 2.0, 4.0, 0.8, 10.0, 0.0, false, 0.8],
	Family.LAUNCHER: [14, 0.3, 0.0, 35.0, 1.5, 3.0, 0.0, 4.0, 3.0, true, 1.0],
	Family.HEAVY: [24, 0.4, 0.0, 45.0, 2.0, 5.0, 0.0, 5.0, 2.0, true, 1.5],
}

## How far over full brightness every particle draws, so the glow picks it up.
const ENERGY := 5.0
## The streaks' and embers' sizes in metres, and a derezz bit's.
const STREAK_SIZE := Vector2(0.014, 0.12)
const EMBER_SIZE := 0.035
const CUBE_SIZE := 0.045
const FULL_TURN := 360.0

## The particle level: its share and trails, set by the arena from the settings.
static var level := "high"
static var _processes := {}
static var _draws := {}
static var _meshes := {}

var _pools := {}
var _next := {}
var _fired := {}
## The followers: the trail pools' emitters, what each follows, and when each is free again.
var _followers: Array[GPUParticles3D] = []
## Untyped on purpose: what a trail follows may be freed under it, and a freed node must not be
## read into a typed slot. _busy says which followers are in use.
var _follow: Array = []
var _busy := PackedByteArray()
var _free_at := PackedFloat32Array()
var _heavy := PackedByteArray()
var _clock := 0.0


func _init() -> void:
	name = "ParticleFx"


func _ready() -> void:
	add_to_group(GROUP)
	for kind in POOLS:
		var spec: Array = POOLS[kind]
		var pool: Array[GPUParticles3D] = []
		for i in spec[0]:
			var trail: bool = kind == Kind.TRAIL or kind == Kind.HEAVY_TRAIL
			var p := _emitter(_process_material(kind), _mesh_of(kind), spec[1], spec[2], not trail, spec[3])
			p.name = "%s%d" % [Kind.keys()[kind].capitalize().replace(" ", ""), i]
			# A world-space effect: its particles stay where they were thrown as the emitter moves.
			p.local_coords = false
			if kind == Kind.SPARK or kind == Kind.BLAST:
				p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
			elif trail:
				p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD
				p.explosiveness = 0.0
			add_child(p)
			pool.append(p)
			if trail:
				_followers.append(p)
				_follow.append(null)
				_busy.append(0)
				_free_at.append(0.0)
				_heavy.append(1 if kind == Kind.HEAVY_TRAIL else 0)
		_pools[kind] = pool
		_next[kind] = 0
		_fired[kind] = 0


## The particle pool in `node`'s tree, or null (a test with no arena).
static func of(node: Node) -> ParticleFx:
	if node == null or not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group(GROUP) as ParticleFx


## The share of each effect's particles shown at the current level.
static func share() -> float:
	return LEVELS.get(level, LEVELS["high"])[0]


static func trails_on() -> bool:
	return LEVELS.get(level, LEVELS["high"])[1]


## Sparks where a shot struck, flying off the surface (its normal `normal`) in `color`; off a
## daemon (`hostile`), red and magenta derezz bits tumbling off it as well.
func impact(point: Vector3, normal: Vector3, hostile: bool, color: Color) -> void:
	var xf := Transform3D(_basis_up(normal), point)
	_fire(Kind.SPARK, xf, Palette.HOSTILE_AMBER if hostile else color, 1.0)
	if hostile:
		_fire(Kind.DEREZZ, xf, Palette.FLASH, 1.0)


## Debris from a blast at `point` in `color`: more of it the farther the blast reaches.
func blast(point: Vector3, color: Color, reach_m: float) -> void:
	_fire(Kind.BLAST, Transform3D(Basis.IDENTITY, point), color, clampf(reach_m / 4.0, 0.35, 1.0))


## Sparks shed behind `target` while it flies, in `color`; `heavy` for the rm -rf slug's. False when
## no follower is free (the pool is the cap) or trails are off at this level.
func follow(target: Node3D, color: Color, heavy: bool = false) -> bool:
	if not trails_on() or target == null or not target.is_inside_tree():
		return false
	for i in _followers.size():
		if (_heavy[i] == 1) != heavy or _busy[i] == 1 or _free_at[i] > _clock:
			continue
		var p := _followers[i]
		p.material_override = _draw_material(color)
		p.amount_ratio = share()
		p.global_position = target.global_position
		p.emitting = true
		_follow[i] = target
		_busy[i] = 1
		_fired[Kind.HEAVY_TRAIL if heavy else Kind.TRAIL] += 1
		return true
	return false


## Each kind's emitters, for the checks.
func pool(kind: Kind) -> Array[GPUParticles3D]:
	return _pools[kind]


## How many effects of `kind` were started.
func fired(kind: Kind) -> int:
	return _fired[kind]


## The trails flying now.
func following() -> int:
	var n := 0
	for busy in _busy:
		n += busy
	return n


## The most particles this pool node can ever show at once: every emitter full.
func cap() -> int:
	var total := 0
	for kind in POOLS:
		total += POOLS[kind][0] * POOLS[kind][1]
	return total


## Moves each trail with what it follows, shedding only while that is shown; once it is gone, stops
## the trail and frees it again when its last spark has burnt out. Makes nothing.
func _process(delta: float) -> void:
	_clock += delta
	for i in _followers.size():
		if _busy[i] == 0:
			continue
		if is_instance_valid(_follow[i]) and (_follow[i] as Node3D).is_inside_tree():
			var target := _follow[i] as Node3D
			_followers[i].global_position = target.global_position
			var shown := target.is_visible_in_tree()
			if _followers[i].emitting != shown:
				_followers[i].emitting = shown
			continue
		_followers[i].emitting = false
		_follow[i] = null
		_busy[i] = 0
		_free_at[i] = _clock + _followers[i].lifetime


func _fire(kind: Kind, xf: Transform3D, color: Color, more: float) -> void:
	var pool: Array[GPUParticles3D] = _pools[kind]
	var at: int = _next[kind]
	_next[kind] = (at + 1) % pool.size()
	var p := pool[at]
	p.global_transform = xf
	p.material_override = _draw_material(color)
	p.amount_ratio = clampf(share() * more, 0.05, 1.0)
	p.restart()
	_fired[kind] += 1


# --- The muzzle bursts. ---

## A weapon's family, from its fire mode (and a charge: the rail); a weapon resource with neither
## (a plain WeaponTuning) is the cannon's pulse.
static func family_of(def: Resource) -> Family:
	var mode = def.get("fire_mode")
	var charge = def.get("charge_s")
	match int(mode) if mode is int else 0:
		1, 4:
			return Family.SCATTER
		2, 7:
			return Family.LAUNCHER
		5:
			return Family.SEEKER
		6:
			return Family.HEAVY
	return Family.RAIL if (charge is float or charge is int) and charge > 0.0 else Family.PULSE


## A muzzle burst for weapon `def` in `color`, made once with its model: in the model's own space,
## so it moves and scales with it; nothing until fire_muzzle().
static func make_muzzle_burst(def: Resource, color: Color) -> GPUParticles3D:
	var family := family_of(def)
	var spec: Array = MUZZLE[family]
	var p := _emitter(_muzzle_process(family), _cube_mesh() if spec[9] else _streak_mesh(), MUZZLE_PARTICLES, spec[1], true, 1.0)
	p.name = MUZZLE_NAME
	p.local_coords = true
	if not spec[9]:
		p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	p.material_override = _draw_material(color)
	p.set_meta(&"base", p.material_override)
	p.set_meta(&"share", float(spec[0]) / MUZZLE_PARTICLES)
	p.set_meta(&"family", family)
	return p


## Fires the burst under `muzzle`, if it has one: in its own colour, or in `tint` when given
## (root's red, C22).
static func fire_muzzle(muzzle: Node, tint: Color = Color.TRANSPARENT) -> bool:
	var p := muzzle.get_node_or_null(MUZZLE_NAME) as GPUParticles3D if muzzle != null else null
	if p == null:
		return false
	p.material_override = _draw_material(tint) if tint.a > 0.0 else p.get_meta(&"base")
	p.amount_ratio = clampf(float(p.get_meta(&"share")) * share(), 0.05, 1.0)
	p.restart()
	return true


# --- What every emitter shares. ---

static func _emitter(process: ParticleProcessMaterial, mesh: Mesh, amount: int, life: float, one_shot: bool, reach: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = one_shot
	p.explosiveness = 1.0
	p.randomness = 0.3
	p.emitting = false
	p.fixed_fps = 0
	p.interpolate = false
	p.process_material = process
	p.draw_pass_1 = mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(-Vector3.ONE * reach, Vector3.ONE * reach * 2.0)
	return p


static func _process_material(kind: Kind) -> ParticleProcessMaterial:
	var key := "kind%d" % kind
	if _processes.has(key):
		return _processes[key]
	var m := ParticleProcessMaterial.new()
	m.color_ramp = _fade()
	m.scale_curve = _shrink()
	m.lifetime_randomness = 0.4
	match kind:
		Kind.SPARK:
			m.direction = Vector3.UP
			m.spread = 65.0
			m.initial_velocity_min = 3.0
			m.initial_velocity_max = 8.0
			m.gravity = Vector3.DOWN * 9.8
			m.damping_min = 1.5
			m.damping_max = 3.0
			m.scale_min = 0.7
			m.scale_max = 1.3
		Kind.DEREZZ:
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			m.emission_sphere_radius = 0.12
			m.direction = Vector3.UP
			m.spread = 100.0
			m.initial_velocity_min = 1.5
			m.initial_velocity_max = 4.0
			m.gravity = Vector3.DOWN * 6.0
			m.scale_min = 0.6
			m.scale_max = 1.4
			m.use_rotation_3d = true
			m.rotation_3d_min = -Vector3.ONE * FULL_TURN
			m.rotation_3d_max = Vector3.ONE * FULL_TURN
			m.use_rotation_velocity_3d = true
			m.rotation_velocity_3d_min = -Vector3.ONE * 540.0
			m.rotation_velocity_3d_max = Vector3.ONE * 540.0
			# Each bit red, magenta or between: the hostile side's colours.
			m.color_initial_ramp = _hostile_mix()
		Kind.BLAST:
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			m.emission_sphere_radius = 0.3
			m.direction = Vector3.UP
			m.spread = 180.0
			m.initial_velocity_min = 3.0
			m.initial_velocity_max = 9.0
			m.gravity = Vector3.DOWN * 7.0
			m.damping_min = 2.0
			m.damping_max = 3.0
			m.scale_min = 0.8
			m.scale_max = 1.6
		Kind.TRAIL, Kind.HEAVY_TRAIL:
			var heavy := kind == Kind.HEAVY_TRAIL
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			m.emission_sphere_radius = 0.08 if heavy else 0.03
			m.spread = 180.0
			m.initial_velocity_min = 0.3 if heavy else 0.1
			m.initial_velocity_max = 1.2 if heavy else 0.6
			# A heavy slug's embers rise off it; a light trail's sparks sink.
			m.gravity = Vector3.UP * 0.6 if heavy else Vector3.DOWN * 1.5
			m.damping_min = 1.0
			m.damping_max = 1.5
			m.scale_min = 1.4 if heavy else 0.7
			m.scale_max = 2.4 if heavy else 1.2
	_processes[key] = m
	return m


static func _muzzle_process(family: Family) -> ParticleProcessMaterial:
	var key := "muzzle%d" % family
	if _processes.has(key):
		return _processes[key]
	var spec: Array = MUZZLE[family]
	var m := ParticleProcessMaterial.new()
	m.color_ramp = _fade()
	m.scale_curve = _shrink()
	m.lifetime_randomness = 0.3
	m.direction = Vector3.FORWARD
	if spec[2] > 0.0:
		m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		m.emission_ring_axis = Vector3.BACK
		m.emission_ring_radius = spec[2]
		m.emission_ring_inner_radius = spec[2] * 0.8
		m.emission_ring_height = 0.0
	m.spread = spec[3]
	m.initial_velocity_min = spec[4]
	m.initial_velocity_max = spec[5]
	m.radial_velocity_min = spec[6]
	m.radial_velocity_max = spec[6] * 1.5
	m.damping_min = spec[7]
	m.damping_max = spec[7] * 1.3
	m.gravity = Vector3.DOWN * spec[8]
	m.scale_min = spec[10] * 0.7
	m.scale_max = spec[10] * 1.3
	if spec[9]:
		m.use_rotation_3d = true
		m.rotation_3d_min = -Vector3.ONE * FULL_TURN
		m.rotation_3d_max = Vector3.ONE * FULL_TURN
	_processes[key] = m
	return m


## The draw material of `color`: unshaded, added onto what is behind it, over-bright for the glow,
## each particle's own colour and fade from its process material on top. One per colour, kept.
static func _draw_material(color: Color) -> StandardMaterial3D:
	if _draws.has(color):
		return _draws[color]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(color.r * ENERGY, color.g * ENERGY, color.b * ENERGY, 1.0)
	_draws[color] = m
	return m


## Every particle material made so far: the process materials and the draw materials, for the checks.
static func materials() -> Array:
	return _processes.values() + _draws.values()


static func _mesh_of(kind: Kind) -> Mesh:
	match kind:
		Kind.DEREZZ:
			return _cube_mesh()
		Kind.TRAIL, Kind.HEAVY_TRAIL:
			return _ember_mesh()
	return _streak_mesh()


static func _streak_mesh() -> Mesh:
	if not _meshes.has("streak"):
		var q := QuadMesh.new()
		q.size = STREAK_SIZE
		_meshes["streak"] = q
	return _meshes["streak"]


static func _ember_mesh() -> Mesh:
	if not _meshes.has("ember"):
		var q := QuadMesh.new()
		q.size = Vector2.ONE * EMBER_SIZE
		_meshes["ember"] = q
	return _meshes["ember"]


static func _cube_mesh() -> Mesh:
	if not _meshes.has("cube"):
		var b := BoxMesh.new()
		b.size = Vector3.ONE * CUBE_SIZE
		_meshes["cube"] = b
	return _meshes["cube"]


## Full at birth, fading out by the end of its life.
static func _fade() -> GradientTexture1D:
	if not _meshes.has("fade"):
		var ramp := Gradient.new()
		ramp.set_color(0, Palette.FLASH)
		ramp.set_color(1, Color(Palette.FLASH, 0.0))
		ramp.add_point(0.6, Color(Palette.FLASH, 0.7))
		var tex := GradientTexture1D.new()
		tex.gradient = ramp
		_meshes["fade"] = tex
	return _meshes["fade"]


## Full size at birth, shrinking to nothing by the end of its life: a derezz bit breaks up.
static func _shrink() -> CurveTexture:
	if not _meshes.has("shrink"):
		var curve := Curve.new()
		curve.add_point(Vector2(0.0, 1.0))
		curve.add_point(Vector2(0.7, 0.6))
		curve.add_point(Vector2(1.0, 0.0))
		var tex := CurveTexture.new()
		tex.curve = curve
		_meshes["shrink"] = tex
	return _meshes["shrink"]


## Hostile red to magenta: each derezz bit takes a colour from it at birth.
static func _hostile_mix() -> GradientTexture1D:
	if not _meshes.has("hostile"):
		var ramp := Gradient.new()
		ramp.set_color(0, Palette.HOSTILE_RED)
		ramp.set_color(1, Palette.GLITCH_SPLIT)
		var tex := GradientTexture1D.new()
		tex.gradient = ramp
		_meshes["hostile"] = tex
	return _meshes["hostile"]


## A right-handed basis whose +Y is `up`.
static func _basis_up(up: Vector3) -> Basis:
	var y := up.normalized() if up.length_squared() > 0.0001 else Vector3.UP
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.98 else Vector3.RIGHT
	var x := ref.cross(y).normalized()
	return Basis(x, y, x.cross(y))
