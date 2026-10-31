class_name RuinsWorld
extends Node3D
## A ruins district, built (C36, PRD 5.6): a set's plan (scripts/ruins/ruins_layout.gd) made into a playable space
## from the kit's pieces (scripts/ruins/ruins_pieces.gd), and put in a register (scripts/ruins/ruins_register.gd).
##
## Built once a run per set into merged meshes, one per chunk of the district (CHUNK_M square, so what is behind the
## camera is not drawn) and one per sector of the void round it, a surface per material (bodies and the floor throw
## shadows; lights, the far giants and the haze do not), and its collision: one static body of boxes, the plan's whole
## `boxes` (the floor, the parapets, the blocks, the cover). Kept for the next arena with the same set, so a retry or an
## R reload builds nothing. Nothing is rebuilt while it is drawn: its lights blink, the cables swing, the rain runs and
## the code falls in its shaders and its particles, on the arena's clock (stepped here at the game's pace, as the
## arena's dressing steps it).
##
## The register (set_register()): the shader global ruins_mix (every ruins shader blends by it), and, mixed the same
## way, the place's environment (fog, sky, ambient), the sun, its lamps' colours and its weather: rain in the ruins,
## motes of data rising over the clean grid, glyphs falling where memory is thin. A change of register runs over
## SHIFT_S with a tear through it (the shader global ruins_tear), so a mission's register shift changes the world.
##
## Its lamps: an OmniLight by each sign in the sign's colour, a small one at each terminal and in each hole; its
## cut cables spark now and then, each with a flash of light. The daemons' code rain (scripts/code_rain_driver.gd's
## slots, the nearest daemons) is fed to its bodies' shader, so the walls bleed code where daemons are near.
## Its places: point() (the plan's, in world space). Visual and collision only: it reads nothing, runs nothing.

const Palette = preload("res://scripts/palette.gd")
const BODY_SHADER := preload("res://shaders/ruins_body.gdshader")
const LIGHT_SHADER := preload("res://shaders/ruins_light.gdshader")
const FLOOR_SHADER := preload("res://shaders/ruins_floor.gdshader")
const HAZE_SHADER := preload("res://shaders/ruins_haze.gdshader")

const GROUP := &"ruins_world"
const NODE_NAME := "Ruins"
## Bumped whenever the pieces or the build change, so a kept build is never reused for a different one.
const BUILD_VERSION := 1
const CHUNK_M := 16.0
## Seconds a register shift takes.
const SHIFT_S := 1.4
## Budgets, checked by tests/ruins_test.gd at every set: triangles drawn and draw calls (a surface each, a particle
## system each, the haze).
const BUDGET_TRIANGLES := 520000
const BUDGET_DRAW_CALLS := 190
## How many lamps of each kind, at most.
const SIGN_LAMPS := 8
const TERMINAL_LAMPS := 6
const SPARKS := 8
## The weather's particles at the high particle level (the settings' level takes a share of them).
const RAIN_AMOUNT := 3200
const MOTE_AMOUNT := 600
const GLYPH_AMOUNT := 900
const SPARK_AMOUNT := 28
## The globals.
const MIX_GLOBAL := &"ruins_mix"
const TEAR_GLOBAL := &"ruins_tear"

signal register_changed(register: String)

## The set it is, and its plan.
var ruins: RuinsSet = null
var layout: RuinsLayout = null
## The place's environment and sun, when it stands in an arena (RuinsStage hands them in); null standing alone.
var environment: Environment = null
var sun: DirectionalLight3D = null
## The register it is in (or going to), and how much of each it shows now.
var register := ""
var mix := Vector4(1, 0, 0, 0)
var tear := 0.0
## What it last pushed to the shader globals (ruins_mix, ruins_tear): the tests' view, as a headless run keeps no globals.
var pushed_mix := Vector4(-1, -1, -1, -1)
var pushed_tear := -1.0

var _from := Vector4(1, 0, 0, 0)
var _to := Vector4(1, 0, 0, 0)
var _shift_t := 0.0
var _shift_s := 0.0
var _built := {}
var _giants: Array[MeshInstance3D] = []
var _rain: GPUParticles3D = null
var _motes: GPUParticles3D = null
var _glyphs: GPUParticles3D = null
var _sparks: Array = []
var _lamps: Array = []
var _spark_rng := RandomNumberGenerator.new()
var _driver: Node = null
var _driver_uploads := -1
var _env_dirty := true

