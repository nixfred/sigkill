extends SceneTree
## Headless enemy art test for SIGKILL (A2, its checks moved onto A2b's creatures). scripts/check.sh
## runs it, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/enemy_art_test.gd
##
## The daemons' look (A2), visual only. The sources: every dummy of the arena names its art (the
## rogue daemon, the zombie process for the zombie and the defunct one, the runaway swarm), a script
## that is not art gets the plain look; the art code touches nothing outside the game and builds
## nothing while it is drawn; its shaders run on the daemon's own clock, not the wall clock; the hit
## volume is byte for byte as it was before A2 (the dummy's collision shape, layer and mask, and the
## arena's dummies' places), and nothing under the art can collide; the avatars' derezz is the same
## effect. Each type built alone: inside its own triangle and draw-call budget, three different
## shapes, its core in its own palette colour, every daemon of every type sharing one obsidian, one
## core, one trail and one glyph material; moving by transforms only, the meshes never rebuilt; its
## clock at the game's pace (half as fast at half the engine's time, as SIGSTOP makes it); the hit
## flash and the rematerialise glitch reaching the shaders. (Since A2b each type is a posed creature,
## tests/enemy_motion_test.gd checks its motion.) In the real arena: each dummy drawn by its art, its hex
## volume by no camera; a grep mark sweeping the lock onto the marked daemon alone; a hit that does
## not kill flashing it; a kill's derezz with its flash, freeing itself on time, the daemon back after
## the respawn delay, glitching as it grows, whole again after the rematerialise time.
## Deterministic: frames counted, only counts and outcomes printed.

const Link = preload("res://scripts/guide/guide_link.gd")
const MainScene = preload("res://scenes/main.tscn")
const DummyScene = preload("res://scenes/target_dummy.tscn")
const Palette = preload("res://scripts/palette.gd")
const Controls = preload("res://scripts/controls.gd")
const DerezzFx = preload("res://scripts/derezz_fx.gd")
const Dummy = preload("res://scripts/target_dummy.gd")
const ART_DIR := "res://scripts/daemons/"
const TYPES := {"rogue_daemon": Palette.HOSTILE_RED, "zombie_process": Palette.HOSTILE_AMBER, "runaway_swarm": Palette.HOSTILE_RED}
const ARENA_ART := {"DummyA": "rogue_daemon", "DummyB": "zombie_process", "DummyC": "zombie_process", "DummyD": "runaway_swarm"}
## The fewest triangles a daemon may take (each type sets its own most, triangles and draw calls).
const TRIANGLES_FIRST := 120
## The hit volume as it was before A2 (15e777d), byte for byte.
const SHAPE_TEXT := "[sub_resource type=\"CylinderShape3D\" id=\"CylinderShape3D_dummy\"]\nheight = 1.8\nradius = 0.55\n"
const SHAPE_NODE_TEXT := "[node name=\"Shape\" type=\"CollisionShape3D\" parent=\".\"]\nposition = Vector3(0, 0.9, 0)\nshape = SubResource(\"CylinderShape3D_dummy\")\n"
const ROOT_TEXT := "[node name=\"TargetDummy\" type=\"StaticBody3D\" groups=[\"targets\"]]\ncollision_layer = 4\ncollision_mask = 0\n"
const PLACES := ["[node name=\"DummyA\" parent=\"Targets\" instance=ExtResource(\"2_dummy\")]\nposition = Vector3(0, 0, -15)\n", "[node name=\"DummyB\" parent=\"Targets\" instance=ExtResource(\"2_dummy\")]\nposition = Vector3(-17.5, 0, 5)\n", "[node name=\"DummyC\" parent=\"Targets\" instance=ExtResource(\"2_dummy\")]\nposition = Vector3(12, 0, 5)\n", "[node name=\"DummyD\" parent=\"Targets\" instance=ExtResource(\"2_dummy\")]\nposition = Vector3(-8, 1, 12)\n"]
const EPS := 0.0005

