extends SceneTree
## Demo-data stills of SIGKILL for the README, by set (-- --set=a1, the default, a2, a3, a2b, a4, c27b, c28 or a5):
## a1, every weapon of the arsenal held in first person, at rest and mid-shot (and mid-charge for
## one that charges), and one wider view, the rail on a daemon; a2, each kind of daemon up close,
## several in one view, a derezz mid-shatter, and one wider view, grep locked on a daemon between
## the pillars; a3, the arena: a wide overview from above, the skyline and the void from off its
## north-east corner, then in play the west corridor, the lair's front, and one wider view, daemons
## ahead and a weapon in hand; a2b, the daemons as creatures: each one's hero view from a free
## camera and a strip of three stills of its motion side by side (the rogue daemon's through a rear
## and its strike), one view in play with all three kinds in it, and the rogue daemon's death in
## shards; a4, the arena lit and finished: the overview from above, a fight (the cannon fired past the
## rogue daemon into its lair's wall: the muzzle burst, the beam, the sparks), the west corridor with the zombie,
## one view at the low and the high preset side by side (with each preset's GPU time printed), the
## same view with both post effects on, and every weapon held at the spawn as a4-weapon-* stills.
## The a4 set uses nothing A4 made, so it shoots the same views from a copy from before A4. c27b,
## the daemons fighting back, in play: a rogue daemon mid-lunge, a zombie's bolt in flight, the
## hit's red vignette and the death it ends in; c28, ping: its ring going out across the floor seen
## from above and behind, daemons outlined through the west cover wall with their tags, and rogue.d
## caught mid-tell by a ping, reeling; a5, the armoured daemons (A5): rogue.d in its tell, rearing
## tall at the player, its visor flared; a zombie's cannon charging at the player, its bands lit; the
## runaway's drones round their core; a line-up of three of each type built from other seeds, no two
## alike (each creature's own art, standing, facing the camera, one row a type, the rows stacked);
## the three elites in their tells; and the runaway's core killed, its drones scattering; then it
## prints what daemons cost: each type's posing timed alone, and the GPU's time with nine drawn and
## with them hidden. Every
## other set plays in practice, the old dummies, as it was shot.
## After each still it prints what the GPU drew for it (draw calls, primitives, objects, and the
## same for shadows). A tool, never part of the game.
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
## a3: the overview's camera (free, high over the south-west corner) and what it looks at, and the
## free cameras' field of view; then each view in play: where the player stands and the point it
## looks at (arena space).
const A3_OVERVIEW_AT := Vector3(-36.0, 26.0, 38.0)
const A3_OVERVIEW_LOOK := Vector3(0.0, 0.0, -3.0)
const A3_OVERVIEW_FOV := 60.0
## The skyline's camera (free, off the north-east corner, over the plinth's edge, looking along the
## north wall's outside to the towers beyond) and its look.
const A3_SKYLINE_AT := Vector3(31.0, 10.0, -29.0)
const A3_SKYLINE_LOOK := Vector3(-60.0, 2.0, -95.0)
const A3_VIEWS := [["corridor", Vector3(-17.5, 0.95, 18.0), Vector3(-17.5, 1.6, -6.0)], ["slab", Vector3(3.5, 0.95, -1.0), Vector3(-1.5, 2.0, -8.0)], ["gameplay", Vector3(-2.0, 0.95, 18.5), Vector3(-10.5, 1.6, 7.0)]]
## a2b: each daemon's hero view: its name, its target, the free camera and the point it looks at
## (arena space); then its motion strip: the frames before each of its three stills, counted from
## the hero still (for the rogue daemon, from the start of its next rear).
const A2B_HEROES := [["rogue", "DummyA", Vector3(2.9, 1.25, -11.2), Vector3(0.0, 1.0, -15.0), [10, 30, 30]], ["zombie", "DummyB", Vector3(-16.1, 1.45, 9.3), Vector3(-17.5, 1.05, 5.0), [12, 12, 12]], ["swarm", "DummyD", Vector3(-5.3, 2.3, 14.7), Vector3(-8.0, 1.95, 12.0), [8, 8, 8]]]
const A2B_FOV := 50.0
## a2b: the part of each still a strip keeps (the middle, where the daemon is), and the longest the
## rogue daemon is waited for to rear, in frames.
const A2B_CROP := Rect2i(400, 90, 1120, 900)
const A2B_REAR_WAIT := 480
## a2b: the view in play (where the player stands and the point it looks at, arena space); the
## death's free camera and look, its target, and the frames after the killing shot for its still.
const A2B_GAMEPLAY_AT := Vector3(-1.5, 0.95, 18.5)
const A2B_GAMEPLAY_LOOK := Vector3(-1.0, 1.2, 0.0)
const A2B_SHATTER_AT := Vector3(3.4, 1.5, -10.6)
const A2B_SHATTER_LOOK := Vector3(0.0, 1.0, -15.0)
const A2B_SHATTER_TARGET := "DummyA"
const A2B_SHATTER_FRAMES := 14
## a4: the fight (where the player stands, the daemon it shoots, the weapon, where it aims: past the
## daemon's side into the lair's wall, as every hit is a kill and a kill's flash would hide the rest;
## frames after the shot), the corridor, the view shown at low and high (each half the size, side
## by side), and how many frames each preset's GPU time is averaged over.
const A4_FIGHT_AT := Vector3(2.6, 0.95, -9.4)
const A4_FIGHT_TARGET := "DummyA"
const A4_FIGHT_SLOT := 0
const A4_FIGHT_AIM := Vector3(1.7, 0.4, 0.0)
const A4_FIGHT_FRAMES := 3
const A4_CORRIDOR_AT := Vector3(-17.5, 0.95, 18.0)
const A4_CORRIDOR_LOOK := Vector3(-17.5, 1.6, -6.0)
const A4_COMPARE_AT := Vector3(-1.5, 0.95, 18.5)
const A4_COMPARE_LOOK := Vector3(-1.0, 1.2, 0.0)
const A4_GPU_FRAMES := 90
## c27b (C27b): where the player stands and where each daemon is put, facing it, in arena space;
## where the still is taken: the lunge this far through its strike, the bolt this long in flight.
const C27B_PLAYER_AT := Vector3(0.0, 0.95, 15.0)
const C27B_ROGUE_AT := Vector3(0.6, 0.0, 12.45)
const C27B_LUNGE_SHARE := 0.45
const C27B_ZOMBIE_AT := Vector3(-3.2, 0.0, 7.4)
const C27B_BOLT_FRAMES := 40
## Frames after the player's death for its still: the derezz's voxels flying, the banner up.
const C27B_DOWN_FRAMES := 14
## Under the floor: where a daemon a still does not use waits, out of every sight line.
const C27B_PARKED := Vector3(0.0, -50.0, 0.0)
## c28 (C28): the ring seen from a camera riding above and behind the player, when it has gone this
## many frames out, with three daemons round it; the reveal from behind the west cover wall (3 m
## high), two daemons beyond it, this long after the ping; the stagger this long after a ping caught
## rogue.d's tell.
const C28_PING_AT := Vector3(0.0, 0.95, 12.0)
const C28_CHASE := Vector3(0.0, 6.5, 8.5)
const C28_CHASE_LOOK := Vector3(0.0, 0.0, -4.0)
const C28_RING_FRAMES := 14
const C28_ROUND := [Vector3(-5.5, 0.0, 9.5), Vector3(4.5, 0.0, 6.0), Vector3(2.0, 1.0, 15.5)]
const C28_WALL_AT := Vector3(-12.0, 0.95, -2.5)
const C28_BEYOND := [Vector3(-13.2, 0.0, 4.8), Vector3(-10.4, 0.0, 6.6)]
const C28_REVEAL_FRAMES := 36
const C28_STAGGER_FRAMES := 26
## Ping's slot (weapon 9).
const C28_SLOT := 8
## a5 (A5): rogue.d put where it hunts the player and shot in its tell (this far in, then its
## camera beside the player, this far toward the player, out to the side and up); the zombie's
## charge, the player and the zombie where c27b put them, the still this far through its tell, its
## free camera and look (arena space); the runaway's; the line-up's rows (type, name, places, the
## share of its size range each seed rolls), its camera and look, and the band of each row's still
## kept; the elites' places, camera and look; the scatter's camera, its frames after the kill; and
## how many frames the cost is averaged over.
const A5_ROGUE_AT := Vector3(0.5, 0.0, 10.5)
const A5_ROGUE_TELL_S := 0.25
const A5_ROGUE_FRAMES := 8
const A5_ROGUE_CAM := Vector3(1.7, 1.15, 3.0)
const A5_ZOMBIE_CAM := Vector3(-0.4, 1.35, 9.2)
const A5_ZOMBIE_LOOK := Vector3(-3.2, 1.15, 7.4)
const A5_CHARGE_SHARE := 0.8
const A5_SWARM_CAM := Vector3(-5.0, 2.2, 15.6)
const A5_SWARM_LOOK := Vector3(-8.0, 2.05, 12.0)
const A5_SWARM_FOV := 40.0
const A5_ROWS := [["rogue_daemon", "rogue.d", [Vector3(-4.3, 0.0, 10.0), Vector3(0.0, 0.0, 10.0), Vector3(4.3, 0.0, 10.0)], [0.95, 0.1, 0.55]], ["zombie_process", "zombie", [Vector3(-3.4, 0.0, 10.0), Vector3(0.0, 0.0, 10.0), Vector3(3.4, 0.0, 10.0)], [0.55, 0.95, 0.1]], ["runaway_swarm", "runaway", [Vector3(-4.6, 0.0, 10.0), Vector3(0.0, 0.0, 10.0), Vector3(4.6, 0.0, 10.0)], [0.1, 0.55, 0.95]]]
const A5_LINEUP_CAM := Vector3(0.0, 1.5, 16.8)
const A5_LINEUP_LOOK := Vector3(0.0, 1.1, 10.0)
const A5_LINEUP_BAND := Rect2i(0, 270, 1920, 500)
const A5_ELITES := [["rogue_daemon", "rogue.d", Vector3(-4.0, 0.0, 10.5)], ["zombie_process", "zombie", Vector3(0.0, 0.0, 10.5)], ["runaway_swarm", "runaway", Vector3(4.4, 0.0, 10.5)]]
const A5_ELITE_CAM := Vector3(0.0, 1.5, 18.2)
const A5_ELITE_LOOK := Vector3(0.0, 1.2, 10.5)
const A5_SCATTER_CAM := Vector3(-4.4, 2.6, 16.2)
const A5_SCATTER_LOOK := Vector3(-8.0, 1.6, 12.0)
const A5_SCATTER_FRAMES := 12
const A5_COST_FRAMES := 120

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
	# Every set is shot as it was: practice, the old dummies (C27b); c27b turns them loose once its
	# daemons are placed.
	GameSettings.current().set_value("gameplay", "practice", true)
	await _frames(90)  # shaders compiled, the code rain running
	if _set == "c27b":
		await _c27b()
		print("capture: %d stills" % _shots)
		quit(0)
		return
	if _set == "a5":
		await _a5()
		print("capture: %d stills" % _shots)
		quit(0)
		return
	if _set == "c28":
		await _c28()
		print("capture: %d stills" % _shots)
		quit(0)
		return
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
	if _set == "a2b":
		await _a2b()
		print("capture: %d stills" % _shots)
		quit(0)
		return
	if _set == "a4":
		await _a4()
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


