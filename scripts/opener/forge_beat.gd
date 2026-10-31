class_name ForgeBeat
extends Node3D
## C42's beat in the machine (PRD 5.7, 1:35 to 2:00: "`kill -9` forges into the rifle; the copy types "you won't."
## Player fires, derezz"), in the world C40's fall landed in (scripts/opener/tree_fall.gd), facing the copy standing on
## the pit's floor (scripts/opener/pit_beat.gd). Everything here is a function of the opener's clock and the one moment
## the player chose, the shot, so the same opener draws the same frames every run. Its moments are the score's
## (scripts/opener/opener_score.gd: the forge in sixteenths from forge_at), so what is seen lands on what is heard.
##
## The forge: `kill -9` types itself in the air between the player and the copy, a letter on each eighth, in the
## player's teal, each letter a block of glowing cells (a 5 by 7 font of our own, each pixel four cells), popping in
## white hot. The letters charge (shaking, heating to white), break into their cells, and the cells stream on curves
## into the player's hands, where the SIGKILL rail rifle (the game's own model of it, scripts/viewmodels/sigkill_rail.gd)
## prints itself from its back to its muzzle as they arrive (shaders/opener_print.gdshader: a white-hot band of hex
## cells sweeping down the barrel, the metal cooling behind it). Its four coils light on the last four sixteenths, and on
## the drop it is whole, in its own colours, and kicks into the hands.
##
## The copy's line, "you won't." (STORY.md's words), types itself in its crimson in the air by its head, a cursor after
## it, while its face's cursor races. From fire_from the player fires (the opener's input); the shot is a beam of the
## rail's white-blue light from the muzzle into the copy's heart, the rifle kicking back; it burns in for BURN_S, then
## the copy flares and shudders;
## on the next beat it bursts: its own parts flung apart (DaemonArt.shatter, as every daemon dies) with a storm of
## crimson and teal voxels in slow, heavy arcs, falling and fading on the floor (the derezz: its memory returned to the
## machine). Nothing here reads anything; the rifle's model is the game's own, built from res://.

const ForgeShader = preload("res://shaders/opener_forge.gdshader")
const PrintShader = preload("res://shaders/opener_print.gdshader")
const Palette = preload("res://scripts/palette.gd")
const RAIL_PATH := "res://resources/sigkill_rail.tres"

## The command, and a 5 by 7 font of our own for it: rows top to bottom, "#" lit.
const WORD := "kill -9"
const FONT := {
	"k": ["#....", "#....", "#..#.", "#.#..", "##...", "#.#..", "#..#."],
	"i": ["..#..", ".....", ".##..", "..#..", "..#..", "..#..", ".###."],
	"l": [".##..", "..#..", "..#..", "..#..", "..#..", "..#..", ".###."],
	"-": [".....", ".....", ".....", ".###.", ".....", ".....", "....."],
	"9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
	" ": [".....", ".....", ".....", ".....", ".....", ".....", "....."],
}
## The copy's line (STORY.md section 5).
const DARE := "you won't."
const CURSOR := "_"
## The letters in the air: how far ahead of the player, how far below the eye, a letter's height; each pixel's cells.
const WORD_M := 2.3
const WORD_DROP := 0.46
const LETTER_M := 0.38
const SUB := 2
const CELL_FILL := 0.82
## The stream: how long a cell takes to fly, at most and least; how high its curve swings.
const FLIGHT_MOST := 1.05
const FLIGHT_LEAST := 0.45
const SWING_M := 0.6
## The rifle's print front, in its own space: its back and its muzzle along Z.
const BACK_Z := 0.27
const MUZZLE_Z := -0.5
## The copy's line by its head: how far to the player's right of it and above; its size.
const DARE_RIGHT := 1.15
const DARE_UP := 0.25
const DARE_PX := 0.0036
## The burst: how many voxels, their size, speed, the pull down, how long they last.
const BURST := 560
const BURST_SIZE := Vector2(0.045, 0.15)
const BURST_SPEED := Vector2(1.6, 8.5)
const GRAVITY := 7.5
const BURST_LIFE := Vector2(0.9, 2.4)
## The beam: how long it burns, its width; how long it burns into the heart before the copy flares.
const BEAM_S := 0.42
const BEAM_W := 0.16
const BURN_S := 0.1
## The rifle's glow here, a share of its own: the machine's glow is tuned for its dark, and the rifle's full charge would
## bloom into one white blur.
const RIFLE_GLOW := 0.32
const SEED := 4242

