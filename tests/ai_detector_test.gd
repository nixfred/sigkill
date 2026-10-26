extends SceneTree
## Headless AI source detector test for SIGKILL. scripts/check.sh runs it, and any FAIL
## exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/ai_detector_test.gd
##
## Everything it touches is a fake: the agent settings, PATH, /sys tree and stubs under
## tests/fixtures/ai, and fake model servers on 127.0.0.1 on random free ports, run on
## their own thread. Every detector here points nvidia_smi_path at a stub or at nothing,
## so the real nvidia-smi is never run; no real agent is called and no real model server
## is reached. The only files written are the stubs' logs and one unreadable-file case, in
## a fresh temporary folder that the test removes at the end.

const Detector = preload("res://scripts/ai/ai_source_detector.gd")
const Result = preload("res://scripts/ai/ai_source_result.gd")
const DETECTOR_PATH := "res://scripts/ai/ai_source_detector.gd"
const FIXTURES := "res://tests/fixtures/ai"
const TIMEOUT_MS := 300
## Generous: proves a wait ended, not how fast a loaded machine schedules threads.
const WATCHDOG_MS := 3000
const SLOW_SMI_TIMEOUT_MS := 200
## Timeout for the checks that time a timeout. Long enough that scheduling noise on a loaded
## machine is small beside it; the upper bound of twice it still catches a timeout 4x late.
const HANG_TIMEOUT_MS := 1000
## A long timeout for the cancel checks, so a cancel that waits for it is plain to see.
const LONG_TIMEOUT_MS := 2000
## Pause between polls while the test waits on an observed state, in milliseconds.
const WAIT_STEP_MS := 10
## A drip server sends one byte per this many milliseconds.
const DRIP_EVERY_MS := 20
## Entries in the oversized but otherwise valid model list.
const HUGE_ENTRIES := 40000
const FULL_TAGS := '{"models":[{"name":"fake-model-alpha"},{"name":"fake-model-beta"},{"name":"fake-model-gamma"}]}'
const FULL_V1 := '{"object":"list","data":[{"id":"fake-model-alpha"},{"id":"fake-model-beta"}]}'
const FAKE_MODEL_WORD := "fake-model"
const FLOOD_LIMIT_BYTES := 2097152
const FLOOD_CHUNK := 16384
const EXPECTED_SMI_ARGS := ["--query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu", "--format=csv,noheader,nounits"]
const SCAN_DIRS := ["res://scripts", "res://scenes"]
const FORBIDDEN_CALLS := ["OS.execute(", "OS.create_process", "OS.create_instance", "OS.shell_open", "OS.shell_show_in_file_manager", "OS.kill", "HTTPRequest", "HTTPClient", "TCPServer", "UDPServer", "PacketPeerUDP", "WebSocket", "set_unix_permissions", "FileAccess.WRITE", "DirAccess.remove", "make_dir", "\"omarchy", "find_command(NVIDIA", "JSON.new", "JSON.parse"]

var _fails := 0
var _checks := 0
var _fx := ""
var _tmp := ""
var _smi_log := ""
var _smi_release := ""
var _smi_done := ""
var _exec_mark := ""
var _huge_body := PackedByteArray()
var _results: Array = []
var _fake_now := 0
var _stop_calls := 0

# Fake servers, served on their own thread. _server answers per its mode; _closer accepts
# and hangs up at once, the test's own "no server here" that nothing else can take.
var _server := TCPServer.new()
var _closer := TCPServer.new()
var _server_thread := Thread.new()
var _server_mutex := Mutex.new()
var _server_stop := false
var _server_mode := "full"
var _accepted := 0
var _port := 0
var _closer_port := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	_fx = ProjectSettings.globalize_path(FIXTURES)
	if not _setup():
		quit(1)
		return
	_safety_checks()
	_parser_checks()
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
	_smi_release = _tmp.path_join("smi_release")
	_smi_done = _tmp.path_join("smi_done")
	_exec_mark = _tmp.path_join("agent_exec_mark.txt")
	OS.set_environment("SIGKILL_TEST_SMI_LOG", _smi_log)
	OS.set_environment("SIGKILL_TEST_SMI_RELEASE", _smi_release)
	OS.set_environment("SIGKILL_TEST_SMI_DONE", _smi_done)
	OS.set_environment("SIGKILL_TEST_EXEC_MARK", _exec_mark)
	# A complete, well-formed model list just over the reader's cap.
	var entries := PackedStringArray()
	for k in HUGE_ENTRIES:
		entries.append('{"name":"%s-%d"}' % [FAKE_MODEL_WORD, k])
	_huge_body = ('{"models":[%s],"data":[%s]}' % [",".join(entries), ",".join(entries)]).to_ascii_buffer()
	if _server.listen(0, Detector.LOCALHOST) != OK or _closer.listen(0, Detector.LOCALHOST) != OK:
		print("FAIL the fake servers could not listen on 127.0.0.1")
		return false
	_port = _server.get_local_port()
	_closer_port = _closer.get_local_port()
	_server_thread.start(_serve)
	return true


func _teardown() -> void:
	_server_mutex.lock()
	_server_stop = true
	_server_mutex.unlock()
	_server_thread.wait_to_finish()
	_server.stop()
	_closer.stop()
	# Only the files this run made, in its own fresh folder.
	for name in ["smi_args.txt", "smi_release", "smi_done", "agent_exec_mark.txt", "unreadable_agent", "home/.config/omarchy/defaults/agent"]:
		var path := _tmp.path_join(name)
		if FileAccess.file_exists(path):
			FileAccess.set_unix_permissions(path, 0x180)  # owner read and write, so it can go
			DirAccess.remove_absolute(path)
	for dir in ["home/.config/omarchy/defaults", "home/.config/omarchy", "home/.config", "home", ""]:
		var path := _tmp.path_join(dir) if dir != "" else _tmp
		if DirAccess.dir_exists_absolute(path):
			DirAccess.remove_absolute(path)


