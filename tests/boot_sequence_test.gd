extends SceneTree
## Headless boot sequence test for SIGKILL. scripts/check.sh runs it, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/boot_sequence_test.gd
##
## Fakes only. The boot screen gets a spy detector (or the real C9 detector class pointed
## at the fixtures under tests/fixtures/ai and a fake model server on a random 127.0.0.1
## port) and a stub adapter built on the real C9b adapter base. The one agent command it
## could ever find is the fixtures' stub that leaves a mark if it is run. No real agent,
## model server, nvidia-smi or settings file is touched: settings live in a fresh temporary
## folder that the test removes at the end.

const BootScene = preload("res://scenes/boot.tscn")
const Boot = preload("res://scripts/boot/boot_sequence.gd")
const BootTuningScript = preload("res://scripts/boot/boot_tuning.gd")
const Settings = preload("res://scripts/boot/guide_settings.gd")
const Detector = preload("res://scripts/ai/ai_source_detector.gd")
const Found = preload("res://scripts/ai/ai_source_result.gd")
const Request = preload("res://scripts/ai/guide_request.gd")
const BOOT_TUNING_PATH := "res://resources/boot.tres"
const FIXTURES := "res://tests/fixtures/ai"
const ARENA := "res://scenes/main.tscn"
const WATCHDOG_MS := 8000
const STUB_ANSWER := "Linked. Let's clear this arena."
const LEAK_MODEL := "fake-model-secret:7b"
const LEAK_HOST := "fake-host-01"
const LEAK_USER := "fakeuser"
const LEAK_PATH := "/fake/people/someone/bin/fakeagent"
## The same kinds of names without a digit or a slash, which a character filter would pass.
const LEAK_USER_WORD := "Fakeuser"
const LEAK_HOST_WORD := "fakehost"
const LEAK_MODEL_WORD := "Fakemodel"
const SOURCE_NEVER := ["OS.execute", "OS.create_process", "OS.kill", "OS.shell_open", "execute_with_pipe", "StreamPeerTCP", "HTTPRequest", "HTTPClient", "TCPServer", "UDPServer", "JSON.parse"]

var _fails := 0
var _checks := 0
var _tmp := ""
var _fx := ""
var _mark := ""
var _fast: Resource
var _screens: Array = []

# Fake model server on its own thread: records every request line, answers what a local
# server would, with private-looking model, host and user strings in it.
var _server := TCPServer.new()
var _server_thread := Thread.new()
var _server_mutex := Mutex.new()
var _server_stop := false
var _server_paths: Array = []
var _port := 0
var _closed_port := 0


class FakeDetector:
	extends RefCounted
	## Stands in for the C9 detector: a canned result, and counts of every call.
	var result: Found
	var reading := {"available": false}
	var starts := 0
	var waits := 0
	var finds := 0
	var cancels := 0
	var gpu_calls := 0
	var gpu_running := 0
	## How long each GPU reading takes unless cancelled; 0 answers at once.
	var slow_ms := 0
	var cancelled := false
	var mutex := Mutex.new()

	func start() -> Error:
		starts += 1
		return OK

	func is_done() -> bool:
		return true

	func wait() -> Found:
		waits += 1
		return result

	func cancel() -> void:
		mutex.lock()
		cancels += 1
		cancelled = true
		mutex.unlock()

	func find_command(_command: String) -> String:
		finds += 1
		return ""

	func poll_gpu() -> Dictionary:  # runs on the boot screen's GPU worker thread
		mutex.lock()
		gpu_calls += 1
		gpu_running += 1
		var out := reading.duplicate()
		mutex.unlock()
		# Like the C9 reader waiting on nvidia-smi: slow, but it gives up at a cancel.
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < slow_ms:
			mutex.lock()
			var stop := cancelled
			mutex.unlock()
			if stop:
				break
			OS.delay_msec(5)
		mutex.lock()
		gpu_running -= 1
		mutex.unlock()
		return out

	func running() -> int:
		mutex.lock()
		var n := gpu_running
		mutex.unlock()
		return n

	func gpu_count() -> int:
		mutex.lock()
		var n := gpu_calls
		mutex.unlock()
		return n


class StubAdapter:
	extends "res://scripts/ai/guide_adapter.gd"
	## A guide adapter that answers as told, on the real base class: pacing, the AI switch
	## and the timeout all come from GuideAdapter.
	var name := "claude"
	var kind := ""
	var mode := "ok"
	var answer := "Linked. Let's clear this arena."
	var tps := -1.0
	var ask_calls := 0
	var begins := 0
	var steps := 0
	var last_message := ""

	func _init(tuning_resource: Resource) -> void:
		super(tuning_resource)

	func adapter_name() -> String:
		return name

	func source_name() -> String:
		return kind if kind != "" else name

	func is_available() -> bool:
		return true

	func ask(request: RefCounted) -> Dictionary:
		ask_calls += 1
		return super(request)

	func _begin(request: RefCounted) -> String:
		begins += 1
		last_message = request.user_message()
		return ""

	func _step() -> Dictionary:
		steps += 1
		if steps < 3 or mode == "hang":
			return {}
		if mode == "ok":
			return result(true, answer, "", tps)
		return result(false, "", mode)


