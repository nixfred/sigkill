extends SceneTree
## Headless AI source detector test for SIGKILL. scripts/check.sh runs it, and any FAIL
## exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/ai_detector_test.gd
##
## Everything it touches is a fake: the agent settings, PATH, /sys tree and stubs under
## tests/fixtures/ai, and a fake model server on 127.0.0.1 on a random free port, run on its
## own thread. No real agent is called, no real model server is reached, and the real
## nvidia-smi is never run. The only files written are the stubs' logs and one
## unreadable-file case, in a fresh temporary folder that the test removes at the end.

const Detector = preload("res://scripts/ai/ai_source_detector.gd")
const Result = preload("res://scripts/ai/ai_source_result.gd")
const DETECTOR_PATH := "res://scripts/ai/ai_source_detector.gd"
const FIXTURES := "res://tests/fixtures/ai"
const TIMEOUT_MS := 300
const TIMEOUT_SLACK_MS := 250
const FULL_TAGS := '{"models":[{"name":"fake-model-alpha"},{"name":"fake-model-beta"},{"name":"fake-model-gamma"}]}'
const FULL_V1 := '{"object":"list","data":[{"id":"fake-model-alpha"},{"id":"fake-model-beta"}]}'
const FAKE_MODEL_WORD := "fake-model"
const EXPECTED_SMI_ARGS := ["--query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu", "--format=csv,noheader,nounits"]
const SCAN_DIRS := ["res://scripts", "res://scenes"]
const FORBIDDEN_CALLS := ["OS.execute(", "OS.create_process", "OS.create_instance", "OS.shell_open", "OS.shell_show_in_file_manager", "OS.kill", "HTTPRequest", "StreamPeerTCP", "PacketPeerUDP", "set_unix_permissions", "FileAccess.WRITE", "DirAccess.remove", "make_dir", "\"omarchy"]

var _fails := 0
var _checks := 0
var _fx := ""
var _tmp := ""
var _smi_log := ""
var _exec_mark := ""
var _results: Array = []
var _fake_now := 0

