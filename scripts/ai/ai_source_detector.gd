extends RefCounted
## Finds which AI this player's game can talk to, following PRD 5.4: the player's Omarchy
## default agent first, then a local model server, then the scripted guide with "AI off".
## No UI, and not wired into any scene yet; the boot screen (C10) will use it.
##
## What it touches, and nothing else (PRD section 6):
## - Omarchy's default-agent setting: only the first line of that one file, at most
##   AGENT_FILE_MAX_BYTES read. Never any other config file. It never runs
##   omarchy-default-agent or omarchy-agent.
## - The PATH directories: whether a known agent's command exists there as a file with an
##   execute bit. Nothing is read from it and it is never run, not even with --version.
## - Local model servers, on 127.0.0.1 only (LOCALHOST is a constant, never a setting): one
##   short HTTP GET per endpoint, Ollama's /api/version and /api/tags and the OpenAI-style
##   /v1/models. Only reachable, latency and a model COUNT are kept; model names are
##   counted and dropped, never stored, logged or printed. Nothing is loaded, pulled,
##   unloaded or changed, and no model setting is touched.
##
## - GPU stats, read-only: a few named /sys attributes per DRM card first (gpu_busy_percent,
##   mem_info_vram_used, mem_info_vram_total, hwmon temp1_input), and only if none answer,
##   the SECOND named execute exception of PRD section 6: nvidia-smi with exactly
##   NVIDIA_SMI_ARGS, query-only, no control flags, as an argument array with no shell.
##   poll_gpu() is the only way in, and it reads at most once per GPU_POLL_MIN_INTERVAL_MS.
##
## Blocking: the server probes wait up to http_timeout_ms per request and nvidia-smi up to
## nvidia_smi_timeout_ms, so they must never run on the main thread. detect() is
## synchronous and start() runs it on a worker thread. nvidia-smi runs through a
## non-blocking pipe with a deadline: if it hangs it is left to exit on its own, never
## waited on forever and never killed.
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
## Most bytes ever read from the setting. A longer first line counts as unset.
const AGENT_FILE_MAX_BYTES := 256
const NEWLINE := 0x0A
const TAB := 0x09
const CARRIAGE_RETURN := 0x0D
const PRINTABLE_FIRST := 0x20
const PRINTABLE_LAST := 0x7E
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
## Largest response body read; anything longer counts as no answer.
const HTTP_BODY_MAX_BYTES := 1048576
const HTTP_OK := 200
const PORT_LAST := 65535
## Pause between polls of a connection or a pipe, in microseconds.
const POLL_SLEEP_USEC := 1000
const SYSFS_ROOT := "/sys"
## DRM cards and hwmon sensors looked at, card0 and hwmon0 upward.
const DRM_CARDS_SCANNED := 8
const HWMON_SCANNED := 16
## Most bytes read from one /sys attribute.
const SYSFS_VALUE_MAX_BYTES := 32
const NVIDIA_SMI := "nvidia-smi"
## The only arguments nvidia-smi is ever given: a query, never a control flag.
const NVIDIA_SMI_ARGS: PackedStringArray = [
	"--query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu",
	"--format=csv,noheader,nounits",
]
const NVIDIA_SMI_FIELDS := 4
## Longest wait for nvidia-smi to finish, in milliseconds.
const NVIDIA_SMI_TIMEOUT_MS := 1500
## Most bytes of nvidia-smi output read.
const NVIDIA_SMI_OUTPUT_MAX_BYTES := 4096
## poll_gpu() reads the GPU at most this often, in milliseconds.
const GPU_POLL_MIN_INTERVAL_MS := 1000
const BYTES_PER_MIB := 1048576
const MILLIDEGREES_PER_DEGREE := 1000.0

## Omarchy's default-agent setting. Empty means the real one under the player's home.
var agent_file_path := ""
## Directories searched for commands. Empty means the player's PATH.
var path_dirs := PackedStringArray()
## Local server ports on 127.0.0.1. The host itself cannot be changed.
var ollama_port := OLLAMA_PORT
var openai_port := OPENAI_PORT
## Longest wait for one HTTP request, in milliseconds.
var http_timeout_ms := HTTP_TIMEOUT_MS
## Root of the /sys tree read for GPU stats.
var sysfs_root := SYSFS_ROOT
## nvidia-smi to run. Empty means the one on the PATH, if any.
var nvidia_smi_path := ""
## Longest wait for nvidia-smi, in milliseconds.
var nvidia_smi_timeout_ms := NVIDIA_SMI_TIMEOUT_MS
## Milliseconds since a fixed start, for the GPU rate limit only. Tests swap it. Timeouts
## and latency always use real time, so a stopped test clock can never stall a probe.
var rate_clock := Callable(Time, "get_ticks_msec")

