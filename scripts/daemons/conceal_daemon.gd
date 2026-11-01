extends DaemonArt
## A palette-only daemon (W3, PRD 5.5: "palette-only enemies"): `conceal`, after ANSI's SGR 8, the escape that draws
## text and hides it. It shows only in the theme it belongs to (its key); in every other theme it is concealed: drawn as
## a ripple in the air and nothing else, never lit, never hit and never hitting (the theme shift, scripts/themes/
## theme_shift.gd, holds it asleep and out of reach), until a shift tears its theme in and it prints itself back.
##
## Its own form, not a recoloured daemon (A5's rule): a creature of character cells. A blinking block cursor for a head
## with a crimson slit behind it (its eye, a weak point); under it a page of text, rows of glyph cells curved round it
## like a scroll, each row turning a little behind the one above so the page wrings itself; two arms of cells hanging
## from its shoulders and whipping like cables; a hem of cells falling off its bottom and fading as they go, text
## dissolving. Either side of it a pair of armoured brackets, `[` and `]`, their seams lit crimson: an escape sequence
## with something inside it. Its cells are a terminal's colour test (red, orange, amber, lime, green, teal, blue, violet,
## magenta, set in a row's order), so in its own theme it wears that theme's colours, each cell the theme's own.
##
## It flies as the runaway's brain flies (scripts/fight/daemon_brain.gd, ai_kind "swarm": round its prey, then in dives
## at it). Its tell before a dive: the brackets clamp in on the page, every cell turns the hostile red (SGR 31) and the
## cursor races; the dive snaps them open. A hit scatters its cells a hand's width and the page shudders.
##
## Its tells while concealed (never an invisible enemy with no cue): the ripple of its shape (shaders/conceal_cell.
## gdshader), a soft chirp every few seconds from where it is (an escape sequence's three blips, made in code), and
## under the Audit Trail visor (I) a selection box round it with its theme, the way selecting hidden text shows it.
##
## No two alike (A5): its seed sets how many rows it has and how many cells a row, the page's radius and its wring, its
## arms' length and swing, its hem, the brackets' height, the colour order, a chipped bracket or two and a flickering
## seam; one in twelve an elite, with four arms and taller brackets. Visual only: its dummy keeps its own volume.

const CellShader = preload("res://shaders/conceal_cell.gdshader")
const SfxSynth = preload("res://scripts/sfx_synth.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")

## The colour test its cells print, at the grade's own hue stops (scripts/themes/theme_look.gd), so each lands on the
## theme's colour of that name.
const TEST := [Color(1.0, 0.07, 0.19), Color(1.0, 0.42, 0.1), Color(1.0, 0.69, 0.0), Color(0.72, 1.0, 0.18), Color(0.0, 1.0, 0.25), Color(0.1, 0.83, 0.77), Color(0.3, 0.49, 1.0), Color(0.62, 0.36, 1.0), Color(1.0, 0.3, 1.0)]
const CURSOR := Color(0.92, 0.95, 1.0)
const CELL := Vector3(0.2, 0.2, 0.05)
const ROW_GAP := 0.24
const ARM_GAP := 0.17
const HEAD_Y := 1.25
const BRACKET_X := 0.78
const LIFT := 0.35
## The chirp: how often (seconds, from and to) while concealed, and how far it carries.
const CHIRP_S := Vector2(2.4, 4.2)
const CHIRP_REACH_M := 16.0
## How fast it prints in or wipes out, per second.
const REVEAL_RATE := 1.6

## The theme it shows in (the theme shift sets it), and whether it is shown now.
var key := ""
var shown_wanted := true
## 0 concealed to 1 shown, now.
var reveal := 1.0
## Chirps sounded (the checks).
var chirps := 0

var _rows := 4
var _per_row := PackedInt32Array()
var _radius := 0.32
var _wring := 0.4
var _spin := 0.3
var _arms := 2
var _arm_len := 7
var _hem := 10
var _bracket_h := 1.5
var _order := 0
var _cell_mm: MultiMesh = null
var _cell_node: MultiMeshInstance3D = null
var _cell_mat: ShaderMaterial = null
var _cell_count := 0
var _row_of := PackedInt32Array()
var _eye: int
var _brackets: Array[int] = []
var _bracket_seams: Array[int] = []
var _chirp: AudioStreamPlayer3D = null
var _chirp_wait := 1.0
var _parts_shown := true

static var _chirp_sound: AudioStreamWAV = null


