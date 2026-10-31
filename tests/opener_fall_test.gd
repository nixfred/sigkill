extends SceneTree
## Headless test of the opener's city and fall for SIGKILL (C40; PRD 5.7, 0:35 to 1:10: the fake desktop shrinking
## away, the fall through the directory tree as a city, the node_modules pit, the hottest process at the bottom).
## scripts/check.sh runs it as step 50, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/opener_fall_test.gd
##
## The city (scripts/opener/tree_layout.gd): the same for the same names, every time; built from the folder names and
## entry counts alone (a level of the tree a terrace, a folder in its parent's slice, entries setting a tower's size,
## the first node_modules the pit, the hidden and the uncounted dim); its caps holding for a huge tree; every name
## cleaned and cut. The machine (scripts/opener/tree_fall.gd): a fixed number of nodes whatever the data; the camera's
## first frame of the screen exactly where the terminal filled the view; its whole way smooth, never through a tower,
## a terrace's edge, a stream or a cable, under the ceiling, landing on the pit's rim facing the pit; the hot process
## beating under once a second. In the opener: the city from a source's own names (invented here), the demo's process
## name where the source has none, a source with no folders still a city, C39's reader on a fake home with nothing in
## it falling back to the demo's city and on one with three folders making them the city, the machine dropped as the
## opener ends. And the code: the opener's build reads nothing but the folders, their counts and the process name, and
## the city and the machine read and print nothing at all. Invented names only: nothing real reaches the output.

const OpenerScene = preload("res://scenes/opener.tscn")
const FPS := 60.0
const MOST_FRAMES := 4600
## Invented folders for a source of the test's own (no machine's), with their counts: two node_modules (the first is
## the pit, the second a maze tower), a hidden one, one not counted, an orphan whose parents are missing, a duplicate,
## an empty name, an escape sequence and a line break, wide characters and one far too long.
const INVENTED := ["atlas", "atlas/maps", "atlas/maps/old", "atlas/node_modules", "bench", "cellar", "cellar/jars", ".hidden-notes", "drafts", "drafts/node_modules", "写真", "lost/deep/thing", "bench", "", "esc\u001b[31mape", "line\nbreak", "zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz"]
const INVENTED_COUNTS := [12, 40, 3, 200, 0, 77, 5, 9, -1, 150, 31, 2, 4, 1, 6, 8, 10]
## The fake homes, under the test's own folder.
const HOMES := ["empty-home", "small-home"]
const SMALL_HOME := ["atlas", "atlas/maps", "bench"]
## The camera may come no nearer than this to anything solid (metres), and move no more than this between frames.
const CLEAR_M := 1.2
const MOST_STEP_M := 1.5
const MOST_TURN_DEG := 3.0


## A data source of the test's own, behind the opener's seam.
class StubData extends OpenerData:
	var dirs := PackedStringArray()
	var counts := PackedInt32Array()

	func kind() -> String:
		return "stub"

	func folders() -> PackedStringArray:
		return dirs

	func folder_counts() -> PackedInt32Array:
		return counts


