extends SceneTree
## Headless arena art test for SIGKILL (A3). scripts/check.sh runs it, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/arena_art_test.gd
##
## The arena's look (A3), visual only. The sources: the arena scene holds the dressing and the
## skyline, a sky and a depth fog, and its gameplay nodes (the blocks, the spawn points, the targets)
## are byte for byte as before A3, as are the scenes and script that make collision; the art code
## touches nothing outside the game, loads nothing at run time and builds nothing while it is drawn;
## the sky never runs on the clock. In the real arena: every block but the floor dressed, the signs,
## the holograms, the skyline built, inside their triangle and draw-call budgets; nothing under them
## can collide, and the arena's collision (every body, shape and spawn point) and the sight lines
## from every spawn point to every daemon are byte for byte what they were before A3; whatever a
## player can walk into stands within a hand of a block, and nothing hangs over a top a player stands
## on lower than a jump reaches; every surface wears one of the palette's shared arena materials; over
## two seconds nothing is rebuilt while the ring and the drift turn; the environment's sky and fog are
## the palette's; and a reload of the arena builds nothing, taking the kept meshes.
## Deterministic: frames counted, only counts and outcomes printed.

const Link = preload("res://scripts/guide/guide_link.gd")
const MainScene = preload("res://scenes/main.tscn")
const Palette = preload("res://scripts/palette.gd")
const Controls = preload("res://scripts/controls.gd")
const SignFont = preload("res://scripts/arena/arena_font.gd")
const ART_SCRIPTS := ["res://scripts/arena/arena_art.gd", "res://scripts/arena/arena_skyline.gd", "res://scripts/arena/arena_font.gd", "res://scripts/art/shape_kit.gd"]
const ARENA_SHADERS := ["arena_panel", "arena_light", "arena_screen", "arena_holo", "arena_tower", "arena_sky"]
## The whole arena's budget: its blocks, its dressing and its skyline together.
const WHOLE_TRIANGLES := 42000
const WHOLE_DRAW_CALLS := 68
## The sha256 of the arena scene's gameplay nodes (every block, the spawn points, the targets) as
## written at b38a900, and of the files that make collision.
const SCENE_SHA := "903b485df4c4c03eeb68fe176e28017cd915c16a6b3ab3e5d75da8018f203002"
const FILE_SHA := {"res://scripts/grey_block.gd": "93bedf0ffdcf6c26e1dc534a3ca76a251ecd9d8d257975ef49dc41d8c76039cd", "res://scenes/grey_block.tscn": "2a969ec9ab4802ac66865cbf9a908de8a746401e123bad133d220e3068d59c4b", "res://scenes/target_dummy.tscn": "ec147ba79534222d950b3b491e54dce9cdbb5fbf8ab0991f0caf85125464de0f", "res://scenes/player.tscn": "5347fabf2d15f713ecca32ee74cbe585852cb9b4678c958f9fc453d3f2e7c271"}
## Heights for the clearance checks, in metres: under this a decoration is a tray or a kick plate a
## foot passes over; above this none can be reached from the floor at the top of a jump (1.8 m tall,
## 1.22 m jump).
const FOOT_M := 0.12
const REACH_M := 3.05
## The arena's collision as it was before A3 (b38a900): every body, every shape, every spawn point.
const COLLISION_TEXT := """Floor | StaticBody3D layer 1 mask 0
WallN | StaticBody3D layer 1 mask 0
WallS | StaticBody3D layer 1 mask 0
WallE | StaticBody3D layer 1 mask 0
WallW | StaticBody3D layer 1 mask 0
RoomFrontL | StaticBody3D layer 1 mask 0
RoomFrontR | StaticBody3D layer 1 mask 0
RoomSideW | StaticBody3D layer 1 mask 0
RoomSideE | StaticBody3D layer 1 mask 0
DoorPostL | StaticBody3D layer 1 mask 0
DoorPostR | StaticBody3D layer 1 mask 0
LowWall | StaticBody3D layer 1 mask 0
CoverL1 | StaticBody3D layer 1 mask 0
CoverL2 | StaticBody3D layer 1 mask 0
PillarA | StaticBody3D layer 1 mask 0
PillarB | StaticBody3D layer 1 mask 0
CrateA | StaticBody3D layer 1 mask 0
CrateB | StaticBody3D layer 1 mask 0
Platform | StaticBody3D layer 1 mask 0
Targets/DummyA | StaticBody3D layer 4 mask 0
Targets/DummyB | StaticBody3D layer 4 mask 0
Targets/DummyC | StaticBody3D layer 4 mask 0
Targets/DummyD | StaticBody3D layer 4 mask 0
Floor/Shape | box (40.500, 0.500, 40.500) | at (0.000, -0.250, 0.000) x (1.000, 0.000, 0.000) y (0.000, 1.000, 0.000) z (0.000, 0.000, 1.000) | enabled
WallN/Shape | box (41.000, 4.000, 0.500) | at (0.000, 2.000, -20.250) x (1.000, 0.000, 0.000) y (0.000, 1.000, 0.000) z (0.000, 0.000, 1.000) | enabled
WallS/Shape | box (41.000, 4.000, 0.500) | at (0.000, 2.000, 20.250) x (1.000, 0.000, 0.000) y (0.000, 1.000, 0.000) z (0.000, 0.000, 1.000) | enabled
WallE/Shape | box (0.500, 4.000, 41.000) | at (20.250, 2.000, 0.000) x (1.000, 0.000, 0.000) y (0.000, 1.000, 0.000) z (0.000, 0.000, 1.000) | enabled
WallW/Shape | box (0.500, 4.000, 41.000) | at (-20.250, 2.000, 0.000) x (1.000, 0.000, 0.000) y (0.000, 1.000, 0.000) z (0.000, 0.000, 1.000) | enabled
RoomFrontL/Shape | box (6.500, 3.500, 0.400) | at (-4.750, 1.750, -8.000) x (1.000, 0.000, 0.000) y (0.000, 1.000, 0.000) z (0.000, 0.000, 1.000) | enabled
RoomFrontR/Shape | box (6.500, 3.500, 0.400) | at (4.750, 1.750, -8.000) x (1.000, 0.000, 0.000) y (0.000, 1.000, 0.000) z (0.000, 0.000, 1.000) | enabled
RoomSideW/Shape | box (0.400, 3.500, 12.000) | at (-8.000, 1.750, -14.000) x (1.000, 0.000, 0.000) y (0.000, 1.000, 0.000) z (0.000, 0.000, 1.000) | enabled
RoomSideE/Shape | box (0.400, 3.500, 12.000) | at (8.000, 1.750, -14.000) x (1.000, 0.000, 0.000) y (0.000, 1.000, 0.000) z (0.000, 0.000, 1.000) | enabled
DoorPostL/Shape | box (0.300, 3.500, 0.500) | at (-1.500, 1.750, -8.000) x (1.000, 0.000, 0.000) y (0.000, 1.000, 0.000) z (0.000, 0.000, 1.000) | enabled
DoorPostR/Shape | box (0.300, 3.500, 0.500) | at (1.500, 1.750, -8.000) x (1.000, 0.000, 0.000) y (0.000, 1.000, 0.000) z (0.000, 0.000, 1.000) | enabled
LowWall/Shape | box (6.000, 1.200, 0.400) | at (0.000, 0.600, 2.000) x (1.000, 0.000, 0.000) y (0.000, 1.000, 0.000) z (0.000, 0.000, 1.000) | enabled
CoverL1/Shape | box (6.000, 3.000, 0.400) | at (-12.000, 1.500, 2.000) x (1.000, 0.000, 0.000) y (0.000, 1.000, 0.000) z (0.000, 0.000, 1.000) | enabled
CoverL2/Shape | box (0.400, 3.000, 6.400) | at (-15.000, 1.500, 5.000) x (1.000, 0.000, 0.000) y (0.000, 1.000, 0.000) z (0.000, 0.000, 1.000) | enabled
PillarA/Shape | box (1.500, 4.000, 1.500) | at (12.000, 2.000, 2.000) x (1.000, 0.000, 0.000) y (0.000, 1.000, 0.000) z (0.000, 0.000, 1.000) | enabled
PillarB/Shape | box (1.500, 4.000, 1.500) | at (12.000, 2.000, 8.000) x (1.000, 0.000, 0.000) y (0.000, 1.000, 0.000) z (0.000, 0.000, 1.000) | enabled
CrateA/Shape | box (1.500, 1.500, 1.500) | at (6.000, 0.750, 10.000) x (1.000, 0.000, 0.000) y (0.000, 1.000, 0.000) z (0.000, 0.000, 1.000) | enabled
CrateB/Shape | box (1.000, 1.000, 1.000) | at (7.400, 0.500, 10.800) x (1.000, 0.000, 0.000) y (0.000, 1.000, 0.000) z (0.000, 0.000, 1.000) | enabled
Platform/Shape | box (4.000, 1.000, 4.000) | at (-8.000, 0.500, 12.000) x (1.000, 0.000, 0.000) y (0.000, 1.000, 0.000) z (0.000, 0.000, 1.000) | enabled
Targets/DummyA/Shape | cylinder r 0.550 h 1.800 | at (0.000, 0.900, -15.000) x (1.000, 0.000, 0.000) y (0.000, 1.000, 0.000) z (0.000, 0.000, 1.000) | enabled
Targets/DummyB/Shape | cylinder r 0.550 h 1.800 | at (-17.500, 0.900, 5.000) x (1.000, 0.000, 0.000) y (0.000, 1.000, 0.000) z (0.000, 0.000, 1.000) | enabled
Targets/DummyC/Shape | cylinder r 0.550 h 1.800 | at (12.000, 0.900, 5.000) x (1.000, 0.000, 0.000) y (0.000, 1.000, 0.000) z (0.000, 0.000, 1.000) | enabled
Targets/DummyD/Shape | cylinder r 0.550 h 1.800 | at (-8.000, 1.900, 12.000) x (1.000, 0.000, 0.000) y (0.000, 1.000, 0.000) z (0.000, 0.000, 1.000) | enabled
spawn S1 at (0.000, 0.950, 10.000)
spawn S2 at (-15.000, 0.950, 15.000)
spawn S3 at (15.000, 0.950, 15.000)
spawn S4 at (15.000, 0.950, -15.000)
spawn S5 at (-15.000, 0.950, -15.000)"""
## The sight lines as they were before A3 (b38a900): from each spawn point at eye height to each
## daemon's middle, what the ray hits first.
const SIGHT_TEXT := """S1 > DummyA: DummyA at (0.000, 0.916, -14.450)
S1 > DummyB: CoverL2 at (-14.800, 1.016, 5.771)
S1 > DummyC: DummyC at (11.492, 0.932, 5.212)
S1 > DummyD: DummyD at (-7.466, 1.883, 11.867)
S2 > DummyA: RoomFrontL at (-3.600, 1.080, -7.800)
S2 > DummyB: DummyB at (-17.367, 0.940, 5.534)
S2 > DummyC: DummyD at (-8.238, 1.462, 12.496)
S2 > DummyD: DummyD at (-8.506, 1.882, 12.217)
S3 > DummyA: PillarB at (11.875, 1.494, 8.750)
S3 > DummyB: Player at (0.043, 1.305, 10.398)
S3 > DummyC: PillarB at (12.750, 1.087, 7.500)
S3 > DummyD: DummyD at (-7.455, 1.894, 12.071)
S4 > DummyA: RoomSideE at (8.200, 1.310, -15.000)
S4 > DummyB: RoomSideE at (8.200, 1.493, -10.815)
S4 > DummyC: PillarA at (12.562, 1.041, 1.250)
S4 > DummyD: DummyD at (-7.643, 1.896, 11.581)
S5 > DummyA: RoomSideW at (-8.200, 1.310, -15.000)
S5 > DummyB: DummyB at (-17.432, 0.920, 4.454)
S5 > DummyC: RoomSideW at (-8.200, 1.461, -9.963)
S5 > DummyD: CoverL1 at (-10.644, 1.806, 1.800)"""