func _set_mode(mode: String) -> void:
	_server_mutex.lock()
	_server_mode = mode
	_server_mutex.unlock()


func _stopping() -> bool:
	_server_mutex.lock()
	var stop := _server_stop
	_server_mutex.unlock()
	return stop


## The mode a new connection gets, read when it is accepted, and the accepted count.
func _accept_mode() -> String:
	_server_mutex.lock()
	var mode := _server_mode
	_accepted += 1
	_server_mutex.unlock()
	return mode


func _accepted_count() -> int:
	_server_mutex.lock()
	var count := _accepted
	_server_mutex.unlock()
	return count


## Takes the first connection to `listener` and keeps it open without answering, or null if
## none arrives before the watchdog.
func _hold_connection(listener: TCPServer) -> StreamPeerTCP:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < WATCHDOG_MS:
		if listener.is_connection_available():
			return listener.take_connection()
		OS.delay_msec(1)
	return null


## Waits, polling, until `ready` returns true or the watchdog passes. True if it did.
func _wait_for(ready: Callable) -> bool:
	var start := Time.get_ticks_msec()
	while not ready.call():
		if Time.get_ticks_msec() - start > WATCHDOG_MS:
			return false
		OS.delay_msec(WAIT_STEP_MS)
	return true


func _body_for(mode: String, path: String) -> PackedByteArray:
	match path:
		Detector.OLLAMA_VERSION_PATH:
			return '{"version":"0.0.0-fake"}'.to_ascii_buffer()
		Detector.OLLAMA_MODELS_PATH, Detector.OPENAI_MODELS_PATH:
			var key := "models" if path == Detector.OLLAMA_MODELS_PATH else "data"
			if mode == "empty":
				return ('{"%s":[]}' % key).to_ascii_buffer()
			if mode == "huge":
				return _huge_body
			if mode == "badutf8":
				var bad := ('{"%s":[{"name":"%s-' % [key, FAKE_MODEL_WORD]).to_ascii_buffer()
				bad.append_array(PackedByteArray([0xFF, 0xFE, 0xC0, 0x80]))
				bad.append_array('"}]}'.to_ascii_buffer())
				return bad
			return (FULL_TAGS if path == Detector.OLLAMA_MODELS_PATH else FULL_V1).to_ascii_buffer()
	return PackedByteArray()


func _reply(mode: String, path: String) -> PackedByteArray:
	var body := _body_for(mode, path)
	var head := ""
	match mode:
		"truncated":
			head = "HTTP/1.0 200 OK\r\nContent-Length: %d\r\n\r\n" % (body.size() + 100)
		"chunked":
			head = "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n"
			var chunked := ("%x\r\n" % body.size()).to_ascii_buffer()
			chunked.append_array(body)
			chunked.append_array("\r\n0\r\n\r\n".to_ascii_buffer())
			body = chunked
		"error500":
			head = "HTTP/1.0 500 Internal Server Error\r\nContent-Length: %d\r\n\r\n" % body.size()
		_:
			var status := "200 OK" if not body.is_empty() else "404 Not Found"
			head = "HTTP/1.1 %s\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % [status, body.size()]
	var out := head.to_ascii_buffer()
	out.append_array(body)
	return out


## The fake servers' loop. Each connection keeps the mode it was accepted in.
func _serve() -> void:
	var conns := []
	var junk := PackedByteArray()
	junk.resize(FLOOD_CHUNK)
	junk.fill(0x61)
	while not _stopping():
		while _closer.is_connection_available():
			_closer.take_connection().disconnect_from_host()
		while _server.is_connection_available():
			var peer_in := _server.take_connection()
			conns.append({"peer": peer_in, "buf": PackedByteArray(), "mode": _accept_mode(), "sent": 0, "flooding": false, "drip": PackedByteArray(), "drip_at": 0})
		for entry in conns.duplicate():
			var peer: StreamPeerTCP = entry["peer"]
			peer.poll()
			if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
				conns.erase(entry)
				continue
			var drip: PackedByteArray = entry["drip"]
			if not drip.is_empty():
				# A whole, valid answer, one byte at a time: it never arrives within the deadline.
				if Time.get_ticks_msec() >= entry["drip_at"]:
					peer.put_data(drip.slice(0, 1))
					entry["drip"] = drip.slice(1)
					entry["drip_at"] = Time.get_ticks_msec() + DRIP_EVERY_MS
				continue
			if entry["flooding"]:
				# Headers that never end, until the client hangs up or the limit.
				var sent: Array = peer.put_partial_data(junk)
				entry["sent"] += sent[1] if sent[0] == OK else 0
				if sent[0] != OK or entry["sent"] > FLOOD_LIMIT_BYTES:
					peer.disconnect_from_host()
					conns.erase(entry)
				continue
			var waiting := peer.get_available_bytes()
			if waiting > 0:
				var buf: PackedByteArray = entry["buf"]
				buf.append_array(peer.get_data(waiting)[1])
				entry["buf"] = buf
			var text: String = (entry["buf"] as PackedByteArray).get_string_from_ascii()
			var mode: String = entry["mode"]
			if mode == "hang" or not text.contains("\r\n\r\n"):
				continue
			if mode == "flood":
				peer.put_data("HTTP/1.0 200 OK\r\nX-Flood: ".to_ascii_buffer())
				entry["flooding"] = true
				continue
			if mode == "drip":
				entry["drip"] = _reply("full", text.split(" ")[1])
				continue
			peer.put_data(_reply(mode, text.split(" ")[1]))
			peer.disconnect_from_host()
			conns.erase(entry)
		OS.delay_usec(500)
	for entry in conns:
		(entry["peer"] as StreamPeerTCP).disconnect_from_host()


