class_name DaemonArt
extends Node3D
## What you see of a daemon (A2): faceless, geometric, never a cartoon (PRD 5.6's art bar).
## Obsidian shards, blades, chunks or drones in turning layers round a glowing core in the type's
## own colour, red terminal glyphs floating round it, and a glitch on its shells. Built once, in
## code, from the shared shape kit (scripts/art/shape_kit.gd), never rebuilt while it is drawn:
## each layer is one node that turns, holding one mesh with an obsidian surface and a core
## surface, and the glyphs are one MultiMesh that turns as a node. Original and procedural: no
## model, texture or font files.
##
## Visual only. The daemon it dresses keeps its own hit volume, health and states; this sits under
## its Body, so the Body's hiding at a derezz and its growing back at a respawn carry it along. Every
## daemon of every type shares the same three materials (shaders/daemon_shell.gdshader,
## daemon_core.gdshader, daemon_glyphs.gdshader); what differs per daemon is in instance uniforms: its
## own clock, which runs at the game's pace and so slows with SIGSTOP; a hit flash; a grep lock (the
## local player's grep marking it); the glitch while it rematerialises; the core's colour; a seed.
##
## Each type is a script extending this one that builds itself in _build(), named by its target's
## `art` (scripts/daemons/<type>.gd), so a new enemy type slots in the same way. Art space: metres,
## the origin at the body's centre, the ground 0.9 below it, +Y up.

const Palette = preload("res://scripts/palette.gd")

## Every daemon's art joins this group.
const GROUP := &"daemon_art"
## The group a grep lock joins (GrepLock), asked every LOCK_POLL_S whether it marks this daemon.
const GREP_GROUP := &"grep_lock"
const LOCK_POLL_S := 0.1
## How long a hit's flash takes to fade, in seconds, and how fast the lock's glow eases, a second.
const FLASH_S := 0.25
const LOCK_EASE := 10.0
## The clock wraps here, in seconds, so nothing in the shaders grows with time.
const CLOCK_WRAP := 3600.0
## Where the ground is, in art space.
const GROUND_Y := -0.9

## The core's colour: a type's own, from the palette.
var core_color := Palette.HOSTILE_RED
## A zombie's core drops out now and then: 0 never, 1 its full gutter.
var gutter := 0.0
## The glyphs: how many, how far out, between which heights, how big, and how fast they go round.
var glyph_count := 8
var glyph_radius := 0.75
var glyph_low := -0.3
var glyph_high := 0.8
var glyph_size := 0.13
var glyph_turns := 0.04
## The whole daemon bobs this far, this many times a second.
var hover_m := 0.035
var hover_hz := 0.45

var _kit: ShapeKit
## Per layer: its shell and core buckets, its turns a second, the axis it turns about (its own Y)
## and its tilt, and once built its holder node and its mesh node (null for a layer with no shapes).
var _layers: Array[Dictionary] = []
var _glyphs: MultiMeshInstance3D
var _drawn: Array[GeometryInstance3D] = []
var _target: Node3D
var _clock := 0.0
var _hit := 0.0
var _locked := 0.0
var _locked_goal := 0.0
var _unstable := 0.0
var _poll := 0.0
var _seed := 0.0
## What the shaders were last told of the flash, the lock and the glitch (the clock goes every frame).
var _sent_hit := -1.0
var _sent_locked := -1.0
var _sent_unstable := -1.0

static var _shell_material: ShaderMaterial
static var _core_material: ShaderMaterial
static var _glyph_material: ShaderMaterial
static var _glyph_mesh: QuadMesh


## The art `script` names, built for `target`, or the plain look when it names none.
static func make(script: Script, target: Node3D = null) -> DaemonArt:
	var art: DaemonArt = script.new() if is_art(script) else DaemonArt.new()
	art.setup(target)
	return art


## True when `script` is a daemon's art: this script or one extending it.
static func is_art(script: Script) -> bool:
	var s := script
	while s != null:
		if s == DaemonArt:
			return true
		s = s.get_base_script()
	return false


func setup(target: Node3D) -> void:
	_target = target
	name = "Art"
	add_to_group(GROUP)
	_seed = float(absi(hash(String(target.name) if target != null else "daemon")) % 1000) / 1000.0
	_kit = ShapeKit.new()
	_build()
	_commit()
	_kit = null
	_send(true)


# --- What the daemon tells it. ---

## A hit landed: the shells, the core and the glyphs flare and fade over FLASH_S.
func flash() -> void:
	_hit = 1.0
	_send(true)


## The glitch of rematerialising: 1 just back, 0 whole.
func set_unstable(amount: float) -> void:
	_unstable = clampf(amount, 0.0, 1.0)
	_send(true)


func hit_glow() -> float:
	return _hit


func lock_glow() -> float:
	return _locked


func unstable() -> float:
	return _unstable


func clock() -> float:
	return _clock


## The core's mesh node, for the checks.
func core_node() -> MeshInstance3D:
	return _layers[0]["mesh"] if not _layers.is_empty() else null


func glyphs() -> MultiMeshInstance3D:
	return _glyphs


## Triangles in the whole daemon: its budget.
func triangles() -> int:
	var total := 0
	for node in _drawn:
		if node is MeshInstance3D:
			var m := (node as MeshInstance3D).mesh as ArrayMesh
			for s in m.get_surface_count():
				total += m.surface_get_array_len(s) / 3
		elif node is MultiMeshInstance3D:
			total += (node as MultiMeshInstance3D).multimesh.instance_count * 2
	return total