static var _kept := {}
static var _materials := {}


func _init(from: RuinsSet = null) -> void:
	ruins = from
	name = NODE_NAME


## The ruins `node` stands in, or null.
static func of(node: Node) -> RuinsWorld:
	if node == null or not node.is_inside_tree():
		return null
	for w in node.get_tree().get_nodes_in_group(GROUP):
		return w
	return null


func _ready() -> void:
	add_to_group(GROUP)
	if ruins == null:
		push_error("ruins: no set to build")
		return
	layout = RuinsLayout.of(ruins)
	var key := "%s:%d:%d" % [ruins.id, ruins.seed, BUILD_VERSION]
	if not _kept.has(key):
		_kept[key] = _build()
	_built = _kept[key]
	_show()
	_spark_rng.seed = ruins.seed
	set_register(ruins.register, 0.0)


# --- Places. ---

## The plan's point `name` in world space; Vector3.INF for a name it has not.
func point(name: String) -> Vector3:
	if layout == null or not layout.points.has(name):
		return Vector3.INF
	return global_transform * (layout.points[name] as Vector3)


func has_point(name: String) -> bool:
	return layout != null and layout.points.has(name)


## Every point whose name begins with `prefix` + "_", in order, in world space.
func points_of(prefix: String) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var i := 0
	while has_point("%s_%d" % [prefix, i]):
		out.append(point("%s_%d" % [prefix, i]))
		i += 1
	return out


# --- The register. ---

## Puts it in `name` ("tron", "cyberpunk", "matrix" or "all") over `seconds` (0 at once), tearing as it goes.
func set_register(name: String, seconds: float = SHIFT_S) -> void:
	if not RuinsRegister.NAMES.has(name):
		name = "tron"
	register = name
	_from = mix
	_to = RuinsRegister.weights(name)
	_shift_s = maxf(seconds, 0.0)
	_shift_t = 0.0
	if _shift_s <= 0.0:
		mix = _to
		tear = 0.0
		_push()
	register_changed.emit(name)


## True while a shift is still running.
func shifting() -> bool:
	return _shift_s > 0.0 and _shift_t < _shift_s


func _process(delta: float) -> void:
	ArenaArt.step_clock(delta)
	if _shift_s > 0.0:
		_shift_t += delta
		var k := clampf(_shift_t / _shift_s, 0.0, 1.0)
		mix = _from.lerp(_to, k * k * (3.0 - 2.0 * k))
		tear = sin(PI * k)
		if k >= 1.0:
			_shift_s = 0.0
			mix = _to
			tear = 0.0
		_push()
	_follow_camera()
	_step_sparks(delta)
	_feed_rain()


func _push() -> void:
	RenderingServer.global_shader_parameter_set(MIX_GLOBAL, mix)
	RenderingServer.global_shader_parameter_set(TEAR_GLOBAL, tear)
	pushed_mix = mix
	pushed_tear = tear
	var env := RuinsRegister.env_at(mix)
	if environment != null:
		environment.fog_light_color = env["fog"]
		environment.fog_density = env["fog_density"]
		environment.fog_depth_end = env["fog_end"]
		environment.ambient_light_color = env["ambient"]
		environment.ambient_light_energy = env["ambient_energy"]
		if environment.sky != null and environment.sky.sky_material is ShaderMaterial:
			var sky := environment.sky.sky_material as ShaderMaterial
			sky.set_shader_parameter("horizon_color", env["horizon"])
			sky.set_shader_parameter("abyss_color", env["abyss"])
			sky.set_shader_parameter("glow_color", env["glow"])
			sky.set_shader_parameter("point_color", env["points"])
			sky.set_shader_parameter("glow_energy", env["glow_energy"])
	if sun != null and is_instance_valid(sun):
		sun.light_color = env["sun"]
		# Black ICE (I3) dims the sun from its own base; the base follows the register.
		sun.set_meta(&"blackout_base", env["sun_energy"])
		sun.light_energy = env["sun_energy"] * ArenaArt.light_level
	var s := RuinsRegister.shares(mix)
	for lamp in _lamps:
		var light: OmniLight3D = lamp["light"]
		var col := _slot_colour(lamp["slot"], s)
		light.light_color = col
		light.light_energy = lamp["energy"] * (1.0 - 0.75 * s.x * float(lamp["slot"] == RuinsPieces.Slot.SIGN_A or lamp["slot"] == RuinsPieces.Slot.SIGN_B))
	if _rain != null:
		_rain.amount_ratio = clampf(env["rain"], 0.0, 1.0)
		_rain.emitting = env["rain"] > 0.01
	if _motes != null:
		_motes.amount_ratio = clampf(env["motes"], 0.0, 1.0)
		_motes.emitting = env["motes"] > 0.01
	if _glyphs != null:
		_glyphs.amount_ratio = clampf(env["glyphs"], 0.0, 1.0)
		_glyphs.emitting = env["glyphs"] > 0.01


