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
##   deadline checked on every step. The answer is checked by a JSON scanner of its own
##   that only counts: it never decodes a string or converts a number, so model names are
##   never even read as text, and no answer can make Godot print. Only reachable, latency
##   and a model COUNT are kept. Nothing is loaded, pulled, unloaded or changed, and no
##   model setting is touched.
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
## Largest header section accepted. Real ones are a few hundred bytes; the cap keeps their
## checking to a few microseconds.
const HTTP_HEADER_MAX_BYTES := 16384
const HTTP_STATUS_OK := ["HTTP/1.0 200", "HTTP/1.1 200"]
## Characters allowed in an HTTP header name (RFC 9110 token), besides letters and digits.
const HTTP_TOKEN_EXTRA := "!#$%&'*+-.^_`|~"
## Deepest nesting the JSON scanner follows.
const JSON_MAX_DEPTH := 64
## Bytes scanned between checks for cancel.
const SCAN_CHECK_EVERY := 65536
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
## with those settings, so they read the GPU at most once per interval between them. The
## key is an Array, so two different clock objects never share a state: a Callable's
## string form leaves out which object it belongs to.
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
## and the timing; the smi_ fields belong to whichever caller holds `refreshing`. The
## process handling lives here, not in the detector, because a detector being freed can
## call other objects' methods but not its own.
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
	var smi_cap := 0
	var smi_sleep_usec := 1000

	## Takes over a just-started nvidia-smi.
	func adopt(run: Dictionary, cap: int, sleep_usec: int) -> void:
		smi_pid = run["pid"]
		smi_stdout = run["stdio"]
		smi_stderr = run["stderr"]
		smi_output = PackedByteArray()
		smi_overflow = false
		smi_cap = cap
		smi_sleep_usec = sleep_usec

	## Reads what nvidia-smi has written, and drains and drops its stderr, until it exits,
	## the deadline passes or `job` (if given) is cancelled. Exit is checked first on every
	## pass, so a process that has exited is always collected, even by a check that does
	## not wait; the deadline and cancel are checked on every pass too, so even an
	## nvidia-smi that never stops writing cannot hold the thread. Once it has exited,
	## everything left in its pipe goes through the output cap. True once exited.
	func pump(deadline: int, job: Object) -> bool:
		while true:
			var chunk := smi_stdout.get_buffer(smi_cap)
			smi_stderr.get_buffer(smi_cap)
			keep(chunk)
			if not OS.is_process_running(smi_pid):
				while true:
					var rest := smi_stdout.get_buffer(smi_cap)
					if rest.is_empty():
						return true
					keep(rest)
			if Time.get_ticks_msec() > deadline or (job != null and job.is_cancelled()):
				return false
			if chunk.is_empty():
				OS.delay_usec(smi_sleep_usec)
		return false

	func keep(chunk: PackedByteArray) -> void:
		if smi_overflow or chunk.is_empty():
			return
		smi_output.append_array(chunk)
		if smi_output.size() > smi_cap:
			smi_overflow = true
			smi_output = PackedByteArray()

	## Collects an exited nvidia-smi and clears the record. Its output when it exited 0 and
	## stayed under the cap, else "".
	func finish() -> String:
		var exit_code := OS.get_process_exit_code(smi_pid)
		var output := smi_output.get_string_from_ascii()
		var good := not smi_overflow and exit_code == 0
		smi_stdout.close()
		smi_stderr.close()
		smi_pid = 0
		smi_stdout = null
		smi_stderr = null
		smi_output = PackedByteArray()
		smi_overflow = false
		return output if good else ""

	## Without waiting: if an earlier nvidia-smi has exited, collects it and returns its
	## output ("" if it failed); null if there is none or it is still running.
	func collect_if_done() -> Variant:
		if smi_pid == 0 or not pump(Time.get_ticks_msec(), null):
			return null
		return finish()

	## For a detector being freed: reaps an earlier nvidia-smi that has exited, unless a
	## poll is busy with it.
	func reap_if_done() -> void:
		mutex.lock()
		if refreshing or smi_pid == 0:
			mutex.unlock()
			return
		refreshing = true
		mutex.unlock()
		collect_if_done()
		mutex.lock()
		refreshing = false
		mutex.unlock()


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
	if what != NOTIFICATION_PREDELETE:
		return
	if _thread != null and _result == null:
		_job.cancel()
		_thread.wait_to_finish()
	# Reap an nvidia-smi that has exited since, without waiting. Only other objects' methods
	# here: Godot cannot call this object's own methods while it is being freed.
	_gpu_states_mutex.lock()
	var state = _gpu_states.get([sysfs_root, nvidia_smi_path, rate_clock])
	_gpu_states_mutex.unlock()
	if state != null:
		state.reap_if_done()


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
	if version.is_empty() or _kind(version["shape"], "version") != "string":
		return _no_server()
	var out := {"reachable": true, "latency_ms": version["latency_ms"], "model_count": -1}
	var listing := _get_json(ollama_port, OLLAMA_MODELS_PATH)
	if not listing.is_empty() and _kind(listing["shape"], "models") == "array":
		out["model_count"] = listing["shape"]["models"]["count"]
	return out