var _t: OpenerTuning
var _fall: TreeFall
var _pit: PitBeat
var _built := false
var _forge_at := 0.0
var _cells: MultiMeshInstance3D
var _cell_home := PackedVector3Array()
var _cell_letter := PackedInt32Array()
var _cell_to := PackedFloat32Array()
var _cell_spin := PackedVector3Array()
var _cell_fly := PackedFloat32Array()
var _rifle: Viewmodel
var _rifle_meshes: Array[MeshInstance3D] = []
var _rifle_kept: Array = []
var _prints: Array[ShaderMaterial] = []
var _printing := false
var _dare: Label3D
var _beam: MeshInstance3D
var _beam_paint: ShaderMaterial
var _muzzle_light: OmniLight3D
var _heart_light: OmniLight3D
var _burst: MultiMeshInstance3D
var _burst_from := PackedVector3Array()
var _burst_v := PackedVector3Array()
var _burst_life := PackedFloat32Array()
var _burst_size := PackedFloat32Array()
var _burst_axis := PackedVector3Array()
var _shot_at := -1.0
var _hit := false
var _flashed := false
var _shattered := false
var _word_place := Transform3D.IDENTITY
var _rng := RandomNumberGenerator.new()


## Builds the beat for timeline `tuning` in the machine `fall`, beside the copy's beat `pit`; hidden until its moments.
func build(tuning: OpenerTuning, fall: TreeFall, pit: PitBeat) -> void:
	if _built:
		return
	_built = true
	name = "ForgeBeat"
	_t = tuning
	_fall = fall
	_pit = pit
	_forge_at = tuning.forge_at
	_rng.seed = SEED
	_word_place = _place_word(fall.landing())
	_build_cells()
	_build_rifle()
	_build_dare()
	_build_beam()
	_build_burst()


## The moment the shot fires, on the opener's clock (the opener sets it once, from the player's press or fire_by).
func set_shot(at: float) -> void:
	if _shot_at < 0.0:
		_shot_at = at


func shot_at() -> float:
	return _shot_at


# --- The score's moments, in the opener's seconds. ---

## When key `k` of WORD is struck.
func key_at(k: int) -> float:
	return _forge_at + (OpenerScore.FORGE_KEYS_FROM + 2 * k) * OpenerScore.STEP_S


func charge_at() -> float:
	return _forge_at + 16 * OpenerScore.STEP_S


func break_at() -> float:
	return _forge_at + OpenerScore.FORGE_BREAK * OpenerScore.STEP_S


func print_from() -> float:
	return break_at() + 0.25


func print_to() -> float:
	return _forge_at + (OpenerScore.FORGE_COILS - 2) * OpenerScore.STEP_S


func coils_at() -> float:
	return _forge_at + OpenerScore.FORGE_COILS * OpenerScore.STEP_S


func drop_at() -> float:
	return _forge_at + OpenerScore.FORGE_DROP * OpenerScore.STEP_S


func dare_at() -> float:
	return _forge_at + OpenerScore.FORGE_DARE * OpenerScore.STEP_S


## When letter `k` of DARE is typed: a sixteenth each from two sixteenths into the dare.
func dare_key_at(k: int) -> float:
	return dare_at() + (2 + k) * OpenerScore.STEP_S


func shatter_at() -> float:
	return _shot_at + OpenerScore.DEREZZ_BEATS * OpenerScore.BEAT_S if _shot_at >= 0.0 else INF


# --- What the checks read. ---

## The rifle (the game's own model of it), shown or not.
func rifle() -> Viewmodel:
	return _rifle


## Whether the rifle is drawn in its own materials (forged), not the print's.
func forged() -> bool:
	return _rifle != null and _rifle.visible and not _printing


## The copy's line as typed now.
func dare_text() -> String:
	return _dare.text if _dare != null and _dare.visible else ""


## How many of the letters' cells there are, and how many show.
func cell_count() -> int:
	return _cell_home.size()


