extends RefCounted
## Finds which AI this player's game can talk to, following PRD 5.4: the player's Omarchy
## default agent first, then a local model server, then the scripted guide with "AI off".
## No UI, and not wired into any scene yet; the boot screen (C10) will use it.
##
## Use: var d := AiSourceDetector.new(); d.start(); then each frame, once d.is_done(),
## var result := d.wait(). Or call d.detect() directly on a thread of your own.
##
## What it touches, and nothing else (PRD section 6):
## - Omarchy's default-agent setting: only its first line, at most AGENT_FILE_MAX_BYTES,
##   read a byte at a time and stopped at the first newline. Never any other config file.
##   It never runs omarchy-default-agent or omarchy-agent.
## - The PATH directories: whether a known agent's command exists there as a file with an
##   execute bit. Nothing is read from it and it is never run, not even with --version.
## - Local model servers, on 127.0.0.1 only (LOCALHOST is a constant, never a setting): one
##   short HTTP/1.0 GET per endpoint, Ollama's /api/version and /api/tags and the
##   OpenAI-style /v1/models, through a small reader of its own with a hard byte cap and a
##   deadline checked on every step. Only reachable, latency and a model COUNT are kept;
##   model names are counted and dropped, never stored, logged or printed. Nothing is
##   loaded, pulled, unloaded or changed, and no model setting is touched.
## - GPU stats, read-only: a few named /sys attributes per DRM card first (gpu_busy_percent,
##   mem_info_vram_used, mem_info_vram_total, hwmon temp1_input), and only if none answer,
##   the SECOND named execute exception of PRD section 6: nvidia-smi at its fixed system
##   path NVIDIA_SMI_PATH (the PATH is never searched for it), with exactly NVIDIA_SMI_ARGS,
##   query-only, no control flags, as an argument array with no shell. poll_gpu() is the
##   only way in. Every detector with the same settings shares one GPU state, so together
##   they read at most once per GPU_POLL_MIN_INTERVAL_MS and never run two nvidia-smi at
##   once.
##
## Blocking: the server probes wait up to http_timeout_ms per request and nvidia-smi up to
## nvidia_smi_timeout_ms, so they must never run on the main thread. detect() is
## synchronous; start() runs it on a worker thread, and cancel() or dropping the detector
## ends it within a millisecond or so. nvidia-smi runs through a non-blocking pipe with a
## deadline: if it hangs it is left to exit on its own, never killed, and no other
## nvidia-smi starts until it has.
##
## Every outside touchpoint is a variable below, so tests point it at fixtures. The
## defaults are the real ones.

const Result = preload("res://scripts/ai/ai_source_result.gd")

