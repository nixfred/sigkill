extends SceneTree
## Headless test of P1, the first polish pass after M5. scripts/check.sh runs it as step 72, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/polish_test.gd
##
## Each check pins one known issue P1 fixed, so it cannot come back:
## - W7's cover drone, out when the arena reloads (R), starts its recharge as it goes: the reloaded arena says
##   "recharging" and sends no fresh drone, as when it leaves on its own.
## - A match starting mid-mode (W2's folder map, W3's theme shift, W4's keybind gunplay, W5's packet tracer) ends the
##   mode and reloads into the plain arena: its district goes with it, the arena's own four daemons are back. The match
##   is the game's own session hosting on a port the system picks, as tests/net_test.gd does; nobody joins, and it
##   leaves again after each check.
## Demo data only: every mode runs on its made-up layer (the real-data opt-in stays off), and nothing real is read.

const MainScene = preload("res://scenes/main.tscn")
const Link = preload("res://scripts/guide/guide_link.gd")
const Controls = preload("res://scripts/controls.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")

const MOST_FRAMES := 3600
const LONG_ROUND_S := 100000.0
## A world mode's reload comes two frames after its end (MissionRunner.reload_after_mount); five seconds is plenty.
const RELOAD_FRAMES := 300


var _checks := 0
var _fails := 0
var _abs := ""


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_abs = ProjectSettings.globalize_path("user://polish-test-%d" % OS.get_process_id())
	if DirAccess.dir_exists_absolute(_abs):
		print("FAIL the test's own folder already exists; not touching it")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_abs)
	Controls.ensure()
	GameSettings.current().reset()
	SettingsApply.apply_audio(GameSettings.current())
	MissionRunner.clear_pending()
	_clear_modes()
	MissionProgress.current().path = _abs.path_join("progress.cfg")
	MissionProgress.current().clear()
	Progress.current().path = _abs.path_join("progress.cfg")
	Progress.current().clear()
	AuditVisor.remembered = false
	await _drone_checks()
	await _match_checks()
	await _cleanup()
	print("POLISH: %d checks" % _checks)
	print("POLISH RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


func _clear_modes() -> void:
	ProcHunt.clear()
	FolderMap.clear()
	ThemeShift.clear()
	KeybindGunplay.clear()
	PacketTracer.clear()
	CoopHunt.clear()
	VoiceDemo.clear()


# --- W7: the cover drone through an arena reload. ---

func _drone_checks() -> void:
	GameSettings.current().set_value("voice", "feed_url", "")
	GameSettings.current().set_value("gameplay", "practice", true)
	VoiceCommands.cover_wait = 0.0
	var main := await _arena()
	var voice := VoiceCommands.of(main)
	await _key(KEY_P)
	await _frames(4)
	var out := voice != null and voice.drone != null and is_instance_valid(voice.drone)
	_check("the cover key (P) sends the drone out, no recharge yet", out and VoiceCommands.cover_wait == 0.0)
	var old_id := main.get_instance_id()
	await _key(KEY_R)
	var next := await _after_reload(old_id)
	var again := VoiceCommands.of(next)
	var said: String = again.cover_me(false) if again != null else ""
	_check("W7's known issue fixed: a drone out when the arena reloads (R) starts its recharge as it goes (%.0f s), so the reloaded arena refuses a fresh one and says when (\"%s\")" % [VoiceCommands.cover_wait, said], again != null and again.drone == null and VoiceCommands.cover_wait > VoiceCommands.COVER_COOL_S - 5.0 and said.begins_with("recharging"))
	VoiceCommands.cover_wait = 0.0
	var fresh: String = again.cover_me(false) if again != null else ""
	_check("the recharge done, the key sends a drone again (the fix holds back only a reload's free drone)", fresh.begins_with("drone out") and again.drone != null)
	await _frames(2)
	GameSettings.current().set_value("gameplay", "practice", false)


# --- W2 to W5: a match starting mid-mode. ---

func _match_checks() -> void:
	var modes := [
		{"name": "the folder map (W2)", "queue": func(): FolderMap.queue(), "of": func(m): return FolderMap.of(m), "queued": func(): return FolderMap.queued},
		{"name": "the theme shift (W3)", "queue": func(): ThemeShift.queue(), "of": func(m): return ThemeShift.of(m), "queued": func(): return ThemeShift.queued},
		{"name": "keybind gunplay (W4)", "queue": func(): KeybindGunplay.queue(), "of": func(m): return KeybindGunplay.of(m), "queued": func(): return KeybindGunplay.queued},
		{"name": "the packet tracer (W5)", "queue": func(): PacketTracer.queue(), "of": func(m): return PacketTracer.of(m), "queued": func(): return PacketTracer.queued},
	]
	for mode in modes:
		_clear_modes()
		mode["queue"].call()
		var main := await _arena()
		var it = mode["of"].call(main)
		await _until(func(): return it != null and is_instance_valid(it) and it.running)
		await _frames(20)
		var district_before := RuinsWorld.of(main) != null or _has_net(main)
		var running_before: bool = it != null and is_instance_valid(it) and it.running
		var session = it.director.session
		var hosted: bool = session != null and session.host(0)
		var old_id := main.get_instance_id()
		var next := await _after_reload(old_id, RELOAD_FRAMES)
		# No reload at all is the old bug: the mode ended, its district left standing under the match.
		var arena: Node = next if next != null else main
		var now = mode["of"].call(arena) if is_instance_valid(arena) else null
		var targets := 0
		var plain := false
		if is_instance_valid(arena) and arena.is_inside_tree():
			targets = arena.get_tree().get_nodes_in_group("targets").filter(func(t): return arena.is_ancestor_of(t)).size()
			plain = RuinsWorld.of(arena) == null and not _has_net(arena)
		_check("%s: a match starts (the game's session hosts)" % mode["name"], hosted)
		_check("%s's known issue fixed: a match starting mid-mode ends it and reloads into the plain arena: it ran in its own world first (%s), then the next arena has no district, the mode neither running nor queued, the arena's own %d daemons back" % [mode["name"], "yes" if district_before else "no", targets], running_before and district_before and next != null and plain and now != null and not now.running and not mode["queued"].call() and targets == 4, "" if next != null else "no reload: the district still standing" if not plain else "no reload")
		if session != null and is_instance_valid(session):
			session.leave()
		await _frames(4)


## Whether the packet tracer's invented network stands under this arena.
func _has_net(main: Node) -> bool:
	for n in main.find_children("*", "", true, false):
		if n is PacketNet and not n.is_queued_for_deletion():
			return true
	return false


# --- The arena. ---

func _arena() -> Node:
	MissionRunner.clear_pending()
	for old in root.get_children():
		if old.scene_file_path == "res://scenes/main.tscn":
			await _drop(old)
	GameSettings.current().set_value("gameplay", "difficulty", "normal")
	GameSettings.current().set_value("gameplay", "ice", false)
	var link := Link.new()
	link.settings_path = _abs.path_join("privacy.cfg")
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
	var player = main.get_node("Player")
	player.assume_captured = true
	player.velocity = Vector3.ZERO
	await _frames(3)


func _after_reload(old_id: int, most: int = MOST_FRAMES) -> Node:
	await _until(func(): return current_scene != null and current_scene.get_instance_id() != old_id and current_scene.has_node("Hud") and current_scene.is_node_ready(), most)
	var main := current_scene
	if main == null or main.get_instance_id() == old_id:
		return null
	await _ready_arena(main)
	await _frames(2)
	return main


func _cleanup() -> void:
	MissionRunner.clear_pending()
	_clear_modes()
	for node in root.get_children():
		if node.scene_file_path == "res://scenes/main.tscn":
			await _drop(node)
	current_scene = null
	VoiceCommands.cover_wait = 0.0
	GameSettings.current().reset()
	MissionProgress.current().path = ""
	MissionProgress.current().clear()
	Progress.current().path = ""
	Progress.current().clear()
	_wipe(_abs)
	_check("the test's own folder is gone, nothing of it left under user://", not DirAccess.dir_exists_absolute(_abs))


## The test's own folder only, file by file.
func _wipe(path: String) -> void:
	if not path.begins_with(ProjectSettings.globalize_path("user://polish-test-")):
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.include_hidden = true
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := path.path_join(name)
		if dir.current_is_dir() and not dir.is_link(name):
			_wipe(full)
		else:
			DirAccess.remove_absolute(full)
		name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)


func _drop(main: Node) -> void:
	if is_instance_valid(main):
		for sfx in main.find_children("*", "AudioStreamPlayer", true, false):
			(sfx as AudioStreamPlayer).stop()
		for sfx in main.find_children("*", "AudioStreamPlayer3D", true, false):
			(sfx as AudioStreamPlayer3D).stop()
		if current_scene == main:
			current_scene = null
		main.queue_free()
		await _frames(3)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _until(condition: Callable, most: int = MOST_FRAMES) -> bool:
	var frames := 0
	while frames < most and not condition.call():
		await process_frame
		frames += 1
	return condition.call()


func _key(code: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var up := down.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame
