class_name PitBeat
extends Node3D
## C41's beat in the machine (PRD 5.7, 1:10 to 1:35), in the world C40's fall landed in (scripts/opener/tree_fall.gd),
## round the camera standing on the pit's rim facing the pit. The link to the player's AI (scripts/opener/
## opener_link.gd) and the copy of them (scripts/opener/copy_art.gd), drawn: everything here is a plain function of
## the opener's clock and the beat's few moments (when the link locked, whether it came live), so the same opener draws
## the same frames every run.
##
## The link: lines of the AI's teal climbing out of the pit (from its rim, straight up the shaft, and up the far wall)
## from the tuning's signal_at, a head racing up each with a tail and a trace left lit behind; when the answer lands
## (or the scripted line takes its place) every line flares once and rings of teal run out across the floor from the
## pit's rim, past the player.
## The copy: it walks up out of the pit toward the player, on a stair of red hexagons that light under its feet as they
## land (each summoned just before, flaring as the foot comes down), over the rim (as its first foot touches the floor
## its own rings run out across it, red, the link's answered in kind) and across the floor, printing a hex at each step
## that fades behind it, and stops a few metres in front of the player on a whole step, its left foot
## ahead. It forms as it climbs: whole above the rim's plane, cells below it. It stares at the player as it comes; once
## it stands it mirrors their look (as a reflection would) and tilts its head. Over it its name: the player's user name
## (OpenerData's, cleaned; the demo's "user" unless the player said yes to their own data), in the green their prompt
## typed in, never anything else. Lit for its armour: crimson from under it, the pit's red behind it, a cool light from
## where the player stands.
##
## The camera's own look on top of the player's (scripted_look()): up a little to watch the signal climb, down again,
## then up a little as the copy comes close. Nothing here reads anything: the name is handed in, and dropped (freed)
## with the machine as the opener ends.
##
## C42's hand-off: copy() is the copy standing where it stopped (stand()), facing the player; its gait and gaze go on
## being set here until C42 takes them.

const SignalShader = preload("res://shaders/opener_signal.gdshader")
const FloorShader = preload("res://shaders/opener_floor.gdshader")
const Palette = preload("res://scripts/palette.gd")

## The link's lines: how many from the pit's rim and up the far wall, how far up each goes, their speeds (metres a
## second), and the width of a rim line and a wall line; and the beam up the shaft's axis from the hot core, its width,
## how far under the rim it starts and its speed.
const RIM_LINES := 22
const WALL_LINES := 16
const RIM_TOP := 420.0
const WALL_TOP := 74.0
const LINE_SPEED := Vector2(70.0, 120.0)
const RIM_LINE_M := 0.45
const WALL_LINE_M := 0.9
const WALL_R := 56.0
const BEAM_M := 3.2
const BEAM_FROM := 150.0
const BEAM_SPEED := 210.0
## The lines keep this far round from where the player stands (radians), so none stands in their face.
const CLEAR_ANGLE := 0.7
## The rings' speed and width (metres), how long the lines and rings take to fade once the copy comes.
const RING_SPEED := 22.0
const RING_M := 0.7
## The stair: how steep (metres up a metre across), how far in front of the player the copy stops, and how many steps
## it takes from the bottom of the stair to there (a whole number, so it stops on a whole step).
const STAIR_SLOPE := 0.6
const STOP_GAP := 4.2
const STEPS := 16
## Its walk's speeding up and slowing down, seconds.
const ACCEL_S := 0.8
const DECEL_S := 1.8
## A step's hexagon: how wide (corner to corner), how far before the foot lands it lights, how long a floor print
## takes to fade, how bright a stair's step stays.
const STEP_M := 0.7
const SUMMON_M := 0.5
const PRINT_FADE_S := 3.2
const STAIR_GLOW := 0.6
## The forming plane: just under the rim while it climbs, dropping away once it is over it.
const FORM_UNDER := 0.2
## The camera's look on top of the player's (radians up): watching the signal, and the copy close.
const LOOK_SIGNAL := 0.15
const LOOK_COPY := 0.1
## How long its head takes to follow (a second), and its tilt standing (radians).
const GAZE_EASE := 2.2
const STAND_TILT := 0.24
## The name over it: its size and how far it fades in over the rim.
const TAG_PX := 0.0024
const TAG_FADE_M := 0.6

