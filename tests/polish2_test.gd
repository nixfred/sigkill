extends SceneTree
## Headless test of P2, the second polish pass. scripts/check.sh runs it as step 73, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/polish2_test.gd
##
## Each section pins one item P2 fixed, so it cannot come back:
## - W3's Latte zombie: under a light theme every zombie the theme shift fights wears an outline (an inverted hull in a
##   red the grade takes to the theme's red), from its first frame; under a dark theme none does, and nothing but a
##   zombie ever does; a tear to a dark theme takes it off and a tear back puts it on.
## - M7's refused hit and bolts: a hit the target refuses (M7's shell, anything but kill -9) is not a landed hit: nothing
##   off it, no hot flash, a steel hexagon ripple where it met facing the shot, the blocked marker and never the hit
##   marker, the shot not counted as landed; the shell's bolts in its own deep red, bigger and drawn out.
## Demo data only: every mode runs on its made-up layer (the real-data opt-in stays off), and nothing real is read.

const MainScene = preload("res://scenes/main.tscn")
const Link = preload("res://scripts/guide/guide_link.gd")
const Controls = preload("res://scripts/controls.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")
const Palette = preload("res://scripts/palette.gd")

const MOST_FRAMES := 3600
const LONG_ROUND_S := 100000.0


var _checks := 0
var _fails := 0
var _abs := ""
## The sections that ran to their end: a script error mid-section stops that section, and the last check says so by name.
var _done: Array = []
const SECTIONS := ["latte", "refused"]


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_abs = ProjectSettings.globalize_path("user://polish2-test-%d" % OS.get_process_id())
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
	await _latte_checks()
	await _refused_checks()
	await _cleanup()
	_check("every section ran to its end (%s)" % ", ".join(_done), _done == SECTIONS, "wanted %s" % ", ".join(SECTIONS))
	print("POLISH2: %d checks" % _checks)
	print("POLISH2 RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
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


# --- W3: the Latte zombie. ---

func _latte_checks() -> void:
	var code := FileAccess.get_file_as_string("res://shaders/light_outline.gdshader")
	_check("the outline is an inverted hull: front faces culled, unshaded", code.contains("cull_front") and code.contains("unshaded"))
	var latte := ThemeLook.of(OpenerPalette.named("latte").readable())
	var ink: Color = LightOutline.material().get_shader_parameter("ink")
	var on_paper: Color = latte.grade(ink)
	var paper: Color = latte.grade(Palette.VOID)
	var red: Color = latte.grade(Color(1.0, 0.0, 0.0))
	_check("under Latte the rim grades to the theme's red, dark on its paper (rim luma %.2f, paper %.2f)" % [ThemeLook.luma(on_paper), ThemeLook.luma(paper)], ThemeLook.luma(paper) - ThemeLook.luma(on_paper) > 0.35 and on_paper.r > on_paper.g + 0.2 and _close(on_paper, red, 0.12), "%s against %s" % [on_paper.to_html(false), red.to_html(false)])
	# Tokyo Night first (level 0, a dark theme): no zombie outlined.
	ThemeShift.queue()
	var main := await _arena()
	var mode := await _running_mode(main)
	if mode == null:
		_check("the theme shift runs its first level", false, "never ran")
		return
	var z: Node = mode._spawn_daemon("zombie", _beside(main, 6.0), "p2_night")
	await _frames(3)
	_check("a dark theme (%s) outlines nothing: its zombie as it was" % mode.theme, not mode.look_of(mode.theme).light and not mode.outlined() and not LightOutline.worn(z.art_node()))
	# Catppuccin Latte (the last level, the light one): every zombie outlined, nothing else.
	ThemeShift.level = ThemeShift.run.size() - 1
	ThemeShift.queued = true
	var old_id := main.get_instance_id()
	MissionRunner.reload_after_mount(self, "$ reset")
	main = await _after_reload(old_id)
	mode = await _running_mode(main)
	if mode == null:
		_check("the theme shift runs its Latte level", false, "never ran")
		return
	var fresh: Node = mode._spawn_daemon("zombie", _beside(main, 6.0), "p2_latte")
	var other: Node = mode._spawn_daemon("rogue", _beside(main, -6.0), "p2_rogue")
	await _frames(3)
	var zombies := 0
	var worn := 0
	var others_worn := 0
	for e in mode.enemies:
		if not is_instance_valid(e["body"]):
			continue
		if str(e["kind"]) == "zombie":
			zombies += 1
			worn += 1 if LightOutline.worn(e["body"].art_node()) else 0
		elif LightOutline.worn(e["body"].art_node()):
			others_worn += 1
	_check("acceptance: under Catppuccin Latte every zombie wears the outline (%d of %d), one spawned mid-level from its first frame" % [worn, zombies], mode.theme == "latte" and mode.outlined() and zombies >= 1 and worn == zombies and LightOutline.worn(fresh.art_node()))
	_check("nothing but a zombie is outlined: the rogue.d and the rest as they were (%d others outlined)" % others_worn, others_worn == 0 and not LightOutline.worn(other.art_node()))
	var sets: Array = fresh.art_node().sets()
	var glyphs = fresh.art_node().glyphs()
	_check("the outline is on every set the zombie is drawn in (%d of %d), never its glyphs" % [LightOutline.worn_count(fresh.art_node()), sets.size()], sets.size() >= 2 and LightOutline.worn_count(fresh.art_node()) == sets.size() and (glyphs == null or glyphs.material_overlay == null))
	mode._set_glow(0.0)  # a tear to a dark theme, at its end
	_check("a tear to a dark theme takes it off every zombie", not mode.outlined() and not LightOutline.worn(fresh.art_node()))
	mode._set_glow(1.0)
	_check("and a tear back to a light one puts it on again", mode.outlined() and LightOutline.worn(fresh.art_node()))
	mode.end()
	await _frames(3)
	ThemeShift.clear()
	_done.append("latte")


# --- M7: the refused hit and the shell's bolts. ---

func _refused_checks() -> void:
	var shell: Dictionary = GlitchBolt.look_for("shell")
	var amber: Dictionary = GlitchBolt.look_for("zombie")
	var core: Color = (shell["core"] as StandardMaterial3D).albedo_color
	_check("the shell's bolts in its own red: a deep red core (g/r %.2f), never washed to white, 1.35 wide and twice as long as a zombie's" % (core.g / core.r), shell["tint"] == Palette.CRIMSON and core.g / core.r < 0.5 and (shell["scale"] as Vector3).z >= 2.0 and (shell["scale"] as Vector3).x > 1.2)
	_check("every other thrower's bolt as it was: amber, its usual size", amber["tint"] == Palette.HOSTILE_AMBER and amber["scale"] == Vector3.ONE)
	var marker = load("res://scripts/hit_marker.gd").new()
	root.add_child(marker)
	marker.configure(0.3, 8.0, 6.0, 2.0)
	marker.show_blocked()
	var blocked: bool = marker.blocked()
	marker.show_hit()
	_check("the hit marker has a refusal's own look (the blocked hexagon), and a hit after it is a hit again", blocked and not marker.blocked() and marker.alpha() > 0.0)
	marker.free()
	# In the arena: a daemon that takes only kill -9, the cannon fired at it.
	GameSettings.current().set_value("gameplay", "practice", true)
	var main := await _arena()
	await _frames(30)
	var player = main.get_node("Player")
	var target: Node3D = null
	var best := INF
	for t in get_nodes_in_group("targets"):
		if t is Node3D and t.has_method("refuses") and t.call("is_alive"):
			var d: float = (t as Node3D).global_position.distance_to(player.global_position)
			if d < best:
				best = d
				target = t
	if target == null:
		_check("a daemon to refuse the cannon", false, "none in the arena")
		return
	target.set("only_from", PackedStringArray(["sigkill_rail"]))
	var health0: float = target.call("health")
	var said := [0]
	var landed := []
	player.shot_refused.connect(func(): said[0] += 1)
	player.shot_fired.connect(func(hit): landed.append(hit))
	var struck := []
	target.struck.connect(func(_d, source, was_landed): struck.append([source, was_landed]))
	player.select_slot(int(player.inventory.slot_of("terminal_cannon")))
	await _frames(40)
	var marker2 = main.get_node("Hud").get("_hit_marker")
	for i in 3:
		_aim(player, target.threat_point())
		player.drive_input(Vector2.ZERO, false, false, true)
		await physics_frame
	player.drive_input(Vector2.ZERO)
	await _frames(2)
	var ripples := get_nodes_in_group(RefusedFx.GROUP)
	var faces := false
	if not ripples.is_empty():
		var to_shooter: Vector3 = (player.global_position - (ripples[0] as Node3D).global_position).normalized()
		faces = (ripples[0] as Node3D).global_transform.basis.z.normalized().dot(to_shooter) > 0.5
	_check("acceptance: a refused hit is not a landed one: nothing off it (%.0f of %.0f), the target says it struck and did not land, the shot not counted as landed" % [target.call("health"), health0], is_equal_approx(float(target.call("health")), health0) and struck.any(func(s): return s[0] == "terminal_cannon" and s[1] == false) and not landed.is_empty() and not landed.has(true))
	_check("acceptance: a refused hit reads as one: a steel ripple where it met, facing the shot (%d), and the blocked marker up, never the hit marker (said %d)" % [ripples.size(), said[0]], ripples.size() >= 1 and faces and said[0] >= 1 and marker2 != null and marker2.blocked())
	_check("kill -9 is still taken (refuses: sigterm yes, the rail no)", target.call("refuses", "sigterm") and not target.call("refuses", "sigkill_rail"))
	await _frames(int(RefusedFx.LIFE_S * 60.0) + 10)
	_check("the ripple frees itself after its life", get_nodes_in_group(RefusedFx.GROUP).is_empty())
	target.set("only_from", PackedStringArray())
	GameSettings.current().set_value("gameplay", "practice", false)
	_done.append("refused")


func _aim(player: Node, at: Vector3) -> void:
	var cam: Camera3D = player.get_node("Head/Camera")
	var to: Vector3 = at - cam.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	player.get_node("Head").rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


func _close(a: Color, b: Color, most: float) -> bool:
	return absf(a.r - b.r) <= most and absf(a.g - b.g) <= most and absf(a.b - b.b) <= most


## A point on the floor `side` metres to the player's right.
func _beside(main: Node, side: float) -> Vector3:
	var p: Node3D = main.get_node("Player")
	return p.global_position + p.global_transform.basis.x * side + Vector3(0, 0, -8.0)


## The theme shift running in `main`, through the reload into its district if one comes first.
func _running_mode(main: Node) -> ThemeShift:
	var mode := ThemeShift.of(main)
	await _until(func(): return (mode != null and mode.running) or current_scene != main, 600)
	if mode != null and mode.running:
		await _frames(2)
		return mode
	main = await _after_reload(main.get_instance_id())
	if main == null:
		return null
	mode = ThemeShift.of(main)
	await _until(func(): return mode != null and mode.running, 600)
	await _frames(2)
	return mode if mode != null and mode.running else null


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
	if not path.begins_with(ProjectSettings.globalize_path("user://polish2-test-")):
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
