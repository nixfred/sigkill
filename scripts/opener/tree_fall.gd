class_name TreeFall
extends SubViewport
## The machine the opener reveals and falls through (C40; PRD 5.7, 0:35 to 1:10): "The fake desktop shrinks away:
## it was inside the game all along", then "fall through the player's directory tree as a city (real folder names
## on towers, node_modules pit). Their top CPU process, named, pulses red at the bottom." A world of its own (never
## the arena's), built from a TreeLayout (scripts/opener/tree_layout.gd: the folder names and entry counts the opener
## took, nothing new read) in the opener's palette, with the camera's whole way through it: pose(), fov_at(),
## speed_at() and pulse_at() are plain functions of the opener's clock, so the same data gives the same shot every
## time. Sized to the window by the opener (scripts/opener/opener.gd), which shows what it draws.
##
## The reveal (shrink_at to fall_at): the camera starts where the terminal's screen, a panel on the home folder's
## monolith, fills the view exactly as the terminal did, then pulls back across the shaft, rising, its field of view
## widening, until the screen is one lit panel on a wall of dark ones in a dark the size of a city; then it tips
## over the edge to look down: rings of light stepping down and in, the pit's red at the bottom.
## The fall (fall_at to land_at): it drops down the shaft as a body does, quicker and quicker, turning slowly round
## the axis to face the far wall (each terrace's towers and their names sweeping past, the cables, the code light,
## speed lines streaking up past it), then slows and lands on the pit's rim, facing the pit: the hand-off
## (landing()) that C41 goes on from. The player may look about a little while it falls (`look`, the mouse, from
## the opener), never steer.
##
## Caps: the layout's (TreeLayout.ROOMS, LABELS, PIECES, CABLES, STREAMS), and so at most MOST_NODES nodes: every box
## in one MultiMesh, the terraces one mesh, the pit one, the streams and the cables one MultiMesh each, the air one,
## a Label3D a name.

const TowerShader = preload("res://shaders/opener_tower.gdshader")
const PanelShader = preload("res://shaders/opener_panel.gdshader")
const TerraceShader = preload("res://shaders/opener_terrace.gdshader")
const MazeShader = preload("res://shaders/opener_maze.gdshader")
const StreamShader = preload("res://shaders/opener_stream.gdshader")
const SpeedShader = preload("res://shaders/opener_speed.gdshader")
const SkyShader = preload("res://shaders/opener_sky.gdshader")
const CoreShader = preload("res://shaders/opener_core.gdshader")

## At most this many nodes, whatever the data (the layout's labels and a fixed set of meshes).
const MOST_NODES := TreeLayout.LABELS + 24
## The camera's field of view: as the screen fills it, pulled back, and falling.
const FOV_SCREEN := 50.0
const FOV_BACK := 61.0
const FOV_FALL := 76.0
## The reveal: how far back it pulls (to just past the axis), by what share of the reveal, how high it rises, how
## far it sways to one side (for parallax), how far it turns and rolls, and when and how far it tips down.
const BACK_M := 160.0
const BACK_SHARE := 0.8
const REVEAL_TOP := 40.0
const RISE := Vector2(0.12, 0.86)
const SWAY_M := 7.0
const YAW_DRIFT := 5.0
const ROLL_DRIFT := 1.5
const PITCH_FROM := 0.6
const PITCH_DOWN := 78.0
## The screen grows brighter as it shrinks into a light in the dark (it starts at exactly the terminal's colours).
const SCREEN_GLOW := 1.8
const BEZEL_M := 0.14
## The fall: how far out from the axis it turns, where round it starts (the reveal ends there) and its pitch along
## the way; the shares of the fall spent speeding up and slowing down; eye height on landing.
const HELIX_R := 11.0
const START_ANGLE := PI / 2.0
const LOOK_UP_PITCH := -12.0
const MID_PITCH := -30.0
const DIP_PITCH := -54.0
const LAND_PITCH := -7.0
const ACCEL_SHARE := 0.3
const DECEL_SHARE := 0.17
const EYE_M := 1.7
const DROP_SAMPLES := 512
## The landing: how far the knees give, and over how long.
const DIP_M := 0.55
const DIP_S := 0.5
## How far the player may look about while falling (radians), and how fast it springs back.
const LOOK_MOST := Vector2(0.24, 0.16)
const LOOK_BACK := 2.5
## The hottest process's beat: once every 1/BEAT_HZ seconds, a soft swell (never 3 flashes a second: under one).
const BEAT_HZ := 0.85
## The air: how many motes and speed lines.
const AIR := 150
## The pit's hot core: how far under the rim, and how big; the process's name in the pit's mouth.
const CORE_DOWN := 160.0
const CORE_R := 9.0
const PROCESS_PX := 0.03
const PROCESS_DOWN := 3.0
## The home folder's sign on its monolith, over the screen: its size and height.
const HOME_SIGN := "~/"
const HOME_SIGN_PX := 0.5
const HOME_SIGN_Y := 78.0
## Over 1, so the sign blooms as the city's edges do.
const HOME_SIGN_GLOW := 1.6
## The fog's density, the label font's size and outline.
const FOG := 0.0028
const LABEL_FONT_PX := 96
const LABEL_OUTLINE := 10