func cells_showing() -> bool:
	return _cells != null and _cells.visible


func beam_showing() -> bool:
	return _beam != null and _beam.visible


func burst_showing() -> bool:
	return _burst != null and _burst.visible


## The copy's heart in the machine's space (where the beam lands).
func heart() -> Vector3:
	return PitBeat.stand() * CopyArt.heart_at()


# --- Running. ---

## Everything at `elapsed` on the opener's clock; `camera` is the camera's place now.
func step(elapsed: float, camera: Transform3D) -> void:
	if not _built:
		return
	_step_cells(elapsed, camera)
	_step_rifle(elapsed)
	_step_dare(elapsed)
	_step_shot(elapsed, camera)
	_step_burst(elapsed)


## The camera's kick at `elapsed`: [Vector3 (pitch, yaw, roll), metres back, field of view push]: the rifle locking in on
## the drop, the shot's recoil and shake.
func kick_at(elapsed: float) -> Array:
	var euler := Vector3.ZERO
	var back := 0.0
	var fov := 0.0
	var since_drop := elapsed - drop_at()
	if since_drop >= 0.0 and since_drop < 0.8:
		var k := sin(since_drop * 18.0) * exp(-since_drop * 7.0)
		euler.x -= 0.035 * k
		fov -= 4.0 * exp(-since_drop * 6.0) * minf(since_drop * 30.0, 1.0)
	if _shot_at >= 0.0 and elapsed >= _shot_at:
		var s := elapsed - _shot_at
		var k := exp(-s * 6.0)
		euler.x += 0.07 * k * minf(s * 60.0, 1.0)
		euler.y += 0.018 * sin(s * 53.0) * k
		euler.z += 0.012 * sin(s * 41.0) * k
		back += 0.06 * k
		fov += 7.0 * exp(-s * 5.0) * minf(s * 40.0, 1.0)
	return [euler, back, fov]


# --- The letters and their cells. ---

## Where the letters stand: WORD_M ahead of the landed camera, WORD_DROP below its eye, facing it.
static func _place_word(eye: Transform3D) -> Transform3D:
	var ahead := -eye.basis.z
	ahead.y = 0.0
	ahead = ahead.normalized()
	var right := ahead.cross(Vector3.UP).normalized()
	var at := eye.origin + ahead * WORD_M + Vector3.DOWN * WORD_DROP
	return Transform3D(Basis(right, Vector3.UP, -ahead), at)


func _build_cells() -> void:
	var px := LETTER_M / 7.0
	var columns := WORD.length() * 6 - 1
	var left := -columns * px * 0.5
	var homes: Array[Vector3] = []
	for k in WORD.length():
		var rows: Array = FONT.get(WORD[k], FONT[" "])
		for row in 7:
			for col in 5:
				if String(rows[row])[col] != "#":
					continue
				for sy in SUB:
					for sx in SUB:
						var x := left + (k * 6 + col) * px + (sx + 0.5) * px / SUB
						var y := (3.5 - row) * px - (sy + 0.5) * px / SUB + px * 0.5
						homes.append(Vector3(x, y, 0.0))
						_cell_letter.append(k)
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.use_colors = true
	many.use_custom_data = true
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	many.mesh = cube
	many.instance_count = homes.size()
	# Where each cell lands on the rifle: spread down its length in the letters' order, with a little scatter.
	for i in homes.size():
		_cell_home.append(homes[i])
		_cell_to.append(clampf(float(i) / maxf(homes.size() - 1, 1) + _rng.randf_range(-0.06, 0.06), 0.0, 1.0))
		_cell_spin.append(Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)).normalized())
		_cell_fly.append(_rng.randf_range(FLIGHT_LEAST, FLIGHT_MOST))
		many.set_instance_color(i, Palette.TEAL.lerp(Palette.MINT, _rng.randf() * 0.35))
		many.set_instance_custom_data(i, Color(0.0, 0.0, 0.0, 0.0))
	_cells = MultiMeshInstance3D.new()
	_cells.name = "Letters"
	_cells.multimesh = many
	_cells.material_override = _paint(0.0, 2.3)
	_cells.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cells.visible = false
	add_child(_cells)