## Draw calls for the whole daemon: a surface each, the glyphs one.
func draw_calls() -> int:
	var total := 0
	for node in _drawn:
		total += (node as MeshInstance3D).mesh.get_surface_count() if node is MeshInstance3D else 1
	return total


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	# The game's own pace: delta is scaled with the engine's time, so SIGSTOP slows it all.
	_clock = fmod(_clock + delta, CLOCK_WRAP)
	_hit = maxf(_hit - delta / FLASH_S, 0.0)
	_poll -= delta
	if _poll <= 0.0:
		_poll = LOCK_POLL_S
		_locked_goal = 1.0 if _marked() else 0.0
	_locked = move_toward(_locked, _locked_goal, LOCK_EASE * delta)
	for layer in _layers:
		var mesh: MeshInstance3D = layer["mesh"]
		if mesh != null and layer["turns"] != 0.0:
			mesh.rotate_object_local(Vector3.UP, TAU * layer["turns"] * delta)
	if _glyphs != null:
		_glyphs.rotate_object_local(Vector3.UP, TAU * glyph_turns * delta)
	position.y = sin(TAU * hover_hz * _clock + _seed * TAU) * hover_m
	_send(false)


## True when a grep lock on this machine marks the daemon this dresses.
func _marked() -> bool:
	if _target == null or not is_inside_tree():
		return false
	for lock in get_tree().get_nodes_in_group(GREP_GROUP):
		if lock.has_method("has_mark") and lock.has_mark(_target):
			return true
	return false


## The instance uniforms on every drawn part: the clock every frame, the rest when they change (or
## all of them when `all`). Nothing is made here: it runs every frame.
func _send(all: bool) -> void:
	var hit := all or _hit != _sent_hit
	var locked := all or _locked != _sent_locked
	var unstable := all or _unstable != _sent_unstable
	for node in _drawn:
		node.set_instance_shader_parameter("clock", _clock)
		if hit:
			node.set_instance_shader_parameter("hit", _hit)
		if locked:
			node.set_instance_shader_parameter("locked", _locked)
		if unstable:
			node.set_instance_shader_parameter("unstable", _unstable)
	_sent_hit = _hit
	_sent_locked = _locked
	_sent_unstable = _unstable


# --- Building. ---

## The type's shapes. The plain look: a short obsidian column round a red core.
func _build() -> void:
	var still := layer(0.0)
	core_spike(still, Vector3(0.0, -0.2, 0.0), Vector3(0.0, 0.3, 0.0), 0.12, 6)
	var turning := layer(0.08)
	for i in 6:
		var a := TAU * i / 6.0
		shell_spike(turning, Vector3(cos(a), -2.6, sin(a)) * 0.3, Vector3(cos(a), 2.4, sin(a)) * 0.25, 0.06, 4, 0.4)


## A new layer turning `turns` times a second about its own Y, tilted by `tilt` (degrees about X, Y
## and Z). Returns its index for the shapes. Layer 0 is the core's.
func layer(turns: float, tilt: Vector3 = Vector3.ZERO) -> int:
	_layers.append({"shell": _kit.bucket(Vector3.ZERO, true), "core": _kit.bucket(), "turns": turns, "tilt": tilt, "node": null, "mesh": null})
	return _layers.size() - 1


func shell_spike(at: int, from: Vector3, to: Vector3, radius: float, sides: int, waist: float = 0.5, phase: float = 0.0) -> void:
	_kit.spike(_layers[at]["shell"], from, to, radius, sides, waist, phase)


func core_spike(at: int, from: Vector3, to: Vector3, radius: float, sides: int, waist: float = 0.5, phase: float = 0.0) -> void:
	_kit.spike(_layers[at]["core"], from, to, radius, sides, waist, phase)


func shell_prism(at: int, center: Vector3, radius: float, length: float, sides: int, turn: Vector3 = Vector3.ZERO, end_radius: float = -1.0, phase: float = 0.0) -> void:
	_kit.prism(_layers[at]["shell"], center, radius, length, sides, turn, end_radius, phase)


func core_prism(at: int, center: Vector3, radius: float, length: float, sides: int, turn: Vector3 = Vector3.ZERO, end_radius: float = -1.0, phase: float = 0.0) -> void:
	_kit.prism(_layers[at]["core"], center, radius, length, sides, turn, end_radius, phase)


static func _materials() -> void:
	if _shell_material != null:
		return
	_shell_material = Palette.daemon_shell_material()
	_core_material = Palette.daemon_core_material()
	_glyph_material = Palette.daemon_glyph_material()
	_glyph_mesh = QuadMesh.new()
	_glyph_mesh.size = Vector2.ONE


## The merge: each layer one node with one mesh, the obsidian a surface and the core another; the
## glyphs one MultiMesh.
func _commit() -> void:
	_materials()
	for i in _layers.size():
		var info: Dictionary = _layers[i]
		var mesh := ArrayMesh.new()
		for part in [["shell", _shell_material], ["core", _core_material]]:
			if _kit.count(info[part[0]]) > 0:
				_kit.commit(info[part[0]], mesh)
				mesh.surface_set_material(mesh.get_surface_count() - 1, part[1])
		var holder := Node3D.new()
		holder.name = "Layer%d" % i
		holder.basis = ShapeKit.basis(info["tilt"])
		add_child(holder)
		info["node"] = holder
		if mesh.get_surface_count() == 0:
			continue
		var node := MeshInstance3D.new()
		node.name = "Mesh"
		node.mesh = mesh
		# The core is light, not a solid: only the obsidian throws a shadow.
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if _kit.count(info["shell"]) > 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(node)
		info["mesh"] = node
		_drawn.append(node)
		node.set_instance_shader_parameter("core_color", core_color)
		node.set_instance_shader_parameter("gutter", gutter)
		node.set_instance_shader_parameter("seed", _seed)
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