func _slot_colour(slot: int, s: Vector3) -> Color:
	var a: Color = RuinsRegister.SLOTS["tron"][slot]
	var b: Color = RuinsRegister.SLOTS["cyberpunk"][slot]
	var c: Color = RuinsRegister.SLOTS["matrix"][slot]
	return Color(a.r * s.x + b.r * s.y + c.r * s.z, a.g * s.x + b.g * s.y + c.g * s.z, a.b * s.x + b.b * s.y + c.b * s.z)


# --- The settings. ---

## The graphics settings (scripts/main.gd's apply_quality()): the full skyline or the plain (the giants hidden).
func apply_quality(g: Dictionary) -> void:
	for giant in _giants:
		giant.visible = g.get("skyline", true) != false


# --- Building. ---

## The materials, made once a run and shared by every set.
static func materials() -> Dictionary:
	if _materials.is_empty():
		for pair in [["body", BODY_SHADER], ["light", LIGHT_SHADER], ["floor", FLOOR_SHADER], ["haze", HAZE_SHADER]]:
			var m := ShaderMaterial.new()
			m.shader = pair[1]
			_materials[pair[0]] = m
		RuinsRegister.dress(_materials["body"], _materials["light"], _materials["floor"], _materials["haze"])
	return _materials


func _build() -> Dictionary:
	var started := Time.get_ticks_msec()
	var chunks := {}
	var near_kit := func(p: Vector3) -> Array:
		var key := Vector2i(floori(p.x / CHUNK_M), floori(p.z / CHUNK_M))
		if not chunks.has(key):
			var kit := ShapeKit.new()
			chunks[key] = [kit, {"body": kit.bucket(Vector3.ZERO, true, true), "light": kit.bucket(Vector3.ZERO, false, true), "floor": kit.bucket(Vector3.ZERO, false, true)}, false]
		return chunks[key]
	var far_kit := func(p: Vector3) -> Array:
		var key := "far:%d" % posmod(floori((atan2(p.x, p.z) + PI) / TAU * 8.0), 8)
		if not chunks.has(key):
			var kit := ShapeKit.new()
			chunks[key] = [kit, {"body": kit.bucket(Vector3.ZERO, true, true), "light": kit.bucket(Vector3.ZERO, false, true), "floor": kit.bucket(Vector3.ZERO, false, true)}, true]
		return chunks[key]
	var rng := RandomNumberGenerator.new()
	var dice := func(kind: String, index: int) -> RandomNumberGenerator:
		rng.seed = hash("%d:%s:%d" % [ruins.seed, kind, index])
		return rng
	var out := {"signs": [], "terminals": [], "tips": [], "holes": []}
	# The floor: a slab a cell, its damage worst by the holes and the edges.
	for z in layout.size.y:
		for x in layout.size.x:
			var c := Vector2i(x, z)
			var kind := layout.cell(c)
			if kind != RuinsLayout.Cell.FLOOR and kind != RuinsLayout.Cell.BLOCK:
				continue
			var rims := 0
			var near_void := 0
			for side in 4:
				var n := layout.cell(c + RuinsLayout.SIDES[side])
				if n == RuinsLayout.Cell.VOID or n == RuinsLayout.Cell.HOLE:
					rims |= 1 << side
					near_void += 1
			var r: RandomNumberGenerator = dice.call("slab", z * 64 + x)
			var damage := clampf(r.randf_range(0.05, 0.45) + near_void * 0.22, 0.0, 1.0)
			var at: Array = near_kit.call(layout.center(c))
			RuinsPieces.slab(at[0], at[1], layout, c, damage, rims if kind == RuinsLayout.Cell.FLOOR else 0)
	for i in layout.edges.size():
		var e: Dictionary = layout.edges[i]
		var at: Array = near_kit.call(layout.center(e["cell"]))
		RuinsPieces.edge(at[0], at[1], layout, e, dice.call("edge", i))
	for i in layout.holes.size():
		var h: Dictionary = layout.holes[i]
		var mid := (layout.center(h["rect"].position) + layout.center(h["rect"].end - Vector2i.ONE)) * 0.5
		var at: Array = near_kit.call(mid)
		RuinsPieces.hole(at[0], at[1], layout, h, dice.call("hole", i))
		out["holes"].append(mid)
	for i in layout.blocks.size():
		var bl: Dictionary = layout.blocks[i]
		var r: Rect2i = bl["rect"]
		var lo := layout.center(r.position) - Vector3(RuinsLayout.CELL_M, 0, RuinsLayout.CELL_M) * 0.5 + Vector3.ONE * RuinsLayout.BLOCK_INSET
		var hi := layout.center(r.end - Vector2i.ONE) + Vector3(RuinsLayout.CELL_M, 0, RuinsLayout.CELL_M) * 0.5 - Vector3.ONE * RuinsLayout.BLOCK_INSET
		lo.y = 0.0
		hi.y = 0.0
		var at: Array = near_kit.call((lo + hi) * 0.5)
		match bl["kind"]:
			"monolith":
				RuinsPieces.monolith(at[0], at[1], lo, hi, layout.folder_name(bl["seed"]), dice.call("monolith", i))
			"fallen":
				RuinsPieces.fallen(at[0], at[1], lo, hi, dice.call("fallen", i))
	for i in layout.cover.size():
		var p: Dictionary = layout.cover[i]
		var at: Array = near_kit.call(p["at"])
		RuinsPieces.cover(at[0], at[1], p, dice.call("cover", i))
		if p["kind"] == "terminal":
			out["terminals"].append(Transform3D(Basis(Vector3.UP, p["yaw"]), p["at"]) * Vector3(0, 1.1, -0.5))
	for i in layout.towers.size():
		var t: Dictionary = layout.towers[i]
		var at: Array = near_kit.call(t["at"])
		RuinsPieces.rack_tower(at[0], at[1], t, dice.call("tower", i))
	# The district stands on pylons of racks going down into the abyss, under its edges.
	var pylons := 0
	for i in layout.edges.size():
		var e: Dictionary = layout.edges[i]
		if e["hole"] or i % 3 != 0:
			continue
		var side: Vector2i = RuinsLayout.SIDES[e["side"]]
		var r: RandomNumberGenerator = dice.call("pylon", i)
		var t := {"at": layout.center(e["cell"]) + Vector3(side.x, 0, side.y) * 0.6, "tall": -RuinsLayout.SLAB_M - 0.05, "foot": r.randf_range(90.0, 170.0), "width": r.randf_range(2.2, 3.4), "depth": r.randf_range(1.6, 2.4), "yaw": atan2(side.x, side.y), "lean": Vector2(r.randf_range(-2.0, 2.0), r.randf_range(-2.0, 2.0)), "inside": false}
		var at: Array = near_kit.call(t["at"])
		RuinsPieces.rack_tower(at[0], at[1], t, r, false)
		pylons += 1
	for i in layout.giants.size():
		var g: Dictionary = layout.giants[i]
		var at: Array = far_kit.call(g["at"])
		RuinsPieces.giant(at[0], at[1], g, dice.call("giant", i))
	for i in layout.cables.size():
		var c: Dictionary = layout.cables[i]
		var at: Array = near_kit.call((c["from"] + c["to"]) * 0.5)
		RuinsPieces.cable(at[0], at[1], c, dice.call("cable", i))
		out["tips"].append_array(RuinsPieces.cable_tips(c))
	for i in layout.signs.size():
		var s: Dictionary = layout.signs[i]
		var t: Dictionary = layout.towers[s["tower"]]
		var at: Array = near_kit.call(t["at"])
		var lamp := RuinsPieces.sign(at[0], at[1], t, s, dice.call("sign", i))
		out["signs"].append([lamp, RuinsPieces.Slot.SIGN_A if s["slot"] == 0 else RuinsPieces.Slot.SIGN_B])
	# Commit: per chunk, a solid mesh (bodies and the floor, throwing shadows unless far) and a light mesh.
	var mats := materials()
	var meshes := []
	var triangles := 0
	var surfaces := 0
	for key in chunks:
		var kit: ShapeKit = chunks[key][0]
		var b: Dictionary = chunks[key][1]
		var far: bool = chunks[key][2]
		var solid := ArrayMesh.new()
		for part in ["body", "floor"]:
			if kit.count(b[part]) > 0:
				kit.commit(b[part], solid)
				solid.surface_set_material(solid.get_surface_count() - 1, mats[part])
				triangles += kit.count(b[part]) / 3
		var light := ArrayMesh.new()
		if kit.count(b["light"]) > 0:
			kit.commit(b["light"], light)
			light.surface_set_material(0, mats["light"])
			triangles += kit.count(b["light"]) / 3
		if solid.get_surface_count() > 0:
			meshes.append({"mesh": solid, "shadow": not far, "far": far, "name": "Solid %s" % str(key)})
			surfaces += solid.get_surface_count()
		if light.get_surface_count() > 0:
			meshes.append({"mesh": light, "shadow": false, "far": far, "name": "Light %s" % str(key)})
			surfaces += 1
	var haze := _haze_mesh()
	triangles += 2 * int(haze.get_meta(&"cards", 0))
	out["meshes"] = meshes
	out["haze"] = haze
	var shapes := []
	for box in layout.boxes:
		var shape := BoxShape3D.new()
		shape.size = box["size"]
		shapes.append([box["xform"], shape])
	out["shapes"] = shapes
	out["triangles"] = triangles
	out["surfaces"] = surfaces
	out["pylons"] = pylons
	out["ms"] = Time.get_ticks_msec() - started
	return out