func _paint(mode: float, energy: float) -> ShaderMaterial:
	var paint := ShaderMaterial.new()
	paint.shader = ForgeShader
	paint.set_shader_parameter("mode", mode)
	paint.set_shader_parameter("energy", energy)
	paint.set_shader_parameter("beam_color", Palette.ICE)
	return paint


func _step_cells(elapsed: float, camera: Transform3D) -> void:
	var on := elapsed >= key_at(0) - 0.01 and elapsed < print_to() + 0.2
	_cells.visible = on
	if not on:
		return
	var many := _cells.multimesh
	var px := LETTER_M / 7.0
	var size := px / SUB * CELL_FILL
	var charge := smoothstep(charge_at(), break_at(), elapsed)
	var hands := _hands(camera)
	for i in _cell_home.size():
		var k := _cell_letter[i]
		var struck := key_at(k)
		if elapsed < struck:
			many.set_instance_custom_data(i, Color(0.0, 0.0, 0.0, 0.0))
			many.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), _word_place * _cell_home[i]))
			continue
		var since := elapsed - struck
		var pop := 1.0 + 0.6 * exp(-since * 14.0) * sin(minf(since * 30.0, PI))
		var heat := exp(-since * 9.0) * 0.9 + charge * 0.75
		var shake := Vector3(sin(elapsed * 71.0 + i), sin(elapsed * 83.0 + i * 1.7), 0.0) * 0.006 * charge
		var at := _word_place * (_cell_home[i] + shake)
		var scale := size * pop * minf(since * 25.0, 1.0)
		var basis := Basis.IDENTITY
		var presence := 1.0
		# The stream: each cell leaves in the letters' order and flies on a curve into the rifle's place on its length.
		var leave := break_at() + float(k) / WORD.length() * 0.45
		if elapsed >= leave:
			var arrive := lerpf(print_from(), print_to(), _cell_to[i])
			var span := maxf(arrive - leave, 0.2)
			var u := clampf((elapsed - leave) / span, 0.0, 1.0)
			var eased := u * u * (1.6 - 0.6 * u)
			var to := hands * Vector3(0.0, 0.0, lerpf(BACK_Z, MUZZLE_Z, _cell_to[i]))
			var mid := at.lerp(to, 0.4) + Vector3.UP * SWING_M * (0.6 + 0.8 * _cell_spin[i].x * _cell_spin[i].x) + _word_place.basis.x * SWING_M * 0.5 * _cell_spin[i].y
			at = at.lerp(mid, eased).lerp(mid.lerp(to, eased), eased)
			basis = Basis(_cell_spin[i], u * TAU * 2.0)
			scale *= lerpf(1.0, 0.45, u) * (1.0 + 1.5 * sin(PI * u))
			heat = maxf(heat, 0.35 + 0.65 * u)
			presence = 1.0 - smoothstep(0.92, 1.0, u)
		many.set_instance_transform(i, Transform3D(basis.scaled(Vector3.ONE * scale), at))
		many.set_instance_custom_data(i, Color(heat, presence, 0.0, 0.0))


## The rifle's place in the machine now (in the camera's hands), for the stream's ends.
func _hands(camera: Transform3D) -> Transform3D:
	return camera * _rifle.transform if _rifle != null else camera


# --- The rifle. ---

func _build_rifle() -> void:
	var def := load(RAIL_PATH)
	if def == null:
		return
	_rifle = Viewmodel.make(def)
	_rifle.name = "ForgedRifle"
	_rifle.visible = false
	_rifle.set_glow(def.viewmodel_glow_energy * RIFLE_GLOW)
	var camera := _fall.camera()
	if camera != null:
		camera.add_child(_rifle)
	else:
		add_child(_rifle)
	for node in [_rifle] + _rifle.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node == null or mesh_node.mesh == null:
			continue
		_rifle_meshes.append(mesh_node)
		# Its own materials kept, the print's put on in their place until the drop.
		var kept := {"override": mesh_node.material_override, "surfaces": []}
		var prints: Array = []
		for surface in mesh_node.mesh.get_surface_count():
			var own: Material = mesh_node.material_override if mesh_node.material_override != null else mesh_node.mesh.surface_get_material(surface)
			kept["surfaces"].append(mesh_node.get_surface_override_material(surface))
			prints.append(_print_of(own))
		_rifle_kept.append(kept)
		mesh_node.set_meta("prints", prints)


