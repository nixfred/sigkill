extends SceneTree
## SIGKILL's teaser footage (T1): a fixed shot list of real in-game clips on demo data, for the 70 second teaser at
## the top of playsigkill.com. One run plays one shot (-- --shot=<id>) under Godot's Movie Maker
## (--write-movie, --fixed-fps 60), and tools/trailer_capture.sh keeps the frames between the shot's roll and cut
## marks, one clip a shot, and writes shots.json beside them. `-- --list` prints the shot ids and draws nothing.
##
## The game is the game: the arena, the daemons, ICE, the weapons and the opener are the shipped scenes and scripts,
## driven as the capture tool and the tests drive them (the player's scripted input, its aim set each frame, a
## daemon put where the shot needs it, its brain left to fight). What the trailer adds is its own: the camera
## (moves along smooth paths, never a static frame), the HUD hidden, the 3D drawn at twice the window's resolution
## and filtered down (cleaner neon lines; the HUD and the opener's terminal are drawn as ever), the daemons a shot
## needs beyond the arena's four, each from its own seed, the player kept standing (its health topped up; a
## daemon's hits still land and show), and the title card at the end (the arena's own sign font for the wordmark,
## the brand's hexagon file as it is, never redrawn or recoloured).
##
## Demo data only, enforced here: it refuses to run without --demo, with the opener's real data switched on in its
## user data, or headless (it draws). The guide link is a demo one with its privacy file in user://, real machine
## data and the opener's real data written off there; the opener is checked to be on the demo's data before a frame
## of it is kept. Nothing of the machine is read: no folders, processes, themes or AI; no network.
##
## Seeded: the shots run frame by frame at the fixed rate, the global random generator and the player's own are
## seeded, every daemon is built from a fixed seed. The GPU's particles may differ by a pixel or so between takes.
##
## Each take writes user://trailer/<id>.json: the shot's id and description, the sounds that started (seconds after
## the roll, and which player played them) and the kills, for the shell to match to the loudest moments of the
## clip's own sound. A tool, never part of the game.

const Link = preload("res://scripts/guide/guide_link.gd")
const Privacy = preload("res://scripts/boot/guide_settings.gd")
const MainScene = preload("res://scenes/main.tscn")
const DummyScene = preload("res://scenes/target_dummy.tscn")
const SignFont = preload("res://scripts/arena/arena_font.gd")
const Palette = preload("res://scripts/palette.gd")
const LightTrails = preload("res://scripts/modes/light_trails.gd")
const RemotePlayer = preload("res://scripts/net/remote_player.gd")
const SfxSynth = preload("res://scripts/sfx_synth.gd")
const OUT := "user://trailer"
const PRIVACY_PATH := "user://trailer-privacy.cfg"
const SEED := 7031
## The 3D drawn at this many times the window's resolution, filtered down.
const SUPERSAMPLE := 2.0

## The shot list, in the running order: its id (the clip's file name), its length in seconds (as near as the
## frame), and what is in it.
const SHOTS := [
	{"id": "01a-crash", "s": 4.1, "about": "The arena mid-fight, the cannon on the daemons; then the opener seizes the frame: it freezes, tears, glitches apart and cuts to black."},
	{"id": "01b-thanks", "s": 3.0, "about": "The fake terminal: the prompt has typed itself (demo data: user@workstation), then: thanks for running me."},
	{"id": "01c-install", "s": 4.0, "about": "The terminal types, with a typo taken back: you never read the install script, did you?"},
	{"id": "01d-since", "s": 4.2, "about": "The folders scroll by (invented names), the uptime ticks, and it types: I've been in here since you booted."},
	{"id": "01e-reveal", "s": 3.4, "about": "The shrink-away: the camera pulls back and the terminal becomes one lit screen on a monolith in a city of your folders."},
	{"id": "01f-fall", "s": 3.2, "about": "The fall into the directory tree: past the towers of the top terrace and their names, down toward the node_modules pit."},
	{"id": "02a-skyline", "s": 3.6, "about": "Fly-through: from the dark megastructures of the skyline in over the arena's wall, its signs and code rain below."},
	{"id": "02b-trails", "s": 3.6, "about": "Fly-through, low over the grid: three light trails racing across the floor, code rain pouring down the walls behind."},
	{"id": "03a-rogue", "s": 3.0, "about": "rogue.d up close: the mantis-scorpion stalks in, rears in its tell and lunges, orbited low."},
	{"id": "03b-zombie", "s": 2.8, "about": "A zombie process charges its cannon, bands lighting, and fires a glitch bolt past the camera."},
	{"id": "03c-runaway", "s": 2.8, "about": "The runaway swarm: drones whirling round their core as it hunts, the camera circling with them."},
	{"id": "03d-pack", "s": 3.2, "about": "No two alike: a pack of seeded variants and an elite rogue.d charge the camera, tells flaring, attacks landing."},
	{"id": "04a-ice", "s": 3.4, "about": "ICE: a white ICE wall seals the corridor; the cannon cracks it and a brute ICEbreaker smashes through it."},
	{"id": "04b-black-ice", "s": 3.6, "about": "Black ICE: the arena's lights low, the machine's last defence grows out of the floor, spikes and all, the camera low and pushing in."},
	{"id": "05-01-cannon", "s": 1.5, "about": "Weapon 1, the terminal cannon: rapid beams, daemons derezzing."},
	{"id": "05-02-sigterm", "s": 1.5, "about": "Weapon 2, SIGTERM: violet bolts, a kill each."},
	{"id": "05-03-rail", "s": 2.8, "about": "Weapon 3, the SIGKILL rail, the ult: its coils charge and one beam goes through a line of daemons."},
	{"id": "05-04-fork-bomb", "s": 2.4, "about": "Weapon 4, the fork bomb: thrown into a crowd, it forks and forks again, blasts everywhere."},
	{"id": "05-05-shotgun", "s": 1.5, "about": "Weapon 5, the fork() shotgun: a spray of pellets that fork in flight."},
	{"id": "05-06-grep", "s": 1.8, "about": "Weapon 6, the grep seeker: darts lock on and curve into their matches."},
	{"id": "05-07-rm-rf", "s": 2.0, "about": "Weapon 7, the rm -rf cannon: a wind-up, then a slug and a blast ring."},
	{"id": "05-08-cron", "s": 1.8, "about": "Weapon 8, cron mines: laid on a schedule, they run when daemons walk in."},
	{"id": "05-09-ping", "s": 1.5, "about": "Weapon 9, ping: a sonar ring sweeps the floor and outlines every daemon."},
	{"id": "05-10-chmod", "s": 2.8, "about": "Weapon 10, chmod 000: the freeze beam frosts a daemon solid (PERMISSION DENIED) and it shatters."},
	{"id": "05-11-pipe", "s": 2.8, "about": "Weapon 11, pipe |: one chain beam arcs from daemon to daemon to daemon."},
	{"id": "05-12-dev-null", "s": 2.8, "about": "Weapon 12, /dev/null: a black hole drags a crowd of daemons in and implodes."},
	{"id": "05-13-sighup", "s": 2.8, "about": "Weapon 13, SIGHUP: a wave of static hangs up a crowd; confused, they turn on each other."},
	{"id": "06-fight", "s": 5.0, "about": "The big fight, wide: a crane over the arena as a crowd of daemons swarms the player and the heavy weapons go off."},
	{"id": "07-title", "s": 6.0, "about": "Title: the SIGKILL wordmark slams together out of voxels, the nixfred hexagon, pre-alpha, playsigkill.com."},
]