## A detector wired entirely to fakes. Its nvidia-smi is a stub from `smi_dir`, or a path
## that does not exist, never the real one.
func _detector(agent_case: String = "missing", path_dir: String = "empty", ollama_port: int = -1, openai_port: int = -1, sysfs: String = "sysfs_empty", smi_dir: String = "") -> Detector:
	var d := Detector.new()
	d.agent_file_path = _fx.path_join("agent").path_join(agent_case)
	d.path_dirs = PackedStringArray([_fx.path_join("path").path_join(path_dir)])
	d.ollama_port = _closer_port if ollama_port < 0 else ollama_port
	d.openai_port = _closer_port if openai_port < 0 else openai_port
	d.http_timeout_ms = TIMEOUT_MS
	d.sysfs_root = _fx.path_join(sysfs)
	d.nvidia_smi_path = _fx.path_join("path").path_join(smi_dir if smi_dir != "" else "empty").path_join("nvidia-smi")
	return d


func _detect(d: Detector) -> Result:
	var result := d.detect()
	_results.append(result)
	return result


func _now() -> int:
	return _fake_now


## A stop callback that counts its calls and always says stop.
func _stop_now() -> bool:
	_stop_calls += 1
	return true


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
	_check("the detector never runs, kills, writes, listens or connects anything beyond its two named uses", found.is_empty(), ", ".join(found))
	_check("its one program start is the non-blocking pipe for nvidia-smi, with the fixed query arguments", source.count("OS.execute_with_pipe(") == 1 and source.contains("OS.execute_with_pipe(path, NVIDIA_SMI_ARGS, false)") and Array(Detector.NVIDIA_SMI_ARGS) == EXPECTED_SMI_ARGS)
	_check("nvidia-smi comes from its fixed system path, never from the PATH", Detector.NVIDIA_SMI_PATH == "/usr/bin/nvidia-smi" and Detector.new().nvidia_smi_path == Detector.NVIDIA_SMI_PATH and _detector().nvidia_smi_path != Detector.NVIDIA_SMI_PATH)
	_check("its one network socket connects only to the constant 127.0.0.1", source.count("StreamPeerTCP.new()") == 1 and source.count("connect_to_host(") == 1 and source.contains("peer.connect_to_host(LOCALHOST, port)") and Detector.LOCALHOST == "127.0.0.1")
	_check("every file it opens, it opens for reading", source.count("FileAccess.open(") == 2 and source.count("FileAccess.open(path, FileAccess.READ)") == 2)
	_check("it never hands an answer to Godot's JSON parser or decodes it as text, only plain ASCII keys", source.count("get_string_from_utf8(") == 0 and source.contains("ascii_key(b.slice(key_start, key_end))"))
	var users := PackedStringArray()
	var files := PackedStringArray()
	for dir in SCAN_DIRS:
		_source_files(dir, files)
	for file in files:
		if file.begins_with("res://scripts/ai/"):
			continue
		if FileAccess.get_file_as_string(file).contains("scripts/ai/"):
			users.append(file)
	users.sort()
	_check("outside scripts/ai only the boot screen (C10), the guide link and the guide HUD (C11) use the detector", Array(users) == ["res://scripts/boot/boot_sequence.gd", "res://scripts/boot/guide_settings.gd", "res://scripts/guide/guide_link.gd", "res://scripts/hud/guide_hud.gd"], ", ".join(users))


func _http(head: String, body: PackedByteArray) -> PackedByteArray:
	var raw := head.to_ascii_buffer()
	raw.append_array(body)
	return raw