## The print's material standing in for `own`: its colour and its glow taken from it.
func _print_of(own: Material) -> ShaderMaterial:
	var paint := ShaderMaterial.new()
	paint.shader = PrintShader
	var base := Palette.GUNMETAL
	var glow := Color.BLACK
	if own is StandardMaterial3D:
		var standard := own as StandardMaterial3D
		base = standard.albedo_color
		if standard.emission_enabled:
			glow = standard.emission * standard.emission_energy_multiplier * 0.6
	elif own is ShaderMaterial:
		var value = (own as ShaderMaterial).get_shader_parameter("base_color")
		if value is Color:
			base = value
	paint.set_shader_parameter("base", base)
	paint.set_shader_parameter("glow", glow)
	paint.set_shader_parameter("heat_color", Palette.TEAL)
	_prints.append(paint)
	return paint


func _wear_forging(on: bool) -> void:
	if on == _printing:
		return
	_printing = on
	for i in _rifle_meshes.size():
		var mesh_node := _rifle_meshes[i]
		var kept: Dictionary = _rifle_kept[i]
		var prints: Array = mesh_node.get_meta("prints")
		if on:
			mesh_node.material_override = null
			for surface in prints.size():
				mesh_node.set_surface_override_material(surface, prints[surface])
		else:
			mesh_node.material_override = kept["override"]
			for surface in prints.size():
				mesh_node.set_surface_override_material(surface, kept["surfaces"][surface])


func _step_rifle(elapsed: float) -> void:
	if _rifle == null:
		return
	var shown := elapsed >= print_from() and (_shot_at < 0.0 or elapsed < _shot_at + OpenerScore.BLACK_BEATS * OpenerScore.BEAT_S)
	_rifle.visible = shown
	if not shown:
		return
	var def = _rifle.def
	var home: Vector3 = def.viewmodel_offset
	var drop := elapsed - drop_at()
	var printing := drop < 0.0
	_wear_forging(printing)
	if printing:
		var u := smoothstep(print_from(), print_to(), elapsed)
		var front := lerpf(BACK_Z + 0.02, MUZZLE_Z - 0.04, u)
		var to_rifle := _rifle.global_transform.affine_inverse()
		for paint in _prints:
			paint.set_shader_parameter("front", front)
			paint.set_shader_parameter("to_rifle", to_rifle)
	# Its coils light on the last four sixteenths; full until the shot spends it.
	var charge := clampf((elapsed - coils_at()) / (4.0 * OpenerScore.STEP_S) + 0.25, 0.0, 1.0) if elapsed >= coils_at() else 0.0
	if _shot_at >= 0.0 and elapsed >= _shot_at:
		charge = 1.0 - smoothstep(_shot_at, _shot_at + 0.15, elapsed)
	_rifle.set_charge(charge)
	_dim_rifle()
	# Held: rising into the hands as it prints, the kick of the drop, breathing; the shot's recoil.
	var place := home + Vector3(0.0, -0.08 * (1.0 - smoothstep(print_from(), drop_at(), elapsed)), 0.0)
	var turn := Vector3.ZERO
	if drop >= 0.0:
		var k := sin(drop * 16.0) * exp(-drop * 6.0)
		place += Vector3(0.0, -0.025 * k, 0.03 * k)
		turn.x += 0.05 * k
		place.y += 0.004 * sin(elapsed * TAU * 0.6)
	if _shot_at >= 0.0 and elapsed >= _shot_at:
		var s := elapsed - _shot_at
		var k := exp(-s * 7.0) * minf(s * 80.0, 1.0)
		place += Vector3(0.0, 0.02 * k, 0.11 * k)
		turn.x += 0.16 * k
	_rifle.transform = Transform3D(Basis.from_euler(turn), place)
	_rifle.idle(0.016)


## The rifle's own lit pieces (its coils, which light from the weapon's own glow, not the trim's) at RIFLE_GLOW of what it
## gives them: set again after each charge, which sets them from scratch.
func _dim_rifle() -> void:
	for node in _rifle.get_children():
		if node is MeshInstance3D and String(node.name).begins_with("Piece"):
			var mat := (node as MeshInstance3D).material_override as StandardMaterial3D
			if mat != null:
				mat.emission_energy_multiplier *= RIFLE_GLOW


