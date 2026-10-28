extends SceneTree
## Headless derezz test for SIGKILL. scripts/check.sh runs it, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/derezz_test.gd
##
## Loads the real main scene, kills a real target dummy with the real cannon and checks the
## whole derezz: the state machine, collision, the voxel effect and its cap, voxels bursting
## out and fading, hits ignored while derezzing, the effect freeing itself on time, the
## respawn at full health, and 20 rapid kill cycles leaving no leaked or orphaned nodes.
## Also checks that the voxel motion is the same at 30 and 144 frames per second, that the
## voxels follow the killing shot's direction, from the real cannon and from a direct hit,
## that voxels knocked off the raised platform land on the arena floor below it, and that
## every tuning resource file lists every tunable of its script.
##
## Under --headless the renderer keeps no MultiMesh data, so reading an instance back from
## the MultiMesh returns an identity transform. The test checks the voxel state instead,
## and through the effect's capture hook the transform and colour each frame builds from
## that state for the MultiMesh. Whether they reach the screen needs a windowed run.
## Read-only: nothing outside this process is touched, and the headless audio driver plays
## nothing out loud.

const Dummy = preload("res://scripts/target_dummy.gd")
const DerezzFx = preload("res://scripts/derezz_fx.gd")
const MAIN_SCENE := "res://scenes/main.tscn"
const DUMMY_SCENE := "res://scenes/target_dummy.tscn"
const DEREZZ_PATH := "res://resources/derezz.tres"
const FX_GROUP := &"derezz_fx"
const CYCLES := 20
const FX_SEED := 4242
const RATE_SECONDS := 0.5  # a whole number of frames at both rates below
const RATES := [30, 144]
const RATE_SPOT := Vector3(14.0, 0.0, -4.0)  # open floor, clear of every block
const PLATFORM_HALF := 2.0  # the raised platform is 4 m square, centred under DummyD
const PLATFORM_DROP := 1.0  # its top is 1 m above the arena floor
const PUSH_SECONDS := 0.3
const OBLIQUE_TARGET := "Arena/Targets/DummyC"
const OBLIQUE_OFFSET := 0.4  # metres off the dummy's axis: the shot grazes its side
const OBLIQUE_RANGE := 4.0
const OBLIQUE_MAX_DEGREES := 20.0
const SETTLE_SECONDS := 3.0
const GUARD := 1200  # hard stop for every wait loop
const EPS := 0.0001
const TUNING_FILES := [
	["res://scripts/movement_tuning.gd", "res://resources/movement_tuning.tres"],
	["res://scripts/weapon_tuning.gd", "res://resources/terminal_cannon.tres"],
	["res://scripts/derezz_tuning.gd", "res://resources/derezz.tres"],
]

var _fails := 0
var _frame := 0
var _death_frame := 0
var _main: Node
var _player  # untyped: calls the player script's own methods
var _hud
var _dummy
var _d
var _downed := 0
var _respawned := 0
var _cycle_kills := 0


func _initialize() -> void:
	GameSettings.current().set_value("gameplay", "practice", true)  # these checks predate C27b: the daemons stay the old never-attack dummies
	_run()