var _colours: OpenerPalette
var _dark := Color.BLACK
var _t: OpenerTuning
var _copy: CopyArt
var _tag: Label3D
var _signals: MultiMeshInstance3D
var _signal_paint: ShaderMaterial
var _rings: MeshInstance3D
var _ring_paint: ShaderMaterial
var _red_rings: MeshInstance3D
var _red_paint: ShaderMaterial
var _rim_at := -1.0
var _steps: MultiMeshInstance3D
var _under: OmniLight3D
var _behind: OmniLight3D
var _front: OmniLight3D
var _falls: Array[Dictionary] = []
var _gaze := Vector3.FORWARD
var _tilt := 0.0
var _clock := -1.0
var _lock_at := -1.0
var _name := ""
var _built := false


## Builds the beat in `palette` for timeline `tuning` over the machine's `dark` (TreeFall.void_color()), hidden until its
## moments.
func build(palette: OpenerPalette, tuning: OpenerTuning, dark: Color) -> void:
	if _built:
		return
	_built = true
	_colours = palette
	_dark = dark
	_t = tuning
	name = "PitBeat"
	_build_signals()
	_build_rings()
	_build_copy()
	_build_steps()
	_build_lights()


## The player's user name over the copy (cleaned by the opener; never anything else). "" hides it.
func set_name_tag(text: String) -> void:
	_name = text
	if _tag != null:
		_tag.text = text


## When the link locked (the answer landed, or the scripted line took its place), on the opener's clock.
func set_lock(at: float) -> void:
	if _lock_at < 0.0:
		_lock_at = at


## Everything at `elapsed` on the opener's clock; `look` is the camera's whole look now (the player's and the beat's),
## and `camera` the camera's place, for the copy's gaze.
func step(elapsed: float, look: Vector2, camera: Transform3D) -> void:
	if not _built:
		return
	var delta := 0.0 if _clock < 0.0 else clampf(elapsed - _clock, 0.0, 0.1)
	_clock = elapsed
	_step_signals(elapsed)
	_step_copy(elapsed, delta, look, camera)
	_step_steps(elapsed)


# --- The way out of the pit. ---

## Where the player stands (the fall's landing), on the floor: the line out from the axis through it is the copy's way.
static func way_out() -> Vector3:
	return TreeLayout.on_ring(TreeLayout.LAND_ANGLE, 1.0, 0.0)


## Where the copy stops, from the axis (metres): STOP_GAP in front of the player.
static func stop_r() -> float:
	return TreeLayout.LAND_R - STOP_GAP


## How far it walks, metres across the ground (level, as its feet move under it, so a foot never slides on the
## stair either): STEPS whole strides.
static func walk_length() -> float:
	return STEPS * CopyArt.STRIDE


## Where the stair starts, from the axis: down in the pit, walk_length() short of where it stops.
static func start_r() -> float:
	return stop_r() - walk_length()


## How far from the axis it is, `d` metres along its walk.
static func r_at(d: float) -> float:
	return start_r() + d


## The ground's height `r` metres from the axis: the stair up out of the pit, then the floor.
static func ground_y(r: float) -> float:
	return TreeLayout.PIT_Y - maxf(TreeLayout.PIT_R - r, 0.0) * STAIR_SLOPE


## The ground under it `d` metres along its walk, in the machine's space.
static func ground_at(d: float) -> Vector3:
	var r := r_at(d)
	var at := way_out() * r
	at.y = ground_y(r)
	return at


## How far it has walked at `elapsed`: speeding up from copy_at, steady, slowing to a stop on its last step at copy_stop.
static func walk_at(elapsed: float, t: OpenerTuning) -> float:
	var length := walk_length()
	var span := maxf(t.copy_stop - t.copy_at, ACCEL_S + DECEL_S + 0.1)
	var pace := length / (span - ACCEL_S * 0.5 - DECEL_S * 0.5)
	var s := clampf(elapsed - t.copy_at, 0.0, span)
	if s < ACCEL_S:
		return 0.5 * pace * s * s / ACCEL_S
	if s < span - DECEL_S:
		return pace * (ACCEL_S * 0.5 + s - ACCEL_S)
	var left := span - s
	return length - 0.5 * pace * left * left / DECEL_S