## The agents Omarchy's default-agent setting can name (PRD 5.4, Omarchy 4.x). Omarchy writes
## the canonical name, one line, and the same name is the agent's command.
const KNOWN_AGENTS: PackedStringArray = [
	"pi", "omp", "opencode", "claude", "codex", "grok", "gemini", "openclaw", "hermes",
	"copilot", "crush", "cursor-agent", "muse",
]
## Where Omarchy keeps the setting, under the player's home directory.
const AGENT_FILE_UNDER_HOME := ".config/omarchy/defaults/agent"
## Longest first line accepted, in bytes. A longer one counts as unset.
const AGENT_FILE_MAX_BYTES := 256
const NEWLINE := 0x0A
const TAB := 0x09
const CARRIAGE_RETURN := 0x0D
const PRINTABLE_FIRST := 0x20
const PRINTABLE_LAST := 0x7E
const HIGH_BIT := 0x80
## Owner, group and other execute bits (octal 111).
const EXECUTE_BITS := 0x49
## The only host the detector ever connects to.
const LOCALHOST := "127.0.0.1"
const OLLAMA_PORT := 11434
const OPENAI_PORT := 1234
const OLLAMA_VERSION_PATH := "/api/version"
const OLLAMA_MODELS_PATH := "/api/tags"
const OPENAI_MODELS_PATH := "/v1/models"
## Longest wait for one HTTP request, connect to last byte, in milliseconds.
const HTTP_TIMEOUT_MS := 500
## Largest whole response read, status line and headers included; longer is no answer.
const HTTP_RESPONSE_MAX_BYTES := 1048576
const HTTP_OK := "200"
const PORT_LAST := 65535
## Pause between polls of a connection or a pipe, in microseconds.
const POLL_SLEEP_USEC := 1000
const SYSFS_ROOT := "/sys"
## DRM cards and hwmon sensors looked at, card0 and hwmon0 upward.
const DRM_CARDS_SCANNED := 8
const HWMON_SCANNED := 16
## Most bytes read from one /sys attribute.
const SYSFS_VALUE_MAX_BYTES := 32
## nvidia-smi's fixed home, where NVIDIA's driver utilities install it. Nothing earlier on
## the PATH can stand in for it, because the PATH is never searched for it.
const NVIDIA_SMI_PATH := "/usr/bin/nvidia-smi"
## The only arguments nvidia-smi is ever given: a query, never a control flag.
const NVIDIA_SMI_ARGS: PackedStringArray = [
	"--query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu",
	"--format=csv,noheader,nounits",
]
const NVIDIA_SMI_FIELDS := 4
## Longest wait for nvidia-smi to finish, in milliseconds.
const NVIDIA_SMI_TIMEOUT_MS := 1500
## Most bytes of nvidia-smi output kept; more makes the run no reading.
const NVIDIA_SMI_OUTPUT_MAX_BYTES := 4096
## poll_gpu() reads the GPU at most this often, in milliseconds.
const GPU_POLL_MIN_INTERVAL_MS := 1000
const BYTES_PER_MIB := 1048576
const MILLIDEGREES_PER_DEGREE := 1000.0
## Longest digit string read as a number. Longer ones would overflow, so they are no reading.
const NUMBER_MAX_DIGITS := 15
## Largest readings believed: a percentage, a temperature in C, memory in MiB (16 TiB).
const PERCENT_LAST := 100
const TEMP_C_LAST := 200
const VRAM_MIB_LAST := 16777216

## Omarchy's default-agent setting. Empty means the real one under the player's home.
var agent_file_path := ""
## Directories searched for agent commands. Empty means the player's PATH.
var path_dirs := PackedStringArray()
## Local server ports on 127.0.0.1. The host itself cannot be changed.
var ollama_port := OLLAMA_PORT
var openai_port := OPENAI_PORT
## Longest wait for one HTTP request, in milliseconds.
var http_timeout_ms := HTTP_TIMEOUT_MS
## Root of the /sys tree read for GPU stats.
var sysfs_root := SYSFS_ROOT
## nvidia-smi to run, an absolute path. Tests point it at a stub.
var nvidia_smi_path := NVIDIA_SMI_PATH
## Longest wait for nvidia-smi, in milliseconds.
var nvidia_smi_timeout_ms := NVIDIA_SMI_TIMEOUT_MS
## Milliseconds since a fixed start, for the GPU rate limit only. Tests swap it. Timeouts
## and latency always use real time, so a stopped test clock can never stall a probe.
var rate_clock := Callable(Time, "get_ticks_msec")

var _thread: Thread
var _result: Result
var _job := Job.new()

## One GPU state per (sysfs root, nvidia-smi path, rate clock), shared by every detector
## with those settings, so they read the GPU at most once per interval between them.
static var _gpu_states := {}
static var _gpu_states_mutex := Mutex.new()


## A detection's cancel flag, shared with the worker copy start() makes.
class Job:
	extends RefCounted
	var _mutex := Mutex.new()
	var _cancelled := false
	var _finished := false

	func cancel() -> void:
		_mutex.lock()
		_cancelled = true
		_mutex.unlock()

	func is_cancelled() -> bool:
		_mutex.lock()
		var cancelled := _cancelled
		_mutex.unlock()
		return cancelled

	func mark_finished() -> void:
		_mutex.lock()
		_finished = true
		_mutex.unlock()

	## True once a detect() for this job has run to its end, cancelled or not.
	func is_finished() -> bool:
		_mutex.lock()
		var finished := _finished
		_mutex.unlock()
		return finished