## a2b: each daemon's hero view and its motion strip from a free camera, then the view in play
## with all three kinds in it, then the rogue daemon's death in shards.
func _a2b() -> void:
	for hero in A2B_HEROES:
		var cam := _free_camera(hero[2], hero[3], A2B_FOV)
		await _frames(40)
		await _save("a2b-" + hero[0])
		if hero[0] == "rogue":
			# Wait for its rear (an art that never rears, as A2's for the before stills, does not wait).
			var art: Node = _main.get_node("Arena/Targets/" + hero[1]).art_node()
			var waited := 0
			while art.has_method("rear") and art.rear() < 0.02 and waited < A2B_REAR_WAIT:
				await _frames(1)
				waited += 1
		var stills: Array[Image] = []
		for wait in hero[4]:
			await _frames(wait)
			stills.append(await _grab())
		await _save_strip("a2b-%s-motion" % hero[0], stills)
		_free_camera_done(cam)
	await _stand(A2B_GAMEPLAY_AT, _main.to_global(A2B_GAMEPLAY_LOOK))
	await _save("a2b-gameplay")
	var cam := _free_camera(A2B_SHATTER_AT, A2B_SHATTER_LOOK, A2B_FOV)
	await _frames(30)
	var dummy: Node3D = _main.get_node("Arena/Targets/" + A2B_SHATTER_TARGET)
	dummy.hit(100.0, dummy.global_position + Vector3(0.4, 1.2, 0.5), Vector3(-0.6, 0.0, -1.0).normalized())
	await _frames(A2B_SHATTER_FRAMES)
	await _save("a2b-shatter")
	_free_camera_done(cam)


## a4: the overview, a fight, the corridor, low beside high (and each preset's GPU time), the post
## effects, then every weapon held at the spawn.
func _a4() -> void:
	var settings := GameSettings.current()
	settings.set_value("video", "quality", "high")
	await _free_view("a4-overview", A3_OVERVIEW_AT, A3_OVERVIEW_LOOK)
	var rogue: Node3D = _main.get_node("Arena/Targets/" + A4_FIGHT_TARGET)
	_player.select_slot(A4_FIGHT_SLOT)
	await _stand(A4_FIGHT_AT, rogue.global_position + DUMMY_MIDDLE + A4_FIGHT_AIM)
	_player.drive_input(Vector2.ZERO, false, false, true)
	await physics_frame
	await _frames(A4_FIGHT_FRAMES)
	await _save("a4-fight")
	_player.select_slot(0)
	await _stand(A4_CORRIDOR_AT, _main.to_global(A4_CORRIDOR_LOOK))
	await _save("a4-corridor")
	await _stand(A4_COMPARE_AT, _main.to_global(A4_COMPARE_LOOK))
	var halves: Array[Image] = []
	for preset in ["low", "medium", "high"]:
		settings.set_value("video", "quality", preset)
		await _frames(30)
		print("capture: %s preset, GPU %.2f ms a frame at 1920x1080" % [preset, await _gpu_ms(A4_GPU_FRAMES)])
		if preset != "medium":
			var still := await _grab()
			still.resize(still.get_width() / 2, still.get_height() / 2, Image.INTERPOLATE_LANCZOS)
			halves.append(still)
	var pair := Image.create(halves[0].get_width() * 2, halves[0].get_height(), false, Image.FORMAT_RGBA8)
	for i in halves.size():
		pair.blit_rect(halves[i], Rect2i(Vector2i.ZERO, halves[i].get_size()), Vector2i(halves[0].get_width() * i, 0))
	pair.save_png(OUT.path_join("a4-low-high.png"))
	_shots += 1
	print("capture: a4-low-high, the low preset left of the high one")
	if GameSettings.SCHEMA["video"].has("crt"):
		settings.set_value("video", "chromatic_aberration", true)
		settings.set_value("video", "crt", true)
		await _frames(10)
		await _save("a4-post")
		settings.set_value("video", "chromatic_aberration", false)
		settings.set_value("video", "crt", false)
	_player.respawn_at(_main.to_global(Vector3(0.0, 0.95, 10.0)))
	_player.rotation.y = 0.0
	_player.get_node("Head").rotation.x = 0.0
	var defs: Array = _player.inventory.defs
	for slot in defs.size():
		_player.select_slot(slot)
		await _frames(SETTLE_FRAMES)
		await _save("a4-weapon-%d-%s" % [slot + 1, defs[slot].id.replace("_", "-")])


## c27b: the daemons fighting back, from the player's own view: a rogue daemon mid-lunge, the hit's
## vignette as its slash lands, the player derezzed by its next one (the banner naming it), and a
## zombie's amber bolt in flight. Every daemon a still does not
## use waits under the floor.
func _c27b() -> void:
	var targets := _main.get_node("Arena/Targets")
	for dummy in targets.get_children():
		_c27b_place(dummy, C27B_PARKED + Vector3(dummy.get_index() * 3.0, 0.0, 0.0))
	var life := _main.get_node("SoloLife")
	var rogue: Node3D = targets.get_node("DummyA")
	await _stand(C27B_PLAYER_AT, _main.to_global(C27B_ROGUE_AT + DUMMY_MIDDLE + Vector3(0.0, 0.25, 0.0)))
	_c27b_place(rogue, _main.to_global(C27B_ROGUE_AT))
	GameSettings.current().set_value("gameplay", "practice", false)  # the daemons fight back from here
	var strike_s: float = (load("res://resources/daemon_ai.tres") as DaemonAiTuning).rogue_strike_s
	var waited := 0
	while not (rogue.brain.state == DaemonBrain.State.STRIKE and rogue.brain.state_t >= C27B_LUNGE_SHARE * strike_s):
		await _frames(1)
		waited += 1
	print("capture: the rogue's strike after %d frames, the player at %.0f health" % [waited, life.health()])
	await _save("c27b-lunge")
	waited = 0
	while life.health() >= 100.0:
		await _frames(1)
		waited += 1
	await _frames(1)
	print("capture: its slash landed %d frames later" % waited)
	await _save("c27b-hit")
	# Its next slash takes the last of the player's health: the derezz and the banner naming it.
	life.damage(life.health() - 4.0, rogue, Vector3.FORWARD)
	waited = 0
	while life.alive():
		await _frames(1)
		waited += 1
	await _frames(C27B_DOWN_FRAMES)
	print("capture: derezzed by its next slash %d frames later" % waited)
	await _save("c27b-down")
	_c27b_place(rogue, C27B_PARKED)
	life.reset_for_round()
	var zombie: Node3D = targets.get_node("DummyC")
	await _stand(C27B_PLAYER_AT, _main.to_global(C27B_ZOMBIE_AT + DUMMY_MIDDLE + Vector3(0.0, 0.3, 0.0)))
	_c27b_place(zombie, _main.to_global(C27B_ZOMBIE_AT))
	var director: DaemonDirector = _main.get_node("DaemonDirector")
	waited = 0
	while director.bolts_live() == 0:
		await _frames(1)
		waited += 1
	print("capture: the zombie's bolt after %d frames" % waited)
	await _frames(C27B_BOLT_FRAMES)
	await _save("c27b-bolt")


## c28: ping. The ring from above and behind the player as it goes out across the floor, three
## daemons round it (outlined as it meets them); from behind the west cover wall, rogue.d and a
## zombie beyond it outlined through it with their tags; and rogue.d caught rearing by a ping, reeling
## outlined. Every daemon a still does not use waits under the floor; the daemons fight back.
func _c28() -> void:
	var targets := _main.get_node("Arena/Targets")
	for dummy in targets.get_children():
		_c27b_place(dummy, C27B_PARKED + Vector3(dummy.get_index() * 3.0, 0.0, 0.0))
	GameSettings.current().set_value("gameplay", "practice", false)
	_player.select_slot(C28_SLOT)
	await _stand(C28_PING_AT, _main.to_global(C28_PING_AT + Vector3(0.0, -0.4, -6.0)))
	await _frames(90)  # past the fiction line drawing shows
	var names := ["DummyA", "DummyC", "DummyD"]
	for i in names.size():
		_c27b_place(targets.get_node(names[i]), _main.to_global(C28_ROUND[i]))
	var cam := _free_camera(C28_PING_AT + C28_CHASE, C28_PING_AT + C28_CHASE_LOOK, A3_OVERVIEW_FOV)
	await _frames(20)
	await _ping()
	await _frames(C28_RING_FRAMES)
	print("capture: the ring %.1f m out" % (_player.last_ping.radius() if is_instance_valid(_player.last_ping) else -1.0))
	await _save("c28-ping")
	_free_camera_done(cam)
	for dummy in targets.get_children():
		_c27b_place(dummy, C27B_PARKED + Vector3(dummy.get_index() * 3.0, 0.0, 0.0))
	await _frames(roundi(_player.weapon_tuning().fire_cooldown * 60.0))  # the cooldown back
	# Behind the west cover wall: two daemons beyond it, out of sight, outlined through it.
	await _stand(C28_WALL_AT, _main.to_global(Vector3(-11.8, 1.2, 5.5)))
	_c27b_place(targets.get_node("DummyA"), _main.to_global(C28_BEYOND[0]))
	_c27b_place(targets.get_node("DummyC"), _main.to_global(C28_BEYOND[1]))
	await _frames(20)
	await _ping()
	await _frames(C28_REVEAL_FRAMES)
	await _save("c28-reveal")
	for dummy in targets.get_children():
		_c27b_place(dummy, C27B_PARKED + Vector3(dummy.get_index() * 3.0, 0.0, 0.0))
	await _frames(roundi(_player.weapon_tuning().fire_cooldown * 60.0))
	# rogue.d caught rearing, reeling.
	var rogue: Node3D = targets.get_node("DummyA")
	await _stand(C27B_PLAYER_AT, _main.to_global(C27B_ROGUE_AT + DUMMY_MIDDLE + Vector3(0.0, 0.25, 0.0)))
	_c27b_place(rogue, _main.to_global(C27B_ROGUE_AT))
	var waited := 0
	while not (rogue.brain.state == DaemonBrain.State.TELL and rogue.brain.state_t >= 0.3):
		await _frames(1)
		waited += 1
	await _ping()
	await _frames(C28_STAGGER_FRAMES)
	print("capture: rogue.d's tell after %d frames, staggered %d, reeling %.2f" % [waited, rogue.brain.staggers, rogue.art_node().staggered()])
	await _save("c28-stagger")