## How fast it walks at `elapsed`, metres a second.
static func speed_at(elapsed: float, t: OpenerTuning) -> float:
	return (walk_at(elapsed + 0.02, t) - walk_at(elapsed - 0.02, t)) / 0.04


## The ground's slope under it `d` metres along: the stair's on it, easing to the floor's over the rim.
static func slope_at(d: float) -> float:
	return STAIR_SLOPE * (1.0 - smoothstep(TreeLayout.PIT_R - 0.6, TreeLayout.PIT_R + 0.2, r_at(d)))


## The copy's place `d` metres along: on the ground there, facing out of the pit toward the player.
static func copy_at_walk(d: float) -> Transform3D:
	var basis := Basis.looking_at(way_out(), Vector3.UP)
	return Transform3D(basis, ground_at(d) - DaemonArt.GROUND_Y * Vector3.UP)


## Where it stands at the end: C42's hand-off.
static func stand() -> Transform3D:
	return copy_at_walk(walk_length())


## The beat's look for the camera at `elapsed` (yaw, pitch, radians), on top of the player's: up to watch the signal
## climb, back down, up a little as the copy comes close.
static func scripted_look(elapsed: float, t: OpenerTuning) -> Vector2:
	var watch := smoothstep(t.signal_at, t.signal_at + 1.8, elapsed) * (1.0 - smoothstep(t.answer_from + 0.4, t.answer_by + 1.6, elapsed))
	var near := smoothstep(t.copy_at + 4.0, t.copy_stop, elapsed)
	return Vector2(0.0, LOOK_SIGNAL * watch + LOOK_COPY * near)


## Its footfalls in the machine's space: where each lands, how far along the walk, and its side (CopyArt's, placed).
func footfalls() -> Array[Dictionary]:
	return _falls


## The copy (C42 takes it on from where it stands).
func copy() -> CopyArt:
	return _copy


## When its first foot touches the floor over the rim (its red rings start), on the opener's clock.
func rim_at() -> float:
	return _rim_at


## The name over it as shown, or "".
func name_tag() -> String:
	return _tag.text if _tag != null and _tag.visible else ""


## How many of its steps after the first have landed by `elapsed` (each a step's sound).
func steps_by(elapsed: float) -> int:
	var d := walk_at(elapsed, _t) if elapsed >= _t.copy_at else -1.0
	var n := 0
	for fall in _falls:
		if fall["d"] > 0.0 and fall["d"] <= d + 0.0001:
			n += 1
	return n


# --- Building. ---