## The GPU rate limit and the one nvidia-smi that may be running. `mutex` guards the reading
## and the timing; the smi_ fields belong to whichever poll holds `refreshing`.
class GpuState:
	extends RefCounted
	var mutex := Mutex.new()
	var reading := {}
	var read_at := 0
	var ever_read := false
	var refreshing := false
	var nvidia_smi_runs := 0
	var smi_pid := 0
	var smi_stdout: FileAccess
	var smi_stderr: FileAccess
	var smi_output := PackedByteArray()
	var smi_overflow := false


## Runs every check and resolves the choice. Blocks for up to a few seconds when servers
## time out, so call it from a worker thread, or use start(). After cancel() it stops at
## the next step and resolves on what it has.
func detect() -> Result:
	var result := Result.new()
	var agent := read_agent()
	result.agent_state = agent[0]
	result.agent = agent[1]
	if result.agent_state == Result.AgentState.KNOWN:
		result.agent_cli_present = cli_present(result.agent)
	if not _job.is_cancelled():
		var ollama := probe_ollama()
		result.ollama_reachable = ollama["reachable"]
		result.ollama_latency_ms = ollama["latency_ms"]
		result.ollama_model_count = ollama["model_count"]
	if not _job.is_cancelled():
		var openai := probe_openai()
		result.openai_reachable = openai["reachable"]
		result.openai_latency_ms = openai["latency_ms"]
		result.openai_model_count = openai["model_count"]
	if not _job.is_cancelled():
		result.set_gpu(poll_gpu())
	resolve(result)
	_job.mark_finished()
	return result


## Sets result.source and result.source_name in the PRD 5.4 order: a KNOWN agent whose
## command is on the PATH; else Ollama, else an OpenAI-compatible server, each only if it
## answered and lists at least one model, since a server with none cannot answer; else
## the scripted guide with "AI off". Unknown and unset agents fall through.
static func resolve(result: Result) -> void:
	if result.agent_state == Result.AgentState.KNOWN and result.agent_cli_present:
		result.source = Result.Source.AGENT
		result.source_name = result.agent
	elif result.ollama_reachable and result.ollama_model_count > 0:
		result.source = Result.Source.LOCAL_SERVER
		result.source_name = "ollama"
	elif result.openai_reachable and result.openai_model_count > 0:
		result.source = Result.Source.LOCAL_SERVER
		result.source_name = "openai-compatible"
	else:
		result.source = Result.Source.SCRIPTED
		result.source_name = "ai-off"


## Starts detect() on a worker thread, so the main loop never waits on a probe. Once only.
## The worker runs on a copy of this detector's settings that it holds itself and that
## holds nothing back, so this detector can be dropped at any time: it then cancels the
## worker and joins it, which takes about a millisecond.
func start() -> Error:
	if _thread != null:
		return ERR_ALREADY_IN_USE
	var worker := _worker_copy()
	var thread := Thread.new()
	var err := thread.start(worker._detect_holding.bind(worker))
	if err == OK:
		_thread = thread
	return err


## Asks a running detection to stop at its next step. The result still resolves, on what
## was found so far.
func cancel() -> void:
	_job.cancel()


## True once the worker started by start() has finished, and from then on.
func is_done() -> bool:
	return _thread != null and not _thread.is_alive()


## The worker's result, the same object every call. Waits for it if it is still running,
## so call it once is_done() is true. Null if start() never succeeded.
func wait() -> Result:
	if _thread == null:
		return null
	# Godot's Thread.is_started() turns false once joined, so the joined result is kept here.
	if _result == null:
		_result = _thread.wait_to_finish()
	return _result


## Same settings and the same cancel flag, nothing else. The GPU state is shared through
## the settings.
func _worker_copy() -> RefCounted:
	var copy = get_script().new()
	copy.agent_file_path = agent_file_path
	copy.path_dirs = path_dirs.duplicate()
	copy.ollama_port = ollama_port
	copy.openai_port = openai_port
	copy.http_timeout_ms = http_timeout_ms
	copy.sysfs_root = sysfs_root
	copy.nvidia_smi_path = nvidia_smi_path
	copy.nvidia_smi_timeout_ms = nvidia_smi_timeout_ms
	copy.rate_clock = rate_clock
	copy._job = _job
	return copy


