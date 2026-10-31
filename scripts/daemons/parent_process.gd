extends DaemonArt
## The parent process (M2, mission 2 `defunct`): the process that started the zombies and never came back for them, so
## nothing ever reaped them. Not a walker: a tower rooted in the street, half again a zombie's height three times over,
## still running. Six armoured roots splay from a hex plinth into the ground; over it five process frames stand one on
## another, each a collar of four armour plates turning about the column, the frames turning opposite ways, and between
## them amber seam rings; inside the column its core burns, one long amber crystal, and over the frames a crown of six
## blades curls out round its anchor, the bright point every one of its children's threads runs to (scripts/missions/
## mission_stage.gd draws them). Faceless: no eye, no mouth, nothing that moves like an animal.
##
## It stands about eleven metres tall (its build at twice a walker's scale), and its core lights the street round it, an
## amber lamp beating with it: dim while sealed, blazing open.
##
## Sealed (its dummy's `sealed`, a mission wave's "sealed"): its frames are drawn in tight round the core, turning
## slowly, the core dim behind them, its seams low; opened, the frames slide out and lean apart, the core shows through
## the gaps and beats, bright and quick, and the seams flare: that is when it can be hurt. Its light is the zombies'
## amber, its parent's colour; its weak points are the core and the anchor.
##
## No two alike (A5's rule, though a mission has one): its seed sets its frames' turning speeds and phases, how far each
## leans when it opens, its roots' spread, the crown's curl and a scorched plate or two. Never an elite. Visual only: its
## dummy keeps its hit volume (a box from the ground to over its crown), its health and its states; it never leaves its
## spot, and its brain (scripts/fight/daemon_brain.gd) never moves it.

const FRAMES := 5
const PLATES_PER_FRAME := 4
const ROOTS := 6
const BLADES := 6
## The column: its first frame's middle, how far apart the frames stand, and a frame plate's size (across, thick, tall).
const FRAME_Y0 := -0.1
const FRAME_STEP := 0.95
const PLATE := Vector3(0.98, 0.17, 0.8)
## A frame's plates' distance out from the column's axis, sealed and open; how far an open frame leans out, radians.
const SEALED_R := 0.46
const OPEN_R := 1.0
const LEAN_MOST := 0.32
## How fast it opens once unsealed (a share a second), and the core's beat, sealed and open, beats a second.
const OPEN_RATE := 0.7
const BEAT_SEALED := 0.5
const BEAT_OPEN := 1.6
## The core's crystal: its middle and length; the anchor's height (where the threads meet) and the crown's.
const CORE_Y := 1.8
const CORE_L := 4.4
const ANCHOR_Y := 4.75
const CROWN_Y := 4.25
## Its hit volume (art space): a box from the ground to over the crown.
const BOX_AT := Vector3(0.0, 2.05, 0.0)
const BOX_SIZE := Vector3(2.1, 5.9, 2.1)
## Its lamp: its reach (art metres, at its scale) and its energy sealed and open, with the beat's on top.
const LAMP_REACH := 9.0
const LAMP_SEALED := 2.2
const LAMP_OPEN := 4.5
const LAMP_BEAT := 3.0

var _plinth: int
var _roots := PackedInt32Array()
var _frames := PackedInt32Array()
var _rings := PackedInt32Array()
var _blades := PackedInt32Array()
var _core: int
var _heart: int
var _anchor: int
var _spin := PackedFloat32Array()
var _phase := PackedFloat32Array()
var _lean := PackedFloat32Array()
var _spread := 1.0
var _curl := 1.0
## How far open it is now (0 sealed, 1 open), and its spin so far per frame.
var _open := 0.0
var _turned := PackedFloat32Array()
## A hit's kick to the frames' spin, easing off.
var _kick := 0.0
var _lamp: OmniLight3D = null