var _gpu := {}
var _gpu_read_at := 0
var _gpu_ever_read := false
var _gpu_mutex := Mutex.new()
var _nvidia_smi_runs := 0


## Reads the default-agent setting and returns [AgentState, agent name or ""].
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
	# One byte past the cap tells a long line from one that just fits.
	var bytes := file.get_buffer(AGENT_FILE_MAX_BYTES + 1)
	file.close()
	return parse_agent_line(bytes)


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


## One GET to 127.0.0.1:port, path. Returns {latency_ms, data} with the parsed JSON, or {}
## on refusal, timeout, a status other than 200, a body over the cap or a body that is not
## JSON. The caller takes what it counts and drops the rest.
func _get_json(port: int, path: String) -> Dictionary:
	if port < 1 or port > PORT_LAST:
		return {}
	var start := Time.get_ticks_msec()
	var deadline := start + http_timeout_ms
	var client := HTTPClient.new()
	if client.connect_to_host(LOCALHOST, port) != OK:
		return {}
	if not _wait_while(client, [HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING], deadline):
		return {}
	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		client.close()
		return {}
	if client.request(HTTPClient.METHOD_GET, path, PackedStringArray(["Accept: application/json"])) != OK:
		client.close()
		return {}
	if not _wait_while(client, [HTTPClient.STATUS_REQUESTING], deadline):
		return {}
	if not client.has_response() or client.get_response_code() != HTTP_OK:
		client.close()
		return {}
	var latency := Time.get_ticks_msec() - start
	var body := PackedByteArray()
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk := client.read_response_body_chunk()
		if chunk.is_empty():
			if Time.get_ticks_msec() > deadline:
				client.close()
				return {}
			OS.delay_usec(POLL_SLEEP_USEC)
			continue
		body.append_array(chunk)
		if body.size() > HTTP_BODY_MAX_BYTES:
			client.close()
			return {}
	client.close()
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return {}
	return {"latency_ms": latency, "data": json.data}


## Polls the client while its status is one of `waiting`. False, with the connection
## closed, if the deadline passes first.
func _wait_while(client: HTTPClient, waiting: Array, deadline: int) -> bool:
	while waiting.has(client.get_status()):
		if Time.get_ticks_msec() > deadline:
			client.close()
			return false
		client.poll()
		OS.delay_usec(POLL_SLEEP_USEC)
	return true


## GPU stats: {available, source, util_percent, vram_used_mib, vram_total_mib, temp_c}.
## Reads at most once per GPU_POLL_MIN_INTERVAL_MS; a call sooner gets the last reading.
## /sys first; nvidia-smi only when /sys gives nothing. Safe to call from any one thread at
## a time; a mutex keeps two callers from reading at once.
func poll_gpu() -> Dictionary:
	_gpu_mutex.lock()
	var now: int = rate_clock.call()
	if not _gpu_ever_read or now - _gpu_read_at >= GPU_POLL_MIN_INTERVAL_MS:
		_gpu_ever_read = true
		_gpu_read_at = now
		_gpu = _read_sysfs_gpu()
		if not _gpu["available"]:
			_gpu = _read_nvidia_smi()
	var reading := _gpu.duplicate()
	_gpu_mutex.unlock()
	return reading


## How many times nvidia-smi has been started by this detector.
func nvidia_smi_runs() -> int:
	return _nvidia_smi_runs


static func _no_gpu() -> Dictionary:
	return {"available": false, "source": "none", "util_percent": -1, "vram_used_mib": -1, "vram_total_mib": -1, "temp_c": -1}


