extends SceneTree
## Headless guide adapter test for SIGKILL. scripts/check.sh runs it, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/guide_adapter_test.gd
##
## Fakes only. The Claude Code and Codex CLIs are stub scripts under tests/fixtures/ai/guide
## that record their argv, PID, working directory and stdin state; the local model server
## is a fake on a random 127.0.0.1 port, on its own thread. No real agent is ever run and no
## real model server is ever reached. The only files written are the stubs' records, the
## adapters' scratch folders and a release file, all in a fresh temporary folder that the
## test removes at the end.

const Request = preload("res://scripts/ai/guide_request.gd")
const Adapter = preload("res://scripts/ai/guide_adapter.gd")
const Agent = preload("res://scripts/ai/agent_adapter.gd")
const Claude = preload("res://scripts/ai/claude_adapter.gd")
const Codex = preload("res://scripts/ai/codex_adapter.gd")
const Local = preload("res://scripts/ai/local_openai_adapter.gd")
const Registry = preload("res://scripts/ai/guide_registry.gd")
const Process = preload("res://scripts/ai/guide_process.gd")
const Json = preload("res://scripts/ai/quiet_json.gd")
const Detector = preload("res://scripts/ai/ai_source_detector.gd")
const Found = preload("res://scripts/ai/ai_source_result.gd")
const TUNING_SCRIPT := "res://scripts/guide_tuning.gd"
const TUNING_PATH := "res://resources/guide.tres"
const STUBS := "res://tests/fixtures/ai/guide"
const WATCHDOG_MS := 5000
const HANG_TIMEOUT_MS := 1000
const FAKE_MODEL_WORD := "fake-model"
const LOADED_MODEL := "fake-model-loaded:1b"
const LISTED_MODEL := "fake-model-listed"
const EMBED_MODEL := "fake-model-embed"
const SENTINEL := "late sentinel"
const CLAUDE_EXPECTED := ["-p", "--tools", "", "--permission-mode", "dontAsk", "--permission-prompts", "none", "--strict-mcp-config", "--safe-mode", "--disable-slash-commands", "--no-session-persistence", "--output-format", "text", "--system-prompt"]
const CLAUDE_FORBIDDEN := ["--dangerously-skip-permissions", "--allow-dangerously-skip-permissions", "bypassPermissions", "acceptEdits", "auto", "--allowedTools", "--allowed-tools", "--add-dir", "--mcp-config", "--plugin-dir", "--plugin-url", "--agents", "--continue", "--resume", "--bg", "omarchy-agent", "omarchy-agent-prompt"]
const CODEX_EXPECTED := ["exec", "--sandbox", "read-only", "--skip-git-repo-check", "--ephemeral", "--ignore-user-config", "--ignore-rules", "--color", "never", "--disable", "shell_tool", "--disable", "unified_exec", "--config", "include_environment_context=false", "--cd"]
const CODEX_FORBIDDEN := ["--full-auto", "--dangerously-bypass-approvals-and-sandbox", "--dangerously-bypass-hook-trust", "--approve-for-me", "workspace-write", "danger-full-access", "--add-dir", "omarchy-agent", "omarchy-agent-prompt"]
const GUIDE_SOURCES := ["guide_adapter.gd", "agent_adapter.gd", "claude_adapter.gd", "codex_adapter.gd", "local_openai_adapter.gd", "local_http.gd", "guide_request.gd", "guide_registry.gd", "guide_process.gd", "quiet_json.gd"]
const NEVER_ANYWHERE := ["OS.execute(", "OS.create_process", "OS.create_instance", "OS.shell_open", "/bin/sh", "\"sh\"", "\"bash\"", "-c\"", "\"omarchy", "HTTPRequest", "HTTPClient", "JSON.parse", "JSON.new", "to_float(", "UDPServer", "TCPServer"]
const LOCAL_NEVER := ["/api/pull", "/api/delete", "/api/generate", "/api/create", "/api/copy", "/api/push", "/load", "/unload", "\"/v1/models\"", "keep_alive", "num_ctx", "\"options\""]
const V1_MODELS := "/v1/models"

var _fails := 0
var _checks := 0
var _tmp := ""
var _log := ""
var _release := ""
var _results: Array = []
var _fake_now := 0

