extends RefCounted
## The common interface to the player's AI guide (PRD 5.4). One adapter per source: the
## Claude Code CLI, the Codex CLI, or a local OpenAI-compatible model server. Not wired into
## any scene yet; the boot sequence (C10) and the HUD (C11) will be.
##
## Non-blocking, polled: ask(request) returns {} when the request has started, and then
## poll(), called each frame or tick, returns {} until the result is ready and the result
## once. ask() returns a finished result at once when it cannot start: "ai_off" when the
## guide is switched off, "busy" while one request is in flight (one at a time per adapter),
## "rate_limited" within min_interval_ms of the last ask, "unavailable", "bad_request".
## cancel() stops a running request and returns its "cancelled" result.
##
## Every result has the same shape: {ok, text, error_kind, latency_ms, tokens_per_sec}.
## text is the cleaned answer when ok; error_kind is "" when ok; tokens_per_sec is -1
## except for the local server. Timeouts use real time; the rate limit uses rate_clock,
## which tests may swap.

const Tuning = preload("res://scripts/guide_tuning.gd")
const DEFAULT_TUNING_PATH := "res://resources/guide.tres"
const ESC := 0x1B
const BEL := 0x07
const NEWLINE := 0x0A
const TAB := 0x09
const SPACE := 0x20
const CONTROL_LAST := 0x1F
const DELETE := 0x7F
const C1_FIRST := 0x80
const C1_LAST := 0x9F
const CSI_FINAL_FIRST := 0x40
const CSI_FINAL_LAST := 0x7E
## Escape sequences that run to a terminator: OSC, DCS, SOS, PM, APC.
const STRING_ESCAPES := [0x5D, 0x50, 0x58, 0x5E, 0x5F]
const BACKSLASH := 0x5C
const OPEN_BRACKET := 0x5B
## Invisible and direction-changing characters dropped from answers.
const INVISIBLE := [0x061C, 0x200B, 0x200C, 0x200D, 0x200E, 0x200F, 0x202A, 0x202B, 0x202C, 0x202D, 0x202E, 0x2060, 0x2066, 0x2067, 0x2068, 0x2069, 0xFEFF]
## The most blank lines kept in a row in an answer.
const BLANK_LINES_KEPT := 1

## Milliseconds since a fixed start, for the rate limit only. Tests swap it.
var rate_clock := Callable(Time, "get_ticks_msec")

var _t: Tuning
var _busy := false
var _ever_asked := false
var _last_ask_at := 0
var _started_at := 0


func _init(tuning: Resource = null) -> void:
	_t = usable_tuning(tuning)


## The tuning given if it is safe, else the shipped one, else the built-in defaults.
static func usable_tuning(tuning: Resource) -> Tuning:
	if tuning is Tuning:
		var issues: PackedStringArray = tuning.problems()
		if issues.is_empty():
			return tuning
		for issue in issues:
			push_warning("guide tuning: " + issue + "; using the shipped tuning instead")
	var shipped = load(DEFAULT_TUNING_PATH)
	if shipped is Tuning and shipped.problems().is_empty():
		return shipped
	return Tuning.new()


func tuning() -> Tuning:
	return _t


## Which adapter this is: "claude", "codex", "local", or "none".
func adapter_name() -> String:
	return "none"


## Whether this adapter can be asked at all (its command or server is there).
func is_available() -> bool:
	return false


func is_busy() -> bool:
	return _busy


## Starts a request; see the header. `request` is a GuideRequest.
func ask(request: RefCounted) -> Dictionary:
	if not _t.ai_enabled:
		return result(false, "", "ai_off")
	if _busy:
		return result(false, "", "busy")
	var now: int = rate_clock.call()
	if _ever_asked and now - _last_ask_at < _t.min_interval_ms:
		return result(false, "", "rate_limited")
	if request == null or not request.has_method("user_message"):
		return result(false, "", "bad_request")
	if not is_available():
		return result(false, "", "unavailable")
	_ever_asked = true
	_last_ask_at = now
	_started_at = Time.get_ticks_msec()
	_busy = true
	var problem := _begin(request)
	if problem != "":
		return _end(result(false, "", problem))
	return {}


## {} while the request runs; its result once, when done. Never blocks.
func poll() -> Dictionary:
	if not _busy:
		return {}
	var done := _step()
	if done.is_empty():
		if Time.get_ticks_msec() - _started_at > _timeout_ms():
			_abort()
			return _end(result(false, "", "timeout"))
		return {}
	return _end(done)


## Stops a running request and returns its "cancelled" result; {} if none was running.
func cancel() -> Dictionary:
	if not _busy:
		return {}
	_abort()
	return _end(result(false, "", "cancelled"))