## The first DRM card under sysfs_root that reports busy percent or VRAM.
func _read_sysfs_gpu() -> Dictionary:
	for card in DRM_CARDS_SCANNED:
		var device := sysfs_root.path_join("class/drm/card%d/device" % card)
		var busy := _read_sysfs_int(device.path_join("gpu_busy_percent"))
		var used := _read_sysfs_int(device.path_join("mem_info_vram_used"))
		var total := _read_sysfs_int(device.path_join("mem_info_vram_total"))
		if busy < 0 and total <= 0:
			continue
		var temp := -1
		for sensor in HWMON_SCANNED:
			var milli := _read_sysfs_int(device.path_join("hwmon/hwmon%d/temp1_input" % sensor))
			if milli >= 0:
				temp = roundi(milli / MILLIDEGREES_PER_DEGREE)
				break
		return {
			"available": true,
			"source": "sysfs",
			"util_percent": busy,
			"vram_used_mib": used / BYTES_PER_MIB if used >= 0 else -1,
			"vram_total_mib": total / BYTES_PER_MIB if total > 0 else -1,
			"temp_c": temp,
		}
	return _no_gpu()


## A whole number from one /sys attribute, or -1 if it is missing or not a number.
static func _read_sysfs_int(path: String) -> int:
	if not FileAccess.file_exists(path):
		return -1
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var text := file.get_buffer(SYSFS_VALUE_MAX_BYTES).get_string_from_ascii().strip_edges()
	file.close()
	if not text.is_valid_int():
		return -1
	var value := text.to_int()
	return value if value >= 0 else -1


## Runs nvidia-smi with exactly NVIDIA_SMI_ARGS and reads the first GPU's line.
func _read_nvidia_smi() -> Dictionary:
	var path := nvidia_smi_path if not nvidia_smi_path.is_empty() else find_command(NVIDIA_SMI)
	if path.is_empty() or not path.is_absolute_path() or DirAccess.dir_exists_absolute(path):
		return _no_gpu()
	if not FileAccess.file_exists(path) or not (FileAccess.get_unix_permissions(path) & EXECUTE_BITS):
		return _no_gpu()
	var run := OS.execute_with_pipe(path, NVIDIA_SMI_ARGS, false)
	if run.is_empty():
		return _no_gpu()
	_nvidia_smi_runs += 1
	var stdout: FileAccess = run["stdio"]
	var stderr: FileAccess = run["stderr"]
	var pid: int = run["pid"]
	var deadline := Time.get_ticks_msec() + nvidia_smi_timeout_ms
	var output := PackedByteArray()
	var finished := false
	while true:
		var chunk := stdout.get_buffer(NVIDIA_SMI_OUTPUT_MAX_BYTES)
		output.append_array(chunk)
		stderr.get_buffer(NVIDIA_SMI_OUTPUT_MAX_BYTES)  # drained and dropped, so it never fills
		if output.size() > NVIDIA_SMI_OUTPUT_MAX_BYTES:
			break
		if chunk.is_empty():
			if not OS.is_process_running(pid):
				output.append_array(stdout.get_buffer(NVIDIA_SMI_OUTPUT_MAX_BYTES))
				finished = true
				break
			if Time.get_ticks_msec() > deadline:
				break  # left to exit on its own: never killed (PRD section 6)
			OS.delay_usec(POLL_SLEEP_USEC)
	stdout.close()
	stderr.close()
	if not finished or output.size() > NVIDIA_SMI_OUTPUT_MAX_BYTES or OS.get_process_exit_code(pid) != 0:
		return _no_gpu()
	return parse_nvidia_smi(output.get_string_from_ascii())


## The first line of nvidia-smi's CSV: utilization %, memory used MiB, memory total MiB,
## temperature C. A field that is not a whole number, such as "[N/A]", becomes -1.
static func parse_nvidia_smi(text: String) -> Dictionary:
	var line := text.split("\n", false)
	if line.is_empty():
		return _no_gpu()
	var fields := line[0].split(",")
	if fields.size() != NVIDIA_SMI_FIELDS:
		return _no_gpu()
	var values := PackedInt64Array()
	for field in fields:
		var value := field.strip_edges()
		values.append(value.to_int() if value.is_valid_int() and value.to_int() >= 0 else -1)
	if values[0] < 0 and values[2] < 0:
		return _no_gpu()
	return {
		"available": true,
		"source": "nvidia-smi",
		"util_percent": values[0],
		"vram_used_mib": values[1],
		"vram_total_mib": values[2],
		"temp_c": values[3],
	}


func _search_dirs() -> PackedStringArray:
	if not path_dirs.is_empty():
		return path_dirs
	return OS.get_environment("PATH").split(":", false)


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
