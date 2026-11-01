class_name ShaderWarmup
extends Node3D
## The combat shaders compiled as the arena loads, so no weapon's first use stalls on one. Godot compiles a shader
## the first frame something draws with it, on the main thread, and the effects below are only drawn once a weapon is
## used: with Godot's and the driver's shader caches cold, chmod 000's first hit froze the game for about 1.2 s while
## frost_crust compiled, /dev/null's first throw for about 1.2 s while its device's black glass did (a
## StandardMaterial3D whose features nothing else in the arena uses), and SIGHUP and ping lost 50 to 160 ms (RTX 3090,
## 2560x1440). A zombie's glitch bolt's two materials are drawn too, as the bolt is only drawn once one flies. The
## export's shader baker cannot help, since it only bakes materials it finds in scenes and resources, and these are
## made in code. Not covered: fork()'s pellets can still stall about a second the first time they fly a long way (no
## shader compile shows then; likely a pipeline the driver builds).
##
## The arena (scripts/main.gd) makes this node. On its first frame with a camera it hangs one tiny quad per material
## in materials() in front of that camera, far under a pixel, holds them for HOLD_FRAMES drawn frames so each
## compiles, then frees itself. With warm caches (user://shader_cache, user://vulkan) the compiles are reads and the
## frames cost next to nothing. Headless, or with no camera after GIVE_UP_FRAMES, it frees itself and draws nothing.
## The world's own shaders (the arena, the daemons, the ruins) compile as the arena is built and are not listed.

## Every shader a weapon, an ability or a hit draws only once it is used, preloaded (nothing is loaded at run time).
## tests/shader_warmup_test.gd checks that each is a spatial shader and that every shader under scripts/weapons/ is
## listed.
const SHADERS: Array[Shader] = [
	preload("res://shaders/freeze_beam.gdshader"),
	preload("res://shaders/frost_crust.gdshader"),
	preload("res://shaders/pipe_arc.gdshader"),
	preload("res://shaders/ping_wave.gdshader"),
	preload("res://shaders/ping_reveal.gdshader"),
	preload("res://shaders/dev_null_lens.gdshader"),
	preload("res://shaders/dev_null_disc.gdshader"),
	preload("res://shaders/dev_null_debris.gdshader"),
	preload("res://shaders/dev_null_floor.gdshader"),
	preload("res://shaders/sighup_wave.gdshader"),
	preload("res://shaders/sighup_curtain.gdshader"),
	preload("res://shaders/derezz_voxel.gdshader"),
	preload("res://shaders/breaker_mark.gdshader"),
	preload("res://shaders/ice_field.gdshader"),
	preload("res://shaders/vision_glyphs.gdshader"),
]
## The weapons' own StandardMaterial3Ds whose features nothing else in the arena draws (and a zombie's glitch bolt's,
## scripts/fight/glitch_bolt.gd materials()): each one a shader of its own.
const DevNullLook = preload("res://scripts/weapons/dev_null_look.gd")
const NODE_NAME := "ShaderWarmup"
## The quads' side and how far in front of the camera they hang, metres: a fifth of a millimetre at half a metre is
## well under a pixel at any field of view the settings allow.
const QUAD_M := 0.0002
const AHEAD_M := 0.5
## Drawn frames the quads are held for, and frames waited for a camera before giving up.
const HOLD_FRAMES := 2
const GIVE_UP_FRAMES := 30

## True when nothing is drawn (a headless run), so it frees itself at once; the checks turn it off to see the quads.
var headless := DisplayServer.get_name() == "headless"

var _quads: Array[MeshInstance3D] = []
var _held := 0
var _waited := 0


func _init() -> void:
	name = NODE_NAME


func _process(_delta: float) -> void:
	if not _quads.is_empty():
		_held += 1
		if _held >= HOLD_FRAMES:
			queue_free()
		return
	var camera := get_viewport().get_camera_3d() if not headless else null
	if camera == null:
		_waited += 1
		if headless or _waited >= GIVE_UP_FRAMES:
			queue_free()
		return
	var quad := QuadMesh.new()
	quad.size = Vector2(QUAD_M, QUAD_M)
	for material in materials():
		var m := MeshInstance3D.new()
		m.mesh = quad
		m.material_override = material
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.position = Vector3(0.0, 0.0, -AHEAD_M)
		camera.add_child(m)
		_quads.append(m)


## A material per listed shader, and the weapons' own StandardMaterial3Ds, as they are drawn in the game.
static func materials() -> Array[Material]:
	var all: Array[Material] = []
	for shader in SHADERS:
		var material := ShaderMaterial.new()
		material.shader = shader
		all.append(material)
	all.append(DevNullLook.glass_material())
	all.append(DevNullLook.nothing_material())
	all.append_array(GlitchBolt.materials())
	return all


## The quads go with it, wherever they hang.
func _exit_tree() -> void:
	for m in _quads:
		if is_instance_valid(m):
			m.queue_free()
	_quads.clear()


## The quads it holds now, for the checks.
func quads() -> Array[MeshInstance3D]:
	return _quads
