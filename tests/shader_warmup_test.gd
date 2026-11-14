extends SceneTree
## Headless test of the combat shaders' warm-up (scripts/fx/shader_warmup.gd). scripts/check.sh runs it as step 62, and
## any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/shader_warmup_test.gd
##
## The list: every entry a spatial shader that loads, and every shader a weapon or the frost draws (scripts/weapons/,
## scripts/fx/frost_look.gd) listed, so a new weapon's shader is not left to compile at its first shot. The node: run
## headless it draws nothing and frees itself; told it draws, under a camera it hangs one quad per shader in front of
## it, each under a pixel and casting no shadow, holds them HOLD_FRAMES frames and then frees itself and them; with no
## camera it gives up after GIVE_UP_FRAMES. /dev/null's black glass and its core's unlit black, StandardMaterial3Ds no
## other part of the arena draws, are the warm-up's own, the same objects every throw wears, and a zombie's glitch
## bolt's two (scripts/fight/glitch_bolt.gd) are too. The arena makes it and makes /dev/null's and SIGHUP's sounds as
## it loads. Nothing is rendered here.

const Warmup = preload("res://scripts/fx/shader_warmup.gd")
const SHADER_REF := "res://shaders/[a-z0-9_]+\\.gdshader"

var _fails := 0
var _checks := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_list_checks()
	await _node_checks()
	_arena_checks()
	print("SHADER WARMUP: %d checks" % _checks)
	print("SHADER WARMUP RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


func _list_checks() -> void:
	var bad := PackedStringArray()
	for shader in Warmup.SHADERS:
		if not (shader is Shader) or shader.get_mode() != Shader.MODE_SPATIAL:
			bad.append(shader.resource_path if shader != null else "null")
	_check("every listed shader is preloaded and spatial", bad.is_empty() and not Warmup.SHADERS.is_empty(), ", ".join(bad))
	var listed := {}
	for shader in Warmup.SHADERS:
		var path: String = shader.resource_path
		_check("%s is listed once" % path.get_file(), not listed.has(path))
		listed[path] = true
	var sources := PackedStringArray(["res://scripts/fx/frost_look.gd"])
	for f in DirAccess.get_files_at("res://scripts/weapons"):
		if f.ends_with(".gd"):
			sources.append("res://scripts/weapons/" + f)
	var ref := RegEx.create_from_string(SHADER_REF)
	var missing := PackedStringArray()
	for source in sources:
		for found in ref.search_all(FileAccess.get_file_as_string(source)):
			if not listed.has(found.get_string()):
				missing.append("%s (%s)" % [found.get_string(), source.get_file()])
	_check("every shader a weapon or the frost draws is listed", missing.is_empty(), ", ".join(missing))
	var mats: Array[Material] = Warmup.materials()
	var look = load("res://scripts/weapons/dev_null_look.gd")
	_check("the warm-up draws /dev/null's own glass and core, the very materials every throw wears", mats.has(look.glass_material()) and mats.has(look.nothing_material()))
	var bolt := GlitchBolt.materials()
	_check("the warm-up draws a zombie's glitch bolt's two materials, the very ones every bolt wears", bolt.size() == 2 and mats.has(bolt[0]) and mats.has(bolt[1]))
	# P2 gave a thrower's shell and a pegged core a red pair (look_for). Godot compiles a StandardMaterial3D per feature
	# set, not per colour, so the red pair needs no quad of its own only while it shares the amber pair's features: if a
	# later pass gives it one that differs, this fails and the red pair joins materials().
	var shared := true
	for kind in ["shell", "pegged"]:
		var red: Dictionary = GlitchBolt.look_for(kind)
		for slot in [["shell", 0], ["core", 1]]:
			var a := red[slot[0]] as StandardMaterial3D
			var b := bolt[slot[1]] as StandardMaterial3D
			shared = shared and a != null and b != null and a != b and a.shading_mode == b.shading_mode and a.transparency == b.transparency and a.blend_mode == b.blend_mode and a.cull_mode == b.cull_mode and a.emission_enabled == b.emission_enabled and a.vertex_color_use_as_albedo == b.vertex_color_use_as_albedo and a.albedo_texture == b.albedo_texture
	_check("a thrower's red bolt materials (look_for) share the amber pair's features, so their shader is the one warmed", shared)
	var look_src := FileAccess.get_file_as_string("res://scripts/weapons/dev_null_look.gd")
	_check("/dev/null's look makes no StandardMaterial3D of its own outside them", look_src.count("StandardMaterial3D.new()") == 2)


func _node_checks() -> void:
	var quiet = Warmup.new()
	root.add_child(quiet)
	await _frames(2)
	_check("headless it draws nothing and frees itself", not is_instance_valid(quiet))
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.make_current()
	var w = Warmup.new()
	w.headless = false
	root.add_child(w)
	await _frames(1)
	var quads: Array = w.quads().duplicate()
	_check("under a camera it hangs one quad per material, each listed shader, /dev/null's glass and core and the glitch bolt's two", quads.size() == Warmup.SHADERS.size() + 4, "%d quads" % quads.size())
	var placed := true
	for m in quads:
		var mesh := (m as MeshInstance3D).mesh as QuadMesh
		placed = placed and m.get_parent() == camera and mesh != null and mesh.size.x <= Warmup.QUAD_M and m.position.z < 0.0
		placed = placed and m.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and m.material_override is Material
	_check("each quad is under a pixel in front of the camera, casts no shadow and draws its material", placed)
	await _frames(Warmup.HOLD_FRAMES + 2)
	var gone := true
	for m in quads:
		gone = gone and not is_instance_valid(m)
	_check("after its frames it frees itself and its quads", not is_instance_valid(w) and gone)
	camera.free()
	var lost = Warmup.new()
	lost.headless = false
	root.add_child(lost)
	await _frames(Warmup.GIVE_UP_FRAMES + 2)
	_check("with no camera it gives up and frees itself", not is_instance_valid(lost))


func _arena_checks() -> void:
	var main := FileAccess.get_file_as_string("res://scripts/main.gd")
	_check("the arena makes the warm-up as it loads", main.contains("add_child(ShaderWarmup.new())"))
	_check("the arena makes /dev/null's and SIGHUP's sounds as it loads", main.contains("DevNullHole.prewarm()") and main.contains("SighupBurst.prewarm()"))
	DevNullHole.prewarm()
	SighupBurst.prewarm()
	_check("/dev/null's hum and implosion are made", DevNullHole._sounds.has("hum") and DevNullHole._sounds.has("boom"))
	_check("SIGHUP's hangup is made", SighupBurst._sounds.has("hangup"))


func _frames(n: int) -> void:
	for i in n:
		await process_frame
