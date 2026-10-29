class_name PipeArc
extends Node3D
## pipe |'s chain as it is drawn (C30): one per shooter, made once and kept (the player's own; on a match's
## screens one under each avatar that fires the pipe). Fed a chain (fire(): where the stream leaves the
## muzzle, then each link's point in order), it draws the stream racing link to link: every arc a jagged
## ribbon of brass light round a hot core (shaders/pipe_arc.gdshader), braided with two thinner filaments
## straying round it, all re-jagged JAG_HZ times a second and bowed a little like a cable, and never wider
## on screen than a share of the eye's distance (so the arc from the muzzle is a thread, not a cone). Down
## the main arc ride the packets: bright "|" bars across it, PACKET_M apart, flowing from source to sink (the
## pipe's own glyph, the data in the stream). Each link lights LINK_DELAY_S after the one before (the head
## of the stream racing down the arc, its packets behind it), a bloom on it and a spill of packets flung on
## from it (the particle pool's pipe kind), the chain's last link spilling the most; a crackle at the first.
## A miss draws the stream into the open (or onto the level) and lights nothing. It holds HOLD_S once the
## last link is lit, then fades over FADE_S. Nothing is made per frame: one ImmediateMesh rebuilt in place,
## one MultiMesh of blooms.
##
## Cosmetic: what a chain reaches and what it does are judged by the shooter (alone) or the host.

const Palette = preload("res://scripts/palette.gd")
const ArcShader = preload("res://shaders/pipe_arc.gdshader")
const Sfx = preload("res://scripts/sfx_synth.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")

## The most links one chain shows (the tuning's own most).
const LINKS_LAST := 8
## How long after the one before each link lights, how long the chain holds once the last is lit, and how
## long it then takes to fade.
const LINK_DELAY_S := 0.04
const HOLD_S := 0.24
const FADE_S := 0.22
## The jag: a kink every KINK_M along an arc (at most KINKS_LAST), straying up to STRAY_M from the line,
## re-drawn JAG_HZ times a second; the side filaments stray SIDE_STRAY times as far. Every arc bows up by
## BOW of its length (at most BOW_LAST_M), a cable of light.
const KINK_M := 0.4
const KINKS_LAST := 28
const STRAY_M := 0.17
const SIDE_STRAY := 1.8
const JAG_HZ := 26.0
const BOW := 0.05
const BOW_LAST_M := 0.6
## The ribbons' widths, metres: the main arc and each of its two side filaments, their weight; and the
## most any is wide as a share of its distance from the eye.
const WIDTH_M := 0.34
const SIDE_WIDTH_M := 0.08
const SIDE_WEIGHT := 0.5
const EYE_SHARE := 0.03
## The packets: one every PACKET_M down the main arc, flowing at PACKET_SPEED metres a second, each a bar
## PACKET_LONG_M along the arc and PACKET_ACROSS times the arc's width across it.
const PACKET_M := 0.55
const PACKET_SPEED := 18.0
const PACKET_LONG_M := 0.05
const PACKET_ACROSS := 1.7
## The bloom on each link: its radius, energy, and how much bigger it starts.
const BLOOM_R := 0.13
const BLOOM_ENERGY := 2.6
const BLOOM_POP := 2.2
const BLOOM_POP_S := 0.16
## The packets each link spills (a share of the pool's), and the chain's last.
const SPILL := 0.6
const SPILL_LAST := 1.0
## The crackle: its loudness and how far it carries.
const CRACKLE_GAIN := 0.5
const CRACKLE_UNIT := 6.0

## Its colours (C33): the shooter's skin of pipe |, the stock brass until painted.
var body := Palette.PIPE
var hot := Palette.PIPE_HI
var light := Palette.PIPE_TEXT
var _ribbons: MeshInstance3D
var _mesh: ImmediateMesh
var _material: ShaderMaterial
var _blooms: MultiMeshInstance3D
var _crackle: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()
## The stream: where it left, then every point it reached (links first, a miss's end after them).
var _points := PackedVector3Array()
var _linked := 0
var _age := -1.0
var _strength := 0.0
var _clock := 0.0
var _jag := 0
var _jag_left := 0.0
var _spilled := 0
var _fired := 0
var _packets := 0


func _init() -> void:
	name = "PipeArc"


func _ready() -> void:
	top_level = true
	_mesh = ImmediateMesh.new()
	_material = ShaderMaterial.new()
	_material.shader = ArcShader
	_material.set_shader_parameter("color", body)
	_material.set_shader_parameter("hot", hot)
	_material.set_shader_parameter("packet_m", PACKET_M)
	_material.set_shader_parameter("packet_speed", PACKET_SPEED)
	_ribbons = MeshInstance3D.new()
	_ribbons.name = "Arcs"
	_ribbons.mesh = _mesh
	_ribbons.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Its vertices are placed in the world each frame: the node itself stays at the origin, unturned.
	_ribbons.top_level = true
	_ribbons.global_transform = Transform3D.IDENTITY
	add_child(_ribbons)
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 10
	sphere.rings = 5
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sphere
	mm.instance_count = LINKS_LAST
	mm.visible_instance_count = 0
	_blooms = MultiMeshInstance3D.new()
	_blooms.name = "Blooms"
	_blooms.multimesh = mm
	_blooms.material_override = Palette.glow(light, BLOOM_ENERGY)
	_blooms.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_blooms.top_level = true
	add_child(_blooms)
	_crackle = AudioStreamPlayer3D.new()
	_crackle.name = "Crackle"
	_crackle.stream = Sfx.pipe_crackle()
	_crackle.bus = SettingsApply.EFFECTS
	_crackle.volume_db = linear_to_db(CRACKLE_GAIN)
	_crackle.unit_size = CRACKLE_UNIT
	_crackle.top_level = true
	add_child(_crackle)
	_ribbons.visible = false