func _build_signals() -> void:
	var line := QuadMesh.new()
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.use_custom_data = true
	many.mesh = line
	many.instance_count = RIM_LINES + WALL_LINES + 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 4141
	var facing := atan2(way_out().z, way_out().x)
	var i := 0
	for k in RIM_LINES + WALL_LINES:
		var rim := k < RIM_LINES
		var count := RIM_LINES if rim else WALL_LINES
		var u := (float(k if rim else k - RIM_LINES) + 0.5) / count
		# Round the far side of the circle, never in the player's face.
		var angle := facing + CLEAR_ANGLE + u * (TAU - 2.0 * CLEAR_ANGLE) + rng.randf_range(-0.04, 0.04)
		var r := TreeLayout.PIT_R + 0.6 if rim else WALL_R + rng.randf_range(-1.5, 1.5)
		var top := RIM_TOP if rim else WALL_TOP * rng.randf_range(0.8, 1.2)
		var width := RIM_LINE_M if rim else WALL_LINE_M
		var foot := Vector3(cos(angle) * r, TreeLayout.PIT_Y, sin(angle) * r)
		many.set_instance_transform(i, Transform3D(Basis(Vector3(width, 0.0, 0.0), Vector3(0.0, top, 0.0), Vector3(0.0, 0.0, 1.0)), foot + Vector3.UP * top * 0.5))
		many.set_instance_custom_data(i, Color(rng.randf_range(0.2, 1.3), rng.randf_range(LINE_SPEED.x, LINE_SPEED.y), rng.randf_range(1.0, 1.5) if rim else rng.randf_range(0.7, 1.0), 0.0))
		i += 1
	# The beam: up the shaft's axis from the hot core under the pit, first of all.
	var length := BEAM_FROM + RIM_TOP
	many.set_instance_transform(i, Transform3D(Basis(Vector3(BEAM_M, 0.0, 0.0), Vector3(0.0, length, 0.0), Vector3(0.0, 0.0, 1.0)), Vector3(0.0, TreeLayout.PIT_Y - BEAM_FROM + length * 0.5, 0.0)))
	many.set_instance_custom_data(i, Color(0.0, BEAM_SPEED, 1.6, 0.0))
	_signal_paint = ShaderMaterial.new()
	_signal_paint.shader = SignalShader
	_signal_paint.set_shader_parameter("line_color", Palette.TEAL)
	_signal_paint.set_shader_parameter("head_color", Palette.MINT)
	_signal_paint.set_shader_parameter("fog_density", TreeFall.FOG)
	_signals = MultiMeshInstance3D.new()
	_signals.name = "Signal"
	_signals.multimesh = many
	_signals.material_override = _signal_paint
	_signals.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_signals.custom_aabb = AABB(Vector3(-80.0, TreeLayout.PIT_Y - BEAM_FROM - 1.0, -80.0), Vector3(160.0, RIM_TOP + BEAM_FROM + 2.0, 160.0))
	_signals.visible = false
	add_child(_signals)


func _build_rings() -> void:
	_ring_paint = _ring_paint_of(Palette.TEAL, RING_SPEED)
	_rings = _ring_plane("LinkRings", _ring_paint, 0.04)
	_red_paint = _ring_paint_of(Palette.CRIMSON, RING_SPEED * 0.6)
	_red_rings = _ring_plane("CopyRings", _red_paint, 0.05)


func _ring_paint_of(colour: Color, speed: float) -> ShaderMaterial:
	var paint := ShaderMaterial.new()
	paint.shader = FloorShader
	paint.set_shader_parameter("mode", 0.0)
	paint.set_shader_parameter("ring_color", colour)
	paint.set_shader_parameter("pit_r", TreeLayout.PIT_R)
	paint.set_shader_parameter("ring_speed", speed)
	paint.set_shader_parameter("ring_m", RING_M)
	return paint


## A flat square over the floor, centred on the pit's axis, for rings running out across it.
func _ring_plane(node_name: String, paint: ShaderMaterial, lift: float) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(240.0, 240.0)
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = plane
	node.material_override = paint
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = Vector3(0.0, TreeLayout.PIT_Y + lift, 0.0)
	node.visible = false
	add_child(node)
	return node


func _build_copy() -> void:
	_copy = CopyArt.new()
	_copy.setup(null, DaemonArt.seed_of("~"))
	# Not one of the arena's daemons: nothing that looks for them (a grep lock, a ping) ever finds it.
	_copy.remove_from_group(DaemonArt.GROUP)
	_copy.name = "Copy"
	_copy.visible = false
	add_child(_copy)
	_copy.transform = copy_at_walk(0.0) * _copy.transform
	_tag = Label3D.new()
	_tag.name = "NameTag"
	_tag.font = TreeFall.label_font()
	_tag.font_size = TreeFall.LABEL_FONT_PX
	_tag.pixel_size = TAG_PX
	_tag.outline_size = TreeFall.LABEL_OUTLINE
	_tag.outline_modulate = Color(0.0, 0.0, 0.0, 0.8)
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.double_sided = true
	_tag.shaded = false
	_tag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tag.modulate = _bright(_colours.color("green"))
	_tag.text = _name
	_tag.visible = false
	add_child(_tag)