## The haze: soft cards in the void round the district and up through its holes (steam, in the rain).
func _haze_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:haze" % ruins.seed)
	var ext := layout.half_extent()
	var card := func(at: Vector3, size: Vector2, facing: Vector3, slot: float, rise: float) -> void:
		var right := Vector3.UP.cross(facing).normalized()
		var up := Vector3.UP
		var c := [at - right * size.x * 0.5, at + right * size.x * 0.5, at + right * size.x * 0.5 + up * size.y, at - right * size.x * 0.5 + up * size.y]
		var uv := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		var colour := Color(rng.randf(), rise, slot, 1.0)
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_color(colour)
			st.set_uv(uv[i])
			st.set_normal(facing)
			st.add_vertex(c[i])
	for i in 34:
		var a := rng.randf() * TAU
		var d := rng.randf_range(maxf(ext.x, ext.y) + 8.0, maxf(ext.x, ext.y) + 120.0)
		var at := Vector3(sin(a) * d, rng.randf_range(-40.0, 18.0), cos(a) * d)
		card.call(at, Vector2(rng.randf_range(24.0, 70.0), rng.randf_range(10.0, 34.0)), -at.normalized() * Vector3(1, 0, 1), 0.0, rng.randf_range(0.0, 0.3))
	for h in layout.holes:
		var mid := (layout.center(h["rect"].position) + layout.center(h["rect"].end - Vector2i.ONE)) * 0.5
		for k in 3:
			var facing := Vector3(sin(k * 1.05), 0, cos(k * 1.05))
			card.call(mid + Vector3(0, -2.0, 0), Vector2(3.4, 9.0), facing, 1.0, 1.0)
	var mesh := st.commit()
	if mesh.get_surface_count() > 0:
		mesh.surface_set_material(0, materials()["haze"])
	mesh.set_meta(&"cards", 34 + 3 * layout.holes.size())
	return mesh