## A chain: the stream leaves `from` (world space) and reaches each of `points` in order; the first
## `linked` of them are links (the rest, at most one, where a miss ended).
## The arcs in the light skin `skin` (C33, scripts/palette.gd): their sheath in the skin's body, their cores and
## packets in its hot colour, the blooms at each link in its beam colour.
func paint(skin: String) -> void:
	body = Palette.skin_body(skin)
	hot = Palette.skin_hot(skin)
	light = Palette.skin_beam(skin)
	if _material == null:
		return
	_material.set_shader_parameter("color", body)
	_material.set_shader_parameter("hot", hot)
	_blooms.material_override = Palette.glow(light, BLOOM_ENERGY)


func fire(from: Vector3, points: PackedVector3Array, linked: int) -> void:
	if not from.is_finite() or points.is_empty():
		return
	var stream := PackedVector3Array([from])
	for p in points.slice(0, LINKS_LAST + 1):
		if not p.is_finite():
			return
		stream.append(p)
	_points = stream
	_linked = clampi(linked, 0, mini(points.size(), LINKS_LAST))
	_age = 0.0
	_strength = 1.0
	_spilled = 0
	_fired += 1
	_jag += 1
	_jag_left = 1.0 / JAG_HZ
	_ribbons.visible = true
	if _crackle.is_inside_tree():
		_crackle.global_position = _points[1]
		_crackle.play()
	_draw()


## Lets go at once (a death, a swap): it fades from now.
func stop() -> void:
	if _age >= 0.0:
		_age = maxf(_age, _held_until())


## True while a chain is drawn.
func on() -> bool:
	return _age >= 0.0


## How many links are lit now, how many chains it has drawn, its strength, the stream's points (the
## muzzle's first) and the packets riding it, for the checks.
func lit() -> int:
	return clampi(floori(_age / LINK_DELAY_S), 0, _linked) if _age >= 0.0 else 0


func fired() -> int:
	return _fired


func strength() -> float:
	return _strength if _age >= 0.0 else 0.0


func points() -> PackedVector3Array:
	return _points


func packets() -> int:
	return _packets if _age >= 0.0 else 0


func _process(delta: float) -> void:
	if _age < 0.0:
		return
	_age += delta
	_clock = fmod(_clock + delta, 3600.0)
	var end := _held_until()
	_strength = 1.0 if _age <= end else 1.0 - (_age - end) / FADE_S
	if _strength <= 0.0:
		_age = -1.0
		_strength = 0.0
		_ribbons.visible = false
		_blooms.multimesh.visible_instance_count = 0
		return
	_jag_left -= delta
	if _jag_left <= 0.0:
		_jag += 1
		_jag_left = 1.0 / JAG_HZ
	_draw()


## When the chain starts to fade: its last arc drawn, then its hold.
func _held_until() -> float:
	return float(_points.size() - 1) * LINK_DELAY_S + HOLD_S


## Every arc as far as the stream has raced, every lit link's bloom and spill.
func _draw() -> void:
	_mesh.clear_surfaces()
	_material.set_shader_parameter("flow_s", _clock)
	_packets = 0
	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	var eye: Vector3 = camera.global_position if camera != null else Vector3.INF
	var began := false
	var blooms := _blooms.multimesh
	var shown := 0
	for i in _points.size() - 1:
		var grow := clampf((_age - float(i) * LINK_DELAY_S) / LINK_DELAY_S, 0.0, 1.0)
		if grow <= 0.0:
			break
		if not began:
			_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _material)
			began = true
		_rng.seed = hash(Vector2i(_jag, i))
		_ribbon(_points[i], _points[i + 1], grow, STRAY_M, WIDTH_M, 1.0, eye)
		for _strand in 2:
			_ribbon(_points[i], _points[i + 1], grow, STRAY_M * SIDE_STRAY, SIDE_WIDTH_M, SIDE_WEIGHT, eye)
		if grow < 1.0 or i >= _linked:
			continue
		# Link i is lit: its bloom, and (once) its spill of packets.
		var at := _points[i + 1]
		var since := _age - float(i + 1) * LINK_DELAY_S
		var pop := lerpf(BLOOM_POP, 1.0, clampf(since / BLOOM_POP_S, 0.0, 1.0))
		var r := BLOOM_R * pop * (0.5 + 0.5 * _strength)
		blooms.set_instance_transform(shown, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * r), at))
		shown += 1
		if _spilled <= i:
			_spilled = i + 1
			_spill(i, at)
	blooms.visible_instance_count = shown
	if began:
		_mesh.surface_end()