func _build() -> void:
	ai_kind = "swarm"
	core_color = Palette.CRIMSON
	edge_color = Palette.CRIMSON
	glyph_count = 7
	glyph_radius = 1.05
	glyph_low = -0.4
	glyph_high = 1.5
	glyph_size = 0.12
	glyph_turns = 0.09
	reach = AABB(Vector3(-1.4, -1.3, -1.4), Vector3(2.8, 3.4, 2.8))
	tag_height = 2.35
	budget_triangles = 4000
	budget_draw_calls = 9
	size_low = 1.15
	size_high = 1.32
	elite_size = 1.45
	_rows = 5 if elite else pick(80, 0, 3, 5)
	for r in _rows:
		_per_row.append(pick(81, r, 4, 6))
	_radius = lerpf(0.26, 0.38, dice(82, 0))
	_wring = lerpf(0.2, 0.7, dice(83, 0)) * (1.0 if dice(83, 1) > 0.5 else -1.0)
	_spin = lerpf(0.15, 0.45, dice(84, 0))
	_arms = 4 if elite else 2
	_arm_len = pick(85, 0, 6, 9)
	_hem = pick(86, 0, 8, 14)
	_bracket_h = (1.9 if elite else lerpf(1.35, 1.65, dice(87, 0)))
	_order = pick(88, 0, 0, TEST.size() - 1)
	# The armour: the eye, and the two brackets (an upright and two arms each), their seams lit.
	_eye = weak(part(Shape.GEM, Look.CORE))
	for side in 2:
		for k in 3:
			_brackets.append(part(Shape.LIMB, Look.ARMOR))
			_bracket_seams.append(seam(part(Shape.SHARD, Look.CORE)))
	for i in pick(89, 0, 0, 2):
		scorch(_brackets[pick(90, i, 0, _brackets.size() - 1)], lerpf(0.4, 0.9, dice(91, i)))
	flicker(_bracket_seams[pick(92, 0, 0, _bracket_seams.size() - 1)], lerpf(0.15, 0.4, dice(93, 0)))
	_make_cells()


## The cells: one MultiMesh of its own (its own material, for its reveal), colours and glyphs set once.
func _make_cells() -> void:
	var count := 1  # the cursor
	for n in _per_row:
		count += n
	count += _arms * _arm_len + _hem
	_cell_count = count
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	_cell_mm = MultiMesh.new()
	_cell_mm.transform_format = MultiMesh.TRANSFORM_3D
	_cell_mm.use_colors = true
	_cell_mm.use_custom_data = true
	_cell_mm.mesh = box
	_cell_mm.instance_count = count
	_cell_mat = ShaderMaterial.new()
	_cell_mat.shader = CellShader
	_cell_node = MultiMeshInstance3D.new()
	_cell_node.name = "Cells"
	_cell_node.multimesh = _cell_mm
	_cell_node.material_override = _cell_mat
	_cell_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cell_node.custom_aabb = reach
	add_child(_cell_node)
	var i := 0
	_cell_mm.set_instance_color(i, CURSOR)
	_cell_mm.set_instance_custom_data(i, Color(0.5, 0.8, 1.0, 0.0))
	_row_of.append(-1)
	i += 1
	for r in _rows:
		for k in _per_row[r]:
			var c: Color = TEST[(_order + r + k) % TEST.size()]
			_cell_mm.set_instance_color(i, c)
			_cell_mm.set_instance_custom_data(i, Color(dice(94, i), lerpf(0.7, 1.1, dice(95, i)), 1.0, float(r + 1) / float(_rows + 2)))
			_row_of.append(r)
			i += 1
	for a in _arms:
		for k in _arm_len:
			var c: Color = TEST[(_order + a * 3 + k) % TEST.size()]
			_cell_mm.set_instance_color(i, c)
			_cell_mm.set_instance_custom_data(i, Color(dice(96, i), 0.9, 1.0, clampf(0.3 + 0.07 * k, 0.0, 1.0)))
			_row_of.append(100 + a)
			i += 1
	for k in _hem:
		var c: Color = TEST[(_order + k * 2) % TEST.size()]
		_cell_mm.set_instance_color(i, c)
		_cell_mm.set_instance_custom_data(i, Color(dice(97, i), 0.8, 1.0, 1.0))
		_row_of.append(200)
		i += 1
	for j in count:
		_cell_mm.set_instance_transform(j, HIDDEN)


