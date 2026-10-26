extends SceneTree
## Headless cannon test for SIGKILL. scripts/check.sh runs it, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/cannon_test.gd
##
## Loads the real main scene, fires the real player's cannon through drive_input() at the
## real target dummy, then at the wall behind it, then at the open sky. Checks the hit,
## the hit marker, recoil and its recovery, every effect node freeing itself on time,
## misses that must not show a marker, the cooldown, the synthesised sounds, the tuning
## validation, and that nothing is left orphaned. Read-only: nothing outside this process
## is touched, and the headless audio driver plays nothing out loud.

const MAIN_SCENE := "res://scenes/main.tscn"
const PLAYER_SCENE := "res://scenes/player.tscn"
const WEAPON_PATH := "res://resources/terminal_cannon.tres"
const Sfx = preload("res://scripts/sfx_synth.gd")
const FX_GROUP := &"cannon_fx"
const EPS := 0.0001

var _fails := 0
var _main: Node
var _player  # untyped: calls the player script's own methods
var _hud
var _w
var _shots: Array = []
var _hit_spark_color := Color.BLACK


func _initialize() -> void:
	_run()


func _run() -> void:
	_tuning_and_sound_checks()
	# _initialize runs before the tree is live, so nodes added here would not be ready yet.
	await physics_frame
	_main = load(MAIN_SCENE).instantiate()
	root.add_child(_main)
	current_scene = _main
	_player = _main.get_node("Player")
	_hud = _main.get_node("Hud")
	_w = _player.weapon_tuning()
	_player.get("_rng").seed = 7
	_player.shot_fired.connect(func(hit: bool) -> void: _shots.append(hit))
	for _i in 15:
		await _step()
	var orphans_before := _orphans()
	await _hit_checks()
	await _miss_checks()
	await _sky_and_cooldown_checks()
	await _recovery_rate_checks()
	await _fallback_check()
	for _i in _frames_for(_longest_effect() + 0.2):
		await _step()
	var alive := get_nodes_in_group(FX_GROUP).size()
	_check("no cannon effect nodes left alive at the end", alive == 0, str(alive))
	var orphans_after := _orphans()
	print("CANNON orphan nodes: %d before the first shot, %d after every shot and effect" % [orphans_before, orphans_after])
	_check("no orphan nodes left behind", orphans_after <= orphans_before)
	print("CANNON RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	# Godot reports a sound as leaked if the process quits while it is still playing. This
	# test runs faster than real time, so stop every sound and give the audio thread a moment
	# of real time to retire the playbacks before quitting.
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


func _frames_for(seconds: float) -> int:
	return ceili(seconds * Engine.physics_ticks_per_second)


func _longest_effect() -> float:
	return maxf(maxf(_w.beam_lifetime, _w.muzzle_flash_lifetime), maxf(_w.impact_flash_lifetime, _w.spark_lifetime))


func _orphans() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))


func _find_fx(kind: String) -> Node:
	for node in get_nodes_in_group(FX_GROUP):
		if String(node.name).contains(kind):
			return node
	return null


func _fx_kinds() -> Array:
	var kinds := []
	for kind in ["MuzzleFlash", "CannonBeam", "CannonImpact"]:
		if _find_fx(kind) != null:
			kinds.append(kind)
	return kinds


func _peak(data: PackedByteArray) -> float:
	var peak := 0
	for i in range(0, data.size(), 2):
		peak = maxi(peak, absi(data.decode_s16(i)))
	return peak / Sfx.INT16_FULL_SCALE