func _run() -> void:
	_tuning_checks()
	# _initialize runs before the tree is live, so nodes added here would not be ready yet.
	await physics_frame
	_main = load(MAIN_SCENE).instantiate()
	root.add_child(_main)
	current_scene = _main
	_player = _main.get_node("Player")
	_hud = _main.get_node("Hud")
	_dummy = _main.get_node("Arena/Targets/DummyA")
	_d = _dummy.get("_d")
	_dummy.downed.connect(func(_who: Node3D) -> void: _downed += 1)
	_dummy.respawned.connect(func(_who: Node3D) -> void: _respawned += 1)
	for _i in 15:
		await _step()
	await _kill_checks()
	await _respawn_checks()
	await _fallback_check()
	await _frame_rate_checks()
	await _platform_checks()
	await _oblique_cannon_check()
	await _rapid_cycle_checks()
	print("DEREZZ RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	# Godot reports a sound as leaked if the process quits while it still plays. This test
	# runs faster than real time, so stop the cannon's sounds and give the audio thread a
	# moment of real time to retire them before quitting.
	for sfx in _main.find_children("*", "AudioStreamPlayer", true, false):
		(sfx as AudioStreamPlayer).stop()
	OS.delay_msec(300)
	await physics_frame
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


## Feeds one physics frame of input to the player, then waits for it to be used.
func _step(fire: bool = false) -> void:
	_player.drive_input(Vector2.ZERO, false, false, fire)
	await physics_frame
	_frame += 1


func _frames_for(seconds: float) -> int:
	return ceili(seconds * Engine.physics_ticks_per_second)


func _fx_nodes() -> Array:
	return get_nodes_in_group(FX_GROUP)


func _nodes() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))


func _orphans() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))


## Mean horizontal distance of the voxels from the body's axis, their mean fade, and how
## many rest on the ground.
func _voxel_stats(effect) -> Dictionary:
	var pos: PackedVector3Array = effect.get("_pos")
	var fade: PackedFloat32Array = effect.get("_fade")
	var rest: float = _d.voxel_size * 0.5
	var radius_sum := 0.0
	var fade_sum := 0.0
	var resting := 0
	for i in pos.size():
		radius_sum += Vector2(pos[i].x, pos[i].z).length()
		fade_sum += fade[i]
		if pos[i].y <= rest + EPS:
			resting += 1
	var n := maxi(pos.size(), 1)
	return {"radius": radius_sum / n, "fade": fade_sum / n, "resting": resting}


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


func _tuning_checks() -> void:
	var d: Resource = load(DEREZZ_PATH)
	var issues: PackedStringArray = d.problems()
	_check("shipped derezz tuning passes validation", issues.is_empty(), ", ".join(issues))
	var bad: Resource = d.duplicate()
	bad.max_voxels = 0
	bad.lifetime_min = -1.0
	bad.ground_mask = 0
	var bad_text := ", ".join(bad.problems())
	_check("validation rejects a zero voxel cap, a negative lifetime and no ground layer", bad_text.contains("max_voxels") and bad_text.contains("lifetime_min") and bad_text.contains("ground_mask"), bad_text)
	for pair in TUNING_FILES:
		var missing := _missing_tres_keys(pair[0], pair[1])
		_check("%s lists every tunable of %s" % [String(pair[1]).get_file(), String(pair[0]).get_file()], missing.is_empty(), "missing: " + ", ".join(missing))