func _ready() -> void:
	if _chirp_sound == null:
		_chirp_sound = _make_chirp()
	_chirp = AudioStreamPlayer3D.new()
	_chirp.name = "Chirp"
	_chirp.stream = _chirp_sound
	_chirp.max_distance = CHIRP_REACH_M
	_chirp.unit_size = 4.0
	_chirp.volume_db = SfxSynth.volume_db(0.32)
	_chirp.bus = SettingsApply.EFFECTS if AudioServer.get_bus_index(SettingsApply.EFFECTS) >= 0 else &"Master"
	add_child(_chirp)
	_chirp_wait = lerpf(CHIRP_S.x, CHIRP_S.y, dice(98, 0))


## Shown (its theme up) or concealed; `at_once` skips the print.
func set_shown(on: bool, at_once: bool = false) -> void:
	shown_wanted = on
	if at_once:
		reveal = 1.0 if on else 0.0
		_apply_reveal()


func concealed() -> bool:
	return reveal <= 0.0


func _pose(t: float, delta: float) -> void:
	reveal = move_toward(reveal, 1.0 if shown_wanted else 0.0, REVEAL_RATE * delta)
	_apply_reveal()
	_step_chirp(delta)
	var tell := drive_amount() if act == Act.TELL else 0.0
	var dive := (1.0 - act_u) * drive_amount() if act == Act.STRIKE else 0.0
	var shake := jolt()
	var mid := recoil() + Vector3(0.0, LIFT + 0.08 * sin(t * 1.3), 0.0)
	var i := 0
	# The cursor: blinking as a terminal's does (racing in its tell), the eye behind it.
	var blink := 1.0 if fposmod(t * (1.06 + 6.0 * tell), 1.0) < 0.55 else 0.0
	var head := mid + Vector3(0.0, HEAD_Y, 0.0)
	_cell(i, head, Basis.from_scale(Vector3(0.22, 0.36, 0.08)), blink * reveal + (1.0 - reveal))
	i += 1
	orient(_eye, head + Vector3(0.0, 0.0, 0.06), Vector3.RIGHT, 0.34 * (1.0 + 0.4 * tell), 0.07)
	brighten(_eye, 1.4 + 3.0 * tell + 2.0 * dive)
	# The page: rows round it, each wrung a little behind the one above.
	for r in _rows:
		var n: int = _per_row[r]
		var y := 1.0 - ROW_GAP * r
		var turn := t * _spin + _wring * float(r) + 0.35 * sin(t * 0.9 + r * 0.7)
		var rad := _radius * (1.0 - 0.35 * tell + 0.25 * dive) + 0.04 * shake * sin(t * 40.0 + r)
		for k in n:
			var a := turn + (float(k) - float(n - 1) * 0.5) * (1.8 / float(n))
			var out := Vector3(sin(a), 0.0, cos(a))
			var at := mid + Vector3(0.0, y, 0.0) + out * rad
			_cell(i, at, Basis.looking_at(out, Vector3.UP) * Basis.from_scale(CELL), 1.0)
			i += 1
	# The arms: chains of cells from its shoulders, a wave running down them.
	for a in _arms:
		var side := -1.0 if a % 2 == 0 else 1.0
		var tier := float(a / 2)
		var shoulder := mid + Vector3(side * (0.42 + 0.08 * tier), 0.92 - 0.3 * tier, 0.0)
		for k in _arm_len:
			var u := float(k + 1)
			var sway := sin(t * (2.2 + 0.3 * a) - u * 0.55 + a) * (0.05 + 0.03 * u)
			var reach_out := side * (0.08 * u + 0.25 * tell * u * 0.2 - 0.15 * dive)
			var at := shoulder + Vector3(reach_out + sway * 0.4, -ARM_GAP * u * (1.0 - 0.5 * dive), sway)
			_cell(i, at, Basis(Vector3.UP, sway * 2.0) * Basis.from_scale(CELL * 0.85), 1.0 - 0.04 * u)
			i += 1
	# The hem: cells falling off its bottom, fading as they go.
	for k in _hem:
		var u := fposmod(t * 0.45 + float(k) / float(_hem), 1.0)
		var a := TAU * dice(99, k) + t * 0.3
		var at := mid + Vector3(cos(a) * _radius * (1.0 - 0.5 * u), -0.15 - 1.0 * u, sin(a) * _radius * (1.0 - 0.5 * u))
		_cell(i, at, Basis(Vector3.UP, a) * Basis.from_scale(CELL * (1.0 - 0.6 * u)), 1.0 - u)
		i += 1
	# The brackets: [ on its left, ] on its right, clamping in on the tell, snapping open on the dive.
	var hb := _bracket_h * 0.5
	for side in 2:
		var s := -1.0 if side == 0 else 1.0
		var x := s * (BRACKET_X - 0.3 * tell + 0.35 * dive)
		var top := mid + Vector3(x, 0.45 + hb, 0.0)
		var bottom := mid + Vector3(x, 0.45 - hb, 0.0)
		var inward := Vector3(-s * 0.34, 0.0, 0.0)
		var b0: int = _brackets[side * 3]
		var b1: int = _brackets[side * 3 + 1]
		var b2: int = _brackets[side * 3 + 2]
		bone(b0, bottom, top, 0.2, 0.16)
		bone(b1, top, top + inward, 0.17, 0.16)
		bone(b2, bottom, bottom + inward, 0.17, 0.16)
		bone(_bracket_seams[side * 3], bottom + Vector3(0, 0, 0.09), top + Vector3(0, 0, 0.09), 0.055, 0.04)
		bone(_bracket_seams[side * 3 + 1], top + Vector3(0, 0, 0.09), top + inward + Vector3(0, 0, 0.09), 0.05, 0.04)
		bone(_bracket_seams[side * 3 + 2], bottom + Vector3(0, 0, 0.09), bottom + inward + Vector3(0, 0, 0.09), 0.05, 0.04)
		for k in 3:
			brighten(_bracket_seams[side * 3 + k], 1.6 + 2.0 * tell + 1.5 * dive)
	if _cell_mat != null:
		_cell_mat.set_shader_parameter("clock", t)
		_cell_mat.set_shader_parameter("tell", tell)
		_cell_mat.set_shader_parameter("flash", hit_glow())


