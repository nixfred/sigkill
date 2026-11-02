class_name CoopBody
extends Node3D
## A co-op player's body as the partner sees it (W6, PRD 5.5): made in code from simple shapes, each seat its own figure
## so the two never read as copies, and neither as `~`'s copies (STORY.md: dark, the prompt lit red): bright, light-edged,
## the nixfred hexagon for a head with its prompt lit in the player's colour.
##   player 1, teal, `>_`: the operator: slim, a high collar, light bars on the shoulders, two long coat tails that swing
##             behind it as it runs, the head pointy-top as the brand draws it
##   player 2, azure, `$_`: the operator's partner: broader, square pauldrons, a turning halo of six bars behind its head
##             (flat-top), a mast on its back with a blinking tip, rings of light on its forearms
## Both hold a rifle along their aim (pitched with the view), walk with their speed, and carry a name tag the partner sees
## through walls. Downed, the body falls to its knees and over, a ring of light on the floor marks where a partner stands
## to revive it (its progress filling it), and a beacon of light rises through walls with the job-control line
## ("[2]+  Stopped"). Visual only: no hit volume (the player's own body is the player's capsule), no brain.
## Drawn on its seat's body layer (scripts/coop/coop_screen.gd), so its own tile never sees it.

const Palette = preload("res://scripts/palette.gd")

## Heights from the body's origin (the player's capsule's middle; the feet at FEET below).
const FEET := -0.9
const HIP := -0.05
const CHEST := 0.32
const NECK := 0.56
const HEAD := 0.78
## A full stride's swing of the legs, radians, at a run.
const SWING := 0.75
const STRIDE_HZ := 1.6
## The revive's fill: rings running outward (their spacing in the disc's own units, so they spread as it grows), a soft
## floor under them and a bright edge at the progress.
const FILL_SHADER := """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color = vec4(0.2, 0.6, 1.0, 0.5);
varying vec2 p;
void vertex() { p = VERTEX.xz; }
void fragment() {
	float r = length(p);
	float rings = 1.0 - smoothstep(0.0, 0.22, abs(fract(r * 5.0 - TIME * 1.3) - 0.5) * 2.0 - 0.55);
	float edge = smoothstep(0.82, 0.98, r) * (1.0 - smoothstep(0.98, 1.0, r));
	ALBEDO = tint.rgb;
	ALPHA = clamp(tint.a * (0.25 + 0.9 * rings * r + 2.2 * edge), 0.0, 1.0);
}
"""
## The revive ring's radius (the mode's reach).
const RING_R := 2.4

var seat := 1
var hue := Color(0.1, 0.83, 0.77)
var hue_hi := Color(0.49, 1.0, 0.81)
## Set by the mode every frame: 0 standing to 1 down; the revive's progress (0 to 1); the player it belongs to.
var slump := 0.0
var revive := 0.0
var player: Node3D = null

var _armor: StandardMaterial3D
var _light: StandardMaterial3D
var _light_hi: StandardMaterial3D
var _ring_mat: StandardMaterial3D
var _beacon_mat: StandardMaterial3D
var _rig: Node3D
var _torso: Node3D
var _head: Node3D
var _halo: Node3D
var _arms: Node3D
var _legs: Array[Node3D] = []
var _tails: Array[Node3D] = []
var _tip: MeshInstance3D
var _ring: MeshInstance3D
var _fill: MeshInstance3D
var _beacon: MeshInstance3D
var _tag: Label3D
var _down_tag: Label3D
var _phase := 0.0
var _clock := 0.0


func _ready() -> void:
	name = "CoopBody%d" % seat
	_armor = StandardMaterial3D.new()
	_armor.albedo_color = Color(0.05, 0.06, 0.07)
	_armor.metallic = 0.75
	_armor.roughness = 0.28
	_armor.rim_enabled = true
	_armor.rim = 0.6
	_armor.rim_tint = 0.8
	_light = _glow(hue, 4.2)
	_light_hi = _glow(hue_hi, 6.0)
	_rig = Node3D.new()
	_rig.name = "Rig"
	add_child(_rig)
	_build()
	_build_down()
	CoopScreen.set_layers(self, CoopScreen.BODY[seat])