func _tuning_and_sound_checks() -> void:
	var w: Resource = load(WEAPON_PATH)
	var issues: PackedStringArray = w.problems()
	_check("shipped weapon tuning passes validation", issues.is_empty(), ", ".join(issues))
	var bad: Resource = w.duplicate()
	bad.spark_lifetime = -1.0
	bad.master_volume = 2.0
	var bad_text := ", ".join(bad.problems())
	_check("validation rejects bad weapon values", bad_text.contains("spark_lifetime") and bad_text.contains("master_volume"), bad_text)
	var zero_life: Resource = w.duplicate()
	zero_life.spark_lifetime = 0.0
	_check("validation rejects a zero spark lifetime (particles need one above 0)", ", ".join(zero_life.problems()).contains("spark_lifetime"))
	var zap: AudioStreamWAV = Sfx.fire_zap(w)
	var zap_again: AudioStreamWAV = Sfx.fire_zap(w)
	var blip: AudioStreamWAV = Sfx.hit_blip(w)
	var zap_samples := int(w.fire_sfx_seconds * w.sfx_mix_rate)
	var blip_samples := int(w.hit_sfx_seconds * w.sfx_mix_rate)
	var zap_peak := _peak(zap.data)
	var blip_peak := _peak(blip.data)
	print("CANNON sounds: fire zap %d samples, peak %.2f of full scale; hit blip %d samples, peak %.2f; both 16-bit mono at %d Hz, synthesised in-engine" % [zap_samples, zap_peak, blip_samples, blip_peak, w.sfx_mix_rate])
	_check("fire sound is 16-bit mono and the right length", zap.format == AudioStreamWAV.FORMAT_16_BITS and not zap.stereo and zap.data.size() == zap_samples * 2)
	_check("hit sound is 16-bit mono and the right length", blip.format == AudioStreamWAV.FORMAT_16_BITS and not blip.stereo and blip.data.size() == blip_samples * 2)
	_check("sound synthesis is deterministic", zap.data == zap_again.data)
	_check("fire sound is audible and stays within its gain", zap_peak > 0.2 and zap_peak <= w.fire_gain + 0.01)
	_check("hit sound is audible and stays within its gain", blip_peak > 0.2 and blip_peak <= w.hit_gain + 0.01)
	_check("master volume 0 means silence", Sfx.volume_db(0.0) == Sfx.SILENT_DB)


func _hit_checks() -> void:
	var dummy = _main.get_node("Arena/Targets/DummyA")
	var cam: Camera3D = _player.get_node("Head/Camera")
	var targets_before := get_nodes_in_group("targets").size()
	_check("camera starts with no recoil", cam.rotation.is_zero_approx())
	_check("no hit marker before firing", _hud.hit_marker_alpha() == 0.0)
	await _step(true)
	var pitch := cam.rotation.x
	var yaw := cam.rotation.y
	_check("the shot registered as a hit", _shots == [true] and _player.hits_landed == 1 and _player.shots_fired == 1, str(_shots))
	_check("the dummy took the damage", dummy.get("_dead") == true)
	_check("hit marker is showing", _hud.hit_marker_alpha() > 0.5, "%.2f" % _hud.hit_marker_alpha())
	_check("the shot frame shows the full kick, recoil_pitch_degrees up", absf(pitch - deg_to_rad(_w.recoil_pitch_degrees)) < EPS, "%.3f deg" % rad_to_deg(pitch))
	_check("recoil added a small yaw within its limit", absf(yaw) > 0.0 and absf(yaw) <= deg_to_rad(_w.recoil_yaw_degrees) + EPS, "%.3f deg" % rad_to_deg(yaw))
	_check("muzzle flash, beam and impact spawned", _fx_kinds().size() == 3, str(_fx_kinds()))
	var flash := _find_fx("MuzzleFlash")
	_check("the muzzle flash carries a light", flash != null and not flash.find_children("*", "OmniLight3D", true, false).is_empty())
	var impact := _find_fx("CannonImpact") as Node3D
	var sparks: CPUParticles3D = impact.get_node("Sparks") if impact != null else null
	_check("impact sparks are emitting", sparks != null and sparks.emitting)
	var facing := impact.global_basis.y.dot(Vector3.BACK) if impact != null else 0.0
	_check("sparks fly along the surface normal (the dummy's front faces +Z)", facing > 0.99, "dot %.4f" % facing)
	if sparks != null:
		_hit_spark_color = (sparks.material_override as StandardMaterial3D).albedo_color
	var fire_sfx: AudioStreamPlayer = _player.get("_fire_sfx")
	var hit_sfx: AudioStreamPlayer = _player.get("_hit_sfx")
	_check("fire and hit sounds both started", fire_sfx.playing and hit_sfx.playing)
	_check("sound volume follows master_volume", is_equal_approx(fire_sfx.volume_db, Sfx.volume_db(_w.master_volume)), "%.2f dB" % fire_sfx.volume_db)

	var recovered_at := -1
	var marker_gone_at := -1
	var fx_gone_at := -1
	var gone := {"MuzzleFlash": -1, "CannonBeam": -1, "CannonImpact": -1}
	for f in range(1, _frames_for(_longest_effect() + 0.5) + 1):
		await _step()
		if recovered_at < 0 and cam.rotation.x < 0.1 * pitch:
			recovered_at = f
		if marker_gone_at < 0 and _hud.hit_marker_alpha() == 0.0:
			marker_gone_at = f
		if fx_gone_at < 0 and get_nodes_in_group(FX_GROUP).is_empty():
			fx_gone_at = f
		for kind in gone:
			if gone[kind] < 0 and _find_fx(kind) == null:
				gone[kind] = f
	var lifetimes := {"MuzzleFlash": _w.muzzle_flash_lifetime, "CannonBeam": _w.beam_lifetime, "CannonImpact": maxf(_w.impact_flash_lifetime, _w.spark_lifetime)}
	for kind in gone:
		var expected := _frames_for(lifetimes[kind])
		_check("%s lives for its own lifetime (%.2f s) and is then freed" % [kind, lifetimes[kind]], gone[kind] >= expected - 1 and gone[kind] <= expected + 3, "gone after %d frames, lifetime %d frames" % [gone[kind], expected])
	var rate := Engine.physics_ticks_per_second
	print("CANNON hit: kick %.3f deg up and %.3f deg sideways; view back under 10%% of the kick after %d frames (%.3f s); hit marker gone after %d frames (%.2f s set); every effect freed after %d frames (longest lifetime %.2f s)" % [rad_to_deg(pitch), rad_to_deg(yaw), recovered_at, float(recovered_at) / rate, marker_gone_at, _w.hit_marker_seconds, fx_gone_at, _longest_effect()])
	_check("recoil recovered smoothly back to rest", recovered_at > 1 and cam.rotation.length() < 0.02 * pitch, "%.4f deg left" % rad_to_deg(cam.rotation.length()))
	_check("hit marker faded out on time", marker_gone_at > 1 and marker_gone_at <= _frames_for(_w.hit_marker_seconds) + 2)
	_check("every effect freed after its lifetime, and not before", fx_gone_at >= _frames_for(_longest_effect()) - 2 and fx_gone_at <= _frames_for(_longest_effect()) + 3)
	_check("the hit dummy despawned", get_nodes_in_group("targets").size() == targets_before - 1)


