class_name DaemonArt
extends Node3D
## What you see of a daemon (A2, redone in A2b, armoured in A5): a creature, never a static mesh.
## Faceless and geometric (PRD 5.6's art bar, no cartoon monsters). Since A5 a daemon is a solid
## body (Tron Legacy, not glowing wire): closed dark armour with mass (plates, a segmented carapace,
## limbs with thickness) whose light is only in its seams, its joints and its weak points, in its
## type's own colour (rogue.d crimson, the zombie amber, the runaway hot magenta), a few terminal
## glyphs of that colour floating round it, and a glitch that stays quiet until it is hit. Every
## part moves every frame: a type poses its parts on the daemon's own clock (the rogue daemon a
## mantis-scorpion stepping on its legs, the zombie a hulk dragging a leg, the runaway a swarm of
## drones round its core), each reacts to a hit with a recoil and a spray of shards, and dies in a
## burst of its own parts (scripts/daemons/daemon_shatter.gd).
##
## No two alike (A5): a daemon is built from a seed (build_seed), and every choice of its build is
## a roll of it: its size (inside its type's hitbox-safe range), its plates, its seams, its stance,
## its gait's timing, its battle damage (chipped and scorched plates, flickering seams) and, one
## spawn in twelve, whether it is its type's elite (bigger, extra parts). The same seed builds the
## same daemon on every machine, so a match's host sends its seeds and every screen draws the same
## creature; the dummy picks the seeds (scripts/target_dummy.gd).
##
## Built once per spawn, never rebuilt while it is drawn. A part is one instance of one of a few unit
## shapes (a crystal shard, a cut gem, a voxel, a light trail's sliver, an armour plate, a limb, a
## blade, a hex puck, a seam ring), made once for every daemon from the shared shape kit
## (scripts/art/shape_kit.gd), in one of four looks (the edged obsidian, the glowing core, the added
## light of a trail, the armour). A daemon holds one MultiMesh per shape and look it uses, so a
## whole creature is a handful of draw calls; posing it moves instances by their transforms and
## nothing else: no mesh, node, material or array is made after the build.
##
## Visual only. The daemon it dresses keeps its own hit volume, health and states; this sits under
## its Body, so the Body's hiding at a derezz and its growing back at a respawn carry it along. Every
## daemon of every type shares one material per look; what differs per daemon is in instance
## uniforms pinned to fixed slots (its hit flash, a grep lock, the glitch while it rematerialises,
## a seed, its colours) and per part in the instance's custom data. The shaders' time is one shader
## global, stepped here once a frame at the game's pace, so SIGSTOP slows them with the rest; the
## poses run on the daemon's own clock, which slows the same way.
##
## Each type is a script extending this one that builds itself in _build() and poses itself in
## _pose(), named by its target's `art` (scripts/daemons/<type>.gd), so a new enemy type slots in
## the same way. Art space: metres, the origin at the body's centre, the ground 0.9 below it, +Y
## up, -Z ahead; the art's own transform scales it by its size about the ground under it (A5).
##
## Fighting back (C27b): a daemon's brain (scripts/fight/daemon_brain.gd) moves the daemon
## itself and tells its art what it is doing, an act (drive()): moving, its tell, its strike, its
## recovery, a scatter. While it does, the type drops its own idle wandering and plays the act
## (the rogue's rear-up is the tell, its lunge and slash the strike), and what should stay put in
## the world as the daemon moves (the rogue's planted feet, a share of each insect's flight) is
## carried back by the daemon's own motion (carried()). With no act (practice, or no brain) the
## type lives its old idle life, the threat displays included. Still visual only: what lands is
## the brain's judgement, never the art's.
##
## A ping's stagger (C28): a walker (rogue.d, a zombie) whose tell a ping called off plays the
## scatter act as a stagger: staggered() is 1 as it starts and eases to 0, the type reels by it (the
## rogue cowering low, the zombie thrown back with its arms up) and its glitch spikes with it (the
## shaders' unstable slot, never above what a respawn's glitch reaches). The swarm's stagger is its
## own scatter.
##
## Weak points (A5): a type marks the parts a later ICEbreaker aims at (its seams, a visor, a core)
## with weak(); weak_points() says where they are now. Nothing aims at them yet.

const Palette = preload("res://scripts/palette.gd")
const Shatter = preload("res://scripts/daemons/daemon_shatter.gd")