## The worker's entry. `_holder` is this same object, bound into the thread's callable so
## the thread keeps it alive for as long as it runs.
func _detect_holding(_holder: RefCounted) -> Result:
	return detect()


func _notification(what: int) -> void:
	# A worker must be joined before its Thread is freed. Cancelled, it ends at its next step.
	if what == NOTIFICATION_PREDELETE and _thread != null and _result == null:
		_job.cancel()
		_thread.wait_to_finish()


## Reads the default-agent setting and returns [AgentState, agent name or ""]. Bytes are
## taken one at a time and the read stops at the first newline: nothing past the first
## line is ever used. (The C library may buffer a little ahead inside its own read; the
## detector never sees those bytes.)
func read_agent() -> Array:
	var path := agent_file_path
	if path.is_empty():
		var home := OS.get_environment("HOME")
		if home.is_empty():
			return [Result.AgentState.UNSET, ""]
		path = home.path_join(AGENT_FILE_UNDER_HOME)
	if DirAccess.dir_exists_absolute(path) or not FileAccess.file_exists(path):
		return [Result.AgentState.UNSET, ""]
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return [Result.AgentState.UNSET, ""]
	var length := file.get_length()
	var line := PackedByteArray()
	var ended := false
	while line.size() < AGENT_FILE_MAX_BYTES and file.get_position() < length:
		var b := file.get_8()
		if b == NEWLINE:
			ended = true
			break
		line.append(b)
	if not ended and line.size() == AGENT_FILE_MAX_BYTES and file.get_position() < length:
		# A line of exactly the cap may still end right here; anything else is too long.
		ended = file.get_8() == NEWLINE
		if not ended:
			file.close()
			return [Result.AgentState.UNSET, ""]
	file.close()
	return parse_agent_line(line)


## The setting's verdict from its raw bytes: only the first line counts, trimmed and
## lowercased the way Omarchy's own reader trims it. Anything that is not plain text, or a
## first line longer than AGENT_FILE_MAX_BYTES, counts as unset. A value outside
## KNOWN_AGENTS is UNKNOWN and is not kept.
static func parse_agent_line(bytes: PackedByteArray) -> Array:
	var line := PackedByteArray()
	var ended := false
	for b in bytes:
		if b == NEWLINE:
			ended = true
			break
		if b != TAB and b != CARRIAGE_RETURN and (b < PRINTABLE_FIRST or b > PRINTABLE_LAST):
			return [Result.AgentState.UNSET, ""]
		line.append(b)
	if not ended and bytes.size() > AGENT_FILE_MAX_BYTES:
		return [Result.AgentState.UNSET, ""]
	var value := line.get_string_from_ascii().strip_edges().to_lower()
	if value.is_empty():
		return [Result.AgentState.UNSET, ""]
	if KNOWN_AGENTS.has(value):
		return [Result.AgentState.KNOWN, value]
	return [Result.AgentState.UNKNOWN, ""]


## Whether a known agent's command is on the PATH: an absolute PATH entry holding a file,
## not a directory, of that name with any execute bit. Names outside KNOWN_AGENTS are
## refused, so nothing but a listed command name is ever looked up.
func cli_present(agent_name: String) -> bool:
	if not KNOWN_AGENTS.has(agent_name):
		return false
	return find_command(agent_name) != ""


## The full path of a command on the PATH, or "" if it is not there. Used by this script
## only; the path is never put in a result.
func find_command(command: String) -> String:
	if command.is_empty() or command.contains("/"):
		return ""
	for dir in _search_dirs():
		# A relative entry, like "" or ".", would search wherever the game happens to run.
		if not dir.is_absolute_path():
			continue
		var candidate := dir.path_join(command)
		if DirAccess.dir_exists_absolute(candidate) or not FileAccess.file_exists(candidate):
			continue
		if FileAccess.get_unix_permissions(candidate) & EXECUTE_BITS:
			return candidate
	return ""