# --- The copy's line. ---

func _build_dare() -> void:
	_dare = Label3D.new()
	_dare.name = "Dare"
	_dare.font = TreeFall.label_font()
	_dare.font_size = TreeFall.LABEL_FONT_PX
	_dare.pixel_size = DARE_PX
	_dare.outline_size = TreeFall.LABEL_OUTLINE
	_dare.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	_dare.modulate = Color(1.0, 0.25, 0.32)
	_dare.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_dare.double_sided = true
	_dare.shaded = false
	_dare.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_dare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dare.visible = false
	var stand := PitBeat.stand()
	var toward := -PitBeat.way_out()
	var right := Vector3.UP.cross(toward).normalized()
	_dare.position = stand * Vector3(0.0, CopyArt.head_y() + DARE_UP, 0.0) - right * DARE_RIGHT
	add_child(_dare)


func _step_dare(elapsed: float) -> void:
	var on := elapsed >= dare_key_at(0) - 0.01 and (_shot_at < 0.0 or elapsed < _shot_at + 0.2)
	_dare.visible = on
	_pit.typing = on and elapsed < dare_key_at(DARE.length() - 1) + 0.15
	if not on:
		return
	var typed := 0
	for k in DARE.length():
		if elapsed >= dare_key_at(k):
			typed = k + 1
	var cursor := CURSOR if fposmod(elapsed * 2.2, 1.0) < 0.55 or typed < DARE.length() else " "
	_dare.text = DARE.left(typed) + cursor
	# Shaking as the shot lands, gone with the copy.
	if _shot_at >= 0.0 and elapsed >= _shot_at:
		_dare.modulate.a = 1.0 - smoothstep(_shot_at, _shot_at + 0.2, elapsed)


# --- The shot and the burst. ---

func _build_beam() -> void:
	var tube := CylinderMesh.new()
	tube.top_radius = 0.5
	tube.bottom_radius = 0.5
	tube.height = 1.0
	tube.radial_segments = 16
	tube.rings = 1
	_beam = MeshInstance3D.new()
	_beam.name = "Beam"
	_beam.mesh = tube
	_beam_paint = _paint(1.0, 1.4)
	_beam.material_override = _beam_paint
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.visible = false
	add_child(_beam)
	_muzzle_light = _lamp("MuzzleLight", Palette.ICE_HI, 9.0)
	_heart_light = _lamp("HeartLight", Color(1.0, 0.25, 0.3), 12.0)


func _lamp(node_name: String, colour: Color, reach: float) -> OmniLight3D:
	var lamp := OmniLight3D.new()
	lamp.name = node_name
	lamp.light_color = colour
	lamp.omni_range = reach
	lamp.light_specular = 0.0
	lamp.shadow_enabled = false
	lamp.visible = false
	add_child(lamp)
	return lamp


func _step_shot(elapsed: float, camera: Transform3D) -> void:
	var fired := _shot_at >= 0.0 and elapsed >= _shot_at
	var s := elapsed - _shot_at if fired else -1.0
	var burning := fired and s < BEAM_S
	_beam.visible = burning
	_muzzle_light.visible = fired and s < 0.3
	_heart_light.visible = fired and s < 1.6
	if not fired:
		return
	var muzzle := (_hands(camera) * Transform3D(Basis.IDENTITY, _rifle.muzzle.position)).origin if _rifle != null else camera.origin
	var target := heart()
	if burning:
		var way := target - muzzle
		var length := way.length()
		var up := way / maxf(length, 0.001)
		var side := up.cross(Vector3.UP if absf(up.y) < 0.95 else Vector3.RIGHT).normalized()
		var width := BEAM_W * (1.0 + 1.4 * exp(-s * 18.0)) * (1.0 - smoothstep(BEAM_S * 0.5, BEAM_S, s))
		_beam.transform = Transform3D(Basis(side * width, up * length, side.cross(up).normalized() * width), muzzle + way * 0.5)
		_beam_paint.set_shader_parameter("clock", elapsed)
		_beam_paint.set_shader_parameter("fade", smoothstep(BEAM_S * 0.4, BEAM_S, s))
	_muzzle_light.position = muzzle
	_muzzle_light.light_energy = 6.0 * exp(-s * 14.0)
	_heart_light.position = target + Vector3(0.0, 0.2, 0.0) - PitBeat.way_out() * 0.6
	_heart_light.light_energy = 9.0 * exp(-maxf(s - shatter_at() + _shot_at, 0.0) * 3.0) * minf(s * 20.0, 1.0)
	var copy := _pit.copy()
	if not _flashed:
		_flashed = true
		if _rifle != null:
			ParticleFx.fire_muzzle(_rifle.muzzle)
	if copy != null and not _hit and s >= BURN_S:
		_hit = true
		copy.react(target, (target - muzzle).normalized())
		copy.set_unstable(0.55)
	if copy != null and not _shattered and elapsed >= shatter_at():
		_shattered = true
		var shove := target - camera.origin
		shove.y = 0.0
		copy.shatter(self, shove.normalized())
		_pit.gone_at = shatter_at()