## A local OpenAI-compatible server: {reachable, latency_ms, model_count}. One request.
func probe_openai() -> Dictionary:
	var listing := _get_json(openai_port, OPENAI_MODELS_PATH)
	if listing.is_empty() or _kind(listing["shape"], "data") != "array":
		return _no_server()
	return {"reachable": true, "latency_ms": listing["latency_ms"], "model_count": listing["shape"]["data"]["count"]}


static func _kind(shape: Dictionary, key: String) -> String:
	return shape[key]["kind"] if shape.has(key) else ""


static func _no_server() -> Dictionary:
	return {"reachable": false, "latency_ms": -1, "model_count": -1}


## One HTTP/1.0 GET to 127.0.0.1:port. Returns {latency_ms, shape} with the top level of the
## JSON answer from json_top_level(), or {} on refusal, timeout, cancel, a reset, a
## response over HTTP_RESPONSE_MAX_BYTES, or anything parse_http_body() or the JSON scanner
## refuses. HTTP/1.0 means the server answers without chunking and closes the connection
## when done, so the response ends at a clean close. Latency is to the first byte of the
## answer. The deadline bounds the waiting on the server; checking an answer that arrived
## in time is bounded by the size cap and stops at a cancel.
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
	var request := ("GET %s HTTP/1.0\r\nHost: %s:%d\r\nAccept: application/json\r\nConnection: close\r\n\r\n" % [path, LOCALHOST, port]).to_ascii_buffer()
	# put_data() would wait for room in the socket with no deadline, so write in parts.
	var sent := 0
	while sent < request.size():
		if _stop_waiting(deadline):
			peer.disconnect_from_host()
			return {}
		var put: Array = peer.put_partial_data(request.slice(sent))
		if put[0] != OK:
			peer.disconnect_from_host()
			return {}
		sent += put[1]
		if put[1] == 0:
			OS.delay_usec(POLL_SLEEP_USEC)
			peer.poll()
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
	var stop := _job.is_cancelled
	var body = parse_http_body(raw, stop)
	if body == null:
		return {}
	var shape = json_top_level(body, stop)
	if shape == null:
		return {}
	return {"latency_ms": latency, "shape": shape}


func _stop_waiting(deadline: int) -> bool:
	return Time.get_ticks_msec() > deadline or _job.is_cancelled()