## a5: the armoured daemons (A5), each type's hero, the line-up, the elites, the scatter, the cost.
func _a5() -> void:
	var targets := _main.get_node("Arena/Targets")
	var rogue: Node3D = targets.get_node("DummyA")
	for dummy in targets.get_children():
		_c27b_place(dummy, C27B_PARKED + Vector3(dummy.get_index() * 3.0, 0.0, 0.0))
	# rogue.d in its tell: rearing tall at the player, its visor flared, from beside the player.
	await _stand(C27B_PLAYER_AT, _main.to_global(A5_ROGUE_AT + DUMMY_MIDDLE))
	_c27b_place(rogue, _main.to_global(A5_ROGUE_AT))
	GameSettings.current().set_value("gameplay", "practice", false)
	var waited := 0
	while not (rogue.brain.state == DaemonBrain.State.TELL and rogue.brain.state_t >= A5_ROGUE_TELL_S) and waited < 900:
		await _frames(1)
		waited += 1
	var at: Vector3 = _main.to_local(rogue.global_position)
	var face: Vector3 = _main.to_local(_player.global_position) - at
	face.y = 0.0
	face = face.normalized()
	var side: Vector3 = face.cross(Vector3.UP)
	var cam := _free_camera(at + face * A5_ROGUE_CAM.z + side * A5_ROGUE_CAM.x + Vector3.UP * A5_ROGUE_CAM.y, at + Vector3.UP * 1.25, A2B_FOV)
	await _frames(A5_ROGUE_FRAMES)
	print("capture: rogue.d (seed %d, size %.2f) in its tell after %d frames, rearing %.2f, its visor at %.2f" % [rogue.build_seed(), rogue.art_node().size_scale, waited, rogue.art_node().rear(), rogue.art_node().visor_glow()])
	await _save("a5-rogue")
	_free_camera_done(cam)
	GameSettings.current().set_value("gameplay", "practice", true)
	_c27b_place(rogue, C27B_PARKED)
	await _frames(10)
	# A zombie's cannon charging at the player, its bands lighting.
	var zombie: Node3D = targets.get_node("DummyC")
	await _stand(C27B_PLAYER_AT, _main.to_global(C27B_ZOMBIE_AT + DUMMY_MIDDLE))
	_c27b_place(zombie, _main.to_global(C27B_ZOMBIE_AT))
	GameSettings.current().set_value("gameplay", "practice", false)
	var tell_s: float = (load("res://resources/daemon_ai.tres") as DaemonAiTuning).zombie_tell_s
	cam = _free_camera(A5_ZOMBIE_CAM, A5_ZOMBIE_LOOK, A2B_FOV)
	waited = 0
	while not (zombie.brain.state == DaemonBrain.State.TELL and zombie.brain.state_t >= A5_CHARGE_SHARE * tell_s) and waited < 900:
		await _frames(1)
		waited += 1
	print("capture: the zombie (seed %d) charging after %d frames, its bands %s" % [zombie.build_seed(), waited, zombie.art_node().band_glow()])
	await _save("a5-zombie")
	_free_camera_done(cam)
	GameSettings.current().set_value("gameplay", "practice", true)
	_c27b_place(zombie, _main.to_global(Vector3(-17.5, 0.0, 5.0)))
	await _frames(30)
	# The runaway on its platform, its drones round the core.
	var swarm: Node3D = targets.get_node("DummyD")
	_c27b_place(swarm, _main.to_global(Vector3(-8.0, 1.0, 12.0)))
	cam = _free_camera(A5_SWARM_CAM, A5_SWARM_LOOK, A5_SWARM_FOV)
	await _frames(60)
	await _save("a5-runaway")
	_free_camera_done(cam)
	# The line-up: three of each type, each from its own seed. The arena's own wait under the floor.
	for dummy in targets.get_children():
		_c27b_place(dummy, C27B_PARKED + Vector3(dummy.get_index() * 3.0, 0.0, 0.0))
	# One row a type, each row three of it side by side, the rows stacked in one still: each
	# creature's own art from its seed, standing driven (its idle wander off) and facing the camera,
	# so builds compare like for like.
	cam = _free_camera(A5_LINEUP_CAM, A5_LINEUP_LOOK, A2B_FOV)
	var rows: Array[Image] = []
	var made := 0
	for row in A5_ROWS:
		var three: Array[DaemonArt] = []
		for k in 3:
			three.append(_a5_art(row[0], row[2][k], _a5_seed(row[0], row[3][k], 600 + made * 50), DaemonArt.Act.MOVE, 0.0))
			made += 1
		await _frames(70)
		var built := PackedStringArray()
		for art in three:
			built.append("%d %.2f %d parts" % [art.build_seed, art.size_scale, art.part_count()])
		print("capture: the line-up's %s: %s" % [row[1], "; ".join(built)])
		rows.append(await _grab())
		for art in three:
			art.get_parent().queue_free()
	var sheet := Image.create(A5_LINEUP_BAND.size.x, A5_LINEUP_BAND.size.y * rows.size(), false, Image.FORMAT_RGBA8)
	for i in rows.size():
		sheet.blit_rect(rows[i], A5_LINEUP_BAND, Vector2i(0, A5_LINEUP_BAND.size.y * i))
	sheet.save_png(OUT.path_join("a5-lineup.png"))
	_shots += 1
	print("capture: a5-lineup, %d rows stacked" % rows.size())
	# What daemons cost: the nine of the line-up at once, three rows deep, drawn, then hidden.
	await _frames(5)
	var costed: Array[DaemonArt] = []
	for k in 9:
		var row: Array = A5_ROWS[k / 3]
		costed.append(_a5_art(row[0], row[2][k % 3] + Vector3(0.0, 0.0, -3.5 * (k / 3)), _a5_seed(row[0], row[3][k % 3], 600 + k * 50), DaemonArt.Act.MOVE, 0.0))
	await _frames(70)
	await _a5_cost(costed)
	for art in costed:
		art.get_parent().queue_free()
	_free_camera_done(cam)
	# The three elites, in their tells: rogue.d rearing, its visor flared; the zombie's cannon raised
	# and charging; the swarm pulled tight round its core.
	var elites: Array[DaemonArt] = []
	for e in A5_ELITES:
		elites.append(_a5_art(e[0], e[2], _a5_elite_seed(e[0], 4000 + elites.size() * 1000), DaemonArt.Act.TELL, 0.8))
	cam = _free_camera(A5_ELITE_CAM, A5_ELITE_LOOK, A2B_FOV)
	await _frames(70)
	var big := PackedStringArray()
	for art in elites:
		big.append("%s %d elite %s %.2f, %d parts" % [art.ai_kind, art.build_seed, art.elite, art.size_scale, art.part_count()])
	print("capture: the elites: " + "; ".join(big))
	await _save("a5-elite")
	_free_camera_done(cam)
	for art in elites:
		art.get_parent().queue_free()
	# The runaway's core killed: its drones scatter.
	_c27b_place(swarm, _main.to_global(Vector3(-8.0, 1.0, 12.0)))
	cam = _free_camera(A5_SCATTER_CAM, A5_SCATTER_LOOK, A2B_FOV)
	await _frames(60)
	swarm.hit(1000.0, swarm.global_position + Vector3(0.0, 0.9, 0.0), Vector3(-0.5, 0.0, -1.0).normalized())
	await _frames(A5_SCATTER_FRAMES)
	await _save("a5-scatter")
	_free_camera_done(cam)


