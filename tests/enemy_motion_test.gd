extends SceneTree
## Headless enemy motion test for SIGKILL (A2b, the enemies redone as creatures). scripts/check.sh
## runs it, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/enemy_motion_test.gd
##
## Every enemy is articulated and posed procedurally, never a static mesh, and all of it is visual
## only. The sources: the art code makes no OS call, opens no file, thread or socket and reads no
## wall clock; nothing that runs each frame makes a node, mesh, material, array or dictionary;
## every daemon shader pins its instance uniforms to the same slots and takes its time from the one
## shader global; the gameplay collision is byte for byte as it was at 1afcdb7 (the dummy's scene
## and the arena's, and the only lines of the dummy's script that touch its collision shape). Each
## type alone: built of MultiMesh parts only; the rogue daemon's feet plant and step in a tripod
## gait while its body glides, and it rears; the zombie's bones flicker in and out, its ghosts trail
## it and change, it limps, its head stays over the hit volume; the swarm's 20 to 40 insects move,
## orbit their nest, keep together and dive; each one 1.5 to 2.5 times A2's size and inside its own
## budget; every pose seeded per daemon and a function of the game clock (SIGSTOP slows it); a hit
## flashes, recoils, sprays shards and brings the type's own reaction; the frames go by with no
## object, node or mesh made. In the real arena: the four dummies' collision shapes, sizes, places,
## layers and masks exactly the 1afcdb7 literals, unchanged after their art has moved for seconds;
## every daemon sharing one material per look; a hit through the dummy reacting; a kill bursting
## into the creature's own parts on top of the derezz, flying apart, gone with it.
## Deterministic: frames counted, only counts and outcomes printed.

const Link = preload("res://scripts/guide/guide_link.gd")
const MainScene = preload("res://scenes/main.tscn")
const DummyScene = preload("res://scenes/target_dummy.tscn")
const Controls = preload("res://scripts/controls.gd")
const DerezzFx = preload("res://scripts/derezz_fx.gd")
const Shatter = preload("res://scripts/daemons/daemon_shatter.gd")
const Dummy = preload("res://scripts/target_dummy.gd")
const Zombie = preload("res://scripts/daemons/zombie_process.gd")
const Swarm = preload("res://scripts/daemons/runaway_swarm.gd")
const ART_DIR := "res://scripts/daemons/"
const TYPES := ["rogue_daemon", "zombie_process", "runaway_swarm"]
## A2's daemons' sizes (the diagonal of the box round each, in metres, at 1afcdb7), and how many
## times that each creature must be now.
const A2_DIAGONAL := {"rogue_daemon": 2.407, "zombie_process": 2.462, "runaway_swarm": 1.969}
const SCALE_LOW := 1.5
const SCALE_HIGH := 2.5
## A creature's size is the box round everything it draws over this many frames (a second).
const SIZE_FRAMES := 60
## The gameplay collision as it was at 1afcdb7: the scenes' hashes, the only lines of the dummy's
## script that touch its collision shape, and each arena dummy's shape as built.
const SCENE_SHA := {"res://scenes/target_dummy.tscn": "ec147ba79534222d950b3b491e54dce9cdbb5fbf8ab0991f0caf85125464de0f", "res://scenes/arena.tscn": "1b8b69fc57c11e6787ba9ec1fca53a14c08be32f672a48795ec57bf711c17434"}
const SHAPE_LINES := ["@onready var _shape: CollisionShape3D = $Shape", "\t_shape.set_deferred(\"disabled\", true)", "\t_shape.set_deferred(\"disabled\", false)"]
const COLLISION_TEXT := """DummyA | layer 4 mask 0 | cylinder r 0.550 h 1.800 | at (0.000, 0.900, -15.000) x (1.000, 0.000, 0.000) y (0.000, 1.000, 0.000) z (0.000, 0.000, 1.000) | enabled
DummyB | layer 4 mask 0 | cylinder r 0.550 h 1.800 | at (-17.500, 0.900, 5.000) x (1.000, 0.000, 0.000) y (0.000, 1.000, 0.000) z (0.000, 0.000, 1.000) | enabled
DummyC | layer 4 mask 0 | cylinder r 0.550 h 1.800 | at (12.000, 0.900, 5.000) x (1.000, 0.000, 0.000) y (0.000, 1.000, 0.000) z (0.000, 0.000, 1.000) | enabled
DummyD | layer 4 mask 0 | cylinder r 0.550 h 1.800 | at (-8.000, 1.900, 12.000) x (1.000, 0.000, 0.000) y (0.000, 1.000, 0.000) z (0.000, 0.000, 1.000) | enabled"""
## What runs every frame, by script: none of it may make anything.
const PER_FRAME := {
	"daemon_art.gd": ["_process", "_step_shader_clock", "_marked", "_send", "_pose", "put", "conceal", "bone", "orient", "present", "brighten", "recoil", "jolt", "since", "dice", "_knock", "_axes", "_pose_spray", "_hide_spray"],
	"rogue_daemon.gd": ["_pose", "_pose_spines", "_pose_legs", "_display_now", "_jerk", "_swinging", "_knee_at"],
	"zombie_process.gd": ["_pose", "_skeleton", "_pose_bits", "_progress", "_root_at", "_yaw_at", "_right_foot", "_left_foot", "_plant", "_lean", "_knee_at"],
	"runaway_swarm.gd": ["_pose", "_fly"],
	"daemon_shatter.gd": ["_physics_process", "_apply"],
}
const MADE := ["SurfaceTool", "ArrayMesh", "MultiMesh.new", ".new(", "add_child", "duplicate(", "Material", "append(", "resize(", "Array(", "Dictionary(", "{", "str(", "\" %"]
## The instance uniforms' slots every daemon shader shares.
const SLOTS := {"hit": 0, "locked": 1, "unstable": 2, "seed": 3, "core_color": 4, "gutter": 5, "edge_color": 6}
const SHADERS := ["daemon_glitch.gdshaderinc", "daemon_shell.gdshader", "daemon_split.gdshader", "daemon_core.gdshader", "daemon_trail.gdshader", "daemon_glyphs.gdshader"]
## Frames each type is watched for, and how far a planted foot may slide, in metres.
const WATCH_FRAMES := 240
const PLANTED_SLIDE := 0.001
## How long the rogue daemon may take to rear on its own, in frames (it rears every 6 s).
const REAR_WAIT := 400