var layout: TreeLayout
var colours: OpenerPalette
## The opener's beats this follows (its tuning's).
var shrink_at := 40.8
var fall_at := 50.0
var land_at := 68.4
## The hottest process's name, shown in the pit's mouth.
var process_name := ""

var _camera: Camera3D
var _env: Environment
var _towers: MultiMeshInstance3D
var _streams: MultiMeshInstance3D
var _cables: MultiMeshInstance3D
var _air: MultiMeshInstance3D
var _panel: MeshInstance3D
var _panel_paint: ShaderMaterial
var _paints: Array[ShaderMaterial] = []
var _air_paint: ShaderMaterial
var _core_paint: ShaderMaterial
var _labels: Array[Label3D] = []
var _process_label: Label3D
var _drop := PackedFloat32Array()
var _drop_mean := 1.0
var _turn := PackedFloat32Array()
var _look := Vector2.ZERO
var _aspect := 16.0 / 9.0
var _built := false

static var _label_font: SystemFont


func _init() -> void:
	own_world_3d = true
	transparent_bg = false
	msaa_3d = Viewport.MSAA_4X
	audio_listener_enable_3d = false
	positional_shadow_atlas_size = 0
	render_target_update_mode = SubViewport.UPDATE_DISABLED


## Builds the machine from `given` in `palette` (made to read on its dark: OpenerPalette's neon()); glow only with
## `bloom` (the player's setting).
func build(given: TreeLayout, palette: OpenerPalette, bloom: bool) -> void:
	if _built:
		return
	_built = true
	layout = given
	colours = palette
	_plan_drop()
	_world(bloom)
	_city()
	_terraces()
	_pit()
	_light()
	_names()
	_panel_mesh()
	step(shrink_at, Vector2.ZERO)


## The camera where it is at `elapsed` on the opener's clock, the player's look on top, and everything that moves.
func step(elapsed: float, look: Vector2) -> void:
	if not _built:
		return
	_look = look
	_camera.transform = pose(elapsed) * Transform3D(Basis.from_euler(Vector3(look.y, look.x, 0.0)), Vector3.ZERO)
	_camera.fov = fov_at(elapsed)
	var beat := pulse_at(elapsed)
	for paint in _paints:
		paint.set_shader_parameter("clock", elapsed)
		paint.set_shader_parameter("pulse", beat)
	_core_paint.set_shader_parameter("pulse", beat)
	_air_paint.set_shader_parameter("cam_pos", _camera.global_position)
	_air_paint.set_shader_parameter("speed", speed_at(elapsed))
	_air_paint.set_shader_parameter("clock", elapsed)
	var back := clampf((elapsed - shrink_at) / maxf(fall_at - shrink_at, 0.01), 0.0, 1.0)
	_panel_paint.set_shader_parameter("bright", lerpf(1.0, SCREEN_GLOW, smoothstep(0.08, 0.45, back)))
	if _process_label != null:
		_process_label.modulate = _neon(colours.color("red")).lerp(Color(1.0, 0.86, 0.86), beat * 0.5)


## How the player's look settles back while it is not moving (seconds `delta`): toward still.
static func settle_look(look: Vector2, delta: float) -> Vector2:
	return look.lerp(Vector2.ZERO, clampf(delta * LOOK_BACK, 0.0, 1.0))


