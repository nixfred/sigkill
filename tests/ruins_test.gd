extends SceneTree
## Headless test of the ruins kit for SIGKILL (C36, PRD 5.6). scripts/check.sh runs it as step 55, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/ruins_test.gd
##
## The code: nothing of the kit runs a program, opens a connection or a file, reads the environment, a path or a
## process: no reads of the player's machine. The data: the ruins book's sets are good, their names demo text that gives
## nothing of the story away. The plans: seeded and repeatable (the same set twice, the same district; another seed,
## another district); every set's named points there (start, exit, plaza, logs, daemons, ICEbreakers, spawns, vistas),
## each on the floor and walkable to from the start; no cable hangs low over the floor. The builds: every set builds
## headless with no errors, inside its budgets, its collision standing: a ray down from each point meets its floor, and a
## player stands there clear of everything. No two racks or monoliths alike. The registers: tron, cyberpunk, matrix and
## all put the ruins' global mix, the place's fog and sun and its weather where they belong, at once or over a shift
## that tears as it goes; every ruins colour keeps its distance from the daemons' and ICE's. In the arena: a set queued
## stands the next arena in it (its level gone, the player, its spawns, the daemons and the ICEbreakers' pickups at the
## ruins' points, ICE stood down, the arena's environment copied), and the next plain arena is as it was. Missions: one
## naming ruins is checked against them (a point it names, no ICE yet). The C35 leftovers: the arena's counter hidden in
## a mission, and an arena the runner reloads coming in from black. Frames counted, outcomes printed.

const MainScene = preload("res://scenes/main.tscn")
const Link = preload("res://scripts/guide/guide_link.gd")
const Controls = preload("res://scripts/controls.gd")
const Palette = preload("res://scripts/palette.gd")
const GreyBlock = preload("res://scripts/grey_block.gd")

const KIT := ["res://scripts/ruins/ruins_set.gd", "res://scripts/ruins/ruins_book.gd", "res://scripts/ruins/ruins_layout.gd", "res://scripts/ruins/ruins_pieces.gd", "res://scripts/ruins/ruins_world.gd", "res://scripts/ruins/ruins_register.gd", "res://scripts/ruins/ruins_stage.gd", "res://shaders/ruins_common.gdshaderinc", "res://shaders/ruins_body.gdshader", "res://shaders/ruins_light.gdshader", "res://shaders/ruins_floor.gdshader", "res://shaders/ruins_haze.gdshader"]
const NEVER := ["OS.execute", "create_process", "OS.kill", "shell_open", "HTTPRequest", "HTTPClient", "PacketPeer", "StreamPeer", "TCPServer", "UDPServer", "WebSocket", "FileAccess", "DirAccess", "store_var", "get_var", "str_to_var", "OS.get_environment", "get_user_data_dir", "get_executable_path", "OpenerData", "AiSourceDetector", "http://", "https://", "/proc", "/sys/", "/home", "nvidia"]
const NAMED := ["start", "exit", "plaza", "log_0", "log_1", "log_2", "log_3", "daemon_0", "daemon_1", "daemon_2", "daemon_3", "daemon_4", "daemon_5", "breaker_0", "breaker_1", "breaker_2", "breaker_3", "breaker_4", "breaker_5", "spawn_0", "spawn_1", "spawn_2", "spawn_3", "spawn_4", "vista_0"]
const MOST_FRAMES := 3000
const LONG_ROUND_S := 100000.0
const PLAYER_R := 0.4
const PLAYER_H := 1.8

