extends SceneTree
## Headless model-load test for SIGKILL (C11b). scripts/check.sh runs it; any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/model_load_test.gd
##
## Fakes only. A stateful fake Ollama server on a random 127.0.0.1 port, on its own
## thread, keeps a list of models with fake names ("fixture-chat-small" and others) and
## which of them are loaded, answers /api/ps, /api/tags, /api/show, /api/generate and the
## chat endpoint, and logs every request with its body. The guide HUD and the boot screen
## drive the real GuideLink, the real Ollama loader and the real C9b local adapter against
## it. No real model server is ever contacted. Settings live in a fresh temporary folder
## that the test removes at the end.

const Fakes = preload("res://tests/support/guide_fakes.gd")
const GuideHud = preload("res://scripts/hud/guide_hud.gd")
const Link = preload("res://scripts/guide/guide_link.gd")
const Loader = preload("res://scripts/guide/ollama_loader.gd")
const Local = preload("res://scripts/ai/local_openai_adapter.gd")
const Settings = preload("res://scripts/boot/guide_settings.gd")
const Detector = preload("res://scripts/ai/ai_source_detector.gd")
const Found = preload("res://scripts/ai/ai_source_result.gd")
const Controls = preload("res://scripts/controls.gd")
const BootScene = preload("res://scenes/boot.tscn")
const Boot = preload("res://scripts/boot/boot_sequence.gd")
const WATCHDOG_MS := 10000
const GB := 1000000000
const SMALL := "fixture-chat-small"
const MEDIUM := "fixture-chat-medium"
const HUGE := "fixture-chat-huge"
const EMBED := "fixture-embed-tiny"
const VECTOR := "fixture-vector-small"
const OTHER := "fixture-other-chat"
const LOADER_NEVER := ["num_ctx", "\"options\"", "/api/pull", "/api/delete", "/api/create", "/api/copy", "/api/push", "/v1/", "StreamPeerTCP", "OS.execute", "\"prompt\"", "print(", "push_warning(", "push_error("]

var _fails := 0
var _checks := 0
var _tmp := ""
var _fake_now := 1000000
var _huds: Array = []
var _log_all := PackedStringArray()

var _server := TCPServer.new()
var _server_thread := Thread.new()
var _mutex := Mutex.new()
var _stop := false
var _port := 0
var _closed_port := 0
## Server state, under _mutex.
var _models: Array = []
var _loaded: Array = []
var _requests: Array = []
var _generate_mode := "load"
var _late_ms := 0
var _late_at := {}
var _lmstudio := false
## Milliseconds the fake server waits before answering /api/ps; a broken /api/ps; models
## whose /api/show answers 500.
var _ps_delay_ms := 0
var _bad_ps := false
var _show_fails: Array = []
var _unload_fails := false
## Models whose unload request the fake server holds open and never answers.
var _hang_unload_for: Array = []


func _initialize() -> void:
	_run()


