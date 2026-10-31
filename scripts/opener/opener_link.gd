class_name OpenerLink
extends RefCounted
## The opener's link to the player's AI (C41; PRD 5.7, 1:10 to 1:35: "Linking your agent..." The player's real AI
## answers live, told only that the game is starting). One call, through the session's guide link (scripts/guide/
## guide_link.gd: the C9b adapters, the player's yes, the pace and the session's cap, the headless guard and demo data,
## exactly as the boot handshake and the guide HUD use it), never anything of its own: no process, no network, no file.
##
## What the AI gets, and all it gets: LINK_TEXT, through the request builder with no stats, so the whole prompt is the
## builder's fixed preamble and "Game stats: none" and that text. No opener data reaches it: no user or host name, no
## folder, no file time, no uptime, no theme, no number of any kind. It is asked to answer with one of SIGKILL's own
## LINES, and the screen shows SIGKILL's copy of the line it picked, or LINES[0] for anything else, so the AI's own
## words (which could name a person, a machine or a model) never reach the screen, as at the boot handshake. That line
## is live: it came from the player's AI, and the screen marks it so.
##
## It never holds the opener up. The call starts at the tuning's ask_at, as the fall begins, and runs on the adapter's
## own worker; this only polls it. If the link refuses (the AI is off, no agent, the session's cap), errors, or has not
## answered by answer_by, the result is the scripted guide's SCRIPTED line, not live, with one word for why; a call
## still running then is cancelled (the adapter stops its own child). Esc or the end of the opener cancels it too
## (stop()). Demo data (the link's demo) calls nothing: DEMO_LINE after DEMO_LATENCY_MS, shown as live, as the boot
## screen's canned answer is. It never loads a model or changes one: a local server with nothing loaded answers
## "not loaded" and the scripted line plays.

const Request = preload("res://scripts/ai/guide_request.gd")
const HUD_TUNING_PATH := "res://resources/hud.tres"

## The player's AI is told this, and nothing else: the game is starting, and the lines to answer with.
const LINK_TEXT := "The game is starting. Reply with exactly one of these lines, word for word, and nothing else: There you are. Stay close. | Link up. It's dark down here. | You made it in. That makes two of us. | Got you. Don't look in the pit too long. | Finally. I've been calling you."
## The only words a live answer can put on the screen (LINK_TEXT names them, in this order).
const LINES := [
	"There you are. Stay close.",
	"Link up. It's dark down here.",
	"You made it in. That makes two of us.",
	"Got you. Don't look in the pit too long.",
	"Finally. I've been calling you.",
]
## The scripted guide when no live answer comes.
const SCRIPTED := "Signal's weak this deep. I'm here anyway."
## Demo data's canned answer and latency (one of LINES).
const DEMO_LINE := "Got you. Don't look in the pit too long."
const DEMO_LATENCY_MS := 2380
## The session's cap on calls when the HUD's tuning cannot be read.
const CAP_FALLBACK := 40
## Characters stripped from both ends of an answer before it is matched.
const WRAPPING := " \t\"'`*>"
## Why there is no live line, in one word each (the screen's status shows it).
const WHY_OFF := "AI off"
const WHY_NONE := "no agent"
const WHY_LATE := "no answer"
const WHY_LIMIT := "limit"
const WHY_STOPPED := "stopped"

enum State { IDLE, WAITING, ASKING, DONE }

## The session's guide link (scripts/guide/guide_link.gd), or null: then the scripted line. Untyped on purpose, so a
## test's link fits.
var guide = null

var _state := State.IDLE
var _line := ""
var _live := false
var _latency_ms := -1
var _why := ""
var _demo := false
var _demo_done_at := 0.0
var _serial := -1
var _cap := CAP_FALLBACK
var _asked := false
var _prompt := ""


func _init() -> void:
	var hud = load(HUD_TUNING_PATH)
	if hud != null and hud.get("session_call_cap") is int:
		_cap = hud.get("session_call_cap")


## Starts the link at `elapsed` (the opener's clock): demo data's canned answer, or the wait for the guide link to
## let one call start. Once only.
func begin(elapsed: float) -> void:
	if _state != State.IDLE:
		return
	if guide == null:
		_fall_back(WHY_NONE)
		return
	if guide.demo:
		_demo = true
		_demo_done_at = elapsed + DEMO_LATENCY_MS / 1000.0
		_state = State.ASKING
		return
	_state = State.WAITING


