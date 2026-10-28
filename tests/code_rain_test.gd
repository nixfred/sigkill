extends SceneTree
## Headless code rain test for SIGKILL. scripts/check.sh runs it, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/code_rain_test.gd
##
## Checks the shader and tuning resource load and validate, then drives the real main scene:
## every greybox block but the floor carries the rain shader and receives the tuning and the
## enemy slots; with no enemy the intensity is the tuned minimum; at an enemy it is the
## maximum, at the falloff radius nothing, and it never rises with distance; the rain fades
## in and out at the tuned rates with no overshoot and converges exactly; a derezzed dummy
## stops counting and a respawned one counts again; more enemies than the cap stay bounded
## and the nearest to the player win; a settled arena uploads nothing.
## Read-only: nothing outside this process is touched, and the headless renderer draws
## nothing. The shader's own pixels cannot be read back headless; the driver's intensity_at()
## mirrors the shader's proximity() and this test holds the CPU side to the same numbers,
## and _hash3() below mirrors the shader's integer glyph hash to show its spread does not
## depend on the size of its inputs.

const Palette = preload("res://scripts/palette.gd")
const Dummy = preload("res://scripts/target_dummy.gd")
const Driver = preload("res://scripts/code_rain_driver.gd")
const MAIN_SCENE := "res://scenes/main.tscn"
const DUMMY_SCENE := "res://scenes/target_dummy.tscn"
const TUNING_SCRIPT := "res://scripts/code_rain_tuning.gd"
const TUNING_PATH := "res://resources/code_rain.tres"
const RAIN_SHADER := "res://shaders/code_rain.gdshader"
const EDGE_SHADER := "res://shaders/neon_edge.gdshader"
const EDGE_UNIFORMS := ["face_color", "edge_color", "edge_width", "edge_energy", "hex_prism", "half_extents"]
const RAIN_UNIFORMS := ["enemies", "enemy_count", "falloff_radius", "min_intensity", "max_intensity", "column_density", "glyph_size", "fall_speed_min", "fall_speed_max", "tail_length", "flicker_rate", "rain_energy", "head_color", "tail_color"]
const GUARD := 1200  # hard stop for every wait loop
const EPS := 0.0001
const SAMPLE_STEP := 0.25  # metres between distance samples
const RING_COUNT := 12  # extra dummies around the player for the cap check
const RING_START := 2.0  # metres from the player to the first ring dummy
const RING_STEP := 0.3
const WALL_TOUCH_MIN := 0.98  # share of the maximum a wall touched by an enemy must show
const BIT_ON := 0.45  # the shader's threshold for a lit glyph bit
const TICK_WRAP := 1024  # the shader wraps its flicker tick here
const HASH_CELLS := 60  # columns and rows sampled each side of the origin
const HASH_SPREAD_TOLERANCE := 0.03
const MASK32 := 0xFFFFFFFF

var _fails := 0
var _frame := 0
var _main: Node
var _player
var _rain
var _t


func _initialize() -> void:
	_run()