func _kill_checks() -> void:
	var shape: CollisionShape3D = _dummy.get_node("Shape")
	var body: MeshInstance3D = _dummy.get_node("Body")
	var tag: Label3D = _dummy.get_node("Tag")
	var full: float = _dummy.max_health
	_check("the dummy starts alive, hittable and at full health", _dummy.state == Dummy.State.ALIVE and _dummy.is_hittable() and is_equal_approx(_dummy.health(), full))
	await _step(true)
	_death_frame = _frame
	_check("one cannon shot kills it and it enters derezzing", _dummy.state == Dummy.State.DEREZZING and _downed == 1, "state %d, downed %d" % [_dummy.state, _downed])
	await _step()
	_check("collision is off while derezzing", shape.disabled)
	_check("body and tag are hidden while derezzing", not body.visible and not tag.visible)
	var fx := _fx_nodes()
	_check("exactly one voxel effect exists", fx.size() == 1, str(fx.size()))
	if fx.is_empty():
		return
	var effect = fx[0]
	var count: int = effect.multimesh.instance_count
	var life: float = effect.lifetime()
	_check("voxel count is above 0 and within the cap", count > 0 and count <= _d.max_voxels and count == effect.voxel_count(), "%d voxels, cap %d" % [count, _d.max_voxels])
	_check("the HUD counts the kill", str(_hud._status.text).contains("1/4"), str(_hud._status.text))
	var early := _voxel_stats(effect)

	# The effect writes each voxel's state into its MultiMesh every frame.
	effect.capture_instance = 0
	await _step()
	var pos0: PackedVector3Array = effect.get("_pos")
	var fade0: PackedFloat32Array = effect.get("_fade")
	var xf: Transform3D = effect.captured_transform
	var first_origin := xf.origin
	_check("each frame builds the voxel's MultiMesh transform and colour from its position, size and fade", xf.origin.is_equal_approx(pos0[0]) and absf(xf.basis.get_scale().x - fade0[0]) < EPS and absf(effect.captured_color.a - fade0[0]) < EPS, "built %s scale %.3f alpha %.3f, state %s fade %.3f" % [xf.origin, xf.basis.get_scale().x, effect.captured_color.a, pos0[0], fade0[0]])
	await _step()
	_check("the next frame builds it from the voxel's new position", not effect.captured_transform.origin.is_equal_approx(first_origin) and effect.captured_transform.origin.is_equal_approx((effect.get("_pos") as PackedVector3Array)[0]))
	effect.capture_instance = -1

	# Hits while derezzing do nothing: a direct hit, and a cannon shot that must pass through.
	var health_before: float = _dummy.health()
	var direct = _dummy.hit(1.0, _dummy.global_position)
	for _i in _frames_for(_player.weapon_tuning().fire_cooldown) + 1:
		await _step()
	var shots_before: int = _player.shots_fired
	var hits_before: int = _player.hits_landed
	await _step(true)
	_check("a direct hit while derezzing is ignored", direct == false and _downed == 1 and _fx_nodes().size() == 1)
	_check("a cannon shot passes through a derezzing dummy and counts as a miss", _player.shots_fired == shots_before + 1 and _player.hits_landed == hits_before)
	_check("health is untouched by both hits while derezzing", is_equal_approx(health_before, _dummy.health()), "%.2f before, %.2f after" % [health_before, _dummy.health()])

	# Voxels burst out, settle on the ground, then shrink and fade.
	while (_frame - _death_frame) < _frames_for(_d.lifetime_min * 0.5):
		await _step()
	var mid := _voxel_stats(effect)
	while (_frame - _death_frame) < _frames_for(_d.lifetime_min * 0.95):
		await _step()
	var late := _voxel_stats(effect)
	print("DEREZZ voxels: %d (cap %d), mean distance from the axis %.2f m at the start, %.2f m at half life; mean size %.2f, %.2f, %.2f; %d of %d resting on the ground late; effect lifetime %.2f s" % [count, _d.max_voxels, early["radius"], mid["radius"], early["fade"], mid["fade"], late["fade"], late["resting"], count, life])
	_check("voxels burst outward", mid["radius"] > early["radius"] + 0.3)
	_check("voxels shrink and fade along the fade curve", early["fade"] > 0.95 and mid["fade"] < early["fade"] and late["fade"] < 0.5)
	_check("gravity brings voxels down to rest on the ground", late["resting"] > 0)

	# The effect frees itself when its lifetime ends.
	var gone_at := -1
	for _i in GUARD:
		if _fx_nodes().is_empty():
			gone_at = _frame - _death_frame
			break
		await _step()
	var expected := _frames_for(life)
	_check("the voxel effect is gone after its lifetime", gone_at >= expected - 1 and gone_at <= expected + 3, "gone after %d frames, lifetime %d frames" % [gone_at, expected])