## A type with no parts of its own and no glyphs, which never poses (A2's self-review pass 2, on
## A2b's rig): it must build and draw with no error, its hit spray its only set.
class NoParts extends DaemonArt:
	func _build() -> void:
		glyph_count = 0

	func _pose(_t: float, _delta: float) -> void:
		pass


var _fails := 0
var _checks := 0
var _tmp := ""
var _scratch: Array = []
var _arenas: Array = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_tmp = OS.get_temp_dir().path_join("sigkill-enemy-art-test-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(_tmp)
	Controls.ensure()
	_source_checks()
	await _type_checks()
	await _arena_checks()
	await _cleanup()
	for name in DirAccess.get_files_at(_tmp):
		DirAccess.remove_absolute(_tmp.path_join(name))
	DirAccess.remove_absolute(_tmp)
	print("ENEMY ART: %d checks" % _checks)
	print("ENEMY ART RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The sources. ---

func _source_checks() -> void:
	var arena := FileAccess.get_file_as_string("res://scenes/arena.tscn")
	var wrong := PackedStringArray()
	for dummy in ARENA_ART:
		var block := _block(arena, "[node name=\"%s\"" % dummy)
		var art: String = ARENA_ART[dummy]
		var id := "5_zombie" if art == "zombie_process" else ("6_swarm" if art == "runaway_swarm" else "")
		var named := block.contains("art = ExtResource(\"%s\")" % id) if id != "" else not block.contains("art = ")
		if not named:
			wrong.append(dummy)
	var dummy_script := _code("res://scripts/target_dummy.gd")
	_check("acceptance: every daemon of the arena names its art: rogue.d the rogue daemon (the dummy's own default), the zombie and the defunct one the zombie process, the runaway the swarm of drones", wrong.is_empty() and dummy_script.contains("@export var art: Script = preload(\"res://scripts/daemons/rogue_daemon.gd\")") and arena.contains("path=\"res://scripts/daemons/zombie_process.gd\" id=\"5_zombie\"") and arena.contains("path=\"res://scripts/daemons/runaway_swarm.gd\" id=\"6_swarm\""), ", ".join(wrong))
	var plain := DaemonArt.make(load("res://scripts/palette.gd"))
	var plain_ok: bool = plain.get_script() == DaemonArt and plain.triangles() > 0
	plain.free()
	_check("a target naming a script that is not art gets the plain look, built", plain_ok)
	var code := _code("res://scripts/art/shape_kit.gd")
	for name in DirAccess.get_files_at(ART_DIR):
		if name.ends_with(".gd"):
			code += _code(ART_DIR + name)
	var found := PackedStringArray()
	for word in ["OS.", "execute", "create_process", "DirAccess", "FileAccess", "move_to_trash", "shell_open", "Thread", "HTTP", "PacketPeer", "StreamPeer", "Expression", "rpc", "Time."]:
		if code.contains(word):
			found.append(word)
	if RegEx.create_from_string("(?<!pre)load\\(").search(code) != null:
		found.append("load(")
	_check("acceptance: the art code is cosmetic only: no OS call, no file or folder access, no thread, socket or network, no wall clock, nothing loaded at run time, no RPC", found.is_empty() and code.length() > 9000, ", ".join(found))
	var art := _code(ART_DIR + "daemon_art.gd")
	var held := ""
	for name in ["_process", "_send", "_marked", "flash", "react", "set_unstable", "_pose_spray", "put", "bone", "orient", "present", "brighten", "conceal"]:
		held += _body(art, name)
	held += _body(dummy_script, "_physics_process") + _body(dummy_script, "_pulse")
	var rebuilt := PackedStringArray()
	for word in ["SurfaceTool", "commit(", "ArrayMesh", "Mesh.new", ".new(", "add_child", "duplicate", "_build", "Material"]:
		if held.contains(word):
			rebuilt.append(word)
	_check("acceptance: nothing is rebuilt while a daemon is drawn: what runs each frame (its posing, its clock, the flash, the recoil and the spray, the lock, the glitch) makes no mesh, node or material", rebuilt.is_empty() and held.length() > 1200, ", ".join(rebuilt))
	var shaders := {}
	for name in ["daemon_shell", "daemon_core", "daemon_glyphs", "daemon_split", "daemon_trail", "derezz_voxel"]:
		shaders[name] = _shader_code("res://shaders/%s.gdshader" % name)
	var glitch := _shader_code("res://shaders/daemon_glitch.gdshaderinc")
	var clocked := not glitch.contains("TIME") and glitch.contains("global uniform float daemon_clock")
	for name in ["daemon_shell", "daemon_core", "daemon_split"]:
		var text: String = shaders[name]
		var raw := FileAccess.get_file_as_string("res://shaders/%s.gdshader" % name)
		clocked = clocked and raw.contains("\n#include \"res://shaders/daemon_glitch.gdshaderinc\"\n") and not text.contains("TIME")
	clocked = clocked and (shaders["daemon_glyphs"] as String).contains("global uniform float daemon_clock") and not (shaders["daemon_glyphs"] as String).contains("TIME") and not (shaders["daemon_trail"] as String).contains("TIME")
	_check("acceptance: the daemons' shaders are in the repo and run on the daemons' shared clock (a shader global stepped at the game's pace, so SIGSTOP slows them), never the wall clock; the derezz voxels' shader too", clocked and not (shaders["derezz_voxel"] as String).contains("TIME") and (shaders["derezz_voxel"] as String).contains("discard"))
	var dummy_scene := FileAccess.get_file_as_string("res://scenes/target_dummy.tscn")
	var places_ok := true
	for place in PLACES:
		places_ok = places_ok and arena.contains(place)
	_check("acceptance: the hit volume is byte for byte as before A2: the dummy's collision shape (1.8 m by 0.55 m), its place, layer 4 and mask 0, and the arena's four dummies where they were", dummy_scene.contains(SHAPE_TEXT) and dummy_scene.contains(SHAPE_NODE_TEXT) and dummy_scene.contains(ROOT_TEXT) and places_ok)
	var avatar := _code("res://scripts/net/remote_player.gd")
	_check("the players' own death is the same derezz: an avatar's die() plays the one DerezzFx", _body(avatar, "die").contains("var fx := DerezzFx.new()") and avatar.contains("const DerezzFx = preload(\"res://scripts/derezz_fx.gd\")"))


# --- Each type built alone. ---

func _type_checks() -> void:
	var world := Node3D.new()
	root.add_child(world)
	_scratch.append(world)
	var arts := {}
	var shapes := {}
	var budget := PackedStringArray()
	var cores := PackedStringArray()
	var shared := PackedStringArray()
	var report := PackedStringArray()
	var shell_mats := {}
	var core_mats := {}
	var trail_mats := {}
	var glyph_mats := {}
	for type in TYPES:
		var art := DaemonArt.make(load(ART_DIR + type + ".gd"))
		art.position = Vector3(3.0 * arts.size(), 0.0, 0.0)
		world.add_child(art)
		arts[type] = art
	await physics_frame
	for type in arts:
		var art: DaemonArt = arts[type]
		var tris := art.triangles()
		var draws := art.draw_calls()
		report.append("%s %d triangles, %d draw calls (budget %d, %d)" % [type, tris, draws, art.budget_triangles, art.budget_draw_calls])
		if tris < TRIANGLES_FIRST or tris > art.budget_triangles or draws > art.budget_draw_calls:
			budget.append("%s %d/%d" % [type, tris, draws])
		var box := art.pose_bounds()
		shapes["%d %d %d %d" % [roundi(box.size.x * 100.0), roundi(box.size.y * 100.0), roundi(box.size.z * 100.0), tris]] = type
		var core := art.core_set()
		var core_mat := core.material_override as ShaderMaterial if core != null else null
		if core_mat == null or core_mat.shader.resource_path.get_file() != "daemon_core.gdshader" or core.get_instance_shader_parameter("core_color") != TYPES[type]:
			cores.append(type)
		for node in art.find_children("*", "GeometryInstance3D", true, false):
			var mat := (node as GeometryInstance3D).material_override as ShaderMaterial
			var file := mat.shader.resource_path.get_file() if mat != null else ""
			if not node is MultiMeshInstance3D:
				shared.append("%s %s is no MultiMesh" % [type, node.name])
			elif file == "daemon_shell.gdshader" and mat.next_pass is ShaderMaterial and (mat.next_pass as ShaderMaterial).shader.resource_path.get_file() == "daemon_split.gdshader":
				shell_mats[mat.get_instance_id()] = true
			elif file == "daemon_core.gdshader":
				core_mats[mat.get_instance_id()] = true
			elif file == "daemon_trail.gdshader":
				trail_mats[mat.get_instance_id()] = true
			elif file == "daemon_glyphs.gdshader":
				glyph_mats[mat.get_instance_id()] = true
			else:
				shared.append("%s %s" % [type, file])
	print("ENEMY ART types: " + "; ".join(report))
	_check("acceptance: every type inside its budget: at least %d triangles, and no more triangles or draw calls than it allows" % TRIANGLES_FIRST, budget.is_empty(), ", ".join(budget))
	_check("acceptance: three different shapes: no two types share their size and triangle count", shapes.size() == TYPES.size(), str(shapes.size()))
	_check("acceptance: every core glows in its type's own palette colour through the shared core shader: hostile red for the rogue daemon and the swarm, hostile amber for the zombie", cores.is_empty(), ", ".join(cores))
	_check("acceptance: every daemon of every type shares one obsidian (its split the next pass), one core, one trail and one glyph material (instance uniforms, no shader of its own), every part in a MultiMesh", shared.is_empty() and shell_mats.size() == 1 and core_mats.size() == 1 and trail_mats.size() == 1 and glyph_mats.size() == 1, "%s; %d %d %d %d" % [", ".join(shared), shell_mats.size(), core_mats.size(), trail_mats.size(), glyph_mats.size()])
	var meshes := _mesh_ids(arts.values())
	var turns := {}
	for type in arts:
		turns[type] = _poses(arts[type])
	var clock_before: float = arts["rogue_daemon"].clock()
	for i in 60:
		await process_frame
	var clock_full: float = arts["rogue_daemon"].clock() - clock_before
	var turned := 0
	for type in arts:
		var now := _poses(arts[type])
		for k in now.size():
			turned += 1 if not now[k].is_equal_approx(turns[type][k]) else 0
	_check("acceptance: drawn, the daemons move by their parts' transforms alone: parts moved, and every mesh and MultiMesh the very one it was built with", _mesh_ids(arts.values()) == meshes and turned >= 60, "%d parts moved" % turned)
	Engine.time_scale = 0.5
	clock_before = arts["rogue_daemon"].clock()
	for i in 60:
		await process_frame
	var clock_half: float = arts["rogue_daemon"].clock() - clock_before
	Engine.time_scale = 1.0
	_check("acceptance: a daemon's clock runs at the game's pace: half as far at half the engine's time, as SIGSTOP slows the world alone", clock_full > 0.9 and absf(clock_half - clock_full * 0.5) < 0.02, "%.3f s then %.3f s" % [clock_full, clock_half])
	var rogue: DaemonArt = arts["rogue_daemon"]
	var shell: GeometryInstance3D = null
	for i in rogue.sets().size():
		if shell == null and rogue.set_look(i) == DaemonArt.Look.SHELL:
			shell = rogue.sets()[i]
	rogue.flash()
	var flashed: bool = is_equal_approx(rogue.hit_glow(), 1.0) and is_equal_approx(shell.get_instance_shader_parameter("hit"), 1.0) and is_equal_approx(rogue.glyphs().get_instance_shader_parameter("hit"), 1.0)
	for i in ceili(DaemonArt.FLASH_S * 60.0) + 2:
		await process_frame
	var faded: bool = rogue.hit_glow() == 0.0 and shell.get_instance_shader_parameter("hit") == 0.0
	rogue.set_unstable(0.7)
	var glitching: bool = is_equal_approx(shell.get_instance_shader_parameter("unstable"), 0.7)
	rogue.set_unstable(0.0)
	_check("a hit's flash and the rematerialise glitch reach the shaders: the flash at once, gone after %.2f s" % DaemonArt.FLASH_S, flashed and faded and glitching)
	var sparse := NoParts.new()
	sparse.setup(null)
	world.add_child(sparse)
	for i in 30:
		await process_frame
	sparse.react(Vector3(0.0, 1.0, 1.0), Vector3.FORWARD)
	for i in 40:
		await process_frame
	_check("a type with no parts of its own, no glyphs and no pose builds, draws and reacts (an error here fails the gate): its spray its only set", sparse.part_count() == DaemonArt.SPRAY and sparse.sets().size() == 1 and sparse.glyphs() == null and sparse.draw_calls() == 1 and sparse.triangles() == DaemonArt.SPRAY * 30)


## Every part's transform of a daemon and its glyphs' basis, in order.
func _poses(art: DaemonArt) -> Array:
	var out := []
	for id in art.part_count():
		out.append(art.part_transform(id))
	if art.glyphs() != null:
		out.append(Transform3D(art.glyphs().basis, Vector3.ZERO))
	return out


# --- In the real arena. ---

func _arena_checks() -> void:
	var side := await _arena()
	var main: Node = side["main"]
	var p: Node = side["player"]
	var dummies := {}
	for name in ARENA_ART:
		dummies[name] = main.get_node("Arena/Targets/" + name)
	var drawn := PackedStringArray()
	for name in dummies:
		var dummy: Node = dummies[name]
		var body := dummy.get_node("Body") as MeshInstance3D
		var art: DaemonArt = dummy.art_node()
		var colliders := art.find_children("*", "CollisionObject3D", true, false).size() + art.find_children("*", "CollisionShape3D", true, false).size()
		if art == null or art.get_parent() != body or body.layers != 0 or body.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF or not art.is_visible_in_tree() or colliders != 0 or art.get_script().resource_path.get_file().get_basename() != ARENA_ART[name]:
			drawn.append(name)
	_check("acceptance: each daemon of the arena is drawn by its own art under its Body, which hides and grows with it; the hex volume is drawn by no camera; nothing under the art can collide", drawn.is_empty(), ", ".join(drawn))
	await _lock_checks(p, dummies)
	await _flash_checks(main)
	await _derezz_checks(p, dummies["DummyA"])


func _lock_checks(p: Node, dummies: Dictionary) -> void:
	var lock: Node = p.get("grep")
	lock.marks.append({"target": dummies["DummyB"], "id": 0, "lost_s": 0.0})
	for i in 18:
		await process_frame
	var marked: float = dummies["DummyB"].art_node().lock_glow()
	var others := 0.0
	for name in ["DummyA", "DummyC", "DummyD"]:
		others = maxf(others, dummies[name].art_node().lock_glow())
	lock.marks.clear()
	for i in 18:
		await process_frame
	var after: float = dummies["DummyB"].art_node().lock_glow()
	_check("acceptance: a grep mark sweeps the lock onto the marked daemon alone, within %.1f s, and off again once the mark goes" % (DaemonArt.LOCK_POLL_S + 1.0 / DaemonArt.LOCK_EASE), is_equal_approx(marked, 1.0) and others == 0.0 and after == 0.0, "marked %.2f, others %.2f, after %.2f" % [marked, others, after])


func _flash_checks(main: Node) -> void:
	var tough = DummyScene.instantiate()
	tough.max_health = 3.0
	tough.position = Vector3(30.0, 0.0, 30.0)
	main.get_node("Arena/Targets").add_child(tough)
	await physics_frame
	var landed: bool = tough.hit(1.0, tough.global_position)
	var glow: float = tough.art_node().hit_glow()
	_check("a hit that does not kill flashes the daemon's art", landed and is_equal_approx(glow, 1.0) and tough.state == Dummy.State.ALIVE)
	tough.queue_free()
	await physics_frame


func _derezz_checks(p: Node, dummy: Node) -> void:
	var d: Resource = dummy.get("_d")
	var art: DaemonArt = dummy.art_node()
	dummy.hit(100.0, dummy.global_position + Vector3(0.0, 0.9, 1.0), Vector3.FORWARD)
	await physics_frame
	var fx: Array = get_nodes_in_group(DerezzFx.FX_GROUP)
	var effect: Node = fx[0] if fx.size() == 1 else null
	var flash_on: bool = effect != null and effect.flashing() and effect.get_node_or_null("Column") != null and effect.get_node_or_null("Ring") != null
	var shader_ok: bool = effect != null and (effect.material_override as ShaderMaterial).shader.resource_path.get_file() == "derezz_voxel.gdshader"
	var hidden: bool = not art.is_visible_in_tree()
	var one := effect != null  # read now: the effect frees itself before the check
	var frames := 0
	var flash_frames := -1
	var gone_frames := -1
	while frames < 600:
		await physics_frame
		frames += 1
		if flash_frames < 0 and is_instance_valid(effect) and not effect.flashing():
			flash_frames = frames
		if gone_frames < 0 and get_nodes_in_group(DerezzFx.FX_GROUP).is_empty():
			gone_frames = frames
		if dummy.state == Dummy.State.RESPAWNING:
			break
	var respawn_at := frames
	var unstable: float = art.unstable()
	var visible_again: bool = art.is_visible_in_tree()
	while dummy.state != Dummy.State.ALIVE and frames < 900:
		await physics_frame
		frames += 1
	var alive_at := frames
	print("ENEMY ART derezz: flash gone after %d frames, effect gone after %d, rematerialising after %d, alive after %d" % [flash_frames, gone_frames, respawn_at, alive_at])
	_check("acceptance: a kill derezzes the daemon with the upgraded effect: one derezz, its edged voxels' shader, a light column and a ground ring that go in %.2f s, the art hidden with its body" % DerezzFx.FLASH_S, one and flash_on and shader_ok and hidden and absi(flash_frames - ceili(DerezzFx.FLASH_S * 60.0)) <= 2, "flash gone after %d frames" % flash_frames)
	_check("acceptance: the derezz keeps its timing: it frees itself within its voxels' longest life, the daemon starts back after the respawn delay and is whole after the rematerialise time", gone_frames > 0 and gone_frames <= ceili(d.lifetime_max * 60.0) + 3 and absi(respawn_at - ceili(d.respawn_delay * 60.0)) <= 2 and absi(alive_at - respawn_at - ceili(d.rematerialise_seconds * 60.0)) <= 2)
	_check("acceptance: it glitches as it grows back, and is steady once whole", visible_again and unstable > 0.8 and art.unstable() == 0.0 and art.is_visible_in_tree(), "unstable %.2f at the start" % unstable)


# --- Helpers. ---

func _arena() -> Dictionary:
	var link := Link.new()
	link.settings_path = _tmp.path_join("arena-privacy.cfg")
	link.demo = true
	Link.park(link)
	var main = MainScene.instantiate()
	root.add_child(main)
	_arenas.append(main)
	var hud = main.get_node("Hud")
	hud.guide().focus_check = func(): return false
	var player = main.get_node("Player")
	player.assume_captured = true
	for i in 3:
		await physics_frame
	return {"main": main, "player": player, "hud": hud}


func _mesh_ids(arts: Array) -> Array:
	var ids := []
	for art in arts:
		for node in (art as Node).find_children("*", "GeometryInstance3D", true, false):
			if node is MeshInstance3D:
				ids.append((node as MeshInstance3D).mesh.get_instance_id())
			elif node is MultiMeshInstance3D:
				ids.append((node as MultiMeshInstance3D).multimesh.get_instance_id())
	return ids


## The block of `text` starting at `head` up to the next node or resource header.
static func _block(text: String, head: String) -> String:
	var at := text.find(head)
	if at < 0:
		return ""
	var end := text.find("\n[", at + 1)
	return text.substr(at, (end if end > 0 else text.length()) - at)


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
	Engine.time_scale = 1.0
	for node in _arenas.duplicate() + _scratch.duplicate():
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