## Ollama on localhost: {reachable, latency_ms, model_count}. Blocks up to two requests.
func probe_ollama() -> Dictionary:
	var version := _get_json(ollama_port, OLLAMA_VERSION_PATH)
	if version.is_empty() or not (version["data"] is Dictionary) or not version["data"].has("version"):
		return _no_server()
	var out := {"reachable": true, "latency_ms": version["latency_ms"], "model_count": -1}
	var listing := _get_json(ollama_port, OLLAMA_MODELS_PATH)
	if not listing.is_empty() and listing["data"] is Dictionary and listing["data"].get("models") is Array:
		out["model_count"] = (listing["data"]["models"] as Array).size()
	return out


## A local OpenAI-compatible server: {reachable, latency_ms, model_count}. One request.
func probe_openai() -> Dictionary:
	var listing := _get_json(openai_port, OPENAI_MODELS_PATH)
	if listing.is_empty() or not (listing["data"] is Dictionary) or not (listing["data"].get("data") is Array):
		return _no_server()
	return {"reachable": true, "latency_ms": listing["latency_ms"], "model_count": (listing["data"]["data"] as Array).size()}


static func _no_server() -> Dictionary:
	return {"reachable": false, "latency_ms": -1, "model_count": -1}


## One HTTP/1.0 GET to 127.0.0.1:port. Returns {latency_ms, data} with the parsed JSON, or
## {} on refusal, timeout, cancel, a reset, a response over HTTP_RESPONSE_MAX_BYTES, or
## anything parse_http_json() refuses. HTTP/1.0 means the server answers without chunking
## and closes the connection when done, so the response ends at a clean close. Latency is
## to the first byte of the answer.
func _get_json(port: int, path: String) -> Dictionary:
	if port < 1 or port > PORT_LAST:
		return {}
	var start := Time.get_ticks_msec()
	var deadline := start + http_timeout_ms
	var peer := StreamPeerTCP.new()
	if peer.connect_to_host(LOCALHOST, port) != OK:
		return {}
	while true:
		peer.poll()
		var status := peer.get_status()
		if status == StreamPeerTCP.STATUS_CONNECTED:
			break
		if status != StreamPeerTCP.STATUS_CONNECTING or _stop_waiting(deadline):
			peer.disconnect_from_host()
			return {}
		OS.delay_usec(POLL_SLEEP_USEC)
	var request := "GET %s HTTP/1.0\r\nHost: %s:%d\r\nAccept: application/json\r\nConnection: close\r\n\r\n" % [path, LOCALHOST, port]
	if peer.put_data(request.to_ascii_buffer()) != OK:
		peer.disconnect_from_host()
		return {}
	var raw := PackedByteArray()
	var latency := -1
	while true:
		if _stop_waiting(deadline):
			peer.disconnect_from_host()
			return {}
		peer.poll()
		var status := peer.get_status()
		if status != StreamPeerTCP.STATUS_CONNECTED:
			if status != StreamPeerTCP.STATUS_NONE:
				return {}  # reset or error: not a whole answer
			break  # a clean close: the whole answer is in
		var waiting := peer.get_available_bytes()
		if waiting <= 0:
			OS.delay_usec(POLL_SLEEP_USEC)
			continue
		var got: Array = peer.get_partial_data(mini(waiting, HTTP_RESPONSE_MAX_BYTES + 1 - raw.size()))
		if got[0] != OK:
			peer.disconnect_from_host()
			return {}
		if latency < 0:
			latency = Time.get_ticks_msec() - start
		raw.append_array(got[1])
		if raw.size() > HTTP_RESPONSE_MAX_BYTES:
			peer.disconnect_from_host()
			return {}
	var data = parse_http_json(raw)
	if data == null:
		return {}
	return {"latency_ms": latency, "data": data}


func _stop_waiting(deadline: int) -> bool:
	return Time.get_ticks_msec() > deadline or _job.is_cancelled()