var _fails := 0
var _checks := 0
var _tmp := ""
var _arenas: Array = []


func _initialize() -> void:
	GameSettings.current().set_value("gameplay", "practice", true)  # these checks predate C27b: the daemons stay the old never-attack dummies
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_tmp = OS.get_temp_dir().path_join("sigkill-arena-art-test-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(_tmp)
	Controls.ensure()
	_source_checks()
	await _arena_checks()
	await _cleanup()
	for name in DirAccess.get_files_at(_tmp):
		DirAccess.remove_absolute(_tmp.path_join(name))
	DirAccess.remove_absolute(_tmp)
	print("ARENA ART: %d checks" % _checks)
	print("ARENA ART RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The sources. ---

func _source_checks() -> void:
	var arena := FileAccess.get_file_as_string("res://scenes/arena.tscn")
	var wired := arena.contains("path=\"res://scripts/arena/arena_art.gd\" id=\"8_art\"") and arena.contains("[node name=\"ArenaArt\" type=\"Node3D\" parent=\".\"]\nscript = ExtResource(\"8_art\")") and arena.contains("path=\"res://scripts/arena/arena_skyline.gd\" id=\"9_skyline\"") and arena.contains("[node name=\"Skyline\" type=\"Node3D\" parent=\".\"]\nscript = ExtResource(\"9_skyline\")")
	var sky := arena.contains("path=\"res://shaders/arena_sky.gdshader\" id=\"7_sky\"") and arena.contains("background_mode = 2") and arena.contains("sky = SubResource(\"Sky_arena\")") and arena.contains("fog_enabled = true\nfog_mode = 1")
	_check("acceptance: the arena scene holds the dressing and the skyline (scripts/arena/), a sky and a depth fog", wired and sky)
	var scene_sha := gameplay_scene_text(arena).sha256_text()
	var changed := PackedStringArray()
	for path in FILE_SHA:
		if FileAccess.get_sha256(path) != FILE_SHA[path]:
			changed.append(path.get_file())
	_check("acceptance: the gameplay geometry is byte for byte as before A3 (b38a900): the arena scene's blocks, spawn points and targets as written, and the grey block's script and scene, the dummy's and the player's scenes", scene_sha == SCENE_SHA and changed.is_empty(), "scene %s; changed: %s" % [scene_sha.left(12), ", ".join(changed)])
	var code := ""
	for path in ART_SCRIPTS:
		code += _code(path)
	var shaders := ""
	for name in ARENA_SHADERS:
		shaders += _shader_code("res://shaders/%s.gdshader" % name)
	var found := PackedStringArray()
	for word in ["OS.", "execute", "create_process", "DirAccess", "FileAccess", "move_to_trash", "shell_open", "Thread", "HTTP", "PacketPeer", "StreamPeer", "Expression", "rpc", "Time.", "ResourceSaver"]:
		if code.contains(word):
			found.append(word)
	if RegEx.create_from_string("(?<!pre)load\\(").search(code) != null:
		found.append("load(")
	_check("acceptance: the art code is cosmetic only: no OS call, no file or folder access, no thread, socket or network, no wall clock, nothing loaded or saved at run time, no RPC", found.is_empty() and code.length() > 20000 and shaders.length() > 8000, ", ".join(found))
	var art := _code("res://scripts/arena/arena_art.gd")
	var skyline := _code("res://scripts/arena/arena_skyline.gd")
	var held := _body(skyline, "_process")
	var rebuilt := PackedStringArray()
	for word in ["SurfaceTool", "commit(", "ArrayMesh", "Mesh.new", ".new(", "add_child", "duplicate", "_build", "Material", "bucket("]:
		if held.contains(word):
			rebuilt.append(word)
	# A4: the dressing's only per-frame code steps the arena's shader clock and the danger lights' glow.
	var art_held := _body(art, "_process") + _body(art, "step_clock")
	for word in ["SurfaceTool", "commit(", "ArrayMesh", "Mesh.new", ".new(", "add_child", "duplicate", "_build", "Material", "bucket("]:
		if art_held.contains(word):
			rebuilt.append("dressing: " + word)
	var per_frame := art.contains("func _physics_process(") or skyline.contains("func _physics_process(")
	_check("acceptance: nothing is rebuilt while the arena is drawn: the dressing's per-frame code only steps the arena's shader clock and its danger lights' glow (A4), and the skyline's only turns its ring and its drift by their transforms", not per_frame and rebuilt.is_empty() and held.contains("_ring.basis =") and held.contains("_drift.basis =") and art_held.contains("global_shader_parameter_set") and art_held.contains("light_energy ="), ", ".join(rebuilt))
	var sky_code := _shader_code("res://shaders/arena_sky.gdshader")
	_check("the sky never runs on the clock (no TIME), so its light is worked out once, not every frame", sky_code.contains("shader_type sky") and not sky_code.contains("TIME"))


# --- In the real arena. ---

func _arena_checks() -> void:
	var main: Node = await _arena()
	var arena: Node = main.get_node("Arena")
	var art: ArenaArt = arena.get_node("ArenaArt")
	var skyline: ArenaSkyline = arena.get_node("Skyline")
	var blocks := PackedStringArray()
	for child in arena.get_children():
		if child is StaticBody3D and child.has_method("surface_material") and child.kind != Palette.Surface.FLOOR:
			blocks.append(child.name)
	var signs := art.signs()
	var unknown := PackedStringArray()
	for text in signs:
		if not SignFont.covers(text):
			unknown.append(text)
	var surfaces := art.solid_node().mesh.get_surface_count() + art.glow_node().mesh.get_surface_count()
	_check("acceptance: the arena builds: every block but the floor dressed (%d), %d signs in the sign font, %d holograms, the solid and the light meshes, the skyline's towers, its ring and its two drifting groups" % [blocks.size(), signs.size(), art.holo_node().multimesh.instance_count], art.dressed() == blocks and blocks.size() >= 18 and signs.size() >= 15 and unknown.is_empty() and art.holo_node().multimesh.instance_count >= 8 and surfaces >= 8 and skyline.mesh_nodes().size() == 4 and skyline.movers().size() == 3, ", ".join(unknown))
	_budget_checks(arena, art, skyline)
	_collision_checks(arena, art, skyline)
	_clearance_checks(arena, art)
	_material_checks(arena, art, skyline)
	await _still_checks(art, skyline)
	_environment_checks(main)
	await _reload_checks(main, art, skyline)


func _budget_checks(arena: Node, art: ArenaArt, skyline: ArenaSkyline) -> void:
	var block_tris := 0
	var block_draws := 0
	for child in arena.get_children():
		if child is StaticBody3D and child.has_method("surface_material"):
			var mesh_node := child.get_node("Mesh") as MeshInstance3D
			for s in mesh_node.mesh.get_surface_count():
				block_tris += _surface_triangles(mesh_node.mesh, s)
				block_draws += 2 if mesh_node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF else 1
	var tris := art.triangles()
	var draws := art.draw_calls()
	var sky_tris := skyline.triangles()
	var sky_draws := skyline.draw_calls()
	var whole_tris := block_tris + tris + sky_tris
	var whole_draws := block_draws + draws + sky_draws
	print("ARENA ART budget: dressing %d triangles in %d draw calls (budget %d, %d); skyline %d triangles in %d draw calls (budget %d, %d); the whole arena with its blocks %d triangles in %d draw calls (budget %d, %d)" % [tris, draws, ArenaArt.BUDGET_TRIANGLES, ArenaArt.BUDGET_DRAW_CALLS, sky_tris, sky_draws, ArenaSkyline.BUDGET_TRIANGLES, ArenaSkyline.BUDGET_DRAW_CALLS, whole_tris, whole_draws, WHOLE_TRIANGLES, WHOLE_DRAW_CALLS])
	_check("acceptance: inside the budget: the dressing, the skyline and the whole arena each under their triangle and draw-call budgets (a draw call a surface, one more for each that throws a shadow)", tris > 5000 and tris <= ArenaArt.BUDGET_TRIANGLES and draws <= ArenaArt.BUDGET_DRAW_CALLS and sky_tris > 2000 and sky_tris <= ArenaSkyline.BUDGET_TRIANGLES and sky_draws <= ArenaSkyline.BUDGET_DRAW_CALLS and whole_tris <= WHOLE_TRIANGLES and whole_draws <= WHOLE_DRAW_CALLS)


func _collision_checks(arena: Node, art: ArenaArt, skyline: ArenaSkyline) -> void:
	var colliders := PackedStringArray()
	for scope in [art, skyline]:
		for kind in ["CollisionObject3D", "CollisionShape3D", "CollisionPolygon3D", "CSGShape3D", "GridMap"]:
			for node in (scope as Node).find_children("*", kind, true, false):
				colliders.append(String(node.name))
	var text := collision_text(arena)
	_check("acceptance: nothing under the dressing or the skyline can collide, and the arena's collision is byte for byte as before A3 (b38a900): every body (class, layer, mask), every shape (kind, size, place, on), every spawn point", colliders.is_empty() and text == COLLISION_TEXT, "%s; %s" % [", ".join(colliders), _first_difference(text, COLLISION_TEXT)])
	var sight := sight_text(arena, root.world_3d.direct_space_state)
	_check("acceptance: the sight lines are as before A3 (b38a900): from every spawn point at eye height to every daemon's middle, the ray hits what it hit", sight == SIGHT_TEXT, _first_difference(sight, SIGHT_TEXT))


## Whatever a player can walk into stands within WALL_DEPTH_MAX of a block (a hand's depth, under a
## player's radius), and over the top of a block a player can stand on nothing hangs lower than a
## jump reaches.
func _clearance_checks(arena: Node, art: ArenaArt) -> void:
	var boxes: Array[AABB] = []
	var tops: Array[AABB] = []
	for child in arena.get_children():
		if child is StaticBody3D and child.has_method("surface_material") and child.kind != Palette.Surface.FLOOR:
			var box := AABB((child as Node3D).position - child.size * 0.5, child.size)
			boxes.append(box.grow(ArenaArt.WALL_DEPTH_MAX + 0.001))
			if child.size.y < ArenaArt.WALKABLE_BELOW:
				tops.append(box)
	var floating := 0
	var over := 0
	var looked := 0
	for node in [art.solid_node(), art.glow_node()]:
		var mesh := (node as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			for v in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
				looked += 1
				if absf(v.x) > 20.0 or absf(v.z) > 20.0:
					continue
				if v.y > FOOT_M and v.y < REACH_M:
					var near := false
					for box in boxes:
						if v.x >= box.position.x and v.x <= box.end.x and v.z >= box.position.z and v.z <= box.end.z:
							near = true
							break
					if not near:
						floating += 1
				for top in tops:
					if v.x > top.position.x + 0.05 and v.x < top.end.x - 0.05 and v.z > top.position.z + 0.05 and v.z < top.end.z - 0.05 and v.y > top.end.y + 0.001 and v.y < top.end.y + REACH_M:
						over += 1
	_check("acceptance: what a player can walk into stands within %.1f m of a block (less than a player's radius), and nothing hangs over a top a player stands on lower than a jump reaches" % ArenaArt.WALL_DEPTH_MAX, looked > 20000 and floating == 0 and over == 0, "%d vertices looked at, %d free-standing, %d over a top" % [looked, floating, over])


func _material_checks(arena: Node, art: ArenaArt, skyline: ArenaSkyline) -> void:
	var allowed := {}
	for mat in Palette.arena_materials():
		allowed[mat.get_instance_id()] = true
	var seen := {}
	var shaders := {}
	var stray := PackedStringArray()
	var meshes: Array = [art.solid_node(), art.glow_node()] + skyline.mesh_nodes()
	for node in meshes:
		var mesh := (node as MeshInstance3D).mesh
		if (node as MeshInstance3D).material_override != null:
			stray.append(String(node.name) + " override")
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s)
			if mat == null or not allowed.has(mat.get_instance_id()):
				stray.append("%s %d" % [node.name, s])
			else:
				seen[mat.get_instance_id()] = true
				shaders[(mat as ShaderMaterial).shader.resource_path.get_file()] = true
	var holo := art.holo_node().material_override
	if holo == null or not allowed.has(holo.get_instance_id()):
		stray.append("holograms")
	else:
		seen[holo.get_instance_id()] = true
		shaders[(holo as ShaderMaterial).shader.resource_path.get_file()] = true
	_check("acceptance: shared materials: every surface of the dressing and the skyline, and the holograms, wears one of the palette's arena materials (%d in use, %d shaders), made once for every arena, never one of its own" % [seen.size(), shaders.size()], stray.is_empty() and seen.size() >= 8 and seen.size() <= allowed.size() and shaders.size() == 5, ", ".join(stray))
	var wrong := PackedStringArray()
	for child in arena.get_children():
		if child is StaticBody3D and child.has_method("surface_material"):
			var mat: ShaderMaterial = child.surface_material()
			if child.kind == Palette.Surface.FLOOR:
				if mat.shader.resource_path.get_file() != "floor_grid.gdshader" or mat.get_shader_parameter("plate_m") != Palette.FLOOR_PLATE_M:
					wrong.append(child.name)
			elif mat.get_shader_parameter("wash_energy") != Palette.ARENA_WALL_WASH:
				wrong.append(child.name)
	_check("the floor is one shared deck of plates, and every other block keeps its own code rain material, now with the light strips' wash", wrong.is_empty(), ", ".join(wrong))


func _still_checks(art: ArenaArt, skyline: ArenaSkyline) -> void:
	var before := _ids(art, skyline)
	var turns: Array = []
	for mover in skyline.movers():
		turns.append((mover as Node3D).basis)
	for i in 120:
		await physics_frame
	var after := _ids(art, skyline)
	var turned := 0
	for i in turns.size():
		if not (skyline.movers()[i] as Node3D).basis.is_equal_approx(turns[i]):
			turned += 1
	_check("acceptance: nothing is rebuilt while the arena is drawn: over 120 frames every mesh, the holograms' MultiMesh and every node stay the same objects, while the ring and the two drifting groups turn", before == after and turned == 3, "%d of %d ids kept, %d turned" % [_kept(before, after), before.size(), turned])


func _environment_checks(main: Node) -> void:
	var env: Environment = (main.find_child("WorldEnvironment", true, false) as WorldEnvironment).environment
	var sky_mat := env.sky.sky_material as ShaderMaterial if env.sky != null else null
	var ok: bool = env.background_mode == Environment.BG_SKY and sky_mat != null and sky_mat.shader.resource_path == "res://shaders/arena_sky.gdshader" and sky_mat.get_shader_parameter("horizon_color") == Palette.SKY_HORIZON
	ok = ok and env.fog_enabled and env.fog_mode == Environment.FOG_MODE_DEPTH and env.fog_light_color == Palette.FOG and env.fog_depth_begin >= 20.0 and env.fog_depth_end > env.fog_depth_begin and env.fog_height_density > 0.0
	_check("acceptance: the void has a sky (the arena sky shader in the palette's colours) and a cheap depth fog in the palette's fog colour, clear near the player and thick in the distance, thicker still down in the abyss", ok, "fog %s, %.0f to %.0f m" % [env.fog_light_color.to_html(false), env.fog_depth_begin, env.fog_depth_end])


## A reload of the arena (R, respawn all) builds nothing: it takes the kept meshes.
func _reload_checks(main: Node, art: ArenaArt, skyline: ArenaSkyline) -> void:
	var first := _ids(art, skyline)
	var built_first := art.built_fresh() or skyline.built_fresh()
	_arenas.erase(main)
	main.free()
	await process_frame
	var again: Node = await _arena()
	var art2: ArenaArt = again.get_node("Arena/ArenaArt")
	var skyline2: ArenaSkyline = again.get_node("Arena/Skyline")
	var second := _ids(art2, skyline2)
	var same_meshes := first.slice(0, 7) == second.slice(0, 7)
	_check("a reload of the arena builds nothing: the second arena takes the first one's kept meshes and MultiMesh, the same objects", built_first and not art2.built_fresh() and not skyline2.built_fresh() and same_meshes)


# --- Helpers. ---

func _arena() -> Node:
	var link := Link.new()
	link.settings_path = _tmp.path_join("arena-privacy-%d.cfg" % _arenas.size())
	link.demo = true
	Link.park(link)
	var main = MainScene.instantiate()
	root.add_child(main)
	_arenas.append(main)
	main.get_node("Hud").guide().focus_check = func(): return false
	main.get_node("Player").assume_captured = true
	for i in 3:
		await physics_frame
	return main


## The ids of every drawn resource and node of the dressing and the skyline, meshes first.
func _ids(art: ArenaArt, skyline: ArenaSkyline) -> Array:
	var out := [art.solid_node().mesh.get_instance_id(), art.glow_node().mesh.get_instance_id(), art.holo_node().multimesh.get_instance_id()]
	for node in skyline.mesh_nodes():
		out.append(node.mesh.get_instance_id())
	for node in [art.solid_node(), art.glow_node(), art.holo_node()] + skyline.mesh_nodes():
		out.append((node as Node).get_instance_id())
	out.append(art.get_child_count())
	out.append(skyline.get_child_count())
	return out


static func _kept(a: Array, b: Array) -> int:
	var n := 0
	for i in mini(a.size(), b.size()):
		if a[i] == b[i]:
			n += 1
	return n


static func _surface_triangles(mesh: Mesh, s: int) -> int:
	var arrays := mesh.surface_get_arrays(s)
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	return (index.size() if not index.is_empty() else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3


## The first line where `got` and `want` differ, for a failing check's detail.
static func _first_difference(got: String, want: String) -> String:
	if got == want:
		return ""
	var a := got.split("\n")
	var b := want.split("\n")
	for i in maxi(a.size(), b.size()):
		var x := a[i] if i < a.size() else "(none)"
		var y := b[i] if i < b.size() else "(none)"
		if x != y:
			return "line %d: got [%s] want [%s]" % [i + 1, x, y]
	return ""


## The arena scene's gameplay nodes as they are written in it: every block (an instance of the grey
## block), the spawn points and the targets, each node's text up to the next header.
static func gameplay_scene_text(scene: String) -> String:
	var out := PackedStringArray()
	for part in scene.split("\n["):
		var block := part if part.begins_with("[") else "[" + part
		var keep := block.contains("instance=ExtResource(\"1_block\")") or block.contains("parent=\"Spawns\"") or block.contains("parent=\"Targets\"") or block.begins_with("[node name=\"Spawns\"") or block.begins_with("[node name=\"Targets\"")
		if block.begins_with("[node ") and keep:
			out.append(block.strip_edges())
	return "\n\n".join(out)


## Every collision body and shape in the arena as text: the body's class, layer and mask; each shape's
## kind and sizes, where it is, whether it is on; and the spawn points. Rounded to the millimetre.
static func collision_text(arena: Node) -> String:
	var lines := PackedStringArray()
	for node in arena.find_children("*", "CollisionObject3D", true, false):
		var body := node as CollisionObject3D
		lines.append("%s | %s layer %d mask %d" % [arena.get_path_to(body), body.get_class(), body.collision_layer, body.collision_mask])
	for node in arena.find_children("*", "CollisionShape3D", true, false):
		var cs := node as CollisionShape3D
		lines.append("%s | %s | %s | %s" % [arena.get_path_to(cs), _shape_text(cs.shape), _xf_text(cs.global_transform), "disabled" if cs.disabled else "enabled"])
	for marker in arena.get_node("Spawns").get_children():
		lines.append("spawn %s at %s" % [marker.name, _v((marker as Node3D).global_position)])
	return "\n".join(lines)


## From each spawn point at eye height to each daemon's middle: what the ray hits first.
static func sight_text(arena: Node, space: PhysicsDirectSpaceState3D) -> String:
	var lines := PackedStringArray()
	for marker in arena.get_node("Spawns").get_children():
		for dummy in arena.get_node("Targets").get_children():
			var from: Vector3 = (marker as Node3D).global_position + Vector3(0.0, 0.7, 0.0)
			var to: Vector3 = (dummy as Node3D).global_position + Vector3(0.0, 0.9, 0.0)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
			lines.append("%s > %s: %s" % [marker.name, dummy.name, (hit["collider"] as Node).name + " at " + _v(hit["position"]) if not hit.is_empty() else "clear"])
	return "\n".join(lines)


static func _shape_text(shape: Shape3D) -> String:
	if shape is BoxShape3D:
		return "box %s" % _v((shape as BoxShape3D).size)
	if shape is CylinderShape3D:
		return "cylinder r %.3f h %.3f" % [(shape as CylinderShape3D).radius, (shape as CylinderShape3D).height]
	if shape is CapsuleShape3D:
		return "capsule r %.3f h %.3f" % [(shape as CapsuleShape3D).radius, (shape as CapsuleShape3D).height]
	return shape.get_class() if shape != null else "none"


static func _xf_text(xf: Transform3D) -> String:
	return "at %s x %s y %s z %s" % [_v(xf.origin), _v(xf.basis.x), _v(xf.basis.y), _v(xf.basis.z)]


static func _v(v: Vector3) -> String:
	return "(%.3f, %.3f, %.3f)" % [v.x, v.y, v.z]


func _shader_code(path: String) -> String:
	var out := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var cut := line.find("//")
		out.append(line.substr(0, cut) if cut >= 0 else line)
	return "\n".join(out)


func _code(path: String) -> String:
	var out := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var quote := ""
		var cut := line.length()
		var i := 0
		while i < line.length():
			var ch := line[i]
			if quote != "":
				if ch == "\\":
					i += 1
				elif ch == quote:
					quote = ""
			elif ch == "\"" or ch == "'":
				quote = ch
			elif ch == "#":
				cut = i
				break
			i += 1
		out.append(line.substr(0, cut).rstrip(" \t"))
	return "\n".join(out)


func _body(source: String, name: String) -> String:
	var at := source.find("\nfunc %s(" % name)
	if at < 0:
		at = source.find("\nstatic func %s(" % name)
	if at < 0:
		return ""
	var end := source.find("\nfunc ", at + 1)
	var end_static := source.find("\nstatic func ", at + 1)
	if end_static > 0 and (end < 0 or end_static < end):
		end = end_static
	return source.substr(at, (end if end > 0 else source.length()) - at)


func _cleanup() -> void:
	for node in _arenas.duplicate():
		if is_instance_valid(node):
			for sfx in node.find_children("*", "AudioStreamPlayer", true, false):
				(sfx as AudioStreamPlayer).stop()
			node.free()
	var left = Link.take_parked()
	if left != null:
		left.shut_down(null)
	Controls.apply_binds({})
	await process_frame
	OS.delay_msec(300)
	await process_frame