func _run() -> void:
	_static_checks()
	# _initialize runs before the tree is live, so nodes added here would not be ready yet.
	await physics_frame
	await _bare_driver_checks()
	_main = load(MAIN_SCENE).instantiate()
	root.add_child(_main)
	current_scene = _main
	_player = _main.get_node("Player")
	_rain = _main.get_node("Arena/CodeRain")
	_t = _rain.active_tuning()
	await _wiring_checks()
	await _fade_in_checks()
	await _distance_checks()
	await _settled_checks()
	await _rebuild_checks()
	await _derezz_checks()
	await _respawn_checks()
	await _cap_checks()
	print("CODE RAIN RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	# Stop any cannon sound and give the audio thread a moment before quitting, as the
	# other tests do, so nothing is reported leaked at exit.
	for sfx in _main.find_children("*", "AudioStreamPlayer", true, false):
		(sfx as AudioStreamPlayer).stop()
	OS.delay_msec(300)
	await physics_frame
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


## One physics frame with no player input.
func _step() -> void:
	_player.drive_input(Vector2.ZERO, false, false, false)
	await physics_frame
	_frame += 1


func _frames_for(seconds: float) -> int:
	return ceili(seconds * Engine.physics_ticks_per_second)


func _uniform_names(shader: Shader) -> PackedStringArray:
	var names := PackedStringArray()
	for u in shader.get_shader_uniform_list():
		names.append(u["name"])
	return names


func _missing_tres_keys(script_path: String, tres_path: String) -> PackedStringArray:
	var script: Script = load(script_path)
	var text := FileAccess.get_file_as_string(tres_path)
	var missing := PackedStringArray()
	for prop in script.get_script_property_list():
		var usage: int = prop["usage"]
		if usage & PROPERTY_USAGE_STORAGE and usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var field: String = prop["name"]
			if not text.contains("\n" + field + " = "):
				missing.append(field)
	return missing


## Mirror of pcg() in shaders/code_rain.gdshader, on 32-bit unsigned arithmetic.
static func _pcg(v: int) -> int:
	v &= MASK32
	var state := (v * 747796405 + 2891336453) & MASK32
	var word := ((((state >> ((state >> 28) + 4)) ^ state) & MASK32) * 277803737) & MASK32
	return ((word >> 22) ^ word) & MASK32


## Mirror of hash3() in shaders/code_rain.gdshader: three integers to 0 to 1.
static func _hash3(a: int, b: int, c: int) -> float:
	var h := _pcg((a & MASK32) + _pcg((b & MASK32) + _pcg(c & MASK32)))
	return float(h >> 8) / 16777216.0


## Share of lit glyph bits over a block of cells at one flicker tick, as the shader rolls them.
static func _lit_share(tick: int) -> float:
	var lit := 0
	var total := 0
	for column in range(-HASH_CELLS, HASH_CELLS):
		for row in range(-HASH_CELLS, HASH_CELLS):
			for bit in 12:  # the 2 mirrored columns by 6 rows of one glyph
				total += 1
				if _hash3(column, row, (bit % 2) + 8 * (1 + bit / 2) + 64 * tick) >= BIT_ON:
					lit += 1
	return float(lit) / float(total)


func _hash_checks() -> void:
	var first := _lit_share(0)
	var last := _lit_share(TICK_WRAP - 1)
	var middle := _lit_share(TICK_WRAP / 2)
	var expected := 1.0 - BIT_ON
	var streams := 0
	for column in range(-1000, 1000):
		if _hash3(column, 1, 0) <= 0.6:
			streams += 1
	var stream_share := float(streams) / 2000.0
	print("CODE RAIN hash: lit glyph bits %.4f at tick 0, %.4f at tick %d, %.4f at the last tick %d (threshold leaves %.2f); %.4f of 2000 columns carry a stream at density 0.6" % [first, middle, TICK_WRAP / 2, last, TICK_WRAP - 1, expected, stream_share])
	_check("the glyph hash keeps its spread at the last flicker tick as at the first", absf(first - expected) < HASH_SPREAD_TOLERANCE and absf(middle - expected) < HASH_SPREAD_TOLERANCE and absf(last - expected) < HASH_SPREAD_TOLERANCE)
	_check("the column hash carries about the tuned share of streams", absf(stream_share - 0.6) < HASH_SPREAD_TOLERANCE)
	_check("the hash tells neighbouring cells apart", _hash3(3, 4, 5) != _hash3(4, 3, 5) and _hash3(3, 4, 5) != _hash3(3, 4, 6) and _hash3(-3, 4, 5) != _hash3(3, 4, 5))


func _static_checks() -> void:
	_hash_checks()
	var rain_shader: Shader = load(RAIN_SHADER)
	var rain_names := _uniform_names(rain_shader)
	var missing := PackedStringArray()
	for name in EDGE_UNIFORMS + RAIN_UNIFORMS:
		if not rain_names.has(name):
			missing.append(name)
	_check("the code rain shader loads and lists every edge and rain uniform", rain_shader != null and missing.is_empty(), "missing: " + ", ".join(missing))
	var edge_names := _uniform_names(load(EDGE_SHADER))
	_check("the neon edge shader still lists exactly its six uniforms", Array(edge_names) == EDGE_UNIFORMS, ", ".join(edge_names))
	var t: Resource = load(TUNING_PATH)
	_check("shipped code rain tuning passes validation", t.problems().is_empty(), ", ".join(t.problems()))
	var tres_missing := _missing_tres_keys(TUNING_SCRIPT, TUNING_PATH)
	_check("code_rain.tres lists every tunable of code_rain_tuning.gd", tres_missing.is_empty(), "missing: " + ", ".join(tres_missing))
	_check("the shipped colours are the palette's Matrix register", t.head_color == Palette.MATRIX_HEAD and t.tail_color == Palette.MATRIX_GREEN)
	_check("the tuning's enemy cap matches the shader's array of 8", t.MAX_ENEMIES == 8 and t.max_enemies_sampled <= 8)
	var bad: Resource = t.duplicate()
	bad.falloff_radius = 0.0
	bad.min_intensity = 0.9
	bad.max_intensity = 0.5
	bad.max_enemies_sampled = 9
	bad.fade_out_rate = 0.0
	bad.column_density = 1.5
	bad.fall_speed_min = 20.0
	bad.tail_length = 0.0
	var problems: PackedStringArray = bad.problems()
	var text := ", ".join(problems)
	_check("validation rejects a zero radius, an inverted range, a cap of 9, a zero fade, a density above 1, inverted speeds and no tail", problems.size() == 7 and text.contains("falloff_radius") and text.contains("max_enemies_sampled") and text.contains("fade_") and text.contains("column_density") and text.contains("fall_speed_min") and text.contains("tail_length"), text)
	var inf: Resource = t.duplicate()
	inf.glyph_size = INF
	_check("validation rejects an infinite glyph size", not inf.problems().is_empty(), ", ".join(inf.problems()))


## A driver alone, then one with a cap of 2 among three dummies and no viewer.
func _bare_driver_checks() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var alone = Driver.new()
	holder.add_child(alone)
	await physics_frame
	_check("a driver with no enemies and no blocks samples nothing and shows the minimum", alone.slot_count() == 0 and alone.surface_count() == 0 and is_equal_approx(alone.intensity_at(Vector3.ZERO), alone.active_tuning().min_intensity))
	var bad: Resource = load(TUNING_PATH).duplicate()
	bad.max_enemies_sampled = 0
	var fallback = Driver.new()
	fallback.tuning = bad
	holder.add_child(fallback)
	await physics_frame
	_check("a driver given bad tuning falls back to safe defaults", fallback.active_tuning() != bad and fallback.active_tuning().problems().is_empty())
	alone.queue_free()
	fallback.queue_free()
	var capped: Resource = load(TUNING_PATH).duplicate()
	capped.max_enemies_sampled = 2
	var two = Driver.new()
	two.tuning = capped
	holder.add_child(two)
	var spots := [Vector3(9.0, 0.0, 0.0), Vector3(2.0, 0.0, 0.0), Vector3(0.0, 0.0, 5.0)]
	for spot in spots:
		var dummy = load(DUMMY_SCENE).instantiate()
		dummy.position = spot
		holder.add_child(dummy)
	for _i in 2:
		await physics_frame
	var chosen: PackedVector4Array = two.slots()
	var xs := [chosen[0].x, chosen[1].x]
	xs.sort()
	_check("with a cap of 2 and no viewer, the two dummies nearest the origin are sampled", two.slot_count() == 2 and xs == [0.0, 2.0], "slots %d, x %s" % [two.slot_count(), xs])
	holder.queue_free()
	await physics_frame
	await physics_frame


func _wiring_checks() -> void:
	await _step()
	_check("main hands the driver the player as its viewer", _rain.viewer == _player)
	var blocks := _main.find_children("*", "StaticBody3D", true, false)
	var rain_blocks := 0
	var floor_blocks := 0
	var wrong := PackedStringArray()
	for block in blocks:
		if not block.has_method("surface_material"):
			continue
		var mat: ShaderMaterial = block.surface_material()
		var shader_file: String = mat.shader.resource_path.get_file()
		if block.kind == Palette.Surface.FLOOR:
			floor_blocks += 1
			if shader_file != "floor_grid.gdshader" or block.is_in_group(Driver.SURFACE_GROUP):
				wrong.append(block.name)
		else:
			rain_blocks += 1
			if shader_file != "code_rain.gdshader" or not block.is_in_group(Driver.SURFACE_GROUP):
				wrong.append(block.name)
	_check("every block but the floor carries the code rain shader and is registered", rain_blocks > 0 and floor_blocks == 1 and wrong.is_empty() and _rain.surface_count() == rain_blocks, "%d rain blocks, %d floors, driver has %d, wrong: %s" % [rain_blocks, floor_blocks, _rain.surface_count(), ", ".join(wrong)])
	var dummies := get_nodes_in_group(&"targets")
	# Since A2 a dummy is drawn by its daemon art under its Body, whose hex is its volume only; since
	# A2b the art's parts are MultiMeshes drawn with their material override.
	var dummy_shaders := {}
	var drawn_volumes := 0
	for dummy in dummies:
		var body := dummy.get_node("Body") as MeshInstance3D
		drawn_volumes += 1 if body.layers != 0 else 0
		for part in body.find_children("*", "GeometryInstance3D", true, false):
			var over := (part as GeometryInstance3D).material_override as ShaderMaterial
			if over != null:
				dummy_shaders[over.shader.resource_path.get_file()] = true
			if part is MeshInstance3D:
				var m: Mesh = (part as MeshInstance3D).mesh
				for i in m.get_surface_count():
					var mat := m.surface_get_material(i) as ShaderMaterial
					if mat != null:
						dummy_shaders[mat.shader.resource_path.get_file()] = true
	_check("the four dummies are drawn by their daemon art (A2: the shared obsidian and core shaders), never by the code rain shader, their hex volume by no camera", dummies.size() == 4 and _rain.target_count() == 4 and dummy_shaders.has("daemon_shell.gdshader") and dummy_shaders.has("daemon_core.gdshader") and not dummy_shaders.has("code_rain.gdshader") and drawn_volumes == 0, str(dummy_shaders.keys()))
	var off := PackedStringArray()
	for block in blocks:
		if not block.has_method("surface_material") or block.kind == Palette.Surface.FLOOR:
			continue
		var mat: ShaderMaterial = block.surface_material()
		for field in Driver.TUNING_UNIFORMS:
			if mat.get_shader_parameter(field) != _t.get(field):
				off.append("%s.%s" % [block.name, field])
	_check("every surface material carries every tuning value", off.is_empty(), ", ".join(off))


## A block rebuilt at runtime gets a new material; the driver must find it and feed it.
func _rebuild_checks() -> void:
	var wall = _main.get_node("Arena/WallN")
	var old_material: ShaderMaterial = wall.surface_material()
	var old_count: int = _rain.surface_count()
	wall.size = wall.size + Vector3(0.0, 0.5, 0.0)
	await _step()
	var new_material: ShaderMaterial = wall.surface_material()
	_check("a wall resized at runtime gets a fresh material that the driver finds and feeds", new_material != old_material and new_material.get_shader_parameter("falloff_radius") == _t.falloff_radius and new_material.get_shader_parameter("enemy_count") == _rain.slot_count() and new_material.get_shader_parameter("enemies") == _rain.slots() and _rain.surface_count() == old_count, "surfaces %d, enemy_count %s" % [_rain.surface_count(), str(new_material.get_shader_parameter("enemy_count"))])
	wall.size = wall.size - Vector3(0.0, 0.5, 0.0)
	await _step()
	var crate = _main.get_node("Arena/CrateA")
	crate.kind = Palette.Surface.FLOOR
	await _step()
	var dropped: int = _rain.surface_count()
	var grouped_as_floor: bool = crate.is_in_group(Driver.SURFACE_GROUP)
	crate.kind = Palette.Surface.CRATE
	await _step()
	_check("a block turned into a floor leaves the rain group and the driver, and comes back when turned back", dropped == old_count - 1 and not grouped_as_floor and crate.is_in_group(Driver.SURFACE_GROUP) and _rain.surface_count() == old_count and crate.surface_material().get_shader_parameter("enemy_count") == _rain.slot_count(), "%d while a floor (in the group: %s), %d after" % [dropped, grouped_as_floor, _rain.surface_count()])


func _fade_in_checks() -> void:
	# The scene is one tick old, so DummyA's weight has taken one step already.
	var a = _main.get_node("Arena/Targets/DummyA")
	var rate: float = _t.fade_in_rate
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var expected_ticks := ceili(1.0 / (rate * dt))
	var worst := 0.0
	var highest := 0.0
	var monotonic := true
	var previous: float = _rain.weight_of(a)
	var converged_at := -1
	for k in range(1, expected_ticks + 10):
		await _step()
		var w: float = _rain.weight_of(a)
		worst = maxf(worst, absf(w - minf(float(k + 1) * rate * dt, 1.0)))
		highest = maxf(highest, w)
		if w < previous:
			monotonic = false
		previous = w
		if converged_at < 0 and w == 1.0:
			converged_at = k + 1
	print("CODE RAIN fade in: weight exactly 1.0 after %d ticks (expected %d at %.1f per second), worst gap from the line %.6f, highest %.6f" % [converged_at, expected_ticks, rate, worst, highest])
	# Sixty steps of a sixtieth can land a hair short of the target, so the exact value may
	# arrive one tick late. The slope itself is held to EPS against the line.
	_check("an enemy's rain fades in along the tuned rate, converges exactly and never overshoots", absi(converged_at - expected_ticks) <= 1 and worst < EPS and highest == 1.0 and monotonic)
	_check("all four dummies are sampled once their rain is in", _rain.slot_count() == 4)
	var wall: ShaderMaterial = _main.get_node("Arena/WallN").surface_material()
	_check("the wall materials hold the driver's slots and count", wall.get_shader_parameter("enemy_count") == 4 and wall.get_shader_parameter("enemies") == _rain.slots())


func _distance_checks() -> void:
	var a = _main.get_node("Arena/Targets/DummyA")
	var centre: Vector3 = a.threat_point()
	var radius: float = _t.falloff_radius
	var away := Vector3.RIGHT  # the other dummies are more than two radii from this line
	_check("the intensity at an enemy is the tuned maximum", is_equal_approx(_rain.intensity_at(centre), _t.max_intensity), "%.4f" % _rain.intensity_at(centre))
	_check("the intensity at the falloff radius and beyond is the tuned minimum", is_equal_approx(_rain.intensity_at(centre + away * radius), _t.min_intensity) and is_equal_approx(_rain.intensity_at(centre + away * (radius + 1.0)), _t.min_intensity))
	var half: float = _rain.intensity_at(centre + away * (radius * 0.5))
	_check("halfway out the intensity is halfway, the smoothstep the shader uses", is_equal_approx(half, lerpf(_t.min_intensity, _t.max_intensity, 0.5)), "%.4f" % half)
	var previous: float = _rain.intensity_at(centre)
	var rises := 0
	var flat_inside := 0
	var d := SAMPLE_STEP
	while d <= radius + 1.0 + EPS:
		var value: float = _rain.intensity_at(centre + away * d)
		if value > previous + EPS:
			rises += 1
		if d < radius - EPS and value >= previous - EPS:
			flat_inside += 1
		previous = value
		d += SAMPLE_STEP
	_check("the intensity never rises with distance and falls strictly inside the radius", rises == 0 and flat_inside == 0, "%d rises, %d flat steps inside" % [rises, flat_inside])
	# An enemy against the north wall: the wall shows nearly the whole maximum where it
	# touches, the exact maximum at the enemy's own centre half a body away.
	var touch = load(DUMMY_SCENE).instantiate()
	var hex: CylinderMesh = touch.get_node("Body").mesh
	touch.position = Vector3(6.0, 0.0, -20.0 + hex.top_radius)  # body against the wall's inner face
	_main.get_node("Arena/Targets").add_child(touch)
	for _i in _frames_for(1.0 / _t.fade_in_rate) + 2:
		await _step()
	var wall_point := Vector3(6.0, hex.height * 0.5, -20.0)
	var at_wall: float = _rain.intensity_at(wall_point)
	print("CODE RAIN wall: an enemy against the north wall gives the wall %.4f of the maximum %.2f where it touches" % [at_wall, _t.max_intensity])
	_check("a wall touched by an enemy shows nearly the maximum", at_wall >= WALL_TOUCH_MIN * _t.max_intensity and is_equal_approx(_rain.intensity_at(touch.threat_point()), _t.max_intensity))
	touch.queue_free()
	await _step()
	await _step()
	_check("a removed enemy leaves the sampling", _rain.target_count() == 4 and _rain.slot_count() == 4)


func _settled_checks() -> void:
	var uploads_before: int = _rain.upload_count()
	var nodes_before := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var objects_before := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for _i in 60:
		await _step()
	print("CODE RAIN settled: %d uploads over 60 ticks, nodes %d then %d, objects %d then %d" % [_rain.upload_count() - uploads_before, nodes_before, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), objects_before, int(Performance.get_monitor(Performance.OBJECT_COUNT))])
	_check("a settled arena uploads nothing and makes no objects", _rain.upload_count() == uploads_before and int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) == nodes_before and int(Performance.get_monitor(Performance.OBJECT_COUNT)) == objects_before)