## A look moved by the mouse's `relative` pixels, kept inside LOOK_MOST.
static func add_look(look: Vector2, relative: Vector2) -> Vector2:
	var moved := look + Vector2(-relative.x, -relative.y) * 0.0025
	return Vector2(clampf(moved.x, -LOOK_MOST.x, LOOK_MOST.x), clampf(moved.y, -LOOK_MOST.y, LOOK_MOST.y))


## The window's shape: the screen's panel is made the window's shape, so it fills the view exactly at the start.
func set_aspect(aspect: float) -> void:
	_aspect = maxf(aspect, 0.1)
	if _panel != null:
		_panel_mesh()


## The panel's picture: the terminal's own viewport.
func set_screen(texture: Texture2D, pixels: Vector2) -> void:
	if _panel_paint != null:
		_panel_paint.set_shader_parameter("screen", texture)
		_panel_paint.set_shader_parameter("screen_px", pixels)


# --- The camera's way. ---

## Where the camera is, and which way it looks, at `elapsed` on the opener's clock.
func pose(elapsed: float) -> Transform3D:
	if elapsed < fall_at:
		return _reveal_pose(clampf((elapsed - shrink_at) / maxf(fall_at - shrink_at, 0.01), 0.0, 1.0))
	if elapsed < land_at:
		return _fall_pose((elapsed - fall_at) / maxf(land_at - fall_at, 0.01), elapsed)
	var landed := _fall_pose(1.0, land_at)
	var since := elapsed - land_at
	var dip := -DIP_M * sin(PI * clampf(since / DIP_S, 0.0, 1.0)) * exp(-since * 2.0)
	landed.origin.y += dip
	return landed


## Where the fall comes to rest, facing the pit: C41's beat starts here.
func landing() -> Transform3D:
	return _fall_pose(1.0, land_at)


## How far the camera stands from the screen when the screen fills the view (FOV_SCREEN, the window's height).
static func screen_distance() -> float:
	return TreeLayout.PANEL_H * 0.5 / tan(deg_to_rad(FOV_SCREEN) * 0.5)


func fov_at(elapsed: float) -> float:
	if elapsed < fall_at:
		var u := clampf((elapsed - shrink_at) / maxf(fall_at - shrink_at, 0.01), 0.0, 1.0)
		return lerpf(FOV_SCREEN, FOV_BACK, smoothstep(0.05, 0.75, u))
	var v := clampf((elapsed - fall_at) / maxf(land_at - fall_at, 0.01), 0.0, 1.0)
	return lerpf(FOV_BACK, FOV_FALL, smoothstep(0.0, 0.3, v)) - (FOV_FALL - FOV_BACK) * 0.35 * smoothstep(0.8, 1.0, v)


## How fast the camera is falling, metres a second, at `elapsed` (0 outside the fall).
func speed_at(elapsed: float) -> float:
	if elapsed <= fall_at or elapsed >= land_at:
		return 0.0
	var v := (elapsed - fall_at) / maxf(land_at - fall_at, 0.01)
	var drop := REVEAL_TOP - (TreeLayout.PIT_Y + EYE_M)
	return drop / (land_at - fall_at) * _speed_shape(v) / _drop_mean


## The hottest process's beat at `elapsed`, 0 to 1: one soft swell every 1/BEAT_HZ seconds.
static func pulse_at(elapsed: float) -> float:
	return pow(0.5 + 0.5 * cos(TAU * BEAT_HZ * elapsed), 4.0)


func _reveal_pose(u: float) -> Transform3D:
	var screen := TreeLayout.panel_at()
	var out := TreeLayout.panel_facing()
	var back := _ease_in_out(clampf(u / BACK_SHARE, 0.0, 1.0), 2.4)
	var dist := lerpf(screen_distance(), BACK_M, back)
	var rise := smoothstep(RISE.x, RISE.y, u)
	# The drift to one side, the turn and the roll grow with the pull-back: while the screen still fills the view the
	# camera only backs away from it.
	var sway := SWAY_M * sin(PI * back) * back
	var at := screen + out * dist + Vector3(sway, (REVEAL_TOP - screen.y) * rise, 0.0)
	var tip := _smoother(clampf((u - PITCH_FROM) / (1.0 - PITCH_FROM), 0.0, 1.0))
	var pitch := -deg_to_rad(PITCH_DOWN) * tip
	var drift := sin(PI * u) * smoothstep(0.0, 0.5, back)
	var yaw := deg_to_rad(YAW_DRIFT) * drift
	var roll := deg_to_rad(ROLL_DRIFT) * drift
	return Transform3D(Basis.from_euler(Vector3(pitch, yaw, roll)), at)