var _id := ""
var _shot: Dictionary
var _main: Node3D
var _player: Node
var _life: Node
var _targets: Node3D
var _cam: Camera3D
var _rolled := false
var _clock := 0.0
var _frame := 0
var _sounds: Array = []
var _events: Array = []
var _heard := {}
var _names := {}
var _guard := true
var _refused := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--list"):
		for shot in SHOTS:
			print("trailer: shot " + shot["id"])
		quit(0)
		return
	for arg in args:
		if arg.begins_with("--shot="):
			_id = arg.substr(7)
	var why := refusal(args, DisplayServer.get_name(), Privacy.DEFAULT_PATH)
	if why == "" and shot_named(_id).is_empty():
		why = "no shot named \"%s\" (-- --list lists them)" % _id
	if why != "":
		print("trailer: refused: " + why)
		quit(3)
		return
	_shot = shot_named(_id)
	_run()


## Why this run may not go ahead, or "" when it may: demo data only (--demo, and the opener's real data not on in
## the user data it would run with), and never headless (it draws).
static func refusal(args: PackedStringArray, display: String, settings_path: String) -> String:
	if not args.has("--demo"):
		return "demo data only: run it with -- --demo (tools/trailer_capture.sh does)"
	if Privacy.opener_real_on(settings_path):
		return "the opener's real data is on in this user data: run it on fresh, empty user data (tools/trailer_capture.sh does)"
	if display == "headless":
		return "headless draws nothing: run it on a private virtual display (tools/trailer_capture.sh)"
	return ""


static func shot_named(id: String) -> Dictionary:
	for shot in SHOTS:
		if shot["id"] == id:
			return shot
	return {}


func _run() -> void:
	seed(SEED)
	DirAccess.make_dir_recursive_absolute(OUT)
	# The guide's link on demo data, its privacy file in user:// with the real data written off.
	Privacy.save_real_data(false, PRIVACY_PATH)
	Privacy.save_opener_real(false, PRIVACY_PATH)
	var link := Link.new()
	link.settings_path = PRIVACY_PATH
	link.demo = true
	Link.park(link)
	_main = MainScene.instantiate()
	_targets = _main.get_node("Arena/Targets")
	_add_daemons()
	root.add_child(_main)
	current_scene = _main
	await process_frame  # in _initialize the root is not in the tree yet: the arena is ready from here
	_player = _main.get_node("Player")
	_player.assume_captured = true
	_life = _main.get_node("SoloLife")
	for rng in ["_rng", "_pellet_rng", "_bomb_rng", "_shake_rng"]:
		var r = _player.get(rng)
		if r is RandomNumberGenerator:
			r.seed = SEED
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameSettings.current().set_value("gameplay", "practice", true)
	_hide_hud()
	_park_all()
	process_frame.connect(_hide_tags)
	await _frames(90)  # shaders compiled, the code rain running
	var method := "_shot_" + _id.replace("-", "_")
	await call(method)
	if _refused:
		return
	_cut()
	quit(0)


# --- The daemons -------------------------------------------------------------------------------------------------

## The arena's four plus these, built before the arena enters the tree so the director steps them: [name, type,
## tag, seed or -1 for its name's own]. Each waits under the floor until a shot puts it somewhere.
const EXTRA := [
	["R1", "rogue_daemon", "rogue.d", 211], ["R2", "rogue_daemon", "rogue.d", 1907], ["R3", "rogue_daemon", "rogue.d", 4410],
	["R4", "rogue_daemon", "rogue.d", 7121], ["Z1", "zombie_process", "zombie", 512], ["Z2", "zombie_process", "<defunct>", 2981],
	["Z3", "zombie_process", "zombie", 6060], ["S1", "runaway_swarm", "runaway", 333], ["S2", "runaway_swarm", "runaway", 5150],
	["E1", "rogue_daemon", "rogue.d", -2], ["E2", "zombie_process", "zombie", -2], ["E3", "runaway_swarm", "runaway", -2],
]
const PARKED := Vector3(0.0, -50.0, 0.0)
var _seeds := {}


func _add_daemons() -> void:
	for spec in EXTRA:
		var dummy: Node3D = DummyScene.instantiate()
		dummy.name = spec[0]
		dummy.tag_text = spec[2]
		dummy.art = load("res://scripts/daemons/%s.gd" % spec[1])
		dummy.position = PARKED
		_targets.add_child(dummy)
		var s: int = spec[3]
		if s == -2:
			s = _elite_seed(9000 + _seeds.size() * 1000)
		if s >= 0:
			_seeds[spec[0]] = s


func _elite_seed(from: int) -> int:
	for s in range(from, from + 5000):
		if DaemonArt.elite_of(s):
			return s
	return from


func _daemon(name: String) -> Node3D:
	var d: Node3D = _targets.get_node(name)
	if _seeds.has(name) and d.build_seed() != _seeds[name]:
		d.follow_seed(_seeds[name])
	return d


## Every daemon under the floor, at home there.
func _park_all() -> void:
	for dummy in _targets.get_children():
		_place(dummy, PARKED + Vector3(dummy.get_index() * 3.0, 0.0, 0.0), Vector3.FORWARD)


## `dummy` put at `at` (arena space), facing `toward` (arena space), at home there.
func _place(dummy: Node3D, at: Vector3, toward: Vector3) -> void:
	dummy.global_position = _main.to_global(at)
	var way: Vector3 = toward - at
	dummy.global_rotation = Vector3(0.0, atan2(-way.x, -way.z), 0.0)
	dummy.brain.take_home()
	dummy.brain.moved = false
	dummy.brain.state = DaemonBrain.State.HOME
	dummy.brain.prey = 0


## The daemons fight back from here (true), or stand as practice's old dummies (false).
func _fight(on: bool) -> void:
	GameSettings.current().set_value("gameplay", "practice", not on)


# --- The frame, the HUD, the camera ------------------------------------------------------------------------------

## The daemons' floating names: clutter on screen (the edit can title them). Hidden every frame before it is drawn, as
## a daemon shows its own again when it comes back.
func _hide_tags() -> void:
	if _targets != null and is_instance_valid(_targets):
		for dummy in _targets.get_children():
			dummy.get("_tag").visible = false


func _hide_hud() -> void:
	var hud: Node = _main.get_node("Hud")
	for child in hud.get_children():
		if child is CanvasItem and child != hud.pause_menu():
			child.visible = false
	root.scaling_3d_scale = SUPERSAMPLE


## The trailer's own camera at `at` looking at `look` (arena space), made current, the player's body hidden.
func _camera(at: Vector3, look: Vector3, fov: float) -> Camera3D:
	if _cam == null:
		_cam = Camera3D.new()
		_cam.name = "TrailerCamera"
		_main.add_child(_cam)
	_cam.fov = fov
	_cam.far = 4000.0
	_aim_camera(at, look)
	_cam.current = true
	_player.visible = false
	return _cam


func _aim_camera(at: Vector3, look: Vector3) -> void:
	_cam.global_position = _main.to_global(at)
	var up := Vector3.UP if absf((look - at).normalized().y) < 0.995 else Vector3.FORWARD
	_cam.look_at(_main.to_global(look), up)


## Back to the player's own eyes.
func _first_person() -> void:
	if _cam != null:
		_cam.current = false
	_player.visible = true
	_player.get_node("Head/Camera").current = true


## A point on the smooth path through `points` (Catmull-Rom, through every point), `u` from 0 to 1.
static func spline(points: Array, u: float) -> Vector3:
	var n := points.size()
	if n == 1:
		return points[0]
	var f := clampf(u, 0.0, 1.0) * (n - 1)
	var i := mini(int(f), n - 2)
	var t := f - i
	var p0: Vector3 = points[maxi(i - 1, 0)]
	var p1: Vector3 = points[i]
	var p2: Vector3 = points[i + 1]
	var p3: Vector3 = points[mini(i + 2, n - 1)]
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)