func _derezz_checks() -> void:
	var a = _main.get_node("Arena/Targets/DummyA")
	var centre: Vector3 = a.threat_point()
	var rate: float = _t.fade_out_rate
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var expected_ticks := ceili(1.0 / (rate * dt))
	a.hit(a.max_health, centre, Vector3.RIGHT)
	_check("the killed dummy is derezzing and no longer alive to the rain", a.state == Dummy.State.DEREZZING and not a.is_alive())
	var worst := 0.0
	var lowest := 1.0
	var monotonic := true
	var previous := 1.0
	var gone_at := -1
	var slots_at_gone := -1
	for k in range(1, expected_ticks + 10):
		await _step()
		var w: float = _rain.weight_of(a)
		worst = maxf(worst, absf(w - maxf(1.0 - float(k) * rate * dt, 0.0)))
		lowest = minf(lowest, w)
		if w > previous:
			monotonic = false
		previous = w
		if gone_at < 0 and w == 0.0:
			gone_at = k
			slots_at_gone = _rain.slot_count()
		if k == 1:
			_check("one tick after the kill its rain is already fading", w < 1.0 and is_equal_approx(_rain.intensity_at(centre), lerpf(_t.min_intensity, _t.max_intensity, w)), "weight %.4f intensity %.4f" % [w, _rain.intensity_at(centre)])
	print("CODE RAIN fade out: weight exactly 0.0 after %d ticks (expected %d at %.1f per second), worst gap from the line %.6f, lowest %.6f, %d slots left" % [gone_at, expected_ticks, rate, worst, lowest, slots_at_gone])
	_check("a derezzed dummy's rain fades out along the tuned rate, converges exactly and never undershoots", absi(gone_at - expected_ticks) <= 1 and worst < EPS and lowest == 0.0 and monotonic)
	_check("once its rain is gone the dummy leaves the sampling and the walls", slots_at_gone == 3 and _rain.slot_count() == 3 and _main.get_node("Arena/WallN").surface_material().get_shader_parameter("enemy_count") == 3)
	_check("the walls around it show the minimum again", is_equal_approx(_rain.intensity_at(centre), _t.min_intensity))