func _fall_pose(v: float, elapsed: float) -> Transform3D:
	var y := lerpf(REVEAL_TOP, TreeLayout.PIT_Y + EYE_M, _drop_at(v))
	var angle := lerpf(START_ANGLE, TreeLayout.LAND_ANGLE, _table_at(_turn, v))
	var out := lerpf(0.0, 1.0, _smoother(clampf((v - 0.78) / 0.22, 0.0, 1.0)))
	var radius := lerpf(lerpf(BACK_M - TreeLayout.RING_R[0], HELIX_R, smoothstep(0.0, 0.25, v)), TreeLayout.LAND_R, out)
	var at := TreeLayout.on_ring(angle, radius, y)
	# Down the shaft as it starts to drop, then up and across at the top terrace's towers and their names while it is
	# still among them, turning; then across and down at the far wall going past, a look down at the pit as it
	# nears, and level with the pit's mouth as it lands.
	var pitch_deg := lerpf(-PITCH_DOWN, LOOK_UP_PITCH, smoothstep(0.0, 0.16, v))
	pitch_deg = lerpf(pitch_deg, MID_PITCH, smoothstep(0.17, 0.36, v))
	pitch_deg += 4.0 * sin(TAU * v * 1.4) * (1.0 - out)
	pitch_deg = lerpf(pitch_deg, DIP_PITCH, smoothstep(0.5, 0.62, v) * (1.0 - smoothstep(0.7, 0.8, v)))
	pitch_deg = lerpf(pitch_deg, LAND_PITCH, out)
	var yaw := PI / 2.0 - angle + 0.07 * sin(TAU * v * 1.3) * (1.0 - out)
	var roll := deg_to_rad(3.0) * sin(TAU * v * 0.9) * (1.0 - out)
	var shake := clampf(speed_at(elapsed) / 40.0, 0.0, 1.0) if v < 1.0 else 0.0
	at += Vector3(sin(elapsed * 23.1) + sin(elapsed * 37.7) * 0.5, sin(elapsed * 29.3) * 0.7, cos(elapsed * 19.9)) * 0.06 * shake
	roll += deg_to_rad(0.5) * sin(elapsed * 17.3) * shake
	return Transform3D(Basis.from_euler(Vector3(deg_to_rad(pitch_deg), yaw, roll)), at)


## The fall's speed as a share of its own mean: picking up as a falling body does, a little more all the way down,
## then braking to a stop.
static func _speed_shape(v: float) -> float:
	var up := minf(v / ACCEL_SHARE, 1.0)
	var s := up * (2.0 - up) * (1.0 + 0.35 * v)
	var brake := clampf((1.0 - v) / DECEL_SHARE, 0.0, 1.0)
	return s * _smoother(brake)


## How fast it turns round the axis as a share of its own mean: easing in from the reveal's stillness, quickest
## early (while it is still among the top terrace's towers, the most folders) and slowing all the way down.
static func _turn_shape(v: float) -> float:
	return smoothstep(0.0, 0.08, v) * pow(1.0 - v, 1.3) + 0.04


## The drop and the turn as tables, each the running share of the whole (0 to 1).
func _plan_drop() -> void:
	_drop_mean = _integrate(_drop, _speed_shape)
	_integrate(_turn, _turn_shape)


static func _integrate(table: PackedFloat32Array, shape: Callable) -> float:
	table.resize(DROP_SAMPLES + 1)
	table[0] = 0.0
	var total := 0.0
	for i in DROP_SAMPLES:
		total += (float(shape.call(float(i) / DROP_SAMPLES)) + float(shape.call(float(i + 1) / DROP_SAMPLES))) * 0.5 / DROP_SAMPLES
		table[i + 1] = total
	for i in table.size():
		table[i] /= maxf(total, 0.0001)
	return total


func _drop_at(v: float) -> float:
	if _drop.is_empty():
		_plan_drop()
	return _table_at(_drop, v)