func _show() -> void:
	for m in _built["meshes"]:
		var node := MeshInstance3D.new()
		node.name = m["name"]
		node.mesh = m["mesh"]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if m["shadow"] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		if m["far"]:
			_giants.append(node)
	var haze := MeshInstance3D.new()
	haze.name = "Haze"
	haze.mesh = _built["haze"]
	haze.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(haze)
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for s in _built["shapes"]:
		var shape := CollisionShape3D.new()
		shape.transform = s[0]
		shape.shape = s[1]
		body.add_child(shape)
	_lamps.clear()
	for i in mini(_built["signs"].size(), SIGN_LAMPS):
		var s: Array = _built["signs"][i]
		_lamp(s[0], s[1], 5.0, 22.0)
	for i in mini(_built["terminals"].size(), TERMINAL_LAMPS):
		_lamp(_built["terminals"][i], RuinsPieces.Slot.SCREEN, 0.9, 4.5)
	for mid in _built["holes"]:
		_lamp(mid + Vector3(0, -2.5, 0), RuinsPieces.Slot.VOID, 2.5, 9.0)
	_weather()
	var tips: Array = _built["tips"]
	for i in mini(tips.size(), SPARKS):
		_spark_at(tips[(i * 5) % tips.size()])


func _lamp(at: Vector3, slot: int, energy: float, reach: float) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.omni_range = reach
	light.omni_attenuation = 1.4
	light.shadow_enabled = false
	add_child(light)
	_lamps.append({"light": light, "slot": slot, "energy": energy})