## Smooth start and end, `u` from 0 to 1.
static func ease_both(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


## The player standing at `at` (arena space), looking at `look` (arena space).
func _stand(at: Vector3, look: Vector3) -> void:
	_player.respawn_at(_main.to_global(at))
	await _frames(2)
	_look_at(look, 1.0)


## The player's view turned toward `look` (arena space): all the way (`share` 1), or that share of the way.
func _look_at(look: Vector3, share: float) -> void:
	var cam: Camera3D = _player.get_node("Head/Camera")
	var to := _main.to_global(look) - cam.global_position
	var yaw := atan2(-to.x, -to.z)
	var pitch := atan2(to.y, Vector2(to.x, to.z).length())
	var head: Node3D = _player.get_node("Head")
	_player.rotation.y = lerp_angle(_player.rotation.y, yaw, share)
	head.rotation.x = lerpf(head.rotation.x, pitch, share)


## A daemon's middle, in arena space, for aiming.
func _middle(dummy: Node3D) -> Vector3:
	return _main.to_local(dummy.global_position) + Vector3.UP * 0.95


# --- Frames, the roll and the cut, what was heard ----------------------------------------------------------------

## `n` frames, the player given `move` (and `fire` pressed) each frame.
func _frames(n: int, move: Vector2 = Vector2.ZERO, fire: bool = false) -> void:
	for i in n:
		await _tick(move, fire)


## One frame: the player's input for it, kept standing, and what was heard noted.
func _tick(move: Vector2 = Vector2.ZERO, fire: bool = false) -> void:
	if _player != null and is_instance_valid(_player):
		_player.drive_input(move, false, false, fire)
	if _guard and _life != null and _life.alive() and _life.health() < 60.0:
		_life.combat.states[SoloLife.ME]["health"] = _life.max_health()
	await physics_frame
	if _rolled:
		_clock += 1.0 / 60.0
		_frame += 1
		_listen()


## The first frame kept: printed as the movie's frame number for the shell.
func _roll() -> void:
	_rolled = true
	_clock = 0.0
	_frame = 0
	_heard.clear()
	_names.clear()
	var trios: Array = _player.get("_sfx")
	for slot in trios.size():
		var weapon: String = _player.inventory.defs[slot].id
		for k in 3:
			_names[trios[slot][k].get_instance_id()] = "%s %s" % [weapon, ["fire", "hit", "reload"][k]]
	var chime = _main.get_node("Hud").round_hud().get("_chime")
	if chime is AudioStreamPlayer:
		_names[chime.get_instance_id()] = "kill chime"
	for p in _audio_players():
		_heard[p.get_instance_id()] = p.get_playback_position() if p.playing else -1.0
	print("trailer: roll at frame %d" % Engine.get_frames_drawn())
	for dummy in _targets.get_children():
		if not dummy.downed.is_connected(_on_downed):
			dummy.downed.connect(_on_downed)


func _cut() -> void:
	print("trailer: cut at frame %d" % Engine.get_frames_drawn())
	var take := {"id": _id, "description": _shot["about"], "frames": _frame, "sounds": _sounds, "events": _events}
	var file := FileAccess.open(OUT.path_join(_id + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(take, "  "))
	file.close()


## The shot's own length in frames.
func _length() -> int:
	return roundi(float(_shot["s"]) * 60.0)


func _on_downed(dummy: Node3D) -> void:
	if _rolled:
		_events.append({"t": snappedf(_clock, 0.001), "what": "kill", "daemon": dummy.tag_text, "weapon": str(dummy.get("killed_with"))})


func _audio_players() -> Array:
	return root.find_children("*", "AudioStreamPlayer", true, false) + root.find_children("*", "AudioStreamPlayer3D", true, false) + root.find_children("*", "AudioStreamPlayer2D", true, false)


## Every sound that started this frame (a looping one's restart is not a start), by what it is: the player's own by
## weapon and kind, the round's kill chime, else the node's name (with its parent's when the node has none of its own).
func _listen() -> void:
	for p in _audio_players():
		var key: int = p.get_instance_id()
		var was: float = _heard.get(key, -1.0)
		var now: float = p.get_playback_position() if p.playing else -1.0
		var loops: bool = p.stream is AudioStreamWAV and p.stream.loop_mode != AudioStreamWAV.LOOP_DISABLED
		if p.playing and (was < 0.0 or (now + 0.02 < was and not loops)):
			var who: String = _names.get(key, String(p.name).replace("@", " ").strip_edges())
			if who.begins_with("AudioStreamPlayer"):
				who = String(p.get_parent().name).replace("@", " ").strip_edges() + " sound"
			_sounds.append({"t": snappedf(_clock - 1.0 / 60.0, 0.001), "name": who})
		_heard[key] = now


# --- First person: aim and fire ------------------------------------------------------------------------------------

## The first of `order` still alive (and in the arena, not parked), or null; with `nearest`, the nearest of them to
## the player instead.
func _first_alive(order: Array, nearest: bool = false) -> Node3D:
	var best: Node3D = null
	for d in order:
		if is_instance_valid(d) and d.is_alive() and d.global_position.y > -10.0:
			if not nearest:
				return d
			if best == null or d.global_position.distance_to(_player.global_position) < best.global_position.distance_to(_player.global_position):
				best = d
	return best


## True when the player's aim is on `point` (arena space): within `radius` metres of it, as seen from the eyes.
func _on_target(point: Vector3, radius: float) -> bool:
	var cam: Camera3D = _player.get_node("Head/Camera")
	var to := _main.to_global(point) - cam.global_position
	return _player.aim_direction().angle_to(to.normalized()) < atan(radius / maxf(to.length(), 0.5))


## `frames` frames of a fight in first person: the view swinging onto the first of `order` alive (a share `turn` of
## the way each frame) and firing once it is on (within `radius` metres of its middle), the player moving by `move`.
func _gun(frames: int, order: Array, move: Vector2, turn: float = 0.3, radius: float = 0.45) -> void:
	for i in frames:
		var t := _first_alive(order)
		var fire := false
		if t != null:
			_look_at(_middle(t), turn)
			fire = _on_target(_middle(t), radius)
		await _tick(move, fire)


## The weapon in `slot` drawn and settled, standing at `at` looking at `look` (arena space).
func _draw(slot: int, at: Vector3, look: Vector3) -> void:
	await _stand(at, look)
	_first_person()
	_player.select_slot(slot)
	await _frames(110)  # the raise done


# --- The opener ---------------------------------------------------------------------------------------------------

## The opener from the Esc menu, as a player picks it, checked to be on the demo's data; null (the run refused)
## when it is not.
func _open_opener() -> Opener:
	var opener: Opener = _main.get_node("Hud").pause_menu().open_opener()
	if opener == null or not (opener.data is DemoOpenerData):
		_refuse("the opener is not on the demo's data")
		return null
	return opener


func _refuse(why: String) -> void:
	print("trailer: refused: " + why)
	_refused = true
	quit(3)


## Frames until the opener's clock is at `seconds`.
func _opener_to(opener: Opener, seconds: float) -> void:
	while is_instance_valid(opener) and opener.playing() and opener.elapsed() < seconds:
		await _tick()


## An opener shot: the arena standing by, the opener from the menu, kept from its clock at `from` to `to`, in the
## demo palette `palette`. With `push` ([the screen point to hold, where it starts and ends on screen, the start and
## end scale]), a slow push-in on the terminal: its layer scaled toward the line being typed, a camera move on the
## real screen (nothing redrawn); only while the terminal is the 2D screen, never across the 3D swap.
func _opener_shot(from: float, to: float, palette: String, push: Array = []) -> void:
	await _stand(Vector3(0.8, 0.95, 14.4), Vector3(0.0, 1.0, 8.8))
	var opener := _open_opener()
	if opener == null:
		return
	await _opener_to(opener, from - 0.25)
	opener.set_palette(OpenerPalette.named(palette))
	await _opener_to(opener, from)
	_roll()
	while is_instance_valid(opener) and opener.playing() and opener.elapsed() < to:
		if not push.is_empty():
			var u := ease_both((opener.elapsed() - from) / (to - from))
			var scale: float = lerpf(push[3], push[4], u)
			var held: Vector2 = push[1].lerp(push[2], u)
			opener.transform = Transform2D(0.0, Vector2(scale, scale), 0.0, held - push[0] * scale)
		await _tick()


## The arena mid-fight, the cannon on a rogue.d, then the opener seizes the frame, glitches it apart and cuts to black.
func _shot_01a_crash() -> void:
	var a := _daemon("DummyA")
	var r1 := _daemon("R1")
	var z1 := _daemon("Z1")
	var s1 := _daemon("S1")
	var me := Vector3(0.8, 0.0, 14.6)
	await _draw(0, me + Vector3.UP * 0.95, Vector3(0.0, 1.0, 8.6))
	_place(a, Vector3(0.0, 0.0, 9.0), me)
	_place(r1, Vector3(3.0, 0.0, 6.8), me)
	_place(z1, Vector3(-3.4, 0.0, 6.2), me)
	_place(s1, Vector3(-0.8, 1.0, 4.6), me)
	_fight(true)
	await _frames(30)
	_roll()
	await _gun(44, [r1, a], Vector2(-0.35, 0.0))
	var opener := _open_opener()
	if opener == null:
		return
	await _opener_to(opener, 3.3)


func _shot_01b_thanks() -> void:
	await _opener_shot(14.9, 17.9, "night", [Vector2(12.0, 22.0), Vector2(150.0, 300.0), Vector2(110.0, 250.0), 1.9, 2.3])


func _shot_01c_install() -> void:
	await _opener_shot(18.95, 22.95, "night", [Vector2(12.0, 30.0), Vector2(150.0, 300.0), Vector2(100.0, 260.0), 1.9, 2.25])


func _shot_01d_since() -> void:
	await _opener_shot(26.3, 30.5, "night", [Vector2(12.0, 940.0), Vector2(60.0, 980.0), Vector2(110.0, 880.0), 1.15, 1.5])


func _shot_01e_reveal() -> void:
	await _opener_shot(40.7, 44.1, "night")


func _shot_01f_fall() -> void:
	await _opener_shot(51.8, 55.0, "latte")


# --- The arena ----------------------------------------------------------------------------------------------------

## From out among the skyline's megastructures, in over the arena's north wall, slowing as the arena opens below.
func _shot_02a_skyline() -> void:
	var path := [Vector3(78.0, 34.0, -128.0), Vector3(46.0, 26.0, -74.0), Vector3(20.0, 15.0, -32.0), Vector3(6.0, 8.5, -8.0)]
	var look := [Vector3(10.0, 4.0, -20.0), Vector3(4.0, 2.0, -10.0), Vector3(0.0, 0.5, 0.0), Vector3(-3.0, 0.5, 6.0)]
	_camera(path[0], look[0], 68.0)
	await _frames(10)
	_roll()
	var n := _length()
	for i in n:
		var u := 1.0 - pow(1.0 - float(i) / (n - 1), 1.6)
		_aim_camera(spline(path, u), spline(look, u))
		_cam.fov = lerpf(68.0, 58.0, u)
		await _tick()


## Three runners' light walls (light-trail mode's own, C20) laid across the open floor as they race, the camera low
## and sliding along the south wall.
func _shot_02b_trails() -> void:
	var trails = LightTrails.of(_main, load("res://resources/light_trail.tres"))
	var runners: Array = []
	for k in 3:
		trails.paint(k + 1, Palette.trail_color(k))
		var body = RemotePlayer.new()
		body.player_id = k + 1
		body.player_name = ""
		body.interp_delay_s = 0.0
		_main.add_child(body)
		runners.append(body)
	var path := [Vector3(-16.0, 7.5, 2.0), Vector3(-15.0, 6.2, 9.0), Vector3(-13.0, 5.0, 15.0)]
	var look := [Vector3(0.0, 0.0, 12.0), Vector3(2.0, 0.0, 12.0), Vector3(4.0, 0.0, 11.0)]
	_camera(path[0], look[0], 60.0)
	var lead := 40
	var n := _length()
	for i in lead + n:
		var t := (i - lead) / 60.0 + 0.4
		for k in 3:
			var at := _runner(k, t)
			var ahead := _runner(k, t + 1.0 / 60.0)
			trails.advance(k + 1, at, true)
			var way := ahead - at
			runners[k].push_sample(i, at + Vector3.UP * 0.95, atan2(-way.x, -way.z), 0.0, way * 60.0)
			runners[k].get("_tag").visible = false
		trails.tick(1.0 / 60.0)
		if i == lead:
			_roll()
		if i >= lead:
			var u := ease_both(float(i - lead) / (n - 1))
			_aim_camera(spline(path, u), spline(look, u))
		await _tick()


## The runners' courses (arena space, on the floor): light-cycle runs with right-angle turns across the open floor,
## clear of the cover, the crates and the platform; each starts a little after the one before.
const RUNS := [
	[Vector3(-18.0, 0.0, 16.5), Vector3(-3.0, 0.0, 16.5), Vector3(-3.0, 0.0, 6.0), Vector3(10.0, 0.0, 6.0), Vector3(10.0, 0.0, 16.0), Vector3(18.0, 0.0, 16.0)],
	[Vector3(18.0, 0.0, 13.5), Vector3(3.0, 0.0, 13.5), Vector3(3.0, 0.0, 18.5), Vector3(-10.0, 0.0, 18.5), Vector3(-10.0, 0.0, 15.0), Vector3(-18.0, 0.0, 15.0)],
	[Vector3(-11.0, 0.0, 4.0), Vector3(-11.0, 0.0, 9.0), Vector3(0.5, 0.0, 9.0), Vector3(0.5, 0.0, 14.8), Vector3(16.0, 0.0, 14.8)],
]
const RUN_SPEED := 13.0
const RUN_START := [0.0, 0.35, 0.8]


## Where runner `k` is at `t` seconds: along its course at RUN_SPEED, held at either end.
static func _runner(k: int, t: float) -> Vector3:
	var course: Array = RUNS[k]
	var d := maxf(t - RUN_START[k], 0.0) * RUN_SPEED
	for i in course.size() - 1:
		var a: Vector3 = course[i]
		var b: Vector3 = course[i + 1]
		var leg := a.distance_to(b)
		if d <= leg:
			return a.lerp(b, d / leg)
		d -= leg
	return course[course.size() - 1]


# --- The daemons --------------------------------------------------------------------------------------------------

## A camera orbiting `dummy` (followed, smoothed) at `radius` metres and `height` over its feet, from `from` to `to`
## radians round it (0: on its way to the player), looking at `look_h` over its feet, for `n` frames.
func _orbit(dummy: Node3D, n: int, radius: Vector2, height: Vector2, from: float, to: float, look_h: float, fov: float) -> void:
	var centre := _main.to_local(dummy.global_position)
	for i in n:
		var u := ease_both(float(i) / maxi(n - 1, 1))
		if dummy.is_alive():
			centre = centre.lerp(_main.to_local(dummy.global_position), 0.12)
		var me := _main.to_local(_player.global_position)
		var toward := Vector3(me.x - centre.x, 0.0, me.z - centre.z).normalized()
		var side := toward.rotated(Vector3.UP, lerpf(from, to, u))
		var at := centre + side * lerpf(radius.x, radius.y, u) + Vector3.UP * lerpf(height.x, height.y, u)
		if i == 0:
			_camera(at, centre + Vector3.UP * look_h, fov)
		else:
			_aim_camera(at, centre + Vector3.UP * look_h)
		await _tick()


## rogue.d stalks in, rears in its tell and lunges, orbited low from its front.
func _shot_03a_rogue() -> void:
	var r := _daemon("R3")
	var me := Vector3(0.0, 0.0, 16.0)
	await _stand(me + Vector3.UP * 0.95, Vector3(0.0, 1.0, 10.0))
	_place(r, Vector3(0.6, 0.0, 10.4), me)
	_fight(true)
	await _frames(20)
	_roll()
	await _orbit(r, _length(), Vector2(3.6, 3.0), Vector2(0.5, 0.9), 0.55, 1.25, 1.05, 52.0)


## A zombie charges its cannon at the player and fires, the camera pushing in beside the bolt's path.
func _shot_03b_zombie() -> void:
	var z := _daemon("Z3")
	var me := Vector3(0.0, 0.0, 17.5)
	await _stand(me + Vector3.UP * 0.95, Vector3(-3.0, 1.0, 4.0))
	_place(z, Vector3(-3.4, 0.0, 3.6), me)
	_fight(true)
	var waited := 0
	while z.brain.state != DaemonBrain.State.TELL and waited < 600:
		await _tick()
		waited += 1
	await _frames(maxi(0, 40 - waited))
	_roll()
	await _orbit(z, _length(), Vector2(4.0, 2.6), Vector2(1.0, 0.75), 0.6, 0.15, 1.35, 50.0)


## The runaway's drones whirling round its core as it hunts, circled.
func _shot_03c_runaway() -> void:
	var s := _daemon("S2")
	var me := Vector3(0.0, 0.0, 16.0)
	await _stand(me + Vector3.UP * 0.95, Vector3(-1.0, 1.5, 9.0))
	_place(s, Vector3(-1.0, 1.0, 9.0), me)
	_fight(false)  # at home: its drones whirl round it, the camera circles close
	await _frames(30)
	_roll()
	await _orbit(s, _length(), Vector2(3.6, 3.0), Vector2(2.2, 1.3), -0.9, 0.5, 0.9, 50.0)


## A pack of seeded variants round an elite rogue.d charge the player, the camera low just in front of it, backing off.
func _shot_03d_pack() -> void:
	var me := Vector3(0.0, 0.0, 19.4)
	await _stand(me + Vector3.UP * 0.95, Vector3(0.0, 1.0, 8.0))
	var pack := [["E1", Vector3(0.2, 0.0, 7.0)], ["R1", Vector3(-2.6, 0.0, 5.6)], ["R2", Vector3(2.8, 0.0, 5.2)], ["R4", Vector3(-0.8, 0.0, 3.4)],
		["Z1", Vector3(-5.0, 0.0, 5.6)], ["Z2", Vector3(5.2, 0.0, 5.2)], ["S1", Vector3(1.6, 1.0, 3.0)], ["E2", Vector3(-3.6, 0.0, 3.0)]]
	for p in pack:
		_place(_daemon(p[0]), p[1], me)
	_fight(true)
	await _frames(25)
	_roll()
	var path := [Vector3(0.6, 0.38, 14.6), Vector3(0.3, 0.9, 16.4), Vector3(-0.2, 3.2, 18.4), Vector3(-0.6, 5.4, 19.6)]
	var look := [Vector3(0.0, 1.2, 6.0), Vector3(0.0, 1.1, 9.0), Vector3(0.0, 0.6, 13.0), Vector3(0.0, 0.2, 15.5)]
	_camera(path[0], look[0], 56.0)
	var n := _length()
	for i in n:
		var u := ease_both(float(i) / (n - 1))
		_aim_camera(spline(path, u), spline(look, u))
		await _tick()


# --- ICE ----------------------------------------------------------------------------------------------------------

## The corridor's white ICE wall: the cannon cracking it while walking up, then a brute ICEbreaker through it.
func _shot_04a_ice() -> void:
	GameSettings.current().set_value("gameplay", "ice", true)
	_fight(true)
	await _frames(10)
	var ice: IceDirector = _main.get_node(IceDirector.NODE_NAME)
	var br: BreakerDirector = _main.get_node(BreakerDirector.NODE_NAME)
	ice.start_round(1)
	br.start_round(1)
	await _frames(10)
	_park_all()
	var wall := ice.wall("wall")
	var look := Vector3(-17.6, 1.6, 8.0)
	await _draw(0, Vector3(-17.0, 0.95, 1.4), look)
	_roll()
	var n := _length()
	var brute_at := 112
	for i in n:
		_look_at(look + Vector3(sin(i * 0.05) * 0.3, 0.0, 0.0), 0.2)
		var fire := i < 110 and i % 9 == 0 and not wall.broken and wall.health() > wall.max_health * 0.3
		if i == brute_at and not wall.broken:
			br.use(1, Breakers.Kind.BRUTE, _player.eye_position(), _player.aim_direction())
		await _tick(Vector2(0.0, -0.5) if i < brute_at else Vector2.ZERO, fire)


## Black ICE: the lights die and it grows out of the floor, the camera pushing in low and tilting up to it.
func _shot_04b_black_ice() -> void:
	GameSettings.current().set_value("gameplay", "ice", true)
	_fight(true)
	await _frames(10)
	var ice: IceDirector = _main.get_node(IceDirector.NODE_NAME)
	_main.get_node("Hud").round_hud()._start_round(3)
	await _frames(5)
	_park_all()
	for kind in ["jam", "hud"]:
		var node := ice.node_of(kind)
		if node != null:
			node.hit(1000.0, Vector3.INF, Vector3.ZERO, "")
			node.hit(1000.0, Vector3.INF, Vector3.ZERO, "")
	if ice.hunter != null:
		for i in 3:
			ice.hunter.hit(1000.0, Vector3.INF, Vector3.ZERO, "")
	var spot: Vector3 = IceDirector.BLACK_SPOTS[3]
	var me := spot + Vector3(3.0, 0.0, 7.5)
	await _stand(me + Vector3.UP * 0.95, spot + Vector3.UP * 2.0)
	var b := ice.summon_black(3)
	while b.phase_t < ice.black_tuning.tell_s - float(_shot["s"]) + 0.4:
		await _tick()
	_roll()
	var path := [spot + Vector3(2.8, 1.3, 5.4), spot + Vector3(2.0, 0.9, 4.2), spot + Vector3(1.3, 0.6, 3.2)]
	var look := [spot + Vector3(0.0, 0.8, 0.0), spot + Vector3(0.0, 1.6, 0.0), spot + Vector3(0.0, 2.4, 0.0)]
	_camera(path[0], look[0], 56.0)
	var n := _length()
	for i in n:
		var u := ease_both(float(i) / (n - 1))
		_aim_camera(spline(path, u), spline(look, u))
		await _tick()


# --- The weapons --------------------------------------------------------------------------------------------------

const ME_AT := Vector3(0.5, 0.0, 14.5)


## Daemons `names` put at `spots` (arena space), facing the player at ME_AT, turned loose.
func _crowd(names: Array, spots: Array) -> Array:
	var out := []
	for i in names.size():
		var d := _daemon(names[i])
		_place(d, spots[i], ME_AT)
		out.append(d)
	return out


## `frames` frames of `_gun` with a pause of `gap` frames after each kill: the view moves on, the trigger waits.
func _gun_paced(frames: int, order: Array, move: Vector2, gap: int, turn: float = 0.3) -> void:
	var wait := 0
	var last := _first_alive(order, true)
	for i in frames:
		var t := _first_alive(order, true)
		if t != last:
			wait = gap
			last = t
		var fire := false
		if t != null:
			_look_at(_middle(t), turn)
			fire = wait <= 0 and _on_target(_middle(t), 0.45)
		wait -= 1
		await _tick(move, fire)


func _weapon_start(slot: int, look: Vector3) -> void:
	await _draw(slot, ME_AT + Vector3.UP * 0.95, look)


func _shot_05_01_cannon() -> void:
	await _weapon_start(0, Vector3(0.0, 1.0, 8.0))
	var c := _crowd(["DummyA", "R1", "Z1", "R2", "S1"], [Vector3(-1.0, 0.0, 9.0), Vector3(3.2, 0.0, 7.0), Vector3(-4.2, 0.0, 6.0), Vector3(1.4, 0.0, 4.4), Vector3(-2.0, 1.0, 3.6)])
	_fight(true)
	await _frames(30)
	_roll()
	await _gun_paced(_length(), c, Vector2(0.5, 0.35), 10)


func _shot_05_02_sigterm() -> void:
	await _weapon_start(1, Vector3(0.0, 1.0, 8.0))
	var c := _crowd(["R2", "Z2", "R4", "DummyC"], [Vector3(2.0, 0.0, 8.6), Vector3(-2.6, 0.0, 7.0), Vector3(3.8, 0.0, 5.0), Vector3(-0.6, 0.0, 4.6)])
	_fight(true)
	await _frames(30)
	_roll()
	await _gun_paced(_length(), c, Vector2(-0.5, 0.35), 8)


## The rail: a full meter, its charge, one beam through a line of daemons; the meter refilled, a second line.
func _shot_05_03_rail() -> void:
	await _weapon_start(2, Vector3(0.4, 1.0, 8.0))
	var first := _crowd(["E1", "R1", "Z1"], [Vector3(0.4, 0.0, 9.0), Vector3(0.3, 0.0, 6.0), Vector3(0.2, 0.0, 3.2)])
	var second := _crowd(["R2", "R3", "S1"], [Vector3(-2.2, 0.0, 5.5), Vector3(-3.6, 0.0, 2.8), Vector3(-5.0, 1.0, 0.2)])
	_fight(true)
	_player.inventory.add_meter(_player.inventory.meter_full())
	await _frames(12)
	_roll()
	var n := _length()
	var aim_second := false
	for i in n:
		if i == 70:
			aim_second = true
			_player.inventory.add_meter(_player.inventory.meter_full())
		var t := _first_alive(second if aim_second else first)
		var fire := false
		if t != null:
			_look_at(_middle(t), 0.25)
			fire = _on_target(_middle(t), 0.35) and (i > 8 and not aim_second or i > 84)
		await _tick(Vector2.ZERO, fire)


## The fork bomb: thrown into a crowd, forking, blasts everywhere; a second one after it.
func _shot_05_04_fork_bomb() -> void:
	await _weapon_start(3, Vector3(0.0, 1.6, 8.0))
	var spots := [Vector3(-1.6, 0.0, 8.0), Vector3(1.8, 0.0, 7.6), Vector3(0.0, 0.0, 6.2), Vector3(-3.4, 0.0, 6.4), Vector3(3.6, 0.0, 5.6), Vector3(-0.6, 1.0, 4.6), Vector3(2.0, 0.0, 4.0)]
	_crowd(["R1", "R2", "Z1", "R4", "Z2", "S1", "DummyA"], spots)
	_fight(true)
	await _frames(20)
	_roll()
	var n := _length()
	for i in n:
		_look_at(Vector3(0.2 * sin(i * 0.04), 1.3, 7.0), 0.15)
		await _tick(Vector2(0.15, 0.3), i == 6)


func _shot_05_05_shotgun() -> void:
	await _weapon_start(4, Vector3(0.0, 1.0, 10.0))
	var c := _crowd(["R1", "R2", "Z1", "R4"], [Vector3(-1.2, 0.0, 9.4), Vector3(1.6, 0.0, 8.8), Vector3(-2.8, 0.0, 7.6), Vector3(0.4, 0.0, 7.0)])
	_fight(true)
	await _frames(24)
	_roll()
	await _gun_paced(_length(), c, Vector2(0.25, 0.6), 8)


func _shot_05_06_grep() -> void:
	await _weapon_start(5, Vector3(0.0, 1.0, 8.0))
	var c := _crowd(["R2", "Z2", "R3", "S2", "Z3"], [Vector3(-3.0, 0.0, 9.0), Vector3(3.0, 0.0, 8.4), Vector3(-5.0, 0.0, 5.4), Vector3(1.0, 1.0, 4.0), Vector3(5.0, 0.0, 5.0)])
	_fight(true)
	await _frames(30)
	_roll()
	await _gun_paced(_length(), c, Vector2(-0.4, 0.25), 6, 0.35)


## rm -rf: the wind-up, then the slug into a knot of three and the blast ring.
func _shot_05_07_rm_rf() -> void:
	await _weapon_start(6, Vector3(0.0, 1.0, 7.0))
	var c := _crowd(["E2", "R1", "R2", "Z1"], [Vector3(0.0, 0.0, 7.0), Vector3(-1.4, 0.0, 7.8), Vector3(1.4, 0.0, 7.6), Vector3(0.2, 0.0, 5.4)])
	_fight(true)
	await _frames(20)
	_roll()
	var n := _length()
	for i in n:
		_look_at(_middle(c[0]) if c[0].is_alive() else Vector3(0.0, 1.0, 7.0), 0.25)
		await _tick(Vector2(0.0, 0.35), i == 4)


## cron mines laid ahead, daemons walking onto them as their schedule runs.
func _shot_05_08_cron() -> void:
	await _weapon_start(7, Vector3(0.0, 0.0, 11.0))
	var head: Node3D = _player.get_node("Head")
	for k in 3:
		_player.rotation.y = deg_to_rad(-14.0 + k * 14.0)
		head.rotation.x = deg_to_rad(-26.0)
		await _tick(Vector2.ZERO, true)
		await _frames(22)
	var c := _crowd(["R1", "R2", "R3", "Z1"], [Vector3(-2.0, 0.0, 5.6), Vector3(2.4, 0.0, 5.2), Vector3(0.2, 0.0, 4.0), Vector3(-4.0, 0.0, 3.6)])
	_fight(true)
	await _frames(30)
	_roll()
	var n := _length()
	for i in n:
		_look_at(Vector3(0.3, 0.6, 9.5), 0.06)
		await _tick(Vector2(0.0, 0.3))


## ping: the sonar ring going out across the floor from the player, every daemon it meets outlined, seen from above
## and behind the player, the camera rising.
func _shot_05_09_ping() -> void:
	await _weapon_start(8, Vector3(0.5, 1.0, 6.0))
	_crowd(["R1", "Z1", "R2", "S1", "R4", "Z2"], [Vector3(-3.6, 0.0, 9.6), Vector3(4.2, 0.0, 7.8), Vector3(-1.2, 0.0, 5.6), Vector3(2.4, 1.0, 4.4), Vector3(-5.6, 0.0, 4.2), Vector3(1.2, 0.0, -0.6)])
	_fight(true)
	await _frames(10)
	_roll()
	var path := [Vector3(0.5, 3.6, 18.4), Vector3(0.6, 4.8, 17.9), Vector3(0.8, 6.0, 17.2)]
	var look := [Vector3(0.5, 0.0, 8.0), Vector3(0.5, 0.0, 7.0), Vector3(0.5, 0.0, 6.0)]
	_camera(path[0], look[0], 64.0)
	var n := _length()
	for i in n:
		var u := ease_both(float(i) / (n - 1))
		_aim_camera(spline(path, u), spline(look, u))
		_look_at(Vector3(0.5, 1.0, 6.0), 0.2)
		await _tick(Vector2.ZERO, i == 2)


## chmod 000: the beam already on a rogue.d (it began before the roll), frost creeping until it freezes solid, then
## the cannon: the frozen daemon shatters, and the next one goes down too.
func _shot_05_10_chmod() -> void:
	await _weapon_start(9, Vector3(0.0, 1.0, 9.0))
	var c := _crowd(["R3", "R1", "Z1"], [Vector3(0.0, 0.0, 6.6), Vector3(-4.4, 0.0, 4.4), Vector3(4.2, 0.0, 3.8)])
	var target: Node3D = c[0]
	_fight(true)
	for i in 12:
		_look_at(_middle(target), 0.3)
		await _tick()
	_player.hold_fire = true
	_roll()
	var n := _length()
	var swapped := -1
	for i in n:
		if swapped < 0 and target.chmod_frozen():
			swapped = i
			_events.append({"t": snappedf(_clock, 0.001), "what": "frozen", "daemon": target.tag_text})
		if swapped >= 0 and i == swapped + 24:
			_player.hold_fire = false
			_player.select_slot(0)
		var t: Node3D = target if target.is_alive() else _first_alive(c, true)
		if t != null:
			_look_at(_middle(t), 0.3)
		var fire: bool = swapped >= 0 and i > swapped + 44 and t != null and _on_target(_middle(t), 0.45)
		await _tick(Vector2(0.2, 0.3), fire)
	_player.hold_fire = false


## pipe |: one chain arcing through a group of daemons, then another through a second group.
func _shot_05_11_pipe() -> void:
	await _weapon_start(10, Vector3(0.0, 1.0, 9.0))
	var first := _crowd(["R1", "R2", "S1", "Z1"], [Vector3(0.6, 0.0, 9.6), Vector3(3.4, 0.0, 7.6), Vector3(1.2, 1.0, 5.0), Vector3(-2.2, 0.0, 6.6)])
	var second := _crowd(["R3", "R4", "Z2"], [Vector3(-4.4, 0.0, 9.0), Vector3(-6.4, 0.0, 6.4), Vector3(-3.8, 0.0, 4.2)])
	_fight(true)
	await _frames(20)
	_roll()
	var n := _length()
	for i in n:
		var t := _first_alive(first if i < 70 else second)
		if t != null:
			_look_at(_middle(t), 0.3)
		var fire: bool = t != null and _on_target(_middle(t), 0.5) and (i == 10 or i == 11 or i == 90 or i == 91)
		await _tick(Vector2(-0.2, 0.4), fire)


## /dev/null: thrown into a crowd, the hole drags them in; once the last is discarded it implodes (its hold, 4 s in
## play, cut short as the capture tool does).
func _shot_05_12_dev_null() -> void:
	await _weapon_start(11, Vector3(0.0, 1.0, 8.0))
	var c := _crowd(["R1", "R2", "Z1", "R4", "S1"], [Vector3(-3.4, 0.0, 6.4), Vector3(3.6, 0.0, 8.4), Vector3(2.4, 0.0, 4.4), Vector3(-1.8, 0.0, 9.8), Vector3(-0.4, 1.0, 3.6)])
	_fight(true)
	_look_at(Vector3(0.0, 1.6, 7.0), 1.0)
	await _tick(Vector2.ZERO, true)
	var hole: Node3D = null
	for i in 150:
		hole = _player.get("last_hole")
		if hole != null and is_instance_valid(hole) and hole.is_open():
			break
		await _tick()
	await _frames(4)
	_roll()
	var n := _length()
	var collapsing := false
	for i in n:
		_look_at(Vector3(0.0, 1.2, 7.0), 0.05)
		if not collapsing and is_instance_valid(hole) and (i > 100 or _first_alive(c) == null) and i > 60:
			hole.open_age = maxf(hole.open_age, hole.tuning.open_s + hole.tuning.hold_s - 0.01)
			collapsing = true
		await _tick(Vector2(0.12, 0.0))


## SIGHUP: thrown into a crowd fighting, the wave of static hangs them up, "reloading config", then confused.
func _shot_05_13_sighup() -> void:
	await _weapon_start(12, Vector3(0.0, 1.0, 8.0))
	_crowd(["R1", "R2", "Z1", "R4", "Z2", "S1"], [Vector3(-2.6, 0.0, 6.6), Vector3(3.2, 0.0, 8.0), Vector3(1.4, 0.0, 4.6), Vector3(-1.0, 0.0, 9.4), Vector3(-4.6, 0.0, 4.8), Vector3(2.4, 1.0, 6.4)])
	_fight(true)
	await _frames(30)
	_roll()
	var n := _length()
	for i in n:
		_look_at(Vector3(0.0, 1.4 if i < 10 else 1.1, 7.2), 0.12)
		await _tick(Vector2(-0.15, 0.45), i == 6)


# --- The fight, wide ----------------------------------------------------------------------------------------------

## The big fight: twelve daemons swarming the player in the middle of the floor while it works through the heavy
## weapons, seen from a crane rising and swinging round, the player's own body (the hexagon others see) standing in.
func _shot_06_fight() -> void:
	var me := Vector3(0.0, 0.0, 10.5)
	await _stand(me + Vector3.UP * 0.95, Vector3(0.0, 1.0, 4.0))
	var names := ["DummyA", "DummyB", "DummyC", "DummyD", "R1", "R2", "R3", "R4", "Z1", "Z2", "Z3", "S1", "S2", "E1"]
	var all := []
	for i in names.size():
		var d := _daemon(names[i])
		var a := TAU * i / names.size()
		_place(d, me + Vector3(sin(a), 0.0, cos(a)) * (6.0 + (i % 3) * 2.2) + Vector3.UP * (1.0 if names[i].begins_with("S") or names[i] == "DummyD" else 0.0), me)
		all.append(d)
	var body = RemotePlayer.new()
	body.player_id = 9
	body.player_name = ""
	body.interp_delay_s = 0.0
	_main.add_child(body)
	_player.select_slot(0)
	_fight(true)
	await _frames(40)
	_roll()
	var path := [Vector3(-11.5, 2.4, 18.6), Vector3(-9.0, 5.0, 18.8), Vector3(-3.0, 7.4, 19.2)]
	var look := [Vector3(0.0, 1.2, 10.0), Vector3(0.0, 0.8, 9.5), Vector3(0.5, 0.6, 9.0)]
	_camera(path[0], look[0], 60.0)
	var n := _length()
	var plan := [[0, 0], [70, 3], [130, 6], [190, 10], [260, 0], [300, 11]]
	for i in n:
		for step in plan:
			if i == step[0]:
				_player.select_slot(step[1])
				if step[1] == 2:
					_player.inventory.add_meter(_player.inventory.meter_full())
		var t := _first_alive(all, true)
		var fire := false
		if t != null:
			_look_at(_middle(t), 0.3)
			fire = _on_target(_middle(t), 0.6)
		body.push_sample(i, _player.global_position, _player.rotation.y, 0.0, Vector3.ZERO)
		body.get("_tag").visible = false
		var u := ease_both(float(i) / (n - 1))
		_aim_camera(spline(path, u), spline(look, u))
		await _tick(Vector2(sin(i * 0.03) * 0.5, 0.0), fire)


# --- The title ----------------------------------------------------------------------------------------------------

const TITLE := "SIGKILL"
## The wordmark's pixel, in metres (a voxel a pixel, a little smaller than it), and where it stands (arena space):
## high over the lair, against the sky, so nothing busy is behind it.
const TITLE_PX := 0.2
const TITLE_AT := Vector3(0.0, 6.6, 0.0)
## The frame the voxels land on, and the camera's start and end.
const TITLE_SLAM := 40
const TITLE_CAM := [Vector3(0.0, 1.9, 9.6), Vector3(0.0, 2.1, 8.6)]
const TITLE_LOOK := Vector3(0.0, 5.7, 0.0)
const ICON_PATH := "res://packaging/linux/sigkill.svg"
## Where the 2D lines sit (px from the top) and the soft dark band behind them.
const ICON_TOP := 92.0
const BADGE_Y := 640.0
const URL_Y := 702.0


## The SIGKILL wordmark in the arena's own sign font, a neon voxel a pixel, flying in from scattered points and
## slamming together high over the arena against the sky; then the hexagon (the brand file as it is, drawn at its own
## colours), PRE-ALPHA and playsigkill.com.
func _shot_07_title() -> void:
	var me := Vector3(0.0, 0.0, 16.0)
	await _stand(me + Vector3.UP * 0.95, Vector3(0.0, 1.0, 4.0))
	var cube := TITLE_PX * 0.9
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * cube
	var mat := Palette._neon_material("neon_edge", Vector3.ONE * cube, Palette.MINT, 3.0)
	mat.set_shader_parameter("face_color", Palette.TEAL.darkened(0.55))
	mesh.material = mat
	var pixels: Array[Vector3] = []
	var w := SignFont.width(TITLE)
	for run in SignFont.runs(TITLE):
		for k in int(run[2]):
			pixels.append(Vector3((run[0] + k - w * 0.5 + 0.5) * TITLE_PX, (SignFont.ROWS * 0.5 - run[1] - 0.5) * TITLE_PX, 0.0))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = pixels.size()
	var word := MultiMeshInstance3D.new()
	word.multimesh = mm
	word.position = TITLE_AT
	word.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_main.add_child(word)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var from: Array[Vector3] = []
	var spin: Array[Vector3] = []
	var late: Array[float] = []
	for p in pixels:
		from.append(p * 2.6 + Vector3(rng.randf_range(-7.0, 7.0), rng.randf_range(-4.0, 5.0), rng.randf_range(-16.0, 5.0)))
		spin.append(Vector3(rng.randf_range(-7.0, 7.0), rng.randf_range(-7.0, 7.0), rng.randf_range(-7.0, 7.0)))
		late.append(rng.randf_range(0.0, 0.3))
	var layer := CanvasLayer.new()
	layer.layer = 50
	_main.add_child(layer)
	var band := TextureRect.new()
	var fade := Gradient.new()
	fade.set_color(0, Color(0.0, 0.0, 0.0, 0.0))
	fade.set_color(1, Color(0.0, 0.0, 0.0, 0.88))
	var ramp := GradientTexture2D.new()
	ramp.gradient = fade
	ramp.fill_from = Vector2(0.0, 0.0)
	ramp.fill_to = Vector2(0.0, 1.0)
	band.texture = ramp
	band.position = Vector2(0.0, 520.0)
	band.size = Vector2(1920.0, 560.0)
	band.modulate.a = 0.0
	layer.add_child(band)
	var icon := TextureRect.new()
	icon.texture = ImageTexture.create_from_image(_icon_image())
	icon.size = Vector2(icon.texture.get_width(), icon.texture.get_height())
	icon.pivot_offset = icon.size * 0.5
	icon.position = Vector2(960.0 - icon.size.x * 0.5, ICON_TOP)
	icon.modulate.a = 0.0
	layer.add_child(icon)
	var badge := _label("PRE-ALPHA", 36, Palette.HOSTILE_RED, 16)
	badge.position = Vector2(0.0, BADGE_Y)
	layer.add_child(badge)
	var url := _label("playsigkill.com", 60, Palette.MINT, 4)
	url.position = Vector2(0.0, URL_Y)
	layer.add_child(url)
	_camera(TITLE_CAM[0], TITLE_LOOK, 50.0)
	var slam := _sound(SfxSynth.opener_thud(), -3.0)
	var boom := _sound(SfxSynth.void_implosion(), -6.0)
	_roll()
	var n := _length()
	for i in n:
		var t := float(i)
		for k in pixels.size():
			var u := clampf((t / TITLE_SLAM - late[k] * (1.0 - t / TITLE_SLAM)) , 0.0, 1.0)
			var e := u * u * u
			var p: Vector3 = from[k].lerp(pixels[k], e)
			if i > TITLE_SLAM and rng.randf() < 0.004:
				p += Vector3(rng.randf_range(-1.0, 1.0), 0.0, 0.0) * TITLE_PX * 0.6  # a voxel glitching now and then
			mm.set_instance_transform(k, Transform3D(Basis.from_euler(spin[k] * (1.0 - e)), p))
		if i == TITLE_SLAM:
			slam.play()
			boom.play()
			ParticleFx.of(_main).blast(_main.to_global(TITLE_AT), Palette.MINT, 7.0)
		var after := maxf(t - TITLE_SLAM, 0.0)
		var shake := 0.1 * exp(-after / 7.0) if i >= TITLE_SLAM else 0.0
		mat.set_shader_parameter("edge_energy", 3.0 + 10.0 * exp(-after / 6.0) if i >= TITLE_SLAM else 2.4)
		var drift := ease_both(float(i) / (n - 1))
		var at: Vector3 = TITLE_CAM[0].lerp(TITLE_CAM[1], drift) + Vector3(sin(i * 1.7), cos(i * 2.3), 0.0) * shake
		_aim_camera(at, TITLE_LOOK)
		band.modulate.a = clampf((after - 10.0) / 30.0, 0.0, 1.0)
		icon.modulate.a = clampf((after - 14.0) / 22.0, 0.0, 1.0)
		icon.scale = Vector2.ONE * (1.0 + 0.12 * (1.0 - ease_both(clampf((after - 14.0) / 22.0, 0.0, 1.0))))
		badge.modulate.a = clampf((after - 36.0) / 14.0, 0.0, 1.0)
		url.modulate.a = clampf((after - 50.0) / 16.0, 0.0, 1.0)
		await _tick()


func _sound(stream: AudioStream, db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"Effects"
	player.volume_db = db
	_main.add_child(player)
	return player


func _icon_image() -> Image:
	var image := Image.new()
	image.load_svg_from_string(FileAccess.get_file_as_string(ICON_PATH), 0.6)
	return image


## A centred line of text across the window in the game's monospace, `size` px, `spacing` px between letters.
func _label(text: String, size: int, color: Color, spacing: int) -> Label:
	var label := Label.new()
	label.text = text
	label.size = Vector2(1920.0, size * 1.6)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var font := FontVariation.new()
	font.base_font = Palette.mono_font()
	font.spacing_glyph = spacing
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Palette.VOID)
	label.add_theme_constant_override("outline_size", 6)
	label.modulate.a = 0.0
	return label