## The response reader, the JSON scanner and number parsing on crafted bytes. None of these
## may print; scripts/check.sh fails on any error line.
func _parser_checks() -> void:
	var ok_body := '{"data":[1,2]}'.to_ascii_buffer()
	var with_length = Detector.parse_http_body(_http("HTTP/1.0 200 OK\r\nContent-Length: %d\r\n\r\n" % ok_body.size(), ok_body))
	var without_length = Detector.parse_http_body(_http("HTTP/1.1 200 OK\r\nServer: fake\r\n\r\n", ok_body))
	_check("a whole 200 answer gives its body, with or without Content-Length", with_length == ok_body and without_length == ok_body)
	var refused := PackedStringArray()
	var cases := {
		"truncated": _http("HTTP/1.0 200 OK\r\nContent-Length: 99\r\n\r\n", ok_body),
		"padded": _http("HTTP/1.0 200 OK\r\nContent-Length: 3\r\n\r\n", ok_body),
		"two lengths": _http("HTTP/1.0 200 OK\r\nContent-Length: %d\r\nContent-Length: 1\r\n\r\n" % ok_body.size(), ok_body),
		"chunked": _http("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n", ok_body),
		"not 200": _http("HTTP/1.0 404 Not Found\r\n\r\n", ok_body),
		"2000 is not 200": _http("HTTP/1.1 2000 OK\r\n\r\n", ok_body),
		"not http": _http("SSH-2.0-fake\r\n\r\n", ok_body),
		"no header end": _http("HTTP/1.0 200 OK\r\nX: y\r\n", ok_body),
		"header without colon": _http("HTTP/1.0 200 OK\r\nbroken\r\n\r\n", ok_body),
		"space before colon": _http("HTTP/1.0 200 OK\r\nContent-Length : %d\r\n\r\n" % ok_body.size(), ok_body),
		"space in name": _http("HTTP/1.0 200 OK\r\nBad Name: x\r\n\r\n", ok_body),
		"bare LF in a line": _http("HTTP/1.0 200 OK\r\nX: a\nY: b\r\n\r\n", ok_body),
		"overflowing length": _http("HTTP/1.0 200 OK\r\nContent-Length: 99999999999999999999999\r\n\r\n", ok_body),
		"bad utf-8": _http("HTTP/1.0 200 OK\r\n\r\n", PackedByteArray([0x7B, 0x22, 0xFF, 0x22, 0x3A, 0x31, 0x7D])),
		"nul in body": _http("HTTP/1.0 200 OK\r\n\r\n", PackedByteArray([0x7B, 0x7D, 0x00])),
	}
	var high_header := "HTTP/1.0 200 OK\r\nX: ".to_ascii_buffer()
	high_header.append_array(PackedByteArray([0xC3, 0xA9]))
	high_header.append_array("\r\n\r\n{}".to_ascii_buffer())
	cases["non-ascii header"] = high_header
	for name in cases:
		if Detector.parse_http_body(cases[name]) != null:
			refused.append(name)
	_check("truncated, padded, chunked, non-200, malformed-header, overflowing, bad UTF-8 and NUL answers are all refused", refused.is_empty(), "accepted: " + ", ".join(refused))
	var shape = Detector.json_top_level('{"version":"0.0.0-fake","models":[{"name":"a"},{"name":"b\\"q"}],"n":-1.5e3,"ok":true,"nothing":null,"deep":{"x":[[]]}}'.to_utf8_buffer())
	_check("the JSON scanner reports each top-level key's kind and an array's count", shape is Dictionary and shape["version"]["kind"] == "string" and shape["models"]["kind"] == "array" and shape["models"]["count"] == 2 and shape["n"]["kind"] == "number" and shape["ok"]["kind"] == "literal" and shape["deep"]["kind"] == "object", str(shape))
	# Valid JSON that Godot's own parser prints about: the scanner takes it quietly.
	var quiet_nul = Detector.json_top_level('{"data":["\\u0000"]}'.to_ascii_buffer())
	var quiet_exponent = Detector.json_top_level('{"data":[1e999999]}'.to_ascii_buffer())
	_check("valid JSON with a \\u0000 escape or a huge exponent is scanned quietly", quiet_nul is Dictionary and quiet_nul["data"]["count"] == 1 and quiet_exponent is Dictionary and quiet_exponent["data"]["count"] == 1)
	var not_json := PackedStringArray()
	var json_cases := {
		"an array at the top": "[1,2]",
		"trailing garbage": '{"a":1} x',
		"unterminated string": '{"a":"b}',
		"bad escape": '{"a":"\\x"}',
		"short unicode escape": '{"a":"\\u12"}',
		"leading zero": '{"a":01}',
		"bare dot": '{"a":1.}',
		"trailing comma": '{"a":[1,]}',
		"missing colon": '{"a" 1}',
		"unquoted key": '{a:1}',
		"misspelled literal": '{"a":tru}',
		"html": "<html>",
		"empty": "",
		"too deep": '{"a":' + "[".repeat(80) + "]".repeat(80) + "}",
	}
	for name in json_cases:
		if Detector.json_top_level(String(json_cases[name]).to_ascii_buffer()) != null:
			not_json.append(name)
	_check("the JSON scanner refuses anything but one well-formed object", not_json.is_empty(), "accepted: " + ", ".join(not_json))
	var pretty = Detector.json_top_level('{\n\t"data": [\r\n\t\t1,\n\t\t2\n\t]\n}\n'.to_ascii_buffer())
	var raw_controls := PackedStringArray()
	for control in [0x01, 0x09, 0x0A, 0x1F]:
		var doc := '{"data":["a'.to_ascii_buffer()
		doc.append(control)
		doc.append_array('b"]}'.to_ascii_buffer())
		if Detector.json_top_level(doc) != null:
			raw_controls.append("0x%02x" % control)
	_check("whitespace between tokens is fine, but a raw control byte inside a string is refused", pretty is Dictionary and pretty["data"]["count"] == 2 and raw_controls.is_empty(), "accepted: " + ", ".join(raw_controls))
	var escaped_key = Detector.json_top_level('{"\\u0064ata":[1,2,3],"\\u00e9":[1],"mo\\/dels":[]}'.to_ascii_buffer())
	_check("top-level keys are matched with their escapes undone; keys that are not plain ASCII are skipped", escaped_key is Dictionary and escaped_key.has("data") and escaped_key["data"]["count"] == 3 and escaped_key.has("mo/dels") and escaped_key.size() == 2, str(escaped_key))
	# A long string of escapes: the closing quote is remembered, so the searches cover the
	# body about once. Measured as bytes searched, not time, so a loaded machine cannot
	# fail it; the watchdog only catches a hang.
	var escapes := ('{"data":["%s"]}' % "\\n".repeat(100000)).to_ascii_buffer()
	var stats := {}
	var t_escapes := Time.get_ticks_msec()
	var escaped_ok = Detector.json_top_level(escapes, Callable(), stats)
	var escape_ms := Time.get_ticks_msec() - t_escapes
	print("AI DETECTOR scanner: a %d byte string of escapes took %d bytes of searching, %d ms" % [escapes.size(), stats["searched"], escape_ms])
	_check("a string of 100000 escapes is scanned in linear work", escaped_ok is Dictionary and stats["searched"] <= 2 * escapes.size() and escape_ms < WATCHDOG_MS, "%d bytes searched for a %d byte body" % [stats["searched"], escapes.size()])
	# A huge key is skipped without decoding, at once.
	var long_key := ('{"%s":1,"data":[1]}' % "k".repeat(900000)).to_ascii_buffer()
	var key_stats := {}
	var t_key := Time.get_ticks_msec()
	var long_key_shape = Detector.json_top_level(long_key, Callable(), key_stats)
	var key_ms := Time.get_ticks_msec() - t_key
	_check("a 900000-character key is skipped without being decoded", long_key_shape is Dictionary and long_key_shape.size() == 1 and long_key_shape["data"]["count"] == 1 and key_stats["searched"] <= 2 * long_key.size() and key_ms < WATCHDOG_MS, "%d ms" % key_ms)
	# A cancel stops even a million-digit number at once.
	_stop_calls = 0
	var digits := ('{"data":[%s]}' % "1".repeat(1000000)).to_ascii_buffer()
	var t_cancel := Time.get_ticks_msec()
	var cancelled_scan = Detector.json_top_level(digits, _stop_now)
	var cancel_scan_ms := Time.get_ticks_msec() - t_cancel
	_check("a cancel stops the scanner inside a long number at once", cancelled_scan == null and _stop_calls == 1 and cancel_scan_ms < WATCHDOG_MS, "%d stop calls, %d ms" % [_stop_calls, cancel_scan_ms])
	var big_header := "HTTP/1.0 200 OK\r\nX-Big: %s\r\n\r\n" % "a".repeat(Detector.HTTP_HEADER_MAX_BYTES)
	_check("a header section over 16 KiB is refused", Detector.parse_http_body(_http(big_header, ok_body)) == null)
	var good_utf8 := [PackedByteArray([0x61]), PackedByteArray([0xC3, 0xA9]), PackedByteArray([0xE2, 0x82, 0xAC]), PackedByteArray([0xF0, 0x9F, 0x98, 0x80])]
	var bad_utf8 := [PackedByteArray([0xC0, 0x80]), PackedByteArray([0xED, 0xA0, 0x80]), PackedByteArray([0xF4, 0x90, 0x80, 0x80]), PackedByteArray([0xE2, 0x82]), PackedByteArray([0x80]), PackedByteArray([0xE0, 0x80, 0x80]), PackedByteArray([0x00])]
	var utf8_ok := true
	for b in good_utf8:
		utf8_ok = utf8_ok and Detector.is_utf8_text(b)
	for b in bad_utf8:
		utf8_ok = utf8_ok and not Detector.is_utf8_text(b)
	_check("the UTF-8 check takes valid text and refuses overlong forms, surrogates, too-high, cut-off, stray and NUL bytes", utf8_ok)
	_check("numbers: plain digits only, and nothing long enough to overflow", Detector.whole_number("123") == 123 and Detector.whole_number("") == -1 and Detector.whole_number("-5") == -1 and Detector.whole_number("12a") == -1 and Detector.whole_number("9999999999999999") == -1 and Detector.whole_number("999999999999999") == 999999999999999)
	var huge := Detector.parse_nvidia_smi("999999999999999999999999999999, 1, 2, 3\n")
	var out_of_range := Detector.parse_nvidia_smi("150, 1, 2, 300\n")
	_check("nvidia-smi readings that overflow or fall out of range become -1, without an error", huge["available"] and huge["util_percent"] == -1 and huge["vram_total_mib"] == 2 and out_of_range["util_percent"] == -1 and out_of_range["temp_c"] == -1)
	var parsed := Detector.parse_nvidia_smi("[N/A], 512, 4096, [N/A]\n")
	_check("nvidia-smi fields it cannot give become -1", parsed["available"] and parsed["util_percent"] == -1 and parsed["vram_total_mib"] == 4096 and parsed["temp_c"] == -1)
	_check("output that is not nvidia-smi's CSV gives no GPU", not Detector.parse_nvidia_smi("garbage\n")["available"] and not Detector.parse_nvidia_smi("")["available"])


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
	# The real location, under a fake HOME, including a first line of exactly the cap.
	var old_home := OS.get_environment("HOME")
	var home := _tmp.path_join("home")
	DirAccess.make_dir_recursive_absolute(home.path_join(".config/omarchy/defaults"))
	var setting := home.path_join(Detector.AGENT_FILE_UNDER_HOME)
	var g := FileAccess.open(setting, FileAccess.WRITE)
	g.store_string("gemini\n")
	g.close()
	OS.set_environment("HOME", home)
	var by_default := Detector.new().read_agent()
	var h := FileAccess.open(setting, FileAccess.WRITE)
	h.store_string(" ".repeat(Detector.AGENT_FILE_MAX_BYTES - 4) + "muse\nsecond line\n")
	h.close()
	var exact_cap := Detector.new().read_agent()
	OS.unset_environment("HOME")
	var no_home := Detector.new().read_agent()
	OS.set_environment("HOME", old_home)
	_check("with no path given it reads HOME/.config/omarchy/defaults/agent, and no HOME is unset", by_default == [Result.AgentState.KNOWN, "gemini"] and no_home == [Result.AgentState.UNSET, ""], "%s, %s" % [by_default, no_home])
	_check("a first line of exactly the cap, then more lines, still reads its value", exact_cap == [Result.AgentState.KNOWN, "muse"], str(exact_cap))


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
	_set_mode("full")
	var full := _detect(_detector("missing", "empty", _port, _port))
	_check("a fake Ollama answers with its model count and a latency", full.ollama_reachable and full.ollama_model_count == 3 and full.ollama_latency_ms >= 0, "count %d, latency %d" % [full.ollama_model_count, full.ollama_latency_ms])
	_check("a fake OpenAI-compatible server answers with its model count and a latency", full.openai_reachable and full.openai_model_count == 2 and full.openai_latency_ms >= 0, "count %d, latency %d" % [full.openai_model_count, full.openai_latency_ms])
	_check("no model name appears anywhere in the result", not str(full).contains(FAKE_MODEL_WORD))
	_set_mode("empty")
	var empty := _detect(_detector("missing", "empty", _port, _port))
	_check("servers listing no models are reachable with a count of 0", empty.ollama_reachable and empty.ollama_model_count == 0 and empty.openai_reachable and empty.openai_model_count == 0)
	var hangup := _detector()
	hangup.http_timeout_ms = HANG_TIMEOUT_MS
	var hangup_ollama := _timed_probe(hangup, "ollama")
	_check("a port that hangs up without answering is no server, well before the timeout", not hangup_ollama[0]["reachable"] and not hangup.probe_openai()["reachable"] and hangup_ollama[1] < HANG_TIMEOUT_MS / 2, "%d ms" % hangup_ollama[1])
	var spare := TCPServer.new()
	spare.listen(0, Detector.LOCALHOST)
	var closed := _detector("missing", "empty", spare.get_local_port(), spare.get_local_port())
	closed.http_timeout_ms = HANG_TIMEOUT_MS
	spare.stop()
	var closed_ollama := _timed_probe(closed, "ollama")
	_check("a closed port is unreachable, well before the timeout", not closed_ollama[0]["reachable"] and not closed.probe_openai()["reachable"] and closed_ollama[1] < HANG_TIMEOUT_MS / 2, "%d ms" % closed_ollama[1])
	_set_mode("hang")
	var hang := _detector("missing", "empty", _port, _port)
	hang.http_timeout_ms = HANG_TIMEOUT_MS
	var hang_ollama := _timed_probe(hang, "ollama")
	var hang_openai := _timed_probe(hang, "openai")
	print("AI DETECTOR hanging server: Ollama gave up after %d ms, OpenAI-compatible after %d ms, timeout %d ms" % [hang_ollama[1], hang_openai[1], HANG_TIMEOUT_MS])
	_check("a server that never answers is unreachable once the timeout passes, and not long after", not hang_ollama[0]["reachable"] and not hang_openai[0]["reachable"] and hang_ollama[1] >= HANG_TIMEOUT_MS and hang_openai[1] >= HANG_TIMEOUT_MS and hang_ollama[1] < 2 * HANG_TIMEOUT_MS and hang_openai[1] < 2 * HANG_TIMEOUT_MS)
	var bad_modes := PackedStringArray()
	for mode in ["truncated", "chunked", "error500", "flood"]:
		_set_mode(mode)
		var m := _detector("missing", "empty", _port, _port)
		var o := _timed_probe(m, "ollama")
		var v := _timed_probe(m, "openai")
		if o[0]["reachable"] or v[0]["reachable"] or o[1] > WATCHDOG_MS or v[1] > WATCHDOG_MS:
			bad_modes.append("%s (%s in %d ms, %s in %d ms)" % [mode, o[0]["reachable"], o[1], v[0]["reachable"], v[1]])
	_check("truncated, chunked, error and endlessly flooding answers are no server, within the deadline", bad_modes.is_empty(), "; ".join(bad_modes))
	_set_mode("huge")
	var huge := _detector("missing", "empty", _port, _port)
	var huge_v := _timed_probe(huge, "openai")
	_check("a complete, valid answer over the 1 MiB cap is no server", _huge_body.size() > Detector.HTTP_RESPONSE_MAX_BYTES and not huge_v[0]["reachable"] and huge_v[1] < WATCHDOG_MS, "%d byte body, %d ms" % [_huge_body.size(), huge_v[1]])
	_set_mode("drip")
	var drip := _detector("missing", "empty", _port, _port)
	drip.http_timeout_ms = HANG_TIMEOUT_MS
	var drip_v := _timed_probe(drip, "openai")
	_check("an answer trickling in a byte at a time is no server once the deadline passes", not drip_v[0]["reachable"] and drip_v[1] >= HANG_TIMEOUT_MS and drip_v[1] < 2 * HANG_TIMEOUT_MS, "%d ms" % drip_v[1])
	_set_mode("badutf8")
	var bad_text := _detect(_detector("missing", "empty", _port, _port))
	_check("a model list that is not valid UTF-8 counts nothing and prints nothing", bad_text.ollama_reachable and bad_text.ollama_model_count == -1 and not bad_text.openai_reachable and not str(bad_text).contains(FAKE_MODEL_WORD))
	var bad := Detector.new()
	bad.ollama_port = 0
	bad.openai_port = Detector.PORT_LAST + 1
	_check("ports outside 1 to 65535 are refused without connecting", not bad.probe_ollama()["reachable"] and not bad.probe_openai()["reachable"])
	_set_mode("full")