## A creature of `type` alone (its art, no daemon round it) at `at` (arena space), built from `seed`,
## facing south to the a5 cameras, doing `act` `u` of the way through (A5).
func _a5_art(type: String, at: Vector3, seed: int, act: int, u: float) -> DaemonArt:
	var holder := Node3D.new()
	_main.add_child(holder)
	holder.position = at + Vector3(0.0, 0.9, 0.0)  # the body's centre over the ground, as a dummy's is
	holder.rotation.y = PI
	var art := DaemonArt.make(load("res://scripts/daemons/%s.gd" % type), null, seed)
	holder.add_child(art)
	art.drive(act, u)
	return art


## A seed of `type` that is no elite and rolls about `share` of its size range, searched from `from`.
func _a5_seed(_type: String, share: float, from: int) -> int:
	var best := from
	for seed in range(from, from + 400):
		if DaemonArt.elite_of(seed):
			continue
		if absf(DaemonArt.roll_of(seed, 9002, 3) - share) < absf(DaemonArt.roll_of(best, 9002, 3) - share):
			best = seed
	return best


## The first elite seed from `from`.
func _a5_elite_seed(_type: String, from: int) -> int:
	for seed in range(from, from + 5000):
		if DaemonArt.elite_of(seed):
			return seed
	return from