func _respawn_checks() -> void:
	var a = _main.get_node("Arena/Targets/DummyA")
	var alive_at := -1
	for _i in GUARD:
		if a.state == Dummy.State.ALIVE:
			alive_at = _frame
			break
		await _step()
	_check("the dummy respawns", alive_at >= 0)
	# The dummy comes back inside a tick, before or after the driver runs, so the first
	# nonzero weight is the anchor and the line is measured from there.
	var rate: float = _t.fade_in_rate
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var first: float = _rain.weight_of(a)
	for _i in 3:
		if first > 0.0:
			break
		await _step()
		first = _rain.weight_of(a)
	var expected_ticks := ceili((1.0 - first) / (rate * dt))
	var worst := 0.0
	var highest := first
	var back_at := -1
	for k in range(1, expected_ticks + 10):
		await _step()
		var w: float = _rain.weight_of(a)
		worst = maxf(worst, absf(w - minf(first + float(k) * rate * dt, 1.0)))
		highest = maxf(highest, w)
		if back_at < 0 and w == 1.0:
			back_at = k
	print("CODE RAIN respawn: rain back from %.4f to exactly 1.0 after %d ticks (expected %d), worst gap from the line %.6f" % [first, back_at, expected_ticks, worst])
	_check("a respawned dummy's rain fades back in along the tuned rate to exactly full with no overshoot", first > 0.0 and absi(back_at - expected_ticks) <= 1 and worst < EPS and highest == 1.0 and _rain.slot_count() == 4 and is_equal_approx(_rain.intensity_at(a.threat_point()), _t.max_intensity), "full after %d ticks, highest %.4f, slots %d" % [back_at, highest, _rain.slot_count()])