func _build_burst() -> void:
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.use_colors = true
	many.use_custom_data = true
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	many.mesh = cube
	many.instance_count = BURST
	var away := -PitBeat.way_out()
	for i in BURST:
		var dir := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.2, 1.0), _rng.randf_range(-1.0, 1.0)).normalized()
		dir = (dir + away * 0.8 + Vector3.UP * 0.35).normalized()
		_burst_from.append(Vector3(_rng.randf_range(-0.35, 0.35), _rng.randf_range(-1.2, 0.9), _rng.randf_range(-0.3, 0.3)))
		_burst_v.append(dir * lerpf(BURST_SPEED.x, BURST_SPEED.y, pow(_rng.randf(), 1.6)))
		_burst_life.append(lerpf(BURST_LIFE.x, BURST_LIFE.y, _rng.randf()))
		_burst_size.append(lerpf(BURST_SIZE.x, BURST_SIZE.y, pow(_rng.randf(), 2.0)))
		_burst_axis.append(Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)).normalized())
		var pick := _rng.randf()
		many.set_instance_color(i, Palette.CRIMSON if pick < 0.68 else (Palette.TEAL if pick < 0.9 else Color(1.0, 0.85, 0.85)))
		many.set_instance_custom_data(i, Color(0.0, 0.0, 0.0, 0.0))
	_burst = MultiMeshInstance3D.new()
	_burst.name = "Derezz"
	_burst.multimesh = many
	_burst.material_override = _paint(0.0, 1.8)
	_burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_burst.visible = false
	add_child(_burst)


func _step_burst(elapsed: float) -> void:
	var from := shatter_at()
	var on := elapsed >= from and elapsed < from + BURST_LIFE.y + 0.1
	_burst.visible = on
	if not on:
		return
	var many := _burst.multimesh
	var s := elapsed - from
	var heart_at := heart()
	var floor_y := TreeLayout.PIT_Y + 0.02
	var turn := Basis.looking_at(PitBeat.way_out(), Vector3.UP)
	for i in BURST:
		var life := _burst_life[i]
		# Heavy and slow: a drag on their flight, the pull down.
		var tau := (1.0 - exp(-s * 1.8)) / 1.8
		var p := heart_at + turn * _burst_from[i] + _burst_v[i] * tau + Vector3.DOWN * 0.5 * GRAVITY * s * s * 0.55
		var landed := p.y <= floor_y
		p.y = maxf(p.y, floor_y)
		var u := clampf(s / life, 0.0, 1.0)
		var size := _burst_size[i] * (1.0 - u * u) * (0.6 if landed else 1.0)
		var spin := Basis(_burst_axis[i], s * (3.0 + 6.0 * _burst_axis[i].x * _burst_axis[i].x) * (0.2 if landed else 1.0))
		many.set_instance_transform(i, Transform3D(spin.scaled(Vector3.ONE * maxf(size, 0.0001)), p))
		var heat := exp(-s * 4.0)
		var flicker := 0.75 + 0.25 * sin(s * 37.0 + i * 1.3)
		many.set_instance_custom_data(i, Color(heat, (1.0 - u) * flicker, 0.0, 0.0))