# --- Weather and sparks. ---

func _weather() -> void:
	var share := ParticleFx.share()
	_rain = _emitter("Rain", int(RAIN_AMOUNT * share), 0.85, _rain_process(), _quad(Vector2(0.012, 0.75)), _particle_material(Color(0.6, 0.55, 1.0, 0.32), BaseMaterial3D.BILLBOARD_FIXED_Y, null))
	_motes = _emitter("Motes", int(MOTE_AMOUNT * share), 9.0, _mote_process(), _quad(Vector2(0.05, 0.05)), _particle_material(Color(Palette.MINT, 0.8), BaseMaterial3D.BILLBOARD_PARTICLES, null))
	var glyph_mat := _particle_material(Color(Palette.MATRIX_GREEN, 0.9), BaseMaterial3D.BILLBOARD_PARTICLES, _glyph_atlas())
	glyph_mat.particles_anim_h_frames = 8
	glyph_mat.particles_anim_v_frames = 8
	glyph_mat.particles_anim_loop = false
	_glyphs = _emitter("Glyphs", int(GLYPH_AMOUNT * share), 4.5, _glyph_process(), _quad(Vector2(0.13, 0.16)), glyph_mat)


func _emitter(label: String, amount: int, life: float, process: ParticleProcessMaterial, mesh: Mesh, mat: Material) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = label
	p.amount = maxi(amount, 1)
	p.lifetime = life
	p.local_coords = false
	p.process_material = process
	p.draw_pass_1 = mesh
	p.material_override = mat
	p.visibility_aabb = AABB(Vector3(-60, -40, -60), Vector3(120, 80, 120))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.preprocess = minf(life, 3.0)
	add_child(p)
	return p


func _quad(size: Vector2) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = size
	return q


func _particle_material(colour: Color, billboard: int, texture: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = billboard
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(colour.r * 2.2, colour.g * 2.2, colour.b * 2.2, colour.a)
	m.disable_receive_shadows = true
	# Faded out close to the eye, so nothing of the weather fills the view.
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = 1.2
	m.distance_fade_max_distance = 4.5
	if texture != null:
		m.albedo_texture = texture
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return m


func _rain_process() -> ParticleProcessMaterial:
	var p := ParticleProcessMaterial.new()
	p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(26, 1, 26)
	p.direction = Vector3(0.08, -1, 0.04)
	p.spread = 2.0
	p.initial_velocity_min = 24.0
	p.initial_velocity_max = 30.0
	p.gravity = Vector3.ZERO
	p.color = Color(1, 1, 1, 0.55)
	return p


func _mote_process() -> ParticleProcessMaterial:
	var p := ParticleProcessMaterial.new()
	p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(30, 9, 30)
	p.direction = Vector3(0, 1, 0)
	p.spread = 25.0
	p.initial_velocity_min = 0.15
	p.initial_velocity_max = 0.7
	p.gravity = Vector3.ZERO
	p.scale_min = 0.5
	p.scale_max = 1.6
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color(1, 1, 1, 1))
	fade.add_point(0.8, Color(1, 1, 1, 1))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	p.color_ramp = ramp
	return p


func _glyph_process() -> ParticleProcessMaterial:
	var p := ParticleProcessMaterial.new()
	p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(28, 6, 28)
	p.direction = Vector3(0, -1, 0)
	p.spread = 0.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 7.0
	p.gravity = Vector3.ZERO
	p.anim_offset_min = 0.0
	p.anim_offset_max = 1.0
	p.scale_min = 0.7
	p.scale_max = 1.4
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	p.color_ramp = ramp
	return p