## The JSON body of a whole HTTP/1.0 or 1.1 response, or null. Refused: no end of headers,
## a header byte that is not printable ASCII, a status other than 200, a malformed header,
## any Transfer-Encoding (an HTTP/1.0 answer is never chunked), a Content-Length that is
## not a plain number or does not match the body, a body that is not valid UTF-8 or holds a
## NUL, and a body that is not JSON. Nothing here prints, whatever the bytes.
static func parse_http_json(raw: PackedByteArray) -> Variant:
	var split := _header_end(raw)
	if split < 0:
		return null
	var head := raw.slice(0, split)
	for b in head:
		if b != NEWLINE and b != CARRIAGE_RETURN and b != TAB and (b < PRINTABLE_FIRST or b > PRINTABLE_LAST):
			return null
	var lines := head.get_string_from_ascii().split("\r\n")
	var status := lines[0].split(" ", false)
	if status.size() < 2 or (status[0] != "HTTP/1.0" and status[0] != "HTTP/1.1") or status[1] != HTTP_OK:
		return null
	var body := raw.slice(split + 4)
	var declared := -1
	for i in range(1, lines.size()):
		var colon := lines[i].find(":")
		if colon <= 0:
			return null
		var header := lines[i].substr(0, colon).strip_edges().to_lower()
		var value := lines[i].substr(colon + 1).strip_edges()
		if header == "transfer-encoding":
			return null
		if header == "content-length":
			var length := whole_number(value)
			if length < 0 or (declared >= 0 and declared != length):
				return null
			declared = length
	if declared >= 0 and body.size() != declared:
		return null
	if not is_utf8_text(body):
		return null
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return null
	return json.data


## Index of the blank line that ends the headers, or -1.
static func _header_end(raw: PackedByteArray) -> int:
	var at := raw.find(CARRIAGE_RETURN)
	while at >= 0 and at + 3 < raw.size():
		if raw[at + 1] == NEWLINE and raw[at + 2] == CARRIAGE_RETURN and raw[at + 3] == NEWLINE:
			return at
		at = raw.find(CARRIAGE_RETURN, at + 1)
	return -1


## True if the bytes are well-formed UTF-8 with no NUL: no stray or missing continuation
## bytes, no overlong forms, no surrogates, nothing past U+10FFFF. Checked here, quietly,
## because Godot's own decoder prints an error for every bad sequence.
static func is_utf8_text(bytes: PackedByteArray) -> bool:
	var i := 0
	var size := bytes.size()
	while i < size:
		var b := bytes[i]
		if b == 0:
			return false
		if b < HIGH_BIT:
			i += 1
			continue
		var extra := 0
		var low := 0x80
		var high := 0xBF
		if b >= 0xC2 and b <= 0xDF:
			extra = 1
		elif b == 0xE0:
			extra = 2
			low = 0xA0
		elif (b >= 0xE1 and b <= 0xEC) or b == 0xEE or b == 0xEF:
			extra = 2
		elif b == 0xED:
			extra = 2
			high = 0x9F
		elif b == 0xF0:
			extra = 3
			low = 0x90
		elif b >= 0xF1 and b <= 0xF3:
			extra = 3
		elif b == 0xF4:
			extra = 3
			high = 0x8F
		else:
			return false
		if i + extra >= size:
			return false
		for k in range(1, extra + 1):
			var c := bytes[i + k]
			if c < (low if k == 1 else 0x80) or c > (high if k == 1 else 0xBF):
				return false
		i += extra + 1
	return true


## A plain non-negative whole number of at most NUMBER_MAX_DIGITS digits, or -1. Anything
## longer could overflow, which Godot's own conversion reports as an error.
static func whole_number(text: String) -> int:
	if text.is_empty() or text.length() > NUMBER_MAX_DIGITS:
		return -1
	for c in text:
		if c < "0" or c > "9":
			return -1
	return text.to_int()