var _fails := 0
var _checks := 0
var _root := ""
var _abs := ""


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_root = "user://opener-fall-test-%d" % OS.get_process_id()
	_abs = ProjectSettings.globalize_path(_root)
	if DirAccess.dir_exists_absolute(_abs):
		print("FAIL the test's own folder already exists; not touching it")
		quit(1)
		return
	GameSettings.current().reset()
	_code_checks()
	_layout_checks()
	_cap_checks()
	_partial_checks()
	await _machine_checks()
	await _opener_checks()
	await _reader_checks()
	await _cleanup()
	print("OPENER FALL: %d checks" % _checks)
	print("OPENER FALL RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


static func _demo_city() -> TreeLayout:
	return TreeLayout.build(PackedStringArray(DemoOpenerData.FOLDERS), PackedInt32Array(DemoOpenerData.COUNTS))


static func _invented_city() -> TreeLayout:
	return TreeLayout.build(PackedStringArray(INVENTED), PackedInt32Array(INVENTED_COUNTS))


static func _room(city: TreeLayout, path: String) -> Dictionary:
	for room in city.rooms:
		if room["path"] == path:
			return room
	return {}


static func _fingerprint(city: TreeLayout) -> String:
	return var_to_str([city.rooms, city.pieces, city.labels, city.cables, city.streams, city.pit_path])


# --- The code. ---

func _code_checks() -> void:
	var opener := FileAccess.get_file_as_string("res://scripts/opener/opener.gd")
	var at := opener.find("\nfunc _build_machine(")
	var body := opener.substr(at, opener.find("\nfunc ", at + 1) - at)
	var reads := PackedStringArray()
	for m in RegEx.create_from_string("_data\\.(\\w+)\\(").search_all(body):
		reads.append(m.get_string(1))
	_check("acceptance: the opener builds its city from the values it already took and nothing more: its build reads the data's %s, and nothing else of it" % ", ".join(reads), body != "" and reads == PackedStringArray(["folders", "folder_counts", "top_process"]))
	var bad := PackedStringArray()
	for path in ["res://scripts/opener/tree_layout.gd", "res://scripts/opener/tree_fall.gd"]:
		var code := FileAccess.get_file_as_string(path)
		var lines := PackedStringArray()
		for line in code.split("\n"):
			if not line.strip_edges().begins_with("#"):
				lines.append(line)
		code = "\n".join(lines)
		for m in RegEx.create_from_string("OpenerData\\.([a-z_]+)\\(").search_all(code):
			if m.get_string(1) != "clean":
				bad.append("%s: OpenerData.%s" % [path.get_file(), m.get_string(1)])
		for word in ["\\b_data\\b", "\\bprint", "push_warning", "push_error", "FileAccess", "DirAccess", "\\bOS\\.", "\\bTime\\."]:
			if RegEx.create_from_string(word).search(code) != null:
				bad.append("%s: %s" % [path.get_file(), word.replace("\\b", "").replace("\\.", ".")])
	var loud := PackedStringArray()
	for file in DirAccess.get_files_at("res://scripts/opener"):
		if not file.ends_with(".gd"):
			continue
		var source := FileAccess.get_file_as_string("res://scripts/opener/" + file)
		if RegEx.create_from_string("\\bprint(err|_rich|_verbose|t|s)?\\(").search(source) != null:
			loud.append(file + ": print")
		for m in RegEx.create_from_string("push_(warning|error)\\(").search_all(source):
			var before := source.substr(0, m.get_start())
			if file != "opener.gd" or before.rfind("\nstatic func usable_tuning(") < before.rfind("\nfunc "):
				loud.append(file + ": " + m.get_string())
	_check("acceptance: no opener script prints anything (the reader included), and the one warning any of them logs is a refused tuning's, never a name", loud.is_empty(), ", ".join(loud))
	_check("the city and the machine touch no data source (only OpenerData.clean() for the names), read no file, the OS or the clock, and print or log nothing", bad.is_empty() and FileAccess.file_exists("res://scripts/opener/tree_fall.gd"), ", ".join(bad))


# --- The city. ---

func _layout_checks() -> void:
	var a := _demo_city()
	var b := _demo_city()
	var other := _invented_city()
	_check("acceptance: deterministic: the demo's city built twice is the same, box for box (%d towers, %d boxes, %d names, %d cables, %d streams); other names make another" % [a.rooms.size(), a.pieces.size(), a.labels.size(), a.cables.size(), a.streams.size()], _fingerprint(a) == _fingerprint(b) and _fingerprint(a) != _fingerprint(other) and a.roll_seed == b.roll_seed and a.roll_seed != other.roll_seed)
	var paths := PackedStringArray()
	for room in a.rooms:
		paths.append(room["path"])
	var same := paths.size() == DemoOpenerData.FOLDERS.size()
	for folder in DemoOpenerData.FOLDERS:
		same = same and paths.has(folder)
	_check("acceptance: the same folders the terminal showed: every one of the demo's 28 a tower (or the pit), its name on it", same and a.labels.size() == 28)
	var code := _room(a, "code")
	var homelab := _room(a, "code/homelab")
	var deep := _room(a, "code/website-redesign")
	var slice_ok: bool = homelab["parent"] >= 0 and a.rooms[homelab["parent"]]["path"] == "code" and absf(wrapf(homelab["angle"] - code["angle"], -PI, PI)) < 0.6
	_check("a level of the tree a terrace: \"code\" on the top one, \"code/homelab\" on the next, in its slice of the circle and hung from its rim by a cable (%d cables)" % a.cables.size(), code["depth"] == 0 and homelab["depth"] == 1 and deep["depth"] == 1 and slice_ok and homelab["base"] == TreeLayout.RING_Y[1] and a.cables.size() >= 4)
	var big := _room(a, "screenshots")
	var small := _room(a, "resume-final-v3")
	var empty := _room(a, "Music")
	_check("acceptance: entries set a tower's size: 200 entries (screenshots) wider and with more windows lit than 3 (resume-final-v3), and 3 than none (Music): %.1f, %.1f, %.1f m wide" % [big["width"], small["width"], empty["width"]], big["width"] > small["width"] and small["width"] > empty["width"] and big["lit"] > small["lit"] and small["lit"] > empty["lit"] and big["height"] > empty["height"])
	var hidden := _room(a, ".config")
	_check("a hidden folder stands short and dim in the back row (.config)", hidden["kind"] == TreeLayout.Kind.HIDDEN and hidden["radius"] >= TreeLayout.RING_R[0] + TreeLayout.ROW_M)
	_check("acceptance: node_modules is the pit at the bottom: the demo's \"code/website-redesign/node_modules\", its name over the pit, a cable down into it", a.pit_path == "code/website-redesign/node_modules" and _room(a, a.pit_path)["kind"] == TreeLayout.Kind.MAZE and a.labels.any(func(l): return l["text"] == "node_modules/" and is_equal_approx(l["at"].y, TreeLayout.PIT_Y + TreeLayout.PIT_LABEL_UP)) and a.cables.any(func(c): return is_equal_approx(c["to"].y, TreeLayout.PIT_Y)))
	var maze := _room(other, "drafts/node_modules")
	var maze_boxes := other.pieces.filter(func(p): return p["kind"] == TreeLayout.Kind.MAZE).size()
	_check("the first node_modules is the pit (atlas/node_modules), any other a maze tower (drafts/node_modules, %d boxes)" % maze_boxes, other.pit_path == "atlas/node_modules" and maze["kind"] == TreeLayout.Kind.MAZE and maze_boxes >= 1)
	var texts := PackedStringArray()
	var clean := true
	for label in other.labels:
		texts.append(label["text"])
		var text: String = label["text"]
		for i in text.length():
			var c := text.unicode_at(i)
			clean = clean and c >= 32 and c != 0x7f
		clean = clean and CellWidth.total(text) <= TreeLayout.LABEL_LONGEST + 1
	_check("acceptance: names cleaned and cut as the terminal's: no escape or line break reaches a tower, wide characters measured in cells, the long one cut to %d (%s)" % [TreeLayout.LABEL_LONGEST, ", ".join(texts.slice(0, 6))], clean and texts.has("写真/") and texts.has("escape/") and texts.has("line break/") and texts.has("z".repeat(TreeLayout.LABEL_LONGEST - 3) + ".../"))
	var orphan := _room(other, "lost/deep/thing")
	_check("an empty name is skipped, a duplicate kept once, an orphan whose parents are missing still placed (on its own terrace, in a slice of its own)", not _room(other, "lost/deep/thing").is_empty() and orphan["depth"] == 2 and orphan["parent"] == -1 and other.rooms.filter(func(r): return r["path"] == "bench").size() == 1 and other.rooms.size() == INVENTED.size() - 2)
	var uncounted := _room(other, "drafts")
	var notes := _room(other, ".hidden-notes")
	_check("a folder not counted (-1, drafts) stands dim, never sized as if it held entries; a hidden one (.hidden-notes) short and dim", uncounted["count"] == -1 and uncounted["kind"] == TreeLayout.Kind.UNCOUNTED and uncounted["width"] <= TreeLayout.UNCOUNTED_WIDTH and uncounted["lit"] == TreeLayout.UNCOUNTED_LIT and notes["kind"] == TreeLayout.Kind.HIDDEN and notes["width"] <= TreeLayout.WIDTH.y * TreeLayout.HIDDEN_SCALE and notes["radius"] >= TreeLayout.RING_R[0] + TreeLayout.ROW_M, "drafts: %s; .hidden-notes: %s" % [str([uncounted.get("count"), uncounted.get("kind"), uncounted.get("width"), uncounted.get("lit")]), str([notes.get("kind"), notes.get("width")])])


func _cap_checks() -> void:
	var names := PackedStringArray()
	var counts := PackedInt32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 50
	for i in 30:
		var top := "top-%02d" % i
		names.append(top)
		counts.append(rng.randi_range(-1, 1000000))
		for j in 12:
			names.append("%s/sub-%02d" % [top, j])
			counts.append(rng.randi_range(-1, 1000000))
			names.append("%s/sub-%02d/a/b/c/d/deeper-%s" % [top, j, "w".repeat(j * 9)])
			counts.append(-1)
	var city := TreeLayout.build(names, counts)
	var looked := names.slice(0, TreeLayout.MOST_GIVEN)
	var tops := 0
	for path in looked:
		tops += 1 if not path.contains("/") else 0
	var depths := {}
	for room in city.rooms:
		depths[room["depth"]] = depths.get(room["depth"], 0) + 1
	_check("acceptance: bounded: a tree of %d folders (counts up to a million, paths 6 deep) makes at most %d towers (%d), %d names (%d), %d boxes (%d), %d cables (%d), %d streams (%d); it looks at the first %d, keeps the shallow ones first (%d top-level, %d a level down) and leaves out %d" % [names.size(), TreeLayout.ROOMS, city.rooms.size(), TreeLayout.LABELS, city.labels.size(), TreeLayout.PIECES, city.pieces.size(), TreeLayout.CABLES, city.cables.size(), TreeLayout.STREAMS, city.streams.size(), TreeLayout.MOST_GIVEN, depths.get(0, 0), depths.get(1, 0), city.left_out], city.rooms.size() == TreeLayout.ROOMS and city.labels.size() == TreeLayout.LABELS and city.pieces.size() <= TreeLayout.PIECES and city.cables.size() == TreeLayout.ROOMS - tops and city.cables.size() <= TreeLayout.CABLES and city.streams.size() <= TreeLayout.STREAMS and depths.get(0, 0) == tops and depths.get(1, 0) == TreeLayout.ROOMS - tops and city.left_out == names.size() - TreeLayout.ROOMS)
	var flood := PackedStringArray()
	for i in 100000:
		flood.append("f%06d" % i)
	var started := Time.get_ticks_usec()
	var flooded := TreeLayout.build(flood, PackedInt32Array())
	var ms := (Time.get_ticks_usec() - started) / 1000.0
	_check("... and its work is bounded too: %d folders handed over are laid out in %.0f ms, the same %d towers" % [flood.size(), ms, flooded.rooms.size()], flooded.rooms.size() == TreeLayout.ROOMS and flooded.given == flood.size() and ms < 1000.0)
	var sizes := true
	for room in city.rooms:
		sizes = sizes and room["width"] <= TreeLayout.WIDTH.y and room["height"] <= TreeLayout.RING_TALLEST[room["depth"]] + 0.001
	_check("a million entries is no bigger than the reader's most (200): every tower within the widest and the tallest", sizes)


func _partial_checks() -> void:
	var no_counts := TreeLayout.build(PackedStringArray(DemoOpenerData.FOLDERS), PackedInt32Array())
	var short := TreeLayout.build(PackedStringArray(DemoOpenerData.FOLDERS), PackedInt32Array([200, 200]))
	_check("acceptance: partial data: folders with no counts stand as not counted, and counts that run short leave the rest not counted (%d of %d)" % [short.rooms.filter(func(r): return r["count"] == -1).size(), short.rooms.size()], no_counts.rooms.all(func(r): return r["count"] == -1) and short.rooms.filter(func(r): return r["count"] == -1).size() == DemoOpenerData.FOLDERS.size() - 2)
	var none := TreeLayout.build(PackedStringArray(), PackedInt32Array())
	_check("acceptance: no folders at all is still a city: no named tower, no pit, but the monolith, %d towers with no name, the megastructures and %d streams" % [none.pieces.size() - 1, none.streams.size()], none.rooms.is_empty() and none.labels.is_empty() and none.pit_path == "" and none.pieces.size() > 100 and none.streams.size() == TreeLayout.STREAMS)


# --- The machine. ---

func _machine_checks() -> void:
	var t := load("res://resources/opener.tres") as OpenerTuning
	var fall := _machine(_demo_city(), t)
	var twin := _machine(_demo_city(), t)
	await process_frame
	_check("acceptance: bounded: the demo's machine is %d nodes (at most %d whatever the data: the boxes in one MultiMesh, %d names)" % [fall.node_count(), TreeFall.MOST_NODES, fall.label_count()], fall.node_count() <= TreeFall.MOST_NODES and fall.piece_count() == fall.layout.pieces.size() and fall.label_count() == fall.layout.labels.size())
	var big_names := PackedStringArray()
	for i in 500:
		big_names.append("t%03d" % i)
	var huge := _machine(TreeLayout.build(big_names, PackedInt32Array()), t)
	await process_frame
	_check("... and a huge tree's machine is %d nodes and %d boxes, inside the same caps" % [huge.node_count(), huge.piece_count()], huge.node_count() <= TreeFall.MOST_NODES and huge.piece_count() <= TreeLayout.PIECES and huge.label_count() == TreeLayout.LABELS)
	huge.queue_free()
	var start := fall.pose(t.shrink_at)
	var screen := TreeLayout.panel_at()
	var facing := TreeLayout.panel_facing()
	var d := TreeFall.screen_distance()
	var fills := 2.0 * d * tan(deg_to_rad(fall.fov_at(t.shrink_at)) * 0.5)
	_check("acceptance: a camera move, not a fade: its first frame stands %.3f m square in front of the screen, looking straight at it, the screen's %.2f m filling the view's %.4f m exactly as the terminal filled the window" % [d, TreeLayout.PANEL_H, fills], start.origin.distance_to(screen + facing * d) < 0.0001 and start.basis.z.dot(facing) > 0.99999 and absf(fills - TreeLayout.PANEL_H) < 0.0001 and fall.pose(t.shrink_at + 1.0).origin.distance_to(screen) > d)
	var worst_step := 0.0
	var worst_turn := 0.0
	var hits := PackedStringArray()
	var prev := fall.pose(t.shrink_at)
	var top_speed := 0.0
	var same := true
	var samples := 0
	var e := t.shrink_at
	while e <= t.end_at:
		var now := fall.pose(e)
		same = same and now == twin.pose(e)
		worst_step = maxf(worst_step, now.origin.distance_to(prev.origin))
		worst_turn = maxf(worst_turn, rad_to_deg(now.basis.get_rotation_quaternion().angle_to(prev.basis.get_rotation_quaternion())))
		top_speed = maxf(top_speed, fall.speed_at(e))
		if hits.size() < 5:
			var hit := _hit(fall.layout, now.origin, e >= t.land_at)
			if hit != "":
				hits.append("%.2f s: %s" % [e, hit])
		prev = now
		samples += 1
		e += 1.0 / FPS
	_check("acceptance: the camera's way from the screen to the landing, %d frames: never more than %.2f m (worst %.2f) or %.1f degrees (worst %.2f) between frames, the reveal flowing into the fall; falling at most %.1f m/s" % [samples, MOST_STEP_M, worst_step, MOST_TURN_DEG, worst_turn, top_speed], worst_step < MOST_STEP_M and worst_turn < MOST_TURN_DEG and top_speed > 20.0 and top_speed < 60.0 and fall.speed_at(t.shrink_at + 1.0) == 0.0)
	_check("acceptance: it never goes through anything: no tower, no terrace's edge, no stream, no cable, never above the ceiling (%d frames checked against %d boxes)" % [samples, fall.layout.pieces.size()], hits.is_empty(), ", ".join(hits))
	_check("deterministic: two machines from the same names take the same way, frame for frame, and name the same towers", same and fall.label_texts() == twin.label_texts())
	var landed := fall.landing()
	var flat := Vector2(landed.origin.x, landed.origin.z)
	var ahead := -landed.basis.z
	_check("acceptance: it lands on the pit's rim (%.1f m from the axis, at eye height over it), facing the pit: the hand-off C41 goes on from (landing())" % flat.length(), absf(flat.length() - TreeLayout.LAND_R) < 0.01 and absf(landed.origin.y - (TreeLayout.PIT_Y + TreeFall.EYE_M)) < 0.01 and Vector2(ahead.x, ahead.z).normalized().dot(-flat.normalized()) > 0.95 and fall.pose(t.end_at).origin.distance_to(landed.origin) < 0.05)
	var swells := 0
	var was := 0.0
	var rising := false
	for i in int(10.0 * FPS):
		var beat := TreeFall.pulse_at(i / FPS)
		if beat > was and not rising and was < 0.2:
			swells += 1
		rising = beat > was
		was = beat
	_check("the hot process beats under once a second (%d swells in 10 s), a soft swell, never a flash" % swells, swells <= 10 and swells >= 7 and TreeFall.BEAT_HZ < 1.0)
	var look := TreeFall.add_look(Vector2.ZERO, Vector2(-100000.0, 100000.0))
	_check("look-only while falling: the mouse turns the view at most %.2f and %.2f radians and it springs back; it never moves the camera" % [TreeFall.LOOK_MOST.x, TreeFall.LOOK_MOST.y], absf(look.x) <= TreeFall.LOOK_MOST.x + 0.0001 and absf(look.y) <= TreeFall.LOOK_MOST.y + 0.0001 and TreeFall.settle_look(look, 10.0).length() < 0.0001)
	fall.queue_free()
	twin.queue_free()
	await process_frame


func _machine(city: TreeLayout, t: OpenerTuning) -> TreeFall:
	var fall := TreeFall.new()
	fall.shrink_at = t.shrink_at
	fall.fall_at = t.fall_at
	fall.land_at = t.land_at
	fall.process_name = DemoOpenerData.TOP_PROCESS
	fall.size = Vector2i(1280, 720)
	root.add_child(fall)
	fall.build(city, OpenerPalette.named(OpenerPalette.DEFAULT_ID).readable(), true)
	return fall


## What the camera at `at` is inside or too near, or "".
static func _hit(city: TreeLayout, at: Vector3, landed: bool) -> String:
	for piece in city.pieces:
		var local: Vector3 = Basis(Vector3.UP, piece["yaw"]).inverse() * (at - piece["at"])
		var half: Vector3 = piece["size"] * 0.5 + Vector3.ONE * CLEAR_M
		if absf(local.x) < half.x and absf(local.y) < half.y and absf(local.z) < half.z:
			return "inside a box at %s" % str(piece["at"])
	var r := Vector2(at.x, at.z).length()
	for k in TreeLayout.RING_R.size():
		if absf(at.y - TreeLayout.RING_Y[k]) < CLEAR_M and r > TreeLayout.RING_R[k] - TreeLayout.TERRACE_IN - CLEAR_M:
			return "through terrace %d" % k
	if not landed and absf(at.y - TreeLayout.PIT_Y) < CLEAR_M and r > TreeLayout.PIT_R - CLEAR_M:
		return "through the pit's rim"
	if at.y > TreeLayout.CEILING_Y - CLEAR_M:
		return "above the ceiling"
	for s in city.streams:
		if at.y < s["top"] and at.y > s["bottom"] and Vector2(at.x - s["x"], at.z - s["z"]).length() < s["width"] * 0.5 + CLEAR_M:
			return "through a stream"
	for c in city.cables:
		var near := Geometry3D.get_closest_point_to_segment(at, c["from"], c["to"])
		if near.distance_to(at) < CLEAR_M:
			return "through a cable"
	return ""


# --- In the opener. ---

func _opener_checks() -> void:
	var stub := StubData.new()
	stub.dirs = PackedStringArray(INVENTED)
	stub.counts = PackedInt32Array(INVENTED_COUNTS)
	var o := _opener(stub)
	await _until(o, func(): return o.event_time("machine") >= 0.0)
	var city := o.layout()
	var expected := _invented_city()
	var machine := o.fall()
	_check("acceptance: the opener's city is its source's own names and counts (invented here: %d towers, the pit under %s), built as the screen went black (%.2f s), nothing read past them" % [city.rooms.size() if city != null else -1, city.pit_path if city != null else "", o.event_time("machine")], city != null and _fingerprint(city) == _fingerprint(expected) and o.event_time("machine") >= o.timing().cut_at - 0.001 and o.event_time("machine") < o.timing().terminal_at)
	var shown := machine.label_texts() if machine != null else PackedStringArray()
	_check("its names on the towers (%s ...), and the hottest process the demo's (\"%s\"): no source but the demo names one" % [", ".join(shown.slice(0, 4)), machine.process_name if machine != null else ""], machine != null and shown.has("atlas/") and shown.has("node_modules/") and machine.process_name == DemoOpenerData.TOP_PROCESS)
	await _until(o, func(): return o.phase_name() == "fall")
	var held := o.fall()
	o.skip()
	await process_frame
	await process_frame
	_check("acceptance: dropped as it ends: Esc mid-fall, and the machine and its city are let go (the world freed, nothing kept)", o.fall() == null and o.layout() == null and not is_instance_valid(held))
	o.free()
	var bare := _opener(OpenerData.new())
	await _until(bare, func(): return not bare.playing())
	var ev := {}
	for e in bare.events():
		ev[e[1]] = e[0]
	_check("acceptance: a source with nothing in it plays every beat to the end over a city with no names (machine, reveal, fall, land, handoff, done)", ev.has("machine") and ev.has("reveal") and ev.has("fall") and ev.has("land") and ev.has("handoff") and ev.has("done") and not ev.has("skipped"))
	bare.free()
	await process_frame


func _opener(data: OpenerData) -> Opener:
	var o: Opener = OpenerScene.instantiate()
	o.data = data
	root.add_child(o)
	return o


func _until(o: Opener, condition: Callable) -> void:
	var frames := 0
	while frames < MOST_FRAMES and is_instance_valid(o) and o.playing() and not condition.call():
		await process_frame
		frames += 1


# --- C39's reader, on fake homes. ---

func _reader_checks() -> void:
	DirAccess.make_dir_recursive_absolute(_abs.path_join("small-home"))
	for folder in SMALL_HOME:
		DirAccess.make_dir_recursive_absolute(_abs.path_join("small-home").path_join(folder))
	for i in 3:
		var f := FileAccess.open(_abs.path_join("small-home/atlas/note-%d.txt" % i), FileAccess.WRITE)
		f.store_string("invented")
		f.close()
	var nothing := _reader("empty-home")
	var o := _opener(nothing)
	await _until(o, func(): return o.event_time("machine") >= 0.0)
	_check("acceptance: per-field fallback: C39's reader on a fake home that is not there reads no folders, so they are the demo's, and the city is the demo's own, box for box", o.layout() != null and _fingerprint(o.layout()) == _fingerprint(_demo_city()) and not nothing.real_fields().has("folders"))
	o.skip()
	o.free()
	var small := _reader("small-home")
	var p := _opener(small)
	await _until(p, func(): return p.event_time("machine") >= 0.0)
	var paths := PackedStringArray()
	if p.layout() != null:
		for room in p.layout().rooms:
			paths.append(room["path"])
	paths.sort()
	_check("... and on a fake home of three (invented) folders, the reader's folders and counts are the city (%s; atlas holds %d)" % [", ".join(paths), _room(p.layout(), "atlas").get("count", -2) if p.layout() != null else -2], small.real_fields().has("folders") and paths == PackedStringArray(SMALL_HOME) and _room(p.layout(), "atlas")["count"] == 4)
	p.skip()
	p.free()
	await process_frame


## C39's reader on one of the test's fake homes, every other source it has pointed at nothing there.
func _reader(home: String) -> RealOpenerData:
	var reader := RealOpenerData.new()
	reader.home = _abs.path_join(home)
	reader.user_name = "tester"
	reader.host_files = PackedStringArray([_abs.path_join("no-host")])
	reader.uptime_file = _abs.path_join("no-uptime")
	reader.clock_unix = 1762300000
	reader.zone_s = 0
	return reader


func _cleanup() -> void:
	_wipe(_abs)
	_check("the test's own folder is gone, nothing of it left under user://", not DirAccess.dir_exists_absolute(_abs))
	GameSettings.current().reset()
	await process_frame
	# A stopped sound is let go on the audio thread's next mix, in real time: give it that before quitting.
	OS.delay_msec(300)
	await process_frame


## The test's own folder removed: only under it, a link removed as itself and never followed.
func _wipe(path: String) -> void:
	if not path.begins_with(_abs):
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.include_hidden = true
	dir.list_dir_begin()
	var files := []
	var folders := []
	var name := dir.get_next()
	while name != "":
		if dir.is_link(name) or not dir.current_is_dir():
			files.append(name)
		else:
			folders.append(name)
		name = dir.get_next()
	dir.list_dir_end()
	for f in files:
		DirAccess.remove_absolute(path.path_join(f))
	for f in folders:
		_wipe(path.path_join(f))
	DirAccess.remove_absolute(path)
