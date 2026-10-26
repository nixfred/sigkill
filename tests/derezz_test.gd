extends SceneTree
## Headless derezz test for SIGKILL. scripts/check.sh runs it, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/derezz_test.gd
##
## Loads the real main scene, kills a real target dummy with the real cannon and checks the
## whole derezz: the state machine, collision, the voxel effect and its cap, voxels bursting
## out and fading, hits ignored while derezzing, the effect freeing itself on time, the
## respawn at full health, and 20 rapid kill cycles leaving no leaked or orphaned nodes.
## Also checks that every tuning resource file lists every tunable of its script.
## Read-only: nothing outside this process is touched, and the headless audio driver plays
## nothing out loud.

const Dummy = preload("res://scripts/target_dummy.gd")
const MAIN_SCENE := "res://scenes/main.tscn"
const DUMMY_SCENE := "res://scenes/target_dummy.tscn"
const DEREZZ_PATH := "res://resources/derezz.tres"
const FX_GROUP := &"derezz_fx"
const CYCLES := 20
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
	var bad_text := ", ".join(bad.problems())
	_check("validation rejects a zero voxel cap and a negative lifetime", bad_text.contains("max_voxels") and bad_text.contains("lifetime_min"), bad_text)
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

	# Hits while derezzing do nothing: a direct hit, and a cannon shot that must pass through.
	var direct = _dummy.hit(1.0, _dummy.global_position)
	var health_now: float = _dummy.health()
	for _i in _frames_for(_player.weapon_tuning().fire_cooldown) + 1:
		await _step()
	var shots_before: int = _player.shots_fired
	var hits_before: int = _player.hits_landed
	await _step(true)
	_check("a direct hit while derezzing is ignored", direct == false and _downed == 1 and _fx_nodes().size() == 1)
	_check("a cannon shot passes through a derezzing dummy and counts as a miss", _player.shots_fired == shots_before + 1 and _player.hits_landed == hits_before)
	_check("health is untouched while derezzing", is_equal_approx(health_now, _dummy.health()))

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
			hit_while_respawning = _dummy.hit(1.0, _dummy.global_position)
			_check("respawning: visible again but still not hittable and collision still off", body.visible and not _dummy.is_hittable() and shape.disabled and hit_while_respawning == false)
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