func _miss_checks() -> void:
	# DummyA is gone, so the same line of fire now runs on through the doorway into the far wall.
	var hits_before: int = _player.hits_landed
	await _step(true)
	var impact := _find_fx("CannonImpact") as Node3D
	var sparks: CPUParticles3D = impact.get_node("Sparks") if impact != null else null
	_check("a shot into the wall registers as a miss", _shots.size() == 2 and _shots[1] == false and _player.hits_landed == hits_before, str(_shots))
	_check("no hit marker on a miss", _hud.hit_marker_alpha() == 0.0)
	_check("a miss still throws sparks at the wall", sparks != null and sparks.emitting)
	var facing := impact.global_basis.y.dot(Vector3.BACK) if impact != null else 0.0
	_check("wall sparks fly along the wall's normal", facing > 0.99, "dot %.4f" % facing)
	if sparks != null:
		var miss_color := (sparks.material_override as StandardMaterial3D).albedo_color
		_check("hits spark amber and misses spark mint, so the player can tell them apart", _hit_spark_color.r > _hit_spark_color.g and miss_color.g > miss_color.r)
	for _i in _frames_for(_longest_effect() + 0.1):
		await _step()


func _sky_and_cooldown_checks() -> void:
	var head: Node3D = _player.get_node("Head")
	var cam: Camera3D = _player.get_node("Head/Camera")
	var limit := deg_to_rad(_player.get("_t").pitch_limit_degrees)
	head.rotation.x = limit  # aim straight up at the open sky, as far as mouse look allows
	var shots_before := _shots.size()
	await _step(true)
	_check("recoil never tips the view past the pitch limit", head.rotation.x + cam.rotation.x <= limit + EPS, "%.3f deg total, limit %.1f" % [rad_to_deg(head.rotation.x + cam.rotation.x), rad_to_deg(limit)])
	var beam := _find_fx("CannonBeam")
	var beam_length := 0.0
	if beam != null:
		beam_length = ((beam.get_child(0) as MeshInstance3D).mesh as CylinderMesh).height
	_check("a shot at the open sky hits nothing and spawns no impact", _shots.size() == shots_before + 1 and _shots[-1] == false and _find_fx("CannonImpact") == null)
	_check("a sky shot's beam runs out to the full range", absf(beam_length - _w.fire_range) < 1.0, "%.2f m" % beam_length)
	# Cooldown: press two frames before it ends (blocked) and one frame after (fires).
	var boundary := _frames_for(_w.fire_cooldown)
	for k in range(1, boundary + 2):
		var probe_before := k == boundary - 2
		var probe_after := k == boundary + 1
		var count_before := _shots.size()
		await _step(probe_before or probe_after)
		if probe_before:
			_check("the cooldown still blocks a shot 2 frames before it ends", _shots.size() == count_before, "frame %d of %d" % [k, boundary])
		elif probe_after:
			_check("the cannon fires again 1 frame after the cooldown ends", _shots.size() == count_before + 1, "frame %d of %d" % [k, boundary])
	print("CANNON cooldown: %.2f s = %d frames; blocked at frame %d, fired at frame %d" % [_w.fire_cooldown, boundary, boundary - 2, boundary + 1])
	# Mouse moving up while recoil is still active: the clamp must hold at once, before the
	# next physics tick, and the next tick too.
	for _i in boundary + 1:
		await _step()
	head.rotation.x = limit - deg_to_rad(3.0)
	await _step(true)
	var kicked := cam.rotation.x
	_player.call("_look", Vector2(0.0, -100000.0))
	var total_now := head.rotation.x + cam.rotation.x
	await _step()
	var total_next := head.rotation.x + cam.rotation.x
	print("CANNON mouse up during recoil: kick %.3f deg; aim plus recoil %.3f deg straight after the mouse move, %.3f deg a tick later (limit %.1f)" % [rad_to_deg(kicked), rad_to_deg(total_now), rad_to_deg(total_next), rad_to_deg(limit)])
	_check("moving the mouse up during recoil never tips the view past the limit, even before the next tick", kicked > 0.0 and total_now <= limit + EPS and total_next <= limit + EPS)
	head.rotation.x = 0.0
	for _i in _frames_for(_longest_effect() + 0.5):
		await _step()