func _cell(i: int, at: Vector3, basis: Basis, presence: float) -> void:
	if i >= _cell_count:
		return
	_cell_mm.set_instance_transform(i, Transform3D(basis, at))
	var c := _cell_mm.get_instance_custom_data(i)
	if c.b != presence:
		c.b = presence
		_cell_mm.set_instance_custom_data(i, c)


## The reveal on its cells' material, and its armour (eye, brackets, glyphs) only while it is more shown than not.
func _apply_reveal() -> void:
	if _cell_mat != null:
		_cell_mat.set_shader_parameter("reveal", reveal)
	var want := reveal > 0.5
	if want == _parts_shown:
		return
	_parts_shown = want
	for node in sets():
		node.visible = want
	if glyphs() != null:
		glyphs().visible = want


## Concealed, a chirp every few seconds from where it is (its tell); never while shown.
func _step_chirp(delta: float) -> void:
	if reveal > 0.0 or _chirp == null or not is_inside_tree():
		return
	_chirp_wait -= delta
	if _chirp_wait > 0.0:
		return
	_chirp_wait = lerpf(CHIRP_S.x, CHIRP_S.y, dice(98, chirps + 1))
	chirps += 1
	_chirp.play()


## Three quick blips falling a little, soft: an escape sequence typed where you cannot see it.
static func _make_chirp() -> AudioStreamWAV:
	var rate := 22050
	var seconds := 0.26
	var count := int(seconds * rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for i in count:
		var tt := float(i) / rate
		var blip := int(tt / 0.085)
		var in_blip := fposmod(tt, 0.085)
		var freq := 2400.0 - 380.0 * blip
		phase = fmod(phase + TAU * freq / rate, TAU)
		var env := minf(in_blip / 0.004, 1.0) * maxf(1.0 - in_blip / 0.05, 0.0)
		var v := (sin(phase) * 0.7 + sin(phase * 2.01) * 0.2) * env * 0.5
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream


## Where its dives start from (its middle) and its lineage line meets it.
func _muzzle() -> Vector3:
	return Vector3(0.0, LIFT + 0.6, 0.0)


func body_box() -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(0.0, LIFT + 0.35, 0.0))


func body_box_size() -> Vector3:
	return Vector3(1.2, 2.3, 0.9)


## The cells' node (the checks).
func cells() -> MultiMeshInstance3D:
	return _cell_node


func cell_count() -> int:
	return _cell_count


## Its build's signature: what its seed chose (the checks: no two alike).
func signature() -> Array:
	return [_rows, Array(_per_row), snappedf(_radius, 0.001), snappedf(_wring, 0.001), _arms, _arm_len, _hem, snappedf(_bracket_h, 0.001), _order]