static func _table_at(table: PackedFloat32Array, v: float) -> float:
	var x := clampf(v, 0.0, 1.0) * DROP_SAMPLES
	var i := mini(floori(x), DROP_SAMPLES - 1)
	return lerpf(table[i], table[i + 1], x - i)


static func _ease_in_out(x: float, power: float) -> float:
	return 0.5 * pow(2.0 * x, power) if x < 0.5 else 1.0 - 0.5 * pow(2.0 * (1.0 - x), power)


static func _smoother(x: float) -> float:
	return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)


# --- Counting (for the checks). ---

func node_count() -> int:
	return find_children("*", "", true, false).size()


func label_count() -> int:
	return _labels.size()


func piece_count() -> int:
	return _towers.multimesh.instance_count if _towers != null else 0


## The names shown on the towers, in order.
func label_texts() -> PackedStringArray:
	var out := PackedStringArray()
	for label in _labels:
		out.append(label.text)
	return out


# --- Building. ---

## The void's colour: the theme's darkest, sunk toward black (a light theme's machine is as dark as any).
func void_color() -> Color:
	var base := colours.color("darker_background") if colours.mode != "light" else Color(0.03, 0.032, 0.045)
	return base.lerp(Color.BLACK, 0.55)


## `c` lifted toward white until it reads on the void as a shape does (OpenerPalette.SHAPE_CONTRAST).
func _neon(c: Color) -> Color:
	var dark := void_color()
	var out := c
	for i in 20:
		if OpenerPalette.contrast(out, dark) >= OpenerPalette.SHAPE_CONTRAST + 1.5:
			break
		out = out.lerp(Color.WHITE, 0.08)
	return out


func _world(bloom: bool) -> void:
	var holder := WorldEnvironment.new()
	holder.name = "Environment"
	_env = Environment.new()
	var dark := void_color()
	var sky_paint := ShaderMaterial.new()
	sky_paint.shader = SkyShader
	sky_paint.set_shader_parameter("zenith", dark.lerp(Color.BLACK, 0.4))
	sky_paint.set_shader_parameter("horizon", dark.lerp(_neon(colours.color("accent")), 0.05))
	sky_paint.set_shader_parameter("abyss", dark.lerp(_neon(colours.color("red")), 0.06))
	sky_paint.set_shader_parameter("glow", _neon(colours.color("red")) * 0.35)
	var sky := Sky.new()
	sky.sky_material = sky_paint
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color.BLACK
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	# Linear, with nothing over it: the screen's first frame is the terminal's colours exactly.
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_env.tonemap_exposure = 1.0
	_env.fog_enabled = true
	_env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	_env.fog_density = FOG
	_env.fog_light_color = dark.lerp(_neon(colours.color("accent")), 0.05)
	_env.fog_aerial_perspective = 0.9
	_env.fog_sky_affect = 0.0
	_env.glow_enabled = bloom
	_env.glow_intensity = 1.0
	_env.glow_strength = 1.0
	_env.glow_bloom = 0.0
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	_env.glow_hdr_threshold = 1.0
	_env.glow_hdr_scale = 2.0
	for level in 7:
		_env.set_glow_level(level, [0.0, 0.7, 1.0, 0.6, 0.25, 0.08, 0.0][level])
	holder.environment = _env
	add_child(holder)
	_camera = Camera3D.new()
	_camera.name = "Eye"
	_camera.near = 0.05
	_camera.far = 2600.0
	_camera.fov = FOV_SCREEN
	add_child(_camera)
	_camera.current = true


func _paint(shader: Shader) -> ShaderMaterial:
	var paint := ShaderMaterial.new()
	paint.shader = shader
	_paints.append(paint)
	return paint