## The body of a whole HTTP/1.0 or 1.1 response, or null. Refused: no end of headers, a
## header byte that is not printable ASCII, a CR or LF left inside a line, a status other
## than 200, a header name that is not an HTTP token or has space before its colon, any
## Transfer-Encoding (an HTTP/1.0 answer is never chunked), a Content-Length that is not a
## plain number or does not match the body, and a body that is not valid UTF-8 or holds a
## NUL. `stop` returning true abandons the check. Nothing here prints, whatever the bytes.
static func parse_http_body(raw: PackedByteArray, stop: Callable = Callable()) -> Variant:
	var split := _header_end(raw, HTTP_HEADER_MAX_BYTES)
	if split < 0:
		return null
	var head := raw.slice(0, split)
	for b in head:
		if b != NEWLINE and b != CARRIAGE_RETURN and b != TAB and (b < PRINTABLE_FIRST or b > PRINTABLE_LAST):
			return null
	var lines := head.get_string_from_ascii().split("\r\n")
	for line in lines:
		if line.contains("\n") or line.contains("\r"):
			return null
	var status_line := lines[0]
	var status_ok := false
	for prefix in HTTP_STATUS_OK:
		if status_line.begins_with(prefix) and (status_line.length() == prefix.length() or status_line[prefix.length()] == " "):
			status_ok = true
	if not status_ok:
		return null
	var body := raw.slice(split + 4)
	var declared := -1
	for i in range(1, lines.size()):
		var colon := lines[i].find(":")
		if colon <= 0:
			return null
		var header := lines[i].substr(0, colon)
		if not _is_http_token(header):
			return null
		var value := lines[i].substr(colon + 1).strip_edges()
		header = header.to_lower()
		if header == "transfer-encoding":
			return null
		if header == "content-length":
			var length := whole_number(value)
			if length < 0 or (declared >= 0 and declared != length):
				return null
			declared = length
	if declared >= 0 and body.size() != declared:
		return null
	if not _is_plain_ascii(body) and not is_utf8_text(body, stop):
		return null
	return body