func _respawn_checks() -> void:
	var shape: CollisionShape3D = _dummy.get_node("Shape")
	var body: MeshInstance3D = _dummy.get_node("Body")
	var tag: Label3D = _dummy.get_node("Tag")
	var home: Vector3 = _dummy.global_position
	var respawning_at := -1
	var alive_at := -1
	var hit_while_respawning = null
	for _i in GUARD:
		if respawning_at < 0 and _dummy.state == Dummy.State.RESPAWNING:
			respawning_at = _frame - _death_frame
			var health_before: float = _dummy.health()
			hit_while_respawning = _dummy.hit(1.0, _dummy.global_position)
			_check("respawning: visible again but still not hittable and collision still off", body.visible and not _dummy.is_hittable() and shape.disabled and hit_while_respawning == false)
			_check("a hit while respawning leaves health and state alone", is_equal_approx(health_before, _dummy.health()) and _dummy.state == Dummy.State.RESPAWNING, "%.2f before, %.2f after" % [health_before, _dummy.health()])
		if _dummy.state == Dummy.State.ALIVE:
			alive_at = _frame - _death_frame
			break
		await _step()
	await _step()
	var full: float = _dummy.max_health
	print("DEREZZ respawn: rematerialising after %d frames (respawn_delay %.2f s), alive after %d frames (+ %.2f s)" % [respawning_at, _d.respawn_delay, alive_at, _d.rematerialise_seconds])
	_check("it starts to rematerialise after the respawn delay", absi(respawning_at - _frames_for(_d.respawn_delay)) <= 2)
	_check("it is alive again after the rematerialise time", absi(alive_at - respawning_at - _frames_for(_d.rematerialise_seconds)) <= 2)
	_check("alive again: hittable, full health, collision on, body and tag back", _dummy.is_hittable() and is_equal_approx(_dummy.health(), full) and not shape.disabled and body.visible and body.scale.is_equal_approx(Vector3.ONE) and tag.visible)
	_check("it respawned at its own spot", _dummy.global_position.is_equal_approx(home))
	_check("the respawn signal fired once and the HUD counts it back", _respawned == 1 and str(_hud._status.text).contains("0/4"), str(_hud._status.text))
	await _step(true)
	_check("the respawned dummy can be killed again", _downed == 2 and _dummy.state == Dummy.State.DEREZZING)


func _fallback_check() -> void:
	var bad: Resource = load(DEREZZ_PATH).duplicate()
	bad.max_voxels = 0
	var extra = load(DUMMY_SCENE).instantiate()
	extra.derezz = bad
	extra.position = Vector3(30.0, 0.0, 30.0)
	_main.add_child(extra)
	var used: Resource = extra.get("_d")
	_check("a dummy given bad derezz tuning falls back to safe defaults", used != bad and used.problems().is_empty())
	extra.queue_free()
	await _step()


## Runs the same seeded derezz at two frame rates by hand and compares the voxels.
func _frame_rate_checks() -> void:
	var hex = _dummy.get("_hex")
	var runs := []
	var spent := []
	for fps in RATES:
		var effect = DerezzFx.new()
		_main.add_child(effect)
		effect.set_physics_process(false)  # driven by hand below, at its own frame rate
		effect.start(RATE_SPOT, hex.top_radius, hex.height, Vector3.RIGHT, _d, FX_SEED)
		var dt := 1.0 / float(fps)
		var began := Time.get_ticks_usec()
		for _i in roundi(RATE_SECONDS * fps):
			effect._physics_process(dt)
		spent.append(float(Time.get_ticks_usec() - began) / maxf(float(effect.get("_steps")), 1.0))
		runs.append(effect)
	var a = runs[0]
	var b = runs[1]
	var pa: PackedVector3Array = a.get("_pos")
	var pb: PackedVector3Array = b.get("_pos")
	var fa: PackedFloat32Array = a.get("_fade")
	var fb: PackedFloat32Array = b.get("_fade")
	var worst := 0.0
	var worst_fade := 0.0
	var resting := 0
	var rest: float = _d.voxel_size * 0.5
	for i in mini(pa.size(), pb.size()):
		worst = maxf(worst, pa[i].distance_to(pb[i]))
		worst_fade = maxf(worst_fade, absf(fa[i] - fb[i]))
		if pa[i].y <= rest + EPS:
			resting += 1
	print("DEREZZ frame rates: %d and %d fps for %.2f s, %d and %d simulation steps, %d of %d voxels resting, widest voxel gap %.6f m, widest fade gap %.6f; %.0f and %.0f microseconds per simulation step on this machine, ground rays included" % [RATES[0], RATES[1], RATE_SECONDS, a.get("_steps"), b.get("_steps"), resting, pa.size(), worst, worst_fade, spent[0], spent[1]])
	_check("the voxels move the same at 30 and 144 fps, sliding and bouncing included", pa.size() == pb.size() and pa.size() > 0 and resting > 0 and a.get("_steps") == b.get("_steps") and worst < EPS and worst_fade < EPS)
	for effect in runs:
		effect.queue_free()
	await _step()