func _build() -> void:
	ai_kind = "parent"
	core_color = Palette.HOSTILE_AMBER
	edge_color = Palette.HOSTILE_AMBER
	gutter = 1.0
	glyph_count = 12
	glyph_radius = 2.1
	glyph_low = 0.2
	glyph_high = 4.6
	glyph_size = 0.2
	glyph_turns = 0.025
	reach = AABB(Vector3(-2.6, -1.0, -2.6), Vector3(5.2, 7.0, 5.2))
	tag_height = 5.55
	budget_triangles = 4200
	budget_draw_calls = 12
	size_low = 1.95
	size_high = 2.05
	elite_size = 1.0
	_lamp = OmniLight3D.new()
	_lamp.name = "CoreLamp"
	_lamp.light_color = Palette.HOSTILE_AMBER
	_lamp.omni_range = LAMP_REACH * 2.0
	_lamp.omni_attenuation = 1.1
	_lamp.shadow_enabled = false
	_lamp.position = Vector3(0.0, CORE_Y, 0.0)
	add_child(_lamp)
	_spread = lerpf(0.9, 1.15, dice(60, 0))
	_curl = lerpf(0.8, 1.2, dice(61, 0))
	_plinth = part(Shape.HEX, Look.ARMOR)
	for i in ROOTS:
		_roots.append(part(Shape.LIMB, Look.ARMOR))
	for k in FRAMES:
		_spin.append(lerpf(0.12, 0.3, dice(62, k)) * (1.0 if k % 2 == 0 else -1.0))
		_phase.append(TAU * dice(63, k))
		_lean.append(lerpf(0.6, 1.0, dice(64, k)))
		_turned.append(0.0)
		for j in PLATES_PER_FRAME:
			_frames.append(part(Shape.PLATE, Look.ARMOR))
	for k in FRAMES + 1:
		_rings.append(seam(part(Shape.RING, Look.CORE)))
	for i in BLADES:
		_blades.append(part(Shape.BLADE, Look.ARMOR))
	_core = weak(part(Shape.GEM, Look.CORE))
	_heart = weak(part(Shape.GEM, Look.CORE))
	_anchor = weak(part(Shape.GEM, Look.CORE))
	# Battle damage: a frame plate or two scorched, a seam ring flickering.
	for i in pick(65, 0, 1, 2):
		scorch(_frames[pick(66, i, 0, _frames.size() - 1)], lerpf(0.5, 1.0, dice(67, i)))
	flicker(_rings[pick(68, 0, 1, FRAMES - 1)], lerpf(0.3, 0.6, dice(69, 0)))