func _gpu_checks() -> void:
	var sysfs := _detector("missing", "empty", -1, -1, "sysfs", "gpu")
	var smi_base := sysfs.nvidia_smi_runs()
	var a := sysfs.poll_gpu()
	_check("the fake /sys tree is read: the first card that reports, in MiB and whole degrees", a["available"] and a["source"] == "sysfs" and a["util_percent"] == 42 and a["vram_used_mib"] == 2048 and a["vram_total_mib"] == 8192 and a["temp_c"] == 55, str(a))
	_check("with /sys answering, nvidia-smi is never run", sysfs.nvidia_smi_runs() == smi_base and _smi_runs_logged().is_empty())
	var smi := _detector("missing", "empty", -1, -1, "sysfs_empty", "gpu")
	smi.rate_clock = _now
	_fake_now = 10000
	var base := smi.nvidia_smi_runs()
	var b := smi.poll_gpu()
	_check("the stub nvidia-smi is read: the first GPU's line", b["available"] and b["source"] == "nvidia-smi" and b["util_percent"] == 63 and b["vram_used_mib"] == 3072 and b["vram_total_mib"] == 12282 and b["temp_c"] == 58, str(b))
	var logged := _smi_runs_logged()
	_check("nvidia-smi got exactly the query-only arguments, nothing else", Array(logged) == EXPECTED_SMI_ARGS + ["--"], ", ".join(logged))
	var runs := PackedInt32Array()
	for t in [10500, 10999, 11000, 11001, 11999, 12000]:
		_fake_now = t
		smi.poll_gpu()
		runs.append(smi.nvidia_smi_runs() - base)
	_check("poll_gpu reads at most once per second, and hands back the last reading in between", Array(runs) == [1, 1, 2, 2, 2, 3] and _smi_runs_logged().count("--") == 3, "runs after each poll: %s" % runs)
	# Two separate detectors with the same settings share one limit.
	var first := _detector("missing", "empty", -1, -1, "sysfs_empty", "gpu")
	var second := _detector("missing", "empty", -1, -1, "sysfs_empty", "gpu")
	first.rate_clock = _now
	second.rate_clock = _now
	_fake_now = 30000
	# Counted from the stub's own log: real starts, whichever detector made them.
	var shared_base := _smi_runs_logged().count("--")
	first.poll_gpu()
	var second_reading := second.poll_gpu()
	var after_two := _smi_runs_logged().count("--") - shared_base
	_fake_now = 31000
	second.poll_gpu()
	var after_three := _smi_runs_logged().count("--") - shared_base
	_check("separate detectors with the same settings share the once-per-second limit", after_two == 1 and second_reading["util_percent"] == 63 and after_three == 2, "%d nvidia-smi starts after two polls, %d after a third a second later" % [after_two, after_three])
	# An nvidia-smi that hangs: one at a time, never waited on twice, its late answer used.
	var slow := _detector("missing", "empty", -1, -1, "sysfs_empty", "gpu_slow")
	slow.rate_clock = _now
	slow.nvidia_smi_timeout_ms = SLOW_SMI_TIMEOUT_MS
	_fake_now = 40000
	var t0 := Time.get_ticks_msec()
	var timed_out := slow.poll_gpu()
	var t1 := Time.get_ticks_msec()
	_fake_now = 41000
	# Code that waited on the hung one again would now wait twice the watchdog: correct code
	# only checks on it and returns at once.
	slow.nvidia_smi_timeout_ms = 2 * WATCHDOG_MS
	var still_running := slow.poll_gpu()
	var t2 := Time.get_ticks_msec()
	var runs_while_hung := slow.nvidia_smi_runs()
	# Release the stub, then poll within the same second, so no poll is due: the late answer
	# must still be collected.
	var release := FileAccess.open(_smi_release, FileAccess.WRITE)
	release.close()
	var late := {}
	var poll_start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - poll_start < WATCHDOG_MS:
		late = slow.poll_gpu()
		if late["available"]:
			break
		OS.delay_msec(WAIT_STEP_MS)
	var runs_after_late := slow.nvidia_smi_runs()
	print("AI DETECTOR hung nvidia-smi: gave up after %d ms, next poll returned in %d ms without starting another, late answer %s" % [t1 - t0, t2 - t1, late["util_percent"]])
	_check("a hung nvidia-smi is given up at the deadline, never run twice at once, and its late answer is used", not timed_out["available"] and t1 - t0 >= SLOW_SMI_TIMEOUT_MS and t1 - t0 < WATCHDOG_MS and not still_running["available"] and t2 - t1 < WATCHDOG_MS and runs_while_hung == 1 and late["available"] and late["util_percent"] == 21 and runs_after_late == 1)
	# Dropping the last detector reaps an nvidia-smi that has exited since, with no poll.
	DirAccess.remove_absolute(_smi_release)
	DirAccess.remove_absolute(_smi_done)
	var reaped := _detector("missing", "empty", -1, -1, "sysfs_empty", "gpu_slow")
	reaped.rate_clock = _now
	reaped.nvidia_smi_timeout_ms = SLOW_SMI_TIMEOUT_MS
	_fake_now = 60000
	reaped.poll_gpu()
	var peer := _detector("missing", "empty", -1, -1, "sysfs_empty", "gpu_slow")
	peer.rate_clock = _now
	var outstanding_before: int = peer._gpu_state().smi_pid
	var free_release := FileAccess.open(_smi_release, FileAccess.WRITE)
	free_release.close()
	# Wait until it has really exited; the done mark comes just before that.
	var exited := _wait_for(func() -> bool: return FileAccess.file_exists(_smi_done) and not OS.is_process_running(outstanding_before))
	reaped = null
	var outstanding_after: int = peer._gpu_state().smi_pid
	_check("dropping a detector reaps an nvidia-smi that has exited, with no poll needed", outstanding_before != 0 and exited and outstanding_after == 0, "pid set %s, exited %s, cleared %s" % [outstanding_before != 0, exited, outstanding_after == 0])
	var flood := _detector("missing", "empty", -1, -1, "sysfs_empty", "gpu_flood")
	_check("an nvidia-smi that floods its output gives no GPU", not flood.poll_gpu()["available"] and flood.nvidia_smi_runs() == 1)
	var neither := _detector().poll_gpu()
	_check("with neither source, gpu_available is false", not neither["available"] and neither["source"] == "none")
	var not_exec := _detector()
	not_exec.nvidia_smi_path = _fx.path_join("path/with_agent/codex")
	_check("a non-executable nvidia-smi is refused unrun", not not_exec.poll_gpu()["available"] and not_exec.nvidia_smi_runs() == 0)
	var with_gpu := _detect(_detector("missing", "empty", -1, -1, "sysfs", "gpu"))
	_check("detect() carries the GPU reading into the result", with_gpu.gpu_available and with_gpu.gpu_source == "sysfs" and with_gpu.gpu_temp_c == 55)