## GPU stats: {available, source, util_percent, vram_used_mib, vram_total_mib, temp_c}.
## Reads at most once per GPU_POLL_MIN_INTERVAL_MS across every detector with the same
## settings; a call sooner, or while another call is reading, gets the last reading at
## once. /sys first; nvidia-smi only when /sys gives nothing. The lock is held only to
## claim the read and to publish it, never during the reading itself.
func poll_gpu() -> Dictionary:
	var state := _gpu_state()
	state.mutex.lock()
	var now: int = rate_clock.call()
	var due := not state.ever_read or now - state.read_at >= GPU_POLL_MIN_INTERVAL_MS
	if not due or state.refreshing:
		var last: Dictionary = state.reading.duplicate() if not state.reading.is_empty() else _no_gpu()
		state.mutex.unlock()
		return last
	state.ever_read = true
	state.read_at = now
	state.refreshing = true
	state.mutex.unlock()
	var reading := _read_sysfs_gpu()
	if not reading["available"]:
		reading = _read_nvidia_smi(state)
	state.mutex.lock()
	state.reading = reading
	state.refreshing = false
	state.mutex.unlock()
	return reading.duplicate()


## How many times nvidia-smi has been started for these settings, by any detector.
func nvidia_smi_runs() -> int:
	var state := _gpu_state()
	state.mutex.lock()
	var runs := state.nvidia_smi_runs
	state.mutex.unlock()
	return runs


func _gpu_state() -> GpuState:
	var key := "%s|%s|%s" % [sysfs_root, nvidia_smi_path, rate_clock]
	_gpu_states_mutex.lock()
	if not _gpu_states.has(key):
		_gpu_states[key] = GpuState.new()
	var state: GpuState = _gpu_states[key]
	_gpu_states_mutex.unlock()
	return state


static func _no_gpu() -> Dictionary:
	return {"available": false, "source": "none", "util_percent": -1, "vram_used_mib": -1, "vram_total_mib": -1, "temp_c": -1}


## The first DRM card under sysfs_root that reports busy percent or VRAM.
func _read_sysfs_gpu() -> Dictionary:
	for card in DRM_CARDS_SCANNED:
		var device := sysfs_root.path_join("class/drm/card%d/device" % card)
		var busy := _in_range(_read_sysfs_int(device.path_join("gpu_busy_percent")), PERCENT_LAST)
		var used := _read_sysfs_int(device.path_join("mem_info_vram_used"))
		var total := _read_sysfs_int(device.path_join("mem_info_vram_total"))
		if busy < 0 and total <= 0:
			continue
		var temp := -1
		for sensor in HWMON_SCANNED:
			var milli := _read_sysfs_int(device.path_join("hwmon/hwmon%d/temp1_input" % sensor))
			if milli >= 0:
				temp = _in_range(roundi(milli / MILLIDEGREES_PER_DEGREE), TEMP_C_LAST)
				break
		return {
			"available": true,
			"source": "sysfs",
			"util_percent": busy,
			"vram_used_mib": _in_range(used / BYTES_PER_MIB, VRAM_MIB_LAST) if used >= 0 else -1,
			"vram_total_mib": _in_range(total / BYTES_PER_MIB, VRAM_MIB_LAST) if total > 0 else -1,
			"temp_c": temp,
		}
	return _no_gpu()


## A whole number from one /sys attribute, or -1 if it is missing or not a plain number.
static func _read_sysfs_int(path: String) -> int:
	if not FileAccess.file_exists(path):
		return -1
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var text := file.get_buffer(SYSFS_VALUE_MAX_BYTES).get_string_from_ascii().strip_edges()
	file.close()
	return whole_number(text)


static func _in_range(value: int, last: int) -> int:
	return value if value >= 0 and value <= last else -1