var _fails := 0
var _checks := 0
var _tmp := ""
var _scratch: Array = []
var _arenas: Array = []


func _initialize() -> void:
	GameSettings.current().set_value("gameplay", "practice", true)  # these checks predate C27b: the daemons stay the old never-attack dummies
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_tmp = OS.get_temp_dir().path_join("sigkill-enemy-motion-test-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(_tmp)
	Controls.ensure()
	_source_checks()
	await _type_checks()
	await _arena_checks()
	await _cleanup()
	for name in DirAccess.get_files_at(_tmp):
		DirAccess.remove_absolute(_tmp.path_join(name))
	DirAccess.remove_absolute(_tmp)
	print("ENEMY MOTION: %d checks" % _checks)
	print("ENEMY MOTION RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The sources. ---

func _source_checks() -> void:
	var code := ""
	for name in DirAccess.get_files_at(ART_DIR):
		if name.ends_with(".gd"):
			code += _code(ART_DIR + name)
	var found := PackedStringArray()
	for word in ["OS.", "execute", "create_process", "DirAccess", "FileAccess", "move_to_trash", "shell_open", "kill(", "Thread", "HTTP", "PacketPeer", "StreamPeer", "Expression", "rpc", "Time.", "Engine.get_time"]:
		if code.contains(word):
			found.append(word)
	if RegEx.create_from_string("(?<!pre)load\\(").search(code) != null:
		found.append("load(")
	_check("acceptance: the art code (the creatures, the rig, the shatter) is cosmetic only: no OS call, no signal, file, folder, thread, socket or network, no wall clock, nothing loaded at run time, no RPC", found.is_empty() and code.length() > 30000, ", ".join(found))
	var made := PackedStringArray()
	var missing := PackedStringArray()
	var held := 0
	var literal := RegEx.create_from_string("(^|[\\s(=,:\\[])\\[")
	for file in PER_FRAME:
		var source := _code(ART_DIR + file)
		for fn in PER_FRAME[file]:
			var body := _body(source, fn)
			if body.is_empty():
				missing.append("%s %s" % [file, fn])
				continue
			held += body.length()
			for word in MADE:
				if body.contains(word):
					made.append("%s %s: %s" % [file, fn, word])
			# An array literal: a "[" that does not follow a name or a closing bracket (an index).
			if literal.search(body.substr(body.find("\n", 1))) != null:
				made.append("%s %s: array literal" % [file, fn])
	_check("acceptance: no per-frame rebuild: nothing that runs each frame (posing, stepping, flocking, the clock, the spray, the shatter) makes a node, mesh, MultiMesh, material, array, dictionary or string", made.is_empty() and missing.is_empty() and held > 12000, "%s %s" % [", ".join(made), ", ".join(missing)])
	var slots_wrong := PackedStringArray()
	var timed := true
	var declared := 0
	var slot_re := RegEx.create_from_string("instance uniform \\w+ (\\w+)\\s*:[^;=]*instance_index\\((\\d+)\\)")
	for name in SHADERS:
		var text := _shader_code("res://shaders/" + name)
		timed = timed and not text.contains("TIME")
		for line in text.split("\n"):
			if not line.contains("instance uniform"):
				continue
			declared += 1
			var m := slot_re.search(line)
			if m == null or not SLOTS.has(m.get_string(1)) or SLOTS[m.get_string(1)] != m.get_string(2).to_int():
				slots_wrong.append("%s: %s" % [name, line.strip_edges()])
	var glitch := _shader_code("res://shaders/daemon_glitch.gdshaderinc")
	var project := FileAccess.get_file_as_string("res://project.godot")
	timed = timed and glitch.contains("global uniform float daemon_clock;") and _shader_code("res://shaders/daemon_glyphs.gdshader").contains("global uniform float daemon_clock;") and project.contains("[shader_globals]") and project.contains("daemon_clock={\n\"type\": \"float\"")
	_check("acceptance: A2's open issue fixed: every instance uniform of every daemon shader is pinned (hit 0, locked 1, unstable 2, seed 3, core_color 4, gutter 5, edge_color 6), the same name always the same slot; the time is the one shader global daemon_clock, never TIME", slots_wrong.is_empty() and declared >= 11 and timed, "%d declared; %s" % [declared, "; ".join(slots_wrong)])
	var hashes_ok := true
	for path in SCENE_SHA:
		hashes_ok = hashes_ok and FileAccess.get_sha256(path) == SCENE_SHA[path]
	var shape_lines := PackedStringArray()
	for line in FileAccess.get_file_as_string("res://scripts/target_dummy.gd").split("\n"):
		if line.contains("_shape") and not line.strip_edges().begins_with("#"):
			shape_lines.append(line)
	_check("acceptance: the gameplay collision is byte for byte as at 1afcdb7: the dummy's scene and the arena's scene, and the dummy's script touching its collision shape only where it did (its three lines, as they were)", hashes_ok and shape_lines == PackedStringArray(SHAPE_LINES), "%s" % [shape_lines])


# --- Each type alone. ---

func _type_checks() -> void:
	var world := Node3D.new()
	root.add_child(world)
	_scratch.append(world)
	var arts := {}
	for type in TYPES:
		var art := DaemonArt.make(load(ART_DIR + type + ".gd"), _named(type))
		art.position = Vector3(8.0 * arts.size(), 0.0, 0.0)
		world.add_child(art)
		arts[type] = art
	await process_frame
	var statics := PackedStringArray()
	for type in arts:
		var art: DaemonArt = arts[type]
		if not art.find_children("*", "MeshInstance3D", true, false).is_empty() or art.sets().is_empty():
			statics.append(type)
	_check("acceptance: never a static mesh: every type is drawn as MultiMesh parts posed each frame, no MeshInstance3D at all", statics.is_empty(), ", ".join(statics))
	await _rogue_checks(arts["rogue_daemon"])
	await _zombie_checks(arts["zombie_process"])
	await _swarm_checks(arts["runaway_swarm"])
	await _scale_checks(arts)
	await _clock_checks(world)
	await _hit_checks(arts)
	await _still_checks(arts)


func _rogue_checks(rogue: DaemonArt) -> void:
	var steps_before: PackedInt32Array = rogue.steps().duplicate()
	var body_from: Vector3 = rogue.body_at()
	var glide := 0.0
	var slid := 0.0
	var both_tripods := 0
	var most_lifted := 0
	var feet_moved := 0
	var off_ground := 0.0
	var last_feet: PackedVector3Array = rogue.feet()
	var last_planted: Array[bool] = rogue.planted()
	var last_steps: PackedInt32Array = rogue.steps().duplicate()
	for f in WATCH_FRAMES:
		await process_frame
		var feet: PackedVector3Array = rogue.feet()
		var planted: Array[bool] = rogue.planted()
		var swinging: Array[bool] = rogue.swinging()
		var steps: PackedInt32Array = rogue.steps()
		var lifted := [0, 0]
		for i in feet.size():
			if feet[i].distance_to(last_feet[i]) > 0.0001:
				feet_moved += 1
			if planted[i] and last_planted[i] and steps[i] == last_steps[i]:
				slid = maxf(slid, feet[i].distance_to(last_feet[i]))
				off_ground = maxf(off_ground, absf(feet[i].y - DaemonArt.GROUND_Y))
			if swinging[i]:
				lifted[rogue.tripods()[i]] += 1
		if lifted[0] > 0 and lifted[1] > 0:
			both_tripods += 1
		most_lifted = maxi(most_lifted, lifted[0] + lifted[1])
		glide = maxf(glide, Vector2(rogue.body_at().x - body_from.x, rogue.body_at().z - body_from.z).length())
		last_feet = feet
		last_planted = planted
		last_steps = steps.duplicate()
	var fewest := 1000
	for i in rogue.steps().size():
		fewest = mini(fewest, rogue.steps()[i] - steps_before[i])
	print("ENEMY MOTION rogue: %d foot moves in %d frames, fewest steps a leg %d, planted feet slid at most %.4f m and stood %.4f m off the ground, legs of both tripods swinging together in %d frames, at most %d legs swinging, the body glided %.2f m" % [feet_moved, WATCH_FRAMES, fewest, slid, off_ground, both_tripods, most_lifted, glide])
	_check("acceptance: rogue.d skitters on its legs: every foot moves, every leg steps at least twice in %d s, a planted foot stays put on the ground (under %.0f mm), the body glides" % [WATCH_FRAMES / 60, PLANTED_SLIDE * 1000.0], feet_moved > 100 and fewest >= 2 and slid < PLANTED_SLIDE and off_ground < 0.0005 and glide > 0.15)
	_check("acceptance: rogue.d's gait is a tripod: three legs swing while three hold, legs of both tripods swinging together in under 5% of frames", most_lifted <= 4 and both_tripods <= WATCH_FRAMES / 20, "%d frames, at most %d legs swinging" % [both_tripods, most_lifted])
	var reared := 0.0
	for f in REAR_WAIT:
		await process_frame
		reared = maxf(reared, rogue.rear())
		if reared > 0.95:
			break
	_check("acceptance: rogue.d rears up on its own (a threat display every 6 s): the front pitches up and its front legs lift", reared > 0.95, "rear %.2f" % reared)


func _zombie_checks(zombie: DaemonArt) -> void:
	var states := {}
	var ghosts := {}
	var path := 0.0
	var low := INF
	var high := -INF
	var head_out := 0
	var last: Vector3 = zombie.pelvis_at()
	var least_shown := 1000
	for f in WATCH_FRAMES:
		await process_frame
		states[str(zombie.bones_state())] = true
		var g: PackedVector3Array = zombie.ghost_offsets()
		ghosts["%.2f %.2f %.2f" % [g[0].length(), g[1].length(), g[2].length()]] = true
		path += zombie.pelvis_at().distance_to(last)
		last = zombie.pelvis_at()
		low = minf(low, last.y)
		high = maxf(high, last.y)
		least_shown = mini(least_shown, zombie.bones_shown())
		var head: Vector3 = zombie.head_at()
		var height := head.y - DaemonArt.GROUND_Y
		if height < 1.4 or height > 1.85 or Vector2(head.x, head.z).length() > 0.6:
			head_out += 1
	var far: PackedVector3Array = zombie.ghost_offsets()
	print("ENEMY MOTION zombie: %d bone states in %d frames (fewest bones drawn %d of %d), %d ghost spacings, ghosts now %.2f, %.2f and %.2f m back, the pelvis walked %.2f m and dipped %.2f m, the head off the hit volume's top in %d frames" % [states.size(), WATCH_FRAMES, least_shown, Zombie.BONES, ghosts.size(), far[0].length(), far[1].length(), far[2].length(), path, high - low, head_out])
	_check("acceptance: the zombie is half derezzed: its bones flicker in and out (many different sets drawn), never all gone", states.size() >= 20 and least_shown >= Zombie.BONES / 3)
	_check("acceptance: its ghost copies trail it: three ghosts, each further back, their offsets changing as it moves", ghosts.size() >= 20 and far[0].length() > 0.1 and far[1].length() > far[0].length() and far[2].length() > far[1].length())
	_check("acceptance: it limps: the pelvis walks its loop and dips on the dragged leg; its head stays over the hit volume's head zone (in 95% of frames)", path > 0.4 and high - low > 0.08 and head_out <= WATCH_FRAMES / 20, "%d frames out" % head_out)


func _swarm_checks(swarm: DaemonArt) -> void:
	var count: int = swarm.boids().size()
	var start: PackedVector3Array = swarm.boids().duplicate()
	var farthest := 0.0
	var lowest := INF
	var spin := 0.0
	var nearest := 0.0
	var samples := 0
	for f in WATCH_FRAMES:
		await process_frame
		var nest: Vector3 = swarm.nest_at()
		var boids: PackedVector3Array = swarm.boids()
		var vel: PackedVector3Array = swarm.velocities()
		var turning := Vector3.ZERO
		for i in boids.size():
			farthest = maxf(farthest, boids[i].distance_to(nest))
			lowest = minf(lowest, boids[i].y)
			turning += (boids[i] - nest).cross(vel[i])
		spin += (turning / boids.size()).length()
		if f % 30 == 0:
			var mean := 0.0
			for i in boids.size():
				var close := INF
				for j in boids.size():
					if j != i:
						close = minf(close, boids[i].distance_to(boids[j]))
				mean += close
			nearest += mean / boids.size()
			samples += 1
	var moved := 0.0
	for i in count:
		moved += swarm.boids()[i].distance_to(start[i])
	moved /= count
	spin /= WATCH_FRAMES
	nearest /= samples
	print("ENEMY MOTION swarm: %d insects moved %.2f m on average, at most %.2f m from the nest, the lowest %.2f m off the ground, turning %.2f m2/s round the nest, %.2f m to the nearest neighbour on average" % [count, moved, farthest, lowest - DaemonArt.GROUND_Y, spin, nearest])
	_check("acceptance: the runaway is a swarm of 20 to 40 insects that fly: every one moves, together they orbit the nest", count >= 20 and count <= 40 and moved > 0.3 and spin > 0.4, "%d insects" % count)
	_check("acceptance: it flocks: the insects keep together round the nest (within 2.3 m), keep apart from each other, and dive at the ground now and then", farthest < 2.3 and nearest > 0.08 and lowest - DaemonArt.GROUND_Y < 0.5)


func _scale_checks(arts: Dictionary) -> void:
	var report := PackedStringArray()
	var wrong := PackedStringArray()
	var budget := PackedStringArray()
	for type in arts:
		var art: DaemonArt = arts[type]
		var smallest := INF
		var largest := 0.0
		for k in 3:
			# The box round everything it draws over a second: a frame where a flickering bone or a
			# ghost drops out does not shrink it.
			var box := art.pose_bounds()
			for f in SIZE_FRAMES:
				await process_frame
				box = box.merge(art.pose_bounds())
			var ratio := box.size.length() / float(A2_DIAGONAL[type])
			smallest = minf(smallest, ratio)
			largest = maxf(largest, ratio)
		report.append("%s %.2f to %.2f times A2, %d triangles, %d draw calls (budget %d, %d)" % [type, smallest, largest, art.triangles(), art.draw_calls(), art.budget_triangles, art.budget_draw_calls])
		if smallest < SCALE_LOW or largest > SCALE_HIGH:
			wrong.append(type)
		if art.triangles() > art.budget_triangles or art.draw_calls() > art.budget_draw_calls:
			budget.append(type)
	print("ENEMY MOTION budget: " + "; ".join(report))
	_check("acceptance: every creature is %.1f to %.1f times A2's daemon (the diagonal of the box round all it draws over a second, against A2's at 1afcdb7)" % [SCALE_LOW, SCALE_HIGH], wrong.is_empty(), ", ".join(wrong))
	_check("acceptance: every creature inside its own triangle and draw-call budget (a draw call a set, one more for the split pass and one more for a shadow)", budget.is_empty(), ", ".join(budget))


## Seeded and on the game clock: the same daemon moves the same way, another differently; a
## zombie's pose is a function of its clock alone, so half the engine's time for twice the frames
## lands on the very same pose; the shader clock is stepped at the game's pace.
func _clock_checks(world: Node3D) -> void:
	var twins := []
	for name in ["TwinA", "TwinA", "Other"]:
		var art := DaemonArt.make(load(ART_DIR + "rogue_daemon.gd"), _named(name))
		world.add_child(art)
		twins.append(art)
	for f in 90:
		await process_frame
	var same := true
	var differ := false
	for id in twins[0].part_count():
		same = same and twins[0].part_transform(id).is_equal_approx(twins[1].part_transform(id))
		differ = differ or not twins[0].part_transform(id).is_equal_approx(twins[2].part_transform(id))
	_check("acceptance: seeded per daemon: two of the same name move exactly alike, another differently", same and differ)
	for art in twins:
		art.queue_free()
	# The slowed one moves alone for 66 frames at half time, then the other alone for 33 at full:
	# both clocks at 0.55 s, clear of every tick its flicker and its twitches roll on.
	var slow := DaemonArt.make(load(ART_DIR + "zombie_process.gd"), _named("Pace"))
	var fast := DaemonArt.make(load(ART_DIR + "zombie_process.gd"), _named("Pace"))
	world.add_child(slow)
	world.add_child(fast)
	fast.visible = false
	var shader_before := DaemonArt.shader_clock()
	Engine.time_scale = 0.5
	for f in 66:
		await process_frame
	var shader_half := DaemonArt.shader_clock() - shader_before
	Engine.time_scale = 1.0
	slow.visible = false
	fast.visible = true
	# The engine's time changes from the next frame on, so the full-speed one lands on the slowed
	# one's clock a frame or so either way of 33: watch for it.
	for f in 40:
		if absf(fast.clock() - slow.clock()) < 0.000001:
			break
		await process_frame
	var posed := absf(fast.clock() - slow.clock()) < 0.000001
	for id in slow.part_count():
		posed = posed and slow.part_transform(id).is_equal_approx(fast.part_transform(id)) and slow.shown(id) == fast.shown(id)
	print("ENEMY MOTION clock: the zombie at half the engine's time reached %.4f s in 66 frames, the one at full time %.4f s; the shader clock went %.4f s in those 66 frames" % [slow.clock(), fast.clock(), shader_half])
	_check("acceptance: on the game clock (SIGSTOP slows it): half the engine's time moves the shader clock and a zombie's clock half as far, and a zombie's pose is its clock's alone: one slowed and one at full speed reach the same pose at the same clock", absf(shader_half - 0.55) < 0.02 and absf(slow.clock() - 0.55) < 0.02 and posed)
	slow.queue_free()
	fast.queue_free()


func _hit_checks(arts: Dictionary) -> void:
	var reacted := PackedStringArray()
	for type in arts:
		var art: DaemonArt = arts[type]
		var point := art.global_position + Vector3(0.3, 0.2, 0.6)
		var local := art.to_local(point)
		var fleeing_before := _fleeing(art, local) if type == "runaway_swarm" else 0.0
		var near := PackedInt32Array()
		if type == "runaway_swarm":
			for i in art.boids().size():
				if art.boids()[i].distance_to(local) < 1.0:
					near.append(i)
		art.react(point, Vector3(0.0, 0.0, -1.0))
		var flashed: bool = art.hit_glow() == 1.0 and art.sets()[0].get_instance_shader_parameter("hit") == 1.0
		var own := true
		if type == "runaway_swarm":
			# The insects near the shot fly away from it at once.
			own = _fleeing(art, local) > fleeing_before + 1.0
		var knocked := 0.0
		var sprayed := 0
		var reared := 0.0
		var scattered := 0.0
		for f in 12:
			await process_frame
			knocked = maxf(knocked, art.recoil().length())
			sprayed = maxi(sprayed, art.spraying())
			if type == "rogue_daemon":
				reared = maxf(reared, art.rear())
			if f == 0 and not near.is_empty():
				# A frame on, after the flock's first step, the insects that were near the shot still
				# fly faster than the swarm's top speed: the scatter outruns it for a moment, never
				# clamped back at once (self-review pass 2).
				for i in near:
					scattered = maxf(scattered, art.velocities()[i].length())
		if type == "rogue_daemon":
			own = reared > 0.3
		elif type == "runaway_swarm":
			print("ENEMY MOTION hit: the swarm's %d insects near the shot, the fastest at %.2f m/s a frame on (its top speed %.1f m/s)" % [near.size(), scattered, Swarm.SPEED_MAX])
			own = own and near.size() >= 3 and scattered > Swarm.SPEED_MAX * 1.5
		for f in ceili(maxf(DaemonArt.RECOIL_S, DaemonArt.SPRAY_S) * 60.0) + 2:
			await process_frame
		var settled := art.recoil() == Vector3.ZERO and art.spraying() == 0
		if not (flashed and knocked > DaemonArt.RECOIL_M * 0.5 and sprayed == DaemonArt.SPRAY and own and settled):
			reacted.append("%s flash %s knock %.3f spray %d own %s settled %s fastest %.2f m/s" % [type, flashed, knocked, sprayed, own, settled, scattered])
	_check("acceptance: a hit reacts on every type: the flash at once, the body knocked back and springing to rest, a spray of glowing shards from where it struck that is gone after %.2f s, and the type's own (the rogue rears; the swarm flees the shot, the insects near it outrunning its top speed by half again a frame later)" % DaemonArt.SPRAY_S, reacted.is_empty(), "; ".join(reacted))


## Frames go by and nothing is made: no object, no node, the same meshes, MultiMeshes and materials.
func _still_checks(arts: Dictionary) -> void:
	for f in 30:
		await process_frame
	var ids := _ids(arts.values())
	var objects := Performance.get_monitor(Performance.OBJECT_COUNT)
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	for f in 120:
		await process_frame
	var objects_after := Performance.get_monitor(Performance.OBJECT_COUNT)
	var nodes_after := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	print("ENEMY MOTION still: %d objects and %d nodes, then %d and %d after 120 frames of all three moving" % [objects, nodes, objects_after, nodes_after])
	_check("acceptance: no per-frame rebuild, at run time: 120 frames of every type moving make no object or node, and every mesh, MultiMesh and material is the one it was built with", objects_after == objects and nodes_after == nodes and _ids(arts.values()) == ids)


# --- In the real arena. ---

func _arena_checks() -> void:
	var main: Node = await _arena()
	var targets := main.get_node("Arena/Targets")
	var before := _collision_text(targets)
	for f in 150:
		await physics_frame
	var after := _collision_text(targets)
	var bodies_whole := true
	for dummy in targets.get_children():
		bodies_whole = bodies_whole and (dummy.get_node("Body") as Node3D).scale == Vector3.ONE
	_check("acceptance: in the arena the four dummies' collision is the 1afcdb7 literal (shape, radius, height, place, axes, layer 4, mask 0, enabled), and still is after 2.5 s of their creatures moving: the visuals never scale the collision or the body", before == COLLISION_TEXT and after == COLLISION_TEXT and bodies_whole, _first_difference(after, COLLISION_TEXT))
	var looks := {}
	var foreign := PackedStringArray()
	for dummy in targets.get_children():
		for node in dummy.art_node().find_children("*", "GeometryInstance3D", true, false):
			var mat := (node as GeometryInstance3D).material_override as ShaderMaterial
			if mat == null:
				foreign.append(node.name)
				continue
			looks[mat.shader.resource_path.get_file()] = looks.get(mat.shader.resource_path.get_file(), {})
			looks[mat.shader.resource_path.get_file()][mat.get_instance_id()] = true
	var shared := foreign.is_empty() and looks.size() == 4
	for file in looks:
		shared = shared and (looks[file] as Dictionary).size() == 1
	_check("acceptance: shared materials: the arena's four daemons, three kinds, draw with one shell (its split the next pass), one core, one trail and one glyph material", shared, str(looks.keys()))
	await _arena_hit_checks(main)
	await _death_checks(main)


func _arena_hit_checks(main: Node) -> void:
	var tough = DummyScene.instantiate()
	tough.max_health = 3.0
	tough.art = load(ART_DIR + "runaway_swarm.gd")
	tough.position = Vector3(30.0, 0.0, 30.0)
	main.get_node("Arena/Targets").add_child(tough)
	await physics_frame
	var art: DaemonArt = tough.art_node()
	var landed: bool = tough.hit(1.0, tough.global_position + Vector3(0.3, 1.2, 0.5), Vector3(0.0, 0.0, -1.0))
	var flashed := art.hit_glow() == 1.0
	var sprayed := 0
	var knocked := 0.0
	for f in 8:
		await process_frame
		sprayed = maxi(sprayed, art.spraying())
		knocked = maxf(knocked, art.recoil().length())
	_check("acceptance: a hit through the dummy that does not kill reaches its creature: the flash, the recoil and the spray, the dummy still alive", landed and flashed and tough.state == Dummy.State.ALIVE and sprayed == DaemonArt.SPRAY and knocked > 0.0)
	tough.queue_free()
	await physics_frame


func _death_checks(main: Node) -> void:
	var dummy: Node3D = main.get_node("Arena/Targets/DummyA")
	var art: DaemonArt = dummy.art_node()
	var shown := 0
	for id in art.part_count():
		shown += 1 if art.shown(id) else 0
	dummy.hit(100.0, dummy.global_position + Vector3(0.0, 1.2, 1.0), Vector3.FORWARD)
	await physics_frame
	var effects: Array = get_nodes_in_group(DerezzFx.FX_GROUP)
	var bursts: Array = get_nodes_in_group(Shatter.GROUP)
	var burst: Node = bursts[0] if bursts.size() == 1 else null
	var parts: int = burst.part_count() if burst != null else 0
	var under_derezz: bool = burst != null and effects.size() == 1 and burst.get_parent() == effects[0]
	var shared := burst != null
	var colliders := 0
	if burst != null:
		colliders = burst.find_children("*", "CollisionObject3D", true, false).size() + burst.find_children("*", "CollisionShape3D", true, false).size()
		var art_mats := {}
		for node in art.sets():
			art_mats[node.material_override.get_instance_id()] = true
		for node in burst.find_children("*", "MultiMeshInstance3D", true, false):
			shared = shared and art_mats.has((node as GeometryInstance3D).material_override.get_instance_id())
	var spread_early := _spread(burst, dummy.global_position) if burst != null else 0.0
	for f in 20:
		await physics_frame
	var spread_late := _spread(burst, dummy.global_position) if is_instance_valid(burst) else 0.0
	var frames := 21
	while frames < 200 and (not get_nodes_in_group(Shatter.GROUP).is_empty() or not get_nodes_in_group(DerezzFx.FX_GROUP).is_empty()):
		await physics_frame
		frames += 1
	print("ENEMY MOTION death: %d parts drawn at the kill, %d in the burst, %.2f m out on average at once, %.2f m after 20 frames; burst and derezz gone after %d frames" % [shown, parts, spread_early, spread_late, frames])
	_check("acceptance: death shatters: the kill bursts the creature into its own parts (every drawn part but the spray) on top of A2's derezz, under it, with the shared materials and nothing that collides", under_derezz and parts >= 40 and parts >= shown - DaemonArt.SPRAY and shared and colliders == 0)
	_check("acceptance: the shards fly apart and are gone with the derezz, within %.1f s" % Shatter.LIFE_S, spread_late > spread_early + 0.5 and frames < ceili(Shatter.LIFE_S * 60.0) + 40, "%.2f m to %.2f m, %d frames" % [spread_early, spread_late, frames])


# --- Helpers. ---

## A stand-in target named `n`, which seeds the art.
func _named(n: String) -> Node3D:
	var node := Node3D.new()
	node.name = n
	_scratch.append(node)
	return node


## How fast, on average, the insects within a metre of `from` fly away from it (m/s).
func _fleeing(art: DaemonArt, from: Vector3) -> float:
	var total := 0.0
	var near := 0
	for i in art.boids().size():
		var away: Vector3 = art.boids()[i] - from
		if away.length() < 1.0:
			total += art.velocities()[i].dot(away.normalized())
			near += 1
	return total / maxf(near, 1.0)


func _shown_count(art: DaemonArt) -> int:
	var count := 0
	for id in art.part_count():
		count += 1 if art.shown(id) else 0
	return count


func _spread(burst: Node, from: Vector3) -> float:
	var positions: PackedVector3Array = burst.positions()
	var total := 0.0
	for p in positions:
		total += p.distance_to(from)
	return total / maxf(positions.size(), 1.0)


func _ids(arts: Array) -> Array:
	var ids := []
	for art in arts:
		for node in (art as Node).find_children("*", "GeometryInstance3D", true, false):
			ids.append(node.get_instance_id())
			ids.append((node as GeometryInstance3D).material_override.get_instance_id())
			if node is MultiMeshInstance3D:
				ids.append((node as MultiMeshInstance3D).multimesh.get_instance_id())
				ids.append((node as MultiMeshInstance3D).multimesh.mesh.get_instance_id())
	return ids


func _collision_text(targets: Node) -> String:
	var lines := PackedStringArray()
	for dummy in targets.get_children():
		var body := dummy as StaticBody3D
		var shape := dummy.get_node("Shape") as CollisionShape3D
		var cyl := shape.shape as CylinderShape3D
		var xf := shape.global_transform
		lines.append("%s | layer %d mask %d | cylinder r %.3f h %.3f | at %s x %s y %s z %s | %s" % [dummy.name, body.collision_layer, body.collision_mask, cyl.radius if cyl != null else -1.0, cyl.height if cyl != null else -1.0, _v(xf.origin), _v(xf.basis.x), _v(xf.basis.y), _v(xf.basis.z), "disabled" if shape.disabled else "enabled"])
	return "\n".join(lines)


static func _v(v: Vector3) -> String:
	return "(%.3f, %.3f, %.3f)" % [v.x, v.y, v.z]


static func _first_difference(a: String, b: String) -> String:
	var la := a.split("\n")
	var lb := b.split("\n")
	for i in maxi(la.size(), lb.size()):
		var x := la[i] if i < la.size() else "<none>"
		var y := lb[i] if i < lb.size() else "<none>"
		if x != y:
			return "line %d: %s (expected %s)" % [i + 1, x, y]
	return ""


func _arena() -> Node:
	var link := Link.new()
	link.settings_path = _tmp.path_join("arena-privacy.cfg")
	link.demo = true
	Link.park(link)
	var main = MainScene.instantiate()
	root.add_child(main)
	_arenas.append(main)
	main.get_node("Hud").guide().focus_check = func(): return false
	main.get_node("Player").assume_captured = true
	for i in 3:
		await physics_frame
	return main


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


## The body of function `name` in `source`, from its line up to the next function.
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