# Fake local model server, served on its own thread.
var _server := TCPServer.new()
var _server_thread := Thread.new()
var _server_mutex := Mutex.new()
var _server_stop := false
var _server_mode := "loaded"
var _server_requests: Array = []
var _port := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	if not _setup():
		quit(1)
		return
	_safety_checks()
	_tuning_checks()
	_request_checks()
	await _base_checks()
	await _claude_checks()
	await _codex_checks()
	await _local_checks()
	_registry_checks()
	_privacy_checks()
	print("GUIDE: %d checks" % _checks)
	print("GUIDE RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	_teardown()
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


func _setup() -> bool:
	_tmp = OS.get_temp_dir().path_join("sigkill-guide-test-%d" % OS.get_process_id())
	if DirAccess.dir_exists_absolute(_tmp):
		print("FAIL the test's temporary folder already exists; not touching it")
		return false
	DirAccess.make_dir_recursive_absolute(_tmp)
	_log = _tmp.path_join("stub")
	_release = _tmp.path_join("release")
	OS.set_environment("SIGKILL_TEST_GUIDE_LOG", _log)
	OS.set_environment("SIGKILL_TEST_GUIDE_RELEASE", _release)
	if _server.listen(0, Detector.LOCALHOST) != OK:
		print("FAIL the fake server could not listen on 127.0.0.1")
		return false
	_port = _server.get_local_port()
	_server_thread.start(_serve)
	return true


func _teardown() -> void:
	_server_mutex.lock()
	_server_stop = true
	_server_mutex.unlock()
	_server_thread.wait_to_finish()
	_server.stop()
	# Only what this run made, in its own fresh folder.
	for name in ["stub.claude.argv", "stub.claude.meta", "stub.codex.argv", "stub.codex.meta", "release"]:
		if FileAccess.file_exists(_tmp.path_join(name)):
			DirAccess.remove_absolute(_tmp.path_join(name))
	for scratch in DirAccess.get_directories_at(_tmp):
		var root := _tmp.path_join(scratch)
		if FileAccess.file_exists(root.path_join(Codex.ANSWER_FILE)):
			DirAccess.remove_absolute(root.path_join(Codex.ANSWER_FILE))
		if DirAccess.dir_exists_absolute(root.path_join(Agent.WORKDIR_NAME)):
			DirAccess.remove_absolute(root.path_join(Agent.WORKDIR_NAME))
		DirAccess.remove_absolute(root)
	DirAccess.remove_absolute(_tmp)


func _now() -> int:
	return _fake_now


func _tuning(timeout_ms: int = HANG_TIMEOUT_MS) -> Resource:
	var t = load(TUNING_PATH).duplicate()
	t.ai_enabled = true
	t.agent_timeout_ms = timeout_ms
	t.local_timeout_ms = timeout_ms
	return t


func _request() -> RefCounted:
	return Request.build({"kills": 4, "deaths": 2, "accuracy_percent": 61.5, "weapon": "terminal_cannon"}, "where should I stand?", 500)


func _agent(kind, scratch: String, timeout_ms: int = HANG_TIMEOUT_MS) -> Agent:
	var command := "claude" if kind == Claude else "codex"
	var a = kind.new(ProjectSettings.globalize_path(STUBS).path_join(command), _tuning(timeout_ms))
	a.scratch_root = _tmp.path_join(scratch)
	a.rate_clock = _now
	return a


## Asks and polls to the end; also returns the child's PID and whether it is gone after.
func _ask(adapter: RefCounted, mode: String, request: RefCounted = null) -> Dictionary:
	OS.set_environment("SIGKILL_TEST_STUB_MODE", mode)
	_fake_now += 60000
	var started: Dictionary = adapter.ask(request if request != null else _request())
	if not started.is_empty():
		_results.append(started)
		return started
	var pid: int = adapter.child_pid() if adapter.has_method("child_pid") else 0
	var got := {}
	var t0 := Time.get_ticks_msec()
	while got.is_empty() and Time.get_ticks_msec() - t0 < WATCHDOG_MS * 4:
		got = adapter.poll()
		if got.is_empty():
			await process_frame
	got["pid"] = pid
	got["pid_gone"] = pid == 0 or not DirAccess.dir_exists_absolute("/proc/%d" % pid)
	_results.append(got.duplicate())
	return got


func _argv(command: String) -> Array:
	var bytes := FileAccess.get_file_as_bytes(_log + "." + command + ".argv")
	var parts := []
	var start := 0
	for i in bytes.size():
		if bytes[i] == 0:
			parts.append(bytes.slice(start, i).get_string_from_utf8())
			start = i + 1
	return parts


func _meta(command: String) -> Dictionary:
	var out := {}
	for line in FileAccess.get_file_as_string(_log + "." + command + ".meta").split("\n", false):
		var eq := line.find("=")
		if eq > 0:
			out[line.substr(0, eq)] = line.substr(eq + 1)
	return out


func _forget_records() -> void:
	for name in ["stub.claude.argv", "stub.claude.meta", "stub.codex.argv", "stub.codex.meta"]:
		if FileAccess.file_exists(_tmp.path_join(name)):
			DirAccess.remove_absolute(_tmp.path_join(name))


## A source file with its comments cut off, so a scan sees code, not the notes explaining it.
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
		out.append(line.substr(0, cut))
	return "\n".join(out)


func _safety_checks() -> void:
	var found := PackedStringArray()
	var execs := 0
	var kills := 0
	for name in GUIDE_SOURCES:
		var source := _code("res://scripts/ai/".path_join(name))
		for word in NEVER_ANYWHERE:
			if source.contains(word):
				found.append("%s in %s" % [word, name])
		execs += source.count("OS.execute_with_pipe(")
		kills += source.count("OS.kill(")
	_check("no guide file runs a shell, omarchy-agent, OS.execute or create_process, or parses with Godot's JSON or to_float", found.is_empty(), ", ".join(found))
	var process := _code("res://scripts/ai/guide_process.gd")
	_check("the one program start and the only stops are in guide_process.gd", execs == 1 and process.count("OS.execute_with_pipe(path, args, false)") == 1 and kills == process.count("OS.kill(pid)") and kills == 2)
	_check("every stop is guarded: our own child, checked running just before", process.count("if OS.is_process_running(pid):\n\t\tOS.kill(pid)") == 1 and process.count("if OS.is_process_running(pid):\n\t\t\tOS.kill(pid)") == 1)
	var local := _code("res://scripts/ai/local_http.gd") + _code("res://scripts/ai/local_openai_adapter.gd")
	var local_bad := PackedStringArray()
	for word in LOCAL_NEVER:
		if local.contains(word):
			local_bad.append(word)
	_check("the local adapter never loads, pulls, deletes, generates or unloads, never lists with /v1/models, and never sends num_ctx, options or keep_alive", local_bad.is_empty(), ", ".join(local_bad))
	_check("its one socket connects only to the constant 127.0.0.1", local.count("connect_to_host(") == 1 and local.contains("connect_to_host(Detector.LOCALHOST, port)"))
	var users := PackedStringArray()
	var dirs := ["res://scripts", "res://scenes"]
	while not dirs.is_empty():
		var dir: String = dirs.pop_back()
		if dir == "res://scripts/ai":
			continue
		for sub in DirAccess.get_directories_at(dir):
			dirs.append(dir.path_join(sub))
		for file in DirAccess.get_files_at(dir):
			var text := FileAccess.get_file_as_string(dir.path_join(file))
			if (file.ends_with(".gd") or file.ends_with(".tscn")) and file != "guide_tuning.gd" and (text.contains("scripts/ai/") or text.contains("guide_tuning")):
				users.append(dir.path_join(file))
	users.sort()
	_check("outside scripts/ai only the boot screen (C10), the guide link and the guide HUD (C11) use the guide", Array(users) == ["res://scripts/boot/boot_sequence.gd", "res://scripts/boot/guide_settings.gd", "res://scripts/guide/guide_link.gd", "res://scripts/hud/guide_hud.gd"], ", ".join(users))


func _tuning_checks() -> void:
	var t: Resource = load(TUNING_PATH)
	_check("shipped guide tuning validates and starts with the AI off", t.problems().is_empty() and t.ai_enabled == false, ", ".join(t.problems()))
	var script: Script = load(TUNING_SCRIPT)
	var text := FileAccess.get_file_as_string(TUNING_PATH)
	var missing := PackedStringArray()
	for prop in script.get_script_property_list():
		if prop["usage"] & PROPERTY_USAGE_STORAGE and prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE and not text.contains("\n" + prop["name"] + " = "):
			missing.append(prop["name"])
	_check("guide.tres lists every tunable of guide_tuning.gd", missing.is_empty(), ", ".join(missing))
	var bad: Resource = t.duplicate()
	bad.min_interval_ms = 0
	bad.agent_timeout_ms = 0
	bad.typed_text_max_chars = 0
	bad.stdout_max_bytes = 10
	bad.local_max_tokens = 0
	var problems: PackedStringArray = bad.problems()
	_check("validation refuses a per-frame interval, a zero timeout, zero caps and zero tokens", problems.size() == 5, ", ".join(problems))
	var fallback = Claude.new("", bad)
	_check("an adapter given bad tuning falls back to the shipped tuning", fallback.tuning().problems().is_empty())
	var big: Resource = t.duplicate()
	big.stdout_max_bytes = 65537
	var late = Claude.new("", t.duplicate())
	late.tuning().stdout_max_bytes = 1048576
	_check("agent output over 64 KiB is refused, and a cap raised after the check is still held to 64 KiB", big.problems().size() == 1 and late.stdout_cap() == 65536 and t.stdout_max_bytes == 65536)


func _request_checks() -> void:
	var rlo := String.chr(0x202E)
	var seeded := {
		"kills": 3, "deaths": 1, "accuracy_percent": 42.0, "weapon": "terminal_cannon",
		"mode": "/fake/people/someone/.ssh/id_fake", "map_path": "/fake/people/someone/maps/arena.map",
		"hostname": "fake-host-01", "process_name": "fakeproc-daemon", "user": "fakeuser", "streak": 2.5, "shots_fired": -4,
	}
	var r = Request.build(seeded, "  stay" + rlo + " low\tand\n\nmove" + String.chr(0x1B) + "[31m " + "x".repeat(800), 500)
	var prompt: String = r.full_prompt()
	var leaked := PackedStringArray()
	for word in ["/fake", "fake-host", "fakeproc", "fakeuser", "map_path", "hostname", "process_name", "/"]:
		if prompt.contains(word):
			leaked.append(word)
	_check("only whitelisted stats get in; a seeded path, host name, process name and user are dropped", r.stats.keys() == ["kills", "deaths", "accuracy_percent", "weapon"] and leaked.is_empty(), "stats %s, leaked %s" % [r.stats.keys(), ", ".join(leaked)])
	_check("typed text is capped and loses control and direction characters", r.text.length() == 500 and not r.text.contains(rlo) and not r.text.contains(String.chr(0x1B)) and not r.text.contains("\t") and not r.text.contains("\n") and r.text.begins_with("stay low and move"))
	_check("the prompt is the fixed preamble, the stats line and the player's text", prompt.begins_with(Request.PREAMBLE) and r.user_message().begins_with("Game stats: kills=3, deaths=1, accuracy_percent=42.0, weapon=terminal_cannon\nPlayer: stay low"))
	var empty = Request.build({}, "", 500)
	_check("no stats and no text still make a well-formed message", empty.user_message() == "Game stats: none\nPlayer: (no message)")


func _base_checks() -> void:
	var off = _agent(Claude, "base")
	off.tuning().ai_enabled = false
	_forget_records()
	var refused: Dictionary = off.ask(_request())
	_results.append(refused)
	_check("with the AI off, ask() refuses at once and launches nothing", refused["error_kind"] == "ai_off" and not refused["ok"] and not FileAccess.file_exists(_log + ".claude.argv"))
	var a = _agent(Claude, "base")
	OS.set_environment("SIGKILL_TEST_STUB_MODE", "ok")
	_fake_now = 1000000
	var first: Dictionary = a.ask(_request())
	var second: Dictionary = a.ask(_request())
	_check("one request in flight: a second ask while busy is refused", first.is_empty() and second["error_kind"] == "busy" and a.is_busy())
	var done := {}
	while done.is_empty():
		done = a.poll()
		await process_frame
	_fake_now += a.tuning().min_interval_ms - 1
	var soon: Dictionary = a.ask(_request())
	_fake_now += 1
	var later: Dictionary = a.ask(_request())
	var later_done := {}
	while later.is_empty() and later_done.is_empty():
		later_done = a.poll()
		await process_frame
	_check("asks closer than min_interval_ms are refused, and the next one after it starts", done["ok"] and soon["error_kind"] == "rate_limited" and later.is_empty() and later_done["ok"])
	var wrong_name = Claude.new(ProjectSettings.globalize_path(STUBS).path_join("codex"), _tuning())
	var relative = Claude.new("tests/fixtures/ai/guide/claude", _tuning())
	var missing = Claude.new(_tmp.path_join("claude"), _tuning())
	var shell = Claude.new("/bin/sh", _tuning())
	_check("a command not named claude, a relative path, a missing file and a shell are all unavailable", not wrong_name.is_available() and not relative.is_available() and not missing.is_available() and not shell.is_available() and wrong_name.ask(_request())["error_kind"] == "unavailable")
	_check("poll() and cancel() with nothing running return nothing", a.poll().is_empty() and a.cancel().is_empty())


func _claude_checks() -> void:
	var a = _agent(Claude, "claude")
	var request := _request()
	var ok := await _ask(a, "ok", request)
	var argv := _argv("claude")
	var meta := _meta("claude")
	_check("Claude Code: the answer comes back from print mode", ok["ok"] and ok["text"] == "Aim for the core, then strafe left." and ok["error_kind"] == "" and ok["tokens_per_sec"] == -1.0)
	_check("Claude Code: argv is exactly the documented flags, the preamble and the prompt", argv.slice(0, CLAUDE_EXPECTED.size()) == CLAUDE_EXPECTED and argv.size() == CLAUDE_EXPECTED.size() + 2 and argv[-2] == Request.PREAMBLE and argv[-1] == request.user_message(), str(argv.slice(0, argv.size() - 2)))
	var bad := PackedStringArray()
	for flag in CLAUDE_FORBIDDEN:
		if argv.has(flag):
			bad.append(flag)
	_check("Claude Code: no permission bypass, granted tools, MCP config or omarchy-agent", bad.is_empty(), ", ".join(bad))
	_check("Claude Code: the prompt is one argument, never an option, and nothing is written to stdin", String(argv[-1]).begins_with("Game stats:") and meta.get("stdin", "") == "open")
	var scratch: String = a.workdir()
	_check("the scratch directory exists and is empty after a run", scratch != "" and DirAccess.get_files_at(scratch).is_empty())
	var ansi := await _ask(_agent(Claude, "claude"), "ansi")
	_check("ANSI escapes, an OSC title, CR and control bytes are stripped from the answer", ansi["ok"] and ansi["text"] == "Stay low\nand move", str(ansi["text"]).c_escape())
	var flood_adapter := _agent(Claude, "claude")
	var flood := await _ask(flood_adapter, "flood")
	_check("a flood of output is capped and the answer cut to answer_max_chars", flood["ok"] and String(flood["text"]).length() == flood_adapter.tuning().answer_max_chars and String(flood["text"]).begins_with("flood line 0\n"))
	var padded := await _ask(_agent(Claude, "claude"), "padded")
	_check("Claude Code: output past 64 KiB is never read: 64 KiB of control bytes, then a sentinel, gives an empty answer", not padded["ok"] and padded["error_kind"] == "empty" and not String(padded["text"]).contains(SENTINEL), str(padded))
	OS.set_environment("SIGKILL_TEST_STUB_MODE", "flood")
	var process := Process.new()
	process.start(ProjectSettings.globalize_path(STUBS).path_join("claude"), PackedStringArray(["flood"]), false, 65536)
	var t0 := Time.get_ticks_msec()
	while not process.poll() and Time.get_ticks_msec() - t0 < WATCHDOG_MS:
		await process_frame
	_check("the process helper keeps exactly the cap of a flood and says it overflowed", process.output().size() == 65536 and process.overflowed() and process.exit_code == 0, "%d bytes" % process.output().size())
	var failed := await _ask(_agent(Claude, "claude"), "fail")
	_check("a nonzero exit is agent_error", not failed["ok"] and failed["error_kind"] == "agent_error" and failed["pid_gone"])
	# Timeout: only our own child is stopped. A bystander stub runs the whole time.
	OS.set_environment("SIGKILL_TEST_STUB_MODE", "hang")
	var bystander := OS.execute_with_pipe(ProjectSettings.globalize_path(STUBS).path_join("claude"), PackedStringArray(["bystander"]), false)
	var hung := await _ask(_agent(Claude, "claude"), "hang")
	var bystander_alive := OS.is_process_running(bystander["pid"])
	print("GUIDE timeout: a hung stub was stopped after %d ms, PID gone %s; a bystander stub alive %s" % [hung["latency_ms"], hung["pid_gone"], bystander_alive])
	_check("a hung agent is stopped at the timeout by its own PID, reaped, and nothing else is touched", not hung["ok"] and hung["error_kind"] == "timeout" and hung["latency_ms"] >= HANG_TIMEOUT_MS and hung["latency_ms"] < WATCHDOG_MS and hung["pid"] > 0 and hung["pid"] != bystander["pid"] and hung["pid_gone"] and bystander_alive)
	# cancel(), then a drop at game exit, both mid-run.
	var c := _agent(Claude, "claude", 60000)
	OS.set_environment("SIGKILL_TEST_STUB_MODE", "hang")
	_fake_now += 60000
	c.ask(_request())
	var cancel_pid: int = c.child_pid()
	var cancelled: Dictionary = c.cancel()
	_results.append(cancelled)
	_check("cancel() stops the running agent and returns cancelled", cancelled["error_kind"] == "cancelled" and cancel_pid > 0 and not DirAccess.dir_exists_absolute("/proc/%d" % cancel_pid) and not c.is_busy())
	var dropped := _agent(Claude, "claude", 60000)
	_fake_now += 60000
	dropped.ask(_request())
	var drop_pid: int = dropped.child_pid()
	dropped = null
	_check("a guide dropped at game exit stops its own running agent", drop_pid > 0 and not DirAccess.dir_exists_absolute("/proc/%d" % drop_pid))
	# Let the bystander end on its own, then reap it.
	FileAccess.open(_release, FileAccess.WRITE).close()
	t0 = Time.get_ticks_msec()
	while OS.is_process_running(bystander["pid"]) and Time.get_ticks_msec() - t0 < WATCHDOG_MS:
		OS.delay_msec(10)
	(bystander["stdio"] as FileAccess).close()
	(bystander["stderr"] as FileAccess).close()
	DirAccess.remove_absolute(_release)


func _codex_checks() -> void:
	var a = _agent(Codex, "codex")
	var request := _request()
	var ok := await _ask(a, "ok", request)
	var argv := _argv("codex")
	var meta := _meta("codex")
	var scratch: String = a.workdir()
	_check("Codex: the answer comes back through --output-last-message", ok["ok"] and ok["text"] == "Aim for the core, then strafe left.")
	_check("Codex: argv is exactly the documented flags, the scratch directory, the answer file and the prompt", argv.slice(0, CODEX_EXPECTED.size()) == CODEX_EXPECTED and argv.size() == CODEX_EXPECTED.size() + 4 and argv[CODEX_EXPECTED.size()] == scratch and argv[-3] == "--output-last-message" and argv[-2] == a.answer_path() and argv[-1] == request.full_prompt(), str(argv.slice(0, CODEX_EXPECTED.size())))
	var bad := PackedStringArray()
	for flag in CODEX_FORBIDDEN:
		if argv.has(flag):
			bad.append(flag)
	_check("Codex: no full-auto, no approval or sandbox bypass, no writable sandbox, no omarchy-agent", bad.is_empty(), ", ".join(bad))
	var configs := []
	for i in argv.size() - 1:
		if argv[i] == "--config" or argv[i] == "-c":
			configs.append(argv[i + 1])
	_check("Codex: the only config override turns off its environment note", configs == ["include_environment_context=false"], str(configs))
	_check("Codex: --cd is the empty scratch directory and the answer file lies outside it", meta.get("cd", "") == scratch and DirAccess.get_files_at(scratch).is_empty() and not a.answer_path().begins_with(scratch))
	_check("Codex: stdin is closed at once, so it never waits for input", meta.get("stdin", "") == "eof")
	var epipe := await _ask(_agent(Codex, "codex"), "epipe")
	_check("an answer written to the file counts even if the agent then dies on its closed stdout", epipe["ok"] and epipe["text"] == "Aim for the core, then strafe left.")
	var stale := _agent(Codex, "codex")
	await _ask(stale, "ok")
	var after := await _ask(_agent(Codex, "codex"), "fail")
	_check("an old answer is never read back: the file is emptied before each launch", not after["ok"] and after["error_kind"] == "agent_error")
	var ansi := await _ask(_agent(Codex, "codex"), "ansi")
	_check("Codex answers are cleaned the same way", ansi["ok"] and ansi["text"] == "Stay low\nand move", str(ansi["text"]).c_escape())
	var flood_adapter := _agent(Codex, "codex")
	var flood := await _ask(flood_adapter, "flood")
	_check("a flooded answer file is read only up to the cap", flood["ok"] and String(flood["text"]).length() == flood_adapter.tuning().answer_max_chars)
	var padded := await _ask(_agent(Codex, "codex"), "padded")
	_check("Codex: the answer file is read only to 64 KiB: control bytes, then a sentinel, gives no answer", not padded["ok"] and padded["error_kind"] == "empty" and not String(padded["text"]).contains(SENTINEL), str(padded))
	var hung := await _ask(_agent(Codex, "codex"), "hang")
	_check("a hung Codex is stopped at the timeout by its own PID and reaped", hung["error_kind"] == "timeout" and hung["pid"] > 0 and hung["pid_gone"])


func _set_mode(mode: String) -> void:
	_server_mutex.lock()
	_server_mode = mode
	_server_requests.clear()
	_server_mutex.unlock()


func _server_state() -> Array:
	_server_mutex.lock()
	var state := [_server_stop, _server_mode, _server_requests.duplicate(true)]
	_server_mutex.unlock()
	return state


## The fake server's answer. LM Studio's own listings put a loaded embedding model and an
## unloaded chat model before the loaded chat model, so an adapter that took the first
## loaded or the first listed model would pick the wrong one; /v1/models lists only the
## unloaded model, as LM Studio does with just-in-time loading on.
func _reply(mode: String, method: String, path: String) -> PackedByteArray:
	var body := ""
	var status := "200 OK"
	var missing := "404 Not Found"
	if path == Local.OLLAMA_PS_PATH:
		body = '{"models":[]}' if mode == "empty" else '{"models":[{"name":"%s","model":"%s","size_vram":123}]}' % [LOADED_MODEL, LOADED_MODEL]
	elif path == Local.LMSTUDIO_V1_PATH:
		match mode:
			"jit":
				body = '{"models":[{"type":"llm","key":"%s","loaded_instances":[]},{"type":"llm","key":"%s","loaded_instances":[]}]}' % [LISTED_MODEL, LOADED_MODEL]
			"embedonly":
				body = '{"models":[{"type":"embedding","key":"%s","loaded_instances":[{"id":"%s","config":{}}]},{"key":"%s","loaded_instances":[{"id":"%s","config":{}}]}]}' % [EMBED_MODEL, EMBED_MODEL, LISTED_MODEL, LISTED_MODEL]
			"v0", "v0hostile", "generic":
				status = missing
			_:
				body = '{"models":[{"type":"embedding","key":"%s","loaded_instances":[{"id":"%s","config":{}}]},{"type":"llm","key":"%s","loaded_instances":[]},{"type":"llm","key":"%s","loaded_instances":[{"id":"%s","config":{}}]}]}' % [EMBED_MODEL, EMBED_MODEL, LISTED_MODEL, LOADED_MODEL, LOADED_MODEL]
	elif path == Local.LMSTUDIO_V0_PATH:
		match mode:
			"v0":
				body = '{"object":"list","data":[{"id":"%s","type":"embeddings","state":"loaded"},{"id":"%s","type":"llm","state":"not-loaded"},{"id":"%s","type":"vlm","state":"loaded"}]}' % [EMBED_MODEL, LISTED_MODEL, LOADED_MODEL]
			"v0hostile":
				body = '{"object":"list","data":[{"id":"%s","type":"llm","state":5},{"id":["x"],"type":"llm","state":"loaded"},{"id":7,"type":"llm","state":null},{"id":"%s","type":5,"state":"loaded"},{"id":"%s","state":"loaded"},"loaded"]}' % [LISTED_MODEL, LISTED_MODEL, LISTED_MODEL]
			_:
				status = missing
	elif path == V1_MODELS:
		body = '{"object":"list","data":[{"id":"%s"}]}' % LISTED_MODEL
	elif path == Local.CHAT_PATH and method == "POST":
		match mode:
			"hostile":
				body = '{"choices":[{"message":{"role":"assistant","content":"zero\\u0000here \\ud800 lone"}}],"usage":{"completion_tokens":1e999999}}'
			"nonjson":
				body = "<html>busy</html>"
			"named":
				body = '{"choices":[{"message":{"role":"assistant","content":"%s here, and %s again."}}]}' % [LOADED_MODEL.to_upper(), LOADED_MODEL]
			_:
				body = '{"choices":[{"message":{"role":"assistant","content":"Strafe left \\u001b[31mnow\\u001b[0m."}}],"usage":{"prompt_tokens":40,"completion_tokens":12}}'
	else:
		status = missing
	if mode == "error500":
		status = "500 Internal Server Error"
	if body == "" and status == "200 OK":
		status = missing
	var bytes := body.to_utf8_buffer()
	var length := bytes.size() + (50 if mode == "truncated" and path == Local.CHAT_PATH else 0)
	var out := ("HTTP/1.1 %s\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % [status, length]).to_utf8_buffer()
	out.append_array(bytes)
	return out


func _serve() -> void:
	var conns := []
	while true:
		var state := _server_state()
		if state[0]:
			break
		while _server.is_connection_available():
			conns.append({"peer": _server.take_connection(), "buf": PackedByteArray(), "mode": _server_state()[1]})
		for e in conns.duplicate():
			var peer: StreamPeerTCP = e["peer"]
			peer.poll()
			if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
				conns.erase(e)
				continue
			var waiting := peer.get_available_bytes()
			if waiting > 0:
				var buf: PackedByteArray = e["buf"]
				buf.append_array(peer.get_data(waiting)[1])
				e["buf"] = buf
			var raw: PackedByteArray = e["buf"]
			var text := raw.get_string_from_ascii()
			var split := text.find("\r\n\r\n")
			if split < 0:
				continue
			var head := text.substr(0, split)
			var length := 0
			for line in head.split("\r\n"):
				if line.to_lower().begins_with("content-length:"):
					length = line.substr(15).strip_edges().to_int()
			if raw.size() - (split + 4) < length:
				continue
			var first := head.split("\r\n")[0].split(" ")
			_server_mutex.lock()
			_server_requests.append({"method": first[0], "path": first[1], "body": raw.slice(split + 4)})
			_server_mutex.unlock()
			if e["mode"] == "hang":
				continue
			peer.put_data(_reply(e["mode"], first[0], first[1]))
			peer.disconnect_from_host()
			conns.erase(e)
		OS.delay_usec(500)
	for e in conns:
		(e["peer"] as StreamPeerTCP).disconnect_from_host()


func _paths(requests: Array) -> Array:
	var out := []
	for r in requests:
		out.append(r["path"])
	return out


func _local(kind: String) -> Local:
	var a := Local.new(_tuning())
	a.configure(kind, Detector.LOCALHOST, _port)
	a.rate_clock = _now
	return a


func _local_checks() -> void:
	var probe := Local.new(_tuning())
	_check("the local adapter refuses every host but 127.0.0.1, even localhost", not probe.configure(Local.KIND_OLLAMA, ".".join(["192", "0", "2", "1"]), _port) and not probe.configure(Local.KIND_OLLAMA, "localhost", _port) and not probe.configure(Local.KIND_OLLAMA, "::1", _port) and not probe.configure("unknown", Detector.LOCALHOST, _port) and not probe.is_available() and probe.configure(Local.KIND_OLLAMA, Detector.LOCALHOST, _port))
	_set_mode("loaded")
	var ok := await _ask(_local(Local.KIND_OLLAMA), "")
	var requests: Array = _server_state()[2]
	_check("Ollama path, an already-loaded model answers, cleaned, with tokens per second", ok["ok"] and ok["text"] == "Strafe left now." and ok["tokens_per_sec"] > 0.0, str(ok))
	_check("Ollama path, it asks /api/ps first, then one chat request", requests.size() == 2 and requests[0]["method"] == "GET" and requests[0]["path"] == Local.OLLAMA_PS_PATH and requests[1]["method"] == "POST" and requests[1]["path"] == Local.CHAT_PATH)
	var body: PackedByteArray = requests[1]["body"] if requests.size() == 2 else PackedByteArray()
	var parsed := Json.parse(body)
	var sent = parsed[1]
	var keys: Array = (sent as Dictionary).keys() if sent is Dictionary else []
	keys.sort()
	var text := body.get_string_from_utf8()
	_check("the chat body is exactly model, messages, stream and max_tokens, with the loaded model", parsed[0] and keys == ["max_tokens", "messages", "model", "stream"] and sent["model"] == LOADED_MODEL and sent["stream"] == false and sent["max_tokens"] == 200, str(keys))
	_check("the chat body carries no num_ctx, options or keep_alive", not text.contains("num_ctx") and not text.contains("options") and not text.contains("keep_alive"))
	_check("the messages are the preamble as system and the stats and text as user", sent is Dictionary and sent["messages"].size() == 2 and sent["messages"][0]["role"] == "system" and sent["messages"][0]["content"] == Request.PREAMBLE and sent["messages"][1]["role"] == "user" and String(sent["messages"][1]["content"]).begins_with("Game stats: kills=4"))
	_set_mode("empty")
	var consent := await _ask(_local(Local.KIND_OLLAMA), "")
	var consent_requests: Array = _server_state()[2]
	_check("nothing loaded: needs_consent, and no chat request is ever made", not consent["ok"] and consent["error_kind"] == "needs_consent" and consent_requests.size() == 1 and consent_requests[0]["path"] == Local.OLLAMA_PS_PATH)
	_set_mode("loaded")
	var lms := await _ask(_local(Local.KIND_OPENAI), "")
	var lms_requests: Array = _server_state()[2]
	_check("LM Studio 0.4+: /api/v1/models, a loaded embedding model and an unloaded chat model are skipped, the loaded chat model used", lms["ok"] and _paths(lms_requests) == [Local.LMSTUDIO_V1_PATH, Local.CHAT_PATH] and Json.parse(lms_requests[1]["body"])[1]["model"] == LOADED_MODEL, str(_paths(lms_requests)))
	_set_mode("jit")
	var jit := await _ask(_local(Local.KIND_OPENAI), "")
	var jit_requests: Array = _server_state()[2]
	_check("LM Studio with just-in-time loading and nothing loaded: needs_consent, no chat request, /v1/models never asked", not jit["ok"] and jit["error_kind"] == "needs_consent" and _paths(jit_requests) == [Local.LMSTUDIO_V1_PATH], str(_paths(jit_requests)))
	_set_mode("v0")
	var v0 := await _ask(_local(Local.KIND_OPENAI), "")
	var v0_requests: Array = _server_state()[2]
	_check("older LM Studio: /api/v0/models, only a chat model (llm or vlm) whose state is loaded", v0["ok"] and _paths(v0_requests) == [Local.LMSTUDIO_V1_PATH, Local.LMSTUDIO_V0_PATH, Local.CHAT_PATH] and Json.parse(v0_requests[2]["body"])[1]["model"] == LOADED_MODEL, str(_paths(v0_requests)))
	_set_mode("embedonly")
	var embed := await _ask(_local(Local.KIND_OPENAI), "")
	var embed_requests: Array = _server_state()[2]
	_check("only an embedding model or an untyped model is loaded: needs_consent, no chat request", not embed["ok"] and embed["error_kind"] == "needs_consent" and _paths(embed_requests) == [Local.LMSTUDIO_V1_PATH], str(_paths(embed_requests)))
	_set_mode("generic")
	var generic := await _ask(_local(Local.KIND_OPENAI), "")
	var generic_requests: Array = _server_state()[2]
	_check("a server that cannot say what is loaded gets needs_consent: no chat request, /v1/models never asked", not generic["ok"] and generic["error_kind"] == "needs_consent" and _paths(generic_requests) == [Local.LMSTUDIO_V1_PATH, Local.LMSTUDIO_V0_PATH], str(_paths(generic_requests)))
	_set_mode("v0hostile")
	var odd := await _ask(_local(Local.KIND_OPENAI), "")
	var odd_requests: Array = _server_state()[2]
	_check("a listing with wrongly typed ids, types and states is skipped quietly: needs_consent", not odd["ok"] and odd["error_kind"] == "needs_consent" and not _paths(odd_requests).has(Local.CHAT_PATH), str(_paths(odd_requests)))
	_set_mode("hostile")
	var hostile := await _ask(_local(Local.KIND_OLLAMA), "")
	_check("a hostile answer (NUL escape, lone surrogate, 1e999999 tokens) is read quietly; tokens per second unknown", hostile["ok"] and hostile["tokens_per_sec"] == -1.0 and String(hostile["text"]).begins_with("zero"))
	_set_mode("named")
	var named := await _ask(_local(Local.KIND_OLLAMA), "")
	_check("an answer that names the loaded model has the name replaced, in any letter case", named["ok"] and named["text"] == "the local model here, and the local model again." and String(named["text"]).findn(FAKE_MODEL_WORD) < 0, str(named["text"]))
	var bad_kinds := PackedStringArray()
	for mode in ["truncated", "nonjson", "error500"]:
		_set_mode(mode)
		var got := await _ask(_local(Local.KIND_OLLAMA), "")
		if got["ok"] or (got["error_kind"] != "bad_response" and got["error_kind"] != "unreachable"):
			bad_kinds.append("%s gave %s" % [mode, got["error_kind"]])
	_check("truncated, non-JSON and error answers are refused", bad_kinds.is_empty(), ", ".join(bad_kinds))
	_set_mode("hang")
	var hung := await _ask(_local(Local.KIND_OLLAMA), "")
	_check("a server that never answers times out", not hung["ok"] and hung["error_kind"] == "timeout" and hung["latency_ms"] >= HANG_TIMEOUT_MS and hung["latency_ms"] < WATCHDOG_MS, "%s in %d ms" % [hung["error_kind"], hung["latency_ms"]])
	_set_mode("loaded")
	var spare := TCPServer.new()
	spare.listen(0, Detector.LOCALHOST)
	var closed_port := spare.get_local_port()
	spare.stop()
	var closed := Local.new(_tuning())
	closed.configure(Local.KIND_OLLAMA, Detector.LOCALHOST, closed_port)
	closed.rate_clock = _now
	var refused := await _ask(closed, "")
	_check("a closed port is unreachable", not refused["ok"] and refused["error_kind"] == "unreachable")


func _found(agent: String, cli: bool, ollama_models: int, openai_models: int) -> Found:
	var f := Found.new()
	if agent != "":
		f.agent_state = Found.AgentState.KNOWN
		f.agent = agent
		f.agent_cli_present = cli
	f.ollama_reachable = ollama_models >= 0
	f.ollama_model_count = ollama_models
	f.openai_reachable = openai_models >= 0
	f.openai_model_count = openai_models
	Detector.resolve(f)
	return f


func _registry_checks() -> void:
	var d := Detector.new()
	d.path_dirs = PackedStringArray([ProjectSettings.globalize_path(STUBS)])
	d.ollama_port = _port
	d.openai_port = _port
	var picks := PackedStringArray()
	for c in [["claude", true, 2, -1], ["codex", true, 2, 1], ["gemini", true, 2, -1], ["claude", false, -1, 3], ["", false, 0, -1], ["", false, -1, -1]]:
		var a = Registry.adapter_for(_found(c[0], c[1], c[2], c[3]), d, _tuning())
		picks.append("null" if a == null else (a.adapter_name() + (":" + String(a.get("_kind")) if a.adapter_name() == "local" else "")))
	_check("the registry follows the fallback order; an agent with no adapter falls through", Array(picks) == ["claude", "codex", "local:ollama", "local:openai-compatible", "null", "null"], ", ".join(picks))
	var empty_path := Detector.new()
	empty_path.path_dirs = PackedStringArray([_tmp])
	_check("an agent whose command cannot be found falls through too", Registry.adapter_for(_found("claude", true, -1, -1), empty_path, _tuning()) == null)


func _privacy_checks() -> void:
	var forbidden := PackedStringArray([ProjectSettings.globalize_path("res://"), _tmp, FAKE_MODEL_WORD, Detector.LOCALHOST])
	for env in ["HOME", "USER", "LOGNAME"]:
		var value := OS.get_environment(env)
		if value.length() > 2:
			forbidden.append(value)
	var hostname := FileAccess.get_file_as_string("/proc/sys/kernel/hostname").strip_edges()
	if hostname.length() > 2:
		forbidden.append(hostname)
	var leaks := 0
	for r in _results:
		var shown: Dictionary = (r as Dictionary).duplicate()
		shown.erase("pid")
		shown.erase("pid_gone")
		var text := str(shown)
		for word in forbidden:
			if text.contains(word):
				leaks += 1
				break
	_check("no result holds a path, a user or host name, the server address or a model name", _results.size() >= 20 and leaks == 0, "%d results, %d with a leak" % [_results.size(), leaks])