## Kills DummyD on the raised platform with a shot that strikes its +X face travelling +X.
## The voxels must drift +X, and those knocked off the platform must come down on the floor.
func _platform_checks() -> void:
	var target = _main.get_node("Arena/Targets/DummyD")
	var before := _fx_nodes()
	# The shot strikes the +X face, so working the direction out from the impact point alone
	# would push the voxels -X: only the real shot direction pushes them +X.
	var struck: Vector3 = target.global_position + Vector3(0.5, 0.9, 0.0)
	var killed: bool = target.hit(target.max_health, struck, Vector3.RIGHT)
	await _step()
	var effect = null
	for candidate in _fx_nodes():
		if not before.has(candidate):
			effect = candidate
	_check("DummyD derezzes on its platform", killed and target.state == Dummy.State.DEREZZING and effect != null)
	if effect == null:
		return
	var start_frame := _frame
	while _frame - start_frame < _frames_for(PUSH_SECONDS):
		await _step()
	var drift := 0.0
	var pos: PackedVector3Array = effect.get("_pos")
	for p in pos:
		drift += p.x
	drift /= maxf(pos.size(), 1.0)
	_check("the voxels drift along the killing shot's direction", drift > 0.2, "mean drift %.2f m along +X after %.1f s" % [drift, PUSH_SECONDS])
	_settle_checks(target)
	_edge_probe_checks(target)
	# Let DummyD's derezz finish before the rapid cycles count nodes.
	for _i in GUARD:
		if not is_instance_valid(effect):
			break
		await _step()


## A seeded derezz with a long life, at DummyD's spot, driven by hand for SETTLE_SECONDS:
## every voxel must end up settled on a real surface, the platform top inside its edge and
## the arena floor outside it, never in mid-air.
func _settle_checks(target) -> void:
	var hex = target.get("_hex")
	var long: Resource = _d.duplicate()
	long.lifetime_min = SETTLE_SECONDS + 1.0
	long.lifetime_max = SETTLE_SECONDS + 1.0
	var effect = DerezzFx.new()
	_main.add_child(effect)
	effect.set_physics_process(false)
	effect.start(target.global_position, hex.top_radius, hex.height, Vector3.RIGHT, long, FX_SEED)
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	for _i in roundi(SETTLE_SECONDS * Engine.physics_ticks_per_second):
		effect._physics_process(dt)
	var pos: PackedVector3Array = effect.get("_pos")
	var vel: PackedVector3Array = effect.get("_vel")
	var probes_settled: int = effect.get("_probes")
	var sliding := 0
	for v in vel:
		if v.y == 0.0 and (v.x != 0.0 or v.z != 0.0):
			sliding += 1
	for _i in 30:
		effect._physics_process(dt)
	var probes_later: int = effect.get("_probes")
	var rest: float = long.voxel_size * 0.5
	var counts := {"on_top": 0, "top_total": 0, "on_floor": 0, "floor_total": 0, "moving": 0}
	for i in pos.size():
		var p := pos[i]
		var edge := maxf(absf(p.x), absf(p.z))
		var wanted := INF
		if edge < PLATFORM_HALF - long.voxel_size:
			wanted = rest
			counts["top_total"] += 1
		elif edge > PLATFORM_HALF + long.voxel_size:
			wanted = rest - PLATFORM_DROP
			counts["floor_total"] += 1
		else:
			continue  # right on the edge: either surface is fair
		# A settled voxel has exactly zero vertical speed: the simulation sets it on landing.
		if vel[i].y != 0.0:
			counts["moving"] += 1
		elif absf(p.y - wanted) < EPS:
			counts["on_top" if wanted == rest else "on_floor"] += 1
	print("DEREZZ platform after %.1f s: %d of %d voxels inside the edge settled on the platform top, %d of %d beyond it settled on the arena floor, %d still moving" % [SETTLE_SECONDS, counts["on_top"], counts["top_total"], counts["on_floor"], counts["floor_total"], counts["moving"]])
	_check("voxels knocked off the platform settle on the arena floor and the rest on the platform, none in mid-air", counts["floor_total"] > 0 and counts["top_total"] > 0 and counts["on_floor"] == counts["floor_total"] and counts["on_top"] == counts["top_total"])
	print("DEREZZ settled derezz: %d ground rays over %.1f s, %d settled voxels still sliding, %d more rays in the next 30 steps" % [probes_settled, SETTLE_SECONDS, sliding, probes_later - probes_settled])
	_check("settled voxels stop dead and cast no more ground rays", sliding == 0 and probes_later == probes_settled)
	effect.queue_free()