func _pose(t: float, delta: float) -> void:
	var want := 0.0 if _target != null and _target.get("sealed") == true else 1.0
	_open = move_toward(_open, want, OPEN_RATE * delta)
	var open := smoothstep(0.0, 1.0, _open)
	_kick = move_toward(_kick, 0.0, 2.5 * delta)
	var beat_hz := lerpf(BEAT_SEALED, BEAT_OPEN, open)
	var beat := pow(maxf(sin(TAU * beat_hz * t), 0.0), 6.0)
	var shake := recoil()
	# The plinth and the roots, splayed into the ground, flexing a little with the beat.
	orient(_plinth, Vector3(0.0, GROUND_Y + 0.3, 0.0) + shake * 0.3, Vector3.UP, 0.6, 1.9)
	for i in ROOTS:
		var a := TAU * (float(i) + 0.5 * dice(70, i)) / ROOTS
		var out := Vector3(cos(a), 0.0, sin(a))
		var from := out * 0.55 + Vector3(0.0, GROUND_Y + 0.55, 0.0)
		var to := out * (1.75 + 0.35 * dice(71, i)) * _spread + Vector3(0.0, GROUND_Y + 0.02 + 0.03 * beat, 0.0)
		bone(_roots[i], from, to, 0.34)
	# The frames: four plates a collar, each collar turning its own way, drawn in or out and leaning apart.
	for k in FRAMES:
		_turned[k] = fmod(_turned[k] + (_spin[k] * lerpf(0.5, 1.4, open) + _kick * (1.0 if k % 2 == 0 else -1.0)) * delta, TAU)
		var y := FRAME_Y0 + FRAME_STEP * k
		var r := lerpf(SEALED_R, OPEN_R, open) + 0.04 * beat * open
		var lean := LEAN_MOST * _lean[k] * open
		for j in PLATES_PER_FRAME:
			var a := _phase[k] + _turned[k] + TAU * float(j) / PLATES_PER_FRAME
			var radial := Vector3(cos(a), 0.0, sin(a))
			var tangent := Vector3(-sin(a), 0.0, cos(a))
			var tip := Basis(tangent, lean)
			var basis := tip * Basis(tangent * PLATE.x, radial * PLATE.y, Vector3.UP * PLATE.z)
			lay(_frames[k * PLATES_PER_FRAME + j], radial * r + Vector3(0.0, y, 0.0) + shake * (0.5 + 0.15 * k), basis)
	# The seams between the frames: amber rings, low while sealed, flaring open and with each beat.
	for k in _rings.size():
		var y := FRAME_Y0 + FRAME_STEP * (float(k) - 0.5)
		orient(_rings[k], Vector3(0.0, y, 0.0) + shake * 0.4, Vector3.UP, 0.07, lerpf(0.95, 1.5, open))
		brighten(_rings[k], lerpf(0.75, 1.3, open) + 0.6 * beat * open)
	# The core, the heart low in it, the anchor over the crown.
	orient(_core, Vector3(0.0, CORE_Y, 0.0) + shake * 0.5, Vector3.UP, CORE_L, lerpf(0.42, 0.62, open) * (1.0 + 0.08 * beat))
	brighten(_core, lerpf(0.9, 1.9, open) + 1.2 * beat * open + 0.3 * beat * (1.0 - open))
	orient(_heart, Vector3(0.0, 0.7, 0.0) + shake * 0.5, Vector3.UP, 0.9 * (1.0 + 0.2 * beat), 0.7 * (1.0 + 0.25 * beat))
	brighten(_heart, lerpf(0.4, 2.2, open) + 1.6 * beat * open)
	orient(_anchor, Vector3(0.0, ANCHOR_Y + 0.05 * sin(t * 1.3), 0.0), Vector3.UP, 0.5, 0.34)
	brighten(_anchor, 1.6 + 0.8 * beat)
	if _lamp != null:
		_lamp.light_energy = lerpf(LAMP_SEALED, LAMP_OPEN, open) + LAMP_BEAT * beat * open
	# The crown: blades curling out and up round the anchor, opening a little wider with the frames.
	for i in BLADES:
		var a := TAU * float(i) / BLADES + 0.4 * sin(t * 0.25)
		var out := Vector3(cos(a), 0.0, sin(a))
		var root := out * 0.55 + Vector3(0.0, CROWN_Y, 0.0)
		var tip := out * (1.15 + 0.3 * open) * _curl + Vector3(0.0, CROWN_Y + 1.0 - 0.15 * open, 0.0)
		bone(_blades[i], root, tip, 0.12, 0.42, Vector3(-sin(a), 0.0, cos(a)))


## Where its children's threads meet (world space): its anchor over the crown.
func anchor() -> Vector3:
	var local := Vector3(0.0, ANCHOR_Y, 0.0)
	return global_transform * local if is_inside_tree() else transform * local


## How far open it is (0 sealed, 1 open), for the checks.
func opened() -> float:
	return _open


func body_box() -> Transform3D:
	return Transform3D(Basis.IDENTITY, BOX_AT)


func body_box_size() -> Vector3:
	return BOX_SIZE


func _on_hit() -> void:
	_kick = 1.6  # a hit throws its frames round


func _muzzle() -> Vector3:
	return Vector3(0.0, ANCHOR_Y, 0.0)