func _recovery_rate_checks() -> void:
	var cam: Camera3D = _player.get_node("Head/Camera")
	var times := []
	var kicks := []
	var fired := true
	for rate in [60, 120]:
		Engine.physics_ticks_per_second = rate
		for _i in _frames_for(0.6):
			await _step()
		var shots_before := _shots.size()
		await _step(true)
		var kick := cam.rotation.x
		fired = fired and _shots.size() == shots_before + 1
		var frames := 0
		while cam.rotation.x > 0.1 * kick and frames < 2000:
			await _step()
			frames += 1
		kicks.append(kick)
		times.append(float(frames) / rate)
	Engine.physics_ticks_per_second = 60
	print("CANNON frame-rate check: shot-frame kick %.3f deg at 60 Hz and %.3f deg at 120 Hz; back under 10%% in %.3f s and %.3f s" % [rad_to_deg(kicks[0]), rad_to_deg(kicks[1]), times[0], times[1]])
	_check("a shot fired at both 60 and 120 Hz, each with a real kick", fired and kicks[0] > 0.5 * deg_to_rad(_w.recoil_pitch_degrees) and kicks[1] > 0.5 * deg_to_rad(_w.recoil_pitch_degrees))
	_check("the shot-frame kick is the same size at 60 and 120 Hz", absf(kicks[0] - kicks[1]) < EPS)
	_check("recoil recovers in the same time at 60 and 120 Hz, within one 60 Hz frame", times[0] > 0.0 and times[1] > 0.0 and absf(times[0] - times[1]) <= 1.0 / 60.0 + 0.000001)


func _fallback_check() -> void:
	var bad: Resource = load(WEAPON_PATH).duplicate()
	bad.beam_sides = 1
	var extra = load(PLAYER_SCENE).instantiate()
	extra.weapon = bad
	extra.position = Vector3(0.0, 40.0, 0.0)
	_main.add_child(extra)
	var used: Resource = extra.weapon_tuning()
	_check("a player given bad weapon tuning falls back to safe defaults", used != bad and used.problems().is_empty())
	extra.queue_free()
	await _step()