static func _is_http_token(name: String) -> bool:
	if name.is_empty():
		return false
	for c in name:
		var letter_or_digit := (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9")
		if not letter_or_digit and not HTTP_TOKEN_EXTRA.contains(c):
			return false
	return true


## True if every byte is ASCII and none is NUL, checked natively: the ASCII decode stops at
## a NUL, and any byte with the high bit set grows when encoded back to UTF-8.
static func _is_plain_ascii(bytes: PackedByteArray) -> bool:
	var text := bytes.get_string_from_ascii()
	return text.length() == bytes.size() and text.to_utf8_buffer().size() == bytes.size()


## Index of the blank line that ends the headers, or -1 if none starts within `limit`.
static func _header_end(raw: PackedByteArray, limit: int) -> int:
	var at := raw.find(CARRIAGE_RETURN)
	while at >= 0 and at <= limit and at + 3 < raw.size():
		if raw[at + 1] == NEWLINE and raw[at + 2] == CARRIAGE_RETURN and raw[at + 3] == NEWLINE:
			return at
		at = raw.find(CARRIAGE_RETURN, at + 1)
	return -1


## True if the bytes are well-formed UTF-8 with no NUL: no stray or missing continuation
## bytes, no overlong forms, no surrogates, nothing past U+10FFFF. Checked here, quietly,
## because Godot's own decoder prints an error for every bad sequence.
static func is_utf8_text(bytes: PackedByteArray, stop: Callable = Callable()) -> bool:
	var i := 0
	var size := bytes.size()
	var next_check := SCAN_CHECK_EVERY
	while i < size:
		if i >= next_check:
			next_check = i + SCAN_CHECK_EVERY
			if stop.is_valid() and stop.call():
				return false
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


## The top level of a JSON object: for each key, {kind, count}, where kind is "object",
## "array", "string", "number" or "literal" and count is an array's element count (-1
## otherwise). Null unless the bytes are exactly one well-formed JSON object. The scanner
## checks structure, escapes and number syntax but never decodes a string or converts a
## number, so model names are never read as text and nothing can make Godot print. Only
## top-level keys are read, and only as plain ASCII names after their escapes are undone;
## a key that is not plain ASCII cannot be one the detector looks for, so it is skipped.
## `stop` returning true abandons the scan. If `stats` is given, stats["searched"] is set to
## the bytes covered by the string scanning's searches, a fixed measure of its work.
static func json_top_level(bytes: PackedByteArray, stop: Callable = Callable(), stats: Dictionary = {}) -> Variant:
	var scan := JsonScan.new(bytes, stop)
	var shape = _scan_top_level(scan)
	stats["searched"] = scan.searched
	return shape


static func _scan_top_level(scan: JsonScan) -> Variant:
	scan.skip_space()
	if scan.at() != JsonScan.OPEN_BRACE:
		return null
	var shape := {}
	if not scan.object(1, shape):
		return null
	scan.skip_space()
	if scan.failed or scan.i != scan.n:
		return null
	return shape


## A one-pass JSON syntax scanner over bytes, used by json_top_level().
class JsonScan:
	extends RefCounted
	const OPEN_BRACE := 0x7B
	const CLOSE_BRACE := 0x7D
	const OPEN_BRACKET := 0x5B
	const CLOSE_BRACKET := 0x5D
	const QUOTE := 0x22
	const BACKSLASH := 0x5C
	const COLON := 0x3A
	const COMMA := 0x2C
	const MINUS := 0x2D
	const PLUS := 0x2B
	const DOT := 0x2E
	const ZERO := 0x30
	const NINE := 0x39
	const LOWER_E := 0x65
	const UPPER_E := 0x45
	const LOWER_U := 0x75
	const SIMPLE_ESCAPES := [0x22, 0x5C, 0x2F, 0x62, 0x66, 0x6E, 0x72, 0x74]
	const SPACE := [0x20, 0x09, 0x0A, 0x0D]
	const CONTROL_LAST := 0x1F
	## Longest raw key decoded. Every key the detector looks for is at most 7 letters, so even
	## written fully as \uXXXX escapes it fits; a longer key is skipped without decoding.
	const KEY_RAW_MAX := 64
	const MAX_DEPTH := 64
	const CHECK_EVERY := 65536
	const ESCAPED := {0x22: "\"", 0x5C: "\\", 0x2F: "/"}

	var b: PackedByteArray
	var n := 0
	var i := 0
	var failed := false
	var last_count := -1
	## Bytes covered by the quote and backslash searches.
	var searched := 0
	var _stop: Callable
	var _next_check := CHECK_EVERY
	var _next_backslash := -1
	var _next_quote := -1
	var _next_control := -1
	var _control_at := PackedInt64Array()

	func _init(bytes: PackedByteArray, stop: Callable) -> void:
		b = bytes
		n = bytes.size()
		_stop = stop
		_control_at.resize(CONTROL_LAST + 1)
		_control_at.fill(-1)

	func at() -> int:
		return b[i] if i < n else -1

	func advance(count: int = 1) -> void:
		i += count
		if i >= _next_check:
			_next_check = i + CHECK_EVERY
			if _stop.is_valid() and _stop.call():
				failed = true

	func fail() -> bool:
		failed = true
		return false

	func skip_space() -> void:
		while not failed and i < n and SPACE.has(b[i]):
			advance()

	## b.find(value, from), counting the bytes it covers.
	func search(value: int, from: int) -> int:
		var found := b.find(value, from)
		searched += (found if found >= 0 else n) - from
		return found

	## The first byte at or after `from` below 0x20, or n. Each control value's next
	## position is remembered and found natively, so this stays linear over the body.
	func next_control(from: int) -> int:
		if _next_control >= from:
			return _next_control
		var least := n
		for value in CONTROL_LAST + 1:
			if _control_at[value] < from:
				var found := b.find(value, from)
				_control_at[value] = found if found >= 0 else n
			least = mini(least, _control_at[value])
		_next_control = least
		return least

	func digit(c: int) -> bool:
		return c >= ZERO and c <= NINE

	func hex(c: int) -> bool:
		return digit(c) or (c >= 0x41 and c <= 0x46) or (c >= 0x61 and c <= 0x66)

	## Scans one value; returns its kind, or "" on failure. last_count holds an array's size.
	func value(depth: int) -> String:
		if failed or depth > MAX_DEPTH:
			fail()
			return ""
		skip_space()
		var c := at()
		if c == OPEN_BRACE:
			return "object" if object(depth + 1, {}) else ""
		if c == OPEN_BRACKET:
			return "array" if array(depth + 1) else ""
		if c == QUOTE:
			return "string" if string_end() >= 0 else ""
		if c == 0x74:
			return "literal" if literal("true") else ""
		if c == 0x66:
			return "literal" if literal("false") else ""
		if c == 0x6E:
			return "literal" if literal("null") else ""
		if c == MINUS or digit(c):
			return "number" if number() else ""
		fail()
		return ""

	## An object; when `record` is the top level's dictionary, each key's kind goes in it.
	func object(depth: int, record: Dictionary) -> bool:
		var top := depth == 1
		advance()
		skip_space()
		if at() == CLOSE_BRACE:
			advance()
			return not failed
		while not failed:
			skip_space()
			if at() != QUOTE:
				return fail()
			var key_start := i + 1
			var key_end := string_end()
			if key_end < 0:
				return fail()
			skip_space()
			if at() != COLON:
				return fail()
			advance()
			var kind := value(depth)
			if kind == "":
				return fail()
			if top:
				var key := ascii_key(b.slice(key_start, key_end))
				if not key.is_empty():
					record[key] = {"kind": kind, "count": last_count if kind == "array" else -1}
			skip_space()
			var c := at()
			if c == COMMA:
				advance()
				continue
			if c == CLOSE_BRACE:
				advance()
				return not failed
			return fail()
		return false

	func array(depth: int) -> bool:
		advance()
		skip_space()
		if at() == CLOSE_BRACKET:
			advance()
			last_count = 0
			return not failed
		var count := 0
		while not failed:
			if value(depth) == "":
				return fail()
			count += 1
			skip_space()
			var c := at()
			if c == COMMA:
				advance()
				continue
			if c == CLOSE_BRACKET:
				advance()
				last_count = count
				return not failed
			return fail()
		return false

	## Scans a string from its opening quote; returns the index of its closing quote, or -1.
	## It jumps to the next quote or backslash natively, and remembers both, so a body of many
	## strings or many escapes is scanned once. A raw byte below 0x20 inside it is an error.
	func string_end() -> int:
		advance()
		while not failed:
			if _next_quote < i:
				_next_quote = search(QUOTE, i)
				if _next_quote < 0:
					fail()
					return -1
			var quote := _next_quote
			if _next_backslash < i and _next_backslash != n:
				_next_backslash = search(BACKSLASH, i)
				if _next_backslash < 0:
					_next_backslash = n
			var segment_end := mini(quote, _next_backslash)
			if next_control(i) < segment_end:
				fail()
				return -1
			if _next_backslash < quote:
				advance(_next_backslash - i + 1)
				var e := at()
				if e == LOWER_U:
					if i + 4 >= n or not (hex(b[i + 1]) and hex(b[i + 2]) and hex(b[i + 3]) and hex(b[i + 4])):
						fail()
						return -1
					advance(5)
				elif SIMPLE_ESCAPES.has(e):
					advance()
				else:
					fail()
					return -1
				continue
			advance(quote - i + 1)
			return quote
		return -1

	## Number syntax only: -? (0 | [1-9][0-9]*) (. [0-9]+)? ([eE] [+-]? [0-9]+)?
	func number() -> bool:
		if at() == MINUS:
			advance()
		if at() == ZERO:
			advance()
		elif digit(at()):
			while not failed and digit(at()):
				advance()
		else:
			return fail()
		if at() == DOT:
			advance()
			if not digit(at()):
				return fail()
			while not failed and digit(at()):
				advance()
		if at() == LOWER_E or at() == UPPER_E:
			advance()
			if at() == PLUS or at() == MINUS:
				advance()
			if not digit(at()):
				return fail()
			while not failed and digit(at()):
				advance()
		return not failed

	## A key's raw bytes as a plain ASCII name with its escapes undone, or "" if it is not
	## one: anything outside printable ASCII, raw or escaped, cannot be a key the detector
	## looks for. The bytes are already checked as a well-formed JSON string.
	static func ascii_key(raw: PackedByteArray) -> String:
		if raw.size() > KEY_RAW_MAX:
			return ""
		var out := ""
		var k := 0
		while k < raw.size():
			var c := raw[k]
			if c == BACKSLASH:
				var e := raw[k + 1]
				if ESCAPED.has(e):
					out += ESCAPED[e]
					k += 2
					continue
				if e != LOWER_U:
					return ""  # \b \f \n \r \t: control characters, never in a wanted key
				var code := ("0x" + raw.slice(k + 2, k + 6).get_string_from_ascii()).hex_to_int()
				if code < 0x20 or code > 0x7E:
					return ""
				out += String.chr(code)
				k += 6
				continue
			if c < 0x20 or c > 0x7E:
				return ""
			out += String.chr(c)
			k += 1
		return out

	func literal(word: String) -> bool:
		var bytes := word.to_ascii_buffer()
		if i + bytes.size() > n or b.slice(i, i + bytes.size()) != bytes:
			return fail()
		advance(bytes.size())
		return not failed


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
	if state.refreshing:
		var busy: Dictionary = state.reading.duplicate() if not state.reading.is_empty() else _no_gpu()
		state.mutex.unlock()
		return busy
	var now: int = rate_clock.call()
	var due := not state.ever_read or now - state.read_at >= GPU_POLL_MIN_INTERVAL_MS
	if due:
		state.ever_read = true
		state.read_at = now
	state.refreshing = true
	state.mutex.unlock()
	var reading := {}
	if due:
		reading = _read_sysfs_gpu()
		if not reading["available"]:
			reading = _read_nvidia_smi(state)
		elif state.smi_pid != 0:
			_tidy_smi(state)  # /sys answers now, but an earlier nvidia-smi still needs reaping
	elif state.smi_pid != 0:
		reading = _tidy_smi(state)  # not due: no new start, but an earlier one may have answered
	state.mutex.lock()
	if not reading.is_empty():
		state.reading = reading
	state.refreshing = false
	var last: Dictionary = state.reading.duplicate() if not state.reading.is_empty() else _no_gpu()
	state.mutex.unlock()
	return last


## How many times nvidia-smi has been started for these settings, by any detector.
func nvidia_smi_runs() -> int:
	var state := _gpu_state()
	state.mutex.lock()
	var runs := state.nvidia_smi_runs
	state.mutex.unlock()
	return runs


func _gpu_state() -> GpuState:
	var key := [sysfs_root, nvidia_smi_path, rate_clock]
	_gpu_states_mutex.lock()
	if not _gpu_states.has(key):
		_gpu_states[key] = GpuState.new()
	var state: GpuState = _gpu_states[key]
	_gpu_states_mutex.unlock()
	return state


## Its answer if an earlier nvidia-smi has exited since, else {} with it left running.
func _tidy_smi(state: GpuState) -> Dictionary:
	var output = state.collect_if_done()
	if output == null:
		return {}
	return parse_nvidia_smi(output) if output != "" else _no_gpu()


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
		var late := _tidy_smi(state)
		if late.is_empty():
			return state.reading.duplicate() if not state.reading.is_empty() else _no_gpu()
		return late
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
	state.adopt(run, NVIDIA_SMI_OUTPUT_MAX_BYTES, POLL_SLEEP_USEC)
	if not state.pump(Time.get_ticks_msec() + nvidia_smi_timeout_ms, _job):
		return _no_gpu()  # still running: left to exit on its own, never killed
	var output := state.finish()
	return parse_nvidia_smi(output) if output != "" else _no_gpu()


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
