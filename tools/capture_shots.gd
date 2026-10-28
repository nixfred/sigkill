extends SceneTree
## Demo-data stills of SIGKILL for the README, by set (-- --set=a1, the default, a2 or a3):
## a1, every weapon of the arsenal held in first person, at rest and mid-shot (and mid-charge for
## one that charges), and one wider view, the rail on a daemon; a2, each kind of daemon up close,
## several in one view, a derezz mid-shatter, and one wider view, grep locked on a daemon between
## the pillars; a3, the arena: a wide overview from above, the skyline and the void from just outside
## the south wall, then in play the west corridor, the lair's front, and one wider view, daemons ahead
## and a weapon in hand. After
## each still it prints what the GPU drew for it (draw calls, primitives, objects). A tool, never
## part of the game.
##
## It draws, so it never runs headless, and it never runs on a real desktop: run it from a clean
## copy on a private virtual display, sound off, with user data in a temporary folder, as
## tools/capture_shots.sh does. The stills land in user://shots/.
##
## Demo data only: the guide link is a demo one with its privacy file in user://, as the tests
## park theirs, so nothing of the machine is read or shown. Times are counted in frames (run it
## with --fixed-fps 60), so the same tree gives the same stills.

const Link = preload("res://scripts/guide/guide_link.gd")
const MainScene = preload("res://scenes/main.tscn")
const OUT := "user://shots"
## Frames after a weapon is drawn before its still: the raise done and the fiction line gone.
const SETTLE_FRAMES := 110
## Frames after a shot leaves for its mid-shot still.
const FIRE_FRAMES := 3
## How far through a charge its mid-charge still is taken.
const CHARGE_SHARE := 0.8
## A mine is placed looking this far down, in degrees, so it lands in view.
const MINE_PITCH := -24.0
## The wider view: where the player stands, the daemon it shoots (between two pillars), and the
## frames after the shot for its still, the flash gone and the beam and the derezz showing.
const WIDE_AT := Vector3(4.0, 0.95, 4.0)
const WIDE_TARGET := "Arena/Targets/DummyC"
const WIDE_FRAMES := 7
## a2: where the player stands for each daemon's close view, and the daemon it looks at.
const A2_CLOSE := [["rogue", Vector3(0.0, 0.95, -13.1), "DummyA"], ["zombie", Vector3(-17.5, 0.95, 6.9), "DummyB"], ["swarm", Vector3(-8.0, 0.95, 14.45), "DummyD"]]
## a2: the view with several daemons in it (the swarm on its platform to the right, a zombie ahead):
## where the player stands and the point it looks at.
const A2_MIXED_AT := Vector3(-14.0, 0.95, 16.0)
const A2_MIXED_LOOK := Vector3(-12.5, 1.2, 8.5)
## a2: where the player stands for the lock on the zombie between the pillars.
const A2_LOCK_AT := Vector3(8.0, 0.95, 4.2)
## a2: frames after the killing shot for the mid-shatter still; frames of aiming for the lock.
const A2_DEREZZ_FRAMES := 7
const A2_LOCK_FRAMES := 75
const DUMMY_MIDDLE := Vector3(0.0, 0.9, 0.0)
## a3: the overview's camera (free, high over the south-west corner) and what it looks at, its field
## of view; then each view in play: where the player stands and the point it looks at (arena space).
const A3_OVERVIEW_AT := Vector3(-36.0, 26.0, 38.0)
const A3_OVERVIEW_LOOK := Vector3(0.0, 0.0, -3.0)
const A3_OVERVIEW_FOV := 60.0
## The skyline's camera (free, off the north-east corner, over the plinth's edge, looking along the
## north wall's outside to the towers beyond) and its look.
const A3_SKYLINE_AT := Vector3(31.0, 10.0, -29.0)
const A3_SKYLINE_LOOK := Vector3(-60.0, 2.0, -95.0)
const A3_VIEWS := [["corridor", Vector3(-17.5, 0.95, 18.0), Vector3(-17.5, 1.6, -6.0)], ["slab", Vector3(3.5, 0.95, -1.0), Vector3(-1.5, 2.0, -8.0)], ["gameplay", Vector3(-2.0, 0.95, 18.5), Vector3(-10.5, 1.6, 7.0)]]

var _main: Node
var _player: Node
var _shots := 0
var _set := "a1"


func _initialize() -> void:
	_run()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("capture: headless draws nothing; run it on a private virtual display")
		quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--set="):
			_set = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(OUT)
	var link := Link.new()
	link.settings_path = "user://capture-privacy.cfg"
	link.demo = true
	Link.park(link)
	_main = MainScene.instantiate()
	root.add_child(_main)
	current_scene = _main
	_player = _main.get_node("Player")
	_player.assume_captured = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _frames(90)  # shaders compiled, the code rain running
	if _set == "a2":
		await _a2()
		print("capture: %d stills" % _shots)
		quit(0)
		return
	if _set == "a3":
		await _a3()
		print("capture: %d stills" % _shots)
		quit(0)
		return
	var defs: Array = _player.inventory.defs
	for slot in defs.size():
		var def: Resource = defs[slot]
		var name := "a1-weapon-%d-%s" % [slot + 1, def.id.replace("_", "-")]
		_player.select_slot(slot)
		await _frames(SETTLE_FRAMES)
		await _save(name)
		await _shoot(def, name)
		await _frames(150)  # the shot's effects gone, ready again
	await _wide()
	print("capture: %d stills" % _shots)
	quit(0)