## One arc from `a` toward `b`, as far as `grow` of the way: a ribbon `width` wide facing `eye`, its kinks
## straying up to `stray` (none at its ends), bowed up; `weight` its brightness. The main arc (weight 1)
## carries the packets.
func _ribbon(a: Vector3, b: Vector3, grow: float, stray: float, width: float, weight: float, eye: Vector3) -> void:
	var span := b - a
	var length := span.length()
	if length < 0.01:
		return
	var way := span / length
	var side := way.cross(Vector3.UP if absf(way.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT).normalized()
	var lift := side.cross(way).normalized()
	var kinks := clampi(ceili(length / KINK_M), 2, KINKS_LAST)
	var bow := minf(length * BOW, BOW_LAST_M)
	var last := ceili(grow * kinks)
	var pts := PackedVector3Array()
	for k in last + 1:
		var u := minf(float(k) / kinks, grow)
		var taper := sin(PI * float(k) / kinks)
		var off := (side * _rng.randf_range(-1.0, 1.0) + lift * _rng.randf_range(-1.0, 1.0)) * stray * taper
		pts.append(a + span * u + lift * (bow * sin(PI * u)) + (off if k < kinks else Vector3.ZERO))
	var along := 0.0
	var color := Color(_strength, weight, 0.0)
	var marks := PackedFloat32Array([0.0])
	for k in pts.size() - 1:
		var p0 := pts[k]
		var p1 := pts[k + 1]
		var v1 := along + p1.distance_to(p0)
		_quad(p0, p1, _facing(p0, p1 - p0, eye) * _width_at(p0, width, eye) * 0.5, _facing(p1, p1 - p0, eye) * _width_at(p1, width, eye) * 0.5, along, v1, color)
		along = v1
		marks.append(along)
	if weight < 1.0:
		return
	# The packets: bars across the main arc, a PACKET_M apart, flowing on from source to sink.
	var bar := Color(_strength, 1.0, 1.0)
	var s := fposmod(_clock * PACKET_SPEED, PACKET_M)
	var seg := 0
	while s < along:
		while seg < marks.size() - 2 and marks[seg + 1] < s:
			seg += 1
		var p0 := pts[seg]
		var p1 := pts[seg + 1]
		var t := (s - marks[seg]) / maxf(marks[seg + 1] - marks[seg], 0.0001)
		var at := p0.lerp(p1, t)
		var on := (p1 - p0).normalized() * PACKET_LONG_M * 0.5
		var across := _facing(at, p1 - p0, eye) * _width_at(at, width, eye) * PACKET_ACROSS * 0.5
		_quad(at - on, at + on, across, across, 0.0, PACKET_LONG_M, bar)
		_packets += 1
		s += PACKET_M


## A quad of the strip from `p0` to `p1`, `s0` and `s1` its half-widths across there, `v0` to `v1` along.
func _quad(p0: Vector3, p1: Vector3, s0: Vector3, s1: Vector3, v0: float, v1: float, color: Color) -> void:
	_vertex(p0 - s0, Vector2(0.0, v0), color)
	_vertex(p0 + s0, Vector2(1.0, v0), color)
	_vertex(p1 + s1, Vector2(1.0, v1), color)
	_vertex(p0 - s0, Vector2(0.0, v0), color)
	_vertex(p1 + s1, Vector2(1.0, v1), color)
	_vertex(p1 - s1, Vector2(0.0, v1), color)


func _vertex(at: Vector3, uv: Vector2, color: Color) -> void:
	_mesh.surface_set_color(color)
	_mesh.surface_set_uv(uv)
	_mesh.surface_add_vertex(at)


## A ribbon's width at `at`: `width`, but never more than EYE_SHARE of its distance from `eye`.
static func _width_at(at: Vector3, width: float, eye: Vector3) -> float:
	return minf(width, at.distance_to(eye) * EYE_SHARE) if eye.is_finite() else width


## The way across a ribbon at `at` running along `way`, turned to face `eye`.
static func _facing(at: Vector3, way: Vector3, eye: Vector3) -> Vector3:
	var to_eye := (eye - at) if eye.is_finite() else Vector3.UP
	var across := way.cross(to_eye)
	if across.length_squared() < 0.000001:
		across = way.cross(Vector3.RIGHT)
	return across.normalized()


## A lit link's spill of packets, flung on the way the stream was going: from link `i` on to the next
## link, or (the last) on along the arc that reached it.
func _spill(i: int, at: Vector3) -> void:
	var fx: ParticleFx = get_tree().get_first_node_in_group(ParticleFx.GROUP) as ParticleFx if is_inside_tree() else null
	if fx == null:
		return
	var last := i == _linked - 1
	var on_to: Vector3 = _points[i + 2] if i + 2 < _points.size() and not last else at + (at - _points[i])
	fx.pipe(at, on_to - at, SPILL_LAST if last else SPILL)
