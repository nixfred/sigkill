extends SceneTree
## Headless guide HUD test for SIGKILL. scripts/check.sh runs it, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/guide_hud_test.gd
##
## Fakes only: a spy detector or the real C9 detector class pointed at tests/fixtures/ai
## and a fake model server on a random 127.0.0.1 port, and a stub adapter on the real C9b
## base (tests/support/guide_fakes.gd). The only agent command the detector could find is
## the fixtures' stub that leaves a mark if it is run. Settings live in a fresh temporary
## folder that the test removes at the end. The input-blocking checks run the real arena
## and its real player.

const Fakes = preload("res://tests/support/guide_fakes.gd")
const GuideHud = preload("res://scripts/hud/guide_hud.gd")
const HudTuningScript = preload("res://scripts/hud/hud_tuning.gd")
const Link = preload("res://scripts/guide/guide_link.gd")
const Settings = preload("res://scripts/boot/guide_settings.gd")
const Detector = preload("res://scripts/ai/ai_source_detector.gd")
const Found = preload("res://scripts/ai/ai_source_result.gd")
const Request = preload("res://scripts/ai/guide_request.gd")
const Controls = preload("res://scripts/controls.gd")
const MainScene = preload("res://scenes/main.tscn")
const HUD_TUNING_PATH := "res://resources/hud.tres"
const WATCHDOG_MS := 8000
const LEAK_MODEL := "fake-model-secret:7b"
const LEAK_HOST := "fake-host-01"
const LEAK_USER := "fakeuser"
const LEAK_PATH := "/fake/people/someone/bin/fakeagent"
const SOURCE_NEVER := ["OS.execute", "OS.create_process", "OS.kill", "OS.shell_open", "execute_with_pipe", "StreamPeerTCP", "HTTPRequest", "HTTPClient", "TCPServer", "RichTextLabel", "bbcode", "JSON.parse"]

var _fails := 0
var _checks := 0
var _tmp := ""
var _fx := ""
var _mark := ""
var _fake_now := 1000000
var _huds: Array = []