func _run() -> void:
	if not _setup():
		quit(1)
		return
	await process_frame
	root.size = Vector2i(1280, 720)
	_unit_checks()
	_source_checks()
	await _natural_path_checks()
	await _decline_checks()
	await _load_checks()
	await _toggle_checks()
	await _cancel_checks()
	await _timeout_checks()
	await _already_loaded_checks()
	await _pre_y_checks()
	await _too_big_checks()
	await _other_server_checks()
	await _guard_checks()
	await _demo_checks()
	await _boot_checks()
	await _hardening_checks()
	await _more_hardening_checks()
	await _last_hardening_checks()
	await _cleanup()
	print("LOAD server log (every request the fake Ollama server saw, in order):")
	for line in _log_all:
		print("  " + line)
	print("LOAD: %d checks" % _checks)
	print("LOAD RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	_teardown()
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


func _setup() -> bool:
	_tmp = OS.get_temp_dir().path_join("sigkill-load-test-%d" % OS.get_process_id())
	if DirAccess.dir_exists_absolute(_tmp):
		print("FAIL the test's temporary folder already exists; not touching it")
		return false
	DirAccess.make_dir_recursive_absolute(_tmp)
	Controls.ensure()
	Settings.save("ollama", true, _tmp.path_join("ollama.cfg"))
	Settings.save("openai-compatible", true, _tmp.path_join("openai.cfg"))
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
	_mutex.lock()
	_stop = true
	_mutex.unlock()
	_server_thread.wait_to_finish()
	_server.stop()
	for name in DirAccess.get_files_at(_tmp):
		DirAccess.remove_absolute(_tmp.path_join(name))
	DirAccess.remove_absolute(_tmp)


## Resets the fake server: these models on offer, these loaded, this generate behaviour.
func _server_state(models: Array, loaded: Array, mode: String = "load", late_ms: int = 0, lmstudio: bool = false) -> void:
	_mutex.lock()
	_models = models.duplicate(true)
	_loaded = loaded.duplicate()
	_generate_mode = mode
	_late_ms = late_ms
	_late_at = {}
	_lmstudio = lmstudio
	_ps_delay_ms = 0
	_bad_ps = false
	_show_fails = []
	_unload_fails = false
	_hang_unload_for = []
	_requests.clear()
	_mutex.unlock()


func _server_tweak(key: String, value) -> void:
	_mutex.lock()
	set(key, value)
	_mutex.unlock()


func _seen() -> Array:
	_mutex.lock()
	var out := _requests.duplicate(true)
	_requests.clear()
	_mutex.unlock()
	for r in out:
		_log_all.append("%s %s %s" % [r["method"], r["path"], r["body"]])
	return out


## True once the fake server has seen an unload request for `name`, without clearing.
func _seen_unload_attempt(name: String) -> bool:
	_mutex.lock()
	var found := false
	for r in _requests:
		found = found or (r["path"] == "/api/generate" and r["body"].contains('"keep_alive":0') and r["body"].contains(name))
	_mutex.unlock()
	return found


## True once the fake server has seen a request to `path`, without clearing the log.
func _has_request(path: String) -> bool:
	_mutex.lock()
	var found := false
	for r in _requests:
		found = found or r["path"] == path
	_mutex.unlock()
	return found


func _loaded_now() -> Array:
	_mutex.lock()
	var out := _loaded.duplicate()
	_mutex.unlock()
	return out


func _set_loaded(names: Array) -> void:
	_mutex.lock()
	_loaded = names.duplicate()
	_mutex.unlock()


static func _paths(requests: Array) -> Array:
	var out := []
	for r in requests:
		out.append(r["method"] + " " + r["path"])
	return out


static func _bodies(requests: Array, path: String) -> Array:
	var out := []
	for r in requests:
		if r["path"] == path and r["method"] == "POST":
			out.append(r["body"])
	return out


func _model(name: String, size: int, family: String = "llama", capabilities: Array = ["completion"]) -> Dictionary:
	return {"name": name, "size": size, "family": family, "capabilities": capabilities}


func _standard_models() -> Array:
	return [
		_model(EMBED, int(0.3 * GB), "nomic-bert", ["embedding"]),
		_model(VECTOR, 1 * GB, "llama", ["embedding"]),
		_model(SMALL, 2 * GB),
		_model(MEDIUM, int(4.7 * GB)),
		_model(HUGE, 20 * GB),
	]


func _serve() -> void:
	var conns := []
	while true:
		_mutex.lock()
		var stop := _stop
		var now := Time.get_ticks_msec()
		for name in _late_at.keys():
			if now >= _late_at[name] and not _loaded.has(name):
				_loaded.append(name)
				_late_at.erase(name)
		_mutex.unlock()
		if stop:
			break
		while _server.is_connection_available():
			conns.append({"peer": _server.take_connection(), "buf": PackedByteArray(), "held": false, "reply": PackedByteArray(), "due": 0})
		for e in conns.duplicate():
			var peer: StreamPeerTCP = e["peer"]
			peer.poll()
			if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
				conns.erase(e)
				continue
			if e["held"]:
				continue
			if not (e["reply"] as PackedByteArray).is_empty():
				if Time.get_ticks_msec() >= e["due"]:
					peer.put_data(e["reply"])
					peer.disconnect_from_host()
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
			var body := raw.slice(split + 4).get_string_from_utf8()
			var reply := _answer(first[0], first[1], body)
			if reply.is_empty():
				e["held"] = true  # a load that never answers: the connection stays open
				continue
			_mutex.lock()
			var delay := _ps_delay_ms if first[1] == "/api/ps" else 0
			_mutex.unlock()
			if delay > 0:
				e["reply"] = reply
				e["due"] = Time.get_ticks_msec() + delay
				continue
			peer.put_data(reply)
			peer.disconnect_from_host()
			conns.erase(e)
		OS.delay_usec(500)


## The fake server's answer, or empty to hold the connection open.
func _answer(method: String, path: String, body: String) -> PackedByteArray:
	_mutex.lock()
	_requests.append({"method": method, "path": path, "body": body})
	var out := ""
	var status := "200 OK"
	match path:
		"/api/version":
			out = '{"version":"0.0.0-fake"}'
		"/api/ps":
			var items := PackedStringArray()
			for name in _loaded:
				items.append('{"name":"%s","model":"%s","size_vram":1}' % [name, name])
			out = '{"models":"unreadable"}' if _bad_ps else '{"models":[%s]}' % ",".join(items)
		"/api/tags":
			var items := PackedStringArray()
			for m in _models:
				items.append('{"name":"%s","model":"%s","size":%d,"details":{"family":"%s","families":["%s"]}}' % [m["name"], m["name"], m["size"], m["family"], m["family"]])
			out = '{"models":[%s]}' % ",".join(items)
		"/api/show":
			var asked = JSON.parse_string(body)
			status = "404 Not Found"
			for m in _models:
				if asked is Dictionary and asked.get("model", "") == m["name"] and not _show_fails.has(m["name"]):
					status = "200 OK"
					out = '{"capabilities":%s,"details":{"family":"%s"}}' % [JSON.stringify(m["capabilities"]), m["family"]]
		"/api/generate":
			var asked = JSON.parse_string(body)
			var name: String = asked.get("model", "") if asked is Dictionary else ""
			if asked is Dictionary and asked.has("keep_alive") and int(asked["keep_alive"]) == 0:
				if _hang_unload_for.has(name):
					_mutex.unlock()
					return PackedByteArray()
				if _unload_fails:
					status = "500 Internal Server Error"
				else:
					_loaded.erase(name)
					out = '{"model":"%s","done":true,"done_reason":"unload"}' % name
			else:
				match _generate_mode:
					"load":
						if not _loaded.has(name):
							_loaded.append(name)
						out = '{"model":"%s","response":"","done":true,"done_reason":"load"}' % name
					"late":
						_late_at[name] = Time.get_ticks_msec() + _late_ms
						_mutex.unlock()
						return PackedByteArray()
					"hang":
						_mutex.unlock()
						return PackedByteArray()
					_:
						status = "404 Not Found"
		"/v1/chat/completions":
			if _loaded.is_empty():
				status = "404 Not Found"
			else:
				out = '{"choices":[{"message":{"role":"assistant","content":"Aim for the core."}}],"usage":{"completion_tokens":12}}'
		_:
			status = "404 Not Found"
	_mutex.unlock()
	var bytes := out.to_utf8_buffer()
	var reply := ("HTTP/1.1 %s\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % [status, bytes.size()]).to_utf8_buffer()
	reply.append_array(bytes)
	return reply


func _now() -> int:
	return _fake_now


func _found(ollama_server: bool, gpu: Dictionary = {}) -> Found:
	var f := Found.new()
	f.agent_state = Found.AgentState.UNSET
	f.ollama_reachable = ollama_server
	f.ollama_model_count = 3 if ollama_server else -1
	f.openai_reachable = not ollama_server
	f.openai_model_count = -1 if ollama_server else 1
	if not gpu.is_empty():
		f.gpu_available = true
		f.gpu_util_percent = 10
		f.gpu_vram_total_mib = gpu["total"]
		f.gpu_vram_used_mib = gpu["used"]
		f.gpu_temp_c = 50
	Detector.resolve(f)
	return f


## A link like a real session's against the fake server: the real C9b local adapter (kind
## ollama or openai-compatible) on its port, and, unless `inject_port` is false, that port
## handed in as the only one the loader may use.
func _link(ollama_server: bool = true, inject_port: bool = true, gpu: Dictionary = {}, tweak: Dictionary = {}) -> Link:
	var link := Link.new()
	var detector := Fakes.FakeDetector.new()
	detector.result = _found(ollama_server, gpu)
	if not gpu.is_empty():
		detector.reading = {"available": true, "util_percent": 10, "vram_used_mib": gpu["used"], "vram_total_mib": gpu["total"], "temp_c": 50}
	link.detector = detector
	link.settings_path = _tmp.path_join("ollama.cfg" if ollama_server else "openai.cfg")
	Settings.save("ollama" if ollama_server else "openai-compatible", true, link.settings_path)  # O in a check saves a no
	if inject_port:
		link.load_port = _port
	var kind := Local.KIND_OLLAMA if ollama_server else Local.KIND_OPENAI
	var port := _port
	link.adapter_factory = func(_f, _d, guide_tuning: Resource):
		var local := Local.new(guide_tuning)
		local.configure(kind, Detector.LOCALHOST, port)
		local.rate_clock = _now
		return local
	link.guide_tuning.load_timeout_ms = tweak.get("load_timeout_ms", 5000)
	link.guide_tuning.unload_timeout_ms = tweak.get("unload_timeout_ms", 2000)
	link.guide_tuning.load_watch_interval_ms = 500
	link.guide_tuning.local_timeout_ms = 5000
	link.start()
	return link


func _hud(link: Link) -> GuideHud:
	var hud := GuideHud.new()
	hud.link = link
	hud.focus_check = func(): return false
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


func _ready(hud: GuideHud) -> bool:
	return await _until(func(): return hud.session_link().is_ready())


func _type(text: String) -> void:
	for i in text.length():
		var c := text.unicode_at(i)
		var down := InputEventKey.new()
		down.keycode = (c - 0x20) as Key
		down.physical_keycode = down.keycode
		down.unicode = c
		down.pressed = true
		Input.parse_input_event(down)
		await process_frame


## Asks the AI something through the HUD's box: T, a few letters, Enter.
func _ask(text: String) -> void:
	await _key(KEY_T)
	await _type(text)
	await _key(KEY_ENTER)


func _key(keycode: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var up := down.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame


## Ends a HUD as the game's end does: a window close request, then freed. Its link then
## unloads what the game loaded.
func _quit(hud: GuideHud) -> void:
	if is_instance_valid(hud):
		hud.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		hud.free()
	Link.take_parked()
	await process_frame


## A HUD with "not loaded" already known (as the boot handshake leaves it) and the
## question on screen.
func _offered(link: Link) -> GuideHud:
	link.not_loaded = true
	var hud := _hud(link)
	await _ready(hud)
	await _key(KEY_T)
	await _until(func(): return hud.status_text() == GuideHud.LOAD_KEYS or link.load_state != "checking")
	return hud


func _unit_checks() -> void:
	var listing := {"models": []}
	for m in _standard_models():
		listing["models"].append({"name": m["name"], "size": m["size"], "details": {"family": m["family"], "families": [m["family"]]}})
	listing["models"].append({"name": "bad name; rm", "size": GB, "details": {"family": "llama"}})
	listing["models"].append({"name": "fixture-no-size", "details": {"family": "llama"}})
	var cap := 8589934592
	var names := func(list: Array) -> Array:
		var out := []
		for c in list:
			out.append(c["name"])
		return out
	var all: Array = names.call(Loader.candidates(listing, cap, -1, 1024))
	_check("candidates: embedding families, names with spaces or no size, and models over the 8 GiB cap are skipped; smallest first", all == [VECTOR, SMALL, MEDIUM], str(all))
	var vram: Array = names.call(Loader.candidates(listing, cap, 3100, 1024))
	_check("candidates: with 3100 MiB free and a 1024 MiB margin, only models under 2076 MiB", vram == [VECTOR, SMALL], str(vram))
	var tight: Array = names.call(Loader.candidates(listing, cap, 1000, 1024))
	_check("candidates: with less free VRAM than the margin, none", tight.is_empty(), str(tight))
	_check("sizes read the way Ollama shows them", Loader.size_text(int(4.7 * GB)) == "4.7 GB" and Loader.size_text(2 * GB) == "2.0 GB")
	_check("/api/show: no completion capability means no chat", not Loader.can_chat({"capabilities": ["embedding"]}) and Loader.can_chat({"capabilities": ["completion", "tools"]}) and Loader.can_chat({}))
	var t: Resource = load("res://resources/guide.tres")
	var bad: Resource = t.duplicate()
	bad.max_load_bytes = 10
	bad.vram_margin_mib = -1
	bad.load_timeout_ms = 1
	bad.unload_timeout_ms = 0
	bad.load_watch_interval_ms = 1
	_check("guide tuning: the load limits ship valid and refuse nonsense", t.problems().is_empty() and t.max_load_bytes == 8589934592 and t.vram_margin_mib == 1024 and t.load_timeout_ms == 120000 and bad.problems().size() == 5, ", ".join(bad.problems()))


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
	var loader := _code("res://scripts/guide/ollama_loader.gd")
	var found := PackedStringArray()
	for word in LOADER_NEVER:
		if loader.contains(word):
			found.append(word)
	_check("the loader never sends num_ctx, options, a prompt or keep_alive on a load, never pulls, deletes or uses /v1, opens no socket itself and never prints", found.is_empty(), ", ".join(found))
	_check("the loader posts to /api/generate in exactly two places: one load with only the model, one unload with keep_alive 0", loader.count("GENERATE_PATH") == 3 and loader.count("_post(GENERATE_PATH, {\"model\": name}, deadline)") == 1 and loader.count("_send(\"POST\", GENERATE_PATH, JSON.stringify({\"model\": name, \"keep_alive\": 0}).to_utf8_buffer(), deadline, cancellable)") == 1)
	var link_code := _code("res://scripts/guide/guide_link.gd")
	_check("loader jobs never overlap: a job asked for while one runs is queued, and the cancel flag is armed before each start", link_code.contains("\tif _loader_thread != null:\n\t\t_queued_job = job\n\t\t_queued_kind = kind\n\t\t_queued_id = id\n\t\treturn true\n\t_loader.arm()\n") and link_code.contains("\t_loader_thread = Thread.new()\n\t_running_kind = kind"))
	var link := _code("res://scripts/guide/guide_link.gd")
	_check("the link loads only from accept_load(), the player's Y, and starts nothing else that loads", link.count("job_load") == 1 and link.contains("func accept_load() -> bool:\n\tif load_state != \"offer\"") and link.count("print(") == 0)
	_check("under the headless guard the loader's only port is one a test handed in", link.contains("\tif load_port > 0:\n\t\treturn load_port\n\tif _guarded or detector == null:\n\t\treturn -1"))


func _natural_path_checks() -> void:
	_server_state(_standard_models(), [])
	var link := _link()
	var hud := _hud(link)
	await _ready(hud)
	await _ask("hi")
	await _until(func(): return link.not_loaded and not hud.is_asking())
	var ask := _seen()
	_check("nothing loaded: the ask finds nothing loaded and loads nothing", link.not_loaded and _paths(ask) == ["GET /api/ps"] and hud.status_text() == GuideHud.NOT_LOADED_LINE + GuideHud.LOADS_ONE, "%s | %s" % [_paths(ask), hud.status_text()])
	await _key(KEY_T)
	await _until(func(): return hud.status_text() == GuideHud.LOAD_KEYS)
	var offer := _seen()
	_check("T then offers exactly one model, the smallest chat model, with its size", hud.panel_text() == "SIGKILL\nLoad %s (2.0 GB) on your local server?\n%s" % [SMALL, GuideHud.LOAD_KEYS], hud.panel_text().c_escape())
	_check("the offer re-reads /api/ps, reads /api/tags, and skips a model /api/show says cannot chat; nothing is loaded", _paths(offer) == ["GET /api/ps", "GET /api/tags", "POST /api/show", "POST /api/show"] and _bodies(offer, "/api/show") == ['{"model":"%s"}' % VECTOR, '{"model":"%s"}' % SMALL] and _loaded_now().is_empty(), str(_paths(offer)))
	await _quit(hud)
	_check("quitting with the question open sends nothing", _seen().is_empty())


func _decline_checks() -> void:
	for key in [KEY_N, KEY_ESCAPE]:
		_server_state(_standard_models(), [])
		var link := _link()
		var hud := await _offered(link)
		_seen()
		await _key(key)
		for i in 30:
			await process_frame
		var after := _seen()
		_check("%s at the question: no load sent, the scripted guide stays, still not loaded" % ("N" if key == KEY_N else "Esc"), after.is_empty() and hud.panel_text() == "SIGKILL\n" + GuideHud.NOT_LOADING_LINE and link.not_loaded and link.load_state == "declined" and _loaded_now().is_empty(), str(_paths(after)))
		await _quit(hud)
		_check("and nothing to unload at the end", _seen().is_empty())


func _load_checks() -> void:
	_server_state(_standard_models(), [])
	var link := _link()
	var hud := await _offered(link)
	_seen()
	await _key(KEY_Y)
	var loaded: bool = await _until(func(): return link.load_state == "loaded")
	var sent := _seen()
	var bodies := _bodies(sent, "/api/generate")
	var parsed = JSON.parse_string(bodies[0]) if bodies.size() == 1 else null
	_check("Y: one load request whose body is exactly {\"model\": name}: no prompt, options, num_ctx or keep_alive", loaded and bodies.size() == 1 and parsed is Dictionary and parsed.keys() == ["model"] and parsed["model"] == SMALL, str(bodies))
	_check("Y: /api/ps read first, then the load, then /api/ps again to see it loaded; the game owns it", _paths(sent) == ["GET /api/ps", "POST /api/generate", "GET /api/ps"] and link.game_loaded_model() == SMALL and _loaded_now() == [SMALL], str(_paths(sent)))
	await _until(func(): return hud.panel_text() == "SIGKILL\n" + GuideHud.LOADED_LINE)
	_check("the screen says it is loaded and how to ask; not-loaded is gone", hud.panel_text() == "SIGKILL\n" + GuideHud.LOADED_LINE and not link.not_loaded and hud.status_text() == GuideHud.KEYS_LINE, hud.status_text())
	_fake_now += 60000
	await _ask("hi")
	await _until(func(): return hud.panel_text().begins_with("your AI (local) says:"))
	_check("then T asks the loaded model and it answers", hud.panel_text() == "your AI (local) says:\nAim for the core.", hud.panel_text().c_escape())
	_seen()
	await _quit(hud)
	var bye := _seen()
	_check("at the end of the session: one unload, keep_alive 0, for the model the game loaded", _bodies(bye, "/api/generate") == ['{"keep_alive":0,"model":"%s"}' % SMALL] or _bodies(bye, "/api/generate") == ['{"model":"%s","keep_alive":0}' % SMALL], str(_bodies(bye, "/api/generate")))
	_check("and it is unloaded", _loaded_now().is_empty())


func _toggle_checks() -> void:
	_server_state(_standard_models(), [])
	var link := _link()
	var hud := await _offered(link)
	await _key(KEY_Y)
	await _until(func(): return link.load_state == "loaded")
	_seen()
	await _key(KEY_O)
	await _until(func(): return _loaded_now().is_empty() and link.game_loaded_model() == "" and not link.is_loading())
	var off := _seen()
	_check("O turns the AI off and unloads the game's model: keep_alive 0 for it alone", hud.badge_text() == "AI off" and _bodies(off, "/api/generate").size() == 1 and _bodies(off, "/api/generate")[0].contains('"keep_alive":0') and _bodies(off, "/api/generate")[0].contains(SMALL) and link.game_loaded_model() == "", str(_paths(off)))
	await _quit(hud)
	_check("nothing left to unload at the end", _bodies(_seen(), "/api/generate").is_empty())


func _cancel_checks() -> void:
	_server_state(_standard_models(), [], "late", 800)
	var link := _link()
	var hud := await _offered(link)
	await _key(KEY_Y)
	await _until(func(): return _has_request("/api/generate"))  # the load is on its way
	await _key(KEY_ESCAPE)
	_check("Esc while loading stops waiting and says the game will unload it if it turns up", link.load_state == "cancelled" and hud.panel_text() == "SIGKILL\n" + GuideHud.STOPPED_LINE)
	var turned_up: bool = await _until(func(): return _loaded_now().has(SMALL))
	var unloaded: bool = await _until(func(): return _loaded_now().is_empty())
	var sent := _seen()
	_check("the model turned up after the cancel, and the game unloaded it: keep_alive 0 for it alone", turned_up and unloaded and _bodies(sent, "/api/generate").size() == 2 and _bodies(sent, "/api/generate")[1].contains('"keep_alive":0') and _bodies(sent, "/api/generate")[1].contains(SMALL), str(_bodies(sent, "/api/generate")))
	await _quit(hud)
	_seen()


func _timeout_checks() -> void:
	_server_state(_standard_models(), [], "hang")
	var link := _link(true, true, {}, {"load_timeout_ms": 1000})
	var hud := await _offered(link)
	_seen()
	var t0 := Time.get_ticks_msec()
	await _key(KEY_Y)
	var timed_out: bool = await _until(func(): return link.load_state == "timeout")
	var waited := Time.get_ticks_msec() - t0
	await _until(func(): return hud.panel_text() == "SIGKILL\n" + GuideHud.LOAD_TIMEOUT_LINE)
	var sent := _seen()
	_check("a load that never finishes times out, falls to the scripted guide, and sends no chat", timed_out and waited >= 1000 and waited < WATCHDOG_MS and hud.panel_text() == "SIGKILL\n" + GuideHud.LOAD_TIMEOUT_LINE and link.not_loaded and _paths(sent).count("POST /v1/chat/completions") == 0 and _bodies(sent, "/api/generate").size() == 1, "%d ms, %s" % [waited, str(_paths(sent))])
	await _quit(hud)
	var bye := _seen()
	_check("nothing turned up, so nothing is unloaded at the end", _bodies(bye, "/api/generate").is_empty() and _loaded_now().is_empty(), str(_paths(bye)))


func _already_loaded_checks() -> void:
	_server_state(_standard_models(), [OTHER])
	var link := _link()
	link.not_loaded = true
	var hud := _hud(link)
	await _ready(hud)
	await _key(KEY_T)
	await _until(func(): return link.load_state == "loaded_now")
	await process_frame
	var seen := _seen()
	_check("a model loaded by now skips the question: no /api/tags, no load", hud.panel_text() == "SIGKILL\n" + GuideHud.LOADED_NOW_LINE and _paths(seen) == ["GET /api/ps"] and not link.not_loaded, str(_paths(seen)))
	_fake_now += 60000
	await _ask("hi")
	await _until(func(): return hud.panel_text().begins_with("your AI (local) says:"))
	_check("and T asks the model that was already loaded", hud.panel_text() == "your AI (local) says:\nAim for the core.")
	_seen()
	await _quit(hud)
	var bye := _seen()
	_check("a model the game did not load is never unloaded", _bodies(bye, "/api/generate").is_empty() and _loaded_now() == [OTHER], str(_paths(bye)))


func _pre_y_checks() -> void:
	# The candidate itself was loaded by something else between the question and the Y.
	_server_state(_standard_models(), [])
	var link := _link()
	var hud := await _offered(link)
	_set_loaded([SMALL])
	_seen()
	await _key(KEY_Y)
	await _until(func(): return link.load_state == "loaded_now")
	var sent := _seen()
	_check("if the model was already loaded when the player said Y, no load is sent and the game does not own it", _paths(sent) == ["GET /api/ps"] and link.game_loaded_model() == "", str(_paths(sent)))
	await _quit(hud)
	var bye := _seen()
	_check("and at the end it is not unloaded", _bodies(bye, "/api/generate").is_empty() and _loaded_now() == [SMALL], str(_paths(bye)))
	# Another model was loaded before the Y: only the game's own model is unloaded.
	_server_state(_standard_models(), [])
	var link2 := _link()
	var hud2 := await _offered(link2)
	_set_loaded([OTHER])
	await _key(KEY_Y)
	await _until(func(): return link2.load_state == "loaded")
	_seen()
	await _quit(hud2)
	var bye2 := _seen()
	_check("a model that was loaded before the Y is never unloaded; only the game's own is", _bodies(bye2, "/api/generate").size() == 1 and _bodies(bye2, "/api/generate")[0].contains(SMALL) and not _bodies(bye2, "/api/generate")[0].contains(OTHER) and _loaded_now() == [OTHER], str(_bodies(bye2, "/api/generate")))


func _too_big_checks() -> void:
	_server_state([_model(EMBED, int(0.3 * GB), "nomic-bert", ["embedding"]), _model(HUGE, 20 * GB)], [])
	var link := _link()
	var hud := await _offered(link)
	await _until(func(): return link.load_state == "none_fits")
	await process_frame
	var seen := _seen()
	_check("only a 20 GB model and an embedding model: nothing fits under 8.6 GB, nothing is sent to load", hud.panel_text().begins_with("SIGKILL\nNo chat model on your local server fits here (under 8.6 GB") and _bodies(seen, "/api/generate").is_empty() and _bodies(seen, "/api/show").is_empty(), hud.panel_text().c_escape())
	await _quit(hud)
	_server_state(_standard_models(), [])
	var tight := _link(true, true, {"total": 8192, "used": 6192})
	var hud2 := await _offered(tight)
	await _until(func(): return tight.load_state != "checking")
	await process_frame
	var seen2 := _seen()
	_check("with 2000 MiB of VRAM free and a 1024 MiB margin, only models under 976 MiB fit: none, nothing loaded", tight.load_state == "none_fits" and _bodies(seen2, "/api/generate").is_empty(), "%s %s" % [tight.load_state, str(_paths(seen2))])
	await _quit(hud2)
	_server_state(_standard_models(), [])
	var room := _link(true, true, {"total": 8192, "used": 5092})
	var hud3 := await _offered(room)
	await process_frame
	_check("with 3100 MiB free the smallest chat model that fits is offered", hud3.panel_text().contains("Load %s (2.0 GB)" % SMALL), hud3.panel_text().c_escape())
	await _quit(hud3)
	_seen()


func _other_server_checks() -> void:
	_server_state(_standard_models(), [], "load", 0, true)
	var link := _link(false)
	var hud := _hud(link)
	await _ready(hud)
	await _ask("hi")
	await _until(func(): return link.not_loaded and not hud.is_asking())
	await process_frame
	_check("another local server with nothing loaded: a hint to load one in its own app, no offer", not link.can_offer_load() and link.load_hint() == "own_app" and hud.status_text().begins_with(GuideHud.NOT_LOADED_LINE + GuideHud.OWN_APP), hud.status_text())
	_fake_now += 60000
	await _key(KEY_T)
	await _key(KEY_Y)
	await _key(KEY_ESCAPE)
	for i in 30:
		await process_frame
	var seen := _seen()
	var bad := []
	for p in _paths(seen):
		if p.contains("/api/generate") or p.contains("/api/tags") or p.contains("/api/show") or p.ends_with(" /v1/models") or p.contains("/api/ps"):
			bad.append(p)
	_check("it never gets a load call: no /api/generate, /api/tags, /api/show, /api/ps or /v1/models", bad.is_empty() and link.load_state == "", str(_paths(seen)))
	await _quit(hud)
	_check("and nothing to unload at the end", _bodies(_seen(), "/api/generate").is_empty())


func _guard_checks() -> void:
	_server_state(_standard_models(), [])
	var link := _link(true, false)
	var hud := _hud(link)
	await _ready(hud)
	link.not_loaded = true
	await process_frame
	_check("headless guard: with no port handed in, the Ollama server the detector found is never loadable", link.is_guarded() and not link.can_offer_load() and link.load_hint() == "" and hud.status_text() == GuideHud.NOT_LOADED_LINE, hud.status_text())
	_seen()
	_fake_now += 60000
	await _key(KEY_T)
	await _key(KEY_Y)
	await _key(KEY_ENTER)
	await _key(KEY_Y)
	for i in 30:
		await process_frame
	var seen := _seen()
	var loads := []
	for p in _paths(seen):
		if p.contains("/api/generate") or p.contains("/api/tags") or p.contains("/api/show"):
			loads.append(p)
	_check("headless guard: T and Y pressed, still no /api/tags, /api/show or /api/generate", loads.is_empty() and link.begin_offer() == false and _loaded_now().is_empty(), str(_paths(seen)))
	await _quit(hud)
	_seen()


func _demo_checks() -> void:
	_server_state(_standard_models(), [])
	var spy := Fakes.FakeDetector.new()
	spy.result = _found(true)
	var link := Link.new()
	link.detector = spy
	link.demo = true
	link.load_port = _port
	link.start()
	var hud := _hud(link)
	await process_frame
	_check("demo mode: the status line shows the demo load key", hud.status_text() == GuideHud.DEMO_KEYS_LINE, hud.status_text())
	await _key(KEY_L)
	_check("demo mode: L shows the question with a fake model", hud.panel_text() == "SIGKILL\nLoad %s (4.7 GB) on your local server?\n%s" % [GuideHud.DEMO_LOAD_NAME, GuideHud.LOAD_KEYS], hud.panel_text().c_escape())
	await _key(KEY_Y)
	var spun: bool = await _until(func(): return hud.status_text().begins_with("loading model"))
	await _until(func(): return hud.panel_text() == "SIGKILL\n" + GuideHud.LOADED_LINE)
	_check("demo mode: a fake load with its spinner, then loaded", spun and hud.panel_text() == "SIGKILL\n" + GuideHud.LOADED_LINE)
	await _quit(hud)
	_check("demo mode: no network at all and no detector reads", _seen().is_empty() and spy.starts == 0 and spy.gpu_count() == 0 and not link.can_offer_load())


func _boot_checks() -> void:
	for ollama_server in [true, false]:
		_server_state(_standard_models(), [], "load", 0, not ollama_server)
		var detector := Fakes.FakeDetector.new()
		detector.result = _found(ollama_server)
		var boot = BootScene.instantiate()
		var fast: Resource = load("res://resources/boot.tres").duplicate()
		fast.chars_per_second = 5000.0
		fast.line_pause_ms = 0
		fast.auto_continue_ms = 100
		boot.tuning = fast
		boot.hand_off = false
		boot.detector = detector
		boot.settings_path = _tmp.path_join("ollama.cfg" if ollama_server else "openai.cfg")
		Settings.save("ollama" if ollama_server else "openai-compatible", true, boot.settings_path)
		boot.load_port = _port
		var kind := Local.KIND_OLLAMA if ollama_server else Local.KIND_OPENAI
		var port := _port
		boot.adapter_factory = func(_f, _d, guide_tuning: Resource):
			var local := Local.new(guide_tuning)
			local.configure(kind, Detector.LOCALHOST, port)
			return local
		var done := [false]
		boot.finished.connect(func(_skipped): done[0] = true)
		root.add_child(boot)
		await _until(func(): return done[0])
		var lines: PackedStringArray = boot.lines()
		var expect: String = Boot.NOT_LOADED_LINE + (Boot.LOAD_IN_ARENA if ollama_server else Boot.LOAD_IN_OWN_APP)
		_check("boot screen, %s with nothing loaded: says so and how to load one, and loads nothing" % ("Ollama" if ollama_server else "another local server"), lines.has(expect) and _bodies(_seen(), "/api/generate").is_empty(), str(lines))
		boot.free()
		await process_frame
		_seen()


## Drives a link without a HUD, polling it by hand.
func _bare_link(tweak: Dictionary = {}) -> Link:
	var link := _link(true, true, {}, tweak)
	await _until(func():
		link.poll(16.0)
		return link.is_ready())
	link.not_loaded = true
	return link


func _pump(link: Link, condition: Callable, ms: int = WATCHDOG_MS) -> bool:
	return await _until(func():
		link.poll(16.0)
		return condition.call(), ms)


func _offer_ready(link: Link) -> bool:
	link.begin_offer()
	return await _pump(link, func(): return link.load_state != "checking")


func _hardening_checks() -> void:
	# O while a load is still in flight: the model turns up later and is still unloaded.
	_server_state(_standard_models(), [], "late", 800)
	var link := _link()
	var hud := await _offered(link)
	await _key(KEY_Y)
	await _until(func(): return _has_request("/api/generate"))
	await _key(KEY_O)
	var turned_up: bool = await _until(func(): return _loaded_now().has(SMALL))
	var gone: bool = await _until(func(): return _loaded_now().is_empty())
	var sent := _seen()
	_check("O while the load is in flight: the model turns up afterwards and is still unloaded, keep_alive 0", turned_up and gone and _bodies(sent, "/api/generate").size() == 2 and _bodies(sent, "/api/generate")[1].contains('"keep_alive":0'), str(_bodies(sent, "/api/generate")))
	await _quit(hud)
	_seen()
	# The load finishes, then Esc comes before the link has joined the worker.
	_server_state(_standard_models(), [])
	var raced := await _bare_link()
	await _offer_ready(raced)
	raced.accept_load()
	await _until(func(): return _loaded_now().has(SMALL))
	OS.delay_msec(200)  # the worker has seen the model in /api/ps and finished, unjoined
	raced.cancel_load()
	var unloaded: bool = await _pump(raced, func(): return _loaded_now().is_empty() and raced.game_loaded_model() == "")
	_check("Esc after the load finished but before the link read it: the model is still unloaded", raced.load_state == "cancelled" and unloaded, raced.load_state)
	raced.shut_down(null)
	_seen()
	# A cancel that comes before the worker runs: no load is ever sent.
	_server_state(_standard_models(), [])
	var early := await _bare_link()
	await _offer_ready(early)
	_seen()
	early.accept_load()
	early.cancel_load()
	await _pump(early, func(): return not early.is_loading(), 3000)
	for i in 20:
		early.poll(16.0)
		await process_frame
	var none := _seen()
	_check("Esc in the same instant as Y: no load is sent and nothing is loaded", _bodies(none, "/api/generate").is_empty() and _loaded_now().is_empty() and early.load_state == "cancelled", str(_paths(none)))
	# That load never reached the server, so it is not watched: when another app loads the
	# same model afterwards, the game leaves it alone.
	_set_loaded([SMALL])
	var t_other := Time.get_ticks_msec()
	await _pump(early, func(): return Time.get_ticks_msec() - t_other > 1800, 4000)
	var left_alone := _seen()
	_check("a load that never reached the server is never watched: another app's copy of the model is left alone", _bodies(left_alone, "/api/generate").is_empty() and _loaded_now() == [SMALL] and not early.load_pending(), str(_paths(left_alone)))
	early.shut_down(null)
	_seen()
	# A Y while an earlier job still runs waits its turn (here the cancelled load, not yet
	# joined); that job's "cancelled" never lands on the new load.
	_server_state(_standard_models(), [], "hang")
	var queued := await _bare_link()
	await _offer_ready(queued)
	queued.accept_load()
	await _until(func(): return _has_request("/api/generate"))
	queued.cancel_load()
	await _pump(queued, func(): return queued.load_state == "cancelled" and not queued.is_loading())
	_server_tweak("_generate_mode", "load")
	_server_tweak("_ps_delay_ms", 400)
	await _pump(queued, func(): return _has_request("/api/ps"), 3000)
	_seen()
	queued.load_state = "offer"
	var accepted := queued.accept_load()
	var finished: bool = await _pump(queued, func(): return queued.load_state == "loaded")
	var order_seen := _seen()
	var order := _paths(order_seen)
	_check("a Y while an earlier job is still unjoined is queued behind it: no thread is replaced, the old job's outcome does not touch it, and the load runs after", accepted and finished and queued.game_loaded_model() == SMALL and order.find("POST /api/generate") > 0, "%s | bodies %s | state %s owned %s" % [str(order), str(_bodies(order_seen, "/api/generate")), queued.load_state, queued.game_loaded_model()])
	_server_tweak("_ps_delay_ms", 0)
	queued.shut_down(null)
	_seen()
	# /api/ps cannot be read at the Y: ownership cannot be proven, so nothing is loaded.
	_server_state(_standard_models(), [])
	var blind := await _bare_link()
	await _offer_ready(blind)
	_server_tweak("_bad_ps", true)
	_seen()
	blind.accept_load()
	await _pump(blind, func(): return not blind.is_loading())
	var blind_sent := _seen()
	_check("an unreadable /api/ps at the Y: no load is sent", blind.load_state == "error" and _bodies(blind_sent, "/api/generate").is_empty(), str(_paths(blind_sent)))
	blind.shut_down(null)
	_seen()
	# An /api/show that fails is never taken as a yes.
	_server_state(_standard_models(), [])
	_server_tweak("_show_fails", [SMALL, MEDIUM])
	var unsure := await _bare_link()
	await _offer_ready(unsure)
	_check("a model whose /api/show fails is never offered", unsure.load_state == "none_fits", unsure.load_state)
	unsure.shut_down(null)
	_seen()
	# Many small embedding-only models before the chat model: every one is checked.
	var many := []
	for i in 6:
		many.append(_model("fixture-vector-%d" % i, (i + 1) * 100000000, "llama", ["embedding"]))
	many.append(_model(SMALL, 2 * GB))
	_server_state(many, [])
	var thorough := await _bare_link()
	await _offer_ready(thorough)
	_check("six smaller embedding-only models are all checked and skipped; the chat model is offered", thorough.load_state == "offer" and thorough.offer_name() == SMALL and _bodies(_seen(), "/api/show").size() == 7, thorough.load_state)
	thorough.shut_down(null)
	_seen()


func _more_hardening_checks() -> void:
	# Two loads in flight: A stopped waiting and still pending, then B loaded and used.
	_server_state(_standard_models(), [], "late", 1500)
	var two := await _bare_link()
	await _offer_ready(two)
	two.accept_load()
	await _until(func(): return _has_request("/api/generate"))
	two.cancel_load()
	await _pump(two, func(): return two.loader_idle() and two.load_state == "cancelled")
	_server_tweak("_models", [_model(MEDIUM, int(4.7 * GB))])
	_server_tweak("_generate_mode", "load")
	await _offer_ready(two)
	var offered_b: String = two.offer_name()
	two.accept_load()
	await _pump(two, func(): return two.load_state == "loaded")
	var a_up: bool = await _pump(two, func(): return _loaded_now().has(SMALL))
	var a_gone: bool = a_up and await _pump(two, func(): return _loaded_now() == [MEDIUM])
	var two_sent := _seen()
	_check("a cancelled load A and a later load B: A is unloaded when it turns up, B stays loaded and in use", offered_b == MEDIUM and a_gone and two.game_loaded_model() == MEDIUM and _bodies(two_sent, "/api/generate").has('{"keep_alive":0,"model":"%s"}' % SMALL) and not _bodies(two_sent, "/api/generate").has('{"keep_alive":0,"model":"%s"}' % MEDIUM), str(_bodies(two_sent, "/api/generate")))
	two.shut_down(null)
	_seen()
	# An unload that fails is retried, with a growing wait, until it goes through.
	_server_state(_standard_models(), [])
	var retry := await _bare_link()
	await _offer_ready(retry)
	retry.accept_load()
	await _pump(retry, func(): return retry.load_state == "loaded")
	_server_tweak("_unload_fails", true)
	_seen()
	retry.set_consent(false)
	# 32 s of game time, in 16 ms steps: with waits of 0.5, 1, 2, 4, 8 and 16 s that is
	# about 7 tries. Each step also waits for a running try to end, in real time.
	for i in 2000:
		retry.poll(16.0)
		while not retry.loader_idle():
			await process_frame
			retry.poll(0.0)
	var failed_tries := _bodies(_seen(), "/api/generate").size()
	_server_tweak("_unload_fails", false)
	var retried: bool = await _pump(retry, func(): return _loaded_now().is_empty() and not retry.load_pending())
	_seen()
	_check("an unload that fails keeps the model marked and is retried, with a growing wait, until it goes through", failed_tries >= 5 and failed_tries <= 8 and retried and retry.game_loaded_model() == "", "%d failed tries in 32 s of game time" % failed_tries)
	retry.shut_down(null)
	_seen()
	# A watched load seen loaded is kept past its window while its unload keeps failing.
	_server_state(_standard_models(), [], "late", 300)
	var seen_link := await _bare_link({"load_timeout_ms": 1000})
	await _offer_ready(seen_link)
	seen_link.accept_load()
	await _until(func(): return _has_request("/api/generate"))
	_server_tweak("_unload_fails", true)
	seen_link.cancel_load()
	var t1 := Time.get_ticks_msec()
	await _pump(seen_link, func(): return Time.get_ticks_msec() - t1 > 2200, 3500)
	var still_kept: bool = _loaded_now().has(SMALL) and (seen_link.load_pending() or not seen_link.loader_idle())
	_server_tweak("_unload_fails", false)
	var finally_gone: bool = await _pump(seen_link, func(): return _loaded_now().is_empty())
	_check("a watched load seen loaded is kept past its 1 s window while its unload fails, then unloaded", still_kept and finally_gone, "kept %s, gone %s" % [still_kept, finally_gone])
	seen_link.shut_down(null)
	_seen()


func _last_hardening_checks() -> void:
	# A watched load offered and accepted again, then cancelled before anything was sent:
	# the first watch is kept, and the model is unloaded when it turns up.
	_server_state(_standard_models(), [], "late", 1500)
	var again := await _bare_link()
	await _offer_ready(again)
	again.accept_load()
	await _until(func(): return _has_request("/api/generate"))
	again.cancel_load()
	await _pump(again, func(): return again.loader_idle() and again.load_state == "cancelled")
	await _offer_ready(again)
	var offered_again: String = again.offer_name()
	# Cancel at the one point that matters: after the second attempt's /api/ps has run (and
	# it has reached the watched-model branch), right before its load would be sent.
	var loader = again.get("_loader")
	var hooked := [false]
	loader.test_before_load = func():
		hooked[0] = true
		loader.cancel()
	again.accept_load()
	await _pump(again, func(): return again.loader_idle() and again.load_state == "cancelled")
	loader.test_before_load = Callable()
	var appeared: bool = await _pump(again, func(): return _loaded_now().has(SMALL))
	var cleared: bool = appeared and await _pump(again, func(): return _loaded_now().is_empty())
	var again_sent := _seen()
	_check("a watched load accepted again and cancelled right before sending (after its /api/ps) keeps its first watch: unloaded when it turns up", hooked[0] and offered_again == SMALL and cleared and _bodies(again_sent, "/api/generate").count('{"model":"%s"}' % SMALL) == 1 and _bodies(again_sent, "/api/generate").has('{"keep_alive":0,"model":"%s"}' % SMALL), str(_bodies(again_sent, "/api/generate")))
	again.shut_down(null)
	_seen()
	# One unload that hangs (B) does not keep another (a pending load A) from being done.
	_server_state(_standard_models(), [], "late", 1500)
	var stuck := await _bare_link({"unload_timeout_ms": 500})
	await _offer_ready(stuck)
	stuck.accept_load()
	await _until(func(): return _has_request("/api/generate"))
	stuck.cancel_load()
	await _pump(stuck, func(): return stuck.loader_idle() and stuck.load_state == "cancelled")
	_server_tweak("_models", [_model(MEDIUM, int(4.7 * GB))])
	_server_tweak("_generate_mode", "load")
	_server_tweak("_hang_unload_for", [MEDIUM])
	await _offer_ready(stuck)
	stuck.accept_load()
	await _pump(stuck, func(): return stuck.load_state == "loaded")
	stuck.set_consent(false)
	var a_up: bool = await _pump(stuck, func(): return _loaded_now().has(SMALL))
	var a_unloaded: bool = a_up and await _pump(stuck, func(): return _loaded_now() == [MEDIUM])
	var mid_seen := _seen()
	var b_tries := _bodies(mid_seen, "/api/generate").count('{"keep_alive":0,"model":"%s"}' % MEDIUM)
	_check("while B's unload hangs on every try, the pending load A still turns up and is unloaded", a_unloaded and _bodies(mid_seen, "/api/generate").has('{"keep_alive":0,"model":"%s"}' % SMALL) and b_tries >= 1, "B tries %d; %s" % [b_tries, str(_loaded_now())])
	_server_tweak("_hang_unload_for", [])
	var b_gone: bool = await _pump(stuck, func(): return _loaded_now().is_empty() and not stuck.load_pending())
	_check("and once B's unload is answered, B goes too", b_gone, str(_loaded_now()))
	stuck.shut_down(null)
	_seen()
	# Quitting while a background unload hangs stays within one exit budget.
	_server_state(_standard_models(), [])
	var quitting := await _bare_link({"unload_timeout_ms": 600})
	await _offer_ready(quitting)
	quitting.accept_load()
	await _pump(quitting, func(): return quitting.load_state == "loaded")
	_server_tweak("_hang_unload_for", [SMALL])
	quitting.set_consent(false)
	await _pump(quitting, func(): return not quitting.loader_idle(), 2000)
	await _until(func(): return _has_request("/api/generate") and _seen_unload_attempt(SMALL))
	var t_quit := Time.get_ticks_msec()
	quitting.shut_down(null)
	var quit_ms := Time.get_ticks_msec() - t_quit
	print("LOAD quit: shutting down during a hanging unload took %d ms (exit budget 600 ms)" % quit_ms)
	_check("quitting while a background unload hangs: the job stops at the cancel, and the exit stays within its one budget", quit_ms < 900, "%d ms" % quit_ms)
	_server_tweak("_hang_unload_for", [])
	_set_loaded([])
	_seen()


func _cleanup() -> void:
	for node in _huds:
		if is_instance_valid(node):
			node.free()
	var left = Link.take_parked()
	if left != null:
		left.shut_down(null)
	await process_frame
	_seen()