static func result(ok: bool, text: String, error_kind: String, tokens_per_sec: float = -1.0) -> Dictionary:
	return {"ok": ok, "text": text, "error_kind": error_kind, "latency_ms": -1, "tokens_per_sec": tokens_per_sec}


func _end(done: Dictionary) -> Dictionary:
	_busy = false
	done["latency_ms"] = Time.get_ticks_msec() - _started_at
	return done


# Hooks for each adapter.

## Starts the request; "" when it is under way, else the error_kind.
func _begin(_request: RefCounted) -> String:
	return "unavailable"


## {} while running, else the result (latency is filled in here).
func _step() -> Dictionary:
	return {}


## Stops whatever the request has running.
func _abort() -> void:
	pass


func _timeout_ms() -> int:
	return _t.agent_timeout_ms


## An answer from raw output bytes, safe to show: ANSI escape sequences and control bytes
## removed (newlines kept, tabs become spaces), only well-formed UTF-8 kept, C1 controls and
## invisible or direction-changing characters dropped, at most one blank line in a row,
## trimmed and cut to `max_chars`. Works on bytes and decodes once, so nothing printed.
static func clean_answer(raw: PackedByteArray, max_chars: int) -> String:
	var plain := PackedByteArray()
	var i := 0
	var n := raw.size()
	while i < n:
		var b := raw[i]
		if b == ESC:
			i = _after_escape(raw, i)
			continue
		if b == NEWLINE:
			plain.append(b)
		elif b == TAB:
			plain.append(SPACE)
		elif b > CONTROL_LAST and b != DELETE:
			plain.append(b)
		i += 1
	var text := _keep_utf8(plain, maxi(max_chars, 0) * 2).get_string_from_utf8()
	var blank := "\n".repeat(BLANK_LINES_KEPT + 2)
	var fewer := "\n".repeat(BLANK_LINES_KEPT + 1)
	while text.contains(blank):
		text = text.replace(blank, fewer)
	return text.strip_edges().left(maxi(max_chars, 0)).strip_edges()


## Index just past the escape sequence that starts at `at`.
static func _after_escape(raw: PackedByteArray, at: int) -> int:
	var n := raw.size()
	if at + 1 >= n:
		return n
	var kind := raw[at + 1]
	if kind == OPEN_BRACKET:
		var j := at + 2
		while j < n and (raw[j] < CSI_FINAL_FIRST or raw[j] > CSI_FINAL_LAST):
			j += 1
		return mini(j + 1, n)
	if STRING_ESCAPES.has(kind):
		var j := at + 2
		while j < n:
			if raw[j] == BEL:
				return j + 1
			if raw[j] == ESC and j + 1 < n and raw[j + 1] == BACKSLASH:
				return j + 2
			j += 1
		return n
	return at + 2


## The well-formed UTF-8 in `bytes`, with C1 controls and INVISIBLE characters dropped and
## everything after `max_chars` characters left out. Malformed bytes are skipped one by one.
static func _keep_utf8(bytes: PackedByteArray, max_chars: int) -> PackedByteArray:
	var out := PackedByteArray()
	var chars := 0
	var i := 0
	var n := bytes.size()
	while i < n and chars < max_chars:
		var b := bytes[i]
		if b < 0x80:
			out.append(b)
			chars += 1
			i += 1
			continue
		var extra := 0
		var low := 0x80
		var high := 0xBF
		var code := 0
		if b >= 0xC2 and b <= 0xDF:
			extra = 1
			code = b & 0x1F
		elif b == 0xE0:
			extra = 2
			low = 0xA0
			code = b & 0x0F
		elif (b >= 0xE1 and b <= 0xEC) or b == 0xEE or b == 0xEF:
			extra = 2
			code = b & 0x0F
		elif b == 0xED:
			extra = 2
			high = 0x9F
			code = b & 0x0F
		elif b == 0xF0:
			extra = 3
			low = 0x90
			code = b & 0x07
		elif b >= 0xF1 and b <= 0xF3:
			extra = 3
			code = b & 0x07
		elif b == 0xF4:
			extra = 3
			high = 0x8F
			code = b & 0x07
		else:
			i += 1
			continue
		var good := i + extra < n
		var k := 1
		while good and k <= extra:
			var c := bytes[i + k]
			if c < (low if k == 1 else 0x80) or c > (high if k == 1 else 0xBF):
				good = false
			else:
				code = (code << 6) | (c & 0x3F)
			k += 1
		if not good:
			i += 1
			continue
		if not (code >= C1_FIRST and code <= C1_LAST) and not INVISIBLE.has(code):
			out.append_array(bytes.slice(i, i + extra + 1))
			chars += 1
		i += extra + 1
	return out