## Runs one voxel at DummyD's spot from a set position, speed and remembered ground for
## `seconds`, and returns where it ends up and its speed.
func _one_voxel(target, at: Vector3, speed: Vector3, probed_at: Vector2, ground: float, seconds: float) -> Array:
	var hex = target.get("_hex")
	var one: Resource = _d.duplicate()
	one.max_voxels = 1
	one.lifetime_min = seconds + 1.0
	one.lifetime_max = seconds + 1.0
	var effect = DerezzFx.new()
	_main.add_child(effect)
	effect.set_physics_process(false)
	effect.start(target.global_position, hex.top_radius, hex.height, Vector3.ZERO, one, FX_SEED)
	# Packed arrays come back as copies, so each one is changed and written back.
	for field in [["_pos", at], ["_vel", speed], ["_probe_at", probed_at], ["_ground", ground]]:
		var values = effect.get(field[0])
		values[0] = field[1]
		effect.set(field[0], values)
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	for _i in roundi(seconds * Engine.physics_ticks_per_second):
		effect._physics_process(dt)
	var out := [(effect.get("_pos") as PackedVector3Array)[0], (effect.get("_vel") as PackedVector3Array)[0]]
	effect.queue_free()
	return out


## Two edge cases of the ground probe, each set up exactly.
func _edge_probe_checks(target) -> void:
	var rest: float = _d.voxel_size * 0.5
	var floor_rest := rest - PLATFORM_DROP
	# A voxel last measured over the platform drops just past its edge, less than one
	# probe spacing away: it must measure again on landing and fall to the arena floor.
	var edge := _one_voxel(target, Vector3(PLATFORM_HALF + 0.12, 0.3, 0.0), Vector3.ZERO, Vector2(PLATFORM_HALF - 0.1, 0.0), 0.0, 1.5)
	print("DEREZZ edge drop: a voxel 0.12 m past the platform edge ends at %.3f m with vertical speed %.3f (arena floor rest height %.3f m)" % [edge[0].y, edge[1].y, floor_rest])
	_check("a voxel dropping just past the platform edge lands on the arena floor, not on stale ground", absf(edge[0].y - floor_rest) < EPS and edge[1].y == 0.0)
	# A fast voxel 0.1 m above the platform top falls a third of a metre in one step, ending
	# inside it. The probe must start above it, so the voxel lands on the top and bounces up
	# instead of falling through.
	var fast := _one_voxel(target, Vector3(0.5, 0.1, 0.0), Vector3(0.0, -20.0, 0.0), Vector2(50.0, 50.0), -PLATFORM_DROP, 1.0 / float(Engine.physics_ticks_per_second))
	print("DEREZZ fast fall: one step after falling at 20 m/s onto the platform, a voxel is at %.3f m moving %.3f m/s vertically (platform rest height %.3f m)" % [fast[0].y, fast[1].y, rest])
	_check("a fast voxel lands on the platform top instead of falling through it", absf(fast[0].y - rest) < EPS and fast[1].y > 0.0)
	# A voxel just past the edge, its ground last measured right there, drifts back over the
	# platform while falling fast. It moves only 3 cm sideways in the step, yet must still
	# land on the top instead of sinking into it.
	var back := _one_voxel(target, Vector3(PLATFORM_HALF + 0.01, 0.1, 0.0), Vector3(-2.0, -20.0, 0.0), Vector2(PLATFORM_HALF + 0.01, 0.0), -PLATFORM_DROP, 1.0 / float(Engine.physics_ticks_per_second))
	print("DEREZZ drift back: one step after drifting back over the edge at 20 m/s down, a voxel is at %.3f m moving %.3f m/s vertically (platform rest height %.3f m)" % [back[0].y, back[1].y, rest])
	_check("a voxel drifting back over the platform edge lands on its top", absf(back[0].y - rest) < EPS and back[1].y > 0.0)
	# The same, but crossing back by under a centimetre in the step: any sideways move counts.
	var graze := _one_voxel(target, Vector3(PLATFORM_HALF + 0.001, 0.1, 0.0), Vector3(-0.5, -20.0, 0.0), Vector2(PLATFORM_HALF + 0.001, 0.0), -PLATFORM_DROP, 1.0 / float(Engine.physics_ticks_per_second))
	print("DEREZZ graze back: one step after crossing back over the edge by 8 mm at 20 m/s down, a voxel is at %.3f m moving %.3f m/s vertically (platform rest height %.3f m)" % [graze[0].y, graze[1].y, rest])
	_check("a voxel crossing back over the edge by under a centimetre still lands on the top", absf(graze[0].y - rest) < EPS and graze[1].y > 0.0)
	# Falling fast just inside the edge and moving out: the voxel crosses the top before it
	# passes the edge in the same step, so it must land on the top, not fall past it.
	var corner := _one_voxel(target, Vector3(PLATFORM_HALF - 0.02, 0.1, 0.0), Vector3(2.0, -20.0, 0.0), Vector2(PLATFORM_HALF - 0.02, 0.0), 0.0, 1.0 / float(Engine.physics_ticks_per_second))
	print("DEREZZ corner: one step after crossing the top 2 cm inside the edge on its way out, a voxel is at x %.4f, y %.3f m, moving %.3f m/s vertically (platform rest height %.3f m)" % [corner[0].x, corner[0].y, corner[1].y, rest])
	_check("a fast voxel crossing the top just inside the edge lands on it instead of falling past", absf(corner[0].y - rest) < EPS and corner[1].y > 0.0 and corner[0].x <= PLATFORM_HALF)
	# Sliding on the top 1 cm from the edge, heading out: it must still slide off and drop.
	var slide := _one_voxel(target, Vector3(PLATFORM_HALF - 0.01, rest, 0.0), Vector3(1.0, 0.0, 0.0), Vector2(PLATFORM_HALF - 0.01, 0.0), 0.0, 1.0)
	print("DEREZZ slide off: a voxel sliding out 1 cm from the edge ends at x %.3f, y %.3f m (arena floor rest height %.3f m)" % [slide[0].x, slide[0].y, floor_rest])
	_check("a voxel sliding off the edge drops to the arena floor", absf(slide[0].y - floor_rest) < EPS and slide[0].x > PLATFORM_HALF)