func _initialize() -> void:
	_run()


func _run() -> void:
	if not _setup():
		quit(1)
		return
	await process_frame
	_tuning_checks()
	_settings_checks()
	_handshake_line_checks()
	_source_checks()
	await _line_checks()
	await _consent_checks()
	await _fallback_checks()
	await _guard_checks()
	await _demo_checks()
	await _gpu_checks()
	await _privacy_checks()
	await _layout_checks()
	await _exit_checks()
	await _leave_checks()
	await _handoff_checks()
	await _cleanup_screens()
	print("BOOT: %d checks" % _checks)
	print("BOOT RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	_teardown()
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


func _setup() -> bool:
	_tmp = OS.get_temp_dir().path_join("sigkill-boot-test-%d" % OS.get_process_id())
	if DirAccess.dir_exists_absolute(_tmp):
		print("FAIL the test's temporary folder already exists; not touching it")
		return false
	DirAccess.make_dir_recursive_absolute(_tmp)
	_fx = ProjectSettings.globalize_path(FIXTURES)
	_mark = _tmp.path_join("exec-mark")
	OS.set_environment("SIGKILL_TEST_EXEC_MARK", _mark)
	var agent_file := FileAccess.open(_tmp.path_join("agent-path"), FileAccess.WRITE)
	agent_file.store_string(LEAK_PATH + "\n")
	agent_file.close()
	_fast = load(BOOT_TUNING_PATH).duplicate()
	_fast.chars_per_second = 5000.0
	_fast.line_pause_ms = 0
	_fast.auto_continue_ms = 100
	if _server.listen(0, Detector.LOCALHOST) != OK:
		print("FAIL the fake server could not listen on 127.0.0.1")
		return false
	_port = _server.get_local_port()
	var spare := TCPServer.new()
	spare.listen(0, Detector.LOCALHOST)
	_closed_port = spare.get_local_port()
	spare.stop()
	_server_thread.start(_serve)
	return true


func _teardown() -> void:
	_server_mutex.lock()
	_server_stop = true
	_server_mutex.unlock()
	_server_thread.wait_to_finish()
	_server.stop()
	# Only what this run made, in its own fresh folder.
	for name in DirAccess.get_files_at(_tmp):
		DirAccess.remove_absolute(_tmp.path_join(name))
	DirAccess.remove_absolute(_tmp)


func _serve() -> void:
	var conns := []
	while true:
		_server_mutex.lock()
		var stop := _server_stop
		_server_mutex.unlock()
		if stop:
			break
		while _server.is_connection_available():
			conns.append({"peer": _server.take_connection(), "buf": PackedByteArray()})
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
			var text := (e["buf"] as PackedByteArray).get_string_from_ascii()
			if not text.contains("\r\n\r\n"):
				continue
			var first := text.split("\r\n")[0].split(" ")
			var path: String = first[1] if first.size() > 1 else ""
			_server_mutex.lock()
			_server_paths.append(first[0] + " " + path)
			_server_mutex.unlock()
			peer.put_data(_reply(path))
			peer.disconnect_from_host()
			conns.erase(e)
		OS.delay_usec(500)


func _reply(path: String) -> PackedByteArray:
	var body := ""
	match path:
		"/api/version":
			body = '{"version":"0.0.0-fake"}'
		"/api/tags":
			body = '{"models":[{"name":"%s","model":"%s","host":"%s","user":"%s"},{"name":"fake-model-other"}]}' % [LEAK_MODEL, LEAK_MODEL, LEAK_HOST, LEAK_USER]
		"/v1/models":
			body = '{"object":"list","data":[{"id":"%s"}]}' % LEAK_MODEL
	var status := "200 OK" if body != "" else "404 Not Found"
	var bytes := body.to_utf8_buffer()
	var out := ("HTTP/1.1 %s\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % [status, bytes.size()]).to_utf8_buffer()
	out.append_array(bytes)
	return out


func _paths_seen() -> Array:
	_server_mutex.lock()
	var out := _server_paths.duplicate()
	_server_paths.clear()
	_server_mutex.unlock()
	return out


func _found(state: Found.AgentState, agent: String, cli: bool, ollama_models: int = -1, openai_models: int = -1) -> Found:
	var f := Found.new()
	f.agent_state = state
	f.agent = agent
	f.agent_cli_present = cli
	f.ollama_reachable = ollama_models >= 0
	f.ollama_model_count = ollama_models
	f.openai_reachable = openai_models >= 0
	f.openai_model_count = openai_models
	Detector.resolve(f)
	return f


func _fake(found: Found, reading: Dictionary = {"available": false}) -> FakeDetector:
	var d := FakeDetector.new()
	d.result = found
	d.reading = reading
	return d


## The real C9 detector class, pointed only at fixtures and the fake server.
func _fixture_detector(agent_file: String, path_dir: String, ollama_port: int) -> Detector:
	var d := Detector.new()
	d.agent_file_path = agent_file
	d.path_dirs = PackedStringArray([_fx.path_join("path").path_join(path_dir)])
	d.ollama_port = ollama_port
	d.openai_port = _closed_port
	d.http_timeout_ms = 500
	d.sysfs_root = _fx.path_join("sysfs")
	d.nvidia_smi_path = _fx.path_join("path").path_join("empty").path_join("nvidia-smi")
	return d


func _save(file: String, source: String, allowed: bool) -> void:
	Settings.save(source, allowed, _tmp.path_join(file))


## Starts a boot screen. `spec` null: no adapter factory; {} a factory that finds no
## adapter, as the registry would; otherwise a stub with these fields.
func _boot(detector, spec, settings: String, extra: Dictionary = {}) -> Dictionary:
	var boot = BootScene.instantiate()
	boot.tuning = extra.get("tuning", _fast)
	boot.settings_path = _tmp.path_join(settings)
	boot.hand_off = extra.get("hand_off", false)
	boot.demo = extra.get("demo", false)
	if detector != null:
		boot.detector = detector
	var state := {"boot": boot, "stub": null, "factory_calls": 0, "done": false, "skipped": false, "frames": 0}
	if spec != null:
		boot.adapter_factory = func(_found_now, _detector_now, guide_tuning: Resource):
			state["factory_calls"] += 1
			if spec.is_empty():
				return null
			if spec.has("slow_ms"):
				OS.delay_msec(spec["slow_ms"])  # a slow PATH lookup, on the adapter worker
			var stub := StubAdapter.new(guide_tuning)
			for key in spec:
				if key == "timeout_ms":
					guide_tuning.agent_timeout_ms = spec[key]
				elif key != "slow_ms":
					stub.set(key, spec[key])
			state["stub"] = stub
			return stub
	boot.finished.connect(func(skipped: bool):
		state["done"] = true
		state["skipped"] = skipped)
	root.add_child(boot)
	_screens.append(boot)
	return state


func _until(condition: Callable, ms: int = WATCHDOG_MS) -> bool:
	var t0 := Time.get_ticks_msec()
	while not condition.call():
		if Time.get_ticks_msec() - t0 > ms:
			return false
		await process_frame
	return true


func _finish(state: Dictionary) -> bool:
	var frames_before := Engine.get_process_frames()
	var ok: bool = await _until(func(): return state["done"])
	state["frames"] = Engine.get_process_frames() - frames_before
	return ok


func _press(keycode: Key, ctrl: bool = false) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.pressed = true
	down.ctrl_pressed = ctrl
	Input.parse_input_event(down)
	await process_frame
	var up := down.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame


func _drop(state: Dictionary) -> void:
	var boot = state["boot"]
	if is_instance_valid(boot):
		boot.queue_free()
	await process_frame


func _answered(line: String) -> bool:
	return line.begins_with("answered in ") and line.contains(" ms") and line.trim_prefix("answered in ").get_slice(" ", 0).is_valid_int()


func _tuning_checks() -> void:
	var t: Resource = load(BOOT_TUNING_PATH)
	_check("shipped boot tuning validates", t is BootTuningScript and t.problems().is_empty(), ", ".join(t.problems()))
	var script: Script = load("res://scripts/boot/boot_tuning.gd")
	var text := FileAccess.get_file_as_string(BOOT_TUNING_PATH)
	var missing := PackedStringArray()
	for prop in script.get_script_property_list():
		if prop["usage"] & PROPERTY_USAGE_STORAGE and prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE and not text.contains("\n" + prop["name"] + " = "):
			missing.append(prop["name"])
	_check("boot.tres lists every tunable of boot_tuning.gd", missing.is_empty(), ", ".join(missing))
	var bad: Resource = t.duplicate()
	bad.chars_per_second = 0.0
	bad.gpu_interval_ms = 10
	bad.auto_continue_ms = -1
	bad.line_font_size = 500
	bad.hint_alpha = 2.0
	_check("validation refuses a stalled typer, a GPU read faster than once a second, a negative wait, a huge font and an opacity over 1", bad.problems().size() == 5, ", ".join(bad.problems()))
	_check("a screen given bad tuning falls back to the shipped tuning", Boot.usable_tuning(bad) == t)


func _settings_checks() -> void:
	var path := _tmp.path_join("settings-helper.cfg")
	_check("no settings file: never asked", Settings.answer_for("claude", path) == Settings.Answer.NOT_ASKED)
	_check("a yes for claude is saved and read back, and counts for claude only", Settings.save("claude", true, path) and Settings.answer_for("claude", path) == Settings.Answer.ALLOWED and Settings.answer_for("codex", path) == Settings.Answer.NOT_ASKED and Settings.answer_for("ollama", path) == Settings.Answer.NOT_ASKED)
	_check("a no is saved and read back", Settings.save("ollama", false, path) and Settings.answer_for("ollama", path) == Settings.Answer.DECLINED and Settings.answer_for("claude", path) == Settings.Answer.NOT_ASKED)
	_check("an answer about an unknown source, or into the project, is refused and nothing is written", not Settings.save("fake-host-01", true, path) and not Settings.save("claude", true, "res://settings.cfg") and Settings.answer_for("ollama", path) == Settings.Answer.DECLINED)
	var damaged := {
		"binary": PackedByteArray([0x61, 0x69, 0x00, 0xFF, 0x0A]),
		"twice": "ai_consent_source=claude\nai_consent=yes\nai_consent=no\n".to_ascii_buffer(),
		"value": "ai_consent_source=claude\nai_consent=maybe\n".to_ascii_buffer(),
		"source": ("ai_consent_source=%s\nai_consent=yes\n" % LEAK_PATH).to_ascii_buffer(),
		"half": "ai_consent_source=claude\n".to_ascii_buffer(),
		"oversized": ("ai_consent_source=claude\nai_consent=yes\n#" + "x".repeat(5000) + "\n").to_ascii_buffer(),
	}
	var bad := PackedStringArray()
	for name in damaged:
		var file_path := _tmp.path_join("damaged-" + name + ".cfg")
		var file := FileAccess.open(file_path, FileAccess.WRITE)
		file.store_buffer(damaged[name])
		file.close()
		if Settings.answer_for("claude", file_path) != Settings.Answer.NOT_ASKED:
			bad.append(name)
	_check("a damaged settings file counts as never asked, quietly: binary, a key twice, a bad value, an unknown source, half a file, oversized", bad.is_empty(), ", ".join(bad))


func _handshake_line_checks() -> void:
	var exact := PackedStringArray()
	for line in Boot.HANDSHAKE_LINES:
		if Boot.handshake_line(line) != line or not Boot.HANDSHAKE_TEXT.contains(line):
			exact.append(line)
	_check("every handshake line is named in the fixed prompt and matches itself", exact.is_empty() and Boot.HANDSHAKE_LINES.has(Boot.DEMO_ANSWER), ", ".join(exact))
	_check("quotes, markdown marks, letter case, extra spaces and later lines around a picked line are ignored", Boot.handshake_line("  \"online.   DAEMONS beware.\"  \nand a second line") == "Online. Daemons beware." and Boot.handshake_line("**Link up. Ready to hunt.**") == "Link up. Ready to hunt." and Boot.handshake_line("> Linked. Let's clear this arena.") == "Linked. Let's clear this arena.")
	var shown := PackedStringArray()
	for text in ["Welcome %s on %s. I am %s." % [LEAK_USER_WORD, LEAK_HOST_WORD, LEAK_MODEL_WORD], "Link up. Ready to hunt, %s." % LEAK_USER_WORD, "Online on %s." % LEAK_HOST_WORD, "I am %s." % LEAK_MODEL_WORD, LEAK_PATH, "", "Link up. Ready to hunt. Also, hello."]:
		if Boot.handshake_line(text) != "":
			shown.append(text)
	_check("anything else is no handshake line at all: names of people, machines and models, paths, empty, extra words", shown.is_empty(), ", ".join(shown))


## Source with its comments cut off, so a scan sees code, not the notes explaining it.
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


func _source_checks() -> void:
	var source := _code("res://scripts/boot/boot_sequence.gd") + _code("res://scripts/boot/guide_settings.gd") + _code("res://scripts/boot/boot_tuning.gd")
	var found := PackedStringArray()
	for word in SOURCE_NEVER:
		if source.contains(word):
			found.append(word)
	_check("the boot screen starts no program, opens no socket and stops nothing itself", found.is_empty(), ", ".join(found))
	var boot := _code("res://scripts/boot/boot_sequence.gd")
	_check("the registry is asked in one place, on the adapter worker, after the headless guard has returned", boot.count("adapter_for(") == 1 and boot.contains("\t\tif guarded:\n\t\t\treturn\n\t\tadapter = RegistryScript.adapter_for(found, detector, tuning)") and boot.contains("_adapter_thread.start(_adapter_job.run)"))
	_check("a real detector is made in one place, only when not guarded", boot.count("Detector.new()") == 1 and boot.contains("\tif detector == null and not _guarded:\n\t\tdetector = Detector.new()"))
	_check("the AI switch is set in one place, on the screen's own copy, right before the one ask", boot.count("ai_enabled = true") == 1 and boot.contains("\t_guide_tuning.ai_enabled = true\n\tvar started: Dictionary = _adapter.ask(") and boot.count(".ask(") == 1)


func _line_checks() -> void:
	_save("lines.cfg", "claude", true)
	var s := _boot(_fake(_found(Found.AgentState.KNOWN, "claude", true)), {"name": "claude"}, "lines.cfg")
	var ok: bool = await _finish(s)
	var lines: PackedStringArray = s["boot"].lines()
	var stub = s["stub"]
	_check("default agent found: title, agent line with Linking..., the answer, its latency, then the arena", ok and lines.size() == 5 and lines[0] == "SIGKILL boot" and lines[1] == "Omarchy default agent: claude. Linking..." and lines[2] == "> " + STUB_ANSWER and _answered(lines[3]) and lines[4] == Boot.LEAVING_LINE, str(lines))
	_check("the handshake is one ask with the fixed prompt and no player data", stub != null and stub.ask_calls == 1 and stub.begins == 1 and stub.last_message == Request.build({}, Boot.HANDSHAKE_TEXT, 500).user_message() and stub.last_message.begins_with("Game stats: none\n"), stub.last_message.c_escape() if stub != null else "")
	await _drop(s)
	var cases := [
		["unknown agent", _found(Found.AgentState.UNKNOWN, "", false), ["SIGKILL boot", "Omarchy default agent: not one SIGKILL knows.", Boot.SCRIPTED_LINE, Boot.LEAVING_LINE]],
		["unset", _found(Found.AgentState.UNSET, "", false), ["SIGKILL boot", "Omarchy default agent: not set.", Boot.SCRIPTED_LINE, Boot.LEAVING_LINE]],
		["nothing found", _found(Found.AgentState.UNSET, "", false, 0, 0), ["SIGKILL boot", "Omarchy default agent: not set.", Boot.SCRIPTED_LINE, Boot.LEAVING_LINE]],
		["agent not installed", _found(Found.AgentState.KNOWN, "claude", false), ["SIGKILL boot", "Omarchy default agent: claude, but its command is not installed.", Boot.SCRIPTED_LINE, Boot.LEAVING_LINE]],
	]
	for c in cases:
		var run := _boot(_fake(c[1]), {}, "lines.cfg")
		var finished: bool = await _finish(run)
		var got: PackedStringArray = run["boot"].lines()
		_check("%s: %s" % [c[0], c[2][1]], finished and Array(got) == c[2], str(got))
		await _drop(run)
	_save("local.cfg", "ollama", true)
	var local := _boot(_fake(_found(Found.AgentState.UNSET, "", false, 2)), {"name": "local", "kind": "ollama", "tps": 42.5}, "local.cfg")
	var local_ok: bool = await _finish(local)
	var local_lines: PackedStringArray = local["boot"].lines()
	_check("local server loaded: the local line, the answer, latency and tokens per second", local_ok and local_lines.size() == 6 and local_lines[1] == "Omarchy default agent: not set." and local_lines[2] == Boot.LOCAL_LINE and local_lines[3] == "> " + STUB_ANSWER and _answered(local_lines[4]) and local_lines[4].ends_with(", 42.5 tok/s"), str(local_lines))
	await _drop(local)
	var empty := _boot(_fake(_found(Found.AgentState.UNSET, "", false, 2)), {"name": "local", "kind": "ollama", "mode": "needs_consent"}, "local.cfg")
	var empty_ok: bool = await _finish(empty)
	var empty_lines: PackedStringArray = empty["boot"].lines()
	_check("local server with nothing loaded: says so, then the scripted guide; asked once, never told to load", empty_ok and Array(empty_lines) == ["SIGKILL boot", "Omarchy default agent: not set.", Boot.LOCAL_LINE, Boot.NOT_LOADED_LINE, Boot.SCRIPTED_LINE, Boot.LEAVING_LINE] and empty["stub"].ask_calls == 1, str(empty_lines))
	await _drop(empty)
	_save("gemini.cfg", "ollama", true)
	var gemini := _boot(_fake(_found(Found.AgentState.KNOWN, "gemini", true, 1)), {"name": "local", "kind": "ollama"}, "gemini.cfg")
	var gemini_ok: bool = await _finish(gemini)
	var gemini_lines: PackedStringArray = gemini["boot"].lines()
	_check("an agent with no SIGKILL adapter says so and falls through to the local server", gemini_ok and gemini_lines[1] == "Omarchy default agent: gemini. No SIGKILL adapter for it yet." and gemini_lines[2] == Boot.LOCAL_LINE, str(gemini_lines))
	await _drop(gemini)


func _consent_checks() -> void:
	var claude := _found(Found.AgentState.KNOWN, "claude", true)
	var s := _boot(_fake(claude), {"name": "claude"}, "consent.cfg")
	var asking: bool = await _until(func(): return s["boot"].is_waiting_for_consent())
	for i in 120:
		await process_frame
	var lines: PackedStringArray = s["boot"].lines()
	_check("first launch: it names the agent and what it gets, then waits for Y or N without calling", asking and lines.has("Allow SIGKILL to call claude? It gets only game stats and what you type.") and lines.has(Boot.CONSENT_KEYS) and s["stub"].ask_calls == 0 and not s["done"], str(lines))
	await _press(KEY_Y, true)
	await _press(KEY_N, true)
	_check("Y or N with Ctrl held is ignored: still waiting, nothing saved", s["boot"].is_waiting_for_consent() and Settings.answer_for("claude", _tmp.path_join("consent.cfg")) == Settings.Answer.NOT_ASKED)
	await _press(KEY_N)
	var no_ok: bool = await _finish(s)
	var after: PackedStringArray = s["boot"].lines()
	_check("N keeps the AI off: no call, the scripted guide, and the no is saved", no_ok and s["stub"].ask_calls == 0 and after.has("AI kept off.") and after.has(Boot.SCRIPTED_LINE) and Settings.answer_for("claude", _tmp.path_join("consent.cfg")) == Settings.Answer.DECLINED, str(after))
	await _drop(s)
	var again := _boot(_fake(claude), {"name": "claude"}, "consent.cfg")
	var again_ok: bool = await _finish(again)
	var again_lines: PackedStringArray = again["boot"].lines()
	_check("the next launch remembers the no: no question, no call", again_ok and again["stub"].ask_calls == 0 and again_lines.has("You said no to the AI link.") and not again_lines.has(Boot.CONSENT_KEYS), str(again_lines))
	await _drop(again)
	var yes := _boot(_fake(claude), {"name": "claude"}, "consent-yes.cfg")
	await _until(func(): return yes["boot"].is_waiting_for_consent())
	await _press(KEY_Y)
	var yes_ok: bool = await _finish(yes)
	var yes_lines: PackedStringArray = yes["boot"].lines()
	_check("Y allows it: saved, then one handshake and its answer", yes_ok and yes["stub"].ask_calls == 1 and yes_lines.has("Allowed.") and yes_lines.has("> " + STUB_ANSWER) and Settings.answer_for("claude", _tmp.path_join("consent-yes.cfg")) == Settings.Answer.ALLOWED, str(yes_lines))
	await _drop(yes)
	_save("consent-codex.cfg", "codex", true)
	var other := _boot(_fake(claude), {"name": "claude"}, "consent-codex.cfg")
	var other_asks: bool = await _until(func(): return other["boot"].is_waiting_for_consent())
	_check("a yes for codex does not cover claude: asked again, no call yet", other_asks and other["stub"].ask_calls == 0)
	await _press(KEY_ESCAPE)
	var skipped: bool = await _finish(other)
	_check("Esc at the question skips to the arena: no call, and the answer is not changed", skipped and other["skipped"] and other["stub"].ask_calls == 0 and Settings.answer_for("claude", _tmp.path_join("consent-codex.cfg")) == Settings.Answer.NOT_ASKED)
	await _drop(other)
	_save("local-consent.cfg", "claude", true)
	var local := _boot(_fake(_found(Found.AgentState.UNSET, "", false, 3)), {"name": "local", "kind": "ollama"}, "local-consent.cfg")
	await _until(func(): return local["boot"].is_waiting_for_consent())
	_check("the local server is asked about too, by name, with what it gets", local["boot"].lines().has("Allow SIGKILL to call the local model server? It gets only game stats and what you type.") and local["stub"].ask_calls == 0)
	await _press(KEY_ENTER)
	await _finish(local)
	await _drop(local)


func _fallback_checks() -> void:
	var claude := _found(Found.AgentState.KNOWN, "claude", true)
	_save("fallback.cfg", "claude", true)
	for c in [["agent_error", "agent_error"], ["timeout", "timeout"], ["Bad/Kind", "error"]]:
		var s := _boot(_fake(claude), {"name": "claude", "mode": c[0]}, "fallback.cfg")
		var ok: bool = await _finish(s)
		var lines: PackedStringArray = s["boot"].lines()
		_check("a stub %s falls back to the scripted line" % c[0], ok and lines.has("No answer from claude (%s)." % c[1]) and lines.has(Boot.SCRIPTED_LINE) and not lines.has("> " + STUB_ANSWER), str(lines))
		await _drop(s)
	var t0 := Time.get_ticks_msec()
	var hung := _boot(_fake(claude), {"name": "claude", "mode": "hang", "timeout_ms": 1000}, "fallback.cfg")
	var hung_ok: bool = await _finish(hung)
	var waited := Time.get_ticks_msec() - t0
	_check("a stub that never answers hits the guide timeout, falls back, and the screen never hangs", hung_ok and hung["boot"].lines().has("No answer from claude (timeout).") and waited >= 1000 and waited < WATCHDOG_MS, "%d ms" % waited)
	await _drop(hung)


func _guard_checks() -> void:
	var guarded := _boot(null, null, "guard-none.cfg", {"hand_off": false})
	var none_ok: bool = await _finish(guarded)
	_check("headless with nothing handed in: guarded, no detector made, no adapter, straight on", none_ok and guarded["boot"].is_guarded() and guarded["boot"].detector == null and guarded["boot"].adapter() == null and guarded["boot"].lines().is_empty())
	await _drop(guarded)
	_save("guard.cfg", "claude", true)
	_paths_seen()
	var real := _fixture_detector(_fx.path_join("agent").path_join("known"), "with_agent", _port)
	var s := _boot(real, null, "guard.cfg")
	var ok: bool = await _finish(s)
	var lines: PackedStringArray = s["boot"].lines()
	var seen := _paths_seen()
	print("BOOT guard: detector saw claude on the fixture PATH, consent saved yes; adapter %s; requests at the fake server %s; stub mark %s" % [s["boot"].adapter(), seen, FileAccess.file_exists(_mark)])
	_check("headless guard: a saved yes and a real-looking claude still make no adapter and say the link was skipped", ok and s["boot"].adapter() == null and Array(lines) == ["SIGKILL boot", "Omarchy default agent: claude.", "AI link skipped: headless run.", Boot.SCRIPTED_LINE, Boot.LEAVING_LINE], str(lines))
	_check("headless guard: the agent command on the PATH was never run", not FileAccess.file_exists(_mark))
	_check("headless guard: the only requests were the detector's own probes, never the adapter's", seen.size() == 2 and seen.has("GET /api/version") and seen.has("GET /api/tags"), str(seen))
	await _drop(s)
	var spy := _fake(_found(Found.AgentState.KNOWN, "claude", true, 2, 2))
	var t := _boot(spy, null, "guard.cfg")
	await _finish(t)
	_check("headless guard with a spy detector: the registry never looked the agent up", spy.finds == 0 and t["boot"].adapter() == null)
	await _drop(t)


func _demo_checks() -> void:
	var spy := _fake(_found(Found.AgentState.KNOWN, "codex", true, 3), {"available": true, "util_percent": 99, "vram_used_mib": 1, "vram_total_mib": 2, "temp_c": 3})
	var s := _boot(spy, {"name": "codex"}, "demo.cfg", {"demo": true})
	var ok: bool = await _finish(s)
	var lines: PackedStringArray = s["boot"].lines()
	var gpu: String = s["boot"].gpu_line()
	_check("demo mode: the demo agent, a canned answer and its fake latency", ok and Array(lines) == ["SIGKILL boot", "Omarchy default agent: claude. Linking...", "> " + Boot.DEMO_ANSWER, "answered in 842 ms", Boot.LEAVING_LINE], str(lines))
	_check("demo mode: fake GPU numbers", gpu.contains("VRAM 3072/8192 MiB") and gpu.ends_with("58 C") and gpu.begins_with("GPU "), gpu)
	_check("demo mode: zero detector reads, zero adapters, zero settings", spy.starts == 0 and spy.waits == 0 and spy.gpu_count() == 0 and spy.finds == 0 and s["factory_calls"] == 0 and not FileAccess.file_exists(_tmp.path_join("demo.cfg")))
	await _drop(s)


func _gpu_checks() -> void:
	var hidden := _fake(_found(Found.AgentState.UNSET, "", false), {"available": false})
	var h := _boot(hidden, {}, "gpu.cfg")
	await _finish(h)
	_check("no GPU source: the readout stays hidden", h["boot"].gpu_line() == "" and hidden.gpu_count() >= 1)
	await _drop(h)
	var slow: Resource = _fast.duplicate()
	slow.auto_continue_ms = 5000
	var shown := _fake(_found(Found.AgentState.UNSET, "", false), {"available": true, "util_percent": 41, "vram_used_mib": 1024, "vram_total_mib": 4096, "temp_c": 61})
	var g := _boot(shown, {}, "gpu.cfg", {"tuning": slow})
	await _finish(g)
	var seconds: float = g["frames"] / 60.0
	var reads := shown.gpu_count()
	print("BOOT GPU: %d readings in %.1f s of game time" % [reads, seconds])
	_check("a GPU source: utilisation, VRAM and temperature", g["boot"].gpu_line() == "GPU 41%   VRAM 1024/4096 MiB   61 C", g["boot"].gpu_line())
	_check("GPU readings are at most once a second", seconds >= 5.0 and reads >= 3 and reads <= int(seconds) + 1, "%d in %.1f s" % [reads, seconds])
	await _drop(g)


func _privacy_checks() -> void:
	_save("privacy.cfg", "ollama", true)
	var forbidden := [LEAK_MODEL, "fake-model", LEAK_HOST, LEAK_USER, LEAK_PATH, "/fake", LEAK_USER_WORD, LEAK_HOST_WORD, LEAK_MODEL_WORD, ProjectSettings.globalize_path("res://"), _tmp]
	for env in ["HOME", "USER", "LOGNAME"]:
		var value := OS.get_environment(env)
		if value.length() > 2:
			forbidden.append(value)
	var host := FileAccess.get_file_as_string("/proc/sys/kernel/hostname").strip_edges()
	if host.length() > 2:
		forbidden.append(host)
	var answers := {
		"everything": "Running %s on %s for %s at %s" % [LEAK_MODEL, LEAK_HOST, LEAK_USER, LEAK_PATH],
		"a user name": "Welcome back, %s." % LEAK_USER_WORD,
		"a host name": "Hello from %s." % LEAK_HOST_WORD,
		"a model name": "I am %s, ready." % LEAK_MODEL_WORD,
	}
	for kind in answers:
		var real := _fixture_detector(_tmp.path_join("agent-path"), "empty", _port)
		var s := _boot(real, {"name": "local", "kind": "ollama", "answer": answers[kind]}, "privacy.cfg")
		var ok: bool = await _finish(s)
		var shown: PackedStringArray = s["boot"].screen_text()
		var leaks := PackedStringArray()
		for line in shown:
			for word in forbidden:
				if line.findn(word) >= 0:
					leaks.append(word)
		_check("an answer with %s, and the seeded setting and server, put nothing private on screen" % kind, ok and leaks.is_empty() and shown.has("> " + Boot.LINK_UP) and shown.has("Omarchy default agent: not one SIGKILL knows."), "leaks %s, lines %s" % [", ".join(leaks), str(s["boot"].lines())])
		await _drop(s)
	_paths_seen()


func _layout_checks() -> void:
	# A headless --script run starts with a 64x64 window: give it the project's own size,
	# then a small window, and check nothing is pushed off either.
	var project_size := Vector2i(ProjectSettings.get_setting("display/window/size/viewport_width"), ProjectSettings.get_setting("display/window/size/viewport_height"))
	var before := root.size
	_save("layout.cfg", "claude", true)
	var reading := {"available": true, "util_percent": 100, "vram_used_mib": 16777216, "vram_total_mib": 16777216, "temp_c": 200}
	for size in [project_size, Vector2i(960, 540)]:
		root.size = size
		var s := _boot(_fake(_found(Found.AgentState.KNOWN, "claude", true), reading), {"name": "claude", "mode": "hang"}, "layout.cfg")
		await _until(func(): return s["boot"].lines().size() >= 2 and s["boot"].gpu_line() != "")
		for i in 3:
			await process_frame
		var screen: Rect2 = s["boot"].get_viewport_rect()
		var outside := PackedStringArray()
		var shown := 0
		for label in s["boot"].find_children("*", "Label", true, false):
			if not label.is_visible_in_tree() or label.text.is_empty():
				continue
			shown += 1
			if not screen.encloses(label.get_global_rect()):
				outside.append("%s %s" % [label.text.left(24), label.get_global_rect()])
		_check("at %dx%d every line, the spinner, the widest GPU readout and the hint sit inside the screen" % [size.x, size.y], screen.size == Vector2(size) and shown >= 5 and outside.is_empty(), "%d labels; outside: %s" % [shown, ", ".join(outside)])
		await _drop(s)
	root.size = before


func _exit_checks() -> void:
	var slow := _fake(_found(Found.AgentState.UNSET, "", false), {"available": true, "util_percent": 5, "vram_used_mib": 1, "vram_total_mib": 2, "temp_c": 30})
	slow.slow_ms = 3000
	var s := _boot(slow, {}, "exit.cfg")
	var busy: bool = await _until(func(): return s["boot"].gpu_busy())
	var t0 := Time.get_ticks_msec()
	s["boot"].free()
	var took := Time.get_ticks_msec() - t0
	print("BOOT exit: a screen freed during a 3000 ms GPU reading was gone in %d ms" % took)
	_check("a screen freed mid GPU reading cancels the reader and joins its worker at once, not after the reading", busy and took < 1000 and slow.cancels >= 1 and slow.running() == 0, "%d ms" % took)


func _leftovers() -> int:
	var n := 0
	for child in root.get_children():
		if child.get_script() == Boot.Leftovers:
			n += 1
	return n


func _leave_checks() -> void:
	_save("leave.cfg", "claude", true)
	var s := _boot(_fake(_found(Found.AgentState.KNOWN, "claude", true)), {"name": "claude", "slow_ms": 2000}, "leave.cfg")
	var choosing: bool = await _until(func(): return s["boot"].is_choosing())
	var t0 := Time.get_ticks_msec()
	await _press(KEY_ENTER)
	var left: bool = await _until(func(): return s["done"], 1500)
	var took := Time.get_ticks_msec() - t0
	var t1 := Time.get_ticks_msec()
	s["boot"].free()
	var freed := Time.get_ticks_msec() - t1
	var pending := _leftovers()
	print("BOOT leave: Enter during a 2000 ms adapter lookup left in %d ms, freed in %d ms, %d worker handed on" % [took, freed, pending])
	_check("Enter while the adapter is still being chosen leaves at once and frees at once; the worker is handed on", choosing and left and s["skipped"] and took < 1000 and freed < 300 and pending == 1, "%d ms, %d ms, %d" % [took, freed, pending])
	var joined: bool = await _until(func(): return _leftovers() == 0, 5000)
	_check("the handed-on worker is joined once the slow lookup ends, and its late adapter is never asked", joined and s["factory_calls"] == 1 and s["stub"] != null and s["stub"].ask_calls == 0)


func _handoff_checks() -> void:
	var s := _boot(null, null, "handoff.cfg", {"demo": true, "hand_off": true})
	current_scene = s["boot"]
	for i in 5:
		await process_frame
	await _press(KEY_ENTER)
	var moved: bool = await _until(func(): return current_scene != null and current_scene.scene_file_path == ARENA)
	_check("Enter skips straight to the arena, and the arena loads with its player", moved and s["skipped"] and current_scene.has_node("Player") and current_scene.has_node("Hud"))
	await _free_current()
	var auto := _boot(null, null, "handoff.cfg", {"demo": true, "hand_off": true})
	current_scene = auto["boot"]
	var went: bool = await _until(func(): return current_scene != null and current_scene.scene_file_path == ARENA)
	_check("with no key pressed it continues to the arena on its own", went and auto["done"] and not auto["skipped"] and current_scene.has_node("Player"))
	await _free_current()
	var direct := _boot(null, null, "handoff.cfg", {"hand_off": true})
	current_scene = direct["boot"]
	var straight: bool = await _until(func(): return current_scene != null and current_scene.scene_file_path == ARENA)
	_check("a headless run with nothing handed in goes straight to the arena", straight)
	await _free_current()


func _free_current() -> void:
	var scene := current_scene
	if scene != null:
		scene.queue_free()
	for i in 3:
		await process_frame


func _cleanup_screens() -> void:
	for boot in _screens:
		if is_instance_valid(boot):
			boot.queue_free()
	await process_frame
