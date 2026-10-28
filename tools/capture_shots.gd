extends SceneTree
## Demo-data stills of SIGKILL for the README (A1): every weapon of the arsenal held in first
## person, at rest and mid-shot (and mid-charge for one that charges), and one wider gameplay view:
## the rail on a daemon. A tool, never part of the game.
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

var _main: Node
var _player: Node
var _shots := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("capture: headless draws nothing; run it on a private virtual display")
		quit(2)
		return
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


func _frames(n: int) -> void:
	for i in n:
		_player.drive_input(Vector2.ZERO)
		await physics_frame


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(OUT.path_join(name + ".png"))
	_shots += 1