## Runs nvidia-smi with exactly NVIDIA_SMI_ARGS and reads the first GPU's line. Never two
## at once: one still running from an earlier poll is checked on, without waiting, and its
## output used once it has exited; until then no new one starts.
func _read_nvidia_smi(state: GpuState) -> Dictionary:
	if state.smi_pid != 0:
		if not _pump_smi(state, Time.get_ticks_msec()):
			return state.reading.duplicate() if not state.reading.is_empty() else _no_gpu()
		return _finish_smi(state)
	var path := nvidia_smi_path
	if path.is_empty() or not path.is_absolute_path() or DirAccess.dir_exists_absolute(path):
		return _no_gpu()
	if not FileAccess.file_exists(path) or not (FileAccess.get_unix_permissions(path) & EXECUTE_BITS):
		return _no_gpu()
	var run := OS.execute_with_pipe(path, NVIDIA_SMI_ARGS, false)
	if run.is_empty():
		return _no_gpu()
	state.mutex.lock()
	state.nvidia_smi_runs += 1
	state.mutex.unlock()
	state.smi_pid = run["pid"]
	state.smi_stdout = run["stdio"]
	state.smi_stderr = run["stderr"]
	state.smi_output = PackedByteArray()
	state.smi_overflow = false
	if not _pump_smi(state, Time.get_ticks_msec() + nvidia_smi_timeout_ms):
		return _no_gpu()  # still running: left to exit on its own, never killed
	return _finish_smi(state)


## Reads what nvidia-smi has written, and drains and drops its stderr, until it exits, the
## deadline passes or the detection is cancelled. True once it has exited.
func _pump_smi(state: GpuState, deadline: int) -> bool:
	while true:
		var chunk := state.smi_stdout.get_buffer(NVIDIA_SMI_OUTPUT_MAX_BYTES)
		state.smi_stderr.get_buffer(NVIDIA_SMI_OUTPUT_MAX_BYTES)
		_keep_smi_output(state, chunk)
		if chunk.is_empty():
			if not OS.is_process_running(state.smi_pid):
				_keep_smi_output(state, state.smi_stdout.get_buffer(NVIDIA_SMI_OUTPUT_MAX_BYTES))
				return true
			if Time.get_ticks_msec() > deadline or _job.is_cancelled():
				return false
			OS.delay_usec(POLL_SLEEP_USEC)
	return false


static func _keep_smi_output(state: GpuState, chunk: PackedByteArray) -> void:
	if state.smi_overflow or chunk.is_empty():
		return
	state.smi_output.append_array(chunk)
	if state.smi_output.size() > NVIDIA_SMI_OUTPUT_MAX_BYTES:
		state.smi_overflow = true
		state.smi_output = PackedByteArray()


## Collects an exited nvidia-smi's result and clears the record.
func _finish_smi(state: GpuState) -> Dictionary:
	var exit_code := OS.get_process_exit_code(state.smi_pid)
	var output := state.smi_output
	var overflow := state.smi_overflow
	state.smi_stdout.close()
	state.smi_stderr.close()
	state.smi_pid = 0
	state.smi_stdout = null
	state.smi_stderr = null
	state.smi_output = PackedByteArray()
	state.smi_overflow = false
	if overflow or exit_code != 0:
		return _no_gpu()
	return parse_nvidia_smi(output.get_string_from_ascii())


## The first line of nvidia-smi's CSV: utilization %, memory used MiB, memory total MiB,
## temperature C. A field that is not a plain whole number in range, such as "[N/A]",
## becomes -1.
static func parse_nvidia_smi(text: String) -> Dictionary:
	var lines := text.split("\n", false)
	if lines.is_empty():
		return _no_gpu()
	var fields := lines[0].split(",")
	if fields.size() != NVIDIA_SMI_FIELDS:
		return _no_gpu()
	var util := _in_range(whole_number(fields[0].strip_edges()), PERCENT_LAST)
	var used := _in_range(whole_number(fields[1].strip_edges()), VRAM_MIB_LAST)
	var total := _in_range(whole_number(fields[2].strip_edges()), VRAM_MIB_LAST)
	var temp := _in_range(whole_number(fields[3].strip_edges()), TEMP_C_LAST)
	if util < 0 and total < 0:
		return _no_gpu()
	return {
		"available": true,
		"source": "nvidia-smi",
		"util_percent": util,
		"vram_used_mib": used,
		"vram_total_mib": total,
		"temp_c": temp,
	}


func _search_dirs() -> PackedStringArray:
	if not path_dirs.is_empty():
		return path_dirs
	return OS.get_environment("PATH").split(":", false)