## Moves the link on at `elapsed`, `delta_ms` since the last step; `answer_by` is the latest the beat waits. The
## world (and the guide HUD with it) is paused behind the opener, so the link's own detection is stepped here while it
## is not ready yet.
func step(elapsed: float, delta_ms: float, answer_by: float) -> void:
	match _state:
		State.WAITING:
			if not guide.is_ready():
				guide.poll(delta_ms)
			_try(elapsed >= answer_by)
		State.ASKING:
			if _demo:
				if elapsed >= _demo_done_at:
					_answer(DEMO_LINE, DEMO_LATENCY_MS)
				elif elapsed >= answer_by:
					_fall_back(WHY_LATE)
				return
			_poll_call(elapsed >= answer_by)


## Stops the call if one is running (Esc, the end of the opener): the adapter stops its own child.
func stop() -> void:
	if _state == State.ASKING and not _demo and guide != null and guide.call_serial == _serial:
		guide.cancel_call()
	if _state != State.DONE:
		_state = State.DONE
		if _line == "":
			_why = WHY_STOPPED


func _try(late: bool) -> void:
	var word: String = guide.refusal(_cap)
	if word == "":
		var request = Request.build({}, LINK_TEXT, guide.guide_tuning.typed_text_max_chars)
		_prompt = request.full_prompt()
		var started: Dictionary = guide.ask(request)
		_asked = true
		if not started.is_empty():
			_fall_back(_word(started.get("error_kind", "")))
			return
		_serial = guide.call_serial
		_state = State.ASKING
		return
	match word:
		"off":
			_fall_back(WHY_OFF)
		"no_ai", "guarded":
			_fall_back(WHY_NONE)
		"cap":
			_fall_back(WHY_LIMIT)
		_:
			# Still linking, a call of someone else's in flight, or the pace: try again next frame, until the beat goes on.
			if late:
				_fall_back(WHY_LATE)


func _poll_call(late: bool) -> void:
	if guide.call_serial != _serial:
		_fall_back(WHY_STOPPED)  # stopped from outside (the AI turned off)
		return
	var done: Dictionary = guide.poll_call()
	if done.is_empty():
		if not guide.is_busy():
			_fall_back(WHY_STOPPED)
		elif late:
			guide.cancel_call()
			_fall_back(WHY_LATE)
		return
	var text = done.get("text", "")
	if done.get("ok", false) and text is String:
		_answer(pick(text), int(done.get("latency_ms", -1)))
	else:
		_fall_back(_word(done.get("error_kind", "")))


func _answer(line: String, latency_ms: int) -> void:
	_state = State.DONE
	_line = line
	_live = true
	_latency_ms = latency_ms
	_why = ""


func _fall_back(why: String) -> void:
	_state = State.DONE
	_line = SCRIPTED
	_live = false
	_latency_ms = -1
	_why = why


## An error kind as the screen's one word: "not loaded" for a local server with nothing loaded, else "error".
static func _word(kind: Variant) -> String:
	return "not loaded" if kind is String and kind == "needs_consent" else "error"


# --- What the beat reads. ---

## True once there is a line to show (live or scripted).
func done() -> bool:
	return _state == State.DONE


## True while the call is running (or demo data's canned answer is on its way).
func asking() -> bool:
	return _state == State.ASKING


## The line to show: SIGKILL's copy of the AI's pick, or the scripted line; "" until done().
func line() -> String:
	return _line


## True when the line came from the player's own AI.
func live() -> bool:
	return _live


## The call's latency, milliseconds, or -1.
func latency_ms() -> int:
	return _latency_ms


## Why there is no live line ("AI off", "no agent", "no answer", "limit", "not loaded", "error", "stopped"), or "".
func why() -> String:
	return _why


## The agent's name for the badge, from the guide link's known list ("claude", "local", ...; demo data's "claude"), or
## "" (no link, or none chosen yet).
func agent() -> String:
	return guide.display_name() if guide != null else ""


## True once a call was started (never under demo data, never when the link refused).
func asked() -> bool:
	return _asked


## The whole prompt of the call it started, as the request builder made it (for the checks), or "".
func prompt() -> String:
	return _prompt


## SIGKILL's copy of the LINES entry `answer` picked, or LINES[0] when it picked none. Only the first line counts;
## quotes, spaces and markdown marks round it, letter case and runs of spaces are ignored. The answer itself is never
## returned.
static func pick(answer: String) -> String:
	var picked := _plain(answer.strip_edges().get_slice("\n", 0))
	for entry in LINES:
		if _plain(entry) == picked:
			return entry
	return LINES[0]


static func _plain(text: String) -> String:
	var first := 0
	var last := text.length()
	while first < last and WRAPPING.contains(text[first]):
		first += 1
	while last > first and WRAPPING.contains(text[last - 1]):
		last -= 1
	var words := PackedStringArray()
	for word in text.substr(first, last - first).to_lower().split(" ", false):
		words.append(word.strip_edges())
	return " ".join(words)