## What daemons cost (A5), on this machine: each type's posing timed alone (its three of the line-up,
## its whole _process, five rounds of A5_COST_FRAMES frames: the quickest round and the median, as
## the machine's other work only ever slows a round), and the GPU's time a frame with the nine drawn
## and with them hidden, three times each in turn (its spread is the timer's noise), with what the
## GPU drew each way.
func _a5_cost(lineup: Array[DaemonArt]) -> void:
	for k in 3:
		var three := lineup.slice(k * 3, k * 3 + 3)
		var rounds := PackedFloat32Array()
		for round in 5:
			var usec := 0
			for i in A5_COST_FRAMES:
				for art in three:
					var t0 := Time.get_ticks_usec()
					art._process(1.0 / 60.0)
					usec += Time.get_ticks_usec() - t0
				await _frames(1)
			rounds.append(float(usec) / (A5_COST_FRAMES * three.size()))
		rounds.sort()
		print("capture: a5 cost, %s posing: %.1f us a daemon a frame at the quickest, %.1f the median (rounds %s)" % [three[0].ai_kind, rounds[0], rounds[2], ", ".join(Array(rounds).map(func(x): return "%.1f" % x))])
	var gpu := PackedStringArray()
	var calls := PackedInt32Array([0, 0])
	var prims := PackedInt32Array([0, 0])
	for pass_ in 6:
		var shown := pass_ % 2 == 0
		for art in lineup:
			art.visible = shown
		await _frames(10)
		var ms := await _gpu_ms(A5_COST_FRAMES)
		gpu.append("%s %.3f" % ["drawn" if shown else "hidden", ms])
		calls[0 if shown else 1] = root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
		prims[0 if shown else 1] = root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
	for art in lineup:
		art.visible = true
	print("capture: a5 cost, the GPU's time a frame at 1920x1080 with the nine drawn and hidden in turn: %s ms; drawn %d draw calls and %d primitives, hidden %d and %d" % [", ".join(gpu), calls[0], prims[0], calls[1], prims[1]])


## Sends a ping: fire for one frame.
func _ping() -> void:
	_player.drive_input(Vector2.ZERO, false, false, true)
	await physics_frame


## Daemon `dummy` put at `at` (world space), facing the player, at home there.
func _c27b_place(dummy: Node3D, at: Vector3) -> void:
	dummy.global_position = at
	var way: Vector3 = _player.global_position - at
	dummy.global_rotation = Vector3(0.0, atan2(-way.x, -way.z), 0.0)
	dummy.brain.take_home()
	dummy.brain.moved = false
	dummy.brain.state = DaemonBrain.State.HOME
	dummy.brain.prey = 0


## The GPU's time for the root viewport, in milliseconds a frame, averaged over `frames` frames.
func _gpu_ms(frames: int) -> float:
	var rid := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	await _frames(5)
	var total := 0.0
	for i in frames:
		await _frames(1)
		await RenderingServer.frame_post_draw
		total += RenderingServer.viewport_get_measured_render_time_gpu(rid)
	RenderingServer.viewport_set_measure_render_time(rid, false)
	return total / frames


## A free camera at `at` looking at `look` (arena space), made current, the player and the HUD
## hidden.
func _free_camera(at: Vector3, look: Vector3, fov: float) -> Camera3D:
	var cam := Camera3D.new()
	cam.fov = fov
	_main.add_child(cam)
	cam.global_position = _main.to_global(at)
	cam.look_at(_main.to_global(look), Vector3.UP)
	cam.current = true
	_main.get_node("Hud").visible = false
	_player.visible = false
	return cam


## Back to the player's own camera and the HUD.
func _free_camera_done(cam: Camera3D) -> void:
	cam.current = false
	cam.queue_free()
	_main.get_node("Hud").visible = true
	_player.visible = true


## A still from a free camera at `at` looking at `look` (arena space), the player and the HUD hidden.
func _free_view(name: String, at: Vector3, look: Vector3) -> void:
	var cam := _free_camera(at, look, A3_OVERVIEW_FOV)
	await _frames(30)
	await _save(name)
	_free_camera_done(cam)


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


## What is on screen now, once it is drawn.
func _grab() -> Image:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image


## Stills side by side, each cut to A2B_CROP, as one image.
func _save_strip(name: String, stills: Array[Image]) -> void:
	var strip := Image.create(A2B_CROP.size.x * stills.size(), A2B_CROP.size.y, false, Image.FORMAT_RGBA8)
	for i in stills.size():
		strip.blit_rect(stills[i], A2B_CROP, Vector2i(A2B_CROP.size.x * i, 0))
	strip.save_png(OUT.path_join(name + ".png"))
	_shots += 1
	print("capture: %s, %d stills side by side" % [name, stills.size()])


func _save(name: String) -> void:
	var image := await _grab()
	image.save_png(OUT.path_join(name + ".png"))
	_shots += 1
	var drawn := []
	for kind in [Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_TYPE_SHADOW]:
		for info in [Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME, Viewport.RENDER_INFO_OBJECTS_IN_FRAME]:
			drawn.append(root.get_render_info(kind, info))
	print("capture: %s drew %d draw calls, %d primitives, %d objects; shadows %d draw calls, %d primitives, %d objects" % ([name] + drawn))
