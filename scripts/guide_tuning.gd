class_name GuideTuning
extends Resource
## Every number that shapes how the game talks to the player's AI guide: the on/off switch,
## pacing, timeouts, size caps, and the limits for loading a model on the player's Ollama
## server after their yes (C11b). The default instance is resources/guide.tres; the guide
## adapters in scripts/ai and scripts/guide/ollama_loader.gd read only from this resource.
## Units are milliseconds, characters, bytes and MiB.

@export_group("Switch")
## Whether the guide may call an AI at all. Off until the player opts in (the first-launch
## opt-in comes with the boot sequence, C10); while off, every ask is refused at once.
@export var ai_enabled: bool = false

@export_group("Pacing")
## Shortest gap between two asks to one adapter. Never per frame: at least 1 second.
@export var min_interval_ms: int = 10000
## Longest an agent CLI may take before the game stops it.
@export var agent_timeout_ms: int = 60000
## Longest a local model server may take, model lookup and answer together.
@export var local_timeout_ms: int = 30000

@export_group("Limits")
## Most characters of the player's typed text sent; the rest is cut.
@export var typed_text_max_chars: int = 500
## Most characters of an answer kept.
@export var answer_max_chars: int = 600
## Most bytes of an agent's output read; more is dropped. At most 64 KiB.
@export var stdout_max_bytes: int = 65536
## Most bytes of a local server's response read; longer is no answer.
@export var local_response_max_bytes: int = 131072
## Most tokens asked of a local model per answer.
@export var local_max_tokens: int = 200

@export_group("Model loading")
## Largest model the game offers to load on the player's Ollama server, in bytes (8 GiB).
@export var max_load_bytes: int = 8589934592
## When the GPU's free VRAM is known, a model must fit under it minus this much, in MiB.
@export var vram_margin_mib: int = 1024
## Longest a load may take after the player's Y before the game stops waiting.
@export var load_timeout_ms: int = 120000
## Longest the game waits at exit to unload the model it loaded.
@export var unload_timeout_ms: int = 2000
## After a load the game stopped waiting for, how often it checks whether that model
## turned up after all, so it can unload it.
@export var load_watch_interval_ms: int = 2000

const MIN_INTERVAL_FLOOR_MS := 1000
const INTERVAL_LAST_MS := 3600000
const TIMEOUT_FLOOR_MS := 1000
const TIMEOUT_LAST_MS := 600000
const TYPED_TEXT_LAST := 2000
const ANSWER_LAST := 4000
const OUTPUT_FLOOR_BYTES := 1024
const OUTPUT_LAST_BYTES := 1048576
## The hard ceiling on an agent's output: 64 KiB, whatever the tuning says.
const STDOUT_LAST_BYTES := 65536
const MAX_TOKENS_LAST := 2048
const LOAD_BYTES_FIRST := 268435456
const LOAD_BYTES_LAST := 1099511627776
const MARGIN_LAST_MIB := 65536
const UNLOAD_FIRST_MS := 100
const UNLOAD_LAST_MS := 10000
const WATCH_FIRST_MS := 500
const WATCH_LAST_MS := 60000


## Everything wrong with these values, or empty when they are safe to use.
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	if min_interval_ms < MIN_INTERVAL_FLOOR_MS or min_interval_ms > INTERVAL_LAST_MS:
		out.append("min_interval_ms must be between %d and %d" % [MIN_INTERVAL_FLOOR_MS, INTERVAL_LAST_MS])
	for field in ["agent_timeout_ms", "local_timeout_ms"]:
		var value: int = get(field)
		if value < TIMEOUT_FLOOR_MS or value > TIMEOUT_LAST_MS:
			out.append("%s must be between %d and %d" % [field, TIMEOUT_FLOOR_MS, TIMEOUT_LAST_MS])
	if typed_text_max_chars < 1 or typed_text_max_chars > TYPED_TEXT_LAST:
		out.append("typed_text_max_chars must be between 1 and %d" % TYPED_TEXT_LAST)
	if answer_max_chars < 1 or answer_max_chars > ANSWER_LAST:
		out.append("answer_max_chars must be between 1 and %d" % ANSWER_LAST)
	if stdout_max_bytes < OUTPUT_FLOOR_BYTES or stdout_max_bytes > STDOUT_LAST_BYTES:
		out.append("stdout_max_bytes must be between %d and %d" % [OUTPUT_FLOOR_BYTES, STDOUT_LAST_BYTES])
	if local_response_max_bytes < OUTPUT_FLOOR_BYTES or local_response_max_bytes > OUTPUT_LAST_BYTES:
		out.append("local_response_max_bytes must be between %d and %d" % [OUTPUT_FLOOR_BYTES, OUTPUT_LAST_BYTES])
	if local_max_tokens < 1 or local_max_tokens > MAX_TOKENS_LAST:
		out.append("local_max_tokens must be between 1 and %d" % MAX_TOKENS_LAST)
	if max_load_bytes < LOAD_BYTES_FIRST or max_load_bytes > LOAD_BYTES_LAST:
		out.append("max_load_bytes must be between %d and %d" % [LOAD_BYTES_FIRST, LOAD_BYTES_LAST])
	if vram_margin_mib < 0 or vram_margin_mib > MARGIN_LAST_MIB:
		out.append("vram_margin_mib must be between 0 and %d" % MARGIN_LAST_MIB)
	if load_timeout_ms < TIMEOUT_FLOOR_MS or load_timeout_ms > TIMEOUT_LAST_MS:
		out.append("load_timeout_ms must be between %d and %d" % [TIMEOUT_FLOOR_MS, TIMEOUT_LAST_MS])
	if unload_timeout_ms < UNLOAD_FIRST_MS or unload_timeout_ms > UNLOAD_LAST_MS:
		out.append("unload_timeout_ms must be between %d and %d" % [UNLOAD_FIRST_MS, UNLOAD_LAST_MS])
	if load_watch_interval_ms < WATCH_FIRST_MS or load_watch_interval_ms > WATCH_LAST_MS:
		out.append("load_watch_interval_ms must be between %d and %d" % [WATCH_FIRST_MS, WATCH_LAST_MS])
	return out