var _fails := 0
var _checks := 0
var _root := ""


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_root = "user://ruins-test-%d" % OS.get_process_id()
	if DirAccess.dir_exists_absolute(_root):
		print("FAIL the test's own folder already exists; not touching it")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_root)
	Controls.ensure()
	GameSettings.current().reset()
	MissionRunner.clear_pending()
	RuinsStage.queue("")
	_code_checks()
	_data_checks()
	_plan_checks()
	await _build_checks()
	_variety_checks()
	await _register_checks()
	_colour_checks()
	await _arena_checks()
	_mission_checks()
	await _cleanup()
	print("RUINS: %d checks" % _checks)
	print("RUINS RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The code. ---

func _code_checks() -> void:
	var found := PackedStringArray()
	var all := ""
	for path in KIT:
		var code := FileAccess.get_file_as_string(path)
		all += code
		for word in NEVER:
			if code.contains(word):
				found.append("%s: %s" % [path.get_file(), word])
	_check("acceptance: no file reads of the player's machine in the kit: nothing of it runs a program, opens a connection or a file, reads the environment, a path, a process or the GPU", found.is_empty() and all.length() > 30000, ", ".join(found))
	var stage := FileAccess.get_file_as_string("res://scripts/ruins/ruins_stage.gd")
	_check("the --ruins flag is taken only with --demo or under --script (the tests and the captures), as --mission is", stage.contains("args.has(\"--demo\") or OS.get_cmdline_args().has(\"--script\")"))


# --- The data. ---

func _data_checks() -> void:
	var problems := RuinsBook.problems()
	_check("the ruins book: every set loads and is good (%d sets)" % RuinsBook.all().size(), problems.is_empty() and RuinsBook.all().size() == RuinsBook.SETS.size() and RuinsBook.all().size() >= 3, ", ".join(problems))
	var registers := {}
	for s in RuinsBook.all():
		registers[s.register] = true
	_check("the sets stand in each register STORY.md's ruins use: tron, cyberpunk and matrix", registers.has("tron") and registers.has("cyberpunk") and registers.has("matrix"))
	var spoilers := PackedStringArray()
	for s in RuinsBook.all():
		for text in s.folders + s.words:
			for word in RuinsLayout.NEVER_SHOWN:
				if text.to_lower().contains(word):
					spoilers.append("%s: %s" % [s.id, text])
	_check("acceptance: no `~` spoilers in the ruins: no folder name or sign word holds 6666, ~, nohup, tilde or a pid", spoilers.is_empty(), ", ".join(spoilers))
	var bad := RuinsSet.new()
	bad.id = "spoiled"
	bad.title = "a test"
	bad.folders = PackedStringArray(["a", "b", "c"])
	bad.words = PackedStringArray(["PID 6666", "OK"])
	_check("a set whose sign gives the story away is refused by name", Array(bad.problems()).any(func(p): return p.contains("gives the story away")))


# --- The plans. ---

func _plan_checks() -> void:
	for s in RuinsBook.all():
		var a := RuinsLayout.new(s)
		var b := RuinsLayout.new(s)
		_check("acceptance: %s's layout is seeded and repeatable: the same set twice, the same district to the box" % s.id, a.ascii() == b.ascii() and str(a.points) == str(b.points) and str(a.towers) == str(b.towers) and str(a.cables) == str(b.cables) and str(a.cover) == str(b.cover) and a.boxes.size() == b.boxes.size(), "" if a.ascii() == b.ascii() else "\n" + a.ascii() + "\n--\n" + b.ascii())
		var other: RuinsSet = s.duplicate()
		other.seed = s.seed + 1
		var c := RuinsLayout.new(other)
		_check("%s with another seed is another district" % s.id, c.ascii() != a.ascii() or str(c.points) != str(a.points))
		var missing := PackedStringArray()
		for name in NAMED:
			if not a.points.has(name):
				missing.append(name)
		_check("acceptance: %s names every point a mission uses (start, exit, plaza, 4 logs, 6 daemons, 6 ICEbreaker spots, 5 spawns, a vista)" % s.id, missing.is_empty(), ", ".join(missing))
		var off := PackedStringArray()
		for name in a.points:
			var p: Vector3 = a.points[name]
			if a.cell(a.cell_at(p)) != RuinsLayout.Cell.FLOOR:
				off.append(name)
		_check("%s: every point stands on a floor cell" % s.id, off.is_empty(), ", ".join(off))
		var unreachable := a.unreachable()
		_check("acceptance: %s: every point is reachable on foot from the start (the walk grid, everything that collides grown by a player's radius)" % s.id, unreachable.is_empty(), ", ".join(unreachable))
		var low := INF
		for cable in a.cables:
			low = minf(low, a.cable_low(cable))
		_check("%s: no cable hangs lower over the floor than %.1f m (lowest %.1f)" % [s.id, RuinsLayout.CABLE_LOW_M, low], low >= RuinsLayout.CABLE_LOW_M)
		_check("%s: ruins on the floor (%d blocks, %d holes into the void, %d cover), towers round it (%d), giants far out (%d), cables (%d), signs (%d)" % [s.id, a.blocks.size(), a.holes.size(), a.cover.size(), a.towers.size(), a.giants.size(), a.cables.size(), a.signs.size()], a.blocks.size() >= 3 and a.holes.size() >= 1 and a.cover.size() >= 6 and a.towers.size() >= 12 and a.giants.size() >= 8 and a.signs.size() >= 4)


# --- The builds. ---

func _build_checks() -> void:
	for s in RuinsBook.all():
		var holder := Node3D.new()
		holder.position = Vector3(400.0 * RuinsBook.all().find(s), 0, 0)
		root.add_child(holder)
		var w := RuinsWorld.new(s)
		holder.add_child(w)
		await physics_frame
		await physics_frame
		var st := w.stats()
		_check("acceptance: %s builds headless, inside its budgets: %d triangles (of %d), %d draw calls (of %d), %d collision boxes, %d lamps, %d emitters, built in %d ms" % [s.id, st["triangles"], RuinsWorld.BUDGET_TRIANGLES, st["draw_calls"], RuinsWorld.BUDGET_DRAW_CALLS, st["boxes"], st["lamps"], st["emitters"], st["ms"]], st["triangles"] > 50000 and st["triangles"] <= RuinsWorld.BUDGET_TRIANGLES and st["draw_calls"] <= RuinsWorld.BUDGET_DRAW_CALLS and st["boxes"] == w.layout.boxes.size() and st["emitters"] >= 3)
		var space := w.get_world_3d().direct_space_state
		var floorless := PackedStringArray()
		var blocked := PackedStringArray()
		for name in w.layout.points:
			var at := w.point(name)
			var foot := Vector3(at.x, holder.position.y, at.z)
			var ray := PhysicsRayQueryParameters3D.create(foot + Vector3(0, 1.6, 0), foot + Vector3(0, -1.0, 0), 1)
			var hit := space.intersect_ray(ray)
			if hit.is_empty() or absf(hit["position"].y - RuinsLayout.FLOOR_Y) > 0.01:
				floorless.append(name)
			var capsule := CapsuleShape3D.new()
			capsule.radius = PLAYER_R
			capsule.height = PLAYER_H
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = capsule
			query.collision_mask = 1
			query.transform = Transform3D(Basis.IDENTITY, foot + Vector3(0, PLAYER_H * 0.5 + 0.05, 0))
			if not space.intersect_shape(query, 1).is_empty():
				blocked.append(name)
		_check("acceptance: %s's points stand on its built floor: a ray down from each meets the floor's top" % s.id, floorless.is_empty(), ", ".join(floorless))
		_check("acceptance: %s: a player stands at every point clear of everything that collides" % s.id, blocked.is_empty(), ", ".join(blocked))
		var t0 := Time.get_ticks_msec()
		var again := RuinsWorld.new(s)
		holder.add_child(again)
		_check("%s is kept: a second arena with it builds nothing (%d ms), the same meshes" % [s.id, Time.get_ticks_msec() - t0], again.stats()["triangles"] == st["triangles"] and Time.get_ticks_msec() - t0 < 400)
		holder.queue_free()
		await process_frame


func _variety_checks() -> void:
	var rng := RandomNumberGenerator.new()
	var racks := {}
	var dupes := 0
	var count := 0
	for s in RuinsBook.all():
		var l := RuinsLayout.of(s)
		for i in l.towers.size():
			var kit := ShapeKit.new()
			var b := {"body": kit.bucket(Vector3.ZERO, true, true), "light": kit.bucket(Vector3.ZERO, false, true), "floor": kit.bucket(Vector3.ZERO, false, true)}
			rng.seed = hash("%d:tower:%d" % [s.seed, i])
			RuinsPieces.rack_tower(kit, b, l.towers[i], rng)
			var sig := _signature(kit, b)
			if racks.has(sig):
				dupes += 1
			racks[sig] = true
			count += 1
	_check("acceptance: no two racks alike: %d rack towers over the sets, each of its own height, lean, slips, damage and lights" % count, dupes == 0 and count >= 40, "%d alike" % dupes)
	var monoliths := {}
	var mono_dupes := 0
	for k in 12:
		var kit := ShapeKit.new()
		var b := {"body": kit.bucket(Vector3.ZERO, true, true), "light": kit.bucket(Vector3.ZERO, false, true), "floor": kit.bucket(Vector3.ZERO, false, true)}
		rng.seed = hash("monolith:%d" % k)
		RuinsPieces.monolith(kit, b, Vector3(-3.4, 0, -1.7), Vector3(3.4, 0, 1.7), "untitled folder", rng)
		var sig := _signature(kit, b)
		if monoliths.has(sig):
			mono_dupes += 1
		monoliths[sig] = true
	_check("no two monoliths alike: twelve of the same name and place, each cracked, shifted and lit its own way", mono_dupes == 0)


## A piece's look as one string: its parts' counts and a sum over every place and paint in it.
func _signature(kit: ShapeKit, b: Dictionary) -> String:
	var out := ""
	for part in ["body", "light"]:
		var mesh := kit.commit(b[part])
		var sum := Vector3.ZERO
		var paint := Color(0, 0, 0, 0)
		if mesh.get_surface_count() > 0:
			var arrays := mesh.surface_get_arrays(0)
			for v in arrays[Mesh.ARRAY_VERTEX]:
				sum += v
			for c in arrays[Mesh.ARRAY_COLOR]:
				paint += c
		out += "%d|%.3f,%.3f,%.3f|%.3f,%.3f;" % [kit.count(b[part]), sum.x, sum.y, sum.z, paint.r, paint.g]
	return out


# --- The registers. ---

func _register_checks() -> void:
	RuinsStage.queue("scheduler_breach")
	var main := await _arena(true)
	RuinsStage.queue("")
	var w := RuinsWorld.of(main)
	if w == null:
		_check("register switching: the arena stands in the ruins queued", false)
		await _drop(main)
		return
	var env: Environment = (main.find_child("WorldEnvironment", true, false) as WorldEnvironment).environment
	var sun: DirectionalLight3D = main.get_node("Sun")
	var ok_all := true
	var detail := PackedStringArray()
	for name in ["tron", "cyberpunk", "matrix"]:
		w.set_register(name, 0.0)
		await process_frame
		var want := RuinsRegister.weights(name)
		var mix: Vector4 = w.pushed_mix
		var e: Dictionary = RuinsRegister.ENV[name]
		var ok: bool = mix.is_equal_approx(want) and env.fog_light_color.is_equal_approx(e["fog"]) and absf(env.fog_density - e["fog_density"]) < 0.001 and sun.light_color.is_equal_approx(e["sun"]) and w.register == name
		var rain: GPUParticles3D = w.get_node("Rain")
		var motes: GPUParticles3D = w.get_node("Motes")
		var glyphs: GPUParticles3D = w.get_node("Glyphs")
		ok = ok and rain.emitting == (name == "cyberpunk") and glyphs.emitting == (name == "matrix") and motes.emitting
		ok_all = ok_all and ok
		detail.append("%s %s" % [name, "ok" if ok else "mix %s fog %s" % [str(mix), str(env.fog_light_color)]])
	_check("acceptance: register switching: tron, cyberpunk and matrix each put the ruins' shaders (the global mix), the place's fog, sun and weather where they belong (rain in the ruins, glyphs where memory is thin)", ok_all, " | ".join(detail))
	w.set_register("tron", 0.0)
	w.set_register("matrix")
	var mid_tear := 0.0
	var frames := 0
	while w.shifting() and frames < MOST_FRAMES:
		await process_frame
		frames += 1
		mid_tear = maxf(mid_tear, w.tear)
	var after: Vector4 = w.pushed_mix
	_check("a shift runs over %.1f s, tearing as it goes (the tear peaked at %.2f), and lands on the new register untorn" % [RuinsWorld.SHIFT_S, mid_tear], mid_tear > 0.8 and after.is_equal_approx(RuinsRegister.weights("matrix")) and w.pushed_tear == 0.0 and frames >= int(RuinsWorld.SHIFT_S * 50.0))
	w.set_register("all", 0.0)
	await process_frame
	_check("\"all\" (the finale's three at once) puts the mix's fourth weight up, the weather a third each", w.pushed_mix.is_equal_approx(Vector4(0, 0, 0, 1)) and RuinsRegister.shares(Vector4(0, 0, 0, 1)).is_equal_approx(Vector3.ONE / 3.0))
	w.set_register("bogus", 0.0)
	_check("a register it does not know is tron's", w.register == "tron")
	await _drop(main)


func _colour_checks() -> void:
	var worst := INF
	var worst_colour := Color()
	for c in RuinsRegister.colours():
		var g := RuinsRegister.gap(c)
		if g < worst:
			worst = g
			worst_colour = c
	_check("acceptance: the daemons and ICE stay readable against every register: no ruins colour (the signs' magenta and amber among them) comes within %.2f OKLab of rogue.d's crimson, the zombie's amber, the runaway's magenta or ICE's blues (nearest %.3f, %s)" % [RuinsRegister.READABLE_GAP, worst, worst_colour.to_html(false)], worst >= RuinsRegister.READABLE_GAP)


# --- In the arena. ---

func _arena_checks() -> void:
	var s := RuinsBook.of("deep_dirs")
	RuinsStage.queue(s.id)
	var main := await _arena(true)
	var w := RuinsWorld.of(main)
	var blocks := 0
	for child in main.get_node("Arena").get_children():
		if child.get_script() == GreyBlock:
			blocks += 1
	_check("acceptance: a set queued stands the next arena in it: the ruins built where the arena's level was (no greybox block, no dressing, no skyline left)", w != null and w.ruins == s and blocks == 0 and not main.has_node("Arena/ArenaArt") and not main.has_node("Arena/Skyline") and not main.has_node("Arena/RoomLight"))
	var player = main.get_node("Player")
	var start := w.point("start")
	_check("the player starts at the ruins' start, and a fall puts it back there", Vector2(player.global_position.x - start.x, player.global_position.z - start.z).length() < 0.6 and (player.get("_spawn") as Transform3D).origin.is_equal_approx(start))
	var daemons := w.points_of("daemon")
	var placed := true
	for dummy in main.get_node("Arena/Targets").get_children():
		var at: Vector3 = daemons[dummy.get_index() % daemons.size()]
		placed = placed and Vector2(dummy.brain.home.origin.x - at.x, dummy.brain.home.origin.z - at.z).length() < 0.01
	_check("each daemon stands at a daemon point, its home from then on (a respawn comes back there)", placed)
	var spawns := w.points_of("spawn")
	var markers := main.get_node("Arena/Spawns").get_children()
	_check("the spawn markers stand at the ruins' spawn points", markers.size() > 0 and (markers[0] as Node3D).global_position.is_equal_approx(spawns[0]))
	var breakers := main.get_node("BreakerDirector")
	var spots_ok: bool = breakers.spots.size() == w.points_of("breaker").size()
	for i in breakers.spots.size():
		spots_ok = spots_ok and (breakers.spots[i] as Vector3).is_equal_approx(main.get_node("Arena").to_local(w.points_of("breaker")[i]))
	_check("the ICEbreakers' pickups stand at the ruins' breaker points, not the arena's", spots_ok and breakers.spots != BreakerDirector.SPOTS)
	var ice := main.get_node("IceDirector")
	_check("in ruins with no mission ICE stands down (its walls and nodes are the arena's)", ice.stand_down)
	var env: Environment = (main.find_child("WorldEnvironment", true, false) as WorldEnvironment).environment
	var plain_arena := (load("res://scenes/arena.tscn") as PackedScene).instantiate()
	var scene_env: Environment = plain_arena.get_node("WorldEnvironment").environment
	_check("the ruins change a copy of the arena's environment, never the scene's own", env != scene_env)
	plain_arena.free()
	var hud = main.get_node("Hud")
	_check("in plain ruins play the arena's \"daemons down\" counter still shows (no mission)", hud.targets_shown())
	RuinsStage.queue("")
	main = await _reload(main)
	_check("the next plain arena is as it was: its floor and dressing back, no ruins, its fog its own", RuinsWorld.of(main) == null and main.has_node("Arena/Floor") and main.has_node("Arena/ArenaArt") and (main.find_child("WorldEnvironment", true, false) as WorldEnvironment).environment.fog_light_color.is_equal_approx(Palette.FOG))
	# Mission 1 in its ruins: begun on the plain arena, it reloads the arena into them.
	var old_id := main.get_instance_id()
	MissionRunner.of(main).begin(MissionBook.at(1))
	main = await _after_reload(old_id)
	var runner := MissionRunner.of(main)
	hud = main.get_node("Hud")
	await _until(func(): return runner.running())
	_check("acceptance: mission 1 runs in its ruins: the scheduler's breach, in its own register (tron), its log at the ruins' log_0 and its vent at their exit", runner.world != null and runner.world.ruins.id == "scheduler_breach" and runner.world.register == "tron" and runner.log_place("temporary").is_equal_approx(runner.world.point("log_0")) and runner.reach_place(3).is_equal_approx(runner.world.point("exit")) and runner.pickup("temporary") != null and runner.pickup("temporary").global_position.is_equal_approx(runner.world.point("log_0")))
	_check("the C35 leftover: the arena's \"daemons down\" counter is hidden while a mission runs (its own panel counts)", not hud.targets_shown())
	var mh: MissionHud = hud.mission_hud()
	_check("the C35 leftover: an arena the runner reloaded comes in from black, not a blink (the cut %.2f a moment in)" % mh.cut_left(), mh.cut_left() > 0.0 and mh.cut_left() < 1.0)
	await _frames(int(MissionHud.CUT_S * 60.0) + 4)
	_check("and is clear once the cut is over (%.2f s)" % MissionHud.CUT_S, mh.cut_left() == 0.0)
	await _until(func(): return runner.state == MissionRunner.State.RUNNING)
	runner.end_here()
	_check("a mission ended shows the arena's counter again", hud.targets_shown())
	MissionRunner.clear_pending()
	await _drop(main)


func _mission_checks() -> void:
	var login := MissionBook.at(1)
	_check("mission 1 names its ruins (the scheduler's breach), and its data is good against them", login.ruins == "scheduler_breach" and login.problems(MissionBook.weapon_ids()).is_empty())
	var bad: MissionDef = login.duplicate(true)
	bad.ice = true
	_check("a mission in ruins with ICE is refused by name (ICE's spots are the arena's)", Array(bad.problems(MissionBook.weapon_ids())).any(func(p): return p.contains("ICE in ruins")))
	var lost: MissionDef = login.duplicate(true)
	lost.objectives[3]["at"] = "nowhere"
	_check("a reach naming a point its ruins have not is refused", Array(lost.problems(MissionBook.weapon_ids())).any(func(p): return p.contains("a point of its ruins")))
	var plain: MissionDef = login.duplicate(true)
	plain.ruins = ""
	_check("on the arena itself a point's name is refused (a place is a Vector3 there)", not plain.problems(MissionBook.weapon_ids()).is_empty())
	var none: MissionDef = login.duplicate(true)
	none.ruins = "no_such_set"
	_check("ruins that are not a set are refused", Array(none.problems(MissionBook.weapon_ids())).any(func(p): return p.contains("is not a set")))


# --- Helpers. ---

func _arena(practice: bool) -> Node:
	for old in root.get_children():
		if old.scene_file_path == "res://scenes/main.tscn":
			await _drop(old)
	GameSettings.current().set_value("gameplay", "practice", practice)
	GameSettings.current().set_value("gameplay", "ice", false)
	var link := Link.new()
	link.settings_path = _root.path_join("privacy.cfg")
	link.demo = true
	Link.park(link)
	var main = MainScene.instantiate()
	root.add_child(main)
	current_scene = main
	await _ready_arena(main)
	return main


func _ready_arena(main: Node) -> void:
	main.get_node("Hud").guide().focus_check = func(): return false
	main.get_node("Hud").pause_menu().focus_check = func(): return false
	main.get_node("Hud").round_hud()._left_s = LONG_ROUND_S
	main.get_node("Player").assume_captured = true
	await _frames(2)


func _reload(main: Node) -> Node:
	var old_id := main.get_instance_id()
	reload_current_scene()
	return await _after_reload(old_id)


func _after_reload(old_id: int) -> Node:
	await _until(func(): return current_scene != null and current_scene.get_instance_id() != old_id and current_scene.has_node("Hud") and current_scene.is_node_ready())
	var fresh := current_scene
	await _ready_arena(fresh)
	return fresh


func _drop(main: Node) -> void:
	if is_instance_valid(main):
		for sfx in main.find_children("*", "AudioStreamPlayer", true, false):
			(sfx as AudioStreamPlayer).stop()
		if current_scene == main:
			current_scene = null
		main.free()
	await _frames(2)


func _cleanup() -> void:
	MissionRunner.clear_pending()
	RuinsStage.queue("")
	for node in root.get_children():
		if node.scene_file_path == "res://scenes/main.tscn":
			await _drop(node)
	current_scene = null
	for name in DirAccess.get_files_at(_root):
		DirAccess.remove_absolute(_root.path_join(name))
	DirAccess.remove_absolute(_root)
	_check("the test's own folder is gone, nothing of it left under user://", not DirAccess.dir_exists_absolute(_root))
	await process_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _until(condition: Callable) -> bool:
	var frames := 0
	while frames < MOST_FRAMES and not condition.call():
		await process_frame
		frames += 1
	return condition.call()