## Every daemon's art joins this group.
const GROUP := &"daemon_art"
## The group a grep lock joins (GrepLock), asked every LOCK_POLL_S whether it marks this daemon.
const GREP_GROUP := &"grep_lock"
const LOCK_POLL_S := 0.1
## How long a hit's flash takes to fade, in seconds, and how fast the lock's glow eases, a second.
const FLASH_S := 0.25
const LOCK_EASE := 10.0
## The clocks wrap here, in seconds, so nothing in the poses or the shaders grows with time.
const CLOCK_WRAP := 3600.0
## Where the ground is, in art space.
const GROUND_Y := -0.9
## /dev/null (C31): the most a hole draws a body out (2.4 times its length along the pull) and leans it in, metres.
const STRETCH_MOST := 1.4
const STRETCH_LEAN_M := 0.3
## And tipped toward it, radians at the most: it leans into the pull.
const STRETCH_TIP := 0.45
## The shader global every daemon shader reads its time from (project.godot's shader globals).
const SHADER_CLOCK := &"daemon_clock"
## A hit's recoil: how far the body is knocked away from the shot, in metres, and how long it
## takes to spring back, in seconds.
const RECOIL_M := 0.16
const RECOIL_S := 0.5
## A hit's spray: how many glowing shards, how long they fly, how fast, and their pull down.
const SPRAY := 10
const SPRAY_S := 0.55
const SPRAY_SPEED := 3.4
const GRAVITY := 9.8
## Where a part goes when it is not drawn: nowhere, at no size.
const HIDDEN := Transform3D(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
## How fast a type eases between its idle life and a brain's acts, a second (C27b).
const DRIVE_EASE := 4.0
## A walker's stagger after a ping (C28): its glitch at the stagger's start, as an unstable share.
const STAGGER_GLITCH := 0.6
## How often a spawn is its type's elite (A5): one in twelve.
const ELITE_RATE := 1.0 / 12.0
## The seeds a build can have (A5): 0 to this, so one fits the wire's 32-bit integers.
const SEED_LAST := 0x7fffffff

## A part's unit shape: SHARD a six-sided crystal from its base (the origin) to its tip (+Y 1), a
## unit across; GEM a cut gem centred on the origin, a unit across and tall; CUBE a unit voxel;
## STREAK a thin sliver from its tail (the origin) to its head (+Y 1). Since A5 the armour's: PLATE
## a slab with a bevelled top, centred, a unit each way (X across, Y thick, Z long); LIMB an eight-
## sided limb from its base (the origin) to its tip (+Y 1), a unit across at the base and narrower
## at the tip; BLADE a curved blade from its root (the origin) to its point (+Y 1), its spine to +Z,
## its edge to -Z, a unit thick (X) and a unit wide (Z); HEX a hex puck with bevelled faces,
## centred, a unit across and tall (+Y its axis); RING an eight-sided band round +Y, centred, a
## unit across and tall: a seam or a joint's light. Since I1 ICE's: FACET a crystal pane, a hexagon a
## unit across its corners (X) and a unit deep (Z), a unit thick (Y), its back flat and its face (+Y)
## cut into a ring of twelve facets round a low six-sided point; PRISM a double-terminated crystal, a
## six-sided column a unit across from its base point (the origin) to its tip point (+Y 1); SHIELD a
## facet's mesh again, its own set, so a hunter's shields take a colour of their own apart from its hull.
enum Shape { SHARD, GEM, CUBE, STREAK, PLATE, LIMB, BLADE, HEX, RING, FACET, PRISM, SHIELD }
## A part's look: the edged obsidian (A2's shell: a voxel peeling off), the glowing core (seams,
## joints and weak points since A5), a trail's added light, the armour (A5), or ICE's (I1): its
## crystal (shaders/ice_crystal.gdshader) and its light (the core's shader, steady, never glitching).
enum Look { SHELL, CORE, TRAIL, ARMOR, ICE, ICE_LIGHT }
## What a brain has the daemon doing (C27b): nothing (its own idle life), moving, its tell, its
## strike, recovering from it, scattering from a hit.
enum Act { IDLE, MOVE, TELL, STRIKE, RECOVER, SCATTER }
const SHAPE_NAMES := ["Shard", "Gem", "Cube", "Streak", "Plate", "Limb", "Blade", "Hex", "Ring", "Facet", "Prism", "Shield"]
const LOOK_NAMES := ["Shell", "Core", "Trail", "Armor", "Ice", "IceLight"]

## The core's colour, and the shell's edges: a type's own, from the palette.
var core_color := Palette.HOSTILE_RED
var edge_color := Palette.HOSTILE_RED
## A zombie's ember drops out now and then: 0 never, 1 its full gutter.
var gutter := 0.0
## The glyphs: how many, how far out, between which heights, how big, and how fast they go round.
var glyph_count := 8
var glyph_radius := 0.75
var glyph_low := -0.3
var glyph_high := 0.8
var glyph_size := 0.13
var glyph_turns := 0.04
## The box every pose stays inside, in art space: the parts' culling box.
var reach := AABB(Vector3(-1.6, -1.0, -1.6), Vector3(3.2, 3.2, 3.2))
## How high over the daemon's feet its name tag floats, clear of the creature, in metres (art space).
var tag_height := 2.25
## The type's budget: the most triangles and draw calls it may take (triangles(), draw_calls()).
var budget_triangles := 800
var budget_draw_calls := 6
## Which brain it fights with (C27b): "rogue", "zombie" or "swarm".
var ai_kind := "rogue"
## Whether the type may put on its own threat displays (the rogue's rear-up on its own clock and
## at a hit): only when no brain fights with it (practice, or no brain). A rear-up is otherwise
## only ever a tell.
var displays := true
## The seed this daemon was built from (A5): every roll of its build (dice()) comes from it.
var build_seed := 0
## Whether this build is its type's elite (A5): bigger, with extra parts; the dummy gives it more
## health.
var elite := false
## Its size (A5), a share of its type's own: every pose, its hit box and its tag scale with it,
## about the ground under it. A type's hitbox-safe range, and its elite's size.
var size_scale := 1.0
var size_low := 1.0
var size_high := 1.0
var elite_size := 1.0
## The brain's act now, how far through it (0 to 1), and how far the type has eased from its idle
## life into being driven (0 to 1).
var act: int = Act.IDLE
var act_u := 0.0
## chmod 000 (C29): true while its daemon is frozen: it holds its pose, nothing moves.
var frozen := false
## /dev/null (C31): how far its body is drawn out toward a hole's core now, 0 (its own shape) to 1, and its
## transform before the hole took it, put back when it lets go.
var stretched := 0.0
var _unstretched := Transform3D.IDENTITY
var _drive := 0.0
## The daemon's motion since the last pose, as a map from the last pose's art space into this
## one's: what stays put in the world is carried back by it. Identity while nothing drives it.
var _carry := Transform3D.IDENTITY
var _last_world := Transform3D.IDENTITY
var _have_world := false

## Per set (one MultiMesh of one shape in one look): its shape, its look, its parts, its node.
var _set_shape := PackedInt32Array()
var _set_look := PackedInt32Array()
var _set_count := PackedInt32Array()
var _set_mm: Array[MultiMesh] = []
var _set_node: Array[MultiMeshInstance3D] = []
## Per part: its set, its instance in that set, its transform as last posed, its custom data.
var _part_set := PackedInt32Array()
var _part_slot := PackedInt32Array()
var _xf: Array[Transform3D] = []
var _custom := PackedColorArray()
## The parts that are weak points (A5).
var _weak := PackedInt32Array()
var _glyphs: MultiMeshInstance3D
var _drawn: Array[GeometryInstance3D] = []
var _target: Node3D
var _clock := 0.0
var _hit := 0.0
var _locked := 0.0
var _locked_goal := 0.0
var _unstable := 0.0
## The stagger's glitch now (C28), sent with the respawn's in the unstable slot (the larger of the two).
var _shudder := 0.0
var _poll := 0.0
var _seed := 0.0
## What the shaders were last told of the flash, the lock and the glitch.
var _sent_hit := -1.0
var _sent_locked := -1.0
var _sent_unstable := -1.0
## The last hit: when, on the clock (-1 none yet), where and which way it went (art space,
## level), and how many there have been.
var _hit_at := -1.0
var _hit_point := Vector3.ZERO
var _hit_dir := Vector3.ZERO
var _hits := 0
## The hit's spray: its first part and each shard's velocity.
var _spray_first := -1
var _spray_v := PackedVector3Array()
var _spray_live := false

static var _materials: Array[ShaderMaterial] = []
static var _meshes: Array[ArrayMesh] = []
static var _mesh_triangles := PackedInt32Array()
static var _glyph_material: ShaderMaterial
static var _glyph_mesh: QuadMesh
static var _shader_clock := 0.0
static var _shader_clock_frame := -1


## The art `script` names, built for `target` from `seed` (A5; below 0, the fixed seed of the
## target's name), or the plain look when it names none.
static func make(script: Script, target: Node3D = null, seed: int = -1) -> DaemonArt:
	var art: DaemonArt = script.new() if is_art(script) else DaemonArt.new()
	art.setup(target, seed)
	return art


## True when `script` is a daemon's art: this script or one extending it.
static func is_art(script: Script) -> bool:
	var s := script
	while s != null:
		if s == DaemonArt:
			return true
		s = s.get_base_script()
	return false


## The fixed seed of a daemon named `daemon_name` (A5): its build in demo, test and capture runs.
## Salted so the arena's four (rogue.d, zombie, <defunct>, runaway) roll no elite: the checks and
## stills keep their one-hit kills (step 39 holds it).
static func seed_of(daemon_name: String) -> int:
	return hash("sk:" + daemon_name) & SEED_LAST


## True when a build from `seed` is its type's elite (A5): one roll of the seed, ELITE_RATE of them.
static func elite_of(seed: int) -> bool:
	return roll_of(seed, 9001, 17) < ELITE_RATE


## A number from 0 to 1 fixed by `seed` and two integers: a build's own dice.
static func roll_of(seed: int, a: int, b: int) -> float:
	return float(hash(Vector3i(a, b, seed)) & 0xffff) / 65535.0


func setup(target: Node3D, seed: int = -1) -> void:
	_target = target
	name = "Art"
	add_to_group(GROUP)
	build_seed = (seed if seed >= 0 else seed_of(String(target.name) if target != null else "daemon")) & SEED_LAST
	_seed = float(build_seed % 1000) / 1000.0
	elite = elite_of(build_seed)
	_build()
	size_scale = elite_size if elite else lerpf(size_low, size_high, dice(9002, 3))
	# Scaled about the ground under it: its feet stay on the floor at any size.
	transform = Transform3D(Basis.from_scale(Vector3.ONE * size_scale), Vector3(0.0, GROUND_Y * (1.0 - size_scale), 0.0))
	_spray_first = _xf.size()
	for i in SPRAY:
		part(Shape.GEM, Look.CORE)
	_spray_v.resize(SPRAY)
	_commit()
	_pose(_clock, 0.0)
	_send(true)


# --- What the daemon tells it. ---

## /dev/null's pull (C31): the body drawn out toward `way` (world space) by `amount`, 0 (its own shape) to 1:
## longer along the way, thinner across it (its volume kept), tipped over toward the core and leaning in. Every
## screen draws it from its own copy of the hole; 0 puts its own shape back.
func stretch_toward(way: Vector3, amount: float) -> void:
	var now := clampf(amount, 0.0, 1.0) if is_finite(amount) else 0.0
	if stretched <= 0.0 and now > 0.0:
		_unstretched = transform
	if now <= 0.0 or way.length() < 0.0001 or not is_inside_tree():
		if stretched > 0.0:
			transform = _unstretched
		stretched = 0.0
		return
	stretched = now
	var parent_basis: Basis = (get_parent() as Node3D).global_transform.basis if get_parent() is Node3D else Basis.IDENTITY
	var w := (parent_basis.inverse() * way).normalized()
	var k := 1.0 + STRETCH_MOST * now
	var across := 1.0 / sqrt(k)
	# across * I + (k - across) * w w^T: k along w, across round it, the volume kept.
	var along := k - across
	var pull := Basis(Vector3(across, 0.0, 0.0) + w * w.x * along, Vector3(0.0, across, 0.0) + w * w.y * along, Vector3(0.0, 0.0, across) + w * w.z * along)
	var level := Vector3(w.x, 0.0, w.z)
	var tip := Basis(Vector3.UP.cross(level).normalized(), STRETCH_TIP * now) if level.length() > 0.001 else Basis.IDENTITY
	transform = Transform3D(tip * pull * _unstretched.basis, _unstretched.origin + w * STRETCH_LEAN_M * now)


## A hit landed: the parts, the core and the glyphs flare and fade over FLASH_S.
func flash() -> void:
	_hit = 1.0
	_send(true)


## A hit that did not kill: the flash, the body knocked away from the shot and springing back, a
## spray of glowing shards from where it struck, and the type's own reaction. `point` is where the
## shot struck and `direction` the way it went, in the world; either may be unknown.
func react(point: Vector3 = Vector3.INF, direction: Vector3 = Vector3.ZERO) -> void:
	flash()
	_hits += 1
	_hit_at = _clock
	var inverse := global_transform.affine_inverse() if is_inside_tree() else transform.affine_inverse()
	var way := inverse.basis * direction
	way.y = 0.0
	var at := inverse * point if point.is_finite() else Vector3(0.0, 0.2, 0.0) - way.normalized() * 0.4
	# Where it struck, kept inside the creature; the way it went, from that point to the middle when
	# the shot gave none.
	at = at.clamp(reach.position, reach.end)
	if way.is_zero_approx():
		way = Vector3(-at.x, 0.0, -at.z)
	if way.is_zero_approx():
		way = Vector3.FORWARD
	_hit_point = at
	_hit_dir = way.normalized()
	for i in SPRAY:
		var a := TAU * _roll(i, 1)
		var spread := Vector3(cos(a), 0.6 + _roll(i, 2), sin(a)) * 0.7
		_spray_v[i] = (-_hit_dir + spread).normalized() * SPRAY_SPEED * (0.55 + 0.6 * _roll(i, 3))
	_spray_live = true
	_on_hit()


## The glitch of rematerialising: 1 just back, 0 whole. Coming back whole from nothing resets the
## type's own motion (its feet, its swarm) to where it stands.
func set_unstable(amount: float) -> void:
	var back := amount >= 0.999 and _unstable < 0.999
	_unstable = clampf(amount, 0.0, 1.0)
	if back:
		_spray_live = false
		_hide_spray()
		_on_return()
	_send(true)


## The death in shards (A2b): a burst of this daemon's own parts as they stand now, flung apart
## under `into` (the death's derezz, so it goes when that does), the killing shot's level way
## `shot` pushing them. A type may fly some of its parts off together instead (the runaway's drones
## scattering when its core dies, A5: _scatter_groups()). It frees itself after its own life at the
## latest.
func shatter(into: Node, shot: Vector3 = Vector3.ZERO) -> Node3D:
	var burst := Shatter.new()
	into.add_child(burst)
	var parts: Array[Dictionary] = []
	var groups := _scatter_groups()
	for id in _xf.size():
		var look := _set_look[_part_set[id]]
		if look == Look.TRAIL or not shown(id) or (id >= _spray_first and id < _spray_first + SPRAY):
			continue
		parts.append({"shape": _set_shape[_part_set[id]], "look": look, "xf": global_transform * _xf[id], "custom": _custom[id], "group": _group_of(id)})
	burst.start(parts, _meshes, _materials, global_transform * Vector3(0.0, GROUND_Y, 0.0), global_transform * Vector3.ZERO, shot, _seed, {"core_color": core_color, "edge_color": edge_color, "seed": _seed, "gutter": gutter}, Callable(DaemonArt, &"_step_shader_clock"), groups)
	return burst


# --- What the brain tells it (C27b). ---

## The brain's act now and how far through it it is, 0 to 1 (Act.IDLE: none, the type's own life).
func drive(new_act: int, u: float = 0.0) -> void:
	act = new_act
	act_u = clampf(u, 0.0, 1.0)


## How far the type is into being driven, 0 (its idle life) to 1.
func drive_amount() -> float:
	return _drive


## Where the daemon's attack comes from now, in the world: the rogue's scythes, the zombie's
## cannon, the swarm's nest. The type gives it in art space (_muzzle()).
func muzzle() -> Vector3:
	return global_transform * _muzzle() if is_inside_tree() else transform * _muzzle()


## The box round the body a shot should hit (C27b's fair hit volume), in art space, beyond the
## daemon's cylinder: its transform (no scale) and its size; ZERO size for none.
func body_box() -> Transform3D:
	return Transform3D.IDENTITY


func body_box_size() -> Vector3:
	return Vector3.ZERO


## The body box's size at this daemon's size (A5), in the body's own metres.
func box_size() -> Vector3:
	return body_box_size() * size_scale


## The name tag's height over the body's centre (A5: at this daemon's size), in the body's metres.
func tag_y() -> float:
	return (transform * Vector3(0.0, tag_height, 0.0)).y


## A walker's stagger after a ping (C28): 1 as it starts, easing to 0; 0 when it is not staggering
## and always for the swarm, whose stagger is its scatter.
func staggered() -> float:
	if act != Act.SCATTER or ai_kind == "swarm":
		return 0.0
	return 1.0 - smoothstep(0.0, 1.0, act_u)


func hit_glow() -> float:
	return _hit


func lock_glow() -> float:
	return _locked


func unstable() -> float:
	return _unstable


func clock() -> float:
	return _clock


## The shared shader clock as last stepped, for the checks.
static func shader_clock() -> float:
	return _shader_clock


func glyphs() -> MultiMeshInstance3D:
	return _glyphs


## The daemon's sets, each one MultiMesh of one shape in one look, in the order they were made.
func sets() -> Array[MultiMeshInstance3D]:
	return _set_node


## The look of set `i`.
func set_look(i: int) -> int:
	return _set_look[i]


## The shape of set `i`.
func set_shape(i: int) -> int:
	return _set_shape[i]


## The set of the core's look holding its gems, the one its colour shows on.
func core_set() -> MultiMeshInstance3D:
	for i in _set_node.size():
		if _set_look[i] == Look.CORE and _set_shape[i] == Shape.GEM:
			return _set_node[i]
	return null


func part_count() -> int:
	return _xf.size()


## Part `id`'s transform as last posed (art space) and its custom data, its shape and its look.
func part_transform(id: int) -> Transform3D:
	return _xf[id]


func part_custom(id: int) -> Color:
	return _custom[id]


func part_shape(id: int) -> int:
	return _set_shape[_part_set[id]]


func part_look(id: int) -> int:
	return _set_look[_part_set[id]]


## The parts marked as weak points (A5).
func weak_parts() -> PackedInt32Array:
	return _weak


## Where each weak point drawn now is (art space): its seams, a visor, a core (A5).
func weak_points() -> PackedVector3Array:
	var out := PackedVector3Array()
	for id in _weak:
		if shown(id):
			out.append(_xf[id].origin)
	return out


## How many of the hit spray's shards are drawn now.
func spraying() -> int:
	var count := 0
	for i in SPRAY:
		count += 1 if shown(_spray_first + i) else 0
	return count


## True when part `id` is drawn: posed at some size and present.
func shown(id: int) -> bool:
	return _xf[id].basis.determinant() > 0.0000001 and _custom[id].b > 0.0


## The box round every part drawn now, in art space: the creature's size as it stands.
func pose_bounds() -> AABB:
	var box := AABB()
	var first := true
	for id in _xf.size():
		if not shown(id) or (id >= _spray_first and id < _spray_first + SPRAY):
			continue
		var b: AABB = _xf[id] * _meshes[_set_shape[_part_set[id]]].get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## Triangles in the whole daemon: its budget.
func triangles() -> int:
	var total := 0
	for i in _set_mm.size():
		total += _set_mm[i].instance_count * _mesh_triangles[_set_shape[i]]
	if _glyphs != null:
		total += _glyphs.multimesh.instance_count * 2
	return total


## Draw calls for the whole daemon: a set each, one more for a set's split pass and one more for
## each set that throws a shadow; the glyphs one.
func draw_calls() -> int:
	var total := 0
	for node in _set_node:
		total += 1
		if node.material_override.next_pass != null:
			total += 1
		if node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			total += 1
	return total + (1 if _glyphs != null else 0)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	# The game's own pace: delta is scaled with the engine's time, so SIGSTOP slows it all.
	_step_shader_clock(delta)
	if frozen:
		# chmod 000 (C29): frozen still, every part where it was, nothing posed or turned; a hit's flash
		# still shows.
		_hit = maxf(_hit - delta / FLASH_S, 0.0)
		_send(false)
		return
	_clock = fmod(_clock + delta, CLOCK_WRAP)
	_hit = maxf(_hit - delta / FLASH_S, 0.0)
	_poll -= delta
	if _poll <= 0.0:
		_poll = LOCK_POLL_S
		_locked_goal = 1.0 if _marked() else 0.0
	_locked = move_toward(_locked, _locked_goal, LOCK_EASE * delta)
	_drive = move_toward(_drive, 0.0 if act == Act.IDLE else 1.0, DRIVE_EASE * delta)
	_shudder = STAGGER_GLITCH * staggered()
	_step_carry()
	_pose(_clock, delta)
	if _spray_live:
		_pose_spray()
	if _glyphs != null:
		_glyphs.rotate_object_local(Vector3.UP, TAU * glyph_turns * delta)
	_send(false)


## The daemon's motion since the last pose (C27b): only while driven and whole (not mid-respawn,
## when the body grows from nothing; whole is its own size, A5), else identity.
func _step_carry() -> void:
	var now := global_transform if is_inside_tree() else Transform3D.IDENTITY
	var whole := absf(now.basis.determinant() / (size_scale * size_scale * size_scale) - 1.0) < 0.01
	_carry = now.affine_inverse() * _last_world if _have_world and whole and _drive > 0.0 else Transform3D.IDENTITY
	_last_world = now
	_have_world = whole


## Steps the shared shader clock once a frame, whichever daemon (or death's burst) draws first.
static func _step_shader_clock(delta: float) -> void:
	var frame := Engine.get_process_frames()
	if frame == _shader_clock_frame:
		return
	_shader_clock_frame = frame
	_shader_clock = fmod(_shader_clock + delta, CLOCK_WRAP)
	RenderingServer.global_shader_parameter_set(SHADER_CLOCK, _shader_clock)


## True when a grep lock on this machine marks the daemon this dresses.
func _marked() -> bool:
	if _target == null or not is_inside_tree():
		return false
	for lock in get_tree().get_nodes_in_group(GREP_GROUP):
		if lock.has_method("has_mark") and lock.has_mark(_target):
			return true
	return false


## The instance uniforms that change, on every drawn set, only when they change (or all of them
## when `all`). Nothing is made here: it runs every frame.
func _send(all: bool) -> void:
	var hit := all or _hit != _sent_hit
	var locked := all or _locked != _sent_locked
	var glitch := maxf(_unstable, _shudder)
	var unstable := all or glitch != _sent_unstable
	if not (hit or locked or unstable):
		return
	for node in _drawn:
		if hit:
			node.set_instance_shader_parameter(&"hit", _hit)
		if locked:
			node.set_instance_shader_parameter(&"locked", _locked)
		if unstable:
			node.set_instance_shader_parameter(&"unstable", glitch)
	_sent_hit = _hit
	_sent_locked = _locked
	_sent_unstable = glitch


# --- What a type gives. ---

## The type's parts, each made with part(). The plain look: a red core in a ring of six obsidian
## shards that lean in and out as they go round it.
func _build() -> void:
	part(Shape.GEM, Look.CORE)
	for i in 6:
		part(Shape.SHARD, Look.SHELL)


## The type's pose at clock `t`, `delta` seconds after the last (0 at the build): every part placed
## with put(), bone(), orient() or conceal(). Called every frame it is drawn.
func _pose(t: float, _delta: float) -> void:
	orient(0, Vector3(0.0, 0.0, 0.0), Vector3.UP, 0.5, 0.26)
	for i in 6:
		var a := TAU * i / 6.0 + t * 0.6
		var lean := 0.25 + 0.1 * sin(t * 2.0 + i)
		var foot := Vector3(cos(a) * 0.35, GROUND_Y + 0.1, sin(a) * 0.35)
		bone(1 + i, foot, foot + Vector3(-cos(a) * lean, 1.4, -sin(a) * lean), 0.12)


## The type's own reaction to a hit (after the flash, the recoil and the spray).
func _on_hit() -> void:
	pass


## The type's own reset when it comes back from a derezz.
func _on_return() -> void:
	pass


## Where its attack comes from, in art space (C27b).
func _muzzle() -> Vector3:
	return Vector3(0.0, 0.2, -0.6)


## The groups of parts its death flies off together (A5): each a Dictionary with its centre and its
## velocity (world space); none by default, every part bursting on its own.
func _scatter_groups() -> Array[Dictionary]:
	return []


## The group part `id` flies off with at its death (_scatter_groups()), or -1 for none.
func _group_of(_id: int) -> int:
	return -1


# --- Building and posing parts. ---

## A new part of `shape` in `look`, drawn as wire when `wire` is 1 (a shell's; a core's or a trail's
## brightness starts at 1, an armour plate's tone at its salt), as ghost `ghost` of a trail when
## above 0. Returns its id. Only in _build().
func part(shape: Shape, look: Look, wire: float = 0.0, ghost: float = 0.0) -> int:
	var bin := -1
	for i in _set_shape.size():
		if _set_shape[i] == shape and _set_look[i] == look:
			bin = i
	if bin < 0:
		_set_shape.append(shape)
		_set_look.append(look)
		_set_count.append(0)
		bin = _set_shape.size() - 1
	var id := _xf.size()
	_part_set.append(bin)
	_part_slot.append(_set_count[bin])
	_set_count[bin] += 1
	_xf.append(HIDDEN)
	var salt := fmod(id * 0.618034 + _seed, 1.0)
	_custom.append(Color(salt, wire if look == Look.SHELL else (salt if look == Look.ARMOR or look == Look.ICE else 1.0), 1.0, ghost))
	return id


## Marks part `id` a weak point (A5): a seam, a visor, a core. Only in _build().
func weak(id: int) -> int:
	_weak.append(id)
	return id


## A seam that flickers (A5's battle damage): part `id` of the core's look dropping out now and then,
## `amount` 0 (steady) to 1 (out more often than not), by the core shader. Only in _build().
func flicker(id: int, amount: float) -> void:
	var c := _custom[id]
	c.a = clampf(amount, 0.0, 1.0)
	_custom[id] = c


## A seam (A5): part `id` of the core's look at the seams' brightness, dimmer than a core, so it
## glows in its type's colour. Returns its id. Only in _build().
func seam(id: int) -> int:
	var c := _custom[id]
	c.g = Palette.DAEMON_SEAM_GLOW
	_custom[id] = c
	return id


## A scorched armour plate (A5's battle damage): part `id` of the armour's look burned darker and
## matte, `amount` 0 to 1. Only in _build().
func scorch(id: int, amount: float) -> void:
	var c := _custom[id]
	c.a = clampf(amount, 0.0, 1.0)
	_custom[id] = c


## Places part `id` at `xf`, in art space.
func put(id: int, xf: Transform3D) -> void:
	_xf[id] = xf
	_set_mm[_part_set[id]].set_instance_transform(_part_slot[id], xf)


## Part `id` not drawn.
func conceal(id: int) -> void:
	if _xf[id] != HIDDEN:
		put(id, HIDDEN)


## A shard part `id` from `from` to `to`, `width` across (and `depth` the other way, the same when
## below 0, flat across `flat` when given: a blade or a wing).
func bone(id: int, from: Vector3, to: Vector3, width: float, depth: float = -1.0, flat: Vector3 = Vector3.ZERO) -> void:
	var along := to - from
	if along.length_squared() < 0.00000001:
		conceal(id)
		return
	put(id, Transform3D(_axes(along, width, along.length(), width if depth < 0.0 else depth, flat), from))


## A centred part `id` (a gem or a voxel) at `at`, its own Y along `axis`, `length` along it and
## `width` across (`depth` the other way, the same when below 0, flat across `flat` when given).
func orient(id: int, at: Vector3, axis: Vector3, length: float, width: float, depth: float = -1.0, flat: Vector3 = Vector3.ZERO) -> void:
	if axis.length_squared() < 0.00000001:
		conceal(id)
		return
	put(id, Transform3D(_axes(axis, width, length, width if depth < 0.0 else depth, flat), at))


## A centred part `id` placed by `basis` (its own X, Y and Z, sizes included) at `at` (A5): a plate
## laid on a body's own axes.
func lay(id: int, at: Vector3, basis: Basis) -> void:
	put(id, Transform3D(basis, at))


## A right-handed frame with `right` across and `back` along, its up between them (A5): how a plate
## is laid on a head, a chest or a tail.
static func plank(right: Vector3, back: Vector3) -> Basis:
	var z := back.normalized()
	var y := z.cross(right).normalized()
	var x := y.cross(z)
	return Basis(x, y, z)


## Sets part `id`'s presence (1 whole, 0 gone, between breaking up) and its wire (-1 keeps it),
## telling the MultiMesh only when they change.
func present(id: int, presence: float, wire: float = -1.0) -> void:
	var c := _custom[id]
	var w := c.g if wire < 0.0 else wire
	if c.b == presence and c.g == w:
		return
	c.b = presence
	c.g = w
	_custom[id] = c
	_set_mm[_part_set[id]].set_instance_custom_data(_part_slot[id], c)


## Sets part `id`'s brightness (a core's or a trail's), telling the MultiMesh only when it changes.
func brighten(id: int, bright: float) -> void:
	var c := _custom[id]
	if c.g == bright:
		return
	c.g = bright
	_custom[id] = c
	_set_mm[_part_set[id]].set_instance_custom_data(_part_slot[id], c)


## The hit's recoil now: an offset away from the shot, out fast and springing back past rest.
func recoil() -> Vector3:
	return _hit_dir * RECOIL_M * _knock()


## How hard the last hit still shakes the daemon: 1 at its peak, 0 settled.
func jolt() -> float:
	return absf(_knock())


## Seconds on the clock since `at` (INF for -1, never).
func since(at: float) -> float:
	return INF if at < 0.0 else fposmod(_clock - at, CLOCK_WRAP)


## A number from 0 to 1 fixed by this daemon's seed, two integers and its hits so far: its own dice
## for a hit's spray, the same on every run.
func _roll(a: int, b: int) -> float:
	return roll_of(build_seed + _hits * 7919, a, b)


## A seeded number from 0 to 1 that does not change with the hits: for its build, its shapes and
## its schedules.
func dice(a: int, b: int) -> float:
	return roll_of(build_seed, a, b)


## A seeded whole number from `low` to `high`, both included (A5's build).
func pick(a: int, b: int, low: int, high: int) -> int:
	return mini(low + int(dice(a, b) * (high - low + 1)), high)


func _knock() -> float:
	var age := since(_hit_at)
	if age >= RECOIL_S:
		return 0.0
	if age < 0.05:
		return age / 0.05
	var u := age - 0.05
	return exp(-u * 9.0) * cos(u * 16.0) * (1.0 - age / RECOIL_S)


## Axes for a part along `along` (a unit Y scaled to `length`), `width` and `depth` across, its
## depth axis turned toward `flat` when given: right-handed, so no part is ever drawn inside out.
static func _axes(along: Vector3, width: float, length: float, depth: float, flat: Vector3) -> Basis:
	var y := along.normalized()
	var ref := flat if not flat.is_zero_approx() else (Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT)
	var x := y.cross(ref)
	if x.length_squared() < 0.000001:
		x = y.cross(Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.BACK)
	x = x.normalized()
	var z := x.cross(y)
	return Basis(x * width, y * length, z * depth)


func _pose_spray() -> void:
	var age := since(_hit_at)
	if age >= SPRAY_S:
		_spray_live = false
		_hide_spray()
		return
	var life := 1.0 - age / SPRAY_S
	for i in SPRAY:
		var v := _spray_v[i]
		var at := _hit_point + v * age + Vector3.DOWN * (0.5 * GRAVITY * age * age)
		var size := 0.07 * life * (0.6 + 0.4 * dice(i, 9))
		orient(_spray_first + i, at, v + Vector3.DOWN * GRAVITY * age, size * 3.0, size)


func _hide_spray() -> void:
	for i in SPRAY:
		conceal(_spray_first + i)


static func _statics() -> void:
	if not _materials.is_empty():
		return
	_materials.append(Palette.daemon_shell_material())
	_materials.append(Palette.daemon_core_material())
	_materials.append(Palette.daemon_trail_material())
	_materials.append(Palette.daemon_armor_material())
	_materials.append(Palette.ice_crystal_material())
	_materials.append(Palette.ice_light_material())
	_glyph_material = Palette.daemon_glyph_material()
	_glyph_mesh = QuadMesh.new()
	_glyph_mesh.size = Vector2.ONE
	var kit := ShapeKit.new()
	for shape in SHAPE_NAMES.size():
		var bucket := kit.bucket(Vector3.ZERO, shape != Shape.STREAK)
		match shape:
			Shape.SHARD:
				_crystal(kit, bucket)
			Shape.GEM:
				_gem(kit, bucket)
			Shape.CUBE:
				kit.box(bucket, Vector3.ZERO, Vector3.ONE)
			Shape.STREAK:
				kit.spike(bucket, Vector3.ZERO, Vector3.UP, 0.5, 3, 0.85)
			Shape.PLATE:
				_plate(kit, bucket)
			Shape.LIMB:
				_limb(kit, bucket)
			Shape.BLADE:
				_blade(kit, bucket)
			Shape.HEX:
				_hex(kit, bucket)
			Shape.RING:
				kit.tube(bucket, Vector3.ZERO, 0.4, 0.5, 1.0, 8, Vector3(90.0, 0.0, 0.0), 22.5)
			Shape.FACET, Shape.SHIELD:
				_facet(kit, bucket)
			Shape.PRISM:
				_prism(kit, bucket)
		_mesh_triangles.append(kit.count(bucket) / 3)
		_meshes.append(kit.commit(bucket))


## The shard: a six-sided crystal standing on a short point at its base, its sides narrowing a
## little to a pyramid tip, a unit across at its widest and a unit long.
static func _crystal(kit: ShapeKit, bucket: int) -> void:
	var low := []
	var high := []
	for i in 6:
		var a := TAU * i / 6.0
		var d := Vector3(cos(a), 0.0, sin(a))
		low.append(d * 0.5 + Vector3(0.0, 0.14, 0.0))
		high.append(d * 0.4 + Vector3(0.0, 0.74, 0.0))
	for i in 6:
		var j := (i + 1) % 6
		var out := (low[i] + low[j]) as Vector3
		out.y = 0.0
		kit.polygon(bucket, [low[i], low[j], Vector3.ZERO], out + Vector3.DOWN * 0.4)
		kit.polygon(bucket, [low[i], low[j], high[j], high[i]], out)
		kit.polygon(bucket, [high[i], high[j], Vector3.UP], out + Vector3.UP * 0.6)


## The gem: an octagonal cut stone centred on the origin: a flat table on top, a crown down to its
## girdle, a pavilion down to a point.
static func _gem(kit: ShapeKit, bucket: int) -> void:
	var table := []
	var girdle := []
	for i in 8:
		var a := TAU * (i + 0.5) / 8.0
		var d := Vector3(cos(a), 0.0, sin(a))
		table.append(d * 0.28 + Vector3(0.0, 0.5, 0.0))
		girdle.append(d * 0.5 + Vector3(0.0, 0.18, 0.0))
	kit.polygon(bucket, table, Vector3.UP)
	for i in 8:
		var j := (i + 1) % 8
		var out := (girdle[i] + girdle[j]) as Vector3
		out.y = 0.0
		kit.polygon(bucket, [table[i], table[j], girdle[j], girdle[i]], out + Vector3.UP * 0.5)
		kit.polygon(bucket, [girdle[i], girdle[j], Vector3(0.0, -0.5, 0.0)], out + Vector3.DOWN * 0.5)


## The plate (A5): an armour slab centred on the origin, a unit each way, its top (+Y) bevelled in
## to a smaller face so its edges catch the light: straight sides up to 0.1, the bevel above them.
static func _plate(kit: ShapeKit, bucket: int) -> void:
	var rims := []
	for r in [[-0.5, 0.5, 0.5], [0.1, 0.5, 0.5], [0.5, 0.36, 0.4]]:
		var rim := []
		for c in [[-1.0, -1.0], [1.0, -1.0], [1.0, 1.0], [-1.0, 1.0]]:
			rim.append(Vector3(r[1] * c[0], r[0], r[2] * c[1]))
		rims.append(rim)
	_band(kit, bucket, rims)
	kit.polygon(bucket, rims[0], Vector3.DOWN)
	kit.polygon(bucket, rims[2], Vector3.UP)


## The sides between each rim of `rims` and the next (A5): each face turned out from the Y axis.
static func _band(kit: ShapeKit, bucket: int, rims: Array) -> void:
	for k in rims.size() - 1:
		var n: int = rims[k].size()
		for i in n:
			var j := (i + 1) % n
			var quad := [rims[k][i], rims[k][j], rims[k + 1][j], rims[k + 1][i]]
			var c := ((quad[0] + quad[1] + quad[2] + quad[3]) as Vector3) * 0.25
			kit.polygon(bucket, quad, Vector3(c.x, 0.0, c.z))


## The limb (A5): an eight-sided limb from its base (the origin) up to +Y 1, a unit across at the
## base, 0.7 at the tip, its two ends cut in a short bevel.
static func _limb(kit: ShapeKit, bucket: int) -> void:
	var rims := []
	for r in [[0.0, 0.36], [0.08, 0.5], [0.9, 0.35], [1.0, 0.24]]:
		var rim := []
		for i in 8:
			var a := TAU * (i + 0.5) / 8.0
			rim.append(Vector3(cos(a) * r[1], r[0], sin(a) * r[1]))
		rims.append(rim)
	_band(kit, bucket, rims)
	kit.polygon(bucket, rims[0], Vector3.DOWN)
	kit.polygon(bucket, rims[rims.size() - 1], Vector3.UP)


## The blade (A5): a scythe from its root (the origin) to its point (+Y 1), curving forward (-Z) as
## it goes; a diamond in section, a thick spine to +Z and a thin edge to -Z, a unit thick across X at
## its root and a unit wide along Z, narrowing to the point.
static func _blade(kit: ShapeKit, bucket: int) -> void:
	# Each station: its height, how far forward its middle has curved, its width (Z), its thickness (X).
	var stations := [[0.0, 0.0, 0.7, 0.9], [0.3, -0.06, 1.0, 1.0], [0.62, -0.2, 0.8, 0.7], [0.86, -0.38, 0.45, 0.4]]
	var rims := []
	var mids := []
	for s in stations:
		var y: float = s[0]
		var mid: float = s[1]
		var w: float = s[2] * 0.5
		var x: float = s[3] * 0.5
		# The spine (+Z), the right flank, the edge (-Z, thin), the left flank.
		rims.append([Vector3(0.0, y, mid + w * 0.55), Vector3(x, y, mid + w * 0.1), Vector3(0.0, y - 0.04, mid - w), Vector3(-x, y, mid + w * 0.1)])
		mids.append(Vector3(0.0, y, mid))
	var tip := Vector3(0.0, 1.0, -0.62)
	for k in rims.size() - 1:
		for i in 4:
			var j := (i + 1) % 4
			var quad := [rims[k][i], rims[k][j], rims[k + 1][j], rims[k + 1][i]]
			var c := ((quad[0] + quad[1] + quad[2] + quad[3]) as Vector3) * 0.25
			kit.polygon(bucket, quad, c - (mids[k] + mids[k + 1]) * 0.5)
	var last: Array = rims[rims.size() - 1]
	for i in 4:
		var j := (i + 1) % 4
		var c := ((last[i] + last[j] + tip) as Vector3) / 3.0
		kit.polygon(bucket, [last[i], last[j], tip], c - mids[mids.size() - 1])
	kit.polygon(bucket, rims[0], Vector3.DOWN)


## The hex puck (A5): a hexagonal body centred on the origin, a unit across its corners and a unit
## tall along +Y, its top and bottom bevelled in.
static func _hex(kit: ShapeKit, bucket: int) -> void:
	var top := []
	var upper := []
	var lower := []
	var bottom := []
	for i in 6:
		var a := TAU * i / 6.0
		var d := Vector3(cos(a), 0.0, sin(a))
		top.append(d * 0.34 + Vector3(0.0, 0.5, 0.0))
		upper.append(d * 0.5 + Vector3(0.0, 0.22, 0.0))
		lower.append(d * 0.5 + Vector3(0.0, -0.22, 0.0))
		bottom.append(d * 0.34 + Vector3(0.0, -0.5, 0.0))
	for i in 6:
		var j := (i + 1) % 6
		var out := (upper[i] + upper[j]) as Vector3
		out.y = 0.0
		kit.polygon(bucket, [top[i], top[j], upper[j], upper[i]], out + Vector3.UP * 0.6)
		kit.polygon(bucket, [upper[i], upper[j], lower[j], lower[i]], out)
		kit.polygon(bucket, [lower[i], lower[j], bottom[j], bottom[i]], out + Vector3.DOWN * 0.6)
	kit.polygon(bucket, top, Vector3.UP)
	kit.polygon(bucket, bottom, Vector3.DOWN)


## The facet (I1): an ICE crystal pane, a hexagon a unit across its corners along X (and a unit deep
## along Z, its corners stretched to it), its back (-Y) flat at -0.5, its sides straight up to 0.12,
## then a ring of twelve facets in to a smaller hexagon turned half a corner, then six to its point
## at +0.5: a cut stone's crown, so each facet takes the light its own way.
static func _facet(kit: ShapeKit, bucket: int) -> void:
	var back := []
	var rim := []
	var crown := []
	for i in 6:
		var a := TAU * i / 6.0
		var b := TAU * (i + 0.5) / 6.0
		rim.append(Vector3(cos(a) * 0.5, 0.12, sin(a) * 0.5))
		back.append(Vector3(cos(a) * 0.5, -0.5, sin(a) * 0.5))
		crown.append(Vector3(cos(b) * 0.27, 0.36, sin(b) * 0.27))
	var tip := Vector3(0.0, 0.5, 0.0)
	for i in 6:
		var j := (i + 1) % 6
		var out := (rim[i] + rim[j]) as Vector3
		out.y = 0.0
		kit.polygon(bucket, [back[i], back[j], rim[j], rim[i]], out)
		kit.polygon(bucket, [rim[i], rim[j], crown[i]], out + Vector3.UP * 0.9)
		kit.polygon(bucket, [crown[i], rim[j], crown[j]], ((crown[i] + crown[j]) as Vector3) * Vector3(1.0, 0.0, 1.0) + Vector3.UP * 1.1)
		kit.polygon(bucket, [crown[i], crown[j], tip], ((crown[i] + crown[j]) as Vector3) * Vector3(1.0, 0.0, 1.0) + Vector3.UP * 1.6)
	kit.polygon(bucket, back, Vector3.DOWN)


## The prism (I1): a double-terminated crystal, a six-sided column a unit across from a point at its
## base (the origin) to a point at its tip (+Y 1): short pyramids at both ends, its sides between.
static func _prism(kit: ShapeKit, bucket: int) -> void:
	var low := []
	var high := []
	for i in 6:
		var a := TAU * i / 6.0
		var d := Vector3(cos(a), 0.0, sin(a)) * 0.5
		low.append(d + Vector3(0.0, 0.16, 0.0))
		high.append(d + Vector3(0.0, 0.84, 0.0))
	for i in 6:
		var j := (i + 1) % 6
		var out := (low[i] + low[j]) as Vector3
		out.y = 0.0
		kit.polygon(bucket, [low[i], low[j], Vector3.ZERO], out + Vector3.DOWN * 0.5)
		kit.polygon(bucket, [low[i], low[j], high[j], high[i]], out)
		kit.polygon(bucket, [high[i], high[j], Vector3.UP], out + Vector3.UP * 0.5)


## The merge: a MultiMesh for each set, every part hidden until posed; the glyphs one MultiMesh.
func _commit() -> void:
	_statics()
	for bin in _set_shape.size():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = _meshes[_set_shape[bin]]
		mm.instance_count = _set_count[bin]
		mm.custom_aabb = reach
		var node := MultiMeshInstance3D.new()
		node.name = LOOK_NAMES[_set_look[bin]] + SHAPE_NAMES[_set_shape[bin]]
		node.multimesh = mm
		node.material_override = _materials[_set_look[bin]]
		# Light is not a solid: only the obsidian, the armour and ICE's crystal throw a shadow.
		var solid := _set_look[bin] == Look.SHELL or _set_look[bin] == Look.ARMOR or _set_look[bin] == Look.ICE
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if solid else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		_set_mm.append(mm)
		_set_node.append(node)
		_drawn.append(node)
		node.set_instance_shader_parameter("seed", _seed)
		node.set_instance_shader_parameter("core_color", core_color)
		node.set_instance_shader_parameter("edge_color", edge_color)
		node.set_instance_shader_parameter("gutter", gutter)
	for id in _xf.size():
		_set_mm[_part_set[id]].set_instance_transform(_part_slot[id], HIDDEN)
		_set_mm[_part_set[id]].set_instance_custom_data(_part_slot[id], _custom[id])
	if glyph_count > 0:
		_glyphs = MultiMeshInstance3D.new()
		_glyphs.name = "Glyphs"
		_glyphs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_glyphs.material_override = _glyph_material
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = _glyph_mesh
		mm.instance_count = glyph_count
		for g in glyph_count:
			var a := TAU * (g + _seed) / glyph_count
			var y := lerpf(glyph_low, glyph_high, fmod(g * 0.618034 + _seed, 1.0))
			var out := glyph_radius * (0.85 + 0.15 * fmod(g * 0.414214, 1.0))
			mm.set_instance_transform(g, Transform3D(Basis.from_scale(Vector3.ONE * glyph_size), Vector3(cos(a) * out, y, sin(a) * out)))
			mm.set_instance_custom_data(g, Color(fmod(g * 0.137 + _seed, 1.0), 0.0, 0.0, 0.0))
		_glyphs.multimesh = mm
		add_child(_glyphs)
		_drawn.append(_glyphs)
		_glyphs.set_instance_shader_parameter("seed", _seed)
		_glyphs.set_instance_shader_parameter("core_color", core_color)