## One flat hexagon a unit across its corners (on +-x), for a step's light.
static func _hex_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 6:
		var a0 := TAU * i / 6.0
		var a1 := TAU * (i + 1) / 6.0
		for p in [Vector3.ZERO, Vector3(cos(a1), 0.0, sin(a1)) * 0.5, Vector3(cos(a0), 0.0, sin(a0)) * 0.5]:
			tool.set_normal(Vector3.UP)
			tool.add_vertex(p)
	return tool.commit()


func _build_steps() -> void:
	# Where each foot lands in the machine's space, from the copy's own footfalls placed along its way.
	for fall in CopyArt.footfalls(walk_length()):
		var body := copy_at_walk(fall["d"])
		var local: Vector3 = fall["at"]
		var at := body * Vector3(local.x, DaemonArt.GROUND_Y, local.z)
		var r := Vector2(at.x, at.z).length()
		at.y = ground_y(r) + 0.02
		_falls.append({"d": fall["d"], "side": fall["side"], "at": at, "stair": r < TreeLayout.PIT_R, "when": _when(fall["d"])})
		if r >= TreeLayout.PIT_R and _rim_at < 0.0:
			_rim_at = _falls[-1]["when"]
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.use_custom_data = true
	many.mesh = _hex_mesh()
	many.instance_count = _falls.size()
	var turn := Basis.looking_at(way_out(), Vector3.UP)
	for i in _falls.size():
		many.set_instance_transform(i, Transform3D(turn * Basis.from_scale(Vector3(STEP_M, 1.0, STEP_M)), _falls[i]["at"]))
		many.set_instance_custom_data(i, Color(0.0, 0.0, 0.0, 0.0))
	var paint := ShaderMaterial.new()
	paint.shader = FloorShader
	paint.set_shader_parameter("mode", 1.0)
	paint.set_shader_parameter("step_color", Palette.CRIMSON)
	_steps = MultiMeshInstance3D.new()
	_steps.name = "Steps"
	_steps.multimesh = many
	_steps.material_override = paint
	_steps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_steps.visible = false
	add_child(_steps)


## When it walks past `d` metres, on the opener's clock (the walk's inverse, found by halving).
func _when(d: float) -> float:
	var low := _t.copy_at
	var high := _t.copy_stop
	if d <= 0.0:
		return low
	for i in 40:
		var mid := (low + high) * 0.5
		if walk_at(mid, _t) < d:
			low = mid
		else:
			high = mid
	return high


func _build_lights() -> void:
	_under = _light("Under", Palette.CRIMSON, 2.6, 4.5)
	_behind = _light("Behind", _bright(_colours.color("magenta")).lerp(Palette.CRIMSON, 0.4), 3.2, 6.0)
	_front = _light("Front", Color(0.62, 0.78, 0.86), 0.35, 14.0)


func _light(node_name: String, colour: Color, energy: float, reach: float) -> OmniLight3D:
	var lamp := OmniLight3D.new()
	lamp.name = node_name
	lamp.light_color = colour
	lamp.light_energy = energy
	lamp.omni_range = reach
	lamp.shadow_enabled = false
	# Light on its armour's planes only: a lamp's glint on a bevel reads as a light of its own.
	lamp.light_specular = 0.0
	lamp.visible = false
	add_child(lamp)
	return lamp


## `c` lifted toward white until it reads on the machine's dark (as the city's names are).
func _bright(c: Color) -> Color:
	var out := c
	for i in 20:
		if OpenerPalette.contrast(out, _dark) >= OpenerPalette.SHAPE_CONTRAST + 1.5:
			break
		out = out.lerp(Color.WHITE, 0.08)
	return out


# --- Running. ---

func _step_signals(elapsed: float) -> void:
	var climb := elapsed - _t.signal_at
	var fade := 1.0 - smoothstep(_t.copy_at - 2.0, _t.copy_at + 2.0, elapsed)
	_signals.visible = climb >= 0.0 and fade > 0.0
	_signal_paint.set_shader_parameter("climb", climb)
	_signal_paint.set_shader_parameter("lock", elapsed - _lock_at if _lock_at >= 0.0 else -1.0)
	_signal_paint.set_shader_parameter("strength", fade * smoothstep(0.0, 0.3, climb))
	var since := elapsed - _lock_at if _lock_at >= 0.0 else -1.0
	_rings.visible = since >= 0.0 and since < 4.0
	_ring_paint.set_shader_parameter("since", since)
	var red := elapsed - _rim_at if _rim_at >= 0.0 and elapsed >= _rim_at else -1.0
	_red_rings.visible = red >= 0.0 and red < 4.0
	_red_paint.set_shader_parameter("since", red)