## Kills DummyC with the real cannon, the shot travelling +X but grazing the dummy's side
## OBLIQUE_OFFSET off its axis. There the direction from the impact point to the body's
## centre is about 47 degrees off the shot, so the voxels only follow the shot if the
## player hands its real direction to the dummy.
func _oblique_cannon_check() -> void:
	var target = _main.get_node(OBLIQUE_TARGET)
	var cam: Camera3D = _player.get_node("Head/Camera")
	for _i in _frames_for(_player.weapon_tuning().fire_cooldown) + 1:
		await _step()
	_player.global_position = target.global_position + Vector3(-OBLIQUE_RANGE, _player.global_position.y - target.global_position.y, OBLIQUE_OFFSET)
	_player.rotation.y = -PI * 0.5  # face +X
	await _step()
	var aim := -cam.global_transform.basis.z
	aim.y = 0.0
	aim = aim.normalized()
	var before := _fx_nodes()
	await _step(true)
	var effect = null
	for candidate in _fx_nodes():
		if not before.has(candidate):
			effect = candidate
	_check("a real cannon shot grazing DummyC derezzes it", target.state == Dummy.State.DEREZZING and effect != null, "state %d" % target.state)
	if effect == null:
		return
	var mean := Vector3.ZERO
	var vel: PackedVector3Array = effect.get("_vel")
	for v in vel:
		mean += Vector3(v.x, 0.0, v.z)
	mean /= maxf(vel.size(), 1.0)
	var off_degrees := rad_to_deg(mean.angle_to(aim))
	print("DEREZZ oblique cannon kill: shot along %s, mean voxel push along %s, %.1f degrees off the shot" % [aim, mean.normalized(), off_degrees])
	_check("voxels from a real cannon kill follow the shot's own direction", off_degrees < OBLIQUE_MAX_DEGREES, "%.1f degrees off, limit %.0f" % [off_degrees, OBLIQUE_MAX_DEGREES])