## One shot of the drawn weapon: a still mid-charge for one that charges (the rail's coils, the
## rm -rf wind-up), and one just after the shot leaves. The rail, an ult, gets a full meter first.
func _shoot(def: Resource, name: String) -> void:
	_player.inventory.add_meter(_player.inventory.meter_full())
	# A press counts on the physics step after the one it is made before: made just after a still
	# (after the draw), the next frame's own press would overwrite it, so wait for a step first.
	await physics_frame
	var mine: bool = def.has_method("is_mine") and def.is_mine()
	if mine:
		_player.get_node("Head").rotation.x = deg_to_rad(MINE_PITCH)
	_player.drive_input(Vector2.ZERO, false, false, true)
	await physics_frame
	if def.charge_s > 0.0:
		var frames := ceili(def.charge_s * 60.0)
		var early := int(frames * CHARGE_SHARE)
		await _frames(early - 1)
		await _save(name + "-charge")
		await _frames(frames - early)
	await _frames(FIRE_FRAMES)
	await _save(name + "-fire")
	if mine:
		_player.get_node("Head").rotation.x = 0.0


## The wider view: off to one side of the spawn, the rail on a daemon as its shot lands.
func _wide() -> void:
	_player.respawn_at(_main.to_global(WIDE_AT))
	var target: Node3D = _main.get_node(WIDE_TARGET)
	await _frames(30)
	var cam: Camera3D = _player.get_node("Head/Camera")
	var to := target.global_position + Vector3.UP - cam.global_position
	_player.rotation.y = atan2(-to.x, -to.z)
	_player.get_node("Head").rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	_player.select_slot(2)
	await _frames(SETTLE_FRAMES)
	_player.inventory.add_meter(_player.inventory.meter_full())
	_player.drive_input(Vector2.ZERO, false, false, true)
	await physics_frame
	await _frames(ceili(_player.inventory.defs[2].charge_s * 60.0) + WIDE_FRAMES)
	await _save("a1-gameplay")


## a2: each kind of daemon up close, several at once, a derezz mid-shatter, grep locked on one.
func _a2() -> void:
	for view in A2_CLOSE:
		await _stand(view[1], _main.get_node("Arena/Targets/" + view[2]).global_position + DUMMY_MIDDLE)
		await _save("a2-daemon-" + view[0])
	await _stand(A2_MIXED_AT, _main.to_global(A2_MIXED_LOOK))
	await _save("a2-mixed")
	# The rogue daemon shot down from its close view, the shatter mid-flight.
	var rogue: Node3D = _main.get_node("Arena/Targets/DummyA")
	await _stand(A2_CLOSE[0][1], rogue.global_position + DUMMY_MIDDLE)
	_player.drive_input(Vector2.ZERO, false, false, true)
	await physics_frame
	await _frames(A2_DEREZZ_FRAMES)
	await _save("a2-derezz")
	# grep aimed at the zombie between the pillars until it is marked.
	var zombie: Node3D = _main.get_node("Arena/Targets/DummyC")
	await _stand(A2_LOCK_AT, zombie.global_position + DUMMY_MIDDLE)
	_player.select_slot(5)
	await _frames(SETTLE_FRAMES)
	for i in A2_LOCK_FRAMES:
		_player.set("_aiming", true)
		_player.drive_input(Vector2.ZERO)
		await physics_frame
	await _save("a2-gameplay")


## a3: the arena from above and the void beyond its wall (free cameras), then each view in play, the
## last with the cannon drawn and a shot just leaving.
func _a3() -> void:
	await _free_view("a3-overview", A3_OVERVIEW_AT, A3_OVERVIEW_LOOK)
	await _free_view("a3-skyline", A3_SKYLINE_AT, A3_SKYLINE_LOOK)
	for view in A3_VIEWS:
		await _stand(view[1], _main.to_global(view[2]))
		if view[0] == "gameplay":
			_player.drive_input(Vector2.ZERO, false, false, true)
			await physics_frame
			await _frames(FIRE_FRAMES)
		await _save("a3-" + view[0])


## A still from a free camera at `at` looking at `look` (arena space), the player and the HUD hidden.
func _free_view(name: String, at: Vector3, look: Vector3) -> void:
	var hud: CanvasLayer = _main.get_node("Hud")
	var cam := Camera3D.new()
	cam.fov = A3_OVERVIEW_FOV
	_main.add_child(cam)
	cam.global_position = _main.to_global(at)
	cam.look_at(_main.to_global(look), Vector3.UP)
	cam.current = true
	hud.visible = false
	_player.visible = false
	await _frames(30)
	await _save(name)
	cam.current = false
	cam.queue_free()
	hud.visible = true
	_player.visible = true


## Stands the player at `at` (arena space) looking at `target` (world space), settled.
func _stand(at: Vector3, target: Vector3) -> void:
	_player.respawn_at(_main.to_global(at))
	await _frames(30)
	var cam: Camera3D = _player.get_node("Head/Camera")
	var to := target - cam.global_position
	_player.rotation.y = atan2(-to.x, -to.z)
	_player.get_node("Head").rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	await _frames(SETTLE_FRAMES)


func _frames(n: int) -> void:
	for i in n:
		_player.drive_input(Vector2.ZERO)
		await physics_frame


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(OUT.path_join(name + ".png"))
	_shots += 1
	var drawn := []
	for kind in [Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_TYPE_SHADOW]:
		for info in [Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME, Viewport.RENDER_INFO_OBJECTS_IN_FRAME]:
			drawn.append(root.get_render_info(kind, info))
	print("capture: %s drew %d draw calls, %d primitives, %d objects; shadows %d draw calls, %d primitives, %d objects" % ([name] + drawn))