func _city() -> void:
	var paint := _paint(TowerShader)
	paint.set_shader_parameter("body_color", void_color().lerp(Color.BLACK, 0.35))
	paint.set_shader_parameter("edge_color", _neon(colours.color("accent")))
	paint.set_shader_parameter("dim_color", _neon(colours.color("muted")))
	paint.set_shader_parameter("window_color", _neon(colours.color("blue")))
	paint.set_shader_parameter("cool_color", _neon(colours.color("cyan")))
	paint.set_shader_parameter("warm_color", _neon(colours.color("yellow")))
	paint.set_shader_parameter("alert_color", _neon(colours.color("red")))
	paint.set_shader_parameter("maze_color", _neon(colours.color("magenta")))
	paint.set_shader_parameter("hot_color", _neon(colours.color("red")))
	paint.set_shader_parameter("panel_color", colours.color("background").lerp(_neon(colours.color("accent")), 0.25))
	paint.set_shader_parameter("pit_y", TreeLayout.PIT_Y)
	paint.set_shader_parameter("panel_at", TreeLayout.panel_at())
	var box := BoxMesh.new()
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.use_custom_data = true
	many.mesh = box
	many.instance_count = layout.pieces.size()
	for i in layout.pieces.size():
		var piece: Dictionary = layout.pieces[i]
		var basis := Basis(Vector3.UP, piece["yaw"]) * Basis.from_scale(piece["size"])
		many.set_instance_transform(i, Transform3D(basis, piece["at"]))
		many.set_instance_custom_data(i, Color(piece["lit"], piece["kind"], piece["seed"], piece["flags"]))
	_towers = _instances("City", many, paint)


func _instances(node_name: String, many: MultiMesh, paint: Material) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = many
	node.material_override = paint
	node.custom_aabb = AABB(Vector3(-1500.0, -1300.0, -1500.0), Vector3(3000.0, 1600.0, 3000.0))
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


## The terraces, the pit's rim and the ceiling: flat rings, one mesh.
func _terraces() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in TreeLayout.RING_R.size():
		var inner: float = TreeLayout.RING_R[k] - TreeLayout.TERRACE_IN
		_ring(tool, inner, TreeLayout.RING_R[k] + TreeLayout.TERRACE_OUT, TreeLayout.RING_Y[k], 0.0)
	_ring(tool, TreeLayout.PIT_R, TreeLayout.RING_R[3] + TreeLayout.TERRACE_OUT, TreeLayout.PIT_Y, 2.0)
	_ring(tool, 0.0, 900.0, TreeLayout.CEILING_Y, 1.0)
	var paint := _paint(TerraceShader)
	paint.set_shader_parameter("floor_color", void_color().lerp(Color.BLACK, 0.2))
	paint.set_shader_parameter("grid_color", _neon(colours.color("accent")))
	paint.set_shader_parameter("rim_color", _neon(colours.color("accent")))
	paint.set_shader_parameter("maze_color", _neon(colours.color("magenta")))
	paint.set_shader_parameter("trace_color", _neon(colours.color("muted")))
	paint.set_shader_parameter("hot_color", _neon(colours.color("red")))
	paint.set_shader_parameter("pit_r", TreeLayout.PIT_R)
	var node := MeshInstance3D.new()
	node.name = "Terraces"
	node.mesh = tool.commit()
	node.material_override = paint
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


static func _ring(tool: SurfaceTool, inner: float, outer: float, y: float, kind: float) -> void:
	var steps := 160
	for i in steps:
		var a0 := TAU * i / steps
		var a1 := TAU * (i + 1) / steps
		var p := [TreeLayout.on_ring(a0, inner, y), TreeLayout.on_ring(a1, inner, y), TreeLayout.on_ring(a1, outer, y), TreeLayout.on_ring(a0, outer, y)]
		for at in [0, 2, 1, 0, 3, 2]:
			tool.set_normal(Vector3.UP)
			tool.set_uv(Vector2(inner, kind))
			tool.add_vertex(p[at])


## The node_modules pit: a well under the bottom of the tree, a smaller one inside it, and the hot core.
func _pit() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_well(tool, Vector2.ZERO, TreeLayout.PIT_R, TreeLayout.PIT_Y, TreeLayout.PIT_Y - TreeLayout.PIT_DEEP)
	_well(tool, Vector2(8.0, -5.0), 12.5, TreeLayout.PIT_Y - 70.0, TreeLayout.PIT_Y - TreeLayout.PIT_DEEP)
	var paint := _paint(MazeShader)
	paint.set_shader_parameter("wall_color", void_color().lerp(Color.BLACK, 0.3))
	paint.set_shader_parameter("maze_color", _neon(colours.color("magenta")))
	paint.set_shader_parameter("hot_color", _neon(colours.color("red")))
	paint.set_shader_parameter("pit_y", TreeLayout.PIT_Y)
	paint.set_shader_parameter("core_y", TreeLayout.PIT_Y - CORE_DOWN)
	var node := MeshInstance3D.new()
	node.name = "Pit"
	node.mesh = tool.commit()
	node.material_override = paint
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	var core := MeshInstance3D.new()
	core.name = "Core"
	var ball := SphereMesh.new()
	ball.radius = CORE_R
	ball.height = CORE_R * 2.0
	core.mesh = ball
	_core_paint = ShaderMaterial.new()
	_core_paint.shader = CoreShader
	_core_paint.set_shader_parameter("hot_color", _neon(colours.color("red")))
	core.material_override = _core_paint
	core.position = Vector3(0.0, TreeLayout.PIT_Y - CORE_DOWN, 0.0)
	add_child(core)