func _rapid_cycle_checks() -> void:
	var fast: Resource = load(DEREZZ_PATH).duplicate()
	fast.respawn_delay = 0.1
	fast.rematerialise_seconds = 0.05
	fast.lifetime_min = 0.5
	fast.lifetime_max = 0.6
	var target = load(DUMMY_SCENE).instantiate()
	target.derezz = fast
	target.position = Vector3(6.0, 0.0, 4.0)
	_main.get_node("Arena").add_child(target)
	target.downed.connect(func(_who: Node3D) -> void: _cycle_kills += 1)
	# Settle: DummyA's second derezz and every cannon effect must be gone first.
	for _i in GUARD:
		if _fx_nodes().is_empty() and _dummy.state == Dummy.State.ALIVE and get_nodes_in_group(&"cannon_fx").is_empty():
			break
		await _step()
	for _i in 5:
		await _step()
	var nodes_before := _nodes()
	var orphans_before := _orphans()
	var most_alive := 0
	var most_voxels := 0
	for _cycle in CYCLES:
		for _i in GUARD:
			if target.is_hittable():
				break
			await _step()
		target.hit(1.0, target.global_position + Vector3(0.0, 0.9, 1.0))
		await _step()
		var alive := _fx_nodes()
		most_alive = maxi(most_alive, alive.size())
		for effect in alive:
			most_voxels = maxi(most_voxels, effect.voxel_count())
	for _i in GUARD:
		if _fx_nodes().is_empty() and target.state == Dummy.State.ALIVE:
			break
		await _step()
	for _i in 3:
		await _step()
	var nodes_after := _nodes()
	var orphans_after := _orphans()
	print("DEREZZ %d rapid kill cycles: %d deaths, up to %d effects alive at once, up to %d voxels each (cap %d); nodes %d before and %d after, orphans %d before and %d after" % [CYCLES, _cycle_kills, most_alive, most_voxels, fast.max_voxels, nodes_before, nodes_after, orphans_before, orphans_after])
	_check("20 rapid kill cycles: 20 deaths, one derezz each", _cycle_kills == CYCLES)
	_check("rapid kills overlap their effects, and each stays within the cap", most_alive >= 2 and most_voxels <= fast.max_voxels)
	_check("every voxel effect freed itself", _fx_nodes().is_empty())
	_check("node count back to baseline after 20 cycles", nodes_after == nodes_before)
	_check("no orphan nodes after 20 cycles", orphans_after <= orphans_before)
	target.queue_free()
	await _step()