static func _glow(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c.darkened(0.3)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.roughness = 0.4
	return m


func _box(parent: Node3D, size: Vector3, at: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat
	m.position = at
	m.rotation = rot
	parent.add_child(m)
	if mat == _armor and size.y >= 0.2 and size.x >= 0.06:
		# Light along the armour's front edges, Tron style: the plate drawn by its seams.
		for side in [-1.0, 1.0]:
			var e := MeshInstance3D.new()
			var eb := BoxMesh.new()
			eb.size = Vector3(0.012, size.y * 0.86, 0.012)
			e.mesh = eb
			e.material_override = _light
			e.position = Vector3(side * (size.x * 0.5 - 0.004), 0.0, -size.z * 0.5 - 0.002)
			m.add_child(e)
	return m


func _hex(parent: Node3D, r_top: float, r_bottom: float, h: float, at: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bottom
	c.height = h
	c.radial_segments = 6
	c.rings = 1
	m.mesh = c
	m.material_override = mat
	m.position = at
	m.rotation = rot
	parent.add_child(m)
	return m


func _build() -> void:
	var broad := 1.0 if seat == 1 else 1.22
	# Pelvis and torso: hexagon columns, the chest tapering up to the shoulders.
	_hex(_rig, 0.17 * broad, 0.15 * broad, 0.2, Vector3(0, HIP, 0), _armor)
	_torso = Node3D.new()
	_torso.position = Vector3(0, HIP + 0.08, 0)
	_rig.add_child(_torso)
	_hex(_torso, 0.25 * broad, 0.16 * broad, 0.5, Vector3(0, 0.27, 0), _armor)
	_box(_torso, Vector3(0.05, 0.38, 0.02), Vector3(0, 0.28, -0.2 * broad), _light)  # the chest's seam
	_box(_torso, Vector3(0.3 * broad, 0.025, 0.02), Vector3(0, 0.12, -0.17 * broad), _light)
	if seat == 1:
		_box(_torso, Vector3(0.34, 0.12, 0.3), Vector3(0, 0.56, 0.02), _armor)  # the high collar
		_box(_torso, Vector3(0.36, 0.02, 0.02), Vector3(0, 0.62, -0.13), _light_hi)
		for side in [-1.0, 1.0]:
			_box(_torso, Vector3(0.2, 0.08, 0.26), Vector3(side * 0.3, 0.5, 0), _armor)
			_box(_torso, Vector3(0.2, 0.015, 0.02), Vector3(side * 0.3, 0.545, -0.13), _light_hi)
		# Coat tails: two long plates from the waist, swinging behind.
		for side in [-1.0, 1.0]:
			var tail := Node3D.new()
			tail.position = Vector3(side * 0.1, HIP + 0.02, 0.12)
			_rig.add_child(tail)
			_box(tail, Vector3(0.14, 0.62, 0.025), Vector3(0, -0.31, 0), _armor)
			_box(tail, Vector3(0.015, 0.6, 0.03), Vector3(side * 0.07, -0.31, 0), _light)
			_tails.append(tail)
	else:
		for side in [-1.0, 1.0]:
			_box(_torso, Vector3(0.24, 0.16, 0.34), Vector3(side * 0.36, 0.48, 0), _armor)  # square pauldrons
			_box(_torso, Vector3(0.02, 0.12, 0.3), Vector3(side * 0.485, 0.48, 0), _light)
		# The mast on its back, a blinking tip.
		_box(_torso, Vector3(0.22, 0.3, 0.12), Vector3(0, 0.35, 0.24), _armor)
		_box(_torso, Vector3(0.025, 0.72, 0.025), Vector3(0.08, 0.72, 0.28), _armor)
		_tip = MeshInstance3D.new()
		var tip := SphereMesh.new()
		tip.radius = 0.045
		tip.height = 0.09
		_tip.mesh = tip
		_tip.material_override = _light_hi
		_tip.position = Vector3(0.08, 1.1, 0.28)
		_torso.add_child(_tip)
	# The head: the hexagon, a dark plate with the prompt lit on it.
	_head = Node3D.new()
	_head.position = Vector3(0, HEAD, 0)
	_rig.add_child(_head)
	var flat := seat == 2
	var face := _hex(_head, 0.2, 0.2, 0.08, Vector3.ZERO, _armor, Vector3(PI * 0.5, 0, PI / 6.0 if flat else 0.0))
	face.name = "Face"
	# The hexagon's rim of light, six bars, a gap at each corner (as the brand draws it).
	for i in 6:
		var a0 := TAU * i / 6.0 + (PI / 6.0 if flat else 0.0)
		var a1 := TAU * (i + 1) / 6.0 + (PI / 6.0 if flat else 0.0)
		var p0 := Vector2(sin(a0), cos(a0)) * 0.235
		var p1 := Vector2(sin(a1), cos(a1)) * 0.235
		var mid := (p0 + p1) * 0.5
		var bar := _box(_head, Vector3(p0.distance_to(p1) * 0.78, 0.03, 0.05), Vector3(mid.x, mid.y, 0), _light)
		bar.rotation.z = atan2(p1.y - p0.y, p1.x - p0.x)
	# The prompt on the face, as the partner reads it from the front (the head looks along -Z, so its own +X is the
	# partner's left): `>_` and `$_` the right way round, never the mirrored `_<` of `~`'s copies.
	var glyph := _light_hi
	if seat == 1:
		_box(_head, Vector3(0.13, 0.03, 0.02), Vector3(0.05, 0.042, -0.05), glyph, Vector3(0, 0, 0.6))
		_box(_head, Vector3(0.13, 0.03, 0.02), Vector3(0.05, -0.042, -0.05), glyph, Vector3(0, 0, -0.6))
		_box(_head, Vector3(0.1, 0.03, 0.02), Vector3(-0.08, -0.09, -0.05), glyph)
	else:
		_box(_head, Vector3(0.11, 0.026, 0.02), Vector3(0.055, 0.065, -0.05), glyph)
		_box(_head, Vector3(0.11, 0.026, 0.02), Vector3(0.055, 0.0, -0.05), glyph)
		_box(_head, Vector3(0.11, 0.026, 0.02), Vector3(0.055, -0.065, -0.05), glyph)
		_box(_head, Vector3(0.026, 0.07, 0.02), Vector3(0.11, 0.033, -0.05), glyph)
		_box(_head, Vector3(0.026, 0.07, 0.02), Vector3(0.0, -0.033, -0.05), glyph)
		_box(_head, Vector3(0.018, 0.19, 0.02), Vector3(0.055, 0.0, -0.05), glyph)
		_box(_head, Vector3(0.09, 0.026, 0.02), Vector3(-0.09, -0.09, -0.05), glyph)
		# The halo: six bars behind the head, turning.
		_halo = Node3D.new()
		_halo.position = Vector3(0, 0, 0.14)
		_head.add_child(_halo)
		for i in 6:
			var a := TAU * i / 6.0
			var bar := _box(_halo, Vector3(0.24, 0.025, 0.025), Vector3(sin(a), cos(a), 0) * 0.36, _light)
			bar.rotation.z = -a
	# Arms holding a rifle along the aim.
	_arms = Node3D.new()
	_arms.position = Vector3(0, CHEST + 0.12, 0)
	_rig.add_child(_arms)
	for side in [-1.0, 1.0]:
		_box(_arms, Vector3(0.09, 0.09, 0.42), Vector3(side * 0.2 * broad, -0.06, -0.16), _armor, Vector3(0.0, -side * 0.35, 0.0))
		if seat == 2:
			_box(_arms, Vector3(0.11, 0.11, 0.025), Vector3(side * 0.16 * broad, -0.06, -0.3), _light)
	_box(_arms, Vector3(0.08, 0.1, 0.72), Vector3(0.06, -0.04, -0.46), _armor)
	_box(_arms, Vector3(0.015, 0.015, 0.7), Vector3(0.06, 0.015, -0.46), _light_hi)
	_box(_arms, Vector3(0.03, 0.03, 0.03), Vector3(0.06, -0.04, -0.83), _light_hi)
	# Legs, swung from the hips.
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.1 * broad, HIP - 0.06, 0)
		_rig.add_child(leg)
		_box(leg, Vector3(0.12, 0.42, 0.13), Vector3(0, -0.21, 0), _armor)
		_box(leg, Vector3(0.1, 0.4, 0.12), Vector3(0, -0.6, 0.02), _armor)
		_box(leg, Vector3(0.02, 0.3, 0.02), Vector3(side * 0.06, -0.58, -0.05), _light)
		_box(leg, Vector3(0.13, 0.05, 0.22), Vector3(0, -0.8, -0.04), _armor)
		_legs.append(leg)
	# Its presence on the floor: a soft disc of its light under its feet, and a small light of its own on the floor round it.
	var foot := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.62
	disc.bottom_radius = 0.62
	disc.height = 0.01
	disc.radial_segments = 6
	foot.mesh = disc
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.albedo_color = Color(hue, 0.32)
	foot.material_override = fm
	foot.position = Vector3(0, FEET + 0.02, 0)
	foot.rotation.y = PI / 6.0 if seat == 2 else 0.0
	add_child(foot)
	var glow := OmniLight3D.new()
	glow.light_color = hue
	glow.light_energy = 1.4
	glow.omni_range = 3.2
	glow.shadow_enabled = false
	glow.position = Vector3(0, CHEST, -0.3)
	_rig.add_child(glow)
	# The name tag, through walls, small.
	_tag = Label3D.new()
	_tag.text = "p%d %s" % [seat, CoopScreen.PROMPT[seat]]
	_tag.font = Palette.mono_font()
	_tag.font_size = 36
	_tag.pixel_size = 0.006
	_tag.outline_size = 8
	_tag.outline_modulate = Color(0, 0, 0, 0.8)
	_tag.modulate = Color(hue_hi, 0.9)
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true
	_tag.shaded = false
	_tag.position = Vector3(0, HEAD + 0.5, 0)
	add_child(_tag)


func _build_down() -> void:
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_ring_mat.albedo_color = Color(hue_hi, 0.9)
	_ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = RING_R - 0.07
	torus.outer_radius = RING_R
	torus.rings = 48
	torus.ring_segments = 4
	_ring.mesh = torus
	_ring.material_override = _ring_mat
	_ring.position = Vector3(0, FEET + 0.04, 0)
	add_child(_ring)
	_fill = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.01
	disc.radial_segments = 48
	_fill.mesh = disc
	# The fill (folded in with W7: it read as a flat floor of colour from right over it): rings of light running out
	# from the middle to a bright edge that is the progress itself, so it reads as filling from any angle.
	var fill_shader := Shader.new()
	fill_shader.code = FILL_SHADER
	var fill_mat := ShaderMaterial.new()
	fill_mat.shader = fill_shader
	fill_mat.set_shader_parameter("tint", Color(hue, 0.2))
	_fill.material_override = fill_mat
	_fill.position = Vector3(0, FEET + 0.03, 0)
	add_child(_fill)
	_beacon_mat = StandardMaterial3D.new()
	_beacon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beacon_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beacon_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_beacon_mat.no_depth_test = true
	_beacon_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beacon_mat.albedo_color = Color(1.0, 0.2, 0.3, 0.35)
	_beacon = MeshInstance3D.new()
	var col := CylinderMesh.new()
	col.top_radius = 0.06
	col.bottom_radius = 0.22
	col.height = 14.0
	col.radial_segments = 12
	_beacon.mesh = col
	_beacon.material_override = _beacon_mat
	_beacon.position = Vector3(0, FEET + 7.0, 0)
	add_child(_beacon)
	_down_tag = Label3D.new()
	_down_tag.font = Palette.mono_font()
	_down_tag.font_size = 44
	_down_tag.pixel_size = 0.007
	_down_tag.outline_size = 10
	_down_tag.outline_modulate = Color(0, 0, 0, 0.9)
	_down_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_down_tag.no_depth_test = true
	_down_tag.shaded = false
	_down_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_down_tag.position = Vector3(0, 2.6, 0)
	add_child(_down_tag)
	for n in [_ring, _fill, _beacon, _down_tag]:
		n.visible = false


func _process(delta: float) -> void:
	_clock += delta
	var speed := 0.0
	var pitch := 0.0
	if player != null and is_instance_valid(player):
		speed = Vector2(player.velocity.x, player.velocity.z).length()
		if player.has_method("view_pitch"):
			pitch = player.view_pitch()
	var run := clampf(speed / 7.0, 0.0, 1.0)
	_phase = wrapf(_phase + delta * TAU * STRIDE_HZ * (0.4 + run), 0.0, TAU)
	var swing := sin(_phase) * SWING * run * (1.0 - slump)
	if _legs.size() == 2:
		_legs[0].rotation.x = swing
		_legs[1].rotation.x = -swing
	for i in _tails.size():
		_tails[i].rotation.x = 0.25 + run * 0.7 + sin(_phase * 2.0 + i) * 0.12 * (0.3 + run)
	# The aim: head and arms pitched with the view (the body turns with the player).
	_head.rotation.x = pitch * 0.6
	_arms.rotation.x = pitch
	if _halo != null:
		_halo.rotation.z = _clock * 0.9
	if _tip != null:
		_tip.visible = fmod(_clock, 1.1) < 0.5
	# Down: to the knees and over, the ring and beacon up.
	var s := slump
	_rig.rotation.x = -1.15 * s
	_rig.position = Vector3(0, -0.55 * s, 0.15 * s)
	_arms.rotation.x = lerpf(pitch, 0.9, s)
	if _legs.size() == 2:
		for leg in _legs:
			leg.rotation.x = lerpf(leg.rotation.x, 1.3, s)
	var downed := s > 0.05
	for n in [_ring, _fill, _beacon, _down_tag]:
		n.visible = downed
	_tag.visible = not downed
	if downed:
		var pulse := 0.6 + 0.4 * sin(_clock * 6.0)
		_ring_mat.albedo_color = Color(hue_hi.lerp(Color(1.0, 0.25, 0.3), 0.5 * (1.0 - revive)), 0.55 + 0.4 * pulse)
		_fill.scale = Vector3(RING_R * revive, 1.0, RING_R * revive)
		_fill.visible = revive > 0.0
		_beacon_mat.albedo_color = Color(Color(1.0, 0.2, 0.3).lerp(hue, revive), 0.22 + 0.18 * pulse)
		_down_tag.modulate = Color(1.0, 0.45, 0.5).lerp(hue_hi, revive)
		_down_tag.text = "[%d]+  Stopped" % seat if revive <= 0.0 else "fg %%%d" % seat