func _step_copy(elapsed: float, delta: float, look: Vector2, camera: Transform3D) -> void:
	var on := elapsed >= _t.copy_at
	_copy.visible = on
	_tag.visible = on and _name != ""
	for lamp in [_under, _behind, _front]:
		lamp.visible = on
	if not on:
		return
	var d := walk_at(elapsed, _t)
	var place := copy_at_walk(d)
	_copy.transform = place
	_copy.walk_m = d
	_copy.speed = speed_at(elapsed, _t)
	_copy.slope = slope_at(d)
	_copy.time = elapsed
	var r := r_at(d)
	var plane := TreeLayout.PIT_Y - FORM_UNDER - 3.0 * smoothstep(TreeLayout.PIT_R - 1.4, TreeLayout.PIT_R, r)
	_copy.form_y = plane - place.origin.y
	# Its head: at the player while it walks; standing, the player's look as a mirror shows it.
	var head := place * Vector3(0.0, CopyArt.head_y(), 0.0)
	var at_you := (camera.origin - head).normalized()
	var want := at_you
	var standing := smoothstep(_t.copy_stop - 0.4, _t.copy_stop + 0.4, elapsed)
	if standing > 0.0:
		var seen := -(camera.basis.z).normalized()
		var across := (head - camera.origin)
		across.y = 0.0
		var n := across.normalized() if across.length_squared() > 0.0001 else -way_out()
		var mirrored := seen - 2.0 * seen.dot(n) * n
		want = at_you.lerp(mirrored, standing).normalized()
	var local := (place.basis.inverse() * want).normalized()
	_gaze = local if delta <= 0.0 else _gaze.lerp(local, clampf(delta * GAZE_EASE, 0.0, 1.0)).normalized()
	_copy.gaze = _gaze
	_tilt = lerpf(_tilt, STAND_TILT * standing, clampf(delta * 1.5, 0.0, 1.0)) if delta > 0.0 else STAND_TILT * standing
	_copy.tilt = _tilt
	# The name over it, fading in as it rises over the rim.
	var top := place * Vector3(0.0, _copy.tag_height, 0.0)
	_tag.position = top
	_tag.modulate.a = clampf((top.y - TreeLayout.PIT_Y) / TAG_FADE_M, 0.0, 1.0)
	# Its light goes with it.
	_under.position = place * Vector3(0.0, -0.55, -0.7)
	_behind.position = place * Vector3(0.0, 1.8, 1.6)
	_front.position = camera.origin + Vector3.UP * 1.2


func _step_steps(elapsed: float) -> void:
	_steps.visible = elapsed >= _t.copy_at
	if not _steps.visible:
		return
	var d := walk_at(elapsed, _t)
	var many := _steps.multimesh
	for i in _falls.size():
		var fall: Dictionary = _falls[i]
		var glow := 0.0
		var flare := 0.0
		var ahead: float = fall["d"] - d
		if ahead <= SUMMON_M:
			# Lit as the foot comes, full as it lands, then a stair's step stays lit and a print on the floor fades.
			glow = 1.0 - clampf(ahead / SUMMON_M, 0.0, 1.0) * 0.8
			var since: float = elapsed - fall["when"]
			if ahead <= 0.0:
				flare = exp(-maxf(since, 0.0) * 5.0)
				if fall["stair"]:
					glow = lerpf(1.0, STAIR_GLOW, clampf(since / 0.8, 0.0, 1.0))
				else:
					glow = 1.0 - clampf(since / PRINT_FADE_S, 0.0, 1.0)
		many.set_instance_custom_data(i, Color(glow, flare, 0.0, 0.0))