func _cap_checks() -> void:
	var cap: int = _t.max_enemies_sampled
	var origin: Vector3 = _player.global_position
	var ring := []
	for i in RING_COUNT:
		var dummy = load(DUMMY_SCENE).instantiate()
		var angle := TAU * float(i) / float(RING_COUNT)
		var r := RING_START + RING_STEP * float(i)
		dummy.position = Vector3(origin.x + cos(angle) * r, 0.0, origin.z + sin(angle) * r)
		_main.get_node("Arena/Targets").add_child(dummy)
		ring.append(dummy)
	for _i in _frames_for(1.0 / _t.fade_in_rate) + 2:
		await _step()
	var targets: int = _rain.target_count()
	var slots: int = _rain.slot_count()
	# The sampled ones must be the nearest to the player: the first `cap` ring dummies.
	var sampled := PackedVector3Array()
	var uploaded: PackedVector4Array = _rain.slots()
	for k in slots:
		sampled.append(Vector3(uploaded[k].x, uploaded[k].y, uploaded[k].z))
	var nearest_missing := 0
	for i in mini(cap, RING_COUNT):
		if not sampled.has(ring[i].threat_point()):
			nearest_missing += 1
	var farthest_ring_distance := 0.0
	for p in sampled:
		farthest_ring_distance = maxf(farthest_ring_distance, origin.distance_to(p))
	var worst_point := 0.0
	for p in sampled:
		worst_point = maxf(worst_point, _rain.intensity_at(p))
	print("CODE RAIN cap: %d targets alive, %d sampled (cap %d), the sampled ones reach %.2f m from the player, highest intensity at a sampled enemy %.4f" % [targets, slots, cap, farthest_ring_distance, worst_point])
	_check("more enemies than the cap stay bounded at the cap, nearest to the player first", targets == 4 + RING_COUNT and slots == cap and nearest_missing == 0 and _rain.slots().size() == 8)
	_check("with many enemies the intensity stays within the tuned range", worst_point <= _t.max_intensity + EPS and _rain.intensity_at(origin + Vector3(0.0, 40.0, 0.0)) >= _t.min_intensity - EPS)
	for dummy in ring:
		dummy.queue_free()
	await _step()
	await _step()
	_check("the extra enemies leave cleanly", _rain.target_count() == 4 and _rain.slot_count() == 4)