static func _well(tool: SurfaceTool, centre: Vector2, radius: float, top: float, bottom: float) -> void:
	var steps := 64
	for i in steps:
		var a0 := TAU * i / steps
		var a1 := TAU * (i + 1) / steps
		var c := Vector3(centre.x, 0.0, centre.y)
		var p := [c + TreeLayout.on_ring(a0, radius, top), c + TreeLayout.on_ring(a1, radius, top), c + TreeLayout.on_ring(a1, radius, bottom), c + TreeLayout.on_ring(a0, radius, bottom)]
		for at in [0, 1, 2, 0, 2, 3]:
			tool.set_normal(-TreeLayout.on_ring((a0 + a1) * 0.5, 1.0, 0.0))
			tool.set_uv(centre)
			tool.set_uv2(Vector2(radius, 0.0))
			tool.add_vertex(p[at])


## The code light pouring down the shaft, the tree's cables, and the air round the camera.
func _light() -> void:
	var quad := QuadMesh.new()
	var pour := MultiMesh.new()
	pour.transform_format = MultiMesh.TRANSFORM_3D
	pour.use_custom_data = true
	pour.mesh = quad
	pour.instance_count = layout.streams.size()
	for i in layout.streams.size():
		var s: Dictionary = layout.streams[i]
		var tall: float = s["top"] - s["bottom"]
		var basis := Basis(Vector3(s["width"], 0.0, 0.0), Vector3(0.0, tall, 0.0), Vector3(0.0, 0.0, 1.0))
		pour.set_instance_transform(i, Transform3D(basis, Vector3(s["x"], (s["top"] + s["bottom"]) * 0.5, s["z"])))
		pour.set_instance_custom_data(i, Color(s["seed"], 0.0, 0.75 + 0.5 * s["seed"], 0.0))
	var code := _paint(StreamShader)
	code.set_shader_parameter("mode", 0.0)
	code.set_shader_parameter("code_color", _neon(colours.color("green")))
	code.set_shader_parameter("head_color", _neon(colours.color("green")).lerp(Color.WHITE, 0.6))
	code.set_shader_parameter("fog_density", FOG)
	_streams = _instances("Streams", pour, code)
	var hung := MultiMesh.new()
	hung.transform_format = MultiMesh.TRANSFORM_3D
	hung.use_custom_data = true
	hung.mesh = quad
	hung.instance_count = layout.cables.size()
	for i in layout.cables.size():
		var cable: Dictionary = layout.cables[i]
		var from: Vector3 = cable["from"]
		var to: Vector3 = cable["to"]
		var axis := from - to
		var across := axis.cross(Vector3.UP)
		across = (across.normalized() if across.length() > 0.001 else Vector3.RIGHT) * 0.9
		var basis := Basis(across, axis, across.cross(axis).normalized())
		hung.set_instance_transform(i, Transform3D(basis, (from + to) * 0.5))
		var pit := 1.0 if to.y <= TreeLayout.PIT_Y + 0.1 else 0.0
		hung.set_instance_custom_data(i, Color(float(i % 7) / 7.0, pit, 1.0, 0.0))
	var wire := _paint(StreamShader)
	wire.set_shader_parameter("mode", 1.0)
	wire.set_shader_parameter("cable_color", _neon(colours.color("accent")))
	wire.set_shader_parameter("pit_color", _neon(colours.color("magenta")))
	wire.set_shader_parameter("fog_density", FOG)
	_cables = _instances("Cables", hung, wire)
	var air := MultiMesh.new()
	air.transform_format = MultiMesh.TRANSFORM_3D
	air.use_custom_data = true
	air.mesh = quad
	air.instance_count = AIR
	var rng := RandomNumberGenerator.new()
	rng.seed = layout.roll_seed + 2
	for i in AIR:
		air.set_instance_transform(i, Transform3D.IDENTITY)
		air.set_instance_custom_data(i, Color(rng.randf(), rng.randf(), rng.randf(), rng.randf()))
	_air_paint = ShaderMaterial.new()
	_air_paint.shader = SpeedShader
	_air_paint.set_shader_parameter("line_color", _neon(colours.color("foreground")).lerp(_neon(colours.color("accent")), 0.4))
	_air_paint.set_shader_parameter("mote_color", _neon(colours.color("accent")))
	_air = _instances("Air", air, _air_paint)


