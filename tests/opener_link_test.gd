extends SceneTree
## Headless test of the opener's link to the player's AI and the copy of them for SIGKILL (C41; PRD 5.7, 1:10 to
## 1:35: "Linking your agent..." The player's real AI answers live, told only that the game is starting. The
## scripted guide: "I've been stuck in here with them. They look like you." A daemon walks out wearing their
## username: a copy of them). scripts/check.sh runs it as step 52, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/opener_link_test.gd
##
## Fakes only, no real AI: a guide link (the real scripts/guide/guide_link.gd) on a fake detector, with a stub
## adapter of the test's own in the process, or the real Claude Code adapter pointed at the stub CLI under
## tests/fixtures/ai/guide that records its arguments. The opener plays on a stub data source of invented names (a
## user, a host, folders, an uptime), and none of them may reach the AI, the screen's AI line or this test's output.
## The link: the whole prompt is the request builder's preamble and SIGKILL's own LINK_TEXT, no stats, nothing of the
## data; the agent run with its tools off, never through omarchy-agent; its answer shown only as SIGKILL's own copy of
## the line it picked, marked live; the AI off, no agent, the session's cap, an error, a local model not loaded and no
## answer by answer_by each give the scripted line, and the opener's beats come at the same moments whatever the AI
## does (it never waits). Demo data calls nothing. The copy: the user name on its tag from the data (cleaned), its walk
## up out of the pit on a whole number of steps, each foot planted while down, a hexagon of light where each lands,
## stopping in front of the player, never through them; its name dropped as the opener ends. Esc mid-link and
## mid-copy leaves at once and stops the call. And the code: the link builds its one request from LINK_TEXT alone and
## asks nothing else; the beat, the copy and the HUD read nothing at all. The only files written are the stub CLI's
## records and the adapter's scratch, in the test's own folder under user://, removed at the end.

const OpenerScene = preload("res://scenes/opener.tscn")
const Link = preload("res://scripts/guide/guide_link.gd")
const Request = preload("res://scripts/ai/guide_request.gd")
const Settings = preload("res://scripts/boot/guide_settings.gd")
const Found = preload("res://scripts/ai/ai_source_result.gd")
const Detector = preload("res://scripts/ai/ai_source_detector.gd")
const Claude = preload("res://scripts/ai/claude_adapter.gd")
const Agent = preload("res://scripts/ai/agent_adapter.gd")
const STUBS := "res://tests/fixtures/ai/guide"
const FPS := 60.0
const MOST_FRAMES := 6200
const WATCHDOG_MS := 8000
## The stub data's invented values: none may reach the AI, the AI's line on screen or this test's output.
const NAME := "qz-copy-7"
const HOST := "qz-host-3"
const FOLDERS := ["qz-alpha", "qz-alpha/qz-deep", "qz-beta"]
const UPTIME := 777123
## A user name with an escape sequence in it: the tag shows it cleaned.
const DIRTY_NAME := "qz\u001b[31m-dirty"
const CLAUDE_EXPECTED := ["-p", "--tools", "", "--permission-mode", "dontAsk", "--permission-prompts", "none", "--strict-mcp-config", "--safe-mode", "--disable-slash-commands", "--no-session-persistence", "--output-format", "text", "--system-prompt"]
const CLAUDE_FORBIDDEN := ["--dangerously-skip-permissions", "--allow-dangerously-skip-permissions", "bypassPermissions", "acceptEdits", "--allowedTools", "--allowed-tools", "--add-dir", "--mcp-config", "--continue", "--resume", "omarchy-agent", "omarchy-agent-prompt"]
const NEW_FILES := ["res://scripts/opener/opener_link.gd", "res://scripts/opener/link_beat.gd", "res://scripts/opener/pit_beat.gd", "res://scripts/opener/copy_art.gd"]


## A data source of the test's own, behind the opener's seam: invented names only.
class StubData extends OpenerData:
	var name_given := NAME

	func kind() -> String:
		return "stub"

	func user() -> String:
		return name_given

	func host() -> String:
		return HOST

	func folders() -> PackedStringArray:
		return PackedStringArray(FOLDERS)

	func folder_counts() -> PackedInt32Array:
		return PackedInt32Array([3, 5, 7])

	func uptime_s() -> int:
		return UPTIME


## Stands in for the C9 detector: a canned result.
class FakeDetector:
	extends RefCounted
	var result: Found

	func start() -> Error:
		return OK

	func is_done() -> bool:
		return true

	func wait() -> Found:
		return result

	func cancel() -> void:
		pass

	func find_command(_command: String) -> String:
		return ""

	func poll_gpu() -> Dictionary:
		return {"available": false}