func _resolver_checks() -> void:
	_set_mode("full")
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
	_set_mode("empty")
	var empty := _detect(_detector("unknown", "with_agent", _port, _port))
	_check("fallback order: servers with no models are skipped, to the scripted guide", empty.source == Result.Source.SCRIPTED and empty.source_name == "ai-off")
	_set_mode("full")
	var unknown_count := Result.new()
	unknown_count.ollama_reachable = true
	unknown_count.ollama_model_count = -1
	unknown_count.openai_reachable = true
	unknown_count.openai_model_count = 1
	Detector.resolve(unknown_count)
	_check("fallback order: an Ollama whose models could not be counted is skipped", unknown_count.source_name == "openai-compatible")


func _async_checks() -> void:
	_set_mode("hang")
	var d := _detector("missing", "empty", _port, _port)
	d.http_timeout_ms = HANG_TIMEOUT_MS
	_check("wait() before start() returns null", d.wait() == null and not d.is_done())
	var start := Time.get_ticks_msec()
	var started := d.start()
	var start_ms := Time.get_ticks_msec() - start
	var again := d.start()
	var frames := 0
	while not d.is_done():
		await process_frame
		frames += 1
	var elapsed := Time.get_ticks_msec() - start
	var result := d.wait()
	_results.append(result)
	print("AI DETECTOR async: start() returned in %d ms, done in %d ms against a hanging server while the main loop ticked %d frames" % [start_ms, elapsed, frames])
	# A start() that ran the probes itself would take two full timeouts before returning.
	_check("start() hands the detection to a worker: it returns at once and the main loop keeps ticking", started == OK and again == ERR_ALREADY_IN_USE and start_ms < HANG_TIMEOUT_MS and frames > 0 and elapsed >= 2 * HANG_TIMEOUT_MS and elapsed < 2 * HANG_TIMEOUT_MS + WATCHDOG_MS and result != null and result.source_name == "ai-off")
	_check("wait() returns the same result every call, and is_done() stays true", d.wait() == result and d.is_done())
	# cancel() ends a detection in the middle of a probe, long before its timeout. The test
	# owns this listener and holds the worker's connection, so the worker is provably inside
	# a request, waiting for an answer, when it is cancelled.
	var c_listener := TCPServer.new()
	c_listener.listen(0, Detector.LOCALHOST)
	var c := _detector("missing", "empty", c_listener.get_local_port(), c_listener.get_local_port())
	c.http_timeout_ms = LONG_TIMEOUT_MS
	c.start()
	var c_held := _hold_connection(c_listener)
	var in_probe: bool = c_held != null and not c.is_done() and not c.get("_job").is_finished()
	var cancel_start := Time.get_ticks_msec()
	c.cancel()
	while not c.is_done():
		await process_frame
	var cancel_ms := Time.get_ticks_msec() - cancel_start
	var cancelled := c.wait()
	_results.append(cancelled)
	if c_held != null:
		c_held.disconnect_from_host()
	c_listener.stop()
	print("AI DETECTOR cancel mid-probe: done %d ms after cancel(), with a %d ms timeout" % [cancel_ms, LONG_TIMEOUT_MS])
	_check("cancel() ends a detection mid-probe, long before its timeout, still with a result", in_probe and cancel_ms < LONG_TIMEOUT_MS / 2 and cancelled != null and cancelled.source_name == "ai-off", "%d ms" % cancel_ms)
	# Dropped mid-probe: it cancels and joins its worker, which runs on its own copy.
	var d_listener := TCPServer.new()
	d_listener.listen(0, Detector.LOCALHOST)
	var dropped := _detector("missing", "empty", d_listener.get_local_port(), d_listener.get_local_port())
	dropped.http_timeout_ms = LONG_TIMEOUT_MS
	var job = dropped.get("_job")
	dropped.start()
	var d_held := _hold_connection(d_listener)
	var dropped_in_probe: bool = d_held != null and not dropped.is_done() and not job.is_finished()
	var drop_start := Time.get_ticks_msec()
	dropped = null
	var drop_ms := Time.get_ticks_msec() - drop_start
	if d_held != null:
		d_held.disconnect_from_host()
	d_listener.stop()
	print("AI DETECTOR dropped mid-probe: cancelled and joined its worker in %d ms" % drop_ms)
	_check("a detector dropped mid-probe cancels and joins its worker, which finishes on its own copy", dropped_in_probe and drop_ms < LONG_TIMEOUT_MS / 2 and job.is_finished(), "%d ms, finished %s" % [drop_ms, job.is_finished()])
	_set_mode("full")
	# The worker and its detector share one GPU limit.
	var shared := _detector("missing", "empty", -1, -1, "sysfs_empty", "gpu")
	shared.rate_clock = _now
	_fake_now = 50000
	var starts_before := _smi_runs_logged().count("--")
	shared.start()
	while not shared.is_done():
		await process_frame
	var on_worker := shared.wait()
	_results.append(on_worker)
	var starts_on_worker := _smi_runs_logged().count("--") - starts_before
	var on_parent := shared.poll_gpu()
	var starts_after_parent := _smi_runs_logged().count("--") - starts_before
	_check("a GPU read on the worker counts against its detector's once-per-second limit", starts_on_worker == 1 and starts_after_parent == 1 and on_worker.gpu_source == "nvidia-smi" and on_parent["util_percent"] == on_worker.gpu_util_percent, "%d starts on the worker, %d after the parent's poll" % [starts_on_worker, starts_after_parent])
	_check("the stub agent CLI was never executed by any detection", not FileAccess.file_exists(_exec_mark))


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
	_check("no result's string form holds a path, a user or host name, a model name or the raw setting", _results.size() >= 12 and leaks == 0, "%d results, %d with a leak" % [_results.size(), leaks])