## 64 code-rain glyphs, made here from seeded bits (the code rain's 4 by 6 grid, mirrored), never a font file.
func _glyph_atlas() -> ImageTexture:
	var image := Image.create(64, 80, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xC0DE
	for g in 64:
		var ox := (g % 8) * 8
		var oy := (g / 8) * 10
		for y in 6:
			for x in 2:
				if rng.randf() < 0.5:
					image.set_pixel(ox + 2 + x, oy + 2 + y, Color.WHITE)
					image.set_pixel(ox + 5 - x, oy + 2 + y, Color.WHITE)
	return ImageTexture.create_from_image(image)


func _spark_at(tip: Vector3) -> void:
	var p := ParticleProcessMaterial.new()
	p.direction = Vector3(0, -1, 0)
	p.spread = 70.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_min = 0.6
	p.scale_max = 1.2
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.95, 0.8, 1))
	fade.set_color(fade.get_point_count() - 1, Color(1.0, 0.5, 0.15, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	p.color_ramp = ramp
	var e := _emitter("Spark", maxi(int(SPARK_AMOUNT * ParticleFx.share()), 4), 0.7, p, _quad(Vector2(0.025, 0.12)), _particle_material(Color(1.0, 0.9, 0.7, 1.0), BaseMaterial3D.BILLBOARD_FIXED_Y, null))
	e.one_shot = true
	e.explosiveness = 0.9
	e.emitting = false
	e.preprocess = 0.0
	e.position = tip
	e.visibility_aabb = AABB(Vector3(-6, -8, -6), Vector3(12, 12, 12))
	var light := OmniLight3D.new()
	light.position = tip
	light.omni_range = 6.0
	light.light_color = RuinsRegister.HOT_WHITE
	light.light_energy = 0.0
	light.shadow_enabled = false
	add_child(light)
	_sparks.append({"emitter": e, "light": light, "wait": _spark_rng.randf_range(0.2, 2.5), "flash": 0.0})


func _step_sparks(delta: float) -> void:
	for s in _sparks:
		s["wait"] -= delta
		if s["wait"] <= 0.0:
			s["wait"] = _spark_rng.randf_range(0.5, 3.6)
			s["flash"] = 1.0
			(s["emitter"] as GPUParticles3D).restart()
		s["flash"] = maxf(float(s["flash"]) - delta * 7.0, 0.0)
		(s["light"] as OmniLight3D).light_energy = 3.5 * float(s["flash"]) * ArenaArt.light_level


func _follow_camera() -> void:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null:
		return
	var at := camera.global_position
	if _rain != null:
		_rain.global_position = at + Vector3(0, 14, 0)
	if _motes != null:
		_motes.global_position = at
	if _glyphs != null:
		_glyphs.global_position = at + Vector3(0, 12, 0)


## The daemons' code rain (the arena's driver's nearest daemons) on the walls.
func _feed_rain() -> void:
	if _driver == null or not is_instance_valid(_driver):
		_driver = null
		for d in get_tree().get_nodes_in_group(&"code_rain_driver"):
			_driver = d
			break
		if _driver == null:
			return
	var uploads: int = _driver.upload_count()
	if uploads == _driver_uploads:
		return
	_driver_uploads = uploads
	var body: ShaderMaterial = materials()["body"]
	body.set_shader_parameter("enemies", _driver.slots())
	body.set_shader_parameter("enemy_count", _driver.slot_count() if _driver.is_enabled() else 0)


# --- For the tests. ---

## What it is made of: triangles, draw calls, collision boxes, lamps, emitters, how long its build took (ms).
func stats() -> Dictionary:
	var emitters := 0
	for child in get_children():
		if child is GPUParticles3D:
			emitters += 1
	return {"triangles": _built.get("triangles", 0), "draw_calls": int(_built.get("surfaces", 0)) + emitters + 1, "boxes": _built.get("shapes", []).size(), "lamps": _lamps.size(), "emitters": emitters, "sparks": _sparks.size(), "ms": _built.get("ms", 0), "pylons": _built.get("pylons", 0)}


## Every material it draws with: the four shared ones.
func shader_materials() -> Array:
	return materials().values()