## A guide adapter of the test's own on the real base class (pacing, the AI switch and the timeout are GuideAdapter's):
## it answers as told after a few steps, and keeps what it was asked.
class StubAdapter:
	extends "res://scripts/ai/guide_adapter.gd"
	var mode := "ok"
	var answer := "Got you. Don't look in the pit too long."
	var asks := 0
	var aborts := 0
	var steps := 0
	var prompts: Array[String] = []
	var stats: Array[Dictionary] = []
	var texts: Array[String] = []

	func _init(tuning_resource: Resource) -> void:
		super(tuning_resource)

	func adapter_name() -> String:
		return "claude"

	func is_available() -> bool:
		return true

	func ask(request: RefCounted) -> Dictionary:
		asks += 1
		return super(request)

	func _begin(request: RefCounted) -> String:
		prompts.append(request.full_prompt())
		stats.append(request.stats.duplicate())
		texts.append(request.text)
		steps = 0
		return ""

	func _step() -> Dictionary:
		steps += 1
		if steps < 3 or mode == "hang":
			return {}
		if mode == "ok":
			return result(true, answer, "")
		return result(false, "", mode)

	func _abort() -> void:
		aborts += 1


var _fails := 0
var _checks := 0
var _printed: Array[String] = []
var _root := ""
var _abs := ""
var _factory_calls := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_root = "user://opener-link-test-%d" % OS.get_process_id()
	_abs = ProjectSettings.globalize_path(_root)
	if DirAccess.dir_exists_absolute(_abs):
		print("FAIL the test's own folder already exists; not touching it")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_abs)
	_code_checks()
	_line_checks()
	_tuning_checks()
	_walk_checks()
	await _claude_checks()
	await _fallback_checks()
	await _run_checks()
	await _escape_checks()
	await _demo_checks()
	await _cleanup()
	var leaked := PackedStringArray()
	for line in _printed:
		for secret in [NAME, HOST, "qz-alpha", "qz-deep", "qz-beta", str(UPTIME)]:
			if line.contains(secret):
				leaked.append(secret)
	_check("acceptance: nothing of the stub's data (its user, host, folders, uptime) is in this test's own output", leaked.is_empty(), ", ".join(leaked))
	print("OPENER LINK: %d checks" % _checks)
	print("OPENER LINK RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	var line := ("PASS " if ok else "FAIL ") + label + (("   " + detail) if detail != "" else "")
	_printed.append(line)
	print(line)
	if not ok:
		_fails += 1


# --- The code. ---

static func _code(path: String) -> String:
	var lines := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if not line.strip_edges().begins_with("#"):
			lines.append(line)
	return "\n".join(lines)


func _code_checks() -> void:
	var link := _code("res://scripts/opener/opener_link.gd")
	var bad := PackedStringArray()
	for word in ["OS.", "FileAccess", "DirAccess", "HTTP", "execute", "create_process", "omarchy", "num_ctx", "begin_offer", "accept_load", "unload", "load_port", "Time.", "print", "push_warning", "_data", "OpenerData"]:
		if link.contains(word):
			bad.append(word)
	_check("acceptance: the link runs nothing and reads nothing itself: only the guide link's own refusal, ask, poll and cancel (no OS, file, HTTP, model load, num_ctx, clock, print or opener data in scripts/opener/opener_link.gd)", bad.is_empty() and link.contains("guide.ask(request)") and link.count("guide.ask(") == 1 and link.contains("guide.refusal(_cap)") and link.contains("guide.cancel_call()"), ", ".join(bad))
	_check("acceptance: its one request is built from LINK_TEXT alone, with no stats: Request.build({}, LINK_TEXT, ...)", link.count("Request.build(") == 1 and link.contains("Request.build({}, LINK_TEXT, "))
	var quiet := PackedStringArray()
	for path in ["res://scripts/opener/pit_beat.gd", "res://scripts/opener/copy_art.gd", "res://scripts/opener/link_beat.gd"]:
		var code := _code(path)
		for word in ["\\b_data\\b", "OpenerData\\.", "\\bOS\\.", "\\bTime\\.", "FileAccess", "DirAccess", "\\bprint", "push_warning", "push_error", "HTTP", "guide\\.", "\\.ask\\("]:
			if RegEx.create_from_string(word).search(code) != null:
				quiet.append("%s: %s" % [path.get_file(), word.replace("\\b", "").replace("\\", "")])
	_check("acceptance: the beat in the machine, the copy and the HUD read nothing and ask nothing (no data source, OS, clock, file, print or AI call in pit_beat.gd, copy_art.gd or link_beat.gd)", quiet.is_empty(), ", ".join(quiet))
	var opener := _code("res://scripts/opener/opener.gd")
	var menu := _code("res://scripts/hud/pause_menu.gd")
	_check("acceptance: the copy's name is the user name the opener already took and cleaned, and nothing else; dropped as it ends; the menu hands in the session's guide link", opener.contains("_user = user if user != \"\" else DemoOpenerData.USER") and opener.contains("_pit.set_name_tag(_user)") and opener.count("set_name_tag(") == 1 and opener.contains("\t_user = \"\"") and opener.contains("_link.guide = guide") and menu.contains("_opener.guide = _link()"))
	var listed := FileAccess.get_file_as_string("res://tests/opener_test.gd")
	var missing := PackedStringArray()
	for path in NEW_FILES + ["res://shaders/opener_signal.gdshader", "res://shaders/opener_floor.gdshader"]:
		if not listed.contains("\"%s\"" % path):
			missing.append(path.get_file())
	_check("the C38 to C40 static checks cover the new files: every one is in tests/opener_test.gd's list (no environment, clock, program, network or file there), and its scan of scripts/opener/ and the opener_ shaders leaves none out", missing.is_empty(), ", ".join(missing))
	var sounds := _code("res://scripts/sfx_synth.gd")
	_check("its sounds are made in code (opener_carrier, opener_lock, opener_rise, opener_step), no audio file", sounds.contains("static func opener_carrier(") and sounds.contains("static func opener_lock(") and sounds.contains("static func opener_rise(") and sounds.contains("static func opener_step(") and not opener.contains(".wav") and not opener.contains(".ogg"))


# --- The words. ---

func _line_checks() -> void:
	var in_order := true
	var at := 0
	for line in OpenerLink.LINES:
		var found := OpenerLink.LINK_TEXT.find(line, at)
		in_order = in_order and found >= 0
		at = found + 1
	_check("LINK_TEXT tells the AI only that the game is starting and names SIGKILL's own LINES, in order; the scripted and the demo lines are fixed", OpenerLink.LINK_TEXT.begins_with("The game is starting.") and in_order and OpenerLink.LINES.has(OpenerLink.DEMO_LINE) and OpenerLink.SCRIPTED != "")
	var exact := OpenerLink.pick("Got you. Don't look in the pit too long.")
	var wrapped := OpenerLink.pick("  **\"link up.  it's dark DOWN here.\"**\n and more")
	var stranger := OpenerLink.pick("Hello qz-copy-7, welcome to qz-host-3.")
	_check("the screen shows SIGKILL's own copy of the line the AI picked (quotes, markdown, case, spaces and later lines ignored); anything else, a name or a machine say, is LINES[0], never the AI's own words", exact == OpenerLink.LINES[3] and wrapped == OpenerLink.LINES[1] and stranger == OpenerLink.LINES[0] and OpenerLink.pick("") == OpenerLink.LINES[0])
	_check("the PRD's words, exactly: \"Linking your agent...\" and \"I've been stuck in here with them. They look like you.\"", LinkBeat.LINKING == "Linking your agent..." and LinkBeat.GUIDE == "I've been stuck in here with them. They look like you.")


func _tuning_checks() -> void:
	var t := load("res://resources/opener.tres") as OpenerTuning
	_check("the shipped timeline keeps C41's window: the link at 1:10 (%.1f s), the AI's latest moment %.1f s after it, the copy standing by %.1f s, the hand-off to C42 at %.1f s, the end by 1:35 (%.1f s)" % [t.link_at, t.answer_by - t.link_at, t.copy_stop, t.forge_at, t.end_at], t.problems().is_empty() and t.link_at >= 70.0 and t.link_at <= 70.5 and t.answer_by - t.link_at <= 8.0 and t.forge_at <= 95.5 and t.end_at <= 95.5, ", ".join(t.problems()))
	var patient := OpenerTuning.new()
	patient.answer_by = 80.5
	var early := OpenerTuning.new()
	early.link_at = 69.0
	_check("a timeline that waits on the AI more than 8 s (\"%s\") or links before 1:10 is refused for the shipped one" % ", ".join(patient.problems()), patient.problems().has("the link waits more than 8 s on the AI") and not early.problems().is_empty() and Opener.usable_tuning(patient) == t)


# --- The copy's walk. ---

func _walk_checks() -> void:
	var t := load("res://resources/opener.tres") as OpenerTuning
	var length := PitBeat.walk_length()
	var end_phase := length / (2.0 * CopyArt.STRIDE)
	_check("its walk: %.2f m from %.1f m out (down in the pit, %.1f m under the floor) to %.1f m, a whole number of steps (%d), so it stops on one with both feet down" % [length, PitBeat.start_r(), TreeLayout.PIT_Y - PitBeat.ground_y(PitBeat.start_r()), PitBeat.stop_r(), PitBeat.STEPS], PitBeat.start_r() < TreeLayout.PIT_R - 3.0 and absf(end_phase - roundf(end_phase)) < 0.001 and is_equal_approx(PitBeat.walk_at(t.copy_at, t), 0.0) and is_equal_approx(PitBeat.walk_at(t.copy_stop, t), length))
	var slid := 0.0
	var grew := true
	var last := -1.0
	var e := t.copy_at
	while e < t.copy_stop:
		var d := PitBeat.walk_at(e, t)
		var d2 := PitBeat.walk_at(e + 1.0 / FPS, t)
		grew = grew and d >= last - 0.000001
		last = d
		for side in 2:
			var p0 := fposmod(d / (2.0 * CopyArt.STRIDE) + 0.5 * side, 1.0)
			var p1 := fposmod(d2 / (2.0 * CopyArt.STRIDE) + 0.5 * side, 1.0)
			if p0 < 0.5 and p1 < 0.5 and p1 >= p0:
				var a := PitBeat.copy_at_walk(d) * CopyArt.foot_at(side, d / (2.0 * CopyArt.STRIDE), PitBeat.slope_at(d))
				var b := PitBeat.copy_at_walk(d2) * CopyArt.foot_at(side, d2 / (2.0 * CopyArt.STRIDE), PitBeat.slope_at(d2))
				if PitBeat.slope_at(d) == PitBeat.slope_at(d2) and (PitBeat.slope_at(d) == 0.0 or PitBeat.slope_at(d) == PitBeat.STAIR_SLOPE):
					slid = maxf(slid, a.distance_to(b))
		e += 1.0 / FPS
	_check("acceptance (art): a foot that is down never slides: the most a planted foot moves between frames is %.4f m (on the stair and on the floor), the walk never going back" % slid, slid < 0.005 and grew)
	var landing := TreeLayout.on_ring(TreeLayout.LAND_ANGLE, TreeLayout.LAND_R, TreeLayout.PIT_Y)
	var stand := PitBeat.stand().origin
	var closest := INF
	e = t.copy_at
	while e <= t.end_at:
		var at := PitBeat.copy_at_walk(PitBeat.walk_at(e, t)).origin
		closest = minf(closest, Vector2(at.x - landing.x, at.z - landing.z).length())
		e += 0.1
	var facing := -PitBeat.stand().basis.z
	var toward := (landing - stand)
	toward.y = 0.0
	_check("it stops %.2f m in front of the player, facing them, and never comes nearer (%.2f m at the closest)" % [Vector2(stand.x - landing.x, stand.z - landing.z).length(), closest], absf(Vector2(stand.x - landing.x, stand.z - landing.z).length() - PitBeat.STOP_GAP) < 0.01 and closest >= PitBeat.STOP_GAP - 0.01 and facing.normalized().dot(toward.normalized()) > 0.99)
	var look := PitBeat.scripted_look(t.answer_from, t)
	var most := 0.0
	e = t.handoff_at
	while e <= t.end_at:
		most = maxf(most, PitBeat.scripted_look(e, t).length())
		e += 0.05
	_check("the camera's own look on top of the player's stays small (at most %.2f rad) and is only a pitch" % most, most <= PitBeat.LOOK_SIGNAL + PitBeat.LOOK_COPY + 0.001 and look.x == 0.0 and PitBeat.scripted_look(t.land_at, t) == Vector2.ZERO)


# --- The real adapter, on the stub CLI. ---

## The real Claude Code adapter pointed at the stub CLI: what the agent is run with, and what it is told.
func _claude_checks() -> void:
	var log_base := _abs.path_join("stub")
	OS.set_environment("SIGKILL_TEST_GUIDE_LOG", log_base)
	OS.set_environment("SIGKILL_TEST_STUB_MODE", "ok")
	var stub_path := ProjectSettings.globalize_path(STUBS).path_join("claude")
	var guide := _guide("claude.cfg", func(tuning: Resource):
		var a = Claude.new(stub_path, tuning)
		a.scratch_root = _root.path_join("scratch")
		return a)
	var link := OpenerLink.new()
	link.guide = guide
	link.begin(50.0)
	var t0 := Time.get_ticks_msec()
	while not link.done() and Time.get_ticks_msec() - t0 < WATCHDOG_MS:
		# The opener's clock held at 60 s, well before answer_by: the stub answers in real time.
		link.step(60.0, 16.0, 77.0)
		await process_frame
		OS.delay_msec(5)
	var argv := _argv(log_base + ".claude.argv")
	var bad := PackedStringArray()
	for flag in CLAUDE_FORBIDDEN:
		if argv.has(flag):
			bad.append(flag)
	_check("acceptance: the agent is the player's own CLI, run in print mode with its tools off (--tools \"\", dontAsk, no permission prompts, strict MCP, safe mode, no session kept): exactly the C9b flags", argv.size() == CLAUDE_EXPECTED.size() + 2 and argv.slice(0, CLAUDE_EXPECTED.size()) == PackedStringArray(CLAUDE_EXPECTED), str(argv.size()))
	_check("acceptance: never through omarchy-agent or omarchy-agent-prompt, never a permission bypass, granted tools or an MCP config", bad.is_empty() and not stub_path.contains("omarchy"), ", ".join(bad))
	var told: String = argv[-1] if argv.size() > 0 else ""
	var system: String = argv[-2] if argv.size() > 1 else ""
	_check("acceptance: what the agent is told, all of it: the request builder's fixed preamble as its system prompt, and \"Game stats: none\" with LINK_TEXT as its one prompt", system == Request.PREAMBLE and told == "Game stats: none\nPlayer: " + OpenerLink.LINK_TEXT and link.prompt() == Request.PREAMBLE + "\n\nGame stats: none\nPlayer: " + OpenerLink.LINK_TEXT)
	_check("acceptance: its answer (\"Aim for the core, then strafe left.\", not one of the lines) is live, shown as SIGKILL's own LINES[0], with the call's real latency", link.done() and link.live() and link.line() == OpenerLink.LINES[0] and link.latency_ms() >= 0 and link.why() == "")
	_shut(guide)
	OS.set_environment("SIGKILL_TEST_GUIDE_LOG", "")
	for name in ["stub.claude.argv", "stub.claude.meta"]:
		if FileAccess.file_exists(_abs.path_join(name)):
			DirAccess.remove_absolute(_abs.path_join(name))


func _argv(path: String) -> PackedStringArray:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedStringArray()
	var raw := f.get_buffer(f.get_length())
	f.close()
	var parts := PackedStringArray()
	var start := 0
	for i in raw.size():
		if raw[i] == 0:
			parts.append(raw.slice(start, i).get_string_from_utf8())
			start = i + 1
	return parts


# --- The link's fallbacks, on its own. ---

## Each way there is no live answer gives the scripted line, at once or by answer_by, never later.
func _fallback_checks() -> void:
	var off := _guide("off.cfg", func(tuning: Resource): return StubAdapter.new(tuning), false)
	var r_off := await _link_run(off, 77.0)
	_check("the AI turned off (the player's no): the scripted line at once, \"AI off\", and no call made", r_off["line"] == OpenerLink.SCRIPTED and not r_off["live"] and r_off["why"] == OpenerLink.WHY_OFF and r_off["done_at"] <= 50.5 and not r_off["asked"])
	_shut(off)
	var none := _guide("none.cfg", func(_tuning: Resource): return null)
	var r_none := await _link_run(none, 77.0)
	var r_null := await _link_run(null, 77.0)
	_check("no agent (the registry finds none, or no guide link at all): the scripted line, \"no agent\"", r_none["why"] == OpenerLink.WHY_NONE and r_null["why"] == OpenerLink.WHY_NONE and r_none["line"] == OpenerLink.SCRIPTED and r_null["line"] == OpenerLink.SCRIPTED)
	_shut(none)
	var failing := _guide("error.cfg", func(tuning: Resource):
		var s := StubAdapter.new(tuning)
		s.mode = "bad_exit"
		return s)
	var r_error := await _link_run(failing, 77.0)
	_check("an error: the scripted line, \"error\"", r_error["line"] == OpenerLink.SCRIPTED and r_error["why"] == "error" and r_error["asked"])
	_shut(failing)
	var unloaded := _guide("local.cfg", func(tuning: Resource):
		var s := StubAdapter.new(tuning)
		s.mode = "needs_consent"
		return s)
	var r_unloaded := await _link_run(unloaded, 77.0)
	_check("a local model server with nothing loaded: the scripted line, \"not loaded\"; the link never loads a model for it", r_unloaded["why"] == "not loaded" and r_unloaded["line"] == OpenerLink.SCRIPTED and unloaded.load_state == "")
	_shut(unloaded)
	var capped := _guide("cap.cfg", func(tuning: Resource): return StubAdapter.new(tuning))
	capped.calls = 1000
	var r_cap := await _link_run(capped, 77.0)
	_check("the session's cap on calls reached: the scripted line, \"limit\", and no call made", r_cap["why"] == OpenerLink.WHY_LIMIT and not r_cap["asked"])
	_shut(capped)
	var hung_stub: Array = []
	var hung := _guide("hang.cfg", func(tuning: Resource):
		var s := StubAdapter.new(tuning)
		s.mode = "hang"
		hung_stub.append(s)
		return s)
	var r_hang := await _link_run(hung, 77.0)
	var aborted: int = hung_stub[0].aborts if not hung_stub.is_empty() else 0
	_check("acceptance: no answer by answer_by (a hung agent): the scripted line at 77 s, within a frame (%.2f s), \"no answer\", and the call stopped (the adapter's own child)" % r_hang["done_at"], r_hang["why"] == OpenerLink.WHY_LATE and absf(r_hang["done_at"] - 77.0) < 1.0 / FPS + 0.001 and aborted == 1 and not hung.is_busy())
	_shut(hung)
	var good_stub: Array = []
	var good := _guide("ok.cfg", func(tuning: Resource):
		var s := StubAdapter.new(tuning)
		good_stub.append(s)
		return s)
	var r_ok := await _link_run(good, 77.0)
	var told: String = good_stub[0].prompts[0] if not good_stub.is_empty() and not good_stub[0].prompts.is_empty() else ""
	_check("a live answer: SIGKILL's copy of the line, marked live, asked once; the request carries no stats and only LINK_TEXT", r_ok["live"] and r_ok["line"] == OpenerLink.LINES[3] and good_stub[0].asks == 1 and good_stub[0].stats[0].is_empty() and good_stub[0].texts[0] == OpenerLink.LINK_TEXT and told == Request.PREAMBLE + "\n\nGame stats: none\nPlayer: " + OpenerLink.LINK_TEXT)
	_shut(good)


## A link run on the opener's clock from 50 s, a frame at a time, until it has a line or the clock passes 80 s.
func _link_run(guide, answer_by: float) -> Dictionary:
	var link := OpenerLink.new()
	link.guide = guide
	var e := 50.0
	link.begin(e)
	var done_at := -1.0
	while e < 80.0:
		link.step(e, 1000.0 / FPS, answer_by)
		if link.done():
			done_at = e
			break
		await process_frame
		e += 1.0 / FPS
	link.stop()
	return {"line": link.line(), "live": link.live(), "why": link.why(), "done_at": done_at, "asked": link.asked()}


# --- In the opener. ---

## The opener on the stub data with a guide link: the beats at the same moments whatever the AI does, the lines
## shown, the copy wearing the user name.
func _run_checks() -> void:
	var live_stub: Array = []
	var live_guide := _guide("run-live.cfg", func(tuning: Resource):
		var s := StubAdapter.new(tuning)
		live_stub.append(s)
		return s)
	var live := await _play(live_guide, StubData.new())
	var hang_stub: Array = []
	var hang_guide := _guide("run-hang.cfg", func(tuning: Resource):
		var s := StubAdapter.new(tuning)
		s.mode = "hang"
		hang_stub.append(s)
		return s)
	var hung := await _play(hang_guide, StubData.new())
	var t := load("res://resources/opener.tres") as OpenerTuning
	var same := true
	var names := ["ask", "link", "signal", "guide_start", "copy", "rise", "step", "stand", "forge", "done"]
	for name in names:
		same = same and live["events"].has(name) and hung["events"].has(name) and absf(live["events"][name] - hung["events"][name]) < 1.0 / FPS + 0.001
	_check("acceptance: the opener never waits on the AI: a live answer and a hung agent play every beat at the same moments (ask %.2f, link %.2f, signal %.2f, guide %.2f, copy %.2f, its first step %.2f, it stands %.2f, the hand-off to C42 %.2f, done %.2f s)" % [live["events"].get("ask", -1.0), live["events"].get("link", -1.0), live["events"].get("signal", -1.0), live["events"].get("guide_start", -1.0), live["events"].get("copy", -1.0), live["events"].get("step", -1.0), live["events"].get("stand", -1.0), live["events"].get("forge", -1.0), live["events"].get("done", -1.0)], same)
	_check("... the live answer locks at answer_from (%.2f s), the hung one at answer_by (%.2f s), the hung call stopped there" % [live["events"].get("answer", -1.0), hung["events"].get("scripted", -1.0)], absf(live["events"].get("answer", -1.0) - t.answer_from) < 0.05 and absf(hung["events"].get("scripted", -1.0) - t.answer_by) < 0.05 and not hang_stub.is_empty() and hang_stub[0].aborts == 1)
	_check("acceptance: the HUD comes alive: the badge with the agent's name, \"Linking your agent...\" typing, then the AI's line marked live with its latency; or the scripted line and why, not marked", live["linking"] == LinkBeat.LINKING and live["badge"] == "your AI: claude" and live["answer"] == OpenerLink.LINES[3] and live["mark"] and live["status"].begins_with("live") and hung["answer"] == OpenerLink.SCRIPTED and not hung["mark"] and hung["status"] == LinkBeat.STATUS_SCRIPTED % OpenerLink.WHY_LATE)
	_check("acceptance: then the scripted guide's line, the PRD's words, typed with its beat, and no live mark on it", live["guide"] == LinkBeat.GUIDE and not live["guide_mark"])
	var prompt: String = live_stub[0].prompts[0] if not live_stub.is_empty() and not live_stub[0].prompts.is_empty() else "none"
	var reached := PackedStringArray()
	for secret in [NAME, HOST, "qz-alpha", "qz-deep", "qz-beta", str(UPTIME), "777", "workstation"]:
		if prompt.contains(secret) or String(live["answer"]).contains(secret):
			reached.append("a stub value")
	_check("acceptance: the AI is told nothing of the opener's data: no user or host name, no folder, no uptime, no stats in the request it got; nor does any of it reach the line shown", reached.is_empty() and prompt == Request.PREAMBLE + "\n\nGame stats: none\nPlayer: " + OpenerLink.LINK_TEXT and live_stub[0].stats[0].is_empty(), ", ".join(reached))
	_check("acceptance: the copy walks out wearing the data's user name (the stub's own, compared, never printed), its tag over it; the host is nowhere on it", live["tag"] == NAME and not String(live["tag"]).contains(HOST))
	_check("acceptance: a hexagon of light where each foot lands (%d, the stair and the floor), %d steps heard, and the copy standing on its last at the hand-off" % [live["falls"], live["steps"]], live["falls"] == PitBeat.STEPS + 2 and live["steps"] == PitBeat.STEPS and live["stood_at"].distance_to(PitBeat.stand().origin) < 0.01)
	_check("acceptance: dropped as it ends: the machine with the copy and its tag freed, the user name the copy wore let go, the HUD gone, the call long done", live["after_pit"] == null and live["after_user"] == "" and live["after_beat"] == null and not live_guide.is_busy())
	_shut(live_guide)
	_shut(hang_guide)
	var dirty := StubData.new()
	dirty.name_given = DIRTY_NAME
	var cleaned := await _play(null, dirty, 88.0)
	_check("a user name with an escape sequence in it is worn cleaned, as the terminal showed it; with no guide link the scripted line plays, and the copy still comes", cleaned["tag"] == OpenerData.clean(DIRTY_NAME, OpenerData.NAME_LONGEST) and not String(cleaned["tag"]).contains("\u001b") and cleaned["answer"] == OpenerLink.SCRIPTED)


## Plays the opener with `guide` on `data` to the end (or to `stop_at`), and keeps what was shown along the way.
func _play(guide, data: OpenerData, stop_at: float = -1.0) -> Dictionary:
	var o: Opener = OpenerScene.instantiate()
	o.data = data
	o.guide = guide
	root.add_child(o)
	var t := o.timing()
	var seen := {"linking": "", "badge": "", "answer": "", "mark": false, "status": "", "guide": "", "guide_mark": false, "tag": "", "falls": 0, "steps": 0, "stood_at": Vector3.INF}
	var frames := 0
	while frames < MOST_FRAMES and is_instance_valid(o) and o.playing():
		await process_frame
		frames += 1
		if not is_instance_valid(o) or not o.playing():
			break
		var e := o.elapsed()
		var hud := o.link_beat()
		if hud != null:
			if e < t.answer_from and hud.body_text() != "":
				seen["linking"] = hud.body_text()
			if e >= o.locked_at() and o.locked_at() > 0.0 and e < t.guide_at - 0.1:
				seen["badge"] = hud.badge_text()
				seen["answer"] = hud.body_text()
				seen["mark"] = hud.live_mark()
				seen["status"] = hud.status_text()
			if e > t.guide_end and e < t.forge_at:
				seen["guide"] = hud.body_text()
				seen["guide_mark"] = hud.live_mark()
		var pit := o.pit()
		if pit != null and e > t.copy_at + 4.0 and e < t.forge_at:
			seen["tag"] = pit.name_tag()
			seen["falls"] = pit.footfalls().size()
			seen["steps"] = pit.steps_by(e)
			seen["stood_at"] = pit.copy().transform.origin
		if stop_at > 0.0 and e >= stop_at:
			o.skip()
			break
	await process_frame
	var ev := {}
	for event in o.events():
		if not ev.has(event[1]):
			ev[event[1]] = event[0]
	seen["events"] = ev
	seen["after_pit"] = o.pit()
	seen["after_user"] = o.get("_user")
	seen["after_beat"] = o.link_beat()
	o.free()
	await process_frame
	return seen


# --- Esc. ---

func _escape_checks() -> void:
	var t := load("res://resources/opener.tres") as OpenerTuning
	for when in [["mid-link", 72.0], ["mid-copy", 88.0]]:
		var stub: Array = []
		var guide := _guide("esc.cfg", func(tuning: Resource):
			var s := StubAdapter.new(tuning)
			s.mode = "hang"
			stub.append(s)
			return s)
		var o: Opener = OpenerScene.instantiate()
		o.data = StubData.new()
		o.guide = guide
		var state := {"done": false, "skipped": false}
		o.finished.connect(func(skipped: bool):
			state["done"] = true
			state["skipped"] = skipped)
		root.add_child(o)
		var frames := 0
		while frames < MOST_FRAMES and o.playing() and o.elapsed() < when[1]:
			await process_frame
			frames += 1
		var calling := guide.is_busy()
		var phase := o.phase_name()
		var key := InputEventKey.new()
		key.keycode = KEY_ESCAPE
		key.physical_keycode = KEY_ESCAPE
		key.pressed = true
		root.push_input(key)
		# C42: Esc pauses the opener in its own Esc menu; its "Skip intro" leaves.
		var held := o.is_paused() and o.playing()
		o.menu().buttons()[1].pressed.emit()
		await process_frame
		var aborted: int = stub[0].aborts if not stub.is_empty() else 0
		var label := "acceptance: Esc %s (%s at %.2f s, the call %s) pauses it, and \"Skip intro\" leaves at once, skipped; the call stopped, the copy and its name gone" % [when[0], phase, o.elapsed(), "running" if calling else "already over"]
		_check(label, held and state["done"] and state["skipped"] and not o.playing() and o.pit() == null and o.get("_user") == "" and not guide.is_busy() and (aborted == 1 if calling else true) and (calling if when[1] < t.answer_by else true))
		o.free()
		_shut(guide)
		await process_frame


# --- Demo data. ---

func _demo_checks() -> void:
	_factory_calls = 0
	var guide := Link.new()
	guide.demo = true
	guide.settings_path = _root.path_join("demo.cfg")
	guide.adapter_factory = func(_f, _d, _tuning):
		_factory_calls += 1
		return null
	guide.start()
	var demo := await _play(guide, DemoOpenerData.new(), 80.0)
	_check("acceptance: demo data calls nothing (no adapter made, no call): the canned answer (%s) shown live with its canned latency, the agent \"claude\" on the badge, for every capture" % OpenerLink.DEMO_LINE, _factory_calls == 0 and guide.calls == 0 and demo["answer"] == OpenerLink.DEMO_LINE and demo["mark"] and demo["badge"] == "your AI: claude" and demo["status"] == LinkBeat.STATUS_LIVE % (OpenerLink.DEMO_LATENCY_MS / 1000.0))
	_shut(guide)


# --- Helpers. ---

## A guide link of the test's own: a fake detector naming claude, the adapter `make` makes from the guide tuning, and
## the player's answer (yes unless `allowed` is false) in its own settings file under the test's folder.
func _guide(settings: String, make: Callable, allowed: bool = true) -> Link:
	OpenerLink.forget_session()  # a new session each time (C42 keeps a live answer for a session's replays)
	var guide := Link.new()
	guide.settings_path = _root.path_join(settings)
	Settings.save("claude", allowed, guide.settings_path)
	var found := Found.new()
	found.agent_state = Found.AgentState.KNOWN
	found.agent = "claude"
	found.agent_cli_present = true
	Detector.resolve(found)
	var detector := FakeDetector.new()
	detector.result = found
	guide.detector = detector
	guide.adapter_factory = func(_f, _d, tuning: Resource): return make.call(tuning)
	guide.start()
	return guide


func _shut(guide) -> void:
	if guide != null:
		guide.shut_down(null)


func _cleanup() -> void:
	_wipe(_abs)
	_check("the test's own folder is gone, nothing of it left under user://", not DirAccess.dir_exists_absolute(_abs))
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