# Fake server, run on its own thread.
var _server := TCPServer.new()
var _server_thread := Thread.new()
var _server_stop := false
var _server_mode := "full"
var _port := 0
var _closed_port := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	_fx = ProjectSettings.globalize_path(FIXTURES)
	if not _setup():
		quit(1)
		return
	_safety_checks()
	_agent_checks()
	_cli_checks()
	_server_checks()
	_gpu_checks()
	_resolver_checks()
	await _async_checks()
	_privacy_checks()
	print("AI DETECTOR: %d checks" % _checks)
	print("AI DETECTOR RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	_teardown()
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


func _setup() -> bool:
	_tmp = OS.get_temp_dir().path_join("sigkill-ai-test-%d" % OS.get_process_id())
	if DirAccess.dir_exists_absolute(_tmp):
		print("FAIL the test's temporary folder already exists; not touching it")
		return false
	DirAccess.make_dir_recursive_absolute(_tmp)
	_smi_log = _tmp.path_join("smi_args.txt")
	_exec_mark = _tmp.path_join("agent_exec_mark.txt")
	OS.set_environment("SIGKILL_TEST_SMI_LOG", _smi_log)
	OS.set_environment("SIGKILL_TEST_EXEC_MARK", _exec_mark)
	if _server.listen(0, Detector.LOCALHOST) != OK:
		print("FAIL the fake server could not listen on 127.0.0.1")
		return false
	_port = _server.get_local_port()
	var closed := TCPServer.new()
	closed.listen(0, Detector.LOCALHOST)
	_closed_port = closed.get_local_port()
	closed.stop()
	_server_thread.start(_serve)
	return true


func _teardown() -> void:
	_server_stop = true
	_server_thread.wait_to_finish()
	_server.stop()
	# Only the files this run made, in its own fresh folder.
	for name in ["smi_args.txt", "agent_exec_mark.txt", "unreadable_agent", "home/.config/omarchy/defaults/agent"]:
		var path := _tmp.path_join(name)
		if FileAccess.file_exists(path):
			FileAccess.set_unix_permissions(path, 0x180)  # owner read and write, so it can go
			DirAccess.remove_absolute(path)
	for dir in ["home/.config/omarchy/defaults", "home/.config/omarchy", "home/.config", "home", ""]:
		var path := _tmp.path_join(dir) if dir != "" else _tmp
		if DirAccess.dir_exists_absolute(path):
			DirAccess.remove_absolute(path)


func _body_for(path: String) -> String:
	match path:
		Detector.OLLAMA_VERSION_PATH:
			return '{"version":"0.0.0-fake"}'
		Detector.OLLAMA_MODELS_PATH:
			return FULL_TAGS if _server_mode == "full" else '{"models":[]}'
		Detector.OPENAI_MODELS_PATH:
			return FULL_V1 if _server_mode == "full" else '{"object":"list","data":[]}'
	return ""


## The fake server: answers each request in "full" and "empty" modes, never in "hang".
func _serve() -> void:
	var conns := []
	while not _server_stop:
		while _server.is_connection_available():
			conns.append({"peer": _server.take_connection(), "buf": PackedByteArray()})
		for entry in conns.duplicate():
			var peer: StreamPeerTCP = entry["peer"]
			peer.poll()
			if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
				conns.erase(entry)
				continue
			var waiting := peer.get_available_bytes()
			if waiting > 0:
				var buf: PackedByteArray = entry["buf"]
				buf.append_array(peer.get_data(waiting)[1])
				entry["buf"] = buf
			var text: String = (entry["buf"] as PackedByteArray).get_string_from_ascii()
			if _server_mode != "hang" and text.contains("\r\n\r\n"):
				var body := _body_for(text.split(" ")[1])
				var status := "200 OK" if body != "" else "404 Not Found"
				var reply := "HTTP/1.1 %s\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" % [status, body.length(), body]
				peer.put_data(reply.to_ascii_buffer())
				peer.disconnect_from_host()
				conns.erase(entry)
		OS.delay_usec(500)
	for entry in conns:
		(entry["peer"] as StreamPeerTCP).disconnect_from_host()


## A detector wired entirely to fakes.
func _detector(agent_case: String = "missing", path_dir: String = "empty", ollama_port: int = -1, openai_port: int = -1, sysfs: String = "sysfs_empty") -> Detector:
	var d := Detector.new()
	d.agent_file_path = _fx.path_join("agent").path_join(agent_case)
	d.path_dirs = PackedStringArray([_fx.path_join("path").path_join(path_dir)])
	d.ollama_port = _closed_port if ollama_port < 0 else ollama_port
	d.openai_port = _closed_port if openai_port < 0 else openai_port
	d.http_timeout_ms = TIMEOUT_MS
	d.sysfs_root = _fx.path_join(sysfs)
	return d


func _detect(d: Detector) -> Result:
	var result := d.detect()
	_results.append(result)
	return result


func _now() -> int:
	return _fake_now


func _smi_runs_logged() -> PackedStringArray:
	if not FileAccess.file_exists(_smi_log):
		return PackedStringArray()
	return FileAccess.get_file_as_string(_smi_log).split("\n", false)


func _source_files(dir: String, out: PackedStringArray) -> void:
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd") or file.ends_with(".tscn"):
			out.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		_source_files(dir.path_join(sub), out)


func _safety_checks() -> void:
	var source := FileAccess.get_file_as_string(DETECTOR_PATH)
	var found := PackedStringArray()
	for call in FORBIDDEN_CALLS:
		if source.contains(call):
			found.append(call)
	_check("the detector never runs, kills, writes or connects anything beyond its two named uses", found.is_empty(), ", ".join(found))
	_check("its one program start is the non-blocking pipe for nvidia-smi, with the fixed query arguments", source.count("OS.execute_with_pipe(") == 1 and source.contains("OS.execute_with_pipe(path, NVIDIA_SMI_ARGS, false)") and Array(Detector.NVIDIA_SMI_ARGS) == EXPECTED_SMI_ARGS)
	_check("its one network connection goes to the constant 127.0.0.1", source.count("connect_to_host(") == 1 and source.contains("connect_to_host(LOCALHOST, port)") and Detector.LOCALHOST == "127.0.0.1")
	_check("every file it opens, it opens for reading", source.count("FileAccess.open(") == 2 and source.count("FileAccess.open(path, FileAccess.READ)") == 2)
	var users := PackedStringArray()
	var files := PackedStringArray()
	for dir in SCAN_DIRS:
		_source_files(dir, files)
	for file in files:
		if file.begins_with("res://scripts/ai/"):
			continue
		if FileAccess.get_file_as_string(file).contains("scripts/ai/"):
			users.append(file)
	_check("nothing outside scripts/ai uses the detector yet: it is not wired into any scene", users.is_empty(), ", ".join(users))


func _agent_checks() -> void:
	var expect := {
		"missing": [Result.AgentState.UNSET, ""],
		"empty": [Result.AgentState.UNSET, ""],
		"known": [Result.AgentState.KNOWN, "claude"],
		"known_padded": [Result.AgentState.KNOWN, "codex"],
		"multiline": [Result.AgentState.KNOWN, "opencode"],
		"unknown": [Result.AgentState.UNKNOWN, ""],
		"junk": [Result.AgentState.UNSET, ""],
		"oversized": [Result.AgentState.UNSET, ""],
		"unreadable_dir": [Result.AgentState.UNSET, ""],
	}
	var wrong := PackedStringArray()
	for case in expect:
		var got := _detector(case).read_agent()
		if got != expect[case]:
			wrong.append("%s gave %s" % [case, got])
	_check("each agent-setting case resolves: known names kept, unknown and unset fall through", wrong.is_empty(), "; ".join(wrong))
	# A file that exists but cannot be opened.
	var locked := _tmp.path_join("unreadable_agent")
	var f := FileAccess.open(locked, FileAccess.WRITE)
	f.store_string("claude\n")
	f.close()
	FileAccess.set_unix_permissions(locked, 0)
	var d := Detector.new()
	d.agent_file_path = locked
	_check("an agent setting that cannot be read counts as unset", d.read_agent() == [Result.AgentState.UNSET, ""])
	var fits := PackedByteArray()
	fits.resize(Detector.AGENT_FILE_MAX_BYTES)
	fits.fill(0x61)
	var over := fits.duplicate()
	over.append(0x61)
	_check("a line of exactly the cap is read, one byte over counts as unset", Detector.parse_agent_line(fits)[0] == Result.AgentState.UNKNOWN and Detector.parse_agent_line(over)[0] == Result.AgentState.UNSET)
	# The real location, under a fake HOME.
	var old_home := OS.get_environment("HOME")
	var home := _tmp.path_join("home")
	DirAccess.make_dir_recursive_absolute(home.path_join(".config/omarchy/defaults"))
	var g := FileAccess.open(home.path_join(Detector.AGENT_FILE_UNDER_HOME), FileAccess.WRITE)
	g.store_string("gemini\n")
	g.close()
	OS.set_environment("HOME", home)
	var by_default := Detector.new().read_agent()
	OS.unset_environment("HOME")
	var no_home := Detector.new().read_agent()
	OS.set_environment("HOME", old_home)
	_check("with no path given it reads HOME/.config/omarchy/defaults/agent, and no HOME is unset", by_default == [Result.AgentState.KNOWN, "gemini"] and no_home == [Result.AgentState.UNSET, ""], "%s, %s" % [by_default, no_home])


func _cli_checks() -> void:
	var d := _detector("known", "with_agent")
	_check("an executable agent command on the PATH is present", d.cli_present("claude"))
	_check("a non-executable file, a directory and a missing command are absent", not d.cli_present("codex") and not d.cli_present("opencode") and not d.cli_present("gemini"))
	_check("unknown names and paths are refused", not d.cli_present("notarealagent") and not d.cli_present("../with_agent/claude") and d.find_command("with_agent/claude") == "")
	var relative := Detector.new()
	relative.path_dirs = PackedStringArray(["", ".", "tests/fixtures/ai/path/with_agent"])
	_check("relative PATH entries are skipped", not relative.cli_present("claude"))
	_check("an empty PATH directory has no agent", not _detector("known", "empty").cli_present("claude"))


func _timed_probe(d: Detector, which: String) -> Array:
	var start := Time.get_ticks_msec()
	var got: Dictionary = d.probe_ollama() if which == "ollama" else d.probe_openai()
	return [got, Time.get_ticks_msec() - start]


func _server_checks() -> void:
	_server_mode = "full"
	var full := _detect(_detector("missing", "empty", _port, _port))
	_check("a fake Ollama answers with its model count and a latency", full.ollama_reachable and full.ollama_model_count == 3 and full.ollama_latency_ms >= 0, "count %d, latency %d" % [full.ollama_model_count, full.ollama_latency_ms])
	_check("a fake OpenAI-compatible server answers with its model count and a latency", full.openai_reachable and full.openai_model_count == 2 and full.openai_latency_ms >= 0, "count %d, latency %d" % [full.openai_model_count, full.openai_latency_ms])
	_check("no model name appears anywhere in the result", not str(full).contains(FAKE_MODEL_WORD))
	_server_mode = "empty"
	var empty := _detect(_detector("missing", "empty", _port, _port))
	_check("servers listing no models are reachable with a count of 0", empty.ollama_reachable and empty.ollama_model_count == 0 and empty.openai_reachable and empty.openai_model_count == 0)
	var closed := _detector()
	var closed_ollama := _timed_probe(closed, "ollama")
	var closed_openai := _timed_probe(closed, "openai")
	_check("a closed port is unreachable, at once", not closed_ollama[0]["reachable"] and not closed_openai[0]["reachable"] and closed_ollama[1] < TIMEOUT_MS and closed_openai[1] < TIMEOUT_MS, "%d ms, %d ms" % [closed_ollama[1], closed_openai[1]])
	_server_mode = "hang"
	var hang := _detector("missing", "empty", _port, _port)
	var hang_ollama := _timed_probe(hang, "ollama")
	var hang_openai := _timed_probe(hang, "openai")
	print("AI DETECTOR hanging server: Ollama gave up after %d ms, OpenAI-compatible after %d ms, timeout %d ms" % [hang_ollama[1], hang_openai[1], TIMEOUT_MS])
	_check("a server that never answers is unreachable within the timeout", not hang_ollama[0]["reachable"] and not hang_openai[0]["reachable"] and hang_ollama[1] >= TIMEOUT_MS and hang_ollama[1] < TIMEOUT_MS + TIMEOUT_SLACK_MS and hang_openai[1] >= TIMEOUT_MS and hang_openai[1] < TIMEOUT_MS + TIMEOUT_SLACK_MS)
	var bad := Detector.new()
	bad.ollama_port = 0
	bad.openai_port = Detector.PORT_LAST + 1
	_check("ports outside 1 to 65535 are refused without connecting", not bad.probe_ollama()["reachable"] and not bad.probe_openai()["reachable"])
	_server_mode = "full"


func _gpu_checks() -> void:
	var sysfs := _detector("missing", "gpu", -1, -1, "sysfs")
	var a := sysfs.poll_gpu()
	_check("the fake /sys tree is read: the first card that reports, in MiB and whole degrees", a["available"] and a["source"] == "sysfs" and a["util_percent"] == 42 and a["vram_used_mib"] == 2048 and a["vram_total_mib"] == 8192 and a["temp_c"] == 55, str(a))
	_check("with /sys answering, nvidia-smi is never run", sysfs.nvidia_smi_runs() == 0 and _smi_runs_logged().is_empty())
	var smi := _detector("missing", "gpu")
	smi.rate_clock = _now
	_fake_now = 10000
	var b := smi.poll_gpu()
	_check("the stub nvidia-smi is read: the first GPU's line", b["available"] and b["source"] == "nvidia-smi" and b["util_percent"] == 63 and b["vram_used_mib"] == 3072 and b["vram_total_mib"] == 12282 and b["temp_c"] == 58, str(b))
	var logged := _smi_runs_logged()
	_check("nvidia-smi got exactly the query-only arguments, nothing else", Array(logged) == EXPECTED_SMI_ARGS + ["--"], ", ".join(logged))
	var runs := PackedInt32Array()
	for t in [10500, 10999, 11000, 11001, 11999, 12000]:
		_fake_now = t
		smi.poll_gpu()
		runs.append(smi.nvidia_smi_runs())
	_check("poll_gpu reads at most once per second, and hands back the last reading in between", Array(runs) == [1, 1, 2, 2, 2, 3] and _smi_runs_logged().count("--") == 3, "runs after each poll: %s" % runs)
	var neither := _detector().poll_gpu()
	_check("with neither source, gpu_available is false", not neither["available"] and neither["source"] == "none")
	var not_exec := _detector()
	not_exec.nvidia_smi_path = _fx.path_join("path/with_agent/codex")
	_check("a non-executable nvidia-smi is refused unrun", not not_exec.poll_gpu()["available"] and not_exec.nvidia_smi_runs() == 0)
	var parsed := Detector.parse_nvidia_smi("[N/A], 512, 4096, [N/A]\n")
	_check("nvidia-smi fields it cannot give become -1", parsed["available"] and parsed["util_percent"] == -1 and parsed["vram_total_mib"] == 4096 and parsed["temp_c"] == -1)
	_check("output that is not nvidia-smi's CSV gives no GPU", not Detector.parse_nvidia_smi("garbage\n")["available"] and not Detector.parse_nvidia_smi("")["available"])
	var with_gpu := _detect(_detector("missing", "gpu", -1, -1, "sysfs"))
	_check("detect() carries the GPU reading into the result", with_gpu.gpu_available and with_gpu.gpu_source == "sysfs" and with_gpu.gpu_temp_c == 55)


func _resolver_checks() -> void:
	_server_mode = "full"
	var cases := [
		["known agent with its command beats a server", "known", "with_agent", _port, _port, Result.Source.AGENT, "claude"],
		["known agent without its command falls to Ollama", "known", "empty", _port, _port, Result.Source.LOCAL_SERVER, "ollama"],
		["unknown agent falls to Ollama", "unknown", "with_agent", _port, _port, Result.Source.LOCAL_SERVER, "ollama"],
		["unset agent with only the OpenAI-compatible server", "missing", "empty", -1, _port, Result.Source.LOCAL_SERVER, "openai-compatible"],
		["unset agent and no server is the scripted guide, AI off", "missing", "empty", -1, -1, Result.Source.SCRIPTED, "ai-off"],
	]
	for c in cases:
		var r := _detect(_detector(c[1], c[2], c[3], c[4]))
		_check("fallback order: " + c[0], r.source == c[5] and r.source_name == c[6], "%s %s" % [Result.Source.keys()[r.source], r.source_name])
	_server_mode = "empty"
	var empty := _detect(_detector("unknown", "with_agent", _port, _port))
	_check("fallback order: servers with no models are skipped, to the scripted guide", empty.source == Result.Source.SCRIPTED and empty.source_name == "ai-off")
	_server_mode = "full"
	var unknown_count := Result.new()
	unknown_count.ollama_reachable = true
	unknown_count.ollama_model_count = -1
	unknown_count.openai_reachable = true
	unknown_count.openai_model_count = 1
	Detector.resolve(unknown_count)
	_check("fallback order: an Ollama whose models could not be counted is skipped", unknown_count.source_name == "openai-compatible")


func _async_checks() -> void:
	_server_mode = "hang"
	var d := _detector("missing", "empty", _port, _port)
	_check("wait() before start() returns null", d.wait() == null and not d.is_done())
	var start := Time.get_ticks_msec()
	var started := d.start()
	var again := d.start()
	var frames := 0
	while not d.is_done():
		await process_frame
		frames += 1
	var elapsed := Time.get_ticks_msec() - start
	var result := d.wait()
	_results.append(result)
	print("AI DETECTOR async: done in %d ms against a hanging server while the main loop ticked %d frames" % [elapsed, frames])
	_check("start() runs the detection on a worker: the main loop keeps ticking", started == OK and again == ERR_ALREADY_IN_USE and frames > 10 and result != null and result.source_name == "ai-off")
	_check("wait() returns the same result every call, and is_done() stays true", d.wait() == result and d.is_done())
	# Dropped before wait(), mid-probe against the hanging server: it must join its worker,
	# which runs on its own copy, instead of freeing an unjoined thread or the worker's object.
	# Its GPU read uses the stub, so one more logged run proves the worker finished its work.
	var dropped := _detector("missing", "gpu", _port, _port)
	var logged_before := _smi_runs_logged().count("--")
	dropped.start()
	var drop_start := Time.get_ticks_msec()
	dropped = null
	var drop_ms := Time.get_ticks_msec() - drop_start
	var logged_after := _smi_runs_logged().count("--")
	print("AI DETECTOR dropped mid-probe: joined its worker in %d ms, which finished its detection (%d nvidia-smi run logged)" % [drop_ms, logged_after - logged_before])
	_check("a detector dropped mid-probe joins its worker, which still finishes, within the probe timeouts", drop_ms < 2 * TIMEOUT_MS + TIMEOUT_SLACK_MS and logged_after == logged_before + 1)
	_server_mode = "full"
	# The worker and its detector share one GPU rate limit.
	var shared := _detector("missing", "gpu")
	shared.rate_clock = _now
	_fake_now = 50000
	var runs_before := shared.nvidia_smi_runs()
	shared.start()
	while not shared.is_done():
		await process_frame
	var on_worker := shared.wait()
	_results.append(on_worker)
	var after_worker := shared.nvidia_smi_runs()
	var on_parent := shared.poll_gpu()
	_check("a GPU read on the worker counts against its detector's once-per-second limit", runs_before == 0 and after_worker == 1 and shared.nvidia_smi_runs() == 1 and on_worker.gpu_source == "nvidia-smi" and on_parent["util_percent"] == on_worker.gpu_util_percent)
	var mark_exists := FileAccess.file_exists(_exec_mark)
	_check("the stub agent CLI was never executed by any detection", not mark_exists)


func _privacy_checks() -> void:
	var forbidden := PackedStringArray([_fx, ProjectSettings.globalize_path("res://"), _tmp, FAKE_MODEL_WORD, Detector.LOCALHOST, "notarealagent", "0.0.0-fake"])
	for env in ["HOME", "USER", "LOGNAME"]:
		var value := OS.get_environment(env)
		if value.length() > 2:
			forbidden.append(value)
	var hostname := FileAccess.get_file_as_string("/proc/sys/kernel/hostname").strip_edges()
	if hostname.length() > 2:
		forbidden.append(hostname)
	var leaks := 0
	for result in _results:
		var text := str(result)
		if text.contains("/"):
			leaks += 1
			continue
		for word in forbidden:
			if text.contains(word):
				leaks += 1
				break
	_check("no result's string form holds a path, a user or host name, a model name or the raw setting", _results.size() >= 10 and leaks == 0, "%d results, %d with a leak" % [_results.size(), leaks])