var _server := TCPServer.new()
var _server_thread := Thread.new()
var _server_mutex := Mutex.new()
var _server_stop := false
var _server_paths: Array = []
var _port := 0
var _closed_port := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	if not _setup():
		quit(1)
		return
	await process_frame
	root.size = Vector2i(1280, 720)
	_tuning_checks()
	_source_checks()
	await _badge_checks()
	await _latency_checks()
	await _gpu_checks()
	await _ask_checks()
	await _failure_checks()
	await _rate_checks()
	await _toggle_checks()
	await _guard_checks()
	await _demo_checks()
	await _privacy_checks()
	await _layout_checks()
	await _arena_checks()
	await _cleanup()
	print("HUD: %d checks" % _checks)
	print("HUD RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	_teardown()
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


func _setup() -> bool:
	_tmp = OS.get_temp_dir().path_join("sigkill-hud-test-%d" % OS.get_process_id())
	if DirAccess.dir_exists_absolute(_tmp):
		print("FAIL the test's temporary folder already exists; not touching it")
		return false
	DirAccess.make_dir_recursive_absolute(_tmp)
	Controls.ensure()
	_fx = ProjectSettings.globalize_path("res://tests/fixtures/ai")
	_mark = _tmp.path_join("exec-mark")
	OS.set_environment("SIGKILL_TEST_EXEC_MARK", _mark)
	var agent_file := FileAccess.open(_tmp.path_join("agent-path"), FileAccess.WRITE)
	agent_file.store_string(LEAK_PATH + "\n")
	agent_file.close()
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
			var body := ""
			match path:
				"/api/version":
					body = '{"version":"0.0.0-fake"}'
				"/api/tags":
					body = '{"models":[{"name":"%s","model":"%s","host":"%s","user":"%s"}]}' % [LEAK_MODEL, LEAK_MODEL, LEAK_HOST, LEAK_USER]
			var bytes := body.to_utf8_buffer()
			var out := ("HTTP/1.1 %s\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % ["200 OK" if body != "" else "404 Not Found", bytes.size()]).to_utf8_buffer()
			out.append_array(bytes)
			peer.put_data(out)
			peer.disconnect_from_host()
			conns.erase(e)
		OS.delay_usec(500)


func _paths_seen() -> Array:
	_server_mutex.lock()
	var out := _server_paths.duplicate()
	_server_paths.clear()
	_server_mutex.unlock()
	return out


func _now() -> int:
	return _fake_now


func _found(state: Found.AgentState, agent: String, cli: bool, ollama_models: int = -1) -> Found:
	var f := Found.new()
	f.agent_state = state
	f.agent = agent
	f.agent_cli_present = cli
	f.ollama_reachable = ollama_models >= 0
	f.ollama_model_count = ollama_models
	Detector.resolve(f)
	return f


func _fake(found: Found, reading: Dictionary = {"available": false}) -> Fakes.FakeDetector:
	var d := Fakes.FakeDetector.new()
	d.result = found
	d.reading = reading
	return d


## A started link with a fake detector and, unless spec is null, a stub adapter from a
## factory, as the registry would give. holder["stub"] is the stub once made.
func _link(detector, spec, settings: String, holder: Dictionary = {}) -> Link:
	var link := Link.new()
	link.detector = detector
	link.settings_path = _tmp.path_join(settings)
	if spec != null:
		link.adapter_factory = func(_f, _d, guide_tuning: Resource):
			var stub := Fakes.StubAdapter.new(guide_tuning)
			for key in spec:
				if key == "timeout_ms":
					guide_tuning.agent_timeout_ms = spec[key]
				else:
					stub.set(key, spec[key])
			stub.rate_clock = _now
			holder["stub"] = stub
			return stub
	link.start()
	return link


func _hud(link: Link, extra: Dictionary = {}) -> GuideHud:
	var hud := GuideHud.new()
	hud.tuning = extra.get("tuning", null)
	hud.link = link
	hud.focus_check = extra.get("focus", func(): return false)
	if extra.has("player"):
		hud.player = extra["player"]
	root.add_child(hud)
	_huds.append(hud)
	return hud


func _until(condition: Callable, ms: int = WATCHDOG_MS) -> bool:
	var t0 := Time.get_ticks_msec()
	while not condition.call():
		if Time.get_ticks_msec() - t0 > ms:
			return false
		await process_frame
	return true


func _ready_hud(hud: GuideHud) -> bool:
	return await _until(func(): return hud.session_link().is_ready())


func _drop(hud: GuideHud) -> void:
	if is_instance_valid(hud):
		hud.free()
	Link.take_parked()  # freeing a HUD parks its link; not wanted between checks
	await process_frame


func _key(keycode: Key, unicode: int = 0, ctrl: bool = false) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.unicode = unicode
	down.pressed = true
	down.ctrl_pressed = ctrl
	Input.parse_input_event(down)
	await process_frame
	var up := down.duplicate() as InputEventKey
	up.pressed = false
	up.unicode = 0
	Input.parse_input_event(up)
	await process_frame


func _type(text: String) -> void:
	for i in text.length():
		var c := text.unicode_at(i)
		var code: Key = KEY_SPACE if c == 0x20 else (c - 0x20 if c >= 0x61 and c <= 0x7A else c) as Key
		await _key(code, c)


func _ask(hud: GuideHud, text: String) -> void:
	await _key(KEY_T)
	await _type(text)
	await _key(KEY_ENTER)


func _answered(hud: GuideHud) -> bool:
	return await _until(func(): return not hud.is_asking() and hud.panel_text() != "")


func _tuning_checks() -> void:
	var t: Resource = load(HUD_TUNING_PATH)
	_check("shipped HUD tuning validates", t is HudTuningScript and t.problems().is_empty(), ", ".join(t.problems()))
	var script: Script = load("res://scripts/hud/hud_tuning.gd")
	var text := FileAccess.get_file_as_string(HUD_TUNING_PATH)
	var missing := PackedStringArray()
	for prop in script.get_script_property_list():
		if prop["usage"] & PROPERTY_USAGE_STORAGE and prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE and not text.contains("\n" + prop["name"] + " = "):
			missing.append(prop["name"])
	_check("hud.tres lists every tunable of hud_tuning.gd", missing.is_empty(), ", ".join(missing))
	var bad: Resource = t.duplicate()
	bad.ask_max_chars = 0
	bad.answer_max_chars = 5000
	bad.session_call_cap = 0
	bad.gpu_interval_ms = 10
	bad.panel_alpha = 3.0
	_check("validation refuses an empty ask box, a huge answer, no calls at all, a GPU read faster than once a second and an opacity over 1", bad.problems().size() == 5, ", ".join(bad.problems()))
	_check("a HUD given bad tuning falls back to the shipped tuning", GuideHud.usable_tuning(bad) == t)


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
	var hud := _code("res://scripts/hud/guide_hud.gd") + _code("res://scripts/hud/hud_tuning.gd") + _code("res://scripts/hud.gd")
	var found := PackedStringArray()
	for word in SOURCE_NEVER:
		if hud.contains(word):
			found.append(word)
	_check("the HUD starts no program, opens no socket and never parses rich text", found.is_empty(), ", ".join(found))
	var own := _code("res://scripts/hud/guide_hud.gd")
	_check("the HUD calls the AI in one place, through the link, with the request builder", own.count(".ask(") == 1 and own.contains("_link.ask(Request.build(game_stats(), text, cap))") and own.count("adapter_for(") == 0 and own.count("Detector.new()") == 0)
	_check("the answer is shown through the adapter's clean_answer, in a plain Label", own.contains("Adapter.clean_answer(text.to_utf8_buffer(), _t.answer_max_chars)") and own.contains("var _body: Label"))
	var keys := FileAccess.get_file_as_string("res://scripts/controls.gd")
	_check("T and O are plain keys in the input map", keys.contains("_key(\"ask_ai\", [KEY_T])") and keys.contains("_key(\"toggle_ai\", [KEY_O])"))


func _badge_checks() -> void:
	var cases := [
		["claude, allowed", _found(Found.AgentState.KNOWN, "claude", true), {"name": "claude"}, ["claude", true], "your AI: claude"],
		["codex, allowed", _found(Found.AgentState.KNOWN, "codex", true), {"name": "codex"}, ["codex", true], "your AI: codex"],
		["a local server, allowed", _found(Found.AgentState.UNSET, "", false, 2), {"name": "local", "kind": "ollama"}, ["ollama", true], "your AI: local"],
		["claude, said no", _found(Found.AgentState.KNOWN, "claude", true), {"name": "claude"}, ["claude", false], "AI off"],
		["claude, never asked", _found(Found.AgentState.KNOWN, "claude", true), {"name": "claude"}, [], "AI off"],
		["nothing found", _found(Found.AgentState.UNSET, "", false), {}, [], "AI off"],
	]
	for i in cases.size():
		var c: Array = cases[i]
		var settings := "badge-%d.cfg" % i
		if not c[3].is_empty():
			Settings.save(c[3][0], c[3][1], _tmp.path_join(settings))
		var spec = null if c[2].is_empty() else c[2]
		var hud := _hud(_link(_fake(c[1]), spec, settings))
		await _ready_hud(hud)
		await process_frame
		_check("badge, %s: %s" % [c[0], c[4]], hud.badge_text() == c[4], hud.badge_text())
		await _drop(hud)
	var slow := _fake(_found(Found.AgentState.KNOWN, "claude", true))
	slow.done = false
	var linking := _hud(_link(slow, {"name": "claude"}, "badge-0.cfg"))
	for i in 3:
		await process_frame
	_check("badge while the detector is still working: your AI: linking...", linking.badge_text() == "your AI: linking...", linking.badge_text())
	await _drop(linking)


func _latency_checks() -> void:
	Settings.save("ollama", true, _tmp.path_join("latency-local.cfg"))
	Settings.save("claude", true, _tmp.path_join("latency-claude.cfg"))
	var cases := [
		["the local server, with a reported count", _found(Found.AgentState.UNSET, "", false, 2), {"name": "local", "kind": "ollama", "tps": 42.5}, "latency-local.cfg", true],
		["the local server, with no count", _found(Found.AgentState.UNSET, "", false, 2), {"name": "local", "kind": "ollama", "tps": -1.0}, "latency-local.cfg", false],
		["an agent, even with a number", _found(Found.AgentState.KNOWN, "claude", true), {"name": "claude", "tps": 30.0}, "latency-claude.cfg", false],
	]
	for c in cases:
		var hud := _hud(_link(_fake(c[1]), c[2], c[3]))
		await _ready_hud(hud)
		_check("before any call there is no latency line", hud.latency_text() == "")
		await _ask(hud, "tips")
		await _answered(hud)
		var line := hud.latency_text()
		var shows_rate := line.contains("tok/s")
		_check("latency after a call from %s; tok/s %s" % [c[0], "shown" if c[4] else "hidden"], line.begins_with("last call ") and line.contains(" ms") and shows_rate == c[4] and (not c[4] or line.ends_with("42.5 tok/s")), line)
		await _drop(hud)


func _gpu_checks() -> void:
	var hidden := _fake(_found(Found.AgentState.UNSET, "", false), {"available": false})
	var h := _hud(_link(hidden, null, "gpu.cfg"))
	await _ready_hud(h)
	for i in 10:
		await process_frame
	_check("no GPU source: the GPU line stays hidden", h.gpu_text() == "" and hidden.gpu_count() >= 1)
	await _drop(h)
	var shown := _fake(_found(Found.AgentState.UNSET, "", false), {"available": true, "util_percent": 41, "vram_used_mib": 1024, "vram_total_mib": 4096, "temp_c": 61})
	var g := _hud(_link(shown, null, "gpu.cfg"))
	await _ready_hud(g)
	var frames := 300
	for i in frames:
		await process_frame
	var reads := shown.gpu_count()
	print("HUD GPU: %d readings in %.1f s of game time" % [reads, frames / 60.0])
	_check("a GPU source: utilisation, VRAM and temperature", g.gpu_text() == "GPU 41%   VRAM 1024/4096 MiB   61 C", g.gpu_text())
	_check("GPU readings are at most once a second", reads >= 3 and reads <= frames / 60 + 1, "%d" % reads)
	await _drop(g)


func _ask_checks() -> void:
	Settings.save("claude", true, _tmp.path_join("ask.cfg"))
	var holder := {}
	var player := _spy_player()
	var esc := char(27)
	var long_answer := "[b]bold[/b] [color=red]red[/color] " + esc + "[31mansi" + esc + "[0m ctrl" + char(1) + char(7) + " end\n" + "x".repeat(2000)
	var hud := _hud(_link(_fake(_found(Found.AgentState.KNOWN, "claude", true)), {"name": "claude", "answer": long_answer}, "ask.cfg", holder), {"player": player})
	await _ready_hud(hud)
	await _key(KEY_T)
	_check("T opens the ask box, frees the player's input lock only when it closes", hud.is_typing() and player.input_blocked and hud.status_text() == GuideHud.TYPING_LINE)
	await _type("where do i stand")
	await _key(KEY_ENTER)
	var stub = holder.get("stub")
	_check("Enter sends one ask with what was typed and whitelisted game stats only", stub != null and stub.ask_calls == 1 and stub.last_message.ends_with("Player: where do i stand") and Request.STATS.has_all(stub.last_stats.keys()) and stub.last_stats.has("round_seconds") and not player.input_blocked and not hud.is_typing(), str(stub.last_stats.keys()) if stub != null else "no stub")
	await _answered(hud)
	var body = hud.answer_label()
	var text: String = body.text
	_check("the answer is labelled as the player's AI", hud.panel_text().begins_with("your AI (claude) says:"), hud.panel_text().get_slice("\n", 0))
	_check("the answer shows BBCode as plain text in a Label: nothing parsed", body is Label and not (body is RichTextLabel) and text.contains("[b]bold[/b]") and text.contains("[color=red]red[/color]"))
	_check("escape sequences and control characters are stripped", not text.contains(esc) and not text.contains(char(1)) and not text.contains(char(7)) and text.contains("ansi") and not text.contains("[31m"), text.left(60).c_escape())
	_check("an over-long answer is cut to answer_max_chars", text.length() <= 420 and text.length() > 300, "%d chars" % text.length())
	await _drop(hud)
	var lines_holder := {}
	_fake_now += 60000
	var many := "\n".join(PackedStringArray(["one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]))
	var hud2 := _hud(_link(_fake(_found(Found.AgentState.KNOWN, "claude", true)), {"name": "claude", "answer": many}, "ask.cfg", lines_holder))
	await _ready_hud(hud2)
	await _ask(hud2, "hi")
	await _answered(hud2)
	_check("an answer with many lines is cut to answer_max_lines", hud2.answer_label().text.split("\n").size() == 6 and hud2.answer_label().text.ends_with("six"), hud2.answer_label().text.c_escape())
	await _drop(hud2)
	var cancel_holder := {}
	var spy := _spy_player()
	var hud3 := _hud(_link(_fake(_found(Found.AgentState.KNOWN, "claude", true)), {"name": "claude"}, "ask.cfg", cancel_holder), {"player": spy})
	await _ready_hud(hud3)
	await _key(KEY_T)
	await _type("never mind")
	await _key(KEY_ESCAPE)
	_check("Esc cancels: no call, the box closes and the player's input comes back", not hud3.is_typing() and not spy.input_blocked and (cancel_holder.get("stub") == null or cancel_holder["stub"].ask_calls == 0))
	await _key(KEY_T)
	await _key(KEY_ENTER)
	_check("an empty question sends nothing", not hud3.is_asking() and (cancel_holder.get("stub") == null or cancel_holder["stub"].ask_calls == 0))
	await _drop(hud3)


func _spy_player() -> Node:
	var script := GDScript.new()
	script.source_code = "extends Node\nvar input_blocked := false\nvar assume_captured := true\nvar shots_fired := 7\nvar hits_landed := 3\n"
	script.reload()
	var spy := Node.new()
	spy.set_script(script)
	root.add_child(spy)
	_huds.append(spy)
	return spy


func _failure_checks() -> void:
	Settings.save("claude", true, _tmp.path_join("fail.cfg"))
	for c in [["timeout", "No answer from your AI (timeout). The scripted guide is still here."], ["agent_error", "No answer from your AI (agent_error). The scripted guide is still here."], ["Bad/Kind", "No answer from your AI (error). The scripted guide is still here."]]:
		_fake_now += 60000
		var hud := _hud(_link(_fake(_found(Found.AgentState.KNOWN, "claude", true)), {"name": "claude", "mode": c[0]}, "fail.cfg"))
		await _ready_hud(hud)
		await _ask(hud, "help")
		await _answered(hud)
		_check("a stub %s shows the fixed SIGKILL line" % c[0], hud.panel_text() == "SIGKILL\n" + c[1] and hud.latency_text().contains("(%s)" % ("error" if c[0] == "Bad/Kind" else c[0])), hud.panel_text().c_escape())
		await _drop(hud)
	_fake_now += 60000
	var t0 := Time.get_ticks_msec()
	var hung := _hud(_link(_fake(_found(Found.AgentState.KNOWN, "claude", true)), {"name": "claude", "mode": "hang", "timeout_ms": 1000}, "fail.cfg"))
	await _ready_hud(hung)
	await _ask(hung, "help")
	var spun: bool = await _until(func(): return hung.status_text().begins_with("thinking"))
	var done: bool = await _answered(hung)
	var waited := Time.get_ticks_msec() - t0
	_check("a stub that never answers: the spinner runs, then the guide timeout gives the fixed line, never a hang", spun and done and hung.panel_text().contains("(timeout)") and waited >= 1000 and waited < WATCHDOG_MS, "%d ms" % waited)
	await _drop(hung)
	Settings.save("ollama", true, _tmp.path_join("fail-local.cfg"))
	var empty_holder := {}
	var empty := _hud(_link(_fake(_found(Found.AgentState.UNSET, "", false, 1)), {"name": "local", "kind": "ollama", "mode": "needs_consent"}, "fail-local.cfg", empty_holder))
	await _ready_hud(empty)
	await _ask(empty, "help")
	await _answered(empty)
	_check("a local server with nothing loaded says so and loads nothing", empty.panel_text() == "SIGKILL\n" + GuideHud.NOT_LOADED_LINE)
	_fake_now += 60000
	await _until(func(): return empty.panel_text() == "")
	await process_frame
	_check("\"available, not loaded\" stays on the status line after the panel is gone", empty.panel_text() == "" and empty.status_text() == GuideHud.NOT_LOADED_LINE and empty.badge_text() == "your AI: local", empty.status_text())
	empty_holder["stub"].mode = "ok"
	await _ask(empty, "again")
	await _answered(empty)
	_check("T checks again, and once a model answers the line goes", empty.status_text() != GuideHud.NOT_LOADED_LINE and empty.panel_text().begins_with("your AI (local) says:"), empty.status_text())
	await _drop(empty)
	# The empty server's answer used the session's last call: both facts stay on screen.
	var last: Resource = load(HUD_TUNING_PATH).duplicate()
	last.session_call_cap = 1
	_fake_now += 60000
	var capped := _hud(_link(_fake(_found(Found.AgentState.UNSET, "", false, 1)), {"name": "local", "kind": "ollama", "mode": "needs_consent"}, "fail-local.cfg"), {"tuning": last})
	await _ready_hud(capped)
	await _ask(capped, "help")
	await _answered(capped)
	await _until(func(): return capped.panel_text() == "")
	var before := root.size
	root.size = Vector2i(960, 540)
	for i in 3:
		await process_frame
	var status_rect: Rect2 = capped._status.get_global_rect()
	var fits := Rect2(Vector2.ZERO, Vector2(root.size)).encloses(status_rect)
	_check("when that answer used the last call, \"not loaded\" and \"limit reached\" both stay, and fit at 960x540", capped.status_text() == GuideHud.NOT_LOADED_LINE + "   Limit reached: 1 AI call this session." and fits, "%s %s" % [capped.status_text(), status_rect])
	root.size = before
	await _drop(capped)
	# The boot handshake's "not loaded" carries into the arena on the same link.
	var carried := _link(_fake(_found(Found.AgentState.UNSET, "", false, 1)), {"name": "local", "kind": "ollama"}, "fail-local.cfg")
	carried.not_loaded = true
	var shown := _hud(carried)
	await _ready_hud(shown)
	await process_frame
	_check("a not-loaded answer from the boot handshake shows in the arena", shown.status_text() == GuideHud.NOT_LOADED_LINE)
	await _drop(shown)
	# A save that fails still holds for the session: off stays off, on stays on.
	var unsaved := Link.new()
	unsaved.detector = _fake(_found(Found.AgentState.KNOWN, "claude", true))
	unsaved.settings_path = "not-a-usable-path.cfg"
	unsaved.adapter_factory = func(_f, _d, guide_tuning: Resource): return Fakes.StubAdapter.new(guide_tuning)
	unsaved.start()
	await _until(func():
		unsaved.poll(16.0)
		return unsaved.is_ready())
	var saved_on := unsaved.set_consent(true)
	var on_now := unsaved.ai_on()
	var saved_off := unsaved.set_consent(false)
	_check("an answer that cannot be saved still holds for the session: on, then off", not saved_on and on_now and not saved_off and not unsaved.ai_on() and unsaved.ask(Request.build({}, "x", 10))["error_kind"] == "ai_off")
	unsaved.shut_down(null)


func _rate_checks() -> void:
	Settings.save("claude", true, _tmp.path_join("rate.cfg"))
	var holder := {}
	var capped: Resource = load(HUD_TUNING_PATH).duplicate()
	capped.session_call_cap = 2
	_fake_now += 60000
	var hud := _hud(_link(_fake(_found(Found.AgentState.KNOWN, "claude", true)), {"name": "claude", "mode": "hang"}, "rate.cfg", holder), {"tuning": capped})
	await _ready_hud(hud)
	await _ask(hud, "first")
	await _key(KEY_T)
	var stub = holder["stub"]
	_check("one call in flight: T while it runs is refused and says so, no second call", stub.ask_calls == 1 and not hud.is_typing() and hud.panel_text() == "SIGKILL\n" + GuideHud.BUSY_LINE and hud.status_text().begins_with("thinking"))
	stub.mode = "ok"
	await _answered(hud)
	await _key(KEY_T)
	_check("the minimum interval: T is refused with the time left, shown on the status line too", not hud.is_typing() and hud.panel_text() == "SIGKILL\nNext ask in 10 s." and hud.status_text() == "Next ask in 10 s." and stub.ask_calls == 1, hud.panel_text().c_escape())
	_fake_now += 9500
	await process_frame
	_check("the cooldown counts down", hud.status_text() == "Next ask in 1 s.", hud.status_text())
	_fake_now += 600
	await process_frame
	await _ask(hud, "second")
	await _answered(hud)
	_fake_now += 20000
	await process_frame
	await _key(KEY_T)
	_check("the session cap: after 2 calls T says the limit is reached, on the status line too", stub.ask_calls == 2 and not hud.is_typing() and hud.panel_text() == "SIGKILL\nLimit reached: 2 AI calls this session." and hud.status_text() == "Limit reached: 2 AI calls this session.", "%d calls; %s" % [stub.ask_calls, hud.status_text()])
	await _drop(hud)


func _toggle_checks() -> void:
	var path := _tmp.path_join("toggle.cfg")
	Settings.save("claude", true, path)
	var holder := {}
	_fake_now += 60000
	var hud := _hud(_link(_fake(_found(Found.AgentState.KNOWN, "claude", true)), {"name": "claude", "mode": "hang"}, "toggle.cfg", holder))
	await _ready_hud(hud)
	await _ask(hud, "running")
	var stub = holder["stub"]
	await _key(KEY_O)
	_check("O turns the AI off: badge AI off, the no is saved, the call in flight is stopped", hud.badge_text() == "AI off" and Settings.answer_for("claude", path) == Settings.Answer.DECLINED and stub.cancels >= 1 and not hud.is_asking())
	_fake_now += 60000
	await _key(KEY_T)
	_check("with the AI off, T says so and calls nothing", not hud.is_typing() and hud.panel_text() == "SIGKILL\n" + GuideHud.OFF_LINE and stub.ask_calls == 1)
	await _key(KEY_O)
	_check("O with the AI off asks first, by name, with what it gets", hud.is_asking_consent() and hud.panel_text().contains("Allow SIGKILL to call claude? It gets only game stats and what you type.") and hud.status_text() == GuideHud.CONSENT_KEYS and hud.badge_text() == "AI off")
	await _key(KEY_Y, 0, true)
	_check("Ctrl+Y does not answer the question", hud.is_asking_consent() and Settings.answer_for("claude", path) == Settings.Answer.DECLINED)
	await _key(KEY_N)
	_check("N keeps it off", not hud.is_asking_consent() and hud.badge_text() == "AI off" and Settings.answer_for("claude", path) == Settings.Answer.DECLINED)
	await _key(KEY_O)
	await _key(KEY_ESCAPE)
	_check("Esc dismisses the question: it stays off, nothing saved", not hud.is_asking_consent() and hud.badge_text() == "AI off" and hud.panel_text() == "SIGKILL\nAI stays off." and Settings.answer_for("claude", path) == Settings.Answer.DECLINED)
	await _key(KEY_O)
	await _key(KEY_Y)
	_check("Y turns it on: saved, badge back to the agent", hud.badge_text() == "your AI: claude" and Settings.answer_for("claude", path) == Settings.Answer.ALLOWED)
	await _drop(hud)


func _guard_checks() -> void:
	var inert := GuideHud.new()
	inert.focus_check = func(): return false
	root.add_child(inert)
	_huds.append(inert)
	await process_frame
	var link := inert.session_link()
	await _key(KEY_T)
	_check("headless with nothing handed in: a guarded link, no detector, no adapter, AI off, T calls nothing", link.is_guarded() and link.detector == null and link.adapter == null and inert.badge_text() == "AI off" and inert.panel_text() == "SIGKILL\n" + GuideHud.NO_AI_LINE)
	await _drop(inert)
	Settings.save("claude", true, _tmp.path_join("guard.cfg"))
	_paths_seen()
	var real := Detector.new()
	real.agent_file_path = _fx.path_join("agent").path_join("known")
	real.path_dirs = PackedStringArray([_fx.path_join("path").path_join("with_agent")])
	real.ollama_port = _port
	real.openai_port = _closed_port
	real.http_timeout_ms = 500
	real.sysfs_root = _fx.path_join("sysfs_empty")
	real.nvidia_smi_path = _fx.path_join("path").path_join("empty").path_join("nvidia-smi")
	var guarded := Link.new()
	guarded.detector = real
	guarded.settings_path = _tmp.path_join("guard.cfg")
	guarded.start()
	var hud := _hud(guarded)
	await _ready_hud(hud)
	await _key(KEY_T)
	await _key(KEY_O)
	var seen := _paths_seen()
	print("HUD guard: claude on the fixture PATH, consent saved yes; adapter %s; requests at the fake server %s; stub mark %s" % [guarded.adapter, seen, FileAccess.file_exists(_mark)])
	_check("headless guard in the HUD: a saved yes and a real-looking claude still make no adapter; badge AI off", guarded.adapter == null and hud.badge_text() == "AI off" and guarded.found != null and guarded.found.agent == "claude")
	_check("headless guard in the HUD: T and O launch nothing and contact nothing beyond the detector's own probes", not FileAccess.file_exists(_mark) and seen.size() == 2 and seen.has("GET /api/version") and seen.has("GET /api/tags"), str(seen))
	await _drop(hud)


func _demo_checks() -> void:
	var spy := _fake(_found(Found.AgentState.KNOWN, "codex", true, 3), {"available": true, "util_percent": 99, "vram_used_mib": 1, "vram_total_mib": 2, "temp_c": 3})
	var link := Link.new()
	link.detector = spy
	link.demo = true
	link.settings_path = _tmp.path_join("demo.cfg")
	link.start()
	var hud := _hud(link)
	await process_frame
	_check("demo mode: badge claude and fake GPU numbers", hud.badge_text() == "your AI: claude" and hud.gpu_text().contains("VRAM 3072/8192 MiB"))
	await _ask(hud, "anything")
	await _answered(hud)
	_check("demo mode: a canned answer and its fake latency", hud.panel_text() == "your AI (claude) says:\n" + GuideHud.DEMO_ANSWER and hud.latency_text() == "last call 842 ms", hud.panel_text().c_escape())
	await _key(KEY_O)
	_check("demo mode: the toggle works without a settings file", hud.badge_text() == "AI off" and not FileAccess.file_exists(_tmp.path_join("demo.cfg")))
	_check("demo mode: zero detector reads and nothing launched", spy.starts == 0 and spy.waits == 0 and spy.gpu_count() == 0 and spy.finds == 0 and link.adapter == null)
	await _drop(hud)


func _privacy_checks() -> void:
	Settings.save("ollama", true, _tmp.path_join("privacy.cfg"))
	var real := Detector.new()
	real.agent_file_path = _tmp.path_join("agent-path")
	real.path_dirs = PackedStringArray([_fx.path_join("path").path_join("empty")])
	real.ollama_port = _port
	real.openai_port = _closed_port
	real.http_timeout_ms = 500
	real.sysfs_root = _fx.path_join("sysfs")
	real.nvidia_smi_path = _fx.path_join("path").path_join("empty").path_join("nvidia-smi")
	var holder := {}
	var link := Link.new()
	link.detector = real
	link.settings_path = _tmp.path_join("privacy.cfg")
	link.adapter_factory = func(_f, _d, guide_tuning: Resource):
		var stub := Fakes.StubAdapter.new(guide_tuning)
		stub.name = "local"
		stub.kind = "ollama"
		stub.tps = 12.0
		stub.rate_clock = _now
		holder["stub"] = stub
		return stub
	link.start()
	var hud := _hud(link)
	await _ready_hud(hud)
	_fake_now += 60000
	await _ask(hud, "status")
	await _answered(hud)
	await _key(KEY_O)
	var shown := hud.shown_text()
	shown.append(hud.badge_text())
	shown.append(hud.latency_text())
	shown.append(hud.gpu_text())
	var forbidden := [LEAK_MODEL, "fake-model", LEAK_HOST, LEAK_USER, LEAK_PATH, "/fake", ProjectSettings.globalize_path("res://"), _tmp]
	for env in ["HOME", "USER", "LOGNAME"]:
		var value := OS.get_environment(env)
		if value.length() > 2:
			forbidden.append(value)
	var host := FileAccess.get_file_as_string("/proc/sys/kernel/hostname").strip_edges()
	if host.length() > 2:
		forbidden.append(host)
	var leaks := PackedStringArray()
	for line in shown:
		for word in forbidden:
			if line.findn(word) >= 0:
				leaks.append(word)
	_paths_seen()
	_check("seeded private strings (a path in the agent setting, model, host and user names from the server) never reach any HUD label", leaks.is_empty() and hud.latency_text().contains("12.0 tok/s"), "leaks %s; shown %s" % [", ".join(leaks), str(shown)])
	await _drop(hud)


func _layout_checks() -> void:
	Settings.save("claude", true, _tmp.path_join("layout.cfg"))
	var before := root.size
	var long_answer := "word ".repeat(200)
	for size in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = size
		_fake_now += 60000
		var link := _link(_fake(_found(Found.AgentState.KNOWN, "claude", true), {"available": true, "util_percent": 100, "vram_used_mib": 16777216, "vram_total_mib": 16777216, "temp_c": 200}), {"name": "claude", "answer": long_answer}, "layout.cfg")
		var main = MainScene.instantiate()
		Link.park(link)
		root.add_child(main)
		_huds.append(main)
		await _until(func(): return main.get_node("Hud").guide().session_link().is_ready())
		var hud: GuideHud = main.get_node("Hud").guide()
		hud.focus_check = func(): return false
		await _ask(hud, "layout")
		await _answered(hud)
		for i in 3:
			await process_frame
		var answer_out := _outside(main)
		_fake_now += 60000  # past the cooldown, so T really opens the box
		await process_frame
		await _key(KEY_T)
		for i in 3:
			await process_frame
		var typing_out := _outside(main)
		var box_shown: bool = hud.is_typing() and typing_out[2]
		_check("at %dx%d every HUD label sits inside the screen, with a long answer and with the ask box open" % [size.x, size.y], answer_out[0] >= 6 and answer_out[1].is_empty() and box_shown and typing_out[0] >= 6 and typing_out[1].is_empty(), "box %s; %s | %s" % [box_shown, ", ".join(answer_out[1]), ", ".join(typing_out[1])])
		await _key(KEY_ESCAPE)
		main.free()
		Link.take_parked()
		await process_frame
	root.size = before


func _outside(main: Node) -> Array:
	var screen := Rect2(Vector2.ZERO, Vector2(root.size))
	var shown := 0
	var box := false
	var outside := PackedStringArray()
	for control in main.find_children("*", "Control", true, false):
		if not (control is Label or control is LineEdit) or not control.is_visible_in_tree():
			continue
		if control is Label and control.text.is_empty():
			continue
		shown += 1
		box = box or control is LineEdit
		if not screen.encloses(control.get_global_rect()):
			outside.append("%s %s" % [(control.text if control is Label else "ask box").left(20), control.get_global_rect()])
	return [shown, outside, box]


func _arena_checks() -> void:
	Settings.save("claude", true, _tmp.path_join("arena.cfg"))
	_fake_now += 60000
	var holder := {}
	var link := _link(_fake(_found(Found.AgentState.KNOWN, "claude", true)), {"name": "claude"}, "arena.cfg", holder)
	Link.park(link)
	var main = MainScene.instantiate()
	root.add_child(main)
	current_scene = main
	_huds.append(main)
	await _until(func(): return main.get_node("Hud").guide().session_link().is_ready())
	var hud: GuideHud = main.get_node("Hud").guide()
	var player = main.get_node("Player")
	player.assume_captured = true
	var shots := [0]
	player.shot_fired.connect(func(_hit): shots[0] += 1)
	for i in 30:
		await physics_frame
	# Control: with the box closed, held keys move the player and a click fires.
	var start: Vector3 = player.global_position
	Input.action_press("move_forward")
	for i in 30:
		await physics_frame
	Input.action_release("move_forward")
	var moved: float = Vector2(player.global_position.x - start.x, player.global_position.z - start.z).length()
	await _click()
	for i in 20:
		await physics_frame
	var control_shots: int = shots[0]
	_check("control: with the ask box closed, a held W moves the player and a click fires", moved > 0.5 and control_shots >= 1, "moved %.2f m, %d shots" % [moved, control_shots])
	for i in 60:
		await physics_frame
	# Typing: the same keys and the click do nothing in the game.
	await _key(KEY_T)
	var at: Vector3 = player.global_position
	var arena_id: int = main.get_instance_id()
	Input.action_press("move_forward")
	Input.action_press("jump")
	await _type("wd r t o")
	await _click()
	for i in 40:
		await physics_frame
	Input.action_release("move_forward")
	Input.action_release("jump")
	var drift: float = Vector2(player.global_position.x - at.x, player.global_position.z - at.z).length()
	var typed: String = hud._edit.text
	print("HUD typing: drift %.3f m, rise %.3f m, shots %d -> %d, typed '%s', still typing %s" % [drift, player.global_position.y - at.y, control_shots, shots[0], typed, hud.is_typing()])
	_check("typing blocks the game: held W and Space, typed WASD, R, T and O and a click move nothing, jump nothing, fire nothing", hud.is_typing() and player.input_blocked and drift < 0.01 and player.global_position.y - at.y < 0.01 and shots[0] == control_shots, "drift %.3f, shots %d" % [drift, shots[0]])
	_check("typed keys land in the ask box, R does not reload the arena, T and O do not reopen or toggle", typed == "wd r t o" and is_instance_valid(main) and main.get_instance_id() == arena_id and current_scene == main and hud.badge_text() == "your AI: claude")
	hud.focus_check = func(): return false
	await _key(KEY_ESCAPE)
	_check("Esc closes the box and gives input back, without grabbing the mouse when the window has no focus", not hud.is_typing() and not player.input_blocked and hud.recaptures() == 0 and holder["stub"].ask_calls == 0)
	hud.focus_check = func(): return true
	await _key(KEY_T)
	await _key(KEY_ESCAPE)
	_check("with focus, closing the box captures the mouse again", hud.recaptures() == 1)
	# R reloads the arena: the new HUD takes the same session link back.
	var old_arena: int = main.get_instance_id()
	await _key(KEY_R)
	await _until(func(): return current_scene != null and current_scene.get_instance_id() != old_arena and current_scene.has_node("Hud"))
	await process_frame
	var reloaded: GuideHud = current_scene.get_node("Hud").guide() if current_scene != null else null
	_check("R reloads the arena and the new HUD keeps the session's link", reloaded != null and reloaded.session_link() == link)
	if current_scene != null:
		current_scene.free()
	current_scene = null
	Link.take_parked()
	await process_frame


func _click() -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = Vector2(200, 200)
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var up := down.duplicate() as InputEventMouseButton
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame


func _cleanup() -> void:
	for node in _huds:
		if is_instance_valid(node):
			node.free()
	var left = Link.take_parked()
	if left != null:
		left.shut_down(null)
	await process_frame
	await _until(func():
		for child in root.get_children():
			if child.get_script() == Link.Leftovers:
				return false
		return true)
	# A shot's sound still playing at exit shows up as leaked objects: let it end first.
	OS.delay_msec(300)
	await process_frame