## A name over each labelled tower, the pit's over it, and the hottest process's in the pit's mouth.
func _names() -> void:
	var name_ink := _neon(colours.color("bright_foreground"))
	for entry in layout.labels:
		var ink := name_ink
		var kind := int(entry["kind"])
		if kind == TreeLayout.Kind.HIDDEN or kind == TreeLayout.Kind.UNCOUNTED:
			ink = _neon(colours.color("muted"))
		elif kind == TreeLayout.Kind.MAZE:
			ink = _neon(colours.color("magenta"))
		var label := _label(entry["text"], entry["px"])
		label.position = entry["at"]
		label.modulate = ink
		_labels.append(label)
	var shown := OpenerData.clean(process_name, TreeLayout.LABEL_LONGEST)
	if shown != "":
		_process_label = _label(shown, PROCESS_PX)
		_process_label.name = "Process"
		_process_label.position = Vector3(0.0, TreeLayout.PIT_Y - PROCESS_DOWN, 0.0)
		_process_label.modulate = _neon(colours.color("red"))
	var sign := _label(HOME_SIGN, HOME_SIGN_PX)
	sign.name = "Home"
	sign.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sign.position = TreeLayout.on_ring(TreeLayout.HOME_ANGLE, TreeLayout.RING_R[0] - 0.3, HOME_SIGN_Y)
	sign.rotation.y = TreeLayout.facing_in(TreeLayout.HOME_ANGLE) + PI
	sign.modulate = _neon(colours.color("accent")) * HOME_SIGN_GLOW


func _label(text: String, px: float) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = label_font()
	label.font_size = LABEL_FONT_PX
	label.pixel_size = px
	label.outline_size = LABEL_OUTLINE
	label.outline_modulate = Color(void_color(), 0.7)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.double_sided = true
	label.shaded = false
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(label)
	return label


## The names' font: the terminal's (the system's monospace), bold, as a distance field so it is crisp at any size.
static func label_font() -> SystemFont:
	if _label_font == null:
		_label_font = SystemFont.new()
		_label_font.font_names = PackedStringArray(FakeTerminal.FONT_NAMES)
		_label_font.font_weight = 700
		_label_font.multichannel_signed_distance_field = true
		_label_font.msdf_pixel_range = 32
		_label_font.msdf_size = 64
		_label_font.allow_system_fallback = true
	return _label_font


## The screen on the monolith's face: the window's shape, a thin bezel round it.
func _panel_mesh() -> void:
	var high := TreeLayout.PANEL_H
	var wide := high * _aspect
	var quad := QuadMesh.new()
	quad.size = Vector2(wide + BEZEL_M * 2.0, high + BEZEL_M * 2.0)
	if _panel == null:
		_panel = MeshInstance3D.new()
		_panel.name = "Screen"
		_panel_paint = ShaderMaterial.new()
		_panel_paint.shader = PanelShader
		_panel_paint.set_shader_parameter("bezel_color", _neon(colours.color("accent")))
		_panel.material_override = _panel_paint
		_panel.position = TreeLayout.panel_at()
		_panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_panel)
	_panel.mesh = quad
	_panel_paint.set_shader_parameter("inner", Vector2(wide / quad.size.x, high / quad.size.y))
	for paint in _paints:
		if paint.shader == TowerShader:
			paint.set_shader_parameter("panel_half", Vector2(wide, high) * 0.5 + Vector2.ONE * BEZEL_M)
